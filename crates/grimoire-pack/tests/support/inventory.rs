#![allow(dead_code)]

use std::collections::BTreeMap;
use std::io::{Cursor, Read};

use grimoire_pack::inventory::{InventoryError, SourcePath, TreeEntry, TreeReader};

#[derive(Clone, Default)]
pub struct TestTree {
    pub entries: Vec<TreeEntry>,
    pub files: BTreeMap<SourcePath, Vec<u8>>,
    reverse: bool,
}

impl TestTree {
    pub fn reversed(mut self) -> Self {
        self.reverse = true;
        self
    }

    pub fn directory(&mut self, path: &str) {
        self.entries.push(TreeEntry::directory(path));
    }

    pub fn file(&mut self, path: &str, mode: u32, bytes: impl Into<Vec<u8>>) {
        let bytes = bytes.into();
        let path = SourcePath::from(path);
        let mut entry = TreeEntry::file(path.clone(), mode);
        entry.size = Some(bytes.len() as u64);
        self.entries.push(entry);
        self.files.insert(path, bytes);
    }

    pub fn skill(&mut self, root: &str, name: &str) {
        self.directory(root);
        self.file(
            &format!("{root}/SKILL.md"),
            0o100644,
            format!("---\nname: {name}\n---\n"),
        );
    }

    pub fn symlink(&mut self, path: &str, target: &[u8]) {
        self.entries.push(TreeEntry::symlink(path, target.to_vec()));
    }
}

impl TreeReader for TestTree {
    fn entries(&self) -> Result<Vec<TreeEntry>, InventoryError> {
        let mut entries = self.entries.clone();
        if self.reverse {
            entries.reverse();
        }
        Ok(entries)
    }

    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        self.files
            .get(path)
            .map(|bytes| Box::new(Cursor::new(bytes.as_slice())) as Box<dyn Read>)
            .ok_or_else(|| InventoryError::Tree {
                path: path.clone(),
                message: "not a file".into(),
            })
    }
}
