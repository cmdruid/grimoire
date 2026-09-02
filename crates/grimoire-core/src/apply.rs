use std::fs;
use std::path::{Path, PathBuf};

use sha2::{Digest as _, Sha256};

use crate::locks::{LockCoordinator, LockMode, LockRank};
use crate::transaction::journal::{
    Journal, LinkTransition, StateName, StateTransition, JOURNAL_SCHEMA,
};
use crate::transaction::{checkpoint, remove_file_if_present, replace, sync_directory, write_new};
use crate::{
    Action, ApplyOutcome, Approval, ByteHash, CoreError, LinkPrecondition, Paths, Plan, Result,
    Scope, ScopePaths, TransactionRuntime,
};

pub fn apply(
    paths: &Paths,
    plan: &Plan,
    approval: Approval,
    runtime: &dyn TransactionRuntime,
) -> Result<ApplyOutcome> {
    preflight(paths, plan)?;
    if !plan.blockers.is_empty() {
        return Err(CoreError::BlockedPlan);
    }
    if plan.is_destructive() {
        match approval {
            Approval::Granted => {}
            Approval::Declined => return Ok(ApplyOutcome::Cancelled),
            Approval::NotRequired => return Err(CoreError::ApprovalRequired),
        }
    } else if approval == Approval::Declined {
        return Ok(ApplyOutcome::Cancelled);
    }

    let nonce = runtime.transaction_nonce()?;
    validate_nonce(&nonce)?;
    let scope_key = paths.scope_key();
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
        &paths.scope_lock_path(&scope_key),
        LockRank::Scope,
        LockMode::Exclusive,
    )?;

    let journal_path = paths.transaction_journal_path(&scope_key);
    if journal_path.exists() {
        return Err(CoreError::RecoveryRequired(format!(
            "pending transaction at {}",
            journal_path.display()
        )));
    }
    validate_preconditions(paths, plan)?;
    let journal = build_journal(paths, plan, &scope_key, &nonce)?;
    write_new(&journal_path, &journal.to_bytes()?, Some(0o600))?;
    if checkpoint(runtime, "journal-created")? {
        return Ok(ApplyOutcome::Interrupted {
            checkpoint: "journal-created".into(),
        });
    }

    let parent_identity = DirectoryIdentity::capture_or_create(&paths.skills_dir())?;
    match execute(
        paths,
        plan,
        runtime,
        &journal_path,
        journal,
        &parent_identity,
    ) {
        Ok(outcome) => Ok(outcome),
        Err(error) => {
            let bytes = fs::read(&journal_path).map_err(|rollback| {
                CoreError::RecoveryRequired(format!(
                    "{error}; cannot read rollback journal: {rollback}"
                ))
            })?;
            let journal = Journal::from_bytes(&bytes)?;
            rollback(paths, &journal, &nonce).map_err(|rollback| {
                CoreError::RecoveryRequired(format!("{error}; rollback failed: {rollback}"))
            })?;
            remove_file_if_present(&journal_path)?;
            if let Some(parent) = journal_path.parent() {
                sync_directory(parent)?;
            }
            Err(error)
        }
    }
}

fn preflight(paths: &Paths, plan: &Plan) -> Result<()> {
    let expected_scope = match paths.scope {
        ScopePaths::Project { .. } => Scope::Project,
        ScopePaths::Global { .. } => Scope::Global,
    };
    for action in &plan.actions {
        let scope = match action {
            Action::PrepareSnapshot { scope, .. }
            | Action::CreateManifest { scope, .. }
            | Action::ReplaceManifest { scope, .. }
            | Action::CreateLock { scope, .. }
            | Action::ReplaceLock { scope, .. }
            | Action::CreateLink { scope, .. }
            | Action::RetainLink { scope, .. }
            | Action::RepointLink { scope, .. }
            | Action::RemoveLink { scope, .. } => *scope,
            Action::ReplaceTrust { .. } => continue,
        };
        if scope != expected_scope {
            return Err(CoreError::Transaction(
                "plan action belongs to a different scope".into(),
            ));
        }
        if matches!(
            action,
            Action::PrepareSnapshot { .. } | Action::ReplaceTrust { .. }
        ) {
            return Err(CoreError::Transaction(
                "snapshot preparation and trust mutation require the complete action interpreter"
                    .into(),
            ));
        }
        if let Action::CreateLink { target, .. }
        | Action::RetainLink { target, .. }
        | Action::RemoveLink { target, .. } = action
        {
            target.resolve(paths)?;
        }
        if let Action::RepointLink { before, after, .. } = action {
            before.resolve(paths)?;
            after.resolve(paths)?;
        }
    }
    Ok(())
}

