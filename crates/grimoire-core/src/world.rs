use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use grimoire_pack::inventory::{compute_review_tree_digest, scan, Digest, SourceInventory};

use crate::locks::{LockCoordinator, LockMode, LockRank};
use crate::source::{
    inspect_pinned_git, GitRunner, GitSnapshot, GitTreeReader, HeldDirectoryReader, ReviewExport,
};
use crate::{
    CandidateRecord, CanonicalIdentity, CoreError, InstalledLink, LockSource, Manifest,
    ManifestSource, Paths, Result, Scope, ScopePaths, SnapshotId, SnapshotKey, SnapshotKind,
    SnapshotStore, SourceAlias, SourceKey, SourceKind, SourceSnapshot, SourceState,
    TransactionRuntime, TrustStore, WorldObservation, WorldState,
};

pub fn load_world(
    paths: &Paths,
    git: &dyn GitRunner,
    runtime: &dyn TransactionRuntime,
) -> Result<WorldState> {
    let mut locks = LockCoordinator::new();
    locks.acquire(&paths.store_lock_path(), LockRank::Store, LockMode::Shared)?;
    locks.acquire(&paths.trust_lock_path(), LockRank::Trust, LockMode::Shared)?;
    if matches!(paths.scope, ScopePaths::Project { .. }) {
        locks.acquire(
            &paths.projects_lock_path(),
            LockRank::Projects,
            LockMode::Exclusive,
        )?;
    }
    locks.acquire(
        &paths.scope_lock_path(&paths.scope_key()),
        LockRank::Scope,
        LockMode::Shared,
    )?;

    let scope = match paths.scope {
        ScopePaths::Project { .. } => Scope::Project,
        ScopePaths::Global { .. } => Scope::Global,
    };
    let manifest_bytes = read_optional(&paths.manifest_path())?;
    let lock_bytes = read_optional(&paths.lock_path())?;
    if manifest_bytes.is_none() && lock_bytes.is_none() {
        let mut world = WorldState::absent(scope, [], [], None)?;
        collect_journal_observations(paths, &mut world.observations)?;
        if matches!(paths.scope, ScopePaths::Project { .. }) {
            world.project_index_bytes = crate::projects::read(paths)?;
        }
        return Ok(world);
    }
    let (manifest_bytes, lock_bytes) = match (manifest_bytes, lock_bytes) {
        (Some(manifest), Some(lock)) => (manifest, lock),
        _ => {
            return Err(CoreError::Request(
                "scope is partially initialized; manifest and lock must both exist".into(),
            ))
        }
    };
    let manifest = Manifest::parse(manifest_bytes.clone())?;
    let lock = crate::Lockfile::parse(&lock_bytes)?;
    let trust_bytes = read_optional(&paths.trust_path())?;
    if let Some(bytes) = trust_bytes.as_deref() {
        TrustStore::parse(bytes)?;
    }

    let mut observations = Vec::new();
    let mut locked_states = BTreeMap::new();
    for (alias, source) in &lock.sources {
        match load_locked_source(paths, &manifest, alias, source) {
            Ok(state) => {
                locked_states.insert(alias.clone(), state);
            }
            Err(error) => {
                observations.push(observation(
                    "locked-source-invalid",
                    [
                        ("source", alias.to_string()),
                        ("message", error.to_string()),
                    ],
                ));
                locked_states.insert(
                    alias.clone(),
                    placeholder_locked(paths, &manifest, alias, source)?,
                );
            }
        }
    }

    let mut candidates = BTreeMap::new();
    for alias in manifest.sources.keys() {
        let candidate_path = paths.candidate_path(&paths.scope_key(), alias);
        let Some(bytes) = read_optional(&candidate_path)? else {
            continue;
        };
        match load_candidate(paths, &manifest, alias, bytes, git) {
            Ok(state) => {
                candidates.insert(alias.clone(), state);
            }
            Err(error) => observations.push(observation(
                "candidate-invalid",
                [
                    ("source", alias.to_string()),
                    ("message", error.to_string()),
                ],
            )),
        }
    }

    let mut source_states = BTreeMap::new();
    for alias in manifest.sources.keys() {
        if let Some(candidate) = candidates.get(alias) {
            source_states.insert(alias.clone(), candidate.clone());
        } else if let Some(locked) = locked_states.get(alias) {
            source_states.insert(alias.clone(), locked.clone());
        }
    }
    let mut snapshots = locked_states
        .iter()
        .map(|(alias, state)| (alias.clone(), state.snapshot.clone()))
        .collect::<BTreeMap<_, _>>();
    for (alias, state) in &candidates {
        snapshots
            .entry(alias.clone())
            .or_insert_with(|| state.snapshot.clone());
    }
    let links = lock
        .skills
        .keys()
        .map(|name| {
            Ok((
                name.clone(),
                observe_link(&paths.skills_dir().join(name.as_str()))?,
            ))
        })
        .collect::<Result<_>>()?;
    collect_journal_observations(paths, &mut observations)?;

    let mut world = WorldState {
        scope,
        manifest_bytes,
        manifest,
        lock_bytes,
        lock,
        snapshots,
        source_states,
        locked_states,
        candidates,
        trust_bytes,
        links,
        inherited_global: None,
        manifest_present: true,
        lock_present: true,
        observations,
        project_index_bytes: None,
        reachability: None,
    };
    if matches!(paths.scope, ScopePaths::Project { .. }) {
        let nonce = runtime.transaction_nonce()?;
        world.project_index_bytes = Some(crate::projects::refresh_locked(
            paths,
            &world.manifest,
            &world.lock,
            &world.lock_bytes,
            runtime.unix_time()?,
            &nonce,
        )?);
    }
    Ok(world)
}

