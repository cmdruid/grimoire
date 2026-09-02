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
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> Result<bool, InventoryError>,
    ) -> Result<(), InventoryError> {
        let mut entries = self.entries.clone();
        if self.reverse {
            entries.reverse();
        }
        for entry in entries {
            if !visitor(entry)? {
                break;
            }
        }
        Ok(())
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
pub struct FsTree {
    root: std::path::PathBuf,
}

#[cfg(unix)]
impl FsTree {
    pub fn new(root: impl Into<std::path::PathBuf>) -> Self {
        Self { root: root.into() }
    }

    fn walk(
        &self,
        directory: &std::path::Path,
        relative: &[u8],
        entries: &mut Vec<TreeEntry>,
    ) -> Result<(), InventoryError> {
        use std::os::unix::ffi::OsStrExt;
        use std::os::unix::fs::{FileTypeExt, MetadataExt};

        let read_dir = std::fs::read_dir(directory).map_err(|error| self.error(relative, error))?;
        let mut children = read_dir
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| self.error(relative, error))?;
        children.sort_by(|left, right| {
            left.file_name()
                .as_bytes()
                .cmp(right.file_name().as_bytes())
        });
        for child in children {
            let name = child.file_name();
            let name = name.as_bytes();
            let mut child_relative = relative.to_vec();
            if !child_relative.is_empty() {
                child_relative.push(b'/');
            }
            child_relative.extend_from_slice(name);
            let path = SourcePath::new(child_relative.clone());
            let metadata = std::fs::symlink_metadata(child.path())
                .map_err(|error| self.error(&child_relative, error))?;
            let file_type = metadata.file_type();
            if file_type.is_dir() {
                entries.push(TreeEntry::directory(path));
                if !ignored_directory(name) && !child.path().join(".git").exists() {
                    self.walk(&child.path(), &child_relative, entries)?;
                }
            } else if file_type.is_file() {
                let mut entry = TreeEntry::file(path, metadata.mode());
                entry.size = Some(metadata.len());
                entries.push(entry);
            } else if file_type.is_symlink() {
                let target = std::fs::read_link(child.path())
                    .map_err(|error| self.error(&child_relative, error))?;
                entries.push(TreeEntry::symlink(path, target.as_os_str().as_bytes()));
            } else {
                let kind = if file_type.is_fifo() {
                    grimoire_pack::inventory::TreeEntryKind::Fifo
                } else if file_type.is_socket() {
                    grimoire_pack::inventory::TreeEntryKind::Socket
                } else {
                    grimoire_pack::inventory::TreeEntryKind::Device
                };
                entries.push(TreeEntry {
                    path,
                    kind,
                    mode: metadata.mode(),
                    size: None,
                    link_target: None,
                    submodule_commit: None,
                });
            }
        }
        Ok(())
    }

    fn error(&self, path: &[u8], error: std::io::Error) -> InventoryError {
        InventoryError::Tree {
            path: SourcePath::new(path.to_vec()),
            message: error.to_string(),
        }
    }
}

#[cfg(unix)]
impl TreeReader for FsTree {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> Result<bool, InventoryError>,
    ) -> Result<(), InventoryError> {
        let mut entries = Vec::new();
        self.walk(&self.root, b"", &mut entries)?;
        for entry in entries {
            if !visitor(entry)? {
                break;
            }
        }
        Ok(())
    }

    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError> {
        use std::os::unix::ffi::OsStrExt;

        let relative = std::path::Path::new(std::ffi::OsStr::from_bytes(path.as_bytes()));
        let full = self.root.join(relative);
        let metadata =
            std::fs::symlink_metadata(&full).map_err(|error| self.error(path.as_bytes(), error))?;
        if !metadata.file_type().is_file() {
            return Err(InventoryError::Tree {
                path: path.clone(),
                message: "entry is no longer a regular file".into(),
            });
        }
        std::fs::File::open(full)
            .map(|file| Box::new(file) as Box<dyn Read>)
            .map_err(|error| self.error(path.as_bytes(), error))
    }
}

#[cfg(unix)]
fn ignored_directory(name: &[u8]) -> bool {
    matches!(
        name,
        b".git"
            | b".hg"
            | b".svn"
            | b".grimoire"
            | b"node_modules"
            | b"target"
            | b".cache"
            | b".tmp"
            | b".worktrees"
            | b".workstreams"
            | b"build"
            | b"dist"
            | b"vendor"
            | b"fixtures"
    )
}