fn validate_preconditions(paths: &Paths, plan: &Plan) -> Result<()> {
    validate_file_hash(
        &paths.manifest_path(),
        plan.preconditions.manifest.as_ref(),
        "manifest",
    )?;
    validate_file_hash(&paths.lock_path(), plan.preconditions.lock.as_ref(), "lock")?;
    validate_file_hash(
        &paths.trust_path(),
        plan.preconditions.trust.as_ref(),
        "trust",
    )?;
    for (alias, expected) in &plan.preconditions.candidates {
        validate_file_hash(
            &paths.candidate_path(&paths.scope_key(), alias),
            Some(expected),
            "candidate",
        )?;
    }
    for (skill, expected) in &plan.preconditions.links {
        let actual = observe_link(&paths.skills_dir().join(skill.as_str()))?;
        if &actual != expected {
            return Err(CoreError::StalePlan(format!(
                "installed link `{skill}` changed"
            )));
        }
    }
    for action in &plan.actions {
        match action {
            Action::CreateManifest { after, .. } | Action::ReplaceManifest { after, .. } => {
                crate::Manifest::parse(after.clone())?;
            }
            Action::CreateLock { after, .. } | Action::ReplaceLock { after, .. } => {
                crate::Lockfile::parse(after)?;
            }
            _ => {}
        }
    }
    Ok(())
}

fn build_journal(paths: &Paths, plan: &Plan, scope_key: &str, nonce: &str) -> Result<Journal> {
    let mut state = Vec::new();
    let mut links = Vec::new();
    for action in &plan.actions {
        match action {
            Action::CreateManifest { after, .. } => state.push(StateTransition {
                name: StateName::Manifest,
                before: None,
                after: Some(after.clone()),
            }),
            Action::ReplaceManifest { before, after, .. } => state.push(StateTransition {
                name: StateName::Manifest,
                before: Some(before.clone()),
                after: Some(after.clone()),
            }),
            Action::CreateLock { after, .. } => state.push(StateTransition {
                name: StateName::Lock,
                before: None,
                after: Some(after.clone()),
            }),
            Action::ReplaceLock { before, after, .. } => state.push(StateTransition {
                name: StateName::Lock,
                before: Some(before.clone()),
                after: Some(after.clone()),
            }),
            Action::CreateLink { skill, target, .. } => links.push(LinkTransition {
                skill: skill.to_string(),
                before: None,
                after: Some(path_bytes(&target.resolve(paths)?)),
            }),
            Action::RetainLink { .. } => {}
            Action::RepointLink {
                skill,
                before,
                after,
                ..
            } => links.push(LinkTransition {
                skill: skill.to_string(),
                before: Some(path_bytes(&before.resolve(paths)?)),
                after: Some(path_bytes(&after.resolve(paths)?)),
            }),
            Action::RemoveLink { skill, target, .. } => links.push(LinkTransition {
                skill: skill.to_string(),
                before: Some(path_bytes(&target.resolve(paths)?)),
                after: None,
            }),
            Action::PrepareSnapshot { .. } | Action::ReplaceTrust { .. } => {
                unreachable!("preflight")
            }
        }
    }
    state.sort_by_key(|transition| transition.name);
    links.sort_by(|left, right| left.skill.cmp(&right.skill));
    let plan_digest = format!("{:x}", Sha256::digest(plan.to_bytes()?));
    Ok(Journal {
        schema: JOURNAL_SCHEMA.into(),
        scope_key: scope_key.into(),
        nonce: nonce.into(),
        plan_digest,
        committed: false,
        state,
        links,
        completed: Vec::new(),
    })
}

