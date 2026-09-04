use std::cell::RefCell;
use std::io::{Cursor, Read};

use super::super::{
    scan_skill_tree, InventoryError, SourcePath, TreeEntry, TreeReader, VisitDecision,
};

const MANIFEST: &[u8] = b"---\nname: one\ndescription: bounded fixture\n---\n";

struct CountingTree {
    visits: RefCell<Vec<usize>>,
}

impl TreeReader for CountingTree {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> Result<VisitDecision, InventoryError>,
    ) -> Result<(), InventoryError> {
        let mut visited = 0;
        for index in 0..=100_001 {
            let entry = if index == 0 {
                let mut entry = TreeEntry::file("SKILL.md", 0o100644);
                entry.size = Some(MANIFEST.len() as u64);
                entry
            } else {
                TreeEntry::directory(SourcePath::new(format!("entry-{index:06}").into_bytes()))
            };
            visited += 1;
            if visitor(entry)? == VisitDecision::Stop {
                break;
            }
        }
        self.visits.borrow_mut().push(visited);
        Ok(())
    }

    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        if path.as_bytes() == b"SKILL.md" {
            Ok(Box::new(Cursor::new(MANIFEST)))
        } else {
            Err(InventoryError::Tree {
                path: path.clone(),
                message: "not a regular file".into(),
            })
        }
    }
}

#[test]
fn strict_skill_validation_stops_every_traversal_at_the_entry_boundary() {
    let reader = CountingTree {
        visits: RefCell::new(Vec::new()),
    };
    let inventory = scan_skill_tree(&reader, "one").unwrap();

    assert!(inventory
        .findings
        .iter()
        .any(|finding| finding.code == "discovery-entry-limit"));
    assert_eq!(reader.visits.into_inner(), vec![100_001, 100_001, 100_001]);
}
