use std::collections::BTreeMap;
use std::io::{Cursor, Read};

use super::super::digest::{inventory_bytes, review_tree_bytes, skill_content_bytes};
use super::super::{scan, InventoryError, SourcePath, TreeEntry, TreeReader, VisitDecision};

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

struct MemoryTree {
    entries: Vec<TreeEntry>,
    files: BTreeMap<SourcePath, Vec<u8>>,
}

impl MemoryTree {
    fn fixture() -> Self {
        let root_skill = b"---\nname: root\n---\n\n# Root\n".to_vec();
        let helper_skill = b"---\nname: helper\n---\n\n# Helper\n".to_vec();
        let pack = b"---\nschema: grimoire/pack@1\nname: clankshop\ndescription: Test pack\nrequired:\n  - root\noptional:\n  - helper\n---\n".to_vec();
        let script = b"#!/bin/sh\necho root\n".to_vec();
        let mut files = BTreeMap::new();
        for (path, bytes) in [
            ("PACK.md", pack),
            ("skills/helper/SKILL.md", helper_skill),
            ("skills/root/SKILL.md", root_skill),
            ("skills/root/scripts/run.sh", script),
        ] {
            files.insert(SourcePath::from(path), bytes);
        }
        Self {
            entries: vec![
                TreeEntry::file("PACK.md", 0o100644),
                TreeEntry::directory("skills"),
                TreeEntry::directory("skills/helper"),
                TreeEntry::file("skills/helper/SKILL.md", 0o100644),
                TreeEntry::symlink("skills/helper/copy.md", b"SKILL.md".to_vec()),
                TreeEntry::directory("skills/root"),
                TreeEntry::file("skills/root/SKILL.md", 0o100644),
                TreeEntry::directory("skills/root/scripts"),
                TreeEntry::file("skills/root/scripts/run.sh", 0o100755),
            ],
            files,
        }
    }
}

impl TreeReader for MemoryTree {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> Result<VisitDecision, InventoryError>,
    ) -> Result<(), InventoryError> {
        let mut entries = self.entries.clone();
        entries.reverse();
        for mut entry in entries {
            if entry.kind == super::super::TreeEntryKind::File && entry.size.is_none() {
                entry.size = self.files.get(&entry.path).map(|bytes| bytes.len() as u64);
            }
            if visitor(entry)? == VisitDecision::Stop {
                break;
            }
        }
        Ok(())
    }

    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        let bytes = self.files.get(path).ok_or_else(|| InventoryError::Tree {
            path: path.clone(),
            message: "not a regular file".into(),
        })?;
        Ok(Box::new(Cursor::new(bytes.as_slice())))
    }
}

