use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

use grimoire_pack::inventory::scan as scan_inventory;

use crate::locks::{LockCoordinator, LockMode, LockRank};
use crate::source::HeldDirectoryReader;
use crate::transaction::journal::{Journal, StateName};
use crate::{
    Action, Blocker, ByteHash, CoreError, ExitClass, Paths, Plan, Preconditions, ProjectIndex,
    ProjectReference, ReachabilityObservation, Result, Scope, ScopePaths, TransactionRuntime,
    WorldObservation, WorldState,
};

const ENTRY_LIMIT: usize = 100_000;
const STATE_LIMIT: u64 = 16 * 1024 * 1024;

pub fn observe_reachability(
    paths: &Paths,
    explicit_projects: &[PathBuf],
    runtime: &dyn TransactionRuntime,
) -> Result<ReachabilityObservation> {
    if !matches!(paths.scope, ScopePaths::Global { .. }) {
        return Err(CoreError::Request(
            "store reachability requires global resolved paths".into(),
        ));
    }
    let mut locks = LockCoordinator::new();
    locks.acquire(
        &paths.store_lock_path(),
        LockRank::Store,
        LockMode::Exclusive,
    )?;
    locks.acquire(
        &paths.projects_lock_path(),
        LockRank::Projects,
        LockMode::Exclusive,
    )?;

    let mut refresh_findings = Vec::new();
    let index_bytes = refresh_projects(paths, explicit_projects, runtime, &mut refresh_findings)?;
    let mut observation = scan_locked(paths, index_bytes.as_deref())?;
    observation.findings.extend(refresh_findings);
    observation.findings.sort();
    observation.findings.dedup();
    if observation
        .findings
        .iter()
        .any(|finding| finding.code == "project-reference-unknown")
    {
        observation.retain_all = true;
    }
    Ok(observation)
}

pub(crate) fn reobserve_locked(paths: &Paths) -> Result<ReachabilityObservation> {
    let bytes = read_optional_bounded(&paths.projects_path())?;
    scan_locked(paths, bytes.as_deref())
}

pub(crate) fn plan_prune(world: &WorldState) -> Result<Plan> {
    if world.scope != Scope::Global {
        return Err(CoreError::Request("store prune is global-only".into()));
    }
    let observation = world.reachability.as_ref().ok_or_else(|| {
        CoreError::Request("store prune requires reachability observation".into())
    })?;
    let mut blockers = Vec::new();
    if observation.retain_all {
        blockers.push(Blocker::new("prune-reachability-uncertain", []));
    }
    let actions = if blockers.is_empty() {
        observation
            .snapshots
            .difference(&observation.reachable)
            .map(|reference| Action::PruneSnapshot {
                source_key: reference.source_key.clone(),
                snapshot_key: reference.snapshot_key.clone(),
            })
            .collect()
    } else {
        Vec::new()
    };
    Ok(Plan {
        actions,
        blockers,
        preconditions: Preconditions {
            reachability: Some(observation.generation.clone()),
            ..Preconditions::absent()
        },
        facts: Vec::new(),
        exit_class: if observation.retain_all {
            ExitClass::Blocked
        } else {
            ExitClass::Success
        },
    })
}

pub(crate) fn remove_snapshot(paths: &Paths, reference: &ProjectReference) -> Result<()> {
    let root = paths.store_path(&reference.source_key, &reference.snapshot_key);
    let metadata =
        fs::symlink_metadata(&root).map_err(|error| crate::transaction::io_error(&root, error))?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(CoreError::StalePlan(
            "prune target is not a canonical snapshot directory".into(),
        ));
    }
    let mut budget = ENTRY_LIMIT;
    remove_tree(&root, 0, &mut budget)?;
    if let Some(parent) = root.parent() {
        crate::transaction::sync_directory(parent)?;
    }
    Ok(())
}