fn load_locked_source(
    paths: &Paths,
    manifest: &Manifest,
    alias: &SourceAlias,
    source: &LockSource,
) -> Result<SourceState> {
    let identity = declaration_identity(paths, manifest, alias)?;
    match source {
        LockSource::Git {
            commit,
            tree,
            inventory,
            ..
        } => {
            if identity.kind() != SourceKind::Git {
                return Err(CoreError::Source(
                    "locked Git source identity has the wrong kind".into(),
                ));
            }
            let source_key = SourceKey::derive(&identity);
            let snapshot_key = SnapshotKey::derive(SourceKind::Git, commit, tree, inventory)?;
            let root = paths.store_path(&source_key, &snapshot_key);
            let (source_inventory, store) = scan_store(&root, inventory)?;
            Ok(SourceState::new(
                SourceSnapshot::new(
                    alias.clone(),
                    SnapshotId::new(
                        SnapshotKind::Git,
                        Some(commit.clone()),
                        Some(tree.clone()),
                        inventory.clone(),
                    )?,
                    root,
                    source_inventory,
                ),
                store,
                false,
            )
            .source_identity(identity, empty_review_digest()))
        }
        LockSource::Live { .. } => {
            if identity.kind() != SourceKind::Live {
                return Err(CoreError::Source(
                    "locked live source identity has the wrong kind".into(),
                ));
            }
            let root = identity_path(&identity)?;
            let reader = HeldDirectoryReader::open(&root)?;
            let inventory = scan(&reader).map_err(|error| CoreError::Source(error.to_string()))?;
            reader.revalidate()?;
            Ok(SourceState::new(
                SourceSnapshot::new(
                    alias.clone(),
                    SnapshotId::new(
                        SnapshotKind::Live,
                        None,
                        None,
                        inventory.inventory_digest.to_string(),
                    )?,
                    root,
                    inventory.clone(),
                ),
                SnapshotStore::Valid,
                false,
            )
            .source_identity(identity, inventory.review_tree_digest.to_string()))
        }
    }
}

fn placeholder_locked(
    paths: &Paths,
    manifest: &Manifest,
    alias: &SourceAlias,
    source: &LockSource,
) -> Result<SourceState> {
    match source {
        LockSource::Git {
            commit,
            tree,
            inventory,
            ..
        } => {
            let identity = declaration_identity(paths, manifest, alias)?;
            let source_key = SourceKey::derive(&identity);
            let snapshot_key = SnapshotKey::derive(SourceKind::Git, commit, tree, inventory)?;
            Ok(SourceState::new(
                SourceSnapshot::new(
                    alias.clone(),
                    SnapshotId::new(
                        SnapshotKind::Git,
                        Some(commit.clone()),
                        Some(tree.clone()),
                        inventory.clone(),
                    )?,
                    paths.store_path(&source_key, &snapshot_key),
                    empty_inventory_with(inventory, &empty_review_digest())?,
                ),
                SnapshotStore::Corrupt,
                false,
            )
            .source_identity(identity, empty_review_digest()))
        }
        LockSource::Live { declared } => Err(CoreError::Source(format!(
            "cannot recover invalid live source `{declared}`"
        ))),
    }
}

