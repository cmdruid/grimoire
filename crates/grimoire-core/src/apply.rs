use std::ffi::CString;
use std::fs::{self, File};
use std::path::{Path, PathBuf};

use rustix::fs::{
    mkdirat, open, openat, readlinkat, renameat_with, statat, symlinkat, unlinkat, AtFlags, Mode,
    OFlags, RenameFlags,
};

use sha2::{Digest as _, Sha256};

use crate::locks::{LockCoordinator, LockMode, LockRank};
use crate::transaction::journal::{
    Journal, LinkTransition, StateName, StateTransition, VendorTransition, JOURNAL_SCHEMA,
};
use crate::transaction::{
    checkpoint, read_optional_bounded, read_required_bounded, remove_file_if_present, replace,
    sync_directory, write_new, STATE_LIMIT,
};
use crate::{
    Action, ApplyOutcome, Approval, ByteHash, CoreError, LinkPrecondition, Paths, Plan,
    RecoveryDisposition, RecoveryOutcome, Result, Scope, ScopePaths, TransactionRuntime,
};

pub fn recover(paths: &Paths, runtime: &dyn TransactionRuntime) -> Result<RecoveryOutcome> {
    let scope_key = paths.scope_key();
    let journal_path = paths.transaction_journal_path(&scope_key);
    let bytes = match read_optional_bounded(&journal_path, STATE_LIMIT)? {
        Some(bytes) => bytes,
        None => {
            return Ok(RecoveryOutcome {
                dispositions: Vec::new(),
            })
        }
    };
    let journal = Journal::from_bytes(&bytes)?;
    validate_journal(paths, &journal)?;

    let mut locks = LockCoordinator::new();
    let candidates = journal
        .state
        .iter()
        .filter(|state| state.name == StateName::Candidate)
        .collect::<Vec<_>>();
    if candidates.len() > 1 {
        return Err(CoreError::Transaction(
            "journal contains more than one candidate mutation".into(),
        ));
    }
    if let Some(candidate) = candidates.first() {
        let alias = crate::SourceAlias::new(
            candidate
                .alias
                .as_deref()
                .ok_or_else(|| CoreError::Transaction("candidate journal lacks alias".into()))?,
        )?;
        locks.acquire(
            &paths.candidate_lock_path(&scope_key, &alias),
            LockRank::Candidate,
            LockMode::Exclusive,
        )?;
    }
    locks.acquire(&paths.store_lock_path(), LockRank::Store, LockMode::Shared)?;
    locks.acquire(
        &paths.trust_lock_path(),
        LockRank::Trust,
        if journal
            .state
            .iter()
            .any(|state| state.name == StateName::Trust)
        {
            LockMode::Exclusive
        } else {
            LockMode::Shared
        },
    )?;
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
    let current_journal = match read_optional_bounded(&journal_path, STATE_LIMIT)? {
        Some(bytes) => bytes,
        None => {
            return Ok(RecoveryOutcome {
                dispositions: Vec::new(),
            })
        }
    };
    if current_journal != bytes {
        return Err(CoreError::RecoveryRequired(
            "transaction journal changed while acquiring recovery custody".into(),
        ));
    }

    if checkpoint(runtime, "recovery-start")? {
        return Ok(RecoveryOutcome {
            dispositions: Vec::new(),
        });
    }
    let state_after = journal
        .state
        .iter()
        .all(|state| current_state(paths, state).ok() == Some(state.after.clone()));
    let links_after = journal
        .links
        .iter()
        .all(|link| current_link(paths, link).ok() == Some(link.after.clone()));
    let vendors_after = journal.vendors.iter().all(|vendor| {
        current_vendor(paths, vendor).ok() == Some(VendorOccupancy::from(&vendor.after))
    });
    let roll_forward = journal.committed
        || (!journal.state.is_empty() && state_after && links_after && vendors_after);
    let disposition = if roll_forward {
        if !state_after || !links_after || !vendors_after {
            return Err(CoreError::RecoveryRequired(
                "committed transaction does not match its recorded after state".into(),
            ));
        }
        cleanup_captured_vendors(paths, &journal)?;
        cleanup_captured_links(paths, &journal)?;
        RecoveryDisposition::RolledForward {
            scope_key: scope_key.clone(),
        }
    } else {
        restore_before(paths, &journal, &journal.nonce)?;
        RecoveryDisposition::RolledBack {
            scope_key: scope_key.clone(),
        }
    };
    if roll_forward && matches!(paths.scope, ScopePaths::Project { .. }) {
        if checkpoint(runtime, "before-project-refresh")? {
            return Ok(RecoveryOutcome {
                dispositions: Vec::new(),
            });
        }
        refresh_project_index(paths, runtime, &journal.nonce)?;
        if checkpoint(runtime, "after-project-refresh")? {
            return Ok(RecoveryOutcome {
                dispositions: Vec::new(),
            });
        }
    }
    if checkpoint(runtime, "recovery-state-complete")? {
        return Ok(RecoveryOutcome {
            dispositions: Vec::new(),
        });
    }
    remove_file_if_present(&journal_path)?;
    if let Some(parent) = journal_path.parent() {
        sync_directory(parent)?;
    }
    Ok(RecoveryOutcome {
        dispositions: vec![disposition],
    })
}

