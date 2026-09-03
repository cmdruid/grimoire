use std::path::PathBuf;

use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};
use grimoire_core::{
    plan, project_tree, CanonicalIdentity, DesiredEdit, DesiredState, InstalledLink, PlanningMode,
    Request, Scope, SnapshotId, SnapshotKind, SnapshotStore, SourceAlias, SourceSnapshot,
    SourceState, TreeItemKey, TrustBaseline, TrustReceipt, TrustStore, WorldState,
};

const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");
const MANIFEST: &str = concat!(
    "schema = \"grimoire/manifest@1\"\n",
    "[sources.grimoire]\n",
    "url = \"github:cmdruid/grimoire\"\n",
);

fn world() -> WorldState {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skills = vec![Skill {
        name: "journal".into(),
        path: SourcePath::from("skills/journal"),
        content_digest: content,
        files: Vec::new(),
        symlinks: Vec::new(),
        submodules: Vec::new(),
    }];
    let packs: Vec<Pack> = Vec::new();
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&skills, &packs, &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills,
        packs,
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
    };
    let snapshot = SourceSnapshot::new(
        SourceAlias::new("grimoire").unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some("1".repeat(40)),
            Some("2".repeat(40)),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        PathBuf::from("/store/grimoire/snapshot"),
        inventory,
    );
    let identity = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let receipt = TrustReceipt {
        commit: snapshot.id.commit.clone().unwrap(),
        tree: snapshot.id.tree.clone().unwrap(),
        inventory: snapshot.id.inventory_digest.clone(),
    };
    let trust = TrustStore::default()
        .grant_all(
            identity.clone(),
            Some(receipt),
            TrustBaseline {
                commit: snapshot.id.commit.clone(),
                tree: snapshot.id.tree.clone(),
                inventory: snapshot.id.inventory_digest.clone(),
                review_tree: snapshot.inventory.review_tree_digest.to_string(),
            },
            None,
        )
        .unwrap()
        .after;
    let review_tree = snapshot.inventory.review_tree_digest.to_string();
    WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [SourceState::new(snapshot, SnapshotStore::Valid, false)
            .source_identity(identity, review_tree)],
        [("journal", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(Some(trust))
}

#[test]
fn one_available_skill_stages_through_the_exact_core_plan() {
    let world = world();
    let key = TreeItemKey::Skill {
        source: "grimoire".try_into().unwrap(),
        name: "journal".try_into().unwrap(),
    };
    let mut desired = DesiredState::from_world(&world);

    let before = project_tree(&world, &desired).unwrap();
    assert!(!before.item(&key).unwrap().selected);

    desired
        .apply(DesiredEdit::SetSkill {
            name: "journal".try_into().unwrap(),
            source: "grimoire".try_into().unwrap(),
            enabled: true,
        })
        .unwrap();
    let staged = plan(&world, desired.clone().into_request(), PlanningMode::Normal).unwrap();
    let direct = plan(
        &world,
        Request::InstallSkill {
            name: "journal".try_into().unwrap(),
            source: "grimoire".try_into().unwrap(),
        },
        PlanningMode::Normal,
    )
    .unwrap();

    assert_eq!(staged.to_bytes().unwrap(), direct.to_bytes().unwrap());
    assert!(
        project_tree(&world, &desired)
            .unwrap()
            .item(&key)
            .unwrap()
            .selected
    );
    assert_eq!(world.manifest_bytes, MANIFEST.as_bytes());
}
