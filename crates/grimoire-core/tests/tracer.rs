use std::collections::BTreeMap;
use std::path::PathBuf;

use grimoire_core::{
    plan, Action, ByteHash, InstalledLink, LockChange, PlanFact, PlanningMode, Preconditions,
    Request, RequestRoot, Scope, SnapshotId, SnapshotKey, SnapshotKind, SnapshotStore, SourceAlias,
    SourceKey, SourceSnapshot, SourceState, StorePrecondition, TrustBaseline, TrustReceipt,
    TrustStore, VendorPrecondition, VendorState, WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};

const MANIFEST: &str = r#"schema = "grimoire/manifest@3"

[sources.grimoire]
url = "github:cmdruid/grimoire"
ref = "main"

[skills]
journal = { source = "grimoire" }
"#;

const EMPTY_LOCK: &str = r#"{
  "schema": "grimoire/lock@3",
  "sources": {},
  "packs": {},
  "skills": {}
}
"#;

fn fixture() -> (SourceSnapshot, String) {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skill = Skill {
        name: "journal".into(),
        path: SourcePath::from("skills/journal"),
        content_digest: content,
        files: Vec::new(),
        symlinks: Vec::new(),
        submodules: Vec::new(),
    };
    let skills = vec![skill];
    let packs: Vec<Pack> = Vec::new();
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&skills, &packs, &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills,
        packs,
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
    };
    let commit = "1".repeat(40);
    let tree = "2".repeat(40);
    let snapshot = SourceSnapshot::new(
        SourceAlias::new("grimoire").unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some(commit.clone()),
            Some(tree.clone()),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        PathBuf::from("/store/grimoire/snapshot"),
        inventory,
    );
    (snapshot, content.to_string())
}

fn trusted(snapshot: SourceSnapshot) -> (SourceState, Vec<u8>) {
    let identity = grimoire_core::CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let review_tree = snapshot.inventory.review_tree_digest.to_string();
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
                review_tree: review_tree.clone(),
            },
            None,
        )
        .unwrap()
        .after;
    (
        SourceState::new(snapshot, SnapshotStore::Valid, false)
            .source_identity(identity, review_tree),
        trust,
    )
}

#[test]
fn one_direct_skill_traces_the_complete_pure_kernel() {
    let (snapshot, content) = fixture();
    let expected_lock = format!(
        concat!(
            "{{\n",
            "  \"schema\": \"grimoire/lock@3\",\n",
            "  \"sources\": {{\n",
            "    \"grimoire\": {{\n",
            "      \"declared\": \"github:cmdruid/grimoire\",\n",
            "      \"kind\": \"git\",\n",
            "      \"ref\": \"main\",\n",
            "      \"commit\": \"{}\",\n",
            "      \"tree\": \"{}\",\n",
            "      \"inventory\": \"{}\"\n",
            "    }}\n",
            "  }},\n",
            "  \"packs\": {{}},\n",
            "  \"skills\": {{\n",
            "    \"journal\": {{\n",
            "      \"source\": \"grimoire\",\n",
            "      \"path\": \"skills/journal\",\n",
            "      \"content\": \"{}\",\n",
            "      \"requested_by\": [\n",
            "        \"skill:journal\"\n",
            "      ]\n",
            "    }}\n",
            "  }}\n",
            "}}\n"
        ),
        "1".repeat(40),
        "2".repeat(40),
        snapshot.id.inventory_digest,
        content
    );

    let (state, trust) = trusted(snapshot.clone());
    let identity = state.identity.clone().unwrap();
    let source_key = SourceKey::derive(&identity);
    let snapshot_key = SnapshotKey::derive(
        grimoire_core::SourceKind::Git,
        snapshot.id.commit.as_deref().unwrap(),
        snapshot.id.tree.as_deref().unwrap(),
        &snapshot.id.inventory_digest,
    )
    .unwrap();
    let world = WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        EMPTY_LOCK.as_bytes().to_vec(),
        [state],
        [("journal", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(Some(trust.clone()));
    let result = plan(&world, Request::Reconcile, PlanningMode::Normal).unwrap();

    assert_eq!(
        result.actions,
        vec![
            Action::PrepareVendor {
                scope: Scope::Project,
                source: "grimoire".try_into().unwrap(),
                skill: "journal".try_into().unwrap(),
                source_key: source_key.clone(),
                snapshot_key: snapshot_key.clone(),
                skill_path: "skills/journal".into(),
                path: ".agents/skills/journal".into(),
                content: content.clone(),
            },
            Action::CreateVendor {
                scope: Scope::Project,
                source: "grimoire".try_into().unwrap(),
                skill: "journal".try_into().unwrap(),
                path: ".agents/skills/journal".into(),
                after: content.clone(),
                added: Vec::new(),
            },
            Action::ReplaceLock {
                scope: Scope::Project,
                before: EMPTY_LOCK.as_bytes().to_vec(),
                after: expected_lock.as_bytes().to_vec(),
                change: LockChange::Resolve,
            },
        ]
    );
    assert!(result.blockers.is_empty());
    assert_eq!(
        result.preconditions,
        Preconditions {
            manifest: Some(ByteHash::of(MANIFEST.as_bytes())),
            lock: Some(ByteHash::of(EMPTY_LOCK.as_bytes())),
            candidates: BTreeMap::new(),
            stores: BTreeMap::from([(
                "grimoire".try_into().unwrap(),
                StorePrecondition {
                    source_key,
                    snapshot_key,
                    inventory: snapshot.id.inventory_digest.clone(),
                    state: SnapshotStore::Valid,
                },
            )]),
            trust: Some(ByteHash::of(&trust)),
            projects: None,
            reachability: None,
            links: BTreeMap::new(),
            vendors: BTreeMap::from([(
                "journal".try_into().unwrap(),
                VendorPrecondition {
                    state: VendorState::Absent,
                    content: None,
                },
            )]),
        }
    );
    assert_eq!(
        result.facts,
        vec![
            PlanFact::ResolvedRoot {
                root: RequestRoot::Skill("journal".try_into().unwrap()),
                source: "grimoire".try_into().unwrap(),
            },
            PlanFact::SourceContribution {
                source: "grimoire".try_into().unwrap(),
            },
        ]
    );
    assert!(!result.is_destructive());
    assert!(result.has_changes());

    let (state, trust) = trusted(snapshot);
    let settled = WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        expected_lock.as_bytes().to_vec(),
        [state],
        [("journal", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(Some(trust))
    .with_vendors([(
        "journal",
        VendorPrecondition {
            state: VendorState::OwnedUnchanged,
            content: Some(content.clone()),
        },
    )])
    .unwrap();
    let first = plan(&settled, Request::Reconcile, PlanningMode::Normal).unwrap();
    let second = plan(&settled, Request::Reconcile, PlanningMode::Normal).unwrap();

    assert_eq!(first, second);
    assert_eq!(
        first.actions,
        vec![Action::RetainVendor {
            scope: Scope::Project,
            source: "grimoire".try_into().unwrap(),
            skill: "journal".try_into().unwrap(),
            path: ".agents/skills/journal".into(),
            content: content.clone(),
        }]
    );
    assert!(!first.has_changes());
    assert!(!first.is_destructive());
}
