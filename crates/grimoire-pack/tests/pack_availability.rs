#[path = "support/inventory.rs"]
mod support;

use grimoire_pack::inventory::{scan, Severity};
use support::TestTree;

fn pack_tree(required: &[&str], optional: &[&str]) -> TestTree {
    let mut tree = TestTree::default();
    tree.skill("skills/present", "present");
    let sequence = |members: &[&str]| {
        if members.is_empty() {
            " []".to_owned()
        } else {
            format!(
                "\n{}",
                members
                    .iter()
                    .map(|m| format!("  - {m}"))
                    .collect::<Vec<_>>()
                    .join("\n")
            )
        }
    };
    tree.file(
        "PACK.md",
        0o100644,
        format!(
            "---\nschema: grimoire/pack@1\nname: test-pack\ndescription: Availability fixture.\nrequired:{}\noptional:{}\n---\n",
            sequence(required),
            sequence(optional)
        ),
    );
    tree
}

#[test]
fn required_absence_is_a_pack_local_fact_only() {
    let inventory = scan(&pack_tree(&["z-missing", "present", "a-missing"], &[])).unwrap();
    let pack = &inventory.packs[0];
    assert_eq!(pack.required, ["a-missing", "present", "z-missing"]);
    assert_eq!(pack.missing_required, ["a-missing", "z-missing"]);
    assert!(pack.missing_optional.is_empty());
    assert!(inventory.findings.is_empty());
    assert!(inventory.is_valid());
}

#[test]
fn optional_absence_warns_and_changes_the_inventory_digest() {
    let missing = scan(&pack_tree(&[], &["z-missing", "present", "a-missing"])).unwrap();
    let available = scan(&pack_tree(&[], &["present"])).unwrap();
    let pack = &missing.packs[0];
    assert_eq!(pack.optional, ["a-missing", "present", "z-missing"]);
    assert_eq!(pack.missing_optional, ["a-missing", "z-missing"]);
    let warnings: Vec<_> = missing
        .findings
        .iter()
        .filter(|finding| finding.code == "missing-optional-member")
        .collect();
    assert_eq!(warnings.len(), 2);
    assert!(warnings
        .iter()
        .all(|finding| finding.severity == Severity::Warning));
    assert!(missing.is_valid());
    assert_ne!(missing.inventory_digest, available.inventory_digest);
}
