use std::collections::BTreeMap;
use std::path::PathBuf;

use grimoire_core::{
    plan, Action, ByteHash, InstalledLink, LinkPrecondition, PlanFact, PlanningMode, Preconditions,
    Request, RequestRoot, Scope, SnapshotId, SnapshotKind, SourceAlias, SourceSnapshot, WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};

const MANIFEST: &str = r#"schema = "grimoire/manifest@1"

[sources.grimoire]
url = "github:cmdruid/grimoire"
ref = "main"

[skills]
journal = { source = "grimoire" }
"#;

const EMPTY_LOCK: &str = r#"{
  "schema": "grimoire/lock@1",
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

#[test]
fn one_direct_skill_traces_the_complete_pure_kernel() {
    let (snapshot, content) = fixture();
    let target = PathBuf::from("/store/grimoire/snapshot/skills/journal");
    let expected_lock = format!(
        concat!(
            "{{\n",
            "  \"schema\": \"grimoire/lock@1\",\n",
            "  \"sources\": {{\n",
            "    \"grimoire\": {{\n",
            "      \"declared\": \"github:cmdruid/grimoire\",\n",
            "      \"kind\": \"git\",\n",
            "      \"ref\": \"main\",\n",
            "      \"commit\": \"{}\",\n",
            "      \"tree\": \"{}\"\n",
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
        content
    );

    let world = WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        EMPTY_LOCK.as_bytes().to_vec(),
        [snapshot.clone()],
        [("journal", InstalledLink::Absent)],
        None,
    )
    .unwrap();
    let result = plan(&world, Request::Reconcile, PlanningMode::Normal).unwrap();

    assert_eq!(
        result.actions,
        vec![
            Action::ReplaceLock {
                scope: Scope::Project,
                before: EMPTY_LOCK.as_bytes().to_vec(),
                after: expected_lock.as_bytes().to_vec(),
            },
            Action::CreateLink {
                scope: Scope::Project,
                skill: "journal".try_into().unwrap(),
                target: target.clone(),
            },
        ]
    );
    assert!(result.blockers.is_empty());
    assert_eq!(
        result.preconditions,
        Preconditions {
            manifest: Some(ByteHash::of(MANIFEST.as_bytes())),
            lock: Some(ByteHash::of(EMPTY_LOCK.as_bytes())),
            links: BTreeMap::from([("journal".try_into().unwrap(), LinkPrecondition::Absent,)]),
        }
    );
    assert_eq!(
        result.facts,
        vec![PlanFact::ResolvedRoot {
            root: RequestRoot::Skill("journal".try_into().unwrap()),
            source: "grimoire".try_into().unwrap(),
        }]
    );
    assert!(!result.is_destructive());
    assert!(result.has_changes());

    let settled = WorldState::from_bytes(
        Scope::Project,
        MANIFEST.as_bytes().to_vec(),
        expected_lock.as_bytes().to_vec(),
        [snapshot],
        [("journal", InstalledLink::Symlink(target.clone()))],
        None,
    )
    .unwrap();
    let first = plan(&settled, Request::Reconcile, PlanningMode::Normal).unwrap();
    let second = plan(&settled, Request::Reconcile, PlanningMode::Normal).unwrap();

    assert_eq!(first, second);
    assert_eq!(
        first.actions,
        vec![Action::RetainLink {
            scope: Scope::Project,
            skill: "journal".try_into().unwrap(),
            target,
        }]
    );
    assert!(!first.has_changes());
    assert!(!first.is_destructive());
}
