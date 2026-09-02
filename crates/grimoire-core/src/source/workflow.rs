use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};

use grimoire_pack::inventory::scan;

use super::{
    fetch_remote, inspect_pinned_git, CandidateRecord, CanonicalIdentity, GitRunner, GitTreeReader,
    HeldDirectoryReader, ReviewExport, SourceInfo, SourceKey, SourceKind,
};
use crate::locks::{LockCoordinator, LockMode, LockRank};
use crate::{CoreError, Manifest, Paths, Result, SourceAlias, SourceLocation, TrustMode};

pub struct CandidateWorkflow {
    paths: Paths,
    scope_key: String,
    alias: SourceAlias,
    locks: LockCoordinator,
}

pub fn fetch_source(
    paths: Paths,
    alias: SourceAlias,
    runner: &dyn GitRunner,
) -> Result<SourceInfo> {
    let mut workflow = CandidateWorkflow::begin(paths.clone(), alias.clone())?;
    let manifest_bytes =
        fs::read(paths.manifest_path()).map_err(|error| io_error(&paths.manifest_path(), error))?;
    let manifest = Manifest::parse(manifest_bytes)?;
    let source = manifest
        .sources
        .get(&alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` was removed")))?;
    let SourceLocation::Url(declared) = &source.location else {
        return Err(CoreError::Source(
            "fetch_source requires a remote Git declaration".into(),
        ));
    };
    let declaration_hash = manifest.source_declaration_hash(&alias)?;
    let identity = CanonicalIdentity::remote(declared)?;
    let source_key = SourceKey::derive(&identity);
    let mut snapshot = workflow.replace_cache(&source_key, runner, |replacement| {
        fetch_remote(runner, declared, source.reference.as_deref(), replacement)
    })?;
    snapshot.bare_repository = paths.git_cache_path(&source_key);
    let reader = GitTreeReader::new(runner, &snapshot);
    let inventory = scan(&reader).map_err(|error| CoreError::Source(error.to_string()))?;
    let candidate = CandidateRecord::new(
        declaration_hash,
        identity,
        Some(snapshot.commit),
        Some(snapshot.tree),
        inventory.inventory_digest.to_string(),
        inventory.review_tree_digest.to_string(),
    )?;
    let export = ReviewExport::write(
        &paths.review_cache_dir(),
        source_key,
        candidate.review_key()?,
        &inventory,
        &reader,
    )?;
    workflow.publish(&candidate)?;
    Ok(SourceInfo::from_candidate(
        alias,
        declared.clone(),
        source.reference.clone(),
        candidate,
        inventory,
        export,
        TrustMode::Untrusted,
        None,
    ))
}

pub fn inspect_live_source(paths: Paths, alias: SourceAlias) -> Result<SourceInfo> {
    let workflow = CandidateWorkflow::begin(paths.clone(), alias.clone())?;
    let manifest_bytes =
        fs::read(paths.manifest_path()).map_err(|error| io_error(&paths.manifest_path(), error))?;
    let manifest = Manifest::parse(manifest_bytes)?;
    let source = manifest
        .sources
        .get(&alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` was removed")))?;
    let SourceLocation::Path(declared) = &source.location else {
        return Err(CoreError::Source(
            "inspect_live_source requires a local declaration".into(),
        ));
    };
    if !source.live {
        return Err(CoreError::Source(
            "pinned local Git inspection requires Git custody".into(),
        ));
    }
    let manifest_dir = paths
        .manifest_path()
        .parent()
        .ok_or_else(|| CoreError::Source("manifest path has no parent".into()))?
        .to_path_buf();
    let root = normalize_absolute(
        &manifest
            .resolve_declared_path(&alias, &manifest_dir)
            .ok_or_else(|| CoreError::Source("local declaration has no root".into()))?,
    )?;
    let reader = HeldDirectoryReader::open(&root)?;
    let identity = CanonicalIdentity::local(SourceKind::Live, &root)?;
    let inventory = scan(&reader).map_err(|error| CoreError::Source(error.to_string()))?;
    reader.revalidate()?;
    let candidate = CandidateRecord::new(
        manifest.source_declaration_hash(&alias)?,
        identity.clone(),
        None,
        None,
        inventory.inventory_digest.to_string(),
        inventory.review_tree_digest.to_string(),
    )?;
    let export = ReviewExport::write(
        &paths.review_cache_dir(),
        SourceKey::derive(&identity),
        candidate.review_key()?,
        &inventory,
        &reader,
    )?;
    reader.revalidate()?;
    workflow.publish(&candidate)?;
    Ok(SourceInfo::from_candidate(
        alias,
        declared.clone(),
        None,
        candidate,
        inventory,
        export,
        TrustMode::Untrusted,
        None,
    ))
}

pub fn inspect_pinned_source(
    paths: Paths,
    alias: SourceAlias,
    runner: &dyn GitRunner,
) -> Result<SourceInfo> {
    let workflow = CandidateWorkflow::begin(paths.clone(), alias.clone())?;
    let manifest_bytes =
        fs::read(paths.manifest_path()).map_err(|error| io_error(&paths.manifest_path(), error))?;
    let manifest = Manifest::parse(manifest_bytes)?;
    let source = manifest
        .sources
        .get(&alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` was removed")))?;
    let SourceLocation::Path(declared) = &source.location else {
        return Err(CoreError::Source(
            "inspect_pinned_source requires a local declaration".into(),
        ));
    };
    if source.live {
        return Err(CoreError::Source(
            "inspect_pinned_source requires pinned mode".into(),
        ));
    }
    let manifest_dir = paths
        .manifest_path()
        .parent()
        .ok_or_else(|| CoreError::Source("manifest path has no parent".into()))?
        .to_path_buf();
    let root = normalize_absolute(
        &manifest
            .resolve_declared_path(&alias, &manifest_dir)
            .ok_or_else(|| CoreError::Source("local declaration has no root".into()))?,
    )?;
    let snapshot = inspect_pinned_git(runner, &root, source.reference.as_deref())?;
    let reader = GitTreeReader::new(runner, &snapshot);
    let inventory = scan(&reader).map_err(|error| CoreError::Source(error.to_string()))?;
    let candidate = CandidateRecord::new(
        manifest.source_declaration_hash(&alias)?,
        snapshot.identity,
        Some(snapshot.commit),
        Some(snapshot.tree),
        inventory.inventory_digest.to_string(),
        inventory.review_tree_digest.to_string(),
    )?;
    let export = ReviewExport::write(
        &paths.review_cache_dir(),
        candidate.source_key(),
        candidate.review_key()?,
        &inventory,
        &reader,
    )?;
    workflow.publish(&candidate)?;
    Ok(SourceInfo::from_candidate(
        alias,
        declared.clone(),
        source.reference.clone(),
        candidate,
        inventory,
        export,
        TrustMode::Untrusted,
        None,
    ))
}

fn normalize_absolute(path: &Path) -> Result<PathBuf> {
    let mut normalized = PathBuf::from("/");
    for component in path.components() {
        match component {
            std::path::Component::RootDir => {}
            std::path::Component::CurDir => {}
            std::path::Component::ParentDir => {
                if !normalized.pop() {
                    return Err(CoreError::Source(
                        "local path escapes filesystem root".into(),
                    ));
                }
                if normalized.as_os_str().is_empty() {
                    normalized.push("/");
                }
            }
            std::path::Component::Normal(part) => normalized.push(part),
            std::path::Component::Prefix(_) => {
                return Err(CoreError::Source("unsupported local path prefix".into()))
            }
        }
    }
    Ok(normalized)
}

impl CandidateWorkflow {
    pub fn begin(paths: Paths, alias: SourceAlias) -> Result<Self> {
        let scope_key = paths.scope_key();
        let mut locks = LockCoordinator::new();
        locks.acquire(
            &paths.candidate_lock_path(&scope_key, &alias),
            LockRank::Candidate,
            LockMode::Exclusive,
        )?;
        Ok(Self {
            paths,
            scope_key,
            alias,
            locks,
        })
    }

    pub fn with_cache<T>(
        &mut self,
        source: &super::SourceKey,
        operation: impl FnOnce(&Path) -> Result<T>,
    ) -> Result<T> {
        self.locks.acquire(
            &self.paths.cache_lock_path(source),
            LockRank::Cache,
            LockMode::Exclusive,
        )?;
        let result = operation(&self.paths.git_cache_path(source));
        let release = self.locks.release_last(LockRank::Cache);
        match (result, release) {
            (Ok(value), Ok(())) => Ok(value),
            (Err(error), _) | (_, Err(error)) => Err(error),
        }
    }

    pub fn replace_cache<T>(
        &mut self,
        source: &SourceKey,
        runner: &dyn GitRunner,
        prepare: impl FnOnce(&Path) -> Result<T>,
    ) -> Result<T> {
        self.with_cache(source, |fixed| {
            let parent = fixed
                .parent()
                .ok_or_else(|| CoreError::Source("Git cache path has no parent".into()))?;
            fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
            let previous = parent.join(format!(".{source}.previous"));
            let replacement = parent.join(format!(".{source}.replacement"));
            recover_cache(fixed, &previous, &replacement, runner)?;
            remove_cache(&replacement)?;

            let prepared = match prepare(&replacement) {
                Ok(prepared) => prepared,
                Err(error) => {
                    let _ = remove_cache(&replacement);
                    return Err(error);
                }
            };
            if let Err(error) = runner.verify_cache(&replacement) {
                let _ = remove_cache(&replacement);
                return Err(error);
            }
            remove_cache(&previous)?;
            if fixed.exists() {
                fs::rename(fixed, &previous).map_err(|error| io_error(&previous, error))?;
                sync_directory(parent)?;
            }
            if let Err(error) = fs::rename(&replacement, fixed) {
                if previous.exists() && !fixed.exists() {
                    let _ = fs::rename(&previous, fixed);
                    let _ = sync_directory(parent);
                }
                return Err(io_error(fixed, error));
            }
            sync_directory(parent)?;
            remove_cache(&previous)?;
            sync_directory(parent)?;
            Ok(prepared)
        })
    }

    pub fn publish(mut self, candidate: &CandidateRecord) -> Result<PathBuf> {
        self.locks.acquire(
            &self.paths.store_lock_path(),
            LockRank::Store,
            LockMode::Shared,
        )?;
        self.locks.acquire(
            &self.paths.scope_lock_path(&self.scope_key),
            LockRank::Scope,
            LockMode::Exclusive,
        )?;

        let bytes = fs::read(self.paths.manifest_path())
            .map_err(|error| io_error(&self.paths.manifest_path(), error))?;
        let manifest = Manifest::parse(bytes)?;
        let declaration_hash = manifest.source_declaration_hash(&self.alias)?;
        if declaration_hash != candidate.declaration_hash {
            return Err(CoreError::Source(
                "source declaration changed before candidate publication".into(),
            ));
        }
        let identity = declaration_identity(&manifest, &self.alias, &self.paths.manifest_path())?;
        if identity != candidate.identity {
            return Err(CoreError::Source(
                "source identity changed before candidate publication".into(),
            ));
        }
        reject_duplicate_identity(
            &manifest,
            &self.alias,
            &identity,
            &self.paths.manifest_path(),
        )?;

        let destination = self.paths.candidate_path(&self.scope_key, &self.alias);
        let parent = destination
            .parent()
            .ok_or_else(|| CoreError::Source("candidate path has no parent".into()))?;
        fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
        let candidate_bytes = candidate.to_bytes()?;
        let temporary = write_temporary(parent, &self.alias, &candidate_bytes)?;
        if let Err(error) = fs::rename(&temporary, &destination) {
            let _ = fs::remove_file(&temporary);
            return Err(io_error(&destination, error));
        }
        File::open(parent)
            .and_then(|file| file.sync_all())
            .map_err(|error| io_error(parent, error))?;
        Ok(destination)
    }
}

fn recover_cache(
    fixed: &Path,
    previous: &Path,
    replacement: &Path,
    runner: &dyn GitRunner,
) -> Result<()> {
    let fixed_valid = fixed.exists() && runner.verify_cache(fixed).is_ok();
    let previous_valid = previous.exists() && runner.verify_cache(previous).is_ok();
    let replacement_valid = replacement.exists() && runner.verify_cache(replacement).is_ok();
    if fixed_valid {
        remove_cache(previous)?;
        remove_cache(replacement)?;
    } else if replacement_valid {
        remove_cache(fixed)?;
        fs::rename(replacement, fixed).map_err(|error| io_error(fixed, error))?;
        remove_cache(previous)?;
    } else if previous_valid {
        remove_cache(fixed)?;
        fs::rename(previous, fixed).map_err(|error| io_error(fixed, error))?;
        remove_cache(replacement)?;
    } else {
        remove_cache(fixed)?;
        remove_cache(previous)?;
        remove_cache(replacement)?;
    }
    if let Some(parent) = fixed.parent() {
        sync_directory(parent)?;
    }
    Ok(())
}

fn remove_cache(path: &Path) -> Result<()> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.is_dir() => {
            fs::remove_dir_all(path).map_err(|error| io_error(path, error))
        }
        Ok(_) => fs::remove_file(path).map_err(|error| io_error(path, error)),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(io_error(path, error)),
    }
}

fn sync_directory(path: &Path) -> Result<()> {
    File::open(path)
        .and_then(|file| file.sync_all())
        .map_err(|error| io_error(path, error))
}

fn declaration_identity(
    manifest: &Manifest,
    alias: &SourceAlias,
    manifest_path: &Path,
) -> Result<CanonicalIdentity> {
    let source = manifest
        .sources
        .get(alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` was removed")))?;
    match &source.location {
        SourceLocation::Url(declared) => CanonicalIdentity::remote(declared),
        SourceLocation::Path(_) => {
            let manifest_dir = manifest_path
                .parent()
                .ok_or_else(|| CoreError::Source("manifest path has no parent".into()))?;
            let root = manifest
                .resolve_declared_path(alias, manifest_dir)
                .ok_or_else(|| CoreError::Source("local declaration has no root".into()))?
                .canonicalize()
                .map_err(|error| CoreError::Io {
                    path: source.declared().into(),
                    message: error.to_string(),
                })?;
            CanonicalIdentity::local(
                if source.live {
                    SourceKind::Live
                } else {
                    SourceKind::Git
                },
                &root,
            )
        }
    }
}

fn reject_duplicate_identity(
    manifest: &Manifest,
    selected: &SourceAlias,
    identity: &CanonicalIdentity,
    manifest_path: &Path,
) -> Result<()> {
    for alias in manifest.sources.keys().filter(|alias| *alias != selected) {
        if declaration_identity(manifest, alias, manifest_path)? == *identity {
            return Err(CoreError::Source(format!(
                "source `{alias}` has the same canonical identity as `{selected}`"
            )));
        }
    }
    Ok(())
}

fn write_temporary(parent: &Path, alias: &SourceAlias, bytes: &[u8]) -> Result<PathBuf> {
    for nonce in 0..100u32 {
        let path = parent.join(format!(".{alias}.candidate-{}-{nonce}", std::process::id()));
        match OpenOptions::new().write(true).create_new(true).open(&path) {
            Ok(mut file) => {
                if let Err(error) = file.write_all(bytes).and_then(|()| file.sync_all()) {
                    let _ = fs::remove_file(&path);
                    return Err(io_error(&path, error));
                }
                return Ok(path);
            }
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(io_error(&path, error)),
        }
    }
    Err(CoreError::Source(
        "cannot allocate candidate temporary file".into(),
    ))
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
