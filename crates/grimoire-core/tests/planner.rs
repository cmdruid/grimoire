use std::path::PathBuf;

use grimoire_core::{
    plan, Action, ExitClass, InstalledLink, LockChange, ManifestChange, ManifestSource,
    PlanningMode, Preconditions, Request, Scope, SnapshotId, SnapshotKind, SourceAlias,
    SourceLocation, SourceSnapshot, WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Skill, SourceInventory, SourcePath,
};

const BASE: &str = include_str!("fixtures/planner/base.toml");
const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");
const NOOP_PLAN: &[u8] = include_bytes!("fixtures/planner/noop-plan.json");

fn snapshot(root: &str, commit_digit: char) -> SourceSnapshot {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skills = vec![Skill {
        name: "one".into(),
        path: SourcePath::from("skills/one"),
        content_digest: content,
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
            Some(commit_digit.to_string().repeat(40)),
            Some(commit_digit.to_ascii_uppercase().to_string().repeat(40)),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        PathBuf::from(root),
        inventory,
    )
}

fn world(
    manifest: &str,
    lock: Vec<u8>,
    snapshot: SourceSnapshot,
    link: InstalledLink,
) -> WorldState {
    WorldState::from_bytes(
        Scope::Project,
        manifest.as_bytes().to_vec(),
        lock,
        [snapshot],
        [("one", link)],
        None,
    )
    .unwrap()
}

fn lock_after(plan: &grimoire_core::Plan) -> Vec<u8> {
    plan.actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceLock { after, .. } | Action::CreateLock { after, .. } => {
                Some(after.clone())
            }
            _ => None,
        })
        .expect("lock bytes")
}

#[test]
fn absent_scope_initializes_exact_files_without_observation_preconditions() {
    let world = WorldState::absent(Scope::Project, [], [], None).unwrap();
    let plan = plan(&world, Request::Initialize, PlanningMode::Normal).unwrap();
    assert_eq!(plan.exit_class, ExitClass::Success);
    assert_eq!(plan.preconditions, Preconditions::absent());
    assert_eq!(
        plan.actions,
        vec![
            Action::CreateManifest {
                scope: Scope::Project,
                after: b"schema = \"grimoire/manifest@1\"\n".to_vec(),
            },
            Action::CreateLock {
                scope: Scope::Project,
                after: EMPTY_LOCK.to_vec(),
            },
        ]
    );
    assert!(!plan.is_destructive());
}

#[test]
fn request_matrix_carries_typed_manifest_and_lock_changes() {
    let minimal = "schema = \"grimoire/manifest@1\"\n";
    let no_snapshot = WorldState::from_bytes(
        Scope::Project,
        minimal.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [],
        [],
        None,
    )
    .unwrap();
    let add = plan(
        &no_snapshot,
        Request::AddSource {
            alias: "a".try_into().unwrap(),
            source: ManifestSource {
                location: SourceLocation::Url("github:org/a".into()),
                reference: Some("main".into()),
                live: false,
            },
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(add.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceManifest {
            change: ManifestChange::AddSource,
            ..
        }
    )));

    let install = plan(
        &world(
            BASE.split("[skills]").next().unwrap(),
            EMPTY_LOCK.to_vec(),
            snapshot("/store/a-old", '1'),
            InstalledLink::Absent,
        ),
        Request::InstallSkill {
            name: "one".try_into().unwrap(),
            source: "a".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(install.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceManifest {
            change: ManifestChange::InstallSkill,
            ..
        }
    )));
    assert!(install.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceLock {
            change: LockChange::Resolve,
            ..
        }
    )));
}

