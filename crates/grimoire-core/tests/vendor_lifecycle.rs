use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

use grimoire_core::{
    apply, plan, recover, Action, Approval, ByteHash, CanonicalIdentity, FaultDisposition,
    InstalledLink, LinkPrecondition, LockSkill, LockSource, Lockfile, OwnedLinkTarget, Paths, Plan,
    PlanningMode, Preconditions, Request, RequestRoot, Result, Scope, SkillName, SnapshotId,
    SnapshotKey, SnapshotKind, SnapshotStore, SourceAlias, SourceKey, SourceSnapshot, SourceState,
    StorePrecondition, TransactionRuntime, TrustBaseline, TrustReceipt, TrustStore,
    VendorPrecondition, VendorState, WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Digest, Skill, SourceInventory,
    SourcePath,
};

fn force_vendor_mode(world: &mut WorldState) {
    for skill in world.manifest.skills.values_mut() {
        skill.mode = grimoire_core::ProjectionMode::Vendor;
    }
    for pack in world.manifest.packs.values_mut() {
        pack.mode = grimoire_core::ProjectionMode::Vendor;
    }
    for skill in world.lock.skills.values_mut() {
        skill.mode = grimoire_core::ProjectionMode::Vendor;
    }
    for pack in world.lock.packs.values_mut() {
        pack.mode = grimoire_core::ProjectionMode::Vendor;
    }
}

fn snapshot(digit: u8) -> SourceSnapshot {
    let skills = vec![Skill {
        name: "one".into(),
        path: SourcePath::from("skills/one"),
        content_digest: Digest::from_bytes([digit; 32]),
        files: Vec::new(),
        symlinks: Vec::new(),
        submodules: Vec::new(),
    }];
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&skills, &[], &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills,
        packs: Vec::new(),
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
    };
    SourceSnapshot::new(
        SourceAlias::new("a").unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some(char::from(b'0' + digit).to_string().repeat(40)),
            Some(char::from(b'a' + digit).to_string().repeat(40)),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        PathBuf::from(format!("/store/{digit}")),
        inventory,
    )
}

fn initial_lock(old: &SourceSnapshot) -> Vec<u8> {
    let manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[skills]\none = { source = \"a\" }\n"
    );
    let mut world = WorldState::from_bytes(
        Scope::Project,
        manifest.as_bytes().to_vec(),
        Lockfile::default().to_bytes().unwrap(),
        [
            SourceState::new(old.clone(), SnapshotStore::Valid, false).source_identity(
                CanonicalIdentity::remote("github:org/a").unwrap(),
                old.inventory.review_tree_digest.to_string(),
            ),
        ],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap();
    force_vendor_mode(&mut world);
    plan(&world, Request::Reconcile, PlanningMode::Normal)
        .unwrap()
        .actions
        .into_iter()
        .find_map(|action| match action {
            Action::ReplaceLock { after, .. } => Some(after),
            _ => None,
        })
        .unwrap()
}

fn lifecycle_world(state: VendorState, update: bool) -> WorldState {
    let old = snapshot(1);
    let desired = if update { snapshot(2) } else { old.clone() };
    let lock = initial_lock(&old);
    let manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[skills]\none = { source = \"a\" }\n"
    )
    .as_bytes()
    .to_vec();
    let identity = CanonicalIdentity::remote("github:org/a").unwrap();
    let mut world = WorldState::from_bytes(
        Scope::Project,
        manifest,
        lock,
        [
            SourceState::new(desired.clone(), SnapshotStore::Valid, false).source_identity(
                identity.clone(),
                desired.inventory.review_tree_digest.to_string(),
            ),
        ],
        [(
            "one",
            InstalledLink::Symlink(PathBuf::from("../../vendor/grimoire/a/one")),
        )],
        None,
    )
    .unwrap();
    force_vendor_mode(&mut world);
    world.locked_states.insert(
        "a".try_into().unwrap(),
        SourceState::new(old.clone(), SnapshotStore::Valid, false).source_identity(
            identity.clone(),
            old.inventory.review_tree_digest.to_string(),
        ),
    );
    world.vendors.insert(
        "one".try_into().unwrap(),
        VendorPrecondition {
            state,
            content: (state == VendorState::OwnedUnchanged)
                .then(|| old.inventory.skills[0].content_digest.to_string()),
        },
    );
    let trust = TrustStore::default()
        .grant_all(
            identity,
            Some(TrustReceipt {
                commit: old.id.commit.clone().unwrap(),
                tree: old.id.tree.clone().unwrap(),
                inventory: old.id.inventory_digest.clone(),
            }),
            TrustBaseline {
                commit: old.id.commit.clone(),
                tree: old.id.tree.clone(),
                inventory: old.id.inventory_digest.clone(),
                review_tree: old.inventory.review_tree_digest.to_string(),
            },
            None,
        )
        .unwrap()
        .after;
    world.with_trust_bytes(Some(trust))
}

#[test]
#[ignore = "schema 3 drops per-skill mode; unit 3 retargets vendor tests to copies"]
fn update_replaces_only_unchanged_owned_vendor_and_advances_all_trust_baseline() {
    let planned = plan(
        &lifecycle_world(VendorState::OwnedUnchanged, true),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(planned.blockers.is_empty(), "{:?}", planned.blockers);
    assert!(planned.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceVendor { before, after, .. } if before != after
    )));
    assert!(planned.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceTrust {
            change: grimoire_core::TrustChange::AdvanceBaseline,
            ..
        }
    )));
    assert!(planned.actions.iter().any(|action| matches!(
        action,
        Action::RetainLink {
            target: grimoire_core::OwnedLinkTarget::Vendor { .. },
            ..
        }
    )));
}