pub fn apply(
    paths: &Paths,
    plan: &Plan,
    approval: Approval,
    runtime: &dyn TransactionRuntime,
) -> Result<ApplyOutcome> {
    preflight(paths, plan)?;
    validate_action_shapes(plan)?;
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

    if plan.preconditions.reachability.is_some()
        || plan
            .actions
            .iter()
            .any(|action| matches!(action, Action::PruneSnapshot { .. }))
    {
        return apply_prune(paths, plan, runtime);
    }

    let pending_journal = paths.transaction_journal_path(&paths.scope_key());
    if pending_journal.exists() {
        recover(paths, runtime)?;
        if pending_journal.exists() {
            return Err(CoreError::RecoveryRequired(
                "transaction recovery was interrupted".into(),
            ));
        }
    }

    let nonce = runtime.transaction_nonce()?;
    validate_nonce(&nonce)?;
    prepare_snapshots(paths, plan, &nonce)?;
    prepare_vendors(paths, plan, &nonce)?;
    let scope_key = paths.scope_key();
    let trust_only = !plan.actions.is_empty()
        && plan.actions.iter().all(|action| {
            matches!(
                action,
                Action::ReplaceTrust { change, .. }
                    if *change != crate::TrustChange::GrantVendor
            )
        });
    let mut locks = LockCoordinator::new();
    for alias in candidate_lock_aliases(plan)? {
        locks.acquire(
            &paths.candidate_lock_path(&scope_key, &alias),
            LockRank::Candidate,
            LockMode::Exclusive,
        )?;
    }
    locks.acquire(&paths.store_lock_path(), LockRank::Store, LockMode::Shared)?;
    locks.acquire(
        &paths.trust_lock_path(),
        LockRank::Trust,
        if plan
            .actions
            .iter()
            .any(|action| matches!(action, Action::ReplaceTrust { .. }))
        {
            LockMode::Exclusive
        } else {
            LockMode::Shared
        },
    )?;
    if !trust_only && matches!(paths.scope, ScopePaths::Project { .. }) {
        locks.acquire(
            &paths.projects_lock_path(),
            LockRank::Projects,
            LockMode::Exclusive,
        )?;
    }
    if !trust_only {
        locks.acquire(
            &paths.scope_lock_path(&scope_key),
            LockRank::Scope,
            LockMode::Exclusive,
        )?;
    }
    if let Err(error) = validate_preconditions(paths, plan, !trust_only)
        .and_then(|()| validate_store_preconditions(paths, plan))
    {
        cleanup_unjournaled_vendor_preparations(paths, plan, &nonce)?;
        return Err(error);
    }
    if trust_only {
        let mut changed = false;
        for action in &plan.actions {
            if let Action::ReplaceTrust {
                after, create_mode, ..
            } = action
            {
                if checkpoint(runtime, "before-standalone-trust")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "before-standalone-trust".into(),
                    });
                }
                replace(&paths.trust_path(), after, &nonce, Some(*create_mode))?;
                if checkpoint(runtime, "after-standalone-trust")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "after-standalone-trust".into(),
                    });
                }
                changed = true;
            }
        }
        return Ok(ApplyOutcome::Applied { changed });
    }
    let journal_path = paths.transaction_journal_path(&scope_key);
    if journal_path.exists() {
        return Err(CoreError::RecoveryRequired(format!(
            "pending transaction at {}",
            journal_path.display()
        )));
    }
    let journal = build_journal(paths, plan, &scope_key, &nonce)?;
    write_new(&journal_path, &journal.to_bytes()?, Some(0o600))?;
    if checkpoint(runtime, "journal-created")? {
        return Ok(ApplyOutcome::Interrupted {
            checkpoint: "journal-created".into(),
        });
    }

    let parent_identity = plan.actions.iter().any(|action| {
        matches!(
            action,
            Action::CreateLink { .. }
                | Action::RetainLink { .. }
                | Action::RepointLink { .. }
                | Action::RemoveLink { .. }
        )
    });
    let parent_identity = parent_identity
        .then(|| DirectoryIdentity::capture_or_create(&paths.skills_dir()))
        .transpose()?;
    let vendor_sources = plan
        .actions
        .iter()
        .filter_map(|action| match action {
            Action::CreateVendor { source, .. }
            | Action::ReplaceVendor { source, .. }
            | Action::RetainVendor { source, .. }
            | Action::RemoveVendor { source, .. } => Some(source.clone()),
            _ => None,
        })
        .collect::<std::collections::BTreeSet<_>>();
    let vendor_parents = vendor_sources
        .into_iter()
        .map(|source| {
            let parent = ensure_vendor_source_dir(paths, &source)?;
            Ok((source, parent))
        })
        .collect::<Result<std::collections::BTreeMap<_, _>>>()?;
    match execute(
        paths,
        plan,
        runtime,
        &journal_path,
        journal,
        parent_identity.as_ref(),
        &vendor_parents,
    ) {
        Ok(outcome) => Ok(outcome),
        Err(error) => {
            let bytes = read_required_bounded(&journal_path, STATE_LIMIT).map_err(|rollback| {
                CoreError::RecoveryRequired(format!(
                    "{error}; cannot read rollback journal: {rollback}"
                ))
            })?;
            let journal = Journal::from_bytes(&bytes)?;
            if journal.committed {
                return Err(CoreError::RecoveryRequired(format!(
                    "{error}; committed transaction requires project-index recovery"
                )));
            }
            if matches!(error, CoreError::StalePlan(_)) && journal.completed.is_empty() {
                cleanup_captured_vendors(paths, &journal)?;
                remove_file_if_present(&journal_path)?;
                if let Some(parent) = journal_path.parent() {
                    sync_directory(parent)?;
                }
                return Err(error);
            }
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

fn cleanup_unjournaled_vendor_preparations(paths: &Paths, plan: &Plan, nonce: &str) -> Result<()> {
    for action in &plan.actions {
        let Action::PrepareVendor {
            source,
            skill,
            content,
            ..
        } = action
        else {
            continue;
        };
        let parent = ensure_vendor_source_dir(paths, source)?;
        let prepared = paths.vendor_prepare_path(source, skill, nonce)?;
        remove_verified_vendor(&parent, &prepared, skill, Some(content))?;
    }
    Ok(())
}

fn preflight(paths: &Paths, plan: &Plan) -> Result<()> {
    let expected_scope = match paths.scope {
        ScopePaths::Project { .. } => Scope::Project,
        ScopePaths::Global { .. } => Scope::Global,
    };
    for action in &plan.actions {
        let scope = match action {
            Action::PrepareSnapshot { scope, .. }
            | Action::PrepareVendor { scope, .. }
            | Action::CreateVendor { scope, .. }
            | Action::ReplaceVendor { scope, .. }
            | Action::RetainVendor { scope, .. }
            | Action::RemoveVendor { scope, .. }
            | Action::ReplaceCandidate { scope, .. }
            | Action::RemoveCandidate { scope, .. }
            | Action::CreateManifest { scope, .. }
            | Action::ReplaceManifest { scope, .. }
            | Action::CreateLock { scope, .. }
            | Action::ReplaceLock { scope, .. }
            | Action::CreateLink { scope, .. }
            | Action::RetainLink { scope, .. }
            | Action::RepointLink { scope, .. }
            | Action::RemoveLink { scope, .. } => *scope,
            Action::PruneSnapshot { .. } => {
                if !matches!(paths.scope, ScopePaths::Global { .. }) {
                    return Err(CoreError::Transaction(
                        "prune action requires global resolved paths".into(),
                    ));
                }
                continue;
            }
            Action::ReplaceTrust { .. } => continue,
        };
        if scope != expected_scope {
            return Err(CoreError::Transaction(
                "plan action belongs to a different scope".into(),
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
        match action {
            Action::PrepareVendor {
                source,
                skill,
                path,
                content,
                skill_path,
                ..
            } => {
                validate_vendor_action_path(paths, source, skill, path)?;
                validate_content_digest(content)?;
                validate_relative_skill_path(skill_path)?;
            }
            Action::CreateVendor {
                source,
                skill,
                path,
                after: content,
                ..
            }
            | Action::RetainVendor {
                source,
                skill,
                path,
                content,
                ..
            } => {
                validate_vendor_action_path(paths, source, skill, path)?;
                validate_content_digest(content)?;
            }
            Action::ReplaceVendor {
                source,
                skill,
                path,
                before,
                after,
                ..
            } => {
                validate_vendor_action_path(paths, source, skill, path)?;
                validate_content_digest(before)?;
                validate_content_digest(after)?;
            }
            Action::RemoveVendor {
                source,
                skill,
                path,
                before,
                ..
            } => {
                validate_vendor_action_path(paths, source, skill, path)?;
                validate_content_digest(before)?;
            }
            _ => {}
        }
    }
    Ok(())
}

fn validate_vendor_action_path(
    paths: &Paths,
    source: &crate::SourceAlias,
    skill: &crate::SkillName,
    relative: &str,
) -> Result<()> {
    let expected = format!("vendor/grimoire/{source}/{skill}");
    if relative != expected || paths.vendor_path(source, skill)?.is_relative() {
        return Err(CoreError::Transaction(
            "vendor action path is not the exact derived project path".into(),
        ));
    }
    Ok(())
}

fn validate_relative_skill_path(path: &str) -> Result<()> {
    let path = Path::new(path);
    if path.as_os_str().is_empty()
        || path.is_absolute()
        || path
            .components()
            .any(|component| !matches!(component, std::path::Component::Normal(_)))
    {
        return Err(CoreError::Transaction(
            "vendor store skill path is not normalized and relative".into(),
        ));
    }
    Ok(())
}

fn prepare_vendors(paths: &Paths, plan: &Plan, nonce: &str) -> Result<()> {
    let needs_vendor = plan
        .actions
        .iter()
        .any(|action| matches!(action, Action::PrepareVendor { .. }));
    let mut locks = LockCoordinator::new();
    if needs_vendor {
        locks.acquire(&paths.store_lock_path(), LockRank::Store, LockMode::Shared)?;
    }
    let prepared = (|| {
        for action in &plan.actions {
            let Action::PrepareVendor {
                source,
                skill,
                source_key,
                snapshot_key,
                skill_path,
                content,
                ..
            } = action
            else {
                continue;
            };
            let parent = ensure_vendor_source_dir(paths, source)?;
            let prepared = paths.vendor_prepare_path(source, skill, nonce)?;
            let prepared_name = file_name(&prepared)?;
            let store_skill = paths.store_path(source_key, snapshot_key).join(skill_path);
            parent.revalidate(&paths.vendor_source_dir(source)?)?;
            crate::vendor::prepare_from_store(
                &store_skill,
                &parent.descriptor,
                &prepared_name,
                &prepared,
                skill,
                content,
            )?;
            if let Err(error) = parent.revalidate(&paths.vendor_source_dir(source)?) {
                remove_verified_vendor(&parent, &prepared, skill, Some(content))?;
                return Err(error);
            }
        }
        Ok(())
    })();
    if let Err(error) = prepared {
        cleanup_unjournaled_vendor_preparations(paths, plan, nonce).map_err(|cleanup| {
            CoreError::RecoveryRequired(format!(
                "{error}; vendor preparation cleanup failed: {cleanup}"
            ))
        })?;
        return Err(error);
    }
    Ok(())
}

fn prepare_snapshots(paths: &Paths, plan: &Plan, nonce: &str) -> Result<()> {
    for action in &plan.actions {
        let Action::PrepareSnapshot {
            source,
            source_key,
            snapshot_key,
            review_key,
            operation,
            ..
        } = action
        else {
            continue;
        };
        let source_key = crate::SourceKey::parse(source_key.clone())?;
        let snapshot_key = crate::SnapshotKey::parse(snapshot_key.clone())?;
        let review_key = crate::ReviewKey::parse(review_key.clone())?;
        let export = crate::source::ReviewExport::load_for_keys(
            &paths.review_cache_dir(),
            &source_key,
            &review_key,
        )?;
        let intent = crate::store::MaterializationIntent::from_action(action, export.clone())?;
        let destination = paths.store_path(&source_key, &snapshot_key);
        let observed = crate::store::observe(&destination, &export);
        let expected = plan.preconditions.stores.get(source).ok_or_else(|| {
            CoreError::Transaction(format!(
                "snapshot preparation for `{source}` has no store precondition"
            ))
        })?;
        let observed = match observed {
            crate::store::StoreObservation::Absent => crate::SnapshotStore::Absent,
            crate::store::StoreObservation::Valid => crate::SnapshotStore::Valid,
            crate::store::StoreObservation::Corrupt => crate::SnapshotStore::Corrupt,
        };
        if source_key != expected.source_key || snapshot_key != expected.snapshot_key {
            return Err(CoreError::Transaction(format!(
                "snapshot preparation for `{source}` disagrees with its store precondition"
            )));
        }
        if observed != expected.state {
            return Err(CoreError::StalePlan(format!(
                "store snapshot for `{source}` changed"
            )));
        }
        match operation {
            crate::SnapshotPreparation::Materialize => {
                crate::store::materialize(&paths.grimoire_home.join("store/checkouts"), &intent)?;
            }
            crate::SnapshotPreparation::Repair => {
                crate::store::repair(&paths.grimoire_home, &intent, nonce)?;
            }
        }
        if crate::store::observe(&destination, &export) != crate::store::StoreObservation::Valid {
            return Err(CoreError::Store(
                "snapshot preparation did not produce a valid immutable store entry".into(),
            ));
        }
    }
    Ok(())
}

fn validate_preconditions(paths: &Paths, plan: &Plan, include_scope: bool) -> Result<()> {
    if include_scope {
        validate_file_hash(
            &paths.manifest_path(),
            plan.preconditions.manifest.as_ref(),
            "manifest",
        )?;
        validate_file_hash(&paths.lock_path(), plan.preconditions.lock.as_ref(), "lock")?;
    }
    validate_file_hash(
        &paths.trust_path(),
        plan.preconditions.trust.as_ref(),
        "trust",
    )?;
    if include_scope && matches!(paths.scope, ScopePaths::Project { .. }) {
        validate_file_hash(
            &paths.projects_path(),
            plan.preconditions.projects.as_ref(),
            "project index",
        )?;
    }
    for (alias, expected) in &plan.preconditions.candidates {
        validate_file_hash(
            &paths.candidate_path(&paths.scope_key(), alias),
            expected.as_ref(),
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
    if include_scope && !plan.preconditions.vendors.is_empty() {
        let lock_bytes = read_required_bounded(&paths.lock_path(), STATE_LIMIT)?;
        let lock = crate::Lockfile::parse(&lock_bytes)?;
        for (skill, expected) in &plan.preconditions.vendors {
            let incumbent = lock
                .skills
                .get(skill)
                .filter(|entry| entry.mode == crate::ProjectionMode::Vendor);
            let source = incumbent
                .map(|entry| &entry.source)
                .or_else(|| vendor_action_source(plan, skill))
                .ok_or_else(|| {
                    CoreError::Transaction(format!(
                        "vendor precondition for `{skill}` has no derived source"
                    ))
                })?;
            let actual = crate::vendor::observe_vendor_at(paths, source, skill, incumbent)?;
            if &actual != expected {
                return Err(CoreError::StalePlan(format!(
                    "vendor tree `{skill}` changed"
                )));
            }
        }
    }
    Ok(())
}

fn vendor_action_source<'a>(
    plan: &'a Plan,
    skill: &crate::SkillName,
) -> Option<&'a crate::SourceAlias> {
    plan.actions.iter().find_map(|action| match action {
        Action::PrepareVendor {
            source,
            skill: candidate,
            ..
        }
        | Action::CreateVendor {
            source,
            skill: candidate,
            ..
        }
        | Action::ReplaceVendor {
            source,
            skill: candidate,
            ..
        }
        | Action::RetainVendor {
            source,
            skill: candidate,
            ..
        }
        | Action::RemoveVendor {
            source,
            skill: candidate,
            ..
        } if candidate == skill => Some(source),
        _ => None,
    })
}

fn validate_store_preconditions(paths: &Paths, plan: &Plan) -> Result<()> {
    for (alias, expected) in &plan.preconditions.stores {
        let prepared = plan.actions.iter().any(
            |action| matches!(action, Action::PrepareSnapshot { source, .. } if source == alias),
        );
        let root = paths.store_path(&expected.source_key, &expected.snapshot_key);
        let observed = match fs::symlink_metadata(&root) {
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                crate::SnapshotStore::Absent
            }
            Err(error) => return Err(crate::transaction::io_error(&root, error)),
            Ok(metadata) if !metadata.is_dir() || metadata.file_type().is_symlink() => {
                crate::SnapshotStore::Corrupt
            }
            Ok(_) => match crate::source::HeldDirectoryReader::open(&root).and_then(|reader| {
                crate::inventory::scan(&reader).map_err(|error| {
                    CoreError::Store(format!("cannot scan store snapshot: {error}"))
                })
            }) {
                Ok(inventory) if inventory.inventory_digest.to_string() == expected.inventory => {
                    crate::SnapshotStore::Valid
                }
                Ok(_) | Err(_) => crate::SnapshotStore::Corrupt,
            },
        };
        let required = if prepared {
            crate::SnapshotStore::Valid
        } else {
            expected.state
        };
        if observed != required {
            return Err(CoreError::StalePlan(format!(
                "store snapshot for `{alias}` changed"
            )));
        }
    }
    Ok(())
}

fn validate_action_shapes(plan: &Plan) -> Result<()> {
    let has_prune = plan.preconditions.reachability.is_some()
        || plan
            .actions
            .iter()
            .any(|action| matches!(action, Action::PruneSnapshot { .. }));
    if has_prune
        && (plan.preconditions.reachability.is_none()
            || plan
                .actions
                .iter()
                .any(|action| !matches!(action, Action::PruneSnapshot { .. })))
    {
        return Err(CoreError::Transaction(
            "prune actions cannot be mixed with scope transaction actions".into(),
        ));
    }
    let candidate_actions = plan
        .actions
        .iter()
        .filter(|action| {
            matches!(
                action,
                Action::ReplaceCandidate { .. } | Action::RemoveCandidate { .. }
            )
        })
        .count();
    if candidate_actions > 1 {
        return Err(CoreError::Transaction(
            "one plan cannot mutate more than one candidate".into(),
        ));
    }
    let preparations = plan
        .actions
        .iter()
        .filter_map(|action| match action {
            Action::PrepareVendor {
                source,
                skill,
                content,
                ..
            } => Some(((source.clone(), skill.clone()), content.as_str())),
            _ => None,
        })
        .collect::<std::collections::BTreeMap<_, _>>();
    for action in &plan.actions {
        match action {
            Action::CreateVendor {
                source,
                skill,
                after,
                added,
                ..
            }
            | Action::ReplaceVendor {
                source,
                skill,
                after,
                added,
                ..
            } => {
                if preparations.get(&(source.clone(), skill.clone())).copied()
                    != Some(after.as_str())
                {
                    return Err(CoreError::Transaction(format!(
                        "vendor publication for `{skill}` lacks its exact preparation"
                    )));
                }
                validate_sorted_unique(added, "vendor added paths")?;
            }
            Action::RemoveVendor { removed, .. } => {
                validate_sorted_unique(removed, "vendor removed paths")?;
            }
            _ => {}
        }
        if let Action::ReplaceVendor {
            removed, changed, ..
        } = action
        {
            validate_sorted_unique(removed, "vendor removed paths")?;
            validate_sorted_unique(changed, "vendor changed paths")?;
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
            Action::ReplaceTrust { after, .. } => {
                crate::TrustStore::parse(after)?;
            }
            Action::ReplaceCandidate {
                source_key, after, ..
            } => {
                crate::CandidateRecord::parse(after, Some(source_key))?;
            }
            Action::RemoveCandidate {
                source_key, before, ..
            } => {
                crate::CandidateRecord::parse(before, Some(source_key))?;
            }
            _ => {}
        }
    }
    Ok(())
}

fn validate_sorted_unique(values: &[String], name: &str) -> Result<()> {
    if values.windows(2).all(|pair| pair[0] < pair[1]) {
        Ok(())
    } else {
        Err(CoreError::Transaction(format!(
            "{name} are not strictly sorted"
        )))
    }
}

fn build_journal(paths: &Paths, plan: &Plan, scope_key: &str, nonce: &str) -> Result<Journal> {
    let mut state = Vec::new();
    let mut vendors = Vec::new();
    let mut links = Vec::new();
    for action in &plan.actions {
        match action {
            Action::CreateManifest { after, .. } => state.push(StateTransition {
                name: StateName::Manifest,
                alias: None,
                source_key: None,
                before: None,
                after: Some(after.clone()),
            }),
            Action::ReplaceManifest { before, after, .. } => state.push(StateTransition {
                name: StateName::Manifest,
                alias: None,
                source_key: None,
                before: Some(before.clone()),
                after: Some(after.clone()),
            }),
            Action::CreateLock { after, .. } => state.push(StateTransition {
                name: StateName::Lock,
                alias: None,
                source_key: None,
                before: None,
                after: Some(after.clone()),
            }),
            Action::ReplaceLock { before, after, .. } => state.push(StateTransition {
                name: StateName::Lock,
                alias: None,
                source_key: None,
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
            Action::ReplaceTrust { before, after, .. } => state.push(StateTransition {
                name: StateName::Trust,
                alias: None,
                source_key: None,
                before: before.clone(),
                after: Some(after.clone()),
            }),
            Action::ReplaceCandidate {
                alias,
                source_key,
                before,
                after,
                ..
            } => state.push(StateTransition {
                name: StateName::Candidate,
                alias: Some(alias.to_string()),
                source_key: Some(source_key.to_string()),
                before: before.clone(),
                after: Some(after.clone()),
            }),
            Action::RemoveCandidate {
                alias,
                source_key,
                before,
                ..
            } => state.push(StateTransition {
                name: StateName::Candidate,
                alias: Some(alias.to_string()),
                source_key: Some(source_key.to_string()),
                before: Some(before.clone()),
                after: None,
            }),
            Action::PrepareSnapshot { .. } => {}
            Action::PrepareVendor { .. } | Action::RetainVendor { .. } => {}
            Action::CreateVendor {
                source,
                skill,
                after,
                ..
            } => vendors.push(VendorTransition {
                source: source.to_string(),
                skill: skill.to_string(),
                before: None,
                after: Some(after.clone()),
            }),
            Action::ReplaceVendor {
                source,
                skill,
                before,
                after,
                ..
            } => vendors.push(VendorTransition {
                source: source.to_string(),
                skill: skill.to_string(),
                before: Some(before.clone()),
                after: Some(after.clone()),
            }),
            Action::RemoveVendor {
                source,
                skill,
                before,
                ..
            } => vendors.push(VendorTransition {
                source: source.to_string(),
                skill: skill.to_string(),
                before: Some(before.clone()),
                after: None,
            }),
            Action::PruneSnapshot { .. } => unreachable!("separate prune transaction"),
        }
    }
    state.sort_by_key(|transition| state_order(transition.name));
    vendors.sort_by(|left, right| (&left.source, &left.skill).cmp(&(&right.source, &right.skill)));
    links.sort_by(|left, right| left.skill.cmp(&right.skill));
    let plan_digest = format!("{:x}", Sha256::digest(plan.to_bytes()?));
    Ok(Journal {
        schema: JOURNAL_SCHEMA.into(),
        scope_key: scope_key.into(),
        nonce: nonce.into(),
        plan_digest,
        committed: false,
        state,
        vendors,
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
    parent_identity: Option<&DirectoryIdentity>,
    vendor_parents: &std::collections::BTreeMap<crate::SourceAlias, DirectoryIdentity>,
) -> Result<ApplyOutcome> {
    let mut changed = false;
    for action in &plan.actions {
        match action {
            Action::RetainVendor {
                source,
                skill,
                content,
                ..
            } => {
                let parent = vendor_parents
                    .get(source)
                    .expect("vendor action has parent identity");
                require_vendor(paths, parent, source, skill, Some(content))?;
            }
            Action::CreateVendor { source, skill, .. }
            | Action::ReplaceVendor { source, skill, .. } => {
                let parent = vendor_parents
                    .get(source)
                    .expect("vendor action has parent identity");
                if let Some(checkpoint) =
                    publish_vendor(paths, parent, action, &journal.nonce, runtime)?
                {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: checkpoint.into(),
                    });
                }
                if mark(
                    runtime,
                    journal_path,
                    &mut journal,
                    &format!("vendor:{source}:{skill}"),
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
    for action in &plan.actions {
        match action {
            Action::RetainLink { skill, target, .. } => {
                let expected = target.resolve(paths)?;
                require_link(&paths.skills_dir().join(skill.as_str()), Some(&expected))?;
            }
            Action::CreateLink { skill, target, .. } => {
                let destination = paths.skills_dir().join(skill.as_str());
                let parent_identity = parent_identity.expect("link action has parent identity");
                parent_identity.revalidate(&paths.skills_dir())?;
                if checkpoint(runtime, "before-link-ownership")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "before-link-ownership".into(),
                    });
                }
                parent_identity.revalidate(&paths.skills_dir())?;
                require_link(&destination, None)?;
                if checkpoint(runtime, "before-link-mutation")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "before-link-mutation".into(),
                    });
                }
                parent_identity.create_link(
                    skill.as_str(),
                    &target.resolve(paths)?,
                    &destination,
                )?;
                if checkpoint(runtime, "after-link-mutation")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "after-link-mutation".into(),
                    });
                }
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
                let parent_identity = parent_identity.expect("link action has parent identity");
                parent_identity.revalidate(&paths.skills_dir())?;
                require_link(&destination, Some(&before.resolve(paths)?))?;
                if checkpoint(runtime, "before-link-mutation")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "before-link-mutation".into(),
                    });
                }
                parent_identity.replace_owned_link(
                    skill.as_str(),
                    &before.resolve(paths)?,
                    &after.resolve(paths)?,
                    &journal.nonce,
                    &destination,
                )?;
                if checkpoint(runtime, "after-link-mutation")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "after-link-mutation".into(),
                    });
                }
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
                let parent_identity = parent_identity.expect("link action has parent identity");
                parent_identity.revalidate(&paths.skills_dir())?;
                require_link(&destination, Some(&target.resolve(paths)?))?;
                if checkpoint(runtime, "before-link-mutation")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "before-link-mutation".into(),
                    });
                }
                parent_identity.remove_owned_link(
                    skill.as_str(),
                    &target.resolve(paths)?,
                    &journal.nonce,
                    &destination,
                )?;
                if checkpoint(runtime, "after-link-mutation")? {
                    return Ok(ApplyOutcome::Interrupted {
                        checkpoint: "after-link-mutation".into(),
                    });
                }
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
    for action in &plan.actions {
        let Action::RemoveVendor {
            source,
            skill,
            before,
            ..
        } = action
        else {
            continue;
        };
        let parent = vendor_parents
            .get(source)
            .expect("vendor action has parent identity");
        if let Some(checkpoint) = capture_vendor(
            paths,
            parent,
            source,
            skill,
            before,
            &journal.nonce,
            runtime,
        )? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: checkpoint.into(),
            });
        }
        if mark(
            runtime,
            journal_path,
            &mut journal,
            &format!("vendor:{source}:{skill}"),
        )? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "action-marked".into(),
            });
        }
        changed = true;
    }
    for state in journal.state.clone() {
        let path = state_path(paths, &state)?;
        if checkpoint(runtime, "before-state-mutation")? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "before-state-mutation".into(),
            });
        }
        match &state.after {
            Some(bytes) => replace(
                &path,
                bytes,
                &journal.nonce,
                matches!(state.name, StateName::Trust | StateName::Candidate).then_some(0o600),
            )?,
            None => remove_file_if_present(&path)?,
        }
        if checkpoint(runtime, "after-state-mutation")? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "after-state-mutation".into(),
            });
        }
        if mark(runtime, journal_path, &mut journal, state_name(state.name))? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "action-marked".into(),
            });
        }
        changed = true;
    }
    if checkpoint(runtime, "before-commit-marker")? {
        return Ok(ApplyOutcome::Interrupted {
            checkpoint: "before-commit-marker".into(),
        });
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
    if matches!(paths.scope, ScopePaths::Project { .. }) {
        if checkpoint(runtime, "before-project-refresh")? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "before-project-refresh".into(),
            });
        }
        refresh_project_index(paths, runtime, &journal.nonce)?;
        if checkpoint(runtime, "after-project-refresh")? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "after-project-refresh".into(),
            });
        }
    }
    if checkpoint(runtime, "before-cleanup")? {
        return Ok(ApplyOutcome::Interrupted {
            checkpoint: "before-cleanup".into(),
        });
    }
    cleanup_captured_vendors(paths, &journal)?;
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