fn refresh_projects(
    paths: &Paths,
    explicit_projects: &[PathBuf],
    runtime: &dyn TransactionRuntime,
    findings: &mut Vec<WorldObservation>,
) -> Result<Option<Vec<u8>>> {
    let before = read_optional_bounded(&paths.projects_path())?;
    let mut index = match before.as_deref() {
        Some(bytes) => match ProjectIndex::parse(bytes) {
            Ok(index) => index,
            Err(error) => {
                findings.push(observation(
                    "project-index-invalid",
                    [("message", error.to_string())],
                ));
                return Ok(before);
            }
        },
        None => ProjectIndex::default(),
    };

    let mut projects = index
        .records
        .values()
        .map(|record| (record.scope_key.clone(), (record.path.clone(), true)))
        .collect::<BTreeMap<_, _>>();
    for project in explicit_projects {
        match project.canonicalize() {
            Ok(project) => {
                let project_paths = Paths::project(project.clone(), paths.grimoire_home.clone())?;
                projects.insert(project_paths.scope_key(), (project, false));
            }
            Err(error) => {
                findings.push(observation(
                    "project-unreadable",
                    [
                        ("path", project.display().to_string()),
                        ("message", error.to_string()),
                    ],
                ));
            }
        }
    }

    let timestamp = runtime.unix_time()?;
    for (scope_key, (project, indexed)) in projects {
        let project_paths = Paths::project(project.clone(), paths.grimoire_home.clone())?;
        let refreshed = (|| {
            let manifest_bytes = read_required_bounded(&project_paths.manifest_path())?;
            let lock_bytes = read_required_bounded(&project_paths.lock_path())?;
            let manifest = crate::Manifest::parse(manifest_bytes)?;
            let lock = crate::Lockfile::parse(&lock_bytes)?;
            crate::projects::build_record(&project_paths, &manifest, &lock, &lock_bytes, timestamp)
        })();
        match refreshed {
            Ok(record) => {
                index.records.insert(scope_key, record);
            }
            Err(error) => {
                findings.push(observation(
                    "project-unreadable",
                    [
                        ("path", project.display().to_string()),
                        ("message", error.to_string()),
                    ],
                ));
                if !indexed {
                    findings.push(observation("project-reference-unknown", []));
                }
            }
        }
    }

    if index.records.is_empty() && before.is_none() {
        return Ok(None);
    }
    let nonce = runtime.transaction_nonce()?;
    crate::projects::write_locked(paths, &index, &nonce).map(Some)
}

fn scan_locked(paths: &Paths, index_bytes: Option<&[u8]>) -> Result<ReachabilityObservation> {
    let mut scan = ReachabilityScan::default();
    scan.record_bytes("projects", index_bytes);
    let index = match index_bytes {
        Some(bytes) => match ProjectIndex::parse(bytes) {
            Ok(index) => index,
            Err(error) => {
                scan.retain_all = true;
                scan.findings.push(observation(
                    "project-index-invalid",
                    [("message", error.to_string())],
                ));
                ProjectIndex::default()
            }
        },
        None => ProjectIndex::default(),
    };
    for record in index.records.values() {
        scan.reachable.extend(record.references.iter().cloned());
        let lock_path = record.path.join("grimoire.lock");
        match read_optional_bounded(&lock_path) {
            Ok(bytes) => {
                scan.record_bytes(
                    &format!("project-lock:{}", record.scope_key),
                    bytes.as_deref(),
                );
                if bytes.as_deref().map(ByteHash::of).as_ref() != Some(&record.lock_hash) {
                    scan.findings.push(observation(
                        "project-lock-changed",
                        [("scope_key", record.scope_key.clone())],
                    ));
                }
            }
            Err(error) => {
                scan.record_text(&format!("project-lock:{}", record.scope_key), "unreadable");
                scan.findings.push(observation(
                    "project-unreadable",
                    [
                        ("scope_key", record.scope_key.clone()),
                        ("message", error.to_string()),
                    ],
                ));
            }
        }
    }
    scan_global(paths, &mut scan)?;
    scan_candidates(paths, &mut scan)?;
    scan_journals(paths, &mut scan)?;
    scan_store(paths, &mut scan)?;
    scan.entries.sort();
    scan.findings.sort();
    scan.findings.dedup();
    let generation = ByteHash::of(&serde_json::to_vec(&scan.entries)?);
    Ok(ReachabilityObservation {
        generation,
        snapshots: scan.snapshots,
        reachable: scan.reachable,
        findings: scan.findings,
        retain_all: scan.retain_all,
    })
}

fn scan_global(paths: &Paths, scan: &mut ReachabilityScan) -> Result<()> {
    let manifest = read_optional_bounded(&paths.manifest_path())?;
    let lock = read_optional_bounded(&paths.lock_path())?;
    scan.record_bytes("global-manifest", manifest.as_deref());
    scan.record_bytes("global-lock", lock.as_deref());
    match (manifest, lock) {
        (None, None) => Ok(()),
        (Some(manifest), Some(lock)) => {
            let parsed = crate::Manifest::parse(manifest);
            let parsed_lock = crate::Lockfile::parse(&lock);
            match (parsed, parsed_lock) {
                (Ok(manifest), Ok(lock)) => {
                    scan.reachable
                        .extend(crate::projects::references(paths, &manifest, &lock)?);
                }
                (Err(error), _) | (_, Err(error)) => {
                    scan.retain_all = true;
                    scan.findings.push(observation(
                        "global-state-invalid",
                        [("message", error.to_string())],
                    ));
                }
            }
            Ok(())
        }
        _ => {
            scan.retain_all = true;
            scan.findings.push(observation("global-state-partial", []));
            Ok(())
        }
    }
}