#[test]
fn explicit_source_update_distinguishes_exact_old_drift_and_foreign_occupancy() {
    let old = snapshot("/store/a-old", '1');
    let baseline = plan(
        &world(
            BASE,
            EMPTY_LOCK.to_vec(),
            old.clone(),
            InstalledLink::Absent,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    let lock = lock_after(&baseline);
    let old_target = PathBuf::from("/store/a-old/skills/one");
    let new = snapshot("/store/a-new", '2');
    let new_target = PathBuf::from("/store/a-new/skills/one");

    let repoint = plan(
        &world(
            BASE,
            lock.clone(),
            old.clone(),
            InstalledLink::Symlink(old_target.clone()),
        ),
        Request::UpdateSource {
            alias: "a".try_into().unwrap(),
            snapshot: Box::new(new.clone()),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(repoint.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceLock {
            change: LockChange::SourceAdvance,
            ..
        }
    )));
    assert!(repoint.actions.contains(&Action::RepointLink {
        scope: Scope::Project,
        skill: "one".try_into().unwrap(),
        before: old_target.clone(),
        after: new_target.clone(),
    }));
    assert!(repoint.is_destructive());

    for observation in [
        InstalledLink::Symlink(PathBuf::from("/foreign")),
        InstalledLink::File,
        InstalledLink::Directory,
    ] {
        let blocked = plan(
            &world(BASE, lock.clone(), old.clone(), observation),
            Request::UpdateSource {
                alias: "a".try_into().unwrap(),
                snapshot: Box::new(new.clone()),
            },
            PlanningMode::Normal,
        )
        .unwrap();
        assert_eq!(blocked.exit_class, ExitClass::Blocked);
        assert!(blocked.blockers.iter().any(
            |blocker| blocker.code.starts_with("link-") || blocker.code.starts_with("foreign-")
        ));
        assert!(!blocked
            .actions
            .iter()
            .any(|action| matches!(action, Action::RepointLink { .. })));
    }

    let retained = plan(
        &world(BASE, lock, old, InstalledLink::Symlink(new_target)),
        Request::UpdateSource {
            alias: "a".try_into().unwrap(),
            snapshot: Box::new(new),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(retained
        .actions
        .iter()
        .any(|action| matches!(action, Action::RetainLink { .. })));
}

#[test]
fn uninstall_removes_only_the_lock_owned_exact_link_and_keeps_source_declaration() {
    let old = snapshot("/store/a-old", '1');
    let baseline = plan(
        &world(
            BASE,
            EMPTY_LOCK.to_vec(),
            old.clone(),
            InstalledLink::Absent,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    let lock = lock_after(&baseline);
    let removal = plan(
        &world(
            BASE,
            lock,
            old,
            InstalledLink::Symlink(PathBuf::from("/store/a-old/skills/one")),
        ),
        Request::UninstallSkill {
            name: "one".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(removal.actions.iter().any(|action| matches!(
        action,
        Action::ReplaceManifest {
            change: ManifestChange::UninstallSkill,
            ..
        }
    )));
    assert!(removal
        .actions
        .iter()
        .any(|action| matches!(action, Action::RemoveLink { .. })));
    let manifest_after = removal
        .actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceManifest { after, .. } => Some(after),
            _ => None,
        })
        .unwrap();
    assert!(String::from_utf8(manifest_after.clone())
        .unwrap()
        .contains("[sources.a]"));
    assert!(removal.is_destructive());
}

#[test]
fn serialized_plans_are_deterministic_domain_values() {
    let state = world(
        BASE,
        EMPTY_LOCK.to_vec(),
        snapshot("/store/a", '1'),
        InstalledLink::Absent,
    );
    let first = plan(&state, Request::Reconcile, PlanningMode::Normal).unwrap();
    let second = plan(&state, Request::Reconcile, PlanningMode::Normal).unwrap();
    assert_eq!(first, second);
    assert_eq!(first.to_bytes().unwrap(), second.to_bytes().unwrap());
    assert!(first.to_bytes().unwrap().ends_with(b"\n"));

    let noop = plan(
        &WorldState::from_bytes(
            Scope::Project,
            b"schema = \"grimoire/manifest@1\"\n".to_vec(),
            EMPTY_LOCK.to_vec(),
            [],
            [],
            None,
        )
        .unwrap(),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert_eq!(noop.to_bytes().unwrap(), NOOP_PLAN);
}
