#[path = "support/inventory.rs"]
mod support;

use std::io::{Cursor, Read};
use std::panic::catch_unwind;
use std::sync::atomic::{AtomicUsize, Ordering};

use grimoire_pack::inventory::{
    scan, InventoryError, SourcePath, TreeEntry, TreeReader, VisitDecision,
};
use support::TestTree;
use yaml_rust2::YamlLoader;

#[test]
fn upstream_yaml_acceptance_is_an_executable_red_arm_for_pack_policy() {
    for (name, field) in [
        ("old-schema", "schema: grimoire/pack@0"),
        ("face", "face: classic"),
        ("unknown", "extension: enabled"),
    ] {
        let yaml = format!(
            "{field}\nname: fixture\ndescription: fixture\nrequired: [one]\noptional: []\n"
        );
        let mut tree = TestTree::default();
        tree.file(
            "PACK.md",
            0o100644,
            format!("---\n{yaml}---\n").into_bytes(),
        );
        tree.skill("skills/one", "one");
        let inventory = scan(&tree).unwrap();
        assert!(!inventory.is_valid(), "production accepted {name}");

        let upstream_accepts = YamlLoader::load_from_str(&yaml).is_ok();
        let red = catch_unwind(|| assert_rejected(upstream_accepts));
        assert!(red.is_err(), "unguarded YAML parser did not expose {name}");
    }
}

#[test]
fn a_reader_that_disables_stop_reaches_the_entry_canary() {
    let reader = IgnoresStop {
        visits: AtomicUsize::new(0),
    };
    let inventory = scan(&reader).unwrap();
    assert!(inventory
        .findings
        .iter()
        .any(|finding| finding.code == "discovery-entry-limit"));

    let red = catch_unwind(|| assert_bounded(reader.visits.load(Ordering::SeqCst)));
    assert!(red.is_err(), "disabled Stop did not cross the entry canary");
}

fn assert_rejected(accepted: bool) {
    assert!(!accepted, "forbidden policy input was accepted");
}

fn assert_bounded(visits: usize) {
    assert!(visits <= 100_001, "reader enumerated {visits} entries");
}

struct IgnoresStop {
    visits: AtomicUsize,
}

impl TreeReader for IgnoresStop {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> Result<VisitDecision, InventoryError>,
    ) -> Result<(), InventoryError> {
        for index in 0..100_002 {
            self.visits.fetch_add(1, Ordering::SeqCst);
            let path = SourcePath::new(format!("outer/{index:06}.txt").into_bytes());
            let mut entry = TreeEntry::file(path, 0o100644);
            entry.size = Some(0);
            let _ = visitor(entry)?;
        }
        Ok(())
    }

    fn open<'a>(&'a self, _path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        Ok(Box::new(Cursor::new(Vec::new())))
    }
}
