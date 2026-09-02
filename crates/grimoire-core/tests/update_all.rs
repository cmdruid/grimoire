use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, SourceInventory,
};
use grimoire_core::{
    plan, CanonicalIdentity, PlanningMode, Request, Scope, SnapshotId, SnapshotKind, SnapshotStore,
    SourceAlias, SourceSnapshot, SourceState, WorldState,
};

const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");

fn candidate(alias: &str, digit: char, live: bool) -> SourceState {
    let inventory = SourceInventory {
        skills: Vec::new(),
        packs: Vec::new(),
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
        inventory_digest: compute_inventory_digest(&[], &[], &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
    };
    let kind = if live {
        SnapshotKind::Live
    } else {
        SnapshotKind::Git
    };
    let snapshot = SourceSnapshot::new(
        SourceAlias::new(alias).unwrap(),
        SnapshotId::new(
            kind,
            (!live).then(|| digit.to_string().repeat(40)),
            (!live).then(|| digit.to_ascii_uppercase().to_string().repeat(40)),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        format!("/source/{alias}").into(),
        inventory,
    );
    let identity = if live {
        CanonicalIdentity::local(grimoire_core::SourceKind::Live, &snapshot.root).unwrap()
    } else {
        CanonicalIdentity::remote(&format!("github:org/{alias}")).unwrap()
    };
    let review_tree = snapshot.inventory.review_tree_digest.to_string();
    SourceState::new(snapshot, SnapshotStore::Valid, false)
        .source_identity(identity, review_tree)
        .candidate(format!("candidate-{alias}").into_bytes())
}

fn world() -> WorldState {
    let manifest = concat!(
        "schema = \"grimoire/manifest@1\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[sources.b]\nurl = \"github:org/b\"\n",
        "[sources.live]\npath = \"/source/live\"\nlive = true\n",
    );
    let mut world = WorldState::from_bytes(
        Scope::Project,
        manifest.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [],
        [],
        None,
    )
    .unwrap();
    for state in [
        candidate("a", '1', false),
        candidate("b", '2', false),
        candidate("live", '3', true),
    ] {
        world = world.with_candidate(state).unwrap();
    }
    world
}

#[test]
fn update_all_pins_every_non_live_candidate_and_skips_live() {
    let planned = plan(&world(), Request::UpdateAll, PlanningMode::Normal).unwrap();
    assert!(planned.blockers.is_empty());
    assert_eq!(
        planned
            .preconditions
            .candidates
            .keys()
            .map(ToString::to_string)
            .collect::<Vec<_>>(),
        vec!["a", "b"]
    );
}

#[test]
fn update_all_blocks_as_one_plan_when_any_non_live_candidate_is_missing() {
    let mut world = world();
    world.candidates.remove(&SourceAlias::new("b").unwrap());
    let planned = plan(&world, Request::UpdateAll, PlanningMode::Normal).unwrap();
    assert!(planned.blockers.iter().any(|blocker| {
        blocker.code == "source-candidate-missing"
            && blocker.details.get("source").map(String::as_str) == Some("b")
    }));
}

#[test]
fn explicitly_named_live_update_is_an_input_error() {
    assert!(plan(
        &world(),
        Request::UpdateSource {
            alias: SourceAlias::new("live").unwrap(),
        },
        PlanningMode::Normal,
    )
    .is_err());
}
