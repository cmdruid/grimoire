use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use grimoire_core::{
    plan, resolve_manifest, Action, InstalledLink, Lockfile, PackMemberState, Plan, PlanFact,
    PlanningMode, Request, RequestRoot, Scope, SnapshotId, SnapshotKind, SnapshotStore,
    SourceAlias, SourceSnapshot, SourceState, TrustBaseline, TrustReceipt, TrustRecord, TrustStore,
    WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};

const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");

fn snapshot(
    alias: &str,
    kind: SnapshotKind,
    skills: &[&str],
    packs: &[(&str, &[&str], &[&str])],
) -> SourceSnapshot {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skills: Vec<_> = skills
        .iter()
        .map(|name| Skill {
            name: (*name).into(),
            path: SourcePath::from(format!("skills/{name}").as_str()),
            content_digest: content,
            files: Vec::new(),
            symlinks: Vec::new(),
            submodules: Vec::new(),
        })
        .collect();
    let packs: Vec<_> = packs
        .iter()
        .map(|(name, required, optional)| Pack {
            name: (*name).into(),
            path: SourcePath::from(format!("packs/{name}/PACK.md").as_str()),
            digest: content,
            description: "fixture".into(),
            required: required.iter().map(|value| (*value).into()).collect(),
            optional: optional.iter().map(|value| (*value).into()).collect(),
            missing_required: Vec::new(),
            missing_optional: Vec::new(),
        })
        .collect();
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&skills, &packs, &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills,
        packs,
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
    };
    let (commit, tree) = match kind {
        SnapshotKind::Git => (Some("1".repeat(40)), Some("2".repeat(40))),
        SnapshotKind::Link => (None, None),
    };
    SourceSnapshot::new(
        SourceAlias::new(alias).unwrap(),
        SnapshotId::new(kind, commit, tree, inventory.inventory_digest.to_string()).unwrap(),
        PathBuf::from(format!("/store/{alias}")),
        inventory,
    )
}

fn world(
    scope: Scope,
    manifest: &str,
    snapshots: Vec<SourceSnapshot>,
    links: &[(&str, InstalledLink)],
    inherited: Option<grimoire_core::Resolution>,
) -> WorldState {
    let mut trust = TrustStore::default();
    let states = snapshots.into_iter().map(|snapshot| {
        let identity = match snapshot.id.kind {
            SnapshotKind::Git => {
                grimoire_core::CanonicalIdentity::remote(&format!("github:org/{}", snapshot.alias))
                    .unwrap()
            }
            SnapshotKind::Link => grimoire_core::CanonicalIdentity::local(
                grimoire_core::SourceKind::Link,
                &snapshot.root,
            )
            .unwrap(),
        };
        let review_tree = snapshot.inventory.review_tree_digest.to_string();
        let receipt = (snapshot.id.kind == SnapshotKind::Git).then(|| TrustReceipt {
            commit: snapshot.id.commit.clone().unwrap(),
            tree: snapshot.id.tree.clone().unwrap(),
            inventory: snapshot.id.inventory_digest.clone(),
        });
        trust.records.insert(
            grimoire_core::SourceKey::derive(&identity),
            TrustRecord {
                identity: identity.clone(),
                receipts: receipt.into_iter().collect(),
                vendor_receipts: BTreeSet::new(),
                all_snapshots: true,
                baseline: Some(TrustBaseline {
                    commit: snapshot.id.commit.clone(),
                    tree: snapshot.id.tree.clone(),
                    inventory: snapshot.id.inventory_digest.clone(),
                    review_tree: review_tree.clone(),
                }),
            },
        );
        SourceState::new(snapshot, SnapshotStore::Valid, false)
            .source_identity(identity, review_tree)
    });
    WorldState::from_bytes(
        scope,
        manifest.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        states,
        links.iter().cloned(),
        inherited,
    )
    .unwrap()
    .with_trust_bytes(Some(trust.to_bytes().unwrap()))
}

fn planned_lock(plan: &Plan) -> Lockfile {
    let bytes = plan
        .actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceLock { after, .. } => Some(after),
            _ => None,
        })
        .expect("lock replacement");
    Lockfile::parse(bytes).unwrap()
}

