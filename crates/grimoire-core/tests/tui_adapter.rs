use std::path::PathBuf;

use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};
use grimoire_core::{
    plan, project_tree, CanonicalIdentity, DesiredEdit, DesiredState, InstalledLink, PackSelection,
    PlanningMode, ProjectionMode, Request, RequestRoot, Scope, SkillAvailability, SnapshotId,
    SnapshotKind, SnapshotStore, SourceAlias, SourceSnapshot, SourceState, TreeItemKey,
    TreeItemKind, TrustBaseline, TrustReceipt, TrustStore, WorldState,
};

const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");
const MANIFEST: &str = concat!(
    "schema = \"grimoire/manifest@3\"\n",
    "[sources.grimoire]\n",
    "url = \"github:cmdruid/grimoire\"\n",
);

fn world() -> WorldState {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skills = ["journal", "notes"]
        .into_iter()
        .map(|name| Skill {
            name: name.into(),
            path: SourcePath::from(format!("skills/{name}").as_str()),
            content_digest: content,
            files: Vec::new(),
            symlinks: Vec::new(),
            submodules: Vec::new(),
        })
        .collect::<Vec<_>>();
    let packs = vec![Pack {
        name: "toolkit".into(),
        path: SourcePath::from("PACK.md"),
        digest: content,
        description: "fixture toolkit".into(),
        required: vec!["journal".into()],
        optional: vec!["notes".into(), "ghost".into()],
        missing_required: Vec::new(),
        missing_optional: vec!["ghost".into()],
    }];
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
fn packs_members_shared_roots_and_unavailable_items_are_core_facts() {
    let world = world();
    let mut desired = DesiredState::from_world(&world);
    desired
        .apply(DesiredEdit::SetPack {
            name: "toolkit".try_into().unwrap(),
            source: "grimoire".try_into().unwrap(),
            enabled: true,
        })
        .unwrap();
    desired
        .apply(DesiredEdit::SetSkill {
            name: "notes".try_into().unwrap(),
            source: "grimoire".try_into().unwrap(),
            enabled: true,
        })
        .unwrap();

    let tree = project_tree(&world, &desired).unwrap();
    let pack = tree
        .item(&TreeItemKey::Pack {
            source: "grimoire".try_into().unwrap(),
            name: "toolkit".try_into().unwrap(),
        })
        .unwrap();
    assert_eq!(pack.kind, TreeItemKind::Pack(PackSelection::Partial));
    assert_eq!(pack.mode, Some(ProjectionMode::Link));
    assert!(!pack.mode_toggleable);

    let required = tree
        .item(&TreeItemKey::PackMember {
            source: "grimoire".try_into().unwrap(),
            pack: "toolkit".try_into().unwrap(),
            name: "journal".try_into().unwrap(),
        })
        .unwrap();
    assert_eq!(
        required.kind,
        TreeItemKind::Skill(SkillAvailability::Required)
    );
    assert!(required.selected);
    assert!(!required.toggleable);
    assert_eq!(required.mode, Some(ProjectionMode::Link));
    assert!(!required.mode_toggleable);

    let unavailable = tree
        .item(&TreeItemKey::PackMember {
            source: "grimoire".try_into().unwrap(),
            pack: "toolkit".try_into().unwrap(),
            name: "ghost".try_into().unwrap(),
        })
        .unwrap();
    assert_eq!(
        unavailable.kind,
        TreeItemKind::Skill(SkillAvailability::Unavailable)
    );
    assert_eq!(unavailable.inert_reason.as_deref(), Some("unavailable"));

    let notes = tree
        .item(&TreeItemKey::Skill {
            source: "grimoire".try_into().unwrap(),
            name: "notes".try_into().unwrap(),
        })
        .unwrap();
    assert_eq!(
        notes.requested_by,
        [
            RequestRoot::Pack("toolkit".try_into().unwrap()),
            RequestRoot::Skill("notes".try_into().unwrap()),
        ]
        .into_iter()
        .collect()
    );
    assert_eq!(notes.mode, Some(ProjectionMode::Link));
    assert!(!notes.mode_toggleable);
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
            request: grimoire_core::ManifestSkill {
                source: "grimoire".try_into().unwrap(),
                mode: grimoire_core::ProjectionMode::Link,
            },
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