fn publish_vendor(
    paths: &Paths,
    parent: &DirectoryIdentity,
    action: &Action,
    nonce: &str,
    runtime: &dyn TransactionRuntime,
) -> Result<Option<&'static str>> {
    let (source, skill, before, after) = match action {
        Action::CreateVendor {
            source,
            skill,
            after,
            ..
        } => (source, skill, None, after.as_str()),
        Action::ReplaceVendor {
            source,
            skill,
            before,
            after,
            ..
        } => (source, skill, Some(before.as_str()), after.as_str()),
        _ => unreachable!("publication helper received a non-publication action"),
    };
    let parent_path = paths.vendor_source_dir(source)?;
    let destination = paths.vendor_path(source, skill)?;
    let prepared = paths.vendor_prepare_path(source, skill, nonce)?;
    let prepared_name = file_name(&prepared)?;
    let capture = paths.vendor_capture_path(source, skill, nonce)?;
    let capture_name = file_name(&capture)?;
    parent.revalidate(&parent_path)?;
    if crate::vendor::verify_vendor_tree_at(&parent.descriptor, &prepared_name, &prepared, skill)?
        != after
    {
        return Err(CoreError::StalePlan(format!(
            "prepared vendor tree `{skill}` changed"
        )));
    }
    require_vendor(paths, parent, source, skill, before)?;
    if let Some(before) = before {
        if checkpoint(runtime, "before-vendor-capture")? {
            return Ok(Some("before-vendor-capture"));
        }
        parent.rename_no_replace(skill.as_str(), &capture_name, &destination)?;
        let captured = crate::vendor::verify_vendor_tree_at(
            &parent.descriptor,
            &capture_name,
            &capture,
            skill,
        )?;
        if captured != before {
            parent.rename_no_replace(&capture_name, skill.as_str(), &destination)?;
            return Err(CoreError::StalePlan(format!(
                "vendor tree `{skill}` changed during capture"
            )));
        }
        if checkpoint(runtime, "after-vendor-capture")? {
            return Ok(Some("after-vendor-capture"));
        }
    }
    if checkpoint(runtime, "before-vendor-publication")? {
        return Ok(Some("before-vendor-publication"));
    }
    if let Err(error) = parent.rename_no_replace(&prepared_name, skill.as_str(), &destination) {
        if before.is_some()
            && parent
                .entry_identity(skill.as_str(), &destination)?
                .is_none()
            && parent.entry_identity(&capture_name, &capture)?.is_some()
        {
            let _ = parent.rename_no_replace(&capture_name, skill.as_str(), &destination);
        }
        return Err(error);
    }
    let observed = crate::vendor::verify_vendor_tree_at(
        &parent.descriptor,
        skill.as_str(),
        &destination,
        skill,
    )?;
    if observed != after {
        return Err(CoreError::RecoveryRequired(format!(
            "published vendor tree `{skill}` does not match its journal digest"
        )));
    }
    if checkpoint(runtime, "after-vendor-publication")? {
        return Ok(Some("after-vendor-publication"));
    }
    Ok(None)
}