fn scan_candidates(paths: &Paths, scan: &mut ReachabilityScan) -> Result<()> {
    let root = paths.grimoire_home.join("candidates");
    for (relative, path) in two_level_files(&root, "candidate", scan)? {
        let Some((scope_key, file)) = relative.split_once('/') else {
            uncertain(scan, "candidate-invalid", relative);
            continue;
        };
        let alias = file.strip_suffix(".json");
        if (scope_key != "global" && !is_key(scope_key))
            || alias
                .and_then(|alias| crate::SourceAlias::new(alias).ok())
                .is_none()
        {
            uncertain(scan, "candidate-invalid", relative);
            continue;
        }
        let bytes = match read_required_bounded(&path) {
            Ok(bytes) => bytes,
            Err(error) => {
                uncertain(scan, "candidate-invalid", error.to_string());
                continue;
            }
        };
        scan.record_bytes(&format!("candidate:{relative}"), Some(&bytes));
        match crate::CandidateRecord::parse(&bytes, None) {
            Ok(candidate) if candidate.identity.kind() == crate::SourceKind::Git => {
                if let Ok(Some(snapshot_key)) = candidate.snapshot_key() {
                    scan.reachable.insert(ProjectReference {
                        source_key: candidate.source_key(),
                        snapshot_key,
                    });
                } else {
                    uncertain(scan, "candidate-invalid", relative);
                }
            }
            Ok(_) => {}
            Err(error) => uncertain(scan, "candidate-invalid", error.to_string()),
        }
    }
    Ok(())
}

fn scan_journals(paths: &Paths, scan: &mut ReachabilityScan) -> Result<()> {
    let root = paths.grimoire_home.join("transactions");
    if !directory_or_absent(&root) {
        uncertain(
            scan,
            "scope-journal-invalid",
            "transaction root is not a plain directory".into(),
        );
        return Ok(());
    }
    let entries = read_dir_optional(&root)?;
    for entry in entries {
        let name = entry.file_name();
        if name == "store-repair" {
            continue;
        }
        if !plain_directory(&entry.path()) {
            uncertain(
                scan,
                "scope-journal-invalid",
                "scope journal namespace is not a plain directory".into(),
            );
            continue;
        }
        let Some(scope_key) = name.to_str() else {
            uncertain(scan, "scope-journal-invalid", "non-UTF-8 scope key".into());
            continue;
        };
        if scope_key != "global" && !is_key(scope_key) {
            uncertain(scan, "scope-journal-invalid", scope_key.into());
            continue;
        }
        let journal_path = entry.path().join("journal.json");
        let Some(bytes) = read_optional_bounded(&journal_path)? else {
            continue;
        };
        scan.record_bytes(&format!("journal:{scope_key}"), Some(&bytes));
        match Journal::from_bytes(&bytes) {
            Ok(journal) => {
                for state in journal.state {
                    if state.name != StateName::Candidate {
                        continue;
                    }
                    for bytes in [state.before, state.after].into_iter().flatten() {
                        if let Ok(candidate) = crate::CandidateRecord::parse(&bytes, None) {
                            if let Ok(Some(snapshot_key)) = candidate.snapshot_key() {
                                scan.reachable.insert(ProjectReference {
                                    source_key: candidate.source_key(),
                                    snapshot_key,
                                });
                            }
                        }
                    }
                }
                for link in journal.links {
                    for raw in [link.before, link.after].into_iter().flatten() {
                        if let Some(reference) = reference_from_store_path(paths, &raw) {
                            scan.reachable.insert(reference);
                        }
                    }
                }
            }
            Err(error) => uncertain(scan, "scope-journal-invalid", error.to_string()),
        }
    }
    let repairs = paths.grimoire_home.join("transactions/store-repair");
    for (relative, path) in two_level_files(&repairs, "store-repair", scan)? {
        let Some((source, file)) = relative.split_once('/') else {
            uncertain(scan, "store-repair-invalid", relative);
            continue;
        };
        let Some(snapshot) = file.strip_suffix(".json") else {
            uncertain(scan, "store-repair-invalid", relative);
            continue;
        };
        match (
            crate::SourceKey::parse(source.to_owned()),
            crate::SnapshotKey::parse(snapshot.to_owned()),
        ) {
            (Ok(source_key), Ok(snapshot_key)) => {
                scan.reachable.insert(ProjectReference {
                    source_key,
                    snapshot_key,
                });
                let bytes = read_required_bounded(&path)?;
                scan.record_bytes(&format!("store-repair:{relative}"), Some(&bytes));
            }
            _ => uncertain(scan, "store-repair-invalid", relative),
        }
    }
    Ok(())
}