#[test]
#[ignore = "schema 3 drops per-skill mode; unit 3 retargets vendor tests to copies"]
fn uninstall_is_idempotent_for_missing_owned_content_and_blocks_drift_or_foreign_occupancy() {
    let name = SkillName::new("one").unwrap();
    for state in [VendorState::Drifted, VendorState::Foreign] {
        let blocked = plan(
            &lifecycle_world(state, false),
            Request::UninstallSkill { name: name.clone() },
            PlanningMode::Normal,
        )
        .unwrap();
        assert!(blocked.blockers.iter().any(|blocker| matches!(
            (state, blocker.code.as_str()),
            (VendorState::Drifted, "vendor-drift") | (VendorState::Foreign, "foreign-vendor-path")
        )));
        assert!(!blocked
            .actions
            .iter()
            .any(|action| matches!(action, Action::RemoveVendor { .. })));
    }

    let missing = plan(
        &lifecycle_world(VendorState::Absent, false),
        Request::UninstallSkill { name },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(!missing
        .actions
        .iter()
        .any(|action| matches!(action, Action::RemoveVendor { .. })));
}

struct FaultRuntime {
    checkpoint: Option<&'static str>,
    fired: AtomicBool,
}

impl FaultRuntime {
    fn at(checkpoint: &'static str) -> Self {
        Self {
            checkpoint: Some(checkpoint),
            fired: AtomicBool::new(false),
        }
    }

    fn plain() -> Self {
        Self {
            checkpoint: None,
            fired: AtomicBool::new(false),
        }
    }
}

impl TransactionRuntime for FaultRuntime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("vendor-recovery".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        Ok(
            if self.checkpoint == Some(name) && !self.fired.swap(true, Ordering::SeqCst) {
                FaultDisposition::Crash
            } else {
                FaultDisposition::Continue
            },
        )
    }
}

struct ForeignRuntime {
    path: PathBuf,
    fired: AtomicBool,
}

impl TransactionRuntime for ForeignRuntime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("vendor-recovery".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name == "after-vendor-capture" && !self.fired.swap(true, Ordering::SeqCst) {
            fs::write(&self.path, b"foreign\n").unwrap();
            Ok(FaultDisposition::Crash)
        } else {
            Ok(FaultDisposition::Continue)
        }
    }
}

