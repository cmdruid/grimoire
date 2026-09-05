use std::path::PathBuf;

use grimoire_core::{
    plan, Action, CanonicalIdentity, InstalledLink, PlanningMode, Request, Scope, SnapshotId,
    SnapshotKind, SnapshotStore, SourceAlias, SourceSnapshot, SourceState, TrustBaseline,
    TrustChange, TrustMode, TrustReceipt, TrustStore, VendorPrecondition, VendorState, WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Skill, SourceInventory, SourcePath,
};

const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");
const MANIFEST: &str = concat!(
    "schema = \"grimoire/manifest@3\"\n",
    "[sources.a]\nurl = \"github:org/a\"\nref = \"main\"\n",
    "[skills]\none = { source = \"a\" }\n",
);

fn snapshot(root: &str, digit: char, kind: SnapshotKind) -> SourceSnapshot {
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
    let (commit, tree) = match kind {
        SnapshotKind::Git => (
            Some(digit.to_string().repeat(40)),
            Some(digit.to_ascii_uppercase().to_string().repeat(40)),
        ),
        SnapshotKind::Link => (None, None),
    };
    SourceSnapshot::new(
        SourceAlias::new("a").unwrap(),
        SnapshotId::new(kind, commit, tree, inventory.inventory_digest.to_string()).unwrap(),
        PathBuf::from(root),
        inventory,
    )
}

fn state(
    snapshot: SourceSnapshot,
    trust: TrustMode,
    store: SnapshotStore,
    materializable: bool,
) -> Observed {
    let identity = match snapshot.id.kind {
        SnapshotKind::Git => CanonicalIdentity::remote("github:org/a").unwrap(),
        SnapshotKind::Link => {
            CanonicalIdentity::local(grimoire_core::SourceKind::Link, &snapshot.root).unwrap()
        }
    };
    let review_tree = snapshot.inventory.review_tree_digest.to_string();
    Observed {
        state: SourceState::new(snapshot, store, materializable)
            .source_identity(identity, review_tree),
        trust,
    }
}

#[derive(Clone)]
struct Observed {
    state: SourceState,
    trust: TrustMode,
}

impl Observed {
    fn candidate(mut self, bytes: Vec<u8>) -> Self {
        self.state = self.state.candidate(bytes);
        self
    }

    fn stale_candidate(mut self) -> Self {
        self.state = self.state.stale_candidate();
        self
    }

    fn source_identity(mut self, identity: CanonicalIdentity, review_tree: String) -> Self {
        self.state = self.state.source_identity(identity, review_tree);
        self
    }
}

fn trust_bytes(observed: &Observed) -> Option<Vec<u8>> {
    let identity = observed.state.identity.clone().unwrap();
    let snapshot = &observed.state.snapshot;
    let baseline = TrustBaseline {
        commit: snapshot.id.commit.clone(),
        tree: snapshot.id.tree.clone(),
        inventory: snapshot.id.inventory_digest.clone(),
        review_tree: observed.state.review_tree.clone().unwrap(),
    };
    let mutation = match observed.trust {
        TrustMode::Untrusted => return None,
        TrustMode::Snapshot => TrustStore::default()
            .grant_exact(
                identity,
                TrustReceipt {
                    commit: snapshot.id.commit.clone().unwrap(),
                    tree: snapshot.id.tree.clone().unwrap(),
                    inventory: snapshot.id.inventory_digest.clone(),
                },
                baseline,
                None,
            )
            .unwrap(),
        TrustMode::All => TrustStore::default()
            .grant_all(
                identity,
                (snapshot.id.kind == SnapshotKind::Git).then(|| TrustReceipt {
                    commit: snapshot.id.commit.clone().unwrap(),
                    tree: snapshot.id.tree.clone().unwrap(),
                    inventory: snapshot.id.inventory_digest.clone(),
                }),
                baseline,
                None,
            )
            .unwrap(),
    };
    Some(mutation.after)
}

fn world(current: Observed, link: InstalledLink) -> WorldState {
    let trust = trust_bytes(&current);
    WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [current.state],
        [("one", link)],
        None,
    )
    .unwrap()
    .with_trust_bytes(trust)
}

fn blocker_codes(plan: &grimoire_core::Plan) -> Vec<&str> {
    plan.blockers
        .iter()
        .map(|blocker| blocker.code.as_str())
        .collect()
}