fn load_candidate(
    paths: &Paths,
    manifest: &Manifest,
    alias: &SourceAlias,
    bytes: Vec<u8>,
    git: &dyn GitRunner,
) -> Result<SourceState> {
    let candidate = CandidateRecord::parse(&bytes, None)?;
    if manifest.source_declaration_hash(alias)? != candidate.declaration_hash
        || declaration_identity(paths, manifest, alias)? != candidate.identity
    {
        return Err(CoreError::Source(
            "candidate does not match its source declaration".into(),
        ));
    }
    let inventory = scan_candidate(paths, &candidate, git)?;
    if inventory.inventory_digest.to_string() != candidate.inventory
        || inventory.review_tree_digest.to_string() != candidate.review_tree
    {
        return Err(CoreError::Source(
            "candidate inventory identity mismatch".into(),
        ));
    }
    let review_key = candidate.review_key()?;
    let review = ReviewExport::load_for_keys(
        &paths.review_cache_dir(),
        &candidate.source_key(),
        &review_key,
    )?;
    if review.review_tree != candidate.review_tree {
        return Err(CoreError::Source(
            "candidate review export identity mismatch".into(),
        ));
    }
    let (kind, root, store) = match candidate.identity.kind() {
        SourceKind::Live => (
            SnapshotKind::Live,
            identity_path(&candidate.identity)?,
            SnapshotStore::Valid,
        ),
        SourceKind::Git => {
            let snapshot_key = candidate
                .snapshot_key()?
                .ok_or_else(|| CoreError::Source("Git candidate lacks snapshot key".into()))?;
            let root = paths.store_path(&candidate.source_key(), &snapshot_key);
            let store = scan_store(&root, &candidate.inventory)?.1;
            (SnapshotKind::Git, root, store)
        }
    };
    let materializable = candidate.identity.kind() == SourceKind::Git;
    Ok(SourceState::new(
        SourceSnapshot::new(
            alias.clone(),
            SnapshotId::new(
                kind,
                candidate.commit.clone(),
                candidate.tree.clone(),
                candidate.inventory.clone(),
            )?,
            root,
            inventory,
        ),
        store,
        materializable,
    )
    .source_identity(candidate.identity, candidate.review_tree)
    .candidate(bytes))
}

fn scan_candidate(
    paths: &Paths,
    candidate: &CandidateRecord,
    git: &dyn GitRunner,
) -> Result<SourceInventory> {
    if candidate.identity.kind() == SourceKind::Live {
        let root = identity_path(&candidate.identity)?;
        let reader = HeldDirectoryReader::open(&root)?;
        let inventory = scan(&reader).map_err(|error| CoreError::Source(error.to_string()))?;
        reader.revalidate()?;
        return Ok(inventory);
    }
    let snapshot = if candidate.identity.canonical_bytes().starts_with(b"/") {
        let root = identity_path(&candidate.identity)?;
        let mut snapshot = inspect_pinned_git(git, &root, None)?;
        snapshot.commit = candidate.commit.clone().expect("validated Git candidate");
        snapshot.tree = candidate.tree.clone().expect("validated Git candidate");
        snapshot
    } else {
        let cache = paths.git_cache_path(&candidate.source_key());
        if !cache.is_dir() {
            return Err(CoreError::Source("candidate Git cache is missing".into()));
        }
        git.verify_cache(&cache)?;
        GitSnapshot {
            identity: candidate.identity.clone(),
            requested_ref: None,
            fetched_ref: "refs/grimoire/candidate".into(),
            commit: candidate.commit.clone().expect("validated Git candidate"),
            tree: candidate.tree.clone().expect("validated Git candidate"),
            bare_repository: cache,
        }
    };
    let reader = GitTreeReader::new(git, &snapshot);
    scan(&reader).map_err(|error| CoreError::Source(error.to_string()))
}

fn scan_store(root: &Path, expected_inventory: &str) -> Result<(SourceInventory, SnapshotStore)> {
    if !root.exists() {
        return Ok((
            empty_inventory_with(expected_inventory, &empty_review_digest())?,
            SnapshotStore::Absent,
        ));
    }
    let reader = match HeldDirectoryReader::open(root) {
        Ok(reader) => reader,
        Err(_) => {
            return Ok((
                empty_inventory_with(expected_inventory, &empty_review_digest())?,
                SnapshotStore::Corrupt,
            ))
        }
    };
    let inventory = match scan(&reader) {
        Ok(inventory) => inventory,
        Err(_) => {
            return Ok((
                empty_inventory_with(expected_inventory, &empty_review_digest())?,
                SnapshotStore::Corrupt,
            ))
        }
    };
    let valid = reader.revalidate().is_ok()
        && inventory.inventory_digest.to_string() == expected_inventory
        && inventory.is_valid();
    Ok((
        inventory,
        if valid {
            SnapshotStore::Valid
        } else {
            SnapshotStore::Corrupt
        },
    ))
}