fn capture_vendor(
    paths: &Paths,
    parent: &DirectoryIdentity,
    source: &crate::SourceAlias,
    skill: &crate::SkillName,
    before: &str,
    nonce: &str,
    runtime: &dyn TransactionRuntime,
) -> Result<Option<&'static str>> {
    let parent_path = paths.vendor_source_dir(source)?;
    let destination = paths.vendor_path(source, skill)?;
    let capture = paths.vendor_capture_path(source, skill, nonce)?;
    let capture_name = file_name(&capture)?;
    parent.revalidate(&parent_path)?;
    require_vendor(paths, parent, source, skill, Some(before))?;
    if checkpoint(runtime, "before-vendor-capture")? {
        return Ok(Some("before-vendor-capture"));
    }
    parent.rename_no_replace(skill.as_str(), &capture_name, &destination)?;
    if crate::vendor::verify_vendor_tree_at(&parent.descriptor, &capture_name, &capture, skill)?
        != before
    {
        parent.rename_no_replace(&capture_name, skill.as_str(), &destination)?;
        return Err(CoreError::StalePlan(format!(
            "vendor tree `{skill}` changed during capture"
        )));
    }
    if checkpoint(runtime, "after-vendor-capture")? {
        return Ok(Some("after-vendor-capture"));
    }
    Ok(None)
}

fn require_vendor(
    paths: &Paths,
    parent: &DirectoryIdentity,
    source: &crate::SourceAlias,
    skill: &crate::SkillName,
    expected: Option<&str>,
) -> Result<()> {
    let path = paths.vendor_path(source, skill)?;
    parent.revalidate(&paths.vendor_source_dir(source)?)?;
    match (parent.entry_identity(skill.as_str(), &path)?, expected) {
        (None, None) => Ok(()),
        (Some((_, _, 0o040000)), Some(expected)) => {
            let observed = crate::vendor::verify_vendor_tree_at(
                &parent.descriptor,
                skill.as_str(),
                &path,
                skill,
            )
            .map_err(|_| CoreError::StalePlan(format!("vendor tree `{skill}` changed")))?;
            if observed == expected {
                Ok(())
            } else {
                Err(CoreError::StalePlan(format!(
                    "vendor tree `{skill}` changed"
                )))
            }
        }
        _ => Err(CoreError::StalePlan(format!(
            "vendor tree `{skill}` changed"
        ))),
    }
}

fn file_name(path: &Path) -> Result<String> {
    path.file_name()
        .and_then(|name| name.to_str())
        .map(str::to_owned)
        .ok_or_else(|| CoreError::Transaction("transaction path has no UTF-8 basename".into()))
}

fn rollback(paths: &Paths, journal: &Journal, nonce: &str) -> Result<()> {
    restore_before(paths, journal, nonce)
}

fn restore_before(paths: &Paths, journal: &Journal, nonce: &str) -> Result<()> {
    let parent_identity = (!journal.links.is_empty())
        .then(|| DirectoryIdentity::capture_or_create(&paths.skills_dir()))
        .transpose()?;
    for link in journal.links.iter().rev() {
        let destination = paths.skills_dir().join(&link.skill);
        let actual = match observe_link(&destination)? {
            LinkPrecondition::Absent => None,
            LinkPrecondition::Symlink(target) => Some(path_bytes(&target)),
            // A concurrent owner may replace an entry while another link in
            // the same transaction is being applied. Roll back our changes,
            // but never move or remove that foreign entry.
            LinkPrecondition::File | LinkPrecondition::Directory => continue,
        };
        if actual == link.before {
            let parent = parent_identity
                .as_ref()
                .expect("link recovery has parent identity");
            if let Some(after) = &link.after {
                parent.cleanup_capture_if_owned(
                    &format!(".{}.{}.link-swap", link.skill, nonce),
                    &bytes_path(after),
                    &destination,
                )?;
            }
            if let Some(removed) = link.before.as_ref().or(link.after.as_ref()) {
                parent.cleanup_capture_if_owned(
                    &format!(".{}.{}.link-remove", link.skill, nonce),
                    &bytes_path(removed),
                    &destination,
                )?;
            }
            continue;
        }
        if actual != link.after {
            continue;
        }
        match &link.before {
            Some(raw) => match &link.after {
                Some(after) => parent_identity
                    .as_ref()
                    .expect("link recovery has parent identity")
                    .restore_repointed_link(
                        &link.skill,
                        &bytes_path(after),
                        &bytes_path(raw),
                        nonce,
                        &destination,
                    )?,
                None => parent_identity
                    .as_ref()
                    .expect("link recovery has parent identity")
                    .restore_removed_link(&link.skill, &bytes_path(raw), nonce, &destination)?,
            },
            None => parent_identity
                .as_ref()
                .expect("link recovery has parent identity")
                .remove_owned_link(
                    &link.skill,
                    &bytes_path(link.after.as_ref().expect("created link has after target")),
                    nonce,
                    &destination,
                )?,
        }
    }
    for vendor in journal.vendors.iter().rev() {
        restore_vendor_before(paths, vendor, nonce)?;
    }
    for state in journal.state.iter().rev() {
        let actual = current_state(paths, state)?;
        if actual == state.before {
            continue;
        }
        if actual != state.after {
            return Err(CoreError::RecoveryRequired(format!(
                "{} is neither recorded before nor after state",
                state_name(state.name)
            )));
        }
        let path = state_path(paths, state)?;
        match &state.before {
            Some(bytes) => replace(
                &path,
                bytes,
                nonce,
                matches!(state.name, StateName::Trust | StateName::Candidate).then_some(0o600),
            )?,
            None => remove_file_if_present(&path)?,
        }
    }
    Ok(())
}

