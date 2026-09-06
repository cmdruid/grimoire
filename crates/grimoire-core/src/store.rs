mod repair;

use std::collections::BTreeSet;
use std::fs::{self, File, OpenOptions};
use std::io;
use std::path::{Path, PathBuf};

use grimoire_pack::inventory::{SourcePath, SymlinkSafety};
use sha2::{Digest as _, Sha256};

use crate::locks::{LockCoordinator, LockMode, LockRank};
use crate::source::{ReviewExport, ReviewPayload, SnapshotKey, SourceKey};
use crate::{Action, CoreError, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum StoreObservation {
    Absent,
    Valid,
    Corrupt,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MaterializationIntent {
    source_key: SourceKey,
    snapshot_key: SnapshotKey,
    export: ReviewExport,
}

impl MaterializationIntent {
    pub(crate) fn new(
        source_key: SourceKey,
        snapshot_key: SnapshotKey,
        export: ReviewExport,
    ) -> Self {
        Self {
            source_key,
            snapshot_key,
            export,
        }
    }

    pub(crate) fn from_action(action: &Action, export: ReviewExport) -> Result<Self> {
        let Action::PrepareSnapshot {
            source_key,
            snapshot_key,
            review_key,
            ..
        } = action
        else {
            return Err(CoreError::Store(
                "only a planned materialization action creates an intent".into(),
            ));
        };
        let source_key = SourceKey::parse(source_key.clone())?;
        let snapshot_key = SnapshotKey::parse(snapshot_key.clone())?;
        let review_key = crate::ReviewKey::parse(review_key.clone())?;
        if export.source_key != source_key || export.review_key != review_key {
            return Err(CoreError::Store(
                "materialization action and review export identity mismatch".into(),
            ));
        }
        Ok(Self::new(source_key, snapshot_key, export))
    }
}

pub(crate) fn observe(path: &Path, export: &ReviewExport) -> StoreObservation {
    if !path.exists() {
        StoreObservation::Absent
    } else if verify(path, export).is_ok() {
        StoreObservation::Valid
    } else {
        StoreObservation::Corrupt
    }
}

pub(crate) fn materialize(store_root: &Path, intent: &MaterializationIntent) -> Result<PathBuf> {
    let home = store_root
        .parent()
        .and_then(Path::parent)
        .ok_or_else(|| CoreError::Store("store root is not below a Grimoire home".into()))?;
    let mut locks = LockCoordinator::new();
    locks.acquire(
        &home.join("locks/store.lock"),
        LockRank::Store,
        LockMode::Exclusive,
    )?;
    let source_root = store_root.join(intent.source_key.as_str());
    let destination = source_root.join(intent.snapshot_key.as_str());
    match observe(&destination, &intent.export) {
        StoreObservation::Valid => return Ok(destination),
        StoreObservation::Corrupt => {
            return Err(CoreError::Store(
                "corrupt store entry requires repair custody".into(),
            ))
        }
        StoreObservation::Absent => {}
    }
    fs::create_dir_all(&source_root).map_err(|error| io_error(&source_root, error))?;
    let temporary = assemble_unique(&source_root, &intent.snapshot_key, &intent.export)?;
    fs::rename(&temporary, &destination).map_err(|error| io_error(&destination, error))?;
    sync_directory(&source_root)?;
    Ok(destination)
}

fn assemble_unique(
    parent: &Path,
    snapshot: &SnapshotKey,
    export: &ReviewExport,
) -> Result<PathBuf> {
    for nonce in 0..100u32 {
        let temporary = parent.join(format!(
            ".{snapshot}.materialize-{}-{nonce}",
            std::process::id()
        ));
        match fs::create_dir(&temporary) {
            Ok(()) => {
                if let Err(error) = assemble_contents(&temporary, export) {
                    let _ = remove_directory_if_present(&temporary);
                    return Err(error);
                }
                return Ok(temporary);
            }
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(io_error(&temporary, error)),
        }
    }
    Err(CoreError::Store(
        "cannot allocate materialization temporary directory".into(),
    ))
}

fn assemble(temporary: &Path, export: &ReviewExport) -> Result<()> {
    fs::create_dir(temporary).map_err(|error| io_error(temporary, error))?;
    assemble_contents(temporary, export)
}

fn assemble_contents(temporary: &Path, export: &ReviewExport) -> Result<()> {
    let mut directories = vec![temporary.to_path_buf()];
    for entry in &export.entries {
        if matches!(entry.payload, ReviewPayload::Submodule { .. }) {
            continue;
        }
        validate_relative(&entry.path)?;
        let target = join_raw(temporary, &entry.path)?;
        if let Some(parent) = target.parent() {
            create_parents(parent, temporary, &mut directories)?;
        }
        match &entry.payload {
            ReviewPayload::File { size, digest } => {
                let object = export.object_path(digest)?;
                copy_verified(&object, &target, *size, digest)?;
                let mode = if entry.mode == "100755" { 0o555 } else { 0o444 };
                set_mode(&target, mode)?;
            }
            ReviewPayload::Symlink { target: link } => {
                if entry.safety != Some(SymlinkSafety::Internal) {
                    return Err(CoreError::Store(
                        "only safe internal links may materialize".into(),
                    ));
                }
                create_symlink(link, &target)?;
            }
            ReviewPayload::Submodule { .. } => unreachable!(),
        }
    }
    directories.sort_by_key(|path| std::cmp::Reverse(path.components().count()));
    for directory in directories {
        set_mode(&directory, 0o555)?;
    }
    verify(temporary, export)
}

pub(crate) fn repair(home: &Path, intent: &MaterializationIntent, nonce: &str) -> Result<PathBuf> {
    let journal_path = home
        .join("transactions/store-repair")
        .join(intent.source_key.as_str())
        .join(format!("{}.json", intent.snapshot_key));
    if journal_path.exists() {
        recover_repair(home, intent, &journal_path)?;
    }

    let journal = repair::RepairJournal::new(&intent.source_key, &intent.snapshot_key, nonce);
    let (fixed, _quarantine, replacement) =
        journal.validate(home, &intent.source_key, &intent.snapshot_key)?;
    if replacement.exists() {
        remove_directory_if_present(&replacement)?;
    }
    if let Some(parent) = replacement.parent() {
        fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
    }
    assemble(&replacement, &intent.export)?;

    let mut locks = LockCoordinator::new();
    locks.acquire(
        &home.join("locks/store.lock"),
        LockRank::Store,
        LockMode::Exclusive,
    )?;
    if journal_path.exists() {
        recover_repair_locked(home, intent, &journal_path)?;
    }
    if observe(&fixed, &intent.export) == StoreObservation::Valid {
        remove_directory_if_present(&replacement)?;
        return Ok(fixed);
    }

    let journal_parent = journal_path
        .parent()
        .ok_or_else(|| CoreError::Store("repair journal has no parent".into()))?;
    fs::create_dir_all(journal_parent).map_err(|error| io_error(journal_parent, error))?;
    write_new(&journal_path, &journal.to_bytes()?)?;
    sync_directory(journal_parent)?;
    let (_, quarantine, replacement) =
        journal.validate(home, &intent.source_key, &intent.snapshot_key)?;
    if quarantine.exists() {
        remove_directory_if_present(&quarantine)?;
    }
    if fixed.exists() {
        fs::rename(&fixed, &quarantine).map_err(|error| io_error(&quarantine, error))?;
    }
    if let Err(error) = fs::rename(&replacement, &fixed) {
        if quarantine.exists() && !fixed.exists() {
            fs::rename(&quarantine, &fixed).map_err(|restore| io_error(&fixed, restore))?;
        }
        return Err(io_error(&fixed, error));
    }
    let store_parent = fixed
        .parent()
        .ok_or_else(|| CoreError::Store("store entry has no parent".into()))?;
    sync_directory(store_parent)?;
    verify(&fixed, &intent.export)?;
    if quarantine.exists() {
        remove_directory_if_present(&quarantine)?;
    }
    fs::remove_file(&journal_path).map_err(|error| io_error(&journal_path, error))?;
    sync_directory(store_parent)?;
    sync_directory(journal_parent)?;
    Ok(fixed)
}

pub(crate) fn recover_repair(
    home: &Path,
    intent: &MaterializationIntent,
    journal_path: &Path,
) -> Result<()> {
    let mut locks = LockCoordinator::new();
    locks.acquire(
        &home.join("locks/store.lock"),
        LockRank::Store,
        LockMode::Exclusive,
    )?;
    recover_repair_locked(home, intent, journal_path)
}

fn recover_repair_locked(
    home: &Path,
    intent: &MaterializationIntent,
    journal_path: &Path,
) -> Result<()> {
    let bytes = fs::read(journal_path).map_err(|error| io_error(journal_path, error))?;
    let journal = repair::RepairJournal::from_bytes(&bytes)?;
    let (fixed, quarantine, replacement) =
        journal.validate(home, &intent.source_key, &intent.snapshot_key)?;
    let fixed_valid = observe(&fixed, &intent.export) == StoreObservation::Valid;
    let replacement_valid = observe(&replacement, &intent.export) == StoreObservation::Valid;

    if fixed_valid {
        remove_directory_if_present(&quarantine)?;
        remove_directory_if_present(&replacement)?;
    } else if replacement_valid {
        if fixed.exists() {
            if quarantine.exists() {
                remove_directory_if_present(&fixed)?;
            } else {
                fs::rename(&fixed, &quarantine).map_err(|error| io_error(&quarantine, error))?;
            }
        }
        fs::rename(&replacement, &fixed).map_err(|error| io_error(&fixed, error))?;
        verify(&fixed, &intent.export)?;
        remove_directory_if_present(&quarantine)?;
    } else if quarantine.exists() {
        remove_directory_if_present(&fixed)?;
        fs::rename(&quarantine, &fixed).map_err(|error| io_error(&fixed, error))?;
        remove_directory_if_present(&replacement)?;
    } else {
        remove_directory_if_present(&replacement)?;
    }

    if let Some(parent) = fixed.parent() {
        sync_directory(parent)?;
    }
    fs::remove_file(journal_path).map_err(|error| io_error(journal_path, error))?;
    if let Some(parent) = journal_path.parent() {
        sync_directory(parent)?;
    }
    Ok(())
}

fn write_new(path: &Path, bytes: &[u8]) -> Result<()> {
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(|error| io_error(path, error))?;
    use std::io::Write as _;
    file.write_all(bytes)
        .map_err(|error| io_error(path, error))?;
    file.sync_all().map_err(|error| io_error(path, error))
}

fn remove_directory_if_present(path: &Path) -> Result<()> {
    if path.exists() {
        make_tree_removable(path)?;
    }
    match fs::remove_dir_all(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(io_error(path, error)),
    }
}

fn make_tree_removable(path: &Path) -> Result<()> {
    let metadata = fs::symlink_metadata(path).map_err(|error| io_error(path, error))?;
    if !metadata.is_dir() {
        return Ok(());
    }
    set_mode(path, 0o700)?;
    for entry in fs::read_dir(path)
        .map_err(|error| io_error(path, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| io_error(path, error))?
    {
        let child = entry.path();
        if fs::symlink_metadata(&child)
            .map_err(|error| io_error(&child, error))?
            .is_dir()
        {
            make_tree_removable(&child)?;
        }
    }
    Ok(())
}

fn sync_directory(path: &Path) -> Result<()> {
    File::open(path)
        .and_then(|file| file.sync_all())
        .map_err(|error| io_error(path, error))
}

fn verify(root: &Path, export: &ReviewExport) -> Result<()> {
    let root_metadata = fs::symlink_metadata(root).map_err(|error| io_error(root, error))?;
    if !root_metadata.is_dir() || permission_mode(&root_metadata) != 0o555 {
        return Err(CoreError::Store("store root mode mismatch".into()));
    }
    let expected = expected_paths(export)?;
    let mut actual = BTreeSet::new();
    collect_paths(root, root, &mut actual)?;
    if actual != expected {
        return Err(CoreError::Store("store entry set mismatch".into()));
    }
    for entry in &export.entries {
        if matches!(entry.payload, ReviewPayload::Submodule { .. }) {
            continue;
        }
        validate_relative(&entry.path)?;
        let path = join_raw(root, &entry.path)?;
        let metadata = fs::symlink_metadata(&path).map_err(|error| io_error(&path, error))?;
        match &entry.payload {
            ReviewPayload::File { size, digest } => {
                let expected_mode = if entry.mode == "100755" { 0o555 } else { 0o444 };
                if !metadata.file_type().is_file() || permission_mode(&metadata) != expected_mode {
                    return Err(CoreError::Store("store file mode mismatch".into()));
                }
                verify_file(&path, *size, digest)?;
            }
            ReviewPayload::Symlink { target } => {
                if !metadata.file_type().is_symlink()
                    || fs::read_link(&path)
                        .map_err(|error| io_error(&path, error))?
                        .as_os_str()
                        .as_encoded_bytes()
                        != target
                {
                    return Err(CoreError::Store("store link mismatch".into()));
                }
            }
            ReviewPayload::Submodule { .. } => unreachable!(),
        }
    }
    Ok(())
}

fn expected_paths(export: &ReviewExport) -> Result<BTreeSet<SourcePath>> {
    let mut paths = BTreeSet::new();
    for entry in &export.entries {
        if matches!(entry.payload, ReviewPayload::Submodule { .. }) {
            continue;
        }
        validate_relative(&entry.path)?;
        let mut parent = Vec::new();
        let parts: Vec<_> = entry.path.as_bytes().split(|byte| *byte == b'/').collect();
        for part in &parts[..parts.len().saturating_sub(1)] {
            if !parent.is_empty() {
                parent.push(b'/');
            }
            parent.extend_from_slice(part);
            paths.insert(SourcePath::new(parent.clone()));
        }
        paths.insert(entry.path.clone());
    }
    Ok(paths)
}

#[cfg(unix)]
fn collect_paths(root: &Path, directory: &Path, paths: &mut BTreeSet<SourcePath>) -> Result<()> {
    use std::os::unix::ffi::OsStrExt;

    let mut entries = fs::read_dir(directory)
        .map_err(|error| io_error(directory, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| io_error(directory, error))?;
    entries.sort_by(|left, right| {
        left.file_name()
            .as_bytes()
            .cmp(right.file_name().as_bytes())
    });
    for entry in entries {
        let path = entry.path();
        let metadata = fs::symlink_metadata(&path).map_err(|error| io_error(&path, error))?;
        let relative = path
            .strip_prefix(root)
            .map_err(|_| CoreError::Store("store entry escaped root".into()))?;
        let source_path = SourcePath::new(relative.as_os_str().as_bytes().to_vec());
        paths.insert(source_path);
        if metadata.is_dir() {
            if permission_mode(&metadata) != 0o555 {
                return Err(CoreError::Store("store directory mode mismatch".into()));
            }
            collect_paths(root, &path, paths)?;
        } else if !metadata.file_type().is_file() && !metadata.file_type().is_symlink() {
            return Err(CoreError::Store("unsupported store entry kind".into()));
        }
    }
    Ok(())
}

fn copy_verified(source: &Path, destination: &Path, size: u64, digest: &str) -> Result<()> {
    let mut input = File::open(source).map_err(|error| io_error(source, error))?;
    let mut output = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(destination)
        .map_err(|error| io_error(destination, error))?;
    let copied = io::copy(&mut input, &mut output).map_err(|error| io_error(destination, error))?;
    output
        .sync_all()
        .map_err(|error| io_error(destination, error))?;
    if copied != size {
        return Err(CoreError::Store("review object size changed".into()));
    }
    verify_file(destination, size, digest)
}

fn verify_file(path: &Path, size: u64, expected: &str) -> Result<()> {
    let mut file = File::open(path).map_err(|error| io_error(path, error))?;
    let mut digest = Sha256::new();
    let copied = io::copy(&mut file, &mut digest).map_err(|error| io_error(path, error))?;
    if copied == size && format!("sha256:{:x}", digest.finalize()) == expected {
        Ok(())
    } else {
        Err(CoreError::Store("store object digest mismatch".into()))
    }
}

fn validate_relative(path: &SourcePath) -> Result<()> {
    let bytes = path.as_bytes();
    if bytes.is_empty()
        || bytes.starts_with(b"/")
        || bytes
            .split(|byte| *byte == b'/')
            .any(|part| part.is_empty() || matches!(part, b"." | b".."))
    {
        Err(CoreError::Store("unsafe store path".into()))
    } else {
        Ok(())
    }
}

#[cfg(unix)]
fn join_raw(root: &Path, path: &SourcePath) -> Result<PathBuf> {
    use std::os::unix::ffi::OsStrExt;
    Ok(root.join(std::ffi::OsStr::from_bytes(path.as_bytes())))
}

fn create_parents(path: &Path, root: &Path, directories: &mut Vec<PathBuf>) -> Result<()> {
    let relative = path
        .strip_prefix(root)
        .map_err(|_| CoreError::Store("parent escaped store root".into()))?;
    let mut current = root.to_path_buf();
    for component in relative.components() {
        current.push(component);
        if !current.exists() {
            fs::create_dir(&current).map_err(|error| io_error(&current, error))?;
            directories.push(current.clone());
        }
    }
    Ok(())
}

#[cfg(unix)]
fn create_symlink(target: &[u8], destination: &Path) -> Result<()> {
    use std::os::unix::ffi::OsStrExt;
    std::os::unix::fs::symlink(std::ffi::OsStr::from_bytes(target), destination)
        .map_err(|error| io_error(destination, error))
}

#[cfg(unix)]
fn set_mode(path: &Path, mode: u32) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(mode))
        .map_err(|error| io_error(path, error))
}

#[cfg(unix)]
fn permission_mode(metadata: &fs::Metadata) -> u32 {
    use std::os::unix::fs::PermissionsExt;
    metadata.permissions().mode() & 0o777
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use std::fs;

    use grimoire_pack::inventory::{Boundary, SourcePath, SymlinkSafety};
    use sha2::{Digest as _, Sha256};
    use tempfile::tempdir;

    use super::*;
    use crate::source::{CanonicalIdentity, ReviewEntry, ReviewKey, SourceKind};

    fn fixture() -> (tempfile::TempDir, MaterializationIntent) {
        let temporary = tempdir().unwrap();
        let review_root = temporary.path().join("review");
        let objects = review_root.join("objects");
        fs::create_dir_all(&objects).unwrap();
        let contents = b"fixture\n";
        let digest = format!("sha256:{:x}", Sha256::digest(contents));
        let object = objects.join(digest.strip_prefix("sha256:").unwrap());
        fs::write(&object, contents).unwrap();
        set_mode(&object, 0o444).unwrap();

        let identity = CanonicalIdentity::remote("github:org/repo").unwrap();
        let source_key = SourceKey::derive(&identity);
        let snapshot_key = SnapshotKey::derive(
            SourceKind::Git,
            &"1".repeat(40),
            &"2".repeat(40),
            &format!("sha256:{}", "3".repeat(64)),
        )
        .unwrap();
        let review_tree = format!("sha256:{}", "4".repeat(64));
        let review_key = ReviewKey::derive(
            SourceKind::Git,
            Some(&"1".repeat(40)),
            Some(&"2".repeat(40)),
            &format!("sha256:{}", "3".repeat(64)),
            &review_tree,
        )
        .unwrap();
        let export = ReviewExport {
            root: review_root,
            source_key: source_key.clone(),
            review_key,
            review_tree,
            facts: crate::source::ReviewFacts::default(),
            entries: vec![
                ReviewEntry {
                    path: SourcePath::from("skills/one/SKILL.md"),
                    mode: "100755".into(),
                    boundary: Boundary::Skill(SourcePath::from("skills/one")),
                    payload: ReviewPayload::File {
                        size: contents.len() as u64,
                        digest,
                    },
                    safety: None,
                    reason: None,
                },
                ReviewEntry {
                    path: SourcePath::from("skills/one/current"),
                    mode: "120000".into(),
                    boundary: Boundary::Skill(SourcePath::from("skills/one")),
                    payload: ReviewPayload::Symlink {
                        target: b"SKILL.md".to_vec(),
                    },
                    safety: Some(SymlinkSafety::Internal),
                    reason: None,
                },
            ],
        };
        (
            temporary,
            MaterializationIntent::new(source_key, snapshot_key, export),
        )
    }

    #[test]
    fn materialization_is_exact_read_only_and_tamper_evident() {
        let (temporary, intent) = fixture();
        let store = temporary.path().join("home/store/checkouts");
        let destination = materialize(&store, &intent).unwrap();
        assert_eq!(
            fs::read(destination.join("skills/one/SKILL.md")).unwrap(),
            b"fixture\n"
        );
        assert_eq!(
            fs::read_link(destination.join("skills/one/current")).unwrap(),
            PathBuf::from("SKILL.md")
        );
        assert_eq!(
            observe(&destination, &intent.export),
            StoreObservation::Valid
        );

        set_mode(&destination.join("skills/one/SKILL.md"), 0o644).unwrap();
        assert_eq!(
            observe(&destination, &intent.export),
            StoreObservation::Corrupt
        );
    }

    #[test]
    fn repair_journal_paths_are_derived_and_contained() {
        let (temporary, intent) = fixture();
        let journal = repair::RepairJournal::new(&intent.source_key, &intent.snapshot_key, "nonce");
        let (fixed, quarantine, replacement) = journal
            .validate(temporary.path(), &intent.source_key, &intent.snapshot_key)
            .unwrap();
        for path in [fixed, quarantine, replacement] {
            assert!(path.starts_with(temporary.path()));
        }

        let mut tampered: serde_json::Value =
            serde_json::from_slice(&journal.to_bytes().unwrap()).unwrap();
        tampered["fixed"] = serde_json::Value::String("../../outside".into());
        let tampered: repair::RepairJournal = serde_json::from_value(tampered).unwrap();
        assert!(tampered
            .validate(temporary.path(), &intent.source_key, &intent.snapshot_key,)
            .is_err());
    }

    #[test]
    fn only_a_key_exact_plan_action_can_create_a_materialization_intent() {
        let (_temporary, intent) = fixture();
        let action = Action::PrepareSnapshot {
            scope: crate::Scope::Project,
            source: crate::SourceAlias::new("repo").unwrap(),
            source_key: intent.source_key.to_string(),
            snapshot_key: intent.snapshot_key.to_string(),
            review_key: intent.export.review_key.to_string(),
            operation: crate::SnapshotPreparation::Materialize,
        };
        assert_eq!(
            MaterializationIntent::from_action(&action, intent.export.clone()).unwrap(),
            intent
        );
        let mut wrong = action;
        if let Action::PrepareSnapshot { review_key, .. } = &mut wrong {
            *review_key = "0".repeat(64);
        }
        assert!(MaterializationIntent::from_action(&wrong, intent.export).is_err());
    }

    #[test]
    fn corrupt_snapshot_is_replaced_through_the_repair_journal() {
        let (temporary, intent) = fixture();
        let home = temporary.path().canonicalize().unwrap().join("home");
        let destination = materialize(&home.join("store/checkouts"), &intent).unwrap();
        set_mode(&destination.join("skills/one/SKILL.md"), 0o644).unwrap();
        assert_eq!(
            observe(&destination, &intent.export),
            StoreObservation::Corrupt
        );
        let repaired = repair(&home, &intent, "test").unwrap();
        assert_eq!(repaired, destination);
        assert_eq!(observe(&repaired, &intent.export), StoreObservation::Valid);
        assert!(!home
            .join("transactions/store-repair")
            .join(intent.source_key.as_str())
            .join(format!("{}.json", intent.snapshot_key))
            .exists());
    }

    #[test]
    fn repair_recovery_handles_every_durable_swap_state_without_mixed_bytes() {
        for stage in [
            "journaled",
            "quarantined",
            "replacement-installed",
            "replacement-lost",
        ] {
            let (temporary, intent) = fixture();
            let home = temporary.path().canonicalize().unwrap().join(stage);
            let fixed = materialize(&home.join("store/checkouts"), &intent).unwrap();
            let file = fixed.join("skills/one/SKILL.md");
            set_mode(&file, 0o644).unwrap();
            fs::write(&file, b"original-corrupt\n").unwrap();

            let journal =
                repair::RepairJournal::new(&intent.source_key, &intent.snapshot_key, stage);
            let (_, quarantine, replacement) = journal
                .validate(&home, &intent.source_key, &intent.snapshot_key)
                .unwrap();
            if let Some(parent) = replacement.parent() {
                fs::create_dir_all(parent).unwrap();
            }
            assemble(&replacement, &intent.export).unwrap();
            let journal_path = home
                .join("transactions/store-repair")
                .join(intent.source_key.as_str())
                .join(format!("{}.json", intent.snapshot_key));
            fs::create_dir_all(journal_path.parent().unwrap()).unwrap();
            write_new(&journal_path, &journal.to_bytes().unwrap()).unwrap();

            match stage {
                "journaled" => {}
                "quarantined" => fs::rename(&fixed, &quarantine).unwrap(),
                "replacement-installed" => {
                    fs::rename(&fixed, &quarantine).unwrap();
                    fs::rename(&replacement, &fixed).unwrap();
                }
                "replacement-lost" => {
                    fs::rename(&fixed, &quarantine).unwrap();
                    remove_directory_if_present(&replacement).unwrap();
                }
                _ => unreachable!(),
            }

            recover_repair(&home, &intent, &journal_path).unwrap();
            assert!(!journal_path.exists(), "journal remained at {stage}");
            assert!(!quarantine.exists(), "quarantine remained at {stage}");
            assert!(!replacement.exists(), "replacement remained at {stage}");
            if stage == "replacement-lost" {
                assert_eq!(
                    fs::read(fixed.join("skills/one/SKILL.md")).unwrap(),
                    b"original-corrupt\n"
                );
                assert_eq!(observe(&fixed, &intent.export), StoreObservation::Corrupt);
            } else {
                assert_eq!(observe(&fixed, &intent.export), StoreObservation::Valid);
            }
        }
    }
}
