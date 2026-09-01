#[path = "support/inventory.rs"]
mod support;

use grimoire_pack::inventory::{scan, SourcePath, TreeEntry, TreeEntryKind};
use support::TestTree;

#[test]
fn every_reviewed_fact_changes_review_tree_identity() {
    let mut baseline = TestTree::default();
    baseline.skill("skills/demo", "demo");
    baseline.file("README.md", 0o100644, b"one".to_vec());
    let mut changed = baseline.clone();
    changed
        .files
        .insert(SourcePath::from("README.md"), b"two".to_vec());
    assert_ne!(
        scan(&baseline).unwrap().review_tree_digest,
        scan(&changed).unwrap().review_tree_digest
    );
}

#[test]
fn submodule_boundary_and_commit_are_retained() {
    let mut tree = TestTree::default();
    tree.entries.push(TreeEntry {
        path: SourcePath::from("dependency"),
        kind: TreeEntryKind::Submodule,
        mode: 0o160000,
        size: None,
        link_target: None,
        submodule_commit: Some("0123456789abcdef0123456789abcdef01234567".into()),
    });
    let inventory = scan(&tree).unwrap();
    assert_eq!(inventory.reviewed_entries.len(), 1);
    assert_eq!(
        inventory.reviewed_entries[0].path,
        SourcePath::from("dependency")
    );
    assert!(inventory.findings.is_empty());
}