fn execute(
    paths: &Paths,
    plan: &Plan,
    runtime: &dyn TransactionRuntime,
    journal_path: &Path,
    mut journal: Journal,
    parent_identity: &DirectoryIdentity,
) -> Result<ApplyOutcome> {
    let mut changed = false;
    for action in &plan.actions {
        match action {
            Action::RetainLink { skill, target, .. } => {
                let expected = target.resolve(paths)?;
                require_link(&paths.skills_dir().join(skill.as_str()), Some(&expected))?;
            }
            Action::CreateLink { skill, target, .. } => {
                let destination = paths.skills_dir().join(skill.as_str());
                parent_identity.revalidate(&paths.skills_dir())?;
                if checkpoint(runtime, "before-link-ownership")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "before-link-ownership".into(),
                    });
                }
                parent_identity.revalidate(&paths.skills_dir())?;
                require_link(&destination, None)?;
                create_symlink(&target.resolve(paths)?, &destination)?;
                sync_directory(&paths.skills_dir())?;
                if mark(
                    runtime,
                    journal_path,
                    &mut journal,
                    &format!("link:{skill}"),
                )? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "action-marked".into(),
                    });
                }
                changed = true;
            }
            Action::RepointLink {
                skill,
                before,
                after,
                ..
            } => {
                let destination = paths.skills_dir().join(skill.as_str());
                parent_identity.revalidate(&paths.skills_dir())?;
                require_link(&destination, Some(&before.resolve(paths)?))?;
                replace_symlink(&destination, &after.resolve(paths)?, &journal.nonce)?;
                if mark(
                    runtime,
                    journal_path,
                    &mut journal,
                    &format!("link:{skill}"),
                )? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "action-marked".into(),
                    });
                }
                changed = true;
            }
            Action::RemoveLink { skill, target, .. } => {
                let destination = paths.skills_dir().join(skill.as_str());
                parent_identity.revalidate(&paths.skills_dir())?;
                require_link(&destination, Some(&target.resolve(paths)?))?;
                fs::remove_file(&destination)
                    .map_err(|error| crate::transaction::io_error(&destination, error))?;
                sync_directory(&paths.skills_dir())?;
                if mark(
                    runtime,
                    journal_path,
                    &mut journal,
                    &format!("link:{skill}"),
                )? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "action-marked".into(),
                    });
                }
                changed = true;
            }
            _ => {}
        }
    }
    for state in journal.state.clone() {
        let path = state_path(paths, state.name)?;
        match &state.after {
            Some(bytes) => replace(&path, bytes, &journal.nonce, None)?,
            None => remove_file_if_present(&path)?,
        }
        if mark(runtime, journal_path, &mut journal, state_name(state.name))? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "action-marked".into(),
            });
        }
        changed = true;
    }
    journal.committed = true;
    replace(
        journal_path,
        &journal.to_bytes()?,
        &journal.nonce,
        Some(0o600),
    )?;
    if checkpoint(runtime, "committed")? {
        return Ok(ApplyOutcome::Interrupted {
            checkpoint: "committed".into(),
        });
    }
    remove_file_if_present(journal_path)?;
    if let Some(parent) = journal_path.parent() {
        sync_directory(parent)?;
    }
    Ok(ApplyOutcome::Applied { changed })
}

fn mark(
    runtime: &dyn TransactionRuntime,
    journal_path: &Path,
    journal: &mut Journal,
    action: &str,
) -> Result<bool> {
    journal.completed.push(action.into());
    replace(
        journal_path,
        &journal.to_bytes()?,
        &journal.nonce,
        Some(0o600),
    )?;
    checkpoint(runtime, "action-marked")
}

fn rollback(paths: &Paths, journal: &Journal, nonce: &str) -> Result<()> {
    for link in journal.links.iter().rev() {
        if !journal
            .completed
            .iter()
            .any(|completed| completed == &format!("link:{}", link.skill))
        {
            continue;
        }
        let destination = paths.skills_dir().join(&link.skill);
        match &link.before {
            Some(raw) => replace_symlink(&destination, &bytes_path(raw), nonce)?,
            None => remove_file_if_present(&destination)?,
        }
    }
    for state in journal.state.iter().rev() {
        if !journal
            .completed
            .iter()
            .any(|completed| completed == state_name(state.name))
        {
            continue;
        }
        let path = state_path(paths, state.name)?;
        match &state.before {
            Some(bytes) => replace(&path, bytes, nonce, None)?,
            None => remove_file_if_present(&path)?,
        }
    }
    Ok(())
}

fn validate_file_hash(path: &Path, expected: Option<&ByteHash>, name: &str) -> Result<()> {
    match (fs::read(path), expected) {
        (Ok(bytes), Some(expected)) if &ByteHash::of(&bytes) == expected => Ok(()),
        (Err(error), None) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        (Ok(_), None) => Err(CoreError::StalePlan(format!("{name} appeared"))),
        (Err(error), Some(_)) if error.kind() == std::io::ErrorKind::NotFound => {
            Err(CoreError::StalePlan(format!("{name} disappeared")))
        }
        (Ok(_), Some(_)) => Err(CoreError::StalePlan(format!("{name} bytes changed"))),
        (Err(error), _) => Err(crate::transaction::io_error(path, error)),
    }
}

