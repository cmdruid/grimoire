#[path = "support/inventory.rs"]
mod support;

use grimoire_pack::inventory::{compute_inventory_digest, scan};
use support::TestTree;

fn tree() -> TestTree {
    let mut tree = TestTree::default();
    tree.skill("skills/demo", "demo");
    tree.file("skills/demo/body", 0o100644, b"body".to_vec());
    tree
}

#[test]
fn traversal_order_does_not_change_inventory_identity() {
    let forward = scan(&tree()).unwrap();
    let reverse = scan(&tree().reversed()).unwrap();
    assert_eq!(forward.inventory_digest, reverse.inventory_digest);
    assert_eq!(forward.review_tree_digest, reverse.review_tree_digest);
}

#[test]
fn human_messages_do_not_enter_inventory_identity() {
    let mut malformed = TestTree::default();
    malformed.file("PACK.md", 0o100644, b"not frontmatter".to_vec());
    let inventory = scan(&malformed).unwrap();
    let mut findings = inventory.findings.clone();
    findings[0].message = "a completely different explanation".into();
    assert_eq!(
        inventory.inventory_digest,
        compute_inventory_digest(&inventory.skills, &inventory.packs, &findings)
    );
}

#[test]
fn finding_path_presence_and_details_change_inventory_identity() {
    let mut colliding = tree();
    colliding.file("A", 0o100644, b"one".to_vec());
    colliding.file("a", 0o100644, b"two".to_vec());
    assert_ne!(
        scan(&tree()).unwrap().inventory_digest,
        scan(&colliding).unwrap().inventory_digest
    );
}
