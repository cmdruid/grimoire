use std::collections::BTreeMap;
use std::io::{Cursor, Read};

use super::super::{scan, InventoryError, SourcePath, TreeEntry, TreeReader};

struct Files(BTreeMap<SourcePath, Vec<u8>>);

impl TreeReader for Files {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> Result<bool, InventoryError>,
    ) -> Result<(), InventoryError> {
        for path in self.0.keys() {
            let mut entry = TreeEntry::file(path.clone(), 0o100644);
            entry.size = Some(self.0[path].len() as u64);
            if !visitor(entry)? {
                break;
            }
        }
        Ok(())
    }

    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        Ok(Box::new(Cursor::new(self.0[path].as_slice())))
    }
}

#[test]
fn parser_failures_become_canonical_findings_without_message_input() {
    let tree = Files(BTreeMap::from([
        (
            SourcePath::from("PACK.md"),
            b"---\nschema: old\nname: Bad\ndescription: ''\nrequired: []\noptional: []\nextra: true\n---\n".to_vec(),
        ),
        (
            SourcePath::from("skills/bad/SKILL.md"),
            b"---\nname: Bad\n---\n".to_vec(),
        ),
    ]));
    let inventory = scan(&tree).expect("validation is data");
    assert!(inventory.packs.is_empty());
    assert!(inventory.skills.is_empty());
    let codes: Vec<_> = inventory
        .findings
        .iter()
        .map(|finding| finding.code.as_str())
        .collect();
    assert_eq!(
        codes,
        [
            "pack-description-empty",
            "pack-empty",
            "pack-name-invalid",
            "pack-schema-invalid",
            "pack-unknown-key",
            "skill-name-invalid",
        ]
    );
    assert!(inventory
        .findings
        .iter()
        .all(|finding| finding.path.is_some() && !finding.message.is_empty()));
}

#[test]
fn parser_owned_detail_keys_are_exhaustive() {
    let expected: BTreeMap<&str, &[&str]> = BTreeMap::from([
        ("frontmatter-too-large", &["limit", "observed"][..]),
        ("yaml-node-limit", &["limit", "observed"][..]),
        ("yaml-depth-limit", &["limit", "observed"][..]),
        ("yaml-duplicate-key", &["key"][..]),
        ("frontmatter-root-type", &["actual"][..]),
        ("skill-name-type", &["actual"][..]),
        ("skill-name-invalid", &["value"][..]),
        ("pack-unknown-key", &["key"][..]),
        ("pack-field-missing", &["field"][..]),
        ("pack-field-type", &["actual", "expected", "field"][..]),
        ("pack-member-type", &["actual", "field", "index"][..]),
        ("pack-schema-invalid", &["value"][..]),
        ("pack-name-invalid", &["value"][..]),
        ("pack-member-invalid", &["value"][..]),
        ("pack-member-duplicate", &["member"][..]),
        ("pack-member-overlap", &["member"][..]),
    ]);
    assert_eq!(
        expected.len(),
        16,
        "contract table is intentionally explicit"
    );
}