fn scan_store(paths: &Paths, scan: &mut ReachabilityScan) -> Result<()> {
    let root = paths.grimoire_home.join("store/checkouts");
    if !directory_or_absent(&root) {
        uncertain(
            scan,
            "store-entry-invalid",
            "store root is not a plain directory".into(),
        );
        return Ok(());
    }
    for source in read_dir_optional(&root)? {
        let Some(source_name) = source.file_name().to_str().map(str::to_owned) else {
            uncertain(scan, "store-entry-invalid", "non-UTF-8 source key".into());
            continue;
        };
        let source_key = match crate::SourceKey::parse(source_name.clone()) {
            Ok(key) if plain_directory(&source.path()) => key,
            _ => {
                uncertain(scan, "store-entry-invalid", source_name);
                continue;
            }
        };
        for snapshot in read_dir_optional(&source.path())? {
            let Some(snapshot_name) = snapshot.file_name().to_str().map(str::to_owned) else {
                uncertain(scan, "store-entry-invalid", "non-UTF-8 snapshot key".into());
                continue;
            };
            let snapshot_key = match crate::SnapshotKey::parse(snapshot_name.clone()) {
                Ok(key) if plain_directory(&snapshot.path()) => key,
                _ => {
                    uncertain(scan, "store-entry-invalid", snapshot_name);
                    continue;
                }
            };
            let reference = ProjectReference {
                source_key: source_key.clone(),
                snapshot_key,
            };
            scan.snapshots.insert(reference.clone());
            match HeldDirectoryReader::open(&snapshot.path()).and_then(|reader| {
                let inventory = scan_inventory(&reader)
                    .map_err(|error| CoreError::Source(error.to_string()))?;
                reader.revalidate()?;
                Ok(inventory)
            }) {
                Ok(inventory) if inventory.is_valid() => scan.record_text(
                    &format!("store:{}/{}", reference.source_key, reference.snapshot_key),
                    &inventory.inventory_digest.to_string(),
                ),
                Ok(_) => {
                    scan.reachable.insert(reference);
                    scan.findings
                        .push(observation("store-snapshot-invalid", []));
                }
                Err(error) => {
                    scan.reachable.insert(reference);
                    scan.findings.push(observation(
                        "store-snapshot-invalid",
                        [("message", error.to_string())],
                    ));
                }
            }
        }
    }
    Ok(())
}

fn two_level_files(
    root: &Path,
    kind: &str,
    scan: &mut ReachabilityScan,
) -> Result<Vec<(String, PathBuf)>> {
    let mut files = Vec::new();
    if !directory_or_absent(root) {
        uncertain(
            scan,
            &format!("{kind}-invalid"),
            "namespace root is not a plain directory".into(),
        );
        return Ok(files);
    }
    for first in read_dir_optional(root)? {
        let Some(first_name) = first.file_name().to_str().map(str::to_owned) else {
            uncertain(
                scan,
                &format!("{kind}-invalid"),
                "non-UTF-8 namespace".into(),
            );
            continue;
        };
        if !plain_directory(&first.path()) {
            uncertain(scan, &format!("{kind}-invalid"), first_name);
            continue;
        }
        for second in read_dir_optional(&first.path())? {
            let Some(second_name) = second.file_name().to_str().map(str::to_owned) else {
                uncertain(scan, &format!("{kind}-invalid"), "non-UTF-8 entry".into());
                continue;
            };
            if !plain_file(&second.path()) {
                uncertain(scan, &format!("{kind}-invalid"), second_name);
                continue;
            }
            files.push((format!("{first_name}/{second_name}"), second.path()));
            if files.len() > ENTRY_LIMIT {
                return Err(CoreError::Request(format!("{kind} entry limit exceeded")));
            }
        }
    }
    files.sort_by(|left, right| left.0.cmp(&right.0));
    Ok(files)
}