fn restore_vendor_before(paths: &Paths, vendor: &VendorTransition, nonce: &str) -> Result<()> {
    let source = crate::SourceAlias::new(&vendor.source)?;
    let skill = crate::SkillName::new(&vendor.skill)?;
    let parent = ensure_vendor_source_dir(paths, &source)?;
    let destination = paths.vendor_path(&source, &skill)?;
    let capture = paths.vendor_capture_path(&source, &skill, nonce)?;
    let prepared = paths.vendor_prepare_path(&source, &skill, nonce)?;
    let capture_name = file_name(&capture)?;
    let prepared_name = file_name(&prepared)?;
    let current = current_vendor_at(paths, &parent, vendor)?;
    let before = VendorOccupancy::from(&vendor.before);
    let after = VendorOccupancy::from(&vendor.after);

    if current == before {
        remove_verified_vendor(&parent, &prepared, &skill, vendor.after.as_deref())?;
        remove_verified_vendor(&parent, &capture, &skill, vendor.before.as_deref())?;
        return Ok(());
    }
    if current != after && current != VendorOccupancy::Absent {
        return Err(CoreError::RecoveryRequired(format!(
            "foreign replacement occupies vendor path `{}`",
            destination.display()
        )));
    }
    match (&vendor.before, &vendor.after) {
        (None, Some(after)) => {
            if current == VendorOccupancy::Digest(after.clone()) {
                parent.rename_no_replace(skill.as_str(), &prepared_name, &destination)?;
                remove_verified_vendor(&parent, &prepared, &skill, Some(after))?;
            } else {
                remove_verified_vendor(&parent, &prepared, &skill, Some(after))?;
            }
        }
        (Some(before), Some(after)) => {
            if current == VendorOccupancy::Digest(after.clone()) {
                parent.rename_no_replace(skill.as_str(), &prepared_name, &destination)?;
                if crate::vendor::verify_vendor_tree_at(
                    &parent.descriptor,
                    &prepared_name,
                    &prepared,
                    &skill,
                )? != *after
                {
                    let _ = parent.rename_no_replace(&prepared_name, skill.as_str(), &destination);
                    return Err(CoreError::RecoveryRequired(format!(
                        "published vendor `{skill}` changed during rollback"
                    )));
                }
            }
            if parent.entry_identity(&capture_name, &capture)?.is_some()
                && parent
                    .entry_identity(skill.as_str(), &destination)?
                    .is_none()
            {
                if crate::vendor::verify_vendor_tree_at(
                    &parent.descriptor,
                    &capture_name,
                    &capture,
                    &skill,
                )? != *before
                {
                    return Err(CoreError::RecoveryRequired(format!(
                        "captured vendor `{skill}` changed during rollback"
                    )));
                }
                parent.rename_no_replace(&capture_name, skill.as_str(), &destination)?;
            }
            remove_verified_vendor(&parent, &prepared, &skill, Some(after))?;
        }
        (Some(before), None) => {
            if parent.entry_identity(&capture_name, &capture)?.is_some()
                && parent
                    .entry_identity(skill.as_str(), &destination)?
                    .is_none()
            {
                if crate::vendor::verify_vendor_tree_at(
                    &parent.descriptor,
                    &capture_name,
                    &capture,
                    &skill,
                )? != *before
                {
                    return Err(CoreError::RecoveryRequired(format!(
                        "captured vendor `{skill}` changed during rollback"
                    )));
                }
                parent.rename_no_replace(&capture_name, skill.as_str(), &destination)?;
            }
        }
        (None, None) => {}
    }
    Ok(())
}

fn cleanup_captured_vendors(paths: &Paths, journal: &Journal) -> Result<()> {
    for vendor in &journal.vendors {
        let source = crate::SourceAlias::new(&vendor.source)?;
        let skill = crate::SkillName::new(&vendor.skill)?;
        let parent = ensure_vendor_source_dir(paths, &source)?;
        let capture = paths.vendor_capture_path(&source, &skill, &journal.nonce)?;
        let prepared = paths.vendor_prepare_path(&source, &skill, &journal.nonce)?;
        remove_verified_vendor(&parent, &capture, &skill, vendor.before.as_deref())?;
        remove_verified_vendor(&parent, &prepared, &skill, vendor.after.as_deref())?;
    }
    Ok(())
}

fn remove_verified_vendor(
    parent: &DirectoryIdentity,
    path: &Path,
    skill: &crate::SkillName,
    expected: Option<&str>,
) -> Result<()> {
    let original_name = file_name(path)?;
    let deletion_name = crate::vendor::deletion_name(&original_name);
    let deletion_path = path.with_file_name(&deletion_name);
    let (name, owned_path, kind) = match parent.entry_identity(&original_name, path)? {
        Some((_, _, kind)) => (original_name, path.to_path_buf(), kind),
        None => match parent.entry_identity(&deletion_name, &deletion_path)? {
            Some((_, _, kind)) => (deletion_name, deletion_path, kind),
            None => return Ok(()),
        },
    };
    if kind != 0o040000 {
        return Err(CoreError::RecoveryRequired(format!(
            "vendor transaction path `{}` is foreign",
            owned_path.display()
        )));
    }
    let Some(expected) = expected else {
        return Err(CoreError::RecoveryRequired(format!(
            "unexpected vendor transaction path `{}`",
            owned_path.display()
        )));
    };
    crate::vendor::remove_verified_tree_at(&parent.descriptor, &name, &owned_path, skill, expected)
}

fn cleanup_captured_links(paths: &Paths, journal: &Journal) -> Result<()> {
    if journal.links.is_empty() {
        return Ok(());
    }
    let parent = DirectoryIdentity::capture_or_create(&paths.skills_dir())?;
    for link in &journal.links {
        let destination = paths.skills_dir().join(&link.skill);
        if let Some(before) = &link.before {
            for suffix in ["link-swap", "link-remove"] {
                let temporary = format!(".{}.{}.{suffix}", link.skill, journal.nonce);
                parent.cleanup_capture_if_owned(&temporary, &bytes_path(before), &destination)?;
            }
        }
    }
    Ok(())
}

fn current_state(paths: &Paths, state: &StateTransition) -> Result<Option<Vec<u8>>> {
    let path = state_path(paths, state)?;
    read_optional_bounded(&path, STATE_LIMIT)
}

fn current_link(paths: &Paths, link: &LinkTransition) -> Result<Option<Vec<u8>>> {
    let path = paths.skills_dir().join(&link.skill);
    match observe_link(&path)? {
        LinkPrecondition::Absent => Ok(None),
        LinkPrecondition::Symlink(target) => Ok(Some(path_bytes(&target))),
        LinkPrecondition::File | LinkPrecondition::Directory => Err(CoreError::RecoveryRequired(
            format!("foreign entry occupies transaction link `{}`", link.skill),
        )),
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum VendorOccupancy {
    Absent,
    Digest(String),
    Foreign,
}

impl From<&Option<String>> for VendorOccupancy {
    fn from(value: &Option<String>) -> Self {
        value
            .as_ref()
            .map_or(Self::Absent, |digest| Self::Digest(digest.clone()))
    }
}

fn current_vendor(paths: &Paths, vendor: &VendorTransition) -> Result<VendorOccupancy> {
    let source = crate::SourceAlias::new(&vendor.source)?;
    let parent = ensure_vendor_source_dir(paths, &source)?;
    current_vendor_at(paths, &parent, vendor)
}

fn current_vendor_at(
    paths: &Paths,
    parent: &DirectoryIdentity,
    vendor: &VendorTransition,
) -> Result<VendorOccupancy> {
    let source = crate::SourceAlias::new(&vendor.source)?;
    let skill = crate::SkillName::new(&vendor.skill)?;
    let path = paths.vendor_path(&source, &skill)?;
    match parent.entry_identity(skill.as_str(), &path)? {
        None => Ok(VendorOccupancy::Absent),
        Some((_, _, kind)) if kind != 0o040000 => Ok(VendorOccupancy::Foreign),
        Some(_) => match crate::vendor::verify_vendor_tree_at(
            &parent.descriptor,
            skill.as_str(),
            &path,
            &skill,
        ) {
            Ok(digest) => Ok(VendorOccupancy::Digest(digest)),
            Err(_) => Ok(VendorOccupancy::Foreign),
        },
    }
}

fn validate_journal(paths: &Paths, journal: &Journal) -> Result<()> {
    if journal.scope_key != paths.scope_key() {
        return Err(CoreError::Transaction(
            "journal scope does not match resolved paths".into(),
        ));
    }
    validate_nonce(&journal.nonce)?;
    if journal.plan_digest.len() != 64
        || !journal
            .plan_digest
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        return Err(CoreError::Transaction("invalid journal plan digest".into()));
    }
    for state in &journal.state {
        match state.name {
            StateName::Manifest => {
                if state.alias.is_some() || state.source_key.is_some() {
                    return Err(CoreError::Transaction(
                        "manifest journal entry carries candidate identity".into(),
                    ));
                }
                if let Some(bytes) = &state.before {
                    crate::Manifest::parse(bytes.clone())?;
                }
                if let Some(bytes) = &state.after {
                    crate::Manifest::parse(bytes.clone())?;
                }
            }
            StateName::Lock => {
                if state.alias.is_some() || state.source_key.is_some() {
                    return Err(CoreError::Transaction(
                        "lock journal entry carries candidate identity".into(),
                    ));
                }
                if let Some(bytes) = &state.before {
                    crate::Lockfile::parse(bytes)?;
                }
                if let Some(bytes) = &state.after {
                    crate::Lockfile::parse(bytes)?;
                }
            }
            StateName::Trust => {
                if state.alias.is_some() || state.source_key.is_some() {
                    return Err(CoreError::Transaction(
                        "trust journal entry carries candidate identity".into(),
                    ));
                }
                if let Some(bytes) = &state.before {
                    crate::TrustStore::parse(bytes)?;
                }
                if let Some(bytes) = &state.after {
                    crate::TrustStore::parse(bytes)?;
                }
            }
            StateName::Candidate => {
                let alias = state.alias.as_deref().ok_or_else(|| {
                    CoreError::Transaction("candidate journal lacks alias".into())
                })?;
                crate::SourceAlias::new(alias)?;
                let source_key =
                    crate::SourceKey::parse(state.source_key.clone().ok_or_else(|| {
                        CoreError::Transaction("candidate journal lacks source key".into())
                    })?)?;
                if let Some(bytes) = &state.before {
                    crate::CandidateRecord::parse(bytes, Some(&source_key))?;
                }
                if let Some(bytes) = &state.after {
                    crate::CandidateRecord::parse(bytes, Some(&source_key))?;
                }
            }
        }
    }
    if !journal.vendors.is_empty() && !matches!(paths.scope, ScopePaths::Project { .. }) {
        return Err(CoreError::Transaction(
            "vendor journal transitions require Project scope".into(),
        ));
    }
    for vendor in &journal.vendors {
        crate::SourceAlias::new(&vendor.source)?;
        crate::SkillName::new(&vendor.skill)?;
        if vendor.before.is_none() && vendor.after.is_none() {
            return Err(CoreError::Transaction(
                "journal vendor transition has no state".into(),
            ));
        }
        for digest in [&vendor.before, &vendor.after].into_iter().flatten() {
            validate_content_digest(digest)?;
        }
    }
    for link in &journal.links {
        crate::SkillName::new(&link.skill)?;
        if link.before.is_none() && link.after.is_none() {
            return Err(CoreError::Transaction(
                "journal link transition has no state".into(),
            ));
        }
        for raw in [&link.before, &link.after].into_iter().flatten() {
            let path = bytes_path(raw);
            if !path.is_absolute() && !is_vendor_link_target(&path) {
                return Err(CoreError::Transaction(
                    "journal link target is neither absolute nor a derived vendor target".into(),
                ));
            }
        }
    }
    Ok(())
}

fn validate_content_digest(digest: &str) -> Result<()> {
    let Some(hex) = digest.strip_prefix("sha256:") else {
        return Err(CoreError::Transaction(
            "invalid vendor content digest".into(),
        ));
    };
    if hex.len() == 64
        && hex
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(())
    } else {
        Err(CoreError::Transaction(
            "invalid vendor content digest".into(),
        ))
    }
}