pub(crate) fn declaration_identity(
    paths: &Paths,
    manifest: &Manifest,
    alias: &SourceAlias,
) -> Result<CanonicalIdentity> {
    let source = manifest
        .sources
        .get(alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` is not declared")))?;
    match source {
        ManifestSource {
            location: crate::SourceLocation::Url(declared),
            ..
        } => CanonicalIdentity::remote(declared),
        ManifestSource {
            location: crate::SourceLocation::Path(_),
            live,
            ..
        } => {
            let manifest_path = paths.manifest_path();
            let manifest_dir = manifest_path
                .parent()
                .ok_or_else(|| CoreError::Source("manifest path has no parent".into()))?;
            let declared = manifest
                .resolve_declared_path(alias, manifest_dir)
                .ok_or_else(|| CoreError::Source("local source has no path".into()))?;
            let root = declared
                .canonicalize()
                .map_err(|error| io_error(&declared, error))?;
            CanonicalIdentity::local(
                if *live {
                    SourceKind::Live
                } else {
                    SourceKind::Git
                },
                &root,
            )
        }
    }
}

fn observe_link(path: &Path) -> Result<InstalledLink> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => Ok(InstalledLink::Symlink(
            fs::read_link(path).map_err(|error| io_error(path, error))?,
        )),
        Ok(metadata) if metadata.is_file() => Ok(InstalledLink::File),
        Ok(metadata) if metadata.is_dir() => Ok(InstalledLink::Directory),
        Ok(_) => Ok(InstalledLink::File),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(InstalledLink::Absent),
        Err(error) => Err(io_error(path, error)),
    }
}

fn identity_path(identity: &CanonicalIdentity) -> Result<PathBuf> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        let path = PathBuf::from(std::ffi::OsStr::from_bytes(identity.canonical_bytes()));
        if !path.is_absolute() {
            return Err(CoreError::Source(
                "local identity path is not absolute".into(),
            ));
        }
        Ok(path)
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire supports Unix hosts")
}

fn read_optional(path: &Path) -> Result<Option<Vec<u8>>> {
    crate::transaction::read_optional_bounded(path, crate::transaction::STATE_LIMIT)
}

fn empty_inventory_with(inventory: &str, review: &str) -> Result<SourceInventory> {
    Ok(SourceInventory {
        skills: Vec::new(),
        packs: Vec::new(),
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
        inventory_digest: parse_digest(inventory)?,
        review_tree_digest: parse_digest(review)?,
    })
}

fn parse_digest(value: &str) -> Result<Digest> {
    let hex = value
        .strip_prefix("sha256:")
        .ok_or_else(|| CoreError::Source("digest lacks sha256 prefix".into()))?;
    if hex.len() != 64 {
        return Err(CoreError::Source("digest has invalid length".into()));
    }
    let mut bytes = [0u8; 32];
    for (index, slot) in bytes.iter_mut().enumerate() {
        *slot = u8::from_str_radix(&hex[index * 2..index * 2 + 2], 16)
            .map_err(|_| CoreError::Source("digest is not hexadecimal".into()))?;
    }
    Ok(Digest::from_bytes(bytes))
}

fn empty_review_digest() -> String {
    compute_review_tree_digest(&[]).to_string()
}

fn collect_store_repair_observations(
    paths: &Paths,
    observations: &mut Vec<WorldObservation>,
) -> Result<()> {
    let root = paths.grimoire_home.join("transactions/store-repair");
    match fs::symlink_metadata(&root) {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(io_error(&root, error)),
        Ok(metadata) if !metadata.is_dir() || metadata.file_type().is_symlink() => {
            observations.push(observation("store-repair-invalid", []));
            return Ok(());
        }
        Ok(_) => {}
    }
    for source in fs::read_dir(&root).map_err(|error| io_error(&root, error))? {
        let source = source.map_err(|error| io_error(&root, error))?;
        let metadata = source
            .file_type()
            .map_err(|error| io_error(&source.path(), error))?;
        if !metadata.is_dir() {
            observations.push(observation("store-repair-invalid", []));
            continue;
        }
        for journal in
            fs::read_dir(source.path()).map_err(|error| io_error(&source.path(), error))?
        {
            let journal = journal.map_err(|error| io_error(&source.path(), error))?;
            observations.push(observation(
                "store-repair-pending",
                [("journal", journal.path().display().to_string())],
            ));
        }
    }
    Ok(())
}

fn collect_journal_observations(
    paths: &Paths,
    observations: &mut Vec<WorldObservation>,
) -> Result<()> {
    let journal_path = paths.transaction_journal_path(&paths.scope_key());
    if journal_path.exists() {
        observations.push(observation("scope-journal-pending", []));
    }
    collect_store_repair_observations(paths, observations)
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

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