#[test]
#[ignore = "schema 3 drops per-skill mode; unit 3 retargets vendor tests to copies"]
fn every_vendor_publication_prefix_recovers_the_complete_before_state() {
    for checkpoint in [
        "journal-created",
        "before-vendor-capture",
        "after-vendor-capture",
        "before-vendor-publication",
        "after-vendor-publication",
        "action-marked",
        "before-commit-marker",
    ] {
        let (_temporary, paths, plan, old_content, _new_content) = recovery_fixture();
        let outcome = apply(
            &paths,
            &plan,
            Approval::Granted,
            &FaultRuntime::at(checkpoint),
        )
        .unwrap();
        assert!(matches!(
            outcome,
            grimoire_core::ApplyOutcome::Interrupted { .. }
        ));
        let recovered = recover(&paths, &FaultRuntime::plain()).unwrap();
        assert!(matches!(
            recovered.dispositions.as_slice(),
            [grimoire_core::RecoveryDisposition::RolledBack { .. }]
        ));
        let vendor = paths
            .vendor_path(&"a".try_into().unwrap(), &"one".try_into().unwrap())
            .unwrap();
        assert_eq!(
            grimoire_core::verify_vendor_tree(&vendor, &"one".try_into().unwrap()).unwrap(),
            old_content,
            "checkpoint {checkpoint}"
        );
        assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
    }
}

#[test]
#[ignore = "schema 3 drops per-skill mode; unit 3 retargets vendor tests to copies"]
fn every_committed_vendor_prefix_recovers_the_complete_after_state() {
    for checkpoint in [
        "committed",
        "before-project-refresh",
        "after-project-refresh",
        "before-cleanup",
    ] {
        let (_temporary, paths, plan, _old_content, new_content) = recovery_fixture();
        let outcome = apply(
            &paths,
            &plan,
            Approval::Granted,
            &FaultRuntime::at(checkpoint),
        )
        .unwrap();
        assert!(matches!(
            outcome,
            grimoire_core::ApplyOutcome::Interrupted { .. }
        ));
        let recovered = recover(&paths, &FaultRuntime::plain()).unwrap();
        assert!(matches!(
            recovered.dispositions.as_slice(),
            [grimoire_core::RecoveryDisposition::RolledForward { .. }]
        ));
        let vendor = paths
            .vendor_path(&"a".try_into().unwrap(), &"one".try_into().unwrap())
            .unwrap();
        assert_eq!(
            grimoire_core::verify_vendor_tree(&vendor, &"one".try_into().unwrap()).unwrap(),
            new_content,
            "checkpoint {checkpoint}"
        );
        assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
    }
}

#[test]
#[ignore = "schema 3 drops per-skill mode; unit 3 retargets vendor tests to copies"]
fn recovery_preserves_a_late_foreign_vendor_replacement() {
    let (_temporary, paths, plan, _old_content, _new_content) = recovery_fixture();
    let vendor = paths
        .vendor_path(&"a".try_into().unwrap(), &"one".try_into().unwrap())
        .unwrap();
    let outcome = apply(
        &paths,
        &plan,
        Approval::Granted,
        &ForeignRuntime {
            path: vendor.clone(),
            fired: AtomicBool::new(false),
        },
    )
    .unwrap();
    assert!(matches!(
        outcome,
        grimoire_core::ApplyOutcome::Interrupted { .. }
    ));
    assert!(matches!(
        recover(&paths, &FaultRuntime::plain()),
        Err(grimoire_core::CoreError::RecoveryRequired(_))
    ));
    assert_eq!(fs::read(&vendor).unwrap(), b"foreign\n");
    assert!(paths.transaction_journal_path(&paths.scope_key()).exists());
}