#[test]
fn pack_resolution_covers_required_enabled_excluded_and_unavailable_members() {
    let manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\nref = \"main\"\n",
        "[packs]\nbundle = { source = \"a\", exclude = [\"disabled\"] }\n",
    );
    let plan = plan(
        &world(
            Scope::Project,
            manifest,
            vec![snapshot(
                "a",
                SnapshotKind::Git,
                &["required", "enabled", "disabled"],
                &[("bundle", &["required"], &["disabled", "enabled", "missing"])],
            )],
            &[
                ("required", InstalledLink::Absent),
                ("enabled", InstalledLink::Absent),
            ],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();

    assert!(plan.blockers.is_empty());
    let lock = planned_lock(&plan);
    let pack = &lock.packs[&"bundle".try_into().unwrap()];
    assert_eq!(
        pack.required,
        BTreeSet::from(["required".try_into().unwrap()])
    );
    assert_eq!(
        pack.enabled,
        BTreeSet::from(["enabled".try_into().unwrap(), "missing".try_into().unwrap()])
    );
    assert_eq!(
        pack.unavailable,
        BTreeSet::from(["missing".try_into().unwrap()])
    );
    assert!(lock.skills.contains_key(&"required".try_into().unwrap()));
    assert!(lock.skills.contains_key(&"enabled".try_into().unwrap()));
    assert!(!lock.skills.contains_key(&"disabled".try_into().unwrap()));
    assert!(!lock.skills.contains_key(&"missing".try_into().unwrap()));
    assert!(plan.facts.contains(&PlanFact::PackMember {
        pack: "bundle".try_into().unwrap(),
        skill: "missing".try_into().unwrap(),
        state: PackMemberState::Unavailable,
    }));
}

#[test]
fn same_owner_roots_merge_and_source_only_declarations_do_not_enter_the_lock() {
    let manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[sources.unused]\nurl = \"github:org/unused\"\n",
        "[skills]\nshared = { source = \"a\" }\n",
        "[packs]\nbundle = { source = \"a\" }\n",
    );
    let plan = plan(
        &world(
            Scope::Project,
            manifest,
            vec![
                snapshot(
                    "a",
                    SnapshotKind::Git,
                    &["shared"],
                    &[("bundle", &["shared"], &[])],
                ),
                snapshot("unused", SnapshotKind::Git, &[], &[]),
            ],
            &[("shared", InstalledLink::Absent)],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    let lock = planned_lock(&plan);
    assert_eq!(
        lock.skills[&"shared".try_into().unwrap()].requested_by,
        BTreeSet::from([
            RequestRoot::Pack("bundle".try_into().unwrap()),
            RequestRoot::Skill("shared".try_into().unwrap()),
        ])
    );
    assert!(!lock.sources.contains_key(&"unused".try_into().unwrap()));
}

#[test]
fn same_snapshot_and_owner_guards_refuse_cross_source_resolution_or_adoption() {
    let missing = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[sources.b]\nurl = \"github:org/b\"\n",
        "[packs]\nbundle = { source = \"a\" }\n",
    );
    let missing_plan = plan(
        &world(
            Scope::Project,
            missing,
            vec![
                snapshot("a", SnapshotKind::Git, &[], &[("bundle", &["shared"], &[])]),
                snapshot("b", SnapshotKind::Git, &["shared"], &[]),
            ],
            &[],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(missing_plan
        .blockers
        .iter()
        .any(|value| value.code == "pack-required-missing"));

    let collision = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[sources.b]\nurl = \"github:org/b\"\n",
        "[skills]\nshared = { source = \"a\" }\n",
        "[packs]\nbundle = { source = \"b\" }\n",
    );
    let collision_plan = plan(
        &world(
            Scope::Project,
            collision,
            vec![
                snapshot("a", SnapshotKind::Git, &["shared"], &[]),
                snapshot(
                    "b",
                    SnapshotKind::Git,
                    &["shared"],
                    &[("bundle", &["shared"], &[])],
                ),
            ],
            &[],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(collision_plan
        .blockers
        .iter()
        .any(|value| value.code == "skill-owner-collision"));
}

#[test]
fn project_and_global_resolve_independently_with_read_only_shadowing_facts() {
    let global_manifest = grimoire_core::Manifest::parse(
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.global]\nurl = \"github:org/global\"\n",
            "[skills]\nshared = { source = \"global\" }\n",
        )
        .as_bytes()
        .to_vec(),
    )
    .unwrap();
    let global_snapshot = snapshot("global", SnapshotKind::Git, &["shared"], &[]);
    let global = resolve_manifest(
        &global_manifest,
        &BTreeMap::from([(global_snapshot.alias.clone(), global_snapshot)]),
    );
    let project_manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.project]\nurl = \"github:org/project\"\n",
        "[skills]\nshared = { source = \"project\" }\n",
    );
    let plan = plan(
        &world(
            Scope::Project,
            project_manifest,
            vec![snapshot("project", SnapshotKind::Git, &["shared"], &[])],
            &[("shared", InstalledLink::Absent)],
            Some(global),
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(plan.facts.contains(&PlanFact::ShadowedGlobal {
        skill: "shared".try_into().unwrap(),
    }));
    assert!(plan.actions.iter().all(|action| match action {
        Action::ReplaceLock { scope, .. } | Action::CreateLink { scope, .. } => {
            *scope == Scope::Project
        }
        _ => true,
    }));
}

#[test]
fn invalid_exclusions_and_live_frozen_worlds_are_stable_blockers() {
    let invalid = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[packs]\nbundle = { source = \"a\", exclude = [\"required\"] }\n",
    );
    let invalid_plan = plan(
        &world(
            Scope::Project,
            invalid,
            vec![snapshot(
                "a",
                SnapshotKind::Git,
                &["required"],
                &[("bundle", &["required"], &[])],
            )],
            &[],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(invalid_plan
        .blockers
        .iter()
        .any(|value| value.code == "pack-exclusion-invalid"));

    let live = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.local]\npath = \"../local\"\nlink = true\n",
        "[skills]\none = { source = \"local\" }\n",
    );
    let live_plan = plan(
        &world(
            Scope::Project,
            live,
            vec![snapshot("local", SnapshotKind::Link, &["one"], &[])],
            &[("one", InstalledLink::Absent)],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Frozen,
    )
    .unwrap();
    assert!(live_plan
        .blockers
        .iter()
        .any(|value| value.code == "frozen-mismatch"));
}

#[test]
fn projection_mode_follows_the_source_and_is_unanimous() {
    let snapshot = snapshot(
        "a",
        SnapshotKind::Git,
        &["shared"],
        &[("bundle", &["shared"], &[])],
    );
    let agreeing = grimoire_core::Manifest::parse(
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.a]\nurl = \"github:org/a\"\n",
            "[skills]\nshared = { source = \"a\" }\n",
            "[packs]\nbundle = { source = \"a\" }\n",
        )
        .as_bytes()
        .to_vec(),
    )
    .unwrap();
    let resolved = resolve_manifest(
        &agreeing,
        &BTreeMap::from([(snapshot.alias.clone(), snapshot)]),
    );
    assert!(resolved.blockers.is_empty());
    assert_eq!(
        format!(
            "{:?}",
            resolved.lock.skills[&"shared".try_into().unwrap()].mode
        ),
        "Vendor"
    );
    assert_eq!(
        format!(
            "{:?}",
            resolved.lock.packs[&"bundle".try_into().unwrap()].mode
        ),
        "Vendor"
    );
}

#[test]
fn link_activation_is_legal_for_link_sources_and_global_scope() {
    let live_manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.local]\npath = \"../local\"\nlink = true\n",
        "[skills]\none = { source = \"local\" }\n",
    );
    let live_plan = plan(
        &world(
            Scope::Project,
            live_manifest,
            vec![snapshot("local", SnapshotKind::Link, &["one"], &[])],
            &[],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(live_plan
        .blockers
        .iter()
        .all(|blocker| blocker.code != "vendor-live-unsupported"));

    let global_plan = plan(
        &world(
            Scope::Global,
            concat!(
                "schema = \"grimoire/manifest@3\"\n",
                "[sources.a]\nurl = \"github:org/a\"\n",
                "[skills]\none = { source = \"a\" }\n",
            ),
            vec![snapshot("a", SnapshotKind::Git, &["one"], &[])],
            &[],
            None,
        ),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(global_plan
        .blockers
        .iter()
        .all(|blocker| blocker.code != "vendor-global-unsupported"));
}
