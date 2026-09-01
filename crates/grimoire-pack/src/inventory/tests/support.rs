use std::collections::BTreeMap;
use std::io::{Cursor, Read};

use super::super::{InventoryError, SourcePath, TreeEntry, TreeReader};

#[derive(Default)]
pub(crate) struct MemoryTree {
    pub entries: Vec<TreeEntry>,
    pub files: BTreeMap<SourcePath, Vec<u8>>,
}

impl MemoryTree {
    pub fn file(&mut self, path: impl Into<SourcePath>, bytes: impl Into<Vec<u8>>) {
        let path = path.into();
        let bytes = bytes.into();
        let mut entry = TreeEntry::file(path.clone(), 0o100644);
        entry.size = Some(bytes.len() as u64);
        self.entries.push(entry);
        self.files.insert(path, bytes);
    }

    pub fn skill(&mut self, root: &str, name: &str) {
        self.entries.push(TreeEntry::directory(root));
        self.file(
            format!("{root}/SKILL.md").as_str(),
            format!("---\nname: {name}\n---\n").into_bytes(),
        );
    }

    pub fn pack(&mut self, path: &str, name: &str, member: &str) {
        self.file(
            path,
            format!(
                "---\nschema: grimoire/pack@1\nname: {name}\ndescription: Pack\nrequired:\n  - {member}\noptional: []\n---\n"
            )
            .into_bytes(),
        );
    }
}

impl TreeReader for MemoryTree {
    fn entries(&self) -> Result<Vec<TreeEntry>, InventoryError> {
        Ok(self.entries.clone())
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

#[cfg(unix)]
pub(crate) struct FixtureTree {
    root: std::path::PathBuf,
}

#[cfg(unix)]
impl FixtureTree {
    pub fn new(root: impl Into<std::path::PathBuf>) -> Self {
        Self { root: root.into() }
    }

    fn walk(
        &self,
        directory: &std::path::Path,
        entries: &mut Vec<TreeEntry>,
    ) -> Result<(), InventoryError> {
        use std::os::unix::ffi::OsStrExt;
        use std::os::unix::fs::MetadataExt;

        let read = std::fs::read_dir(directory).map_err(|error| InventoryError::Tree {
            path: SourcePath::from(""),
            message: error.to_string(),
        })?;
        for child in read {
            let child = child.map_err(|error| InventoryError::Tree {
                path: SourcePath::from(""),
                message: error.to_string(),
            })?;
            let path = child.path();
            let metadata =
                std::fs::symlink_metadata(&path).map_err(|error| InventoryError::Tree {
                    path: SourcePath::from(""),
                    message: error.to_string(),
                })?;
            let relative = path.strip_prefix(&self.root).unwrap();
            let raw = SourcePath::new(relative.as_os_str().as_bytes().to_vec());
            let file_type = metadata.file_type();
            if file_type.is_dir() {
                entries.push(TreeEntry::directory(raw));
                self.walk(&path, entries)?;
            } else if file_type.is_file() {
                let mut entry = TreeEntry::file(raw, metadata.mode());
                entry.size = Some(metadata.len());
                entries.push(entry);
            } else if file_type.is_symlink() {
                let target = std::fs::read_link(&path).map_err(|error| InventoryError::Tree {
                    path: raw.clone(),
                    message: error.to_string(),
                })?;
                entries.push(TreeEntry::symlink(
                    raw,
                    target.as_os_str().as_bytes().to_vec(),
                ));
            }
        }
        Ok(())
    }
}

#[cfg(unix)]
impl TreeReader for FixtureTree {
    fn entries(&self) -> Result<Vec<TreeEntry>, InventoryError> {
        let mut entries = Vec::new();
        self.walk(&self.root, &mut entries)?;
        Ok(entries)
    }

    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        use std::os::unix::ffi::{OsStrExt, OsStringExt};

        let path = self
            .root
            .join(std::ffi::OsString::from_vec(path.as_bytes().to_vec()));
        let metadata = std::fs::symlink_metadata(&path).map_err(|error| InventoryError::Tree {
            path: SourcePath::new(path.as_os_str().as_bytes().to_vec()),
            message: error.to_string(),
        })?;
        if !metadata.file_type().is_file() {
            return Err(InventoryError::Tree {
                path: SourcePath::new(path.as_os_str().as_bytes().to_vec()),
                message: "entry changed kind".into(),
            });
        }
        std::fs::File::open(&path)
            .map(|file| Box::new(file) as Box<dyn Read>)
            .map_err(|error| InventoryError::Tree {
                path: SourcePath::new(path.as_os_str().as_bytes().to_vec()),
                message: error.to_string(),
            })
    }
}
