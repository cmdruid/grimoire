#[path = "support/inventory.rs"]
mod support;

use grimoire_pack::inventory::{scan, SourcePath};
use support::TestTree;

#[test]
fn file_capabilities_are_bounded_byte_facts() {
    let mut tree = TestTree::default();
    tree.skill("skills/demo", "demo");
    let mut script = b"#!".to_vec();
    script.extend(std::iter::repeat_n(b'x', 600));
    script.push(b'\n');
    script.push(0);
    tree.file("skills/demo/run", 0o100755, script);
    let inventory = scan(&tree).unwrap();
    let file = inventory.skills[0]
        .files
        .iter()
        .find(|file| file.path == SourcePath::from("run"))
        .unwrap();
    assert_eq!(file.mode, "100755");
    assert!(file.executable);
    assert!(file.binary);
    assert_eq!(file.shebang.as_ref().unwrap().len(), 512);
}

#[test]
fn review_byte_limit_uses_the_first_rejected_byte() {
    let mut tree = TestTree::default();
    tree.file("large", 0o100644, Vec::new());
    tree.entries[0].size = Some(134_217_729);
    let inventory = scan(&tree).unwrap();
    let finding = inventory
        .findings
        .iter()
        .find(|finding| finding.code == "review-byte-limit")
        .unwrap();
    assert_eq!(finding.details["limit"], "134217728");
    assert_eq!(finding.details["observed"], "134217729");
}
