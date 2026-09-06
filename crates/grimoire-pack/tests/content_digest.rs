#[path = "support/inventory.rs"]
mod support;

use grimoire_pack::inventory::scan;
use support::TestTree;

fn tree(content: &[u8], mode: u32, target: &[u8]) -> TestTree {
    let mut tree = TestTree::default();
    tree.skill("skills/demo", "demo");
    tree.file("skills/demo/run.sh", mode, content.to_vec());
    tree.symlink("skills/demo/current", target);
    tree
}

#[test]
fn content_mode_and_internal_link_target_each_change_skill_identity() {
    let baseline = scan(&tree(b"echo one\n", 0o100644, b"run.sh")).unwrap();
    let content = scan(&tree(b"echo two\n", 0o100644, b"run.sh")).unwrap();
    let mode = scan(&tree(b"echo one\n", 0o100755, b"run.sh")).unwrap();
    let target = scan(&tree(b"echo one\n", 0o100644, b"./run.sh")).unwrap();
    let digest = baseline.skills[0].content_digest;
    assert_ne!(digest, content.skills[0].content_digest);
    assert_ne!(digest, mode.skills[0].content_digest);
    assert_ne!(digest, target.skills[0].content_digest);
}

#[test]
fn escaping_and_invalid_targets_remain_hashed_facts_and_errors() {
    let escaping = scan(&tree(b"x", 0o100644, b"../../outside")).unwrap();
    let empty = scan(&tree(b"x", 0o100644, b"")).unwrap();
    let nul = scan(&tree(b"x", 0o100644, b"bad\0target")).unwrap();
    assert!(escaping
        .findings
        .iter()
        .any(|finding| finding.code == "escaping-symlink"));
    assert!(empty
        .findings
        .iter()
        .any(|finding| finding.code == "invalid-symlink-target"));
    assert!(nul.findings.iter().any(|finding| finding
        .details
        .get("reason")
        .is_some_and(|value| value == "nul")));
    assert_ne!(
        escaping.skills[0].content_digest,
        empty.skills[0].content_digest
    );
    assert_ne!(empty.skills[0].content_digest, nul.skills[0].content_digest);
}