fn is_vendor_link_target(path: &Path) -> bool {
    let mut components = path.components();
    let Some(std::path::Component::ParentDir) = components.next() else {
        return false;
    };
    let Some(std::path::Component::ParentDir) = components.next() else {
        return false;
    };
    let Some(std::path::Component::Normal(vendor)) = components.next() else {
        return false;
    };
    if vendor != "vendor" {
        return false;
    }
    let Some(std::path::Component::Normal(grimoire)) = components.next() else {
        return false;
    };
    if grimoire != "grimoire" {
        return false;
    }
    let Some(std::path::Component::Normal(source)) = components.next() else {
        return false;
    };
    let Some(std::path::Component::Normal(skill)) = components.next() else {
        return false;
    };
    components.next().is_none()
        && source
            .to_str()
            .is_some_and(|value| crate::SourceAlias::new(value).is_ok())
        && skill
            .to_str()
            .is_some_and(|value| crate::SkillName::new(value).is_ok())
}

fn validate_file_hash(path: &Path, expected: Option<&ByteHash>, name: &str) -> Result<()> {
    match (read_optional_bounded(path, STATE_LIMIT)?, expected) {
        (Some(bytes), Some(expected)) if &ByteHash::of(&bytes) == expected => Ok(()),
        (None, None) => Ok(()),
        (Some(_), None) => Err(CoreError::StalePlan(format!("{name} appeared"))),
        (None, Some(_)) => Err(CoreError::StalePlan(format!("{name} disappeared"))),
        (Some(_), Some(_)) => Err(CoreError::StalePlan(format!("{name} bytes changed"))),
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

fn state_path(paths: &Paths, state: &StateTransition) -> Result<PathBuf> {
    match state.name {
        StateName::Manifest => Ok(paths.manifest_path()),
        StateName::Lock => Ok(paths.lock_path()),
        StateName::Trust => Ok(paths.trust_path()),
        StateName::Candidate => {
            let alias = state
                .alias
                .as_deref()
                .ok_or_else(|| CoreError::Transaction("candidate journal lacks alias".into()))?;
            Ok(paths.candidate_path(&paths.scope_key(), &crate::SourceAlias::new(alias)?))
        }
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

fn state_order(name: StateName) -> u8 {
    match name {
        StateName::Manifest => 0,
        StateName::Candidate => 1,
        StateName::Trust => 2,
        StateName::Lock => 3,
    }
}

fn candidate_lock_aliases(plan: &Plan) -> Result<Vec<crate::SourceAlias>> {
    let action_aliases = plan
        .actions
        .iter()
        .filter_map(|action| match action {
            Action::ReplaceCandidate { alias, .. } | Action::RemoveCandidate { alias, .. } => {
                Some(alias.clone())
            }
            _ => None,
        })
        .collect::<std::collections::BTreeSet<_>>();
    if action_aliases.len() > 1 {
        return Err(CoreError::Transaction(
            "one plan cannot mutate more than one candidate".into(),
        ));
    }
    if !action_aliases
        .iter()
        .all(|alias| plan.preconditions.candidates.contains_key(alias))
    {
        return Err(CoreError::Transaction(
            "candidate action lacks its matching precondition".into(),
        ));
    }
    let mut aliases = plan
        .preconditions
        .candidates
        .keys()
        .cloned()
        .collect::<std::collections::BTreeSet<_>>();
    aliases.extend(action_aliases);
    Ok(aliases.into_iter().collect())
}

fn refresh_project_index(
    paths: &Paths,
    runtime: &dyn TransactionRuntime,
    nonce: &str,
) -> Result<()> {
    let manifest_bytes = read_required_bounded(&paths.manifest_path(), STATE_LIMIT)?;
    let lock_bytes = read_required_bounded(&paths.lock_path(), STATE_LIMIT)?;
    let manifest = crate::Manifest::parse(manifest_bytes)?;
    let lock = crate::Lockfile::parse(&lock_bytes)?;
    crate::projects::refresh_locked(
        paths,
        &manifest,
        &lock,
        &lock_bytes,
        runtime.unix_time()?,
        nonce,
    )?;
    Ok(())
}

fn apply_prune(
    paths: &Paths,
    plan: &Plan,
    runtime: &dyn TransactionRuntime,
) -> Result<ApplyOutcome> {
    if !matches!(paths.scope, ScopePaths::Global { .. }) {
        return Err(CoreError::Transaction(
            "store prune requires global resolved paths".into(),
        ));
    }
    let expected =
        plan.preconditions.reachability.as_ref().ok_or_else(|| {
            CoreError::Transaction("prune plan lacks reachability generation".into())
        })?;
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
    let observed = crate::prune::reobserve_locked(paths)?;
    if &observed.generation != expected {
        return Err(CoreError::StalePlan(
            "prune reachability generation changed".into(),
        ));
    }
    if observed.retain_all {
        return Err(CoreError::StalePlan(
            "prune reachability is uncertain".into(),
        ));
    }
    let mut changed = false;
    for action in &plan.actions {
        let Action::PruneSnapshot {
            source_key,
            snapshot_key,
        } = action
        else {
            return Err(CoreError::Transaction(
                "non-prune action reached prune executor".into(),
            ));
        };
        let reference = crate::ProjectReference {
            source_key: source_key.clone(),
            snapshot_key: snapshot_key.clone(),
        };
        if !observed.snapshots.contains(&reference) || observed.reachable.contains(&reference) {
            return Err(CoreError::StalePlan(
                "planned snapshot is no longer proven unreachable".into(),
            ));
        }
        if checkpoint(runtime, "before-prune-snapshot")? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "before-prune-snapshot".into(),
            });
        }
        crate::prune::remove_snapshot(paths, &reference)?;
        changed = true;
        if checkpoint(runtime, "after-prune-snapshot")? {
            return Ok(ApplyOutcome::Interrupted {
                checkpoint: "after-prune-snapshot".into(),
            });
        }
    }
    Ok(ApplyOutcome::Applied { changed })
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

fn ensure_vendor_source_dir(
    paths: &Paths,
    source: &crate::SourceAlias,
) -> Result<DirectoryIdentity> {
    let ScopePaths::Project { root } = &paths.scope else {
        return Err(CoreError::Request(
            "vendor paths are available only in Project scope".into(),
        ));
    };
    let project_root = crate::source::HeldDirectoryReader::open(root)?;
    let mut parent = project_root.root_handle()?;
    let mut parent_path = root.clone();
    let mut anchors = Vec::new();
    for component in ["vendor", "grimoire", source.as_str()] {
        let component_path = parent_path.join(component);
        let name = CString::new(component)
            .map_err(|_| CoreError::Transaction("vendor parent contains NUL".into()))?;
        let before = match statat(&parent, &name, AtFlags::SYMLINK_NOFOLLOW) {
            Ok(stat) => stat,
            Err(error) if error == rustix::io::Errno::NOENT => {
                mkdirat(&parent, &name, Mode::from_raw_mode(0o755))
                    .map_err(|error| link_error(&component_path, error))?;
                parent
                    .sync_all()
                    .map_err(|error| crate::transaction::io_error(&component_path, error))?;
                statat(&parent, &name, AtFlags::SYMLINK_NOFOLLOW)
                    .map_err(|error| link_error(&component_path, error))?
            }
            Err(error) => return Err(link_error(&component_path, error)),
        };
        if directory_stat_identity(&before).2 != 0o040000 {
            return Err(CoreError::StalePlan(format!(
                "vendor parent `{}` is not a regular directory",
                component_path.display()
            )));
        }
        let child: File = openat(
            &parent,
            &name,
            OFlags::RDONLY | OFlags::DIRECTORY | OFlags::NOFOLLOW | OFlags::CLOEXEC,
            Mode::empty(),
        )
        .map_err(|error| link_error(&component_path, error))?
        .into();
        if file_directory_identity(&child, &component_path)? != directory_stat_identity(&before) {
            return Err(CoreError::StalePlan(format!(
                "vendor parent `{}` changed before open",
                component_path.display()
            )));
        }
        anchors.push(DirectoryAnchor {
            parent,
            name,
            identity: directory_stat_identity(&before),
        });
        parent = child;
        parent_path = component_path;
    }
    project_root.revalidate_location()?;
    let identity = file_directory_identity(&parent, &paths.vendor_source_dir(source)?)?;
    Ok(DirectoryIdentity {
        descriptor: parent,
        device: identity.0,
        inode: identity.1,
        custody: Some(DirectoryCustody {
            project_root,
            anchors,
        }),
    })
}

struct DirectoryAnchor {
    parent: File,
    name: CString,
    identity: (u64, u64, u32),
}

struct DirectoryCustody {
    project_root: crate::source::HeldDirectoryReader,
    anchors: Vec<DirectoryAnchor>,
}

struct DirectoryIdentity {
    // All link mutations stay relative to this held directory. Revalidating only
    // the path would reopen the parent-replacement race before the syscall.
    descriptor: File,
    device: u64,
    inode: u64,
    custody: Option<DirectoryCustody>,
}

impl DirectoryIdentity {
    fn capture_or_create(path: &Path) -> Result<Self> {
        fs::create_dir_all(path).map_err(|error| crate::transaction::io_error(path, error))?;
        Self::capture(path)
    }

    fn capture(path: &Path) -> Result<Self> {
        let descriptor: File = open(
            path,
            OFlags::RDONLY | OFlags::DIRECTORY | OFlags::NOFOLLOW | OFlags::CLOEXEC,
            Mode::empty(),
        )
        .map_err(|error| link_error(path, error))?
        .into();
        let metadata = descriptor
            .metadata()
            .map_err(|error| crate::transaction::io_error(path, error))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            Ok(Self {
                descriptor,
                device: metadata.dev(),
                inode: metadata.ino(),
                custody: None,
            })
        }
        #[cfg(not(unix))]
        unreachable!("Grimoire supports Unix hosts")
    }

    fn revalidate(&self, path: &Path) -> Result<()> {
        if let Some(custody) = &self.custody {
            custody.project_root.revalidate_location()?;
            for anchor in &custody.anchors {
                let current = statat(&anchor.parent, &anchor.name, AtFlags::SYMLINK_NOFOLLOW)
                    .map_err(|error| link_error(path, error))?;
                if directory_stat_identity(&current) != anchor.identity {
                    return Err(CoreError::StalePlan(format!(
                        "vendor parent directory changed at {}",
                        path.display()
                    )));
                }
            }
            let current = file_directory_identity(&self.descriptor, path)?;
            if current.0 == self.device && current.1 == self.inode && current.2 == 0o040000 {
                return Ok(());
            }
            return Err(CoreError::StalePlan(format!(
                "vendor parent directory changed at {}",
                path.display()
            )));
        }
        let current = Self::capture(path)?;
        if current.device == self.device && current.inode == self.inode {
            Ok(())
        } else {
            Err(CoreError::StalePlan(
                "installed-link parent directory changed".into(),
            ))
        }
    }

    fn entry_identity(&self, name: &str, path: &Path) -> Result<Option<(u64, u64, u32)>> {
        if self.custody.is_some() {
            self.revalidate(path.parent().unwrap_or(path))?;
        }
        let name = CString::new(name)
            .map_err(|_| CoreError::Transaction("transaction name contains NUL".into()))?;
        match statat(&self.descriptor, &name, AtFlags::SYMLINK_NOFOLLOW) {
            Ok(stat) => Ok(Some(directory_stat_identity(&stat))),
            Err(error) if error == rustix::io::Errno::NOENT => Ok(None),
            Err(error) => Err(link_error(path, error)),
        }
    }

    fn rename_no_replace(&self, from: &str, to: &str, destination: &Path) -> Result<()> {
        if self.custody.is_some() {
            self.revalidate(destination)?;
        }
        renameat_with(
            &self.descriptor,
            from,
            &self.descriptor,
            to,
            RenameFlags::NOREPLACE,
        )
        .map_err(|error| {
            if matches!(error, rustix::io::Errno::NOENT | rustix::io::Errno::EXIST) {
                CoreError::StalePlan(format!(
                    "vendor ownership changed at {}",
                    destination.display()
                ))
            } else {
                link_error(destination, error)
            }
        })?;
        if self.custody.is_some() {
            self.revalidate(destination)?;
        }
        self.sync(destination)
    }

    fn create_link(&self, name: &str, target: &Path, destination: &Path) -> Result<()> {
        symlinkat(target, &self.descriptor, name).map_err(|error| {
            if error == rustix::io::Errno::EXIST {
                CoreError::StalePlan(format!(
                    "final ownership changed at {}",
                    destination.display()
                ))
            } else {
                link_error(destination, error)
            }
        })?;
        self.sync(destination)
    }

    fn replace_owned_link(
        &self,
        name: &str,
        expected: &Path,
        target: &Path,
        nonce: &str,
        destination: &Path,
    ) -> Result<()> {
        let temporary = format!(".{name}.{nonce}.link-swap");
        if let Some(captured) = self.read_link_optional(&temporary, destination)? {
            // Recovery may find an exchange that reached the filesystem before
            // its captured old link was removed.
            let current = self.read_link(name, destination)?;
            if captured == target && current == expected {
                renameat_with(
                    &self.descriptor,
                    temporary.as_str(),
                    &self.descriptor,
                    name,
                    RenameFlags::EXCHANGE,
                )
                .map_err(|error| link_error(destination, error))?;
                self.remove_verified_link(temporary.as_str(), expected, destination)?;
                return self.sync(destination);
            }
            return Err(CoreError::RecoveryRequired(format!(
                "link exchange capture for `{name}` is not a recoverable generation"
            )));
        }
        symlinkat(target, &self.descriptor, temporary.as_str())
            .map_err(|error| link_error(destination, error))?;
        // Exchange captures whichever entry currently occupies `name`. Only
        // the captured expected symlink is ever deleted.
        if let Err(error) = renameat_with(
            &self.descriptor,
            temporary.as_str(),
            &self.descriptor,
            name,
            RenameFlags::EXCHANGE,
        ) {
            let _ = unlinkat(&self.descriptor, temporary.as_str(), AtFlags::empty());
            return Err(if error == rustix::io::Errno::NOENT {
                CoreError::StalePlan(format!(
                    "final ownership changed at {}",
                    destination.display()
                ))
            } else {
                link_error(destination, error)
            });
        }

        let captured = self.read_link(temporary.as_str(), destination);
        if !matches!(captured.as_ref(), Ok(actual) if actual == expected) {
            renameat_with(
                &self.descriptor,
                temporary.as_str(),
                &self.descriptor,
                name,
                RenameFlags::EXCHANGE,
            )
            .map_err(|error| {
                CoreError::RecoveryRequired(format!(
                    "cannot restore raced link `{name}` after ownership mismatch: {error}"
                ))
            })?;
            self.remove_verified_link(temporary.as_str(), target, destination)?;
            self.sync(destination)?;
            return Err(CoreError::StalePlan(format!(
                "final ownership changed at {}",
                destination.display()
            )));
        }
        self.remove_verified_link(temporary.as_str(), expected, destination)?;
        self.sync(destination)
    }

    fn remove_owned_link(
        &self,
        name: &str,
        expected: &Path,
        nonce: &str,
        destination: &Path,
    ) -> Result<()> {
        let temporary = format!(".{name}.{nonce}.link-remove");
        // A no-replace rename first captures the exact directory entry. This
        // avoids unlinking a foreign replacement introduced after validation.
        renameat_with(
            &self.descriptor,
            name,
            &self.descriptor,
            temporary.as_str(),
            RenameFlags::NOREPLACE,
        )
        .map_err(|error| {
            if error == rustix::io::Errno::NOENT {
                CoreError::StalePlan(format!(
                    "final ownership changed at {}",
                    destination.display()
                ))
            } else if error == rustix::io::Errno::EXIST {
                CoreError::RecoveryRequired(format!(
                    "link capture path already exists for `{name}`"
                ))
            } else {
                link_error(destination, error)
            }
        })?;

        let captured = self.read_link(temporary.as_str(), destination);
        if !matches!(captured.as_ref(), Ok(actual) if actual == expected) {
            renameat_with(
                &self.descriptor,
                temporary.as_str(),
                &self.descriptor,
                name,
                RenameFlags::NOREPLACE,
            )
            .map_err(|error| {
                CoreError::RecoveryRequired(format!(
                    "cannot restore raced link `{name}` after ownership mismatch: {error}"
                ))
            })?;
            self.sync(destination)?;
            return Err(CoreError::StalePlan(format!(
                "final ownership changed at {}",
                destination.display()
            )));
        }
        self.remove_verified_link(temporary.as_str(), expected, destination)?;
        self.sync(destination)
    }

    fn restore_repointed_link(
        &self,
        name: &str,
        expected: &Path,
        target: &Path,
        nonce: &str,
        destination: &Path,
    ) -> Result<()> {
        let temporary = format!(".{name}.{nonce}.link-swap");
        if self.read_link_optional(&temporary, destination)?.is_none() {
            return self.replace_owned_link(name, expected, target, nonce, destination);
        }
        if self.read_link(name, destination)? != expected {
            return Err(CoreError::RecoveryRequired(format!(
                "link `{name}` changed while restoring its exchange capture"
            )));
        }
        // The capture can be the recorded before target or a foreign entry
        // that raced the transaction. Put either one back; only the known
        // transaction target is removed after the exchange.
        renameat_with(
            &self.descriptor,
            temporary.as_str(),
            &self.descriptor,
            name,
            RenameFlags::EXCHANGE,
        )
        .map_err(|error| link_error(destination, error))?;
        self.remove_verified_link(temporary.as_str(), expected, destination)?;
        self.sync(destination)
    }

    fn restore_removed_link(
        &self,
        name: &str,
        target: &Path,
        nonce: &str,
        destination: &Path,
    ) -> Result<()> {
        let temporary = format!(".{name}.{nonce}.link-remove");
        match self.read_link_optional(&temporary, destination)? {
            Some(_) => {
                renameat_with(
                    &self.descriptor,
                    temporary.as_str(),
                    &self.descriptor,
                    name,
                    RenameFlags::NOREPLACE,
                )
                .map_err(|error| link_error(destination, error))?;
                self.sync(destination)
            }
            None => self.create_link(name, target, destination),
        }
    }

    fn read_link(&self, name: &str, destination: &Path) -> Result<PathBuf> {
        let target = readlinkat(&self.descriptor, name, Vec::new())
            .map_err(|error| link_error(destination, error))?;
        #[cfg(unix)]
        {
            use std::os::unix::ffi::OsStrExt;
            Ok(PathBuf::from(std::ffi::OsStr::from_bytes(
                target.to_bytes(),
            )))
        }
        #[cfg(not(unix))]
        unreachable!("Grimoire supports Unix hosts")
    }

    fn read_link_optional(&self, name: &str, destination: &Path) -> Result<Option<PathBuf>> {
        match readlinkat(&self.descriptor, name, Vec::new()) {
            Ok(target) => {
                #[cfg(unix)]
                {
                    use std::os::unix::ffi::OsStrExt;
                    Ok(Some(PathBuf::from(std::ffi::OsStr::from_bytes(
                        target.to_bytes(),
                    ))))
                }
                #[cfg(not(unix))]
                unreachable!("Grimoire supports Unix hosts")
            }
            Err(error) if error == rustix::io::Errno::NOENT => Ok(None),
            Err(error) => Err(link_error(destination, error)),
        }
    }

    fn remove_verified_link(&self, name: &str, expected: &Path, destination: &Path) -> Result<()> {
        if self.read_link(name, destination)? != expected {
            return Err(CoreError::RecoveryRequired(format!(
                "captured owned link changed before cleanup at {}",
                destination.display()
            )));
        }
        unlinkat(&self.descriptor, name, AtFlags::empty())
            .map_err(|error| link_error(destination, error))
    }

    fn cleanup_capture_if_owned(
        &self,
        name: &str,
        expected: &Path,
        destination: &Path,
    ) -> Result<()> {
        let Some(actual) = self.read_link_optional(name, destination)? else {
            return Ok(());
        };
        if actual != expected {
            return Err(CoreError::RecoveryRequired(format!(
                "link capture `{name}` is not the recorded owned target"
            )));
        }
        self.remove_verified_link(name, expected, destination)?;
        self.sync(destination)
    }

    fn sync(&self, destination: &Path) -> Result<()> {
        self.descriptor
            .sync_all()
            .map_err(|error| crate::transaction::io_error(destination, error))
    }
}

fn link_error(path: &Path, error: rustix::io::Errno) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}