#[test]
fn update_requires_and_pins_the_cached_candidate() {
    let current = state(
        snapshot("/store/old", '1', SnapshotKind::Git),
        TrustMode::All,
        SnapshotStore::Valid,
        false,
    );
    let missing = plan(
        &world(current.clone(), InstalledLink::Absent),
        Request::UpdateSource {
            alias: "a".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(blocker_codes(&missing).contains(&"source-candidate-missing"));

    let stale = state(
        snapshot("/store/new", '2', SnapshotKind::Git),
        TrustMode::All,
        SnapshotStore::Valid,
        false,
    )
    .candidate(b"stale-candidate\n".to_vec())
    .stale_candidate();
    let stale_world = world(current.clone(), InstalledLink::Absent)
        .with_candidate(stale.state)
        .unwrap();
    let stale_plan = plan(
        &stale_world,
        Request::UpdateSource {
            alias: "a".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(blocker_codes(&stale_plan).contains(&"source-candidate-stale"));

    let candidate = state(
        snapshot("/store/new", '2', SnapshotKind::Git),
        TrustMode::All,
        SnapshotStore::Valid,
        false,
    )
    .candidate(b"candidate-generation-two\n".to_vec());
    let selected_world = world(current, InstalledLink::Absent)
        .with_candidate(candidate.state)
        .unwrap();
    let selected = plan(
        &selected_world,
        Request::UpdateSource {
            alias: "a".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(selected.blockers.is_empty());
    assert!(selected
        .preconditions
        .candidates
        .contains_key(&SourceAlias::new("a").unwrap()));
    assert!(selected.actions.iter().any(|action| matches!(
        action,
        Action::CreateVendor { skill, path, .. } if skill.as_str() == "one" && path == ".agents/skills/one"
    )));
}

#[test]
fn activation_requires_validation_trust_and_store_integrity() {
    for (trust, store, expected) in [
        (
            TrustMode::Untrusted,
            SnapshotStore::Valid,
            "source-untrusted",
        ),
        (
            TrustMode::All,
            SnapshotStore::Absent,
            "snapshot-store-absent",
        ),
        (
            TrustMode::All,
            SnapshotStore::Corrupt,
            "snapshot-store-corrupt",
        ),
    ] {
        let observed = state(
            snapshot("/store/a", '1', SnapshotKind::Git),
            trust,
            store,
            false,
        );
        let planned = plan(
            &world(observed, InstalledLink::Absent),
            Request::Reconcile,
            PlanningMode::Normal,
        )
        .unwrap();
        assert!(blocker_codes(&planned).contains(&expected));
        assert!(!planned
            .actions
            .iter()
            .any(|action| matches!(action, Action::PrepareSnapshot { .. })));
    }
}

#[test]
fn a_trusted_absent_snapshot_gets_materialized_before_activation() {
    let observed = state(
        snapshot("/store/a", '1', SnapshotKind::Git),
        TrustMode::Snapshot,
        SnapshotStore::Absent,
        true,
    );
    let planned = plan(
        &world(observed, InstalledLink::Absent),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(planned.blockers.is_empty());
    assert!(matches!(
        planned.actions.first(),
        Some(Action::PrepareSnapshot {
            source,
            source_key,
            snapshot_key,
            review_key,
            ..
        }) if source.as_str() == "a"
            && source_key.len() == 64
            && snapshot_key.len() == 64
            && review_key.len() == 64
    ));
    assert_eq!(
        planned
            .preconditions
            .stores
            .get(&SourceAlias::new("a").unwrap())
            .map(|precondition| precondition.state),
        Some(SnapshotStore::Absent)
    );
}

#[test]
fn frozen_refuses_live_even_when_identity_wide_trust_is_present() {
    let manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\npath = \"../a\"\nlink = true\n",
        "[skills]\none = { source = \"a\" }\n",
    );
    let observed = state(
        snapshot("/held/live", '1', SnapshotKind::Link),
        TrustMode::All,
        SnapshotStore::Absent,
        false,
    );
    let live_trust = trust_bytes(&observed);
    let live_world = WorldState::from_bytes(
        Scope::Project,
        manifest.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [observed.state],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(live_trust);
    let planned = plan(&live_world, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(blocker_codes(&planned).contains(&"frozen-mismatch"));
}

#[test]
fn frozen_recreates_a_missing_link_when_lock_is_unchanged() {
    let manifest = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\npath = \"../a\"\nlink = true\n",
        "[skills]\none = { source = \"a\" }\n",
    );
    let observed = state(
        snapshot("/held/live", '1', SnapshotKind::Link),
        TrustMode::All,
        SnapshotStore::Absent,
        false,
    );
    let live_trust = trust_bytes(&observed);
    let baseline = plan(
        &WorldState::from_bytes(
            Scope::Project,
            manifest.as_bytes().to_vec(),
            EMPTY_LOCK.to_vec(),
            [observed.state.clone()],
            [("one", InstalledLink::Absent)],
            None,
        )
        .unwrap()
        .with_trust_bytes(live_trust.clone()),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    let lock = baseline
        .actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceLock { after, .. } => Some(after.clone()),
            _ => None,
        })
        .unwrap();
    let missing = WorldState::from_bytes(
        Scope::Project,
        manifest.as_bytes().to_vec(),
        lock,
        [observed.state.clone()],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(live_trust)
    .with_locked_snapshot(observed.state);
    let frozen = plan(&missing, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(frozen.blockers.is_empty(), "{:?}", frozen.blockers);
    assert!(frozen.actions.iter().any(|action| matches!(
        action,
        Action::CreateLink { skill, .. } if skill.as_str() == "one"
    )));
    assert!(!frozen.actions.iter().any(|action| matches!(
        action,
        Action::CreateVendor { .. } | Action::PrepareVendor { .. }
    )));
}

#[test]
fn untrusted_owned_content_can_still_be_removed() {
    let current = state(
        snapshot("/store/a", '1', SnapshotKind::Git),
        TrustMode::All,
        SnapshotStore::Valid,
        false,
    );
    let baseline = plan(
        &world(current, InstalledLink::Absent),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    let lock = baseline
        .actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceLock { after, .. } => Some(after.clone()),
            _ => None,
        })
        .unwrap();
    let untrusted = state(
        snapshot("/store/a", '1', SnapshotKind::Git),
        TrustMode::Untrusted,
        SnapshotStore::Valid,
        false,
    );
    let content = untrusted.state.snapshot.inventory.skills[0]
        .content_digest
        .to_string();
    let removal_world = WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        lock,
        [untrusted.state],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_vendors([(
        "one",
        VendorPrecondition {
            state: VendorState::OwnedUnchanged,
            content: Some(content),
        },
    )])
    .unwrap();
    let removal = plan(
        &removal_world,
        Request::UninstallSkill {
            name: "one".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(!blocker_codes(&removal).contains(&"source-untrusted"));
    assert!(removal
        .actions
        .iter()
        .any(|action| matches!(action, Action::RemoveVendor { .. })));
}

#[test]
fn frozen_uses_only_the_lock_derived_stored_snapshot() {
    let old_snapshot = snapshot("/store/old", '1', SnapshotKind::Git);
    let old = state(
        old_snapshot.clone(),
        TrustMode::Snapshot,
        SnapshotStore::Valid,
        false,
    );
    let baseline = plan(
        &world(old.clone(), InstalledLink::Absent),
        Request::Reconcile,
        PlanningMode::Normal,
    )
    .unwrap();
    let lock = baseline
        .actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceLock { after, .. } => Some(after.clone()),
            _ => None,
        })
        .unwrap();
    let newer = state(
        snapshot("/store/new", '2', SnapshotKind::Git),
        TrustMode::All,
        SnapshotStore::Valid,
        false,
    );
    let frozen_trust = trust_bytes(&newer);
    let old_content = old_snapshot.inventory.skills[0].content_digest.to_string();
    let frozen_world = WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        lock,
        [newer.state],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(frozen_trust)
    .with_locked_snapshot(old.state)
    .with_vendors([(
        "one",
        VendorPrecondition {
            state: VendorState::OwnedUnchanged,
            content: Some(old_content),
        },
    )])
    .unwrap();
    let frozen = plan(&frozen_world, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(frozen.blockers.is_empty(), "{:?}", frozen.blockers);
    assert!(matches!(
        frozen.actions.as_slice(),
        [Action::RetainVendor { path, .. }] if path == ".agents/skills/one"
    ));
}

#[test]
fn first_activation_under_all_trust_advances_the_baseline_in_the_plan() {
    let identity = CanonicalIdentity::remote("github:org/a").unwrap();
    let old = snapshot("/store/old", '1', SnapshotKind::Git);
    let old_baseline = TrustBaseline {
        commit: old.id.commit.clone(),
        tree: old.id.tree.clone(),
        inventory: old.id.inventory_digest.clone(),
        review_tree: format!("sha256:{}", "8".repeat(64)),
    };
    let granted = TrustStore::default()
        .grant_all(
            identity.clone(),
            Some(TrustReceipt {
                commit: old.id.commit.clone().unwrap(),
                tree: old.id.tree.clone().unwrap(),
                inventory: old.id.inventory_digest.clone(),
            }),
            old_baseline,
            None,
        )
        .unwrap();
    let newer = snapshot("/store/new", '2', SnapshotKind::Git);
    let review_tree = format!("sha256:{}", "9".repeat(64));
    let observed = state(newer.clone(), TrustMode::All, SnapshotStore::Valid, false)
        .source_identity(identity.clone(), review_tree.clone());
    let activation_world =
        world(observed, InstalledLink::Absent).with_trust_bytes(Some(granted.after));
    let activation = plan(&activation_world, Request::Reconcile, PlanningMode::Normal).unwrap();
    let after = activation
        .actions
        .iter()
        .find_map(|action| match action {
            Action::ReplaceTrust {
                after,
                change: TrustChange::AdvanceBaseline,
                ..
            } => Some(after),
            _ => None,
        })
        .expect("baseline update action");
    let updated = TrustStore::parse(after).unwrap();
    let baseline = updated.records[&grimoire_core::SourceKey::derive(&identity)]
        .baseline
        .as_ref()
        .unwrap();
    assert_eq!(baseline.commit, newer.id.commit);
    assert_eq!(baseline.review_tree, review_tree);
}
