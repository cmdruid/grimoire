use std::path::PathBuf;

use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};
use grimoire_core::{
    plan, CanonicalIdentity, InstalledLink, PlanningMode, Request, Scope, SnapshotId, SnapshotKind,
    SnapshotStore, SourceAlias, SourceSnapshot, SourceState, TreeItemKey, TrustBaseline,
    TrustReceipt, TrustStore, WorldState,
};
use ratatui::{backend::TestBackend, Terminal};
use skill_grimoire::tui::{draw, TuiModel};

const EMPTY_LOCK: &[u8] = include_bytes!("../../grimoire-core/tests/fixtures/lock/empty.json");

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
        concat!(
            "schema = \"grimoire/manifest@2\"\n",
            "[sources.grimoire]\n",
            "url = \"github:cmdruid/grimoire\"\n",
        )
        .as_bytes()
        .to_vec(),
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
fn one_ui_toggle_reaches_the_exact_core_plan_pane() {
    let world = world();
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
    let mut model = TuiModel::new(world).unwrap();
    model
        .toggle(&TreeItemKey::Skill {
            source: "grimoire".try_into().unwrap(),
            name: "journal".try_into().unwrap(),
        })
        .unwrap();

    assert_eq!(model.plan_bytes().unwrap(), direct.to_bytes().unwrap());

    let backend = TestBackend::new(92, 18);
    let mut terminal = Terminal::new(backend).unwrap();
    terminal.draw(|frame| draw(frame, &model)).unwrap();
    let rendered = terminal.backend().to_string();
    assert!(rendered.contains("Project"));
    assert!(rendered.contains("[x] journal"));
    assert!(rendered.contains("replace_manifest"));
}