fn directory_stat_identity(stat: &rustix::fs::Stat) -> (u64, u64, u32) {
    (
        stat.st_dev as u64,
        stat.st_ino,
        stat.st_mode as u32 & 0o170000,
    )
}

fn file_directory_identity(file: &File, path: &Path) -> Result<(u64, u64, u32)> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        let metadata = file
            .metadata()
            .map_err(|error| crate::transaction::io_error(path, error))?;
        Ok((metadata.dev(), metadata.ino(), metadata.mode() & 0o170000))
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire supports Unix hosts")
}

#[cfg(test)]
mod link_capture_tests {
    use super::*;

    struct TestRuntime;

    impl TransactionRuntime for TestRuntime {
        fn transaction_nonce(&self) -> Result<String> {
            Ok("stale-cleanup".into())
        }

        fn unix_time(&self) -> Result<i64> {
            Ok(1_700_000_000)
        }

        fn checkpoint(&self, _name: &'static str) -> Result<crate::FaultDisposition> {
            Ok(crate::FaultDisposition::Continue)
        }
    }

    fn store_skill(
        paths: &Paths,
        source_key: &crate::SourceKey,
        snapshot_key: &crate::SnapshotKey,
        name: &str,
    ) -> String {
        let root = paths.store_path(source_key, snapshot_key).join("skill");
        fs::create_dir_all(&root).unwrap();
        fs::write(
            root.join("SKILL.md"),
            format!("---\nname: {name}\ndescription: preparation fixture\n---\n"),
        )
        .unwrap();
        crate::vendor::verify_vendor_tree(&root, &crate::SkillName::new(name).unwrap()).unwrap()
    }

    fn prepare_action(
        source: &str,
        skill: &str,
        source_key: crate::SourceKey,
        snapshot_key: crate::SnapshotKey,
        content: String,
    ) -> Action {
        Action::PrepareVendor {
            scope: Scope::Project,
            source: crate::SourceAlias::new(source).unwrap(),
            skill: crate::SkillName::new(skill).unwrap(),
            source_key,
            snapshot_key,
            skill_path: "skill".into(),
            path: format!("vendor/grimoire/{source}/{skill}"),
            content,
        }
    }