fn reference_from_store_path(paths: &Paths, raw: &[u8]) -> Option<ProjectReference> {
    #[cfg(unix)]
    let path = {
        use std::os::unix::ffi::OsStrExt;
        PathBuf::from(std::ffi::OsStr::from_bytes(raw))
    };
    #[cfg(not(unix))]
    let path = PathBuf::from(std::str::from_utf8(raw).ok()?);
    let relative = path
        .strip_prefix(paths.grimoire_home.join("store/checkouts"))
        .ok()?
        .components()
        .collect::<Vec<_>>();
    let [source, snapshot, ..] = relative.as_slice() else {
        return None;
    };
    Some(ProjectReference {
        source_key: crate::SourceKey::parse(source.as_os_str().to_str()?.to_owned()).ok()?,
        snapshot_key: crate::SnapshotKey::parse(snapshot.as_os_str().to_str()?.to_owned()).ok()?,
    })
}

fn remove_tree(path: &Path, depth: usize, budget: &mut usize) -> Result<()> {
    if depth > 64 {
        return Err(CoreError::Transaction("prune depth limit exceeded".into()));
    }
    let mut entries = fs::read_dir(path)
        .map_err(|error| crate::transaction::io_error(path, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| crate::transaction::io_error(path, error))?;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        if *budget == 0 {
            return Err(CoreError::Transaction("prune entry limit exceeded".into()));
        }
        *budget -= 1;
        let child = entry.path();
        let metadata = fs::symlink_metadata(&child)
            .map_err(|error| crate::transaction::io_error(&child, error))?;
        if metadata.is_dir() && !metadata.file_type().is_symlink() {
            remove_tree(&child, depth + 1, budget)?;
        } else {
            fs::remove_file(&child).map_err(|error| crate::transaction::io_error(&child, error))?;
        }
    }
    fs::remove_dir(path).map_err(|error| crate::transaction::io_error(path, error))
}

fn read_optional_bounded(path: &Path) -> Result<Option<Vec<u8>>> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(crate::transaction::io_error(path, error)),
    };
    if !metadata.is_file() || metadata.file_type().is_symlink() || metadata.len() > STATE_LIMIT {
        return Err(CoreError::Request(format!(
            "state is not a bounded regular file: {}",
            path.display()
        )));
    }
    fs::read(path)
        .map(Some)
        .map_err(|error| crate::transaction::io_error(path, error))
}

fn read_required_bounded(path: &Path) -> Result<Vec<u8>> {
    read_optional_bounded(path)?.ok_or_else(|| CoreError::Io {
        path: path.display().to_string(),
        message: "not found".into(),
    })
}

fn read_dir_optional(path: &Path) -> Result<Vec<fs::DirEntry>> {
    match fs::read_dir(path) {
        Ok(entries) => entries
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(|error| crate::transaction::io_error(path, error)),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(Vec::new()),
        Err(error) => Err(crate::transaction::io_error(path, error)),
    }
}

fn plain_directory(path: &Path) -> bool {
    fs::symlink_metadata(path)
        .is_ok_and(|metadata| metadata.is_dir() && !metadata.file_type().is_symlink())
}

fn plain_file(path: &Path) -> bool {
    fs::symlink_metadata(path)
        .is_ok_and(|metadata| metadata.is_file() && !metadata.file_type().is_symlink())
}

fn directory_or_absent(path: &Path) -> bool {
    match fs::symlink_metadata(path) {
        Ok(metadata) => metadata.is_dir() && !metadata.file_type().is_symlink(),
        Err(error) => error.kind() == std::io::ErrorKind::NotFound,
    }
}

fn is_key(value: &str) -> bool {
    value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn uncertain(scan: &mut ReachabilityScan, code: &str, message: String) {
    scan.retain_all = true;
    scan.findings
        .push(observation(code, [("message", message)]));
}

fn observation<const N: usize>(code: &str, details: [(&str, String); N]) -> WorldObservation {
    WorldObservation {
        code: code.into(),
        details: details
            .into_iter()
            .map(|(key, value)| (key.into(), value))
            .collect(),
    }
}

#[derive(Default)]
struct ReachabilityScan {
    entries: Vec<(String, String)>,
    snapshots: BTreeSet<ProjectReference>,
    reachable: BTreeSet<ProjectReference>,
    findings: Vec<WorldObservation>,
    retain_all: bool,
}

impl ReachabilityScan {
    fn record_bytes(&mut self, name: &str, bytes: Option<&[u8]>) {
        self.entries.push((
            name.into(),
            bytes.map_or_else(
                || "absent".into(),
                |bytes| ByteHash::of(bytes).as_str().into(),
            ),
        ));
    }

    fn record_text(&mut self, name: &str, value: &str) {
        self.entries.push((name.into(), value.into()));
    }
}