fn recovery_fixture() -> (tempfile::TempDir, Paths, Plan, String, String) {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    let old_source = root.join("old-source");
    let new_source = root.join("new-source");
    for (source, description) in [(&old_source, "old"), (&new_source, "new")] {
        fs::create_dir_all(source.join("skills/one")).unwrap();
        fs::write(
            source.join("skills/one/SKILL.md"),
            format!("---\nname: one\ndescription: {description}\n---\n"),
        )
        .unwrap();
    }
    fs::create_dir_all(&project).unwrap();
    let paths = Paths::project(project, home).unwrap();
    let old_inventory = grimoire_core::inventory::scan(
        &grimoire_core::source::HeldDirectoryReader::open(&old_source).unwrap(),
    )
    .unwrap();
    let new_inventory = grimoire_core::inventory::scan(
        &grimoire_core::source::HeldDirectoryReader::open(&new_source).unwrap(),
    )
    .unwrap();
    let old_content = old_inventory.skills[0].content_digest.to_string();
    let new_content = new_inventory.skills[0].content_digest.to_string();
    let source_key = SourceKey::parse("1".repeat(64)).unwrap();
    let snapshot_key = SnapshotKey::parse("2".repeat(64)).unwrap();
    let store = paths.store_path(&source_key, &snapshot_key);
    fs::create_dir_all(store.join("skills/one")).unwrap();
    fs::copy(
        new_source.join("skills/one/SKILL.md"),
        store.join("skills/one/SKILL.md"),
    )
    .unwrap();
    let source = SourceAlias::new("a").unwrap();
    let skill = SkillName::new("one").unwrap();
    let vendor = paths.vendor_path(&source, &skill).unwrap();
    fs::create_dir_all(&vendor).unwrap();
    fs::copy(
        old_source.join("skills/one/SKILL.md"),
        vendor.join("SKILL.md"),
    )
    .unwrap();
    fs::create_dir_all(paths.skills_dir()).unwrap();
    #[cfg(unix)]
    std::os::unix::fs::symlink(
        "../../vendor/grimoire/a/one",
        paths.skills_dir().join("one"),
    )
    .unwrap();
    let manifest = b"schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"github:org/a\"\n[skills]\none = { source = \"a\" }\n".to_vec();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            source.clone(),
            LockSource::Git {
                declared: "github:org/a".into(),
                reference: None,
                commit: "a".repeat(40),
                tree: "b".repeat(40),
                inventory: old_inventory.inventory_digest.to_string(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            skill.clone(),
            LockSkill {
                source: source.clone(),
                mode: grimoire_core::ProjectionMode::Vendor,
                path: "skills/one".into(),
                content: old_content.clone(),
                requested_by: BTreeSet::from([RequestRoot::Skill(skill.clone())]),
            },
        )]),
    }
    .to_bytes()
    .unwrap();
    fs::write(paths.manifest_path(), &manifest).unwrap();
    fs::write(paths.lock_path(), &lock).unwrap();
    let plan = Plan {
        actions: vec![
            Action::PrepareVendor {
                scope: Scope::Project,
                source: source.clone(),
                skill: skill.clone(),
                source_key: source_key.clone(),
                snapshot_key: snapshot_key.clone(),
                skill_path: "skills/one".into(),
                path: "vendor/grimoire/a/one".into(),
                content: new_content.clone(),
            },
            Action::ReplaceVendor {
                scope: Scope::Project,
                source: source.clone(),
                skill: skill.clone(),
                path: "vendor/grimoire/a/one".into(),
                before: old_content.clone(),
                after: new_content.clone(),
                added: Vec::new(),
                removed: Vec::new(),
                changed: vec!["SKILL.md".into()],
            },
            Action::RetainLink {
                scope: Scope::Project,
                skill: skill.clone(),
                target: OwnedLinkTarget::Vendor {
                    source: source.clone(),
                    skill: skill.clone(),
                },
            },
        ],
        blockers: Vec::new(),
        preconditions: Preconditions {
            manifest: Some(ByteHash::of(&manifest)),
            lock: Some(ByteHash::of(&lock)),
            candidates: BTreeMap::new(),
            stores: BTreeMap::from([(
                source,
                StorePrecondition {
                    source_key,
                    snapshot_key,
                    inventory: new_inventory.inventory_digest.to_string(),
                    state: SnapshotStore::Valid,
                },
            )]),
            trust: None,
            projects: None,
            reachability: None,
            links: BTreeMap::from([(
                skill.clone(),
                LinkPrecondition::Symlink(PathBuf::from("../../vendor/grimoire/a/one")),
            )]),
            vendors: BTreeMap::from([(
                skill,
                VendorPrecondition {
                    state: VendorState::OwnedUnchanged,
                    content: Some(old_content.clone()),
                },
            )]),
        },
        facts: Vec::new(),
        exit_class: grimoire_core::ExitClass::Success,
    };
    (temporary, paths, plan, old_content, new_content)
}