    #[test]
    fn interrupted_exchange_and_removal_captures_restore_without_clobbering() {
        let temporary = tempfile::tempdir().unwrap();
        let user = temporary.path().join("user");
        let paths = Paths::global(user, temporary.path().join("home")).unwrap();
        let parent_path = paths.skills_dir();
        let parent = DirectoryIdentity::capture_or_create(&parent_path).unwrap();
        let destination = parent_path.join("one");

        std::os::unix::fs::symlink("old", &destination).unwrap();
        symlinkat("new", &parent.descriptor, ".one.recovery.link-swap").unwrap();
        renameat_with(
            &parent.descriptor,
            ".one.recovery.link-swap",
            &parent.descriptor,
            "one",
            RenameFlags::EXCHANGE,
        )
        .unwrap();
        parent
            .restore_repointed_link(
                "one",
                Path::new("new"),
                Path::new("old"),
                "recovery",
                &destination,
            )
            .unwrap();
        assert_eq!(fs::read_link(&destination).unwrap(), Path::new("old"));
        assert!(!parent_path.join(".one.recovery.link-swap").exists());

        renameat_with(
            &parent.descriptor,
            "one",
            &parent.descriptor,
            ".one.recovery.link-remove",
            RenameFlags::NOREPLACE,
        )
        .unwrap();
        parent
            .restore_removed_link("one", Path::new("old"), "recovery", &destination)
            .unwrap();
        assert_eq!(fs::read_link(&destination).unwrap(), Path::new("old"));
        assert!(!parent_path.join(".one.recovery.link-remove").exists());

        fs::remove_file(&destination).unwrap();
        std::os::unix::fs::symlink("new", &destination).unwrap();
        std::os::unix::fs::symlink("foreign", parent_path.join(".one.recovery.link-swap")).unwrap();
        parent
            .restore_repointed_link(
                "one",
                Path::new("new"),
                Path::new("old"),
                "recovery",
                &destination,
            )
            .unwrap();
        assert_eq!(fs::read_link(&destination).unwrap(), Path::new("foreign"));
        assert!(!parent_path.join(".one.recovery.link-swap").exists());

        fs::remove_file(&destination).unwrap();
        std::os::unix::fs::symlink("foreign", parent_path.join(".one.recovery.link-remove"))
            .unwrap();
        parent
            .restore_removed_link("one", Path::new("old"), "recovery", &destination)
            .unwrap();
        assert_eq!(fs::read_link(&destination).unwrap(), Path::new("foreign"));
        assert!(!parent_path.join(".one.recovery.link-remove").exists());

        fs::remove_file(&destination).unwrap();
        std::os::unix::fs::symlink("created", &destination).unwrap();
        renameat_with(
            &parent.descriptor,
            "one",
            &parent.descriptor,
            ".one.recovery.link-remove",
            RenameFlags::NOREPLACE,
        )
        .unwrap();
        let journal = Journal {
            schema: JOURNAL_SCHEMA.into(),
            scope_key: "global".into(),
            nonce: "recovery".into(),
            plan_digest: "1".repeat(64),
            committed: false,
            state: Vec::new(),
            vendors: Vec::new(),
            links: vec![LinkTransition {
                skill: "one".into(),
                before: None,
                after: Some(b"created".to_vec()),
            }],
            completed: Vec::new(),
        };
        restore_before(&paths, &journal, "recovery").unwrap();
        assert!(!destination.exists());
        assert!(!parent_path.join(".one.recovery.link-remove").exists());
    }

    #[test]
    fn vendor_parent_swap_is_rejected_before_descriptor_relative_rename() {
        let temporary = tempfile::tempdir().unwrap();
        let root = temporary.path().canonicalize().unwrap();
        let project = root.join("project");
        fs::create_dir(&project).unwrap();
        let paths = Paths::project(project.canonicalize().unwrap(), root.join("home")).unwrap();
        let source = crate::SourceAlias::new("a").unwrap();
        let parent = ensure_vendor_source_dir(&paths, &source).unwrap();
        let parent_path = paths.vendor_source_dir(&source).unwrap();
        fs::create_dir(parent_path.join("prepared")).unwrap();

        let displaced = parent_path.with_extension("displaced");
        fs::rename(&parent_path, &displaced).unwrap();
        fs::create_dir(&parent_path).unwrap();

        assert!(matches!(
            parent.rename_no_replace("prepared", "one", &parent_path.join("one")),
            Err(CoreError::StalePlan(_)) | Err(CoreError::Source(_))
        ));
        assert!(!parent_path.join("one").exists());
        assert!(displaced.join("prepared").is_dir());
    }

    #[test]
    fn symlinked_project_ancestor_is_rejected_even_when_it_resolves_to_the_held_inode() {
        let temporary = tempfile::tempdir().unwrap();
        let root = temporary.path().canonicalize().unwrap();
        let container = root.join("container");
        let project = container.join("project");
        fs::create_dir_all(&project).unwrap();
        let paths = Paths::project(project.canonicalize().unwrap(), root.join("home")).unwrap();
        let source = crate::SourceAlias::new("a").unwrap();
        let parent = ensure_vendor_source_dir(&paths, &source).unwrap();
        let parent_path = paths.vendor_source_dir(&source).unwrap();
        fs::create_dir(parent_path.join("prepared")).unwrap();

        let displaced = root.join("container-displaced");
        fs::rename(&container, &displaced).unwrap();
        std::os::unix::fs::symlink("container-displaced", &container).unwrap();

        assert!(matches!(
            parent.rename_no_replace("prepared", "one", &parent_path.join("one")),
            Err(CoreError::Source(_))
        ));
        let displaced_parent = displaced.join("project/vendor/grimoire/a");
        assert!(displaced_parent.join("prepared").is_dir());
        assert!(!displaced_parent.join("one").exists());
    }

    #[test]
    fn failed_later_vendor_preparation_cleans_earlier_work_and_retry_succeeds() {
        let temporary = tempfile::tempdir().unwrap();
        let root = temporary.path().canonicalize().unwrap();
        let project = root.join("project");
        fs::create_dir(&project).unwrap();
        let paths = Paths::project(project.canonicalize().unwrap(), root.join("home")).unwrap();
        let one_source = crate::SourceAlias::new("a").unwrap();
        let two_source = crate::SourceAlias::new("b").unwrap();
        let one = crate::SkillName::new("one").unwrap();
        let two = crate::SkillName::new("two").unwrap();
        let one_source_key = crate::SourceKey::parse("1".repeat(64)).unwrap();
        let one_snapshot_key = crate::SnapshotKey::parse("2".repeat(64)).unwrap();
        let two_source_key = crate::SourceKey::parse("3".repeat(64)).unwrap();
        let two_snapshot_key = crate::SnapshotKey::parse("4".repeat(64)).unwrap();
        let one_content = store_skill(&paths, &one_source_key, &one_snapshot_key, "one");
        let missing_two = root.join("two-source");
        fs::create_dir(&missing_two).unwrap();
        fs::write(
            missing_two.join("SKILL.md"),
            "---\nname: two\ndescription: preparation fixture\n---\n",
        )
        .unwrap();
        let two_content = crate::vendor::verify_vendor_tree(&missing_two, &two).unwrap();
        let plan = Plan {
            actions: vec![
                prepare_action(
                    "a",
                    "one",
                    one_source_key,
                    one_snapshot_key,
                    one_content.clone(),
                ),
                prepare_action(
                    "b",
                    "two",
                    two_source_key.clone(),
                    two_snapshot_key.clone(),
                    two_content.clone(),
                ),
            ],
            blockers: Vec::new(),
            preconditions: crate::Preconditions::absent(),
            facts: Vec::new(),
            exit_class: crate::ExitClass::Success,
        };
        let nonce = "preparation-retry";
        assert!(prepare_vendors(&paths, &plan, nonce).is_err());
        assert!(!paths
            .vendor_prepare_path(&one_source, &one, nonce)
            .unwrap()
            .exists());

        assert_eq!(
            store_skill(&paths, &two_source_key, &two_snapshot_key, "two"),
            two_content
        );
        prepare_vendors(&paths, &plan, nonce).unwrap();
        for (source, skill) in [(&one_source, &one), (&two_source, &two)] {
            assert!(paths
                .vendor_prepare_path(source, skill, nonce)
                .unwrap()
                .is_dir());
        }
        cleanup_unjournaled_vendor_preparations(&paths, &plan, nonce).unwrap();
        for (source, skill) in [(&one_source, &one), (&two_source, &two)] {
            assert!(!paths
                .vendor_prepare_path(source, skill, nonce)
                .unwrap()
                .exists());
        }
    }

    #[test]
    fn stale_first_action_cleans_unconsumed_preparations_before_removing_journal() {
        let temporary = tempfile::tempdir().unwrap();
        let root = temporary.path().canonicalize().unwrap();
        let project = root.join("project");
        fs::create_dir(&project).unwrap();
        let paths = Paths::project(project.canonicalize().unwrap(), root.join("home")).unwrap();
        let one_source = crate::SourceAlias::new("a").unwrap();
        let two_source = crate::SourceAlias::new("b").unwrap();
        let one = crate::SkillName::new("one").unwrap();
        let two = crate::SkillName::new("two").unwrap();
        let two_source_key = crate::SourceKey::parse("5".repeat(64)).unwrap();
        let two_snapshot_key = crate::SnapshotKey::parse("6".repeat(64)).unwrap();
        let one_path = paths.vendor_path(&one_source, &one).unwrap();
        fs::create_dir_all(&one_path).unwrap();
        fs::write(
            one_path.join("SKILL.md"),
            "---\nname: one\ndescription: current vendor\n---\n",
        )
        .unwrap();
        let prepared = paths
            .vendor_prepare_path(&two_source, &two, "stale-cleanup")
            .unwrap();
        let two_content = store_skill(&paths, &two_source_key, &two_snapshot_key, "two");
        let plan = Plan {
            actions: vec![
                prepare_action(
                    "b",
                    "two",
                    two_source_key,
                    two_snapshot_key,
                    two_content.clone(),
                ),
                Action::RetainVendor {
                    scope: Scope::Project,
                    source: one_source,
                    skill: one,
                    path: "vendor/grimoire/a/one".into(),
                    content: format!("sha256:{}", "0".repeat(64)),
                },
                Action::CreateVendor {
                    scope: Scope::Project,
                    source: two_source,
                    skill: two,
                    path: "vendor/grimoire/b/two".into(),
                    after: two_content,
                    added: vec!["SKILL.md".into()],
                },
            ],
            blockers: Vec::new(),
            preconditions: crate::Preconditions::absent(),
            facts: Vec::new(),
            exit_class: crate::ExitClass::Success,
        };

        let result = apply(&paths, &plan, Approval::NotRequired, &TestRuntime);
        assert!(matches!(result, Err(CoreError::StalePlan(_))), "{result:?}");
        assert!(!prepared.exists());
        assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
    }
}
