use std::path::PathBuf;

use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};
use grimoire_core::{
    CanonicalIdentity, InstalledLink, Scope, SnapshotId, SnapshotKind, SnapshotStore, SourceAlias,
    SourceSnapshot, SourceState, TrustBaseline, TrustReceipt, TrustStore, WorldState,
};

const EMPTY_LOCK: &[u8] = include_bytes!("../../../grimoire-core/tests/fixtures/lock/empty.json");

pub fn world(scope: Scope, alias: &str, skills: &[&str], manifest: &str) -> WorldState {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skills = skills
        .iter()
        .map(|name| Skill {
            name: (*name).into(),
            path: SourcePath::from(format!("skills/{name}").as_str()),
            content_digest: content,
            files: Vec::new(),
            symlinks: Vec::new(),
            submodules: Vec::new(),
        })
        .collect::<Vec<_>>();
    let links = skills
        .iter()
        .map(|skill| (skill.name.clone(), InstalledLink::Absent))
        .collect::<Vec<_>>();
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
        SourceAlias::new(alias).unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some("1".repeat(40)),
            Some("2".repeat(40)),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        PathBuf::from(format!("/store/{alias}/snapshot")),
        inventory,
    );
    let declared = format!("github:fixture/{alias}");
    let identity = CanonicalIdentity::remote(&declared).unwrap();
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
    let state = SourceState::new(snapshot, SnapshotStore::Valid, false)
        .source_identity(identity, review_tree);
    WorldState::from_bytes(
        scope,
        manifest.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [state.clone()],
        links
            .iter()
            .map(|(name, link)| (name.as_str(), link.clone())),
        None,
    )
    .unwrap()
    .with_locked_snapshot(state)
    .with_trust_bytes(Some(trust))
}