fn observe_link(path: &Path) -> Result<LinkPrecondition> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => Ok(LinkPrecondition::Symlink(
            fs::read_link(path).map_err(|error| crate::transaction::io_error(path, error))?,
        )),
        Ok(metadata) if metadata.is_file() => Ok(LinkPrecondition::File),
        Ok(metadata) if metadata.is_dir() => Ok(LinkPrecondition::Directory),
        Ok(_) => Ok(LinkPrecondition::File),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(LinkPrecondition::Absent),
        Err(error) => Err(crate::transaction::io_error(path, error)),
    }
}

fn require_link(path: &Path, expected: Option<&Path>) -> Result<()> {
    match (observe_link(path)?, expected) {
        (LinkPrecondition::Absent, None) => Ok(()),
        (LinkPrecondition::Symlink(actual), Some(expected)) if actual == expected => Ok(()),
        _ => Err(CoreError::StalePlan(format!(
            "final ownership changed at {}",
            path.display()
        ))),
    }
}

fn create_symlink(target: &Path, destination: &Path) -> Result<()> {
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(target, destination)
            .map_err(|error| crate::transaction::io_error(destination, error))
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire supports Unix hosts")
}

fn replace_symlink(destination: &Path, target: &Path, nonce: &str) -> Result<()> {
    let parent = destination
        .parent()
        .ok_or_else(|| CoreError::Transaction("link path has no parent".into()))?;
    fs::create_dir_all(parent).map_err(|error| crate::transaction::io_error(parent, error))?;
    let name = destination
        .file_name()
        .and_then(|value| value.to_str())
        .ok_or_else(|| CoreError::Transaction("skill name is not UTF-8".into()))?;
    let temporary = parent.join(format!(".{name}.{nonce}.link"));
    remove_file_if_present(&temporary)?;
    create_symlink(target, &temporary)?;
    fs::rename(&temporary, destination)
        .map_err(|error| crate::transaction::io_error(destination, error))?;
    sync_directory(parent)
}

fn state_path(paths: &Paths, name: StateName) -> Result<PathBuf> {
    match name {
        StateName::Manifest => Ok(paths.manifest_path()),
        StateName::Lock => Ok(paths.lock_path()),
        StateName::Trust => Ok(paths.trust_path()),
        StateName::Candidate => Err(CoreError::Transaction(
            "candidate journal entry lacks an alias".into(),
        )),
    }
}

fn state_name(name: StateName) -> &'static str {
    match name {
        StateName::Manifest => "manifest",
        StateName::Lock => "lock",
        StateName::Trust => "trust",
        StateName::Candidate => "candidate",
    }
}

fn path_bytes(path: &Path) -> Vec<u8> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        path.as_os_str().as_bytes().to_vec()
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire supports Unix hosts")
}

fn bytes_path(bytes: &[u8]) -> PathBuf {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        PathBuf::from(std::ffi::OsStr::from_bytes(bytes))
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire supports Unix hosts")
}

fn validate_nonce(nonce: &str) -> Result<()> {
    if !nonce.is_empty()
        && nonce.len() <= 64
        && nonce
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_')
    {
        Ok(())
    } else {
        Err(CoreError::Transaction("invalid transaction nonce".into()))
    }
}

#[derive(Clone, Copy)]
struct DirectoryIdentity {
    device: u64,
    inode: u64,
}

impl DirectoryIdentity {
    fn capture_or_create(path: &Path) -> Result<Self> {
        fs::create_dir_all(path).map_err(|error| crate::transaction::io_error(path, error))?;
        Self::capture(path)
    }

    fn capture(path: &Path) -> Result<Self> {
        let metadata = fs::symlink_metadata(path)
            .map_err(|error| crate::transaction::io_error(path, error))?;
        if !metadata.is_dir() || metadata.file_type().is_symlink() {
            return Err(CoreError::Transaction(format!(
                "link parent is not an owned directory: {}",
                path.display()
            )));
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            Ok(Self {
                device: metadata.dev(),
                inode: metadata.ino(),
            })
        }
        #[cfg(not(unix))]
        unreachable!("Grimoire supports Unix hosts")
    }

    fn revalidate(self, path: &Path) -> Result<()> {
        let current = Self::capture(path)?;
        if current.device == self.device && current.inode == self.inode {
            Ok(())
        } else {
            Err(CoreError::StalePlan(
                "installed-link parent directory changed".into(),
            ))
        }
    }
}