#[test]
fn one_tree_becomes_one_canonical_inventory() {
    let inventory = scan(&MemoryTree::fixture()).expect("inventory scans");
    assert_eq!(
        inventory
            .skills
            .iter()
            .map(|skill| skill.name.as_str())
            .collect::<Vec<_>>(),
        ["helper", "root"]
    );
    assert_eq!(inventory.packs.len(), 1);
    assert_eq!(inventory.packs[0].name, "clankshop");
    assert_eq!(inventory.packs[0].required, ["root"]);
    assert_eq!(inventory.packs[0].optional, ["helper"]);
    assert!(inventory.findings.is_empty());
    assert_eq!(inventory.skills[0].symlinks.len(), 1);
    assert_eq!(inventory.skills[1].files.len(), 2);
    let helper_skill = b"---\nname: helper\n---\n\n# Helper\n";
    let helper_preimage = skill_content_bytes(&[
        (b'F', b"SKILL.md", b"100644", helper_skill),
        (b'L', b"copy.md", b"120000", b"SKILL.md"),
    ]);
    assert_eq!(
        hex(&helper_preimage),
        "6772696d6f6972652f736b696c6c2d636f6e74656e74403100460000000000000008534b494c4c2e6d640000000000000006313030363434000000000000001f2d2d2d0a6e616d653a2068656c7065720a2d2d2d0a0a232048656c7065720a4c0000000000000007636f70792e6d6400000000000000063132303030300000000000000008534b494c4c2e6d64"
    );
    assert_eq!(
        inventory.skills[0].content_digest.to_string(),
        "sha256:d98827d1aec853458ed2d203a4728cc308ce9dc3a9a96da1ad3e424087105abb"
    );
    let root_skill = b"---\nname: root\n---\n\n# Root\n";
    let root_script = b"#!/bin/sh\necho root\n";
    let root_preimage = skill_content_bytes(&[
        (b'F', b"SKILL.md", b"100644", root_skill),
        (b'F', b"scripts/run.sh", b"100755", root_script),
    ]);
    assert_eq!(
        hex(&root_preimage),
        "6772696d6f6972652f736b696c6c2d636f6e74656e74403100460000000000000008534b494c4c2e6d640000000000000006313030363434000000000000001b2d2d2d0a6e616d653a20726f6f740a2d2d2d0a0a2320526f6f740a46000000000000000e736372697074732f72756e2e73680000000000000006313030373535000000000000001423212f62696e2f73680a6563686f20726f6f740a"
    );
    assert_eq!(
        inventory.skills[1].content_digest.to_string(),
        "sha256:dac22413d43775828b480b061dc43077cf4cae3c34b6d00570fa635f2ad6122a"
    );

    assert_eq!(
        inventory.inventory_digest.to_string(),
        "sha256:584d49abaf74124c16197e046c20a975d1596b793184f75b2b0279fd01ae77fe"
    );
    assert_eq!(
        inventory.review_tree_digest.to_string(),
        "sha256:1de34fce5dd8ee25a4f306989e76c0c76db353130a2c8e0360c9618de88c4824"
    );
    assert_eq!(
        hex(&inventory_bytes(
            &inventory.skills,
            &inventory.packs,
            &inventory.findings,
        )),
        "6772696d6f6972652f736f757263652d696e76656e746f727940310053000000000000000668656c706572000000000000000d736b696c6c732f68656c70657200000000000000477368613235363a64393838323764316165633835333435386564326432303361343732386363333038636539646333613961393664613161643365343234303837313035616262530000000000000004726f6f74000000000000000b736b696c6c732f726f6f7400000000000000477368613235363a64616332323431336434333737353832386234383062303631646334333037376366346361653363333462366430303537306661363335663261643631323261500000000000000009636c616e6b73686f7000000000000000075041434b2e6d6400000000000000477368613235363a33663837306534313364353930626566393937303438353466346563616565383164396232666266326138366230363165386534383736643362303461313534"
    );
    assert_eq!(
        hex(&review_tree_bytes(&inventory.reviewed_entries)),
        "6772696d6f6972652f7265766965772d7472656540310000000000000000075041434b2e6d64000000000000000466696c65000000000000000631303036343400000000000000477368613235363a336638373065343133643539306265663939373034383534663465636165653831643962326662663261383662303631653865343837366433623034613135340000000000000008736e617073686f74000000000000000000000000000000000000000000000016736b696c6c732f68656c7065722f534b494c4c2e6d64000000000000000466696c65000000000000000631303036343400000000000000477368613235363a373331653233626139343335313433386130623432643030633133653435343264356632343234326163383865303264633731636330356136363366386138360000000000000013736b696c6c00736b696c6c732f68656c706572000000000000000000000000000000000000000000000015736b696c6c732f68656c7065722f636f70792e6d64000000000000000773796d6c696e6b00000000000000063132303030300000000000000008534b494c4c2e6d640000000000000013736b696c6c00736b696c6c732f68656c7065720000000000000008696e7465726e616c00000000000000000000000000000014736b696c6c732f726f6f742f534b494c4c2e6d64000000000000000466696c65000000000000000631303036343400000000000000477368613235363a613936316231336263383835333861333361653434363538346264316237373737616666663633636164613134386365393563373763626564613764363230660000000000000011736b696c6c00736b696c6c732f726f6f7400000000000000000000000000000000000000000000001a736b696c6c732f726f6f742f736372697074732f72756e2e7368000000000000000466696c65000000000000000631303037353500000000000000477368613235363a623931353430623938383237366334356335303163346338353865623134366661616361646163316565343338363361383230323532366365626163663464370000000000000011736b696c6c00736b696c6c732f726f6f7400000000000000000000000000000000"
    );
}
