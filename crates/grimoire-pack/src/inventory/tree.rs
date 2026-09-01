use std::io::Read;

use super::{InventoryError, SourcePath};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum TreeEntryKind {
    Directory,
    File,
    Symlink,
    Submodule,
    Device,
    Fifo,
    Socket,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TreeEntry {
    pub path: SourcePath,
    pub kind: TreeEntryKind,
    pub mode: u32,
    pub link_target: Option<Vec<u8>>,
    pub submodule_commit: Option<String>,
}

impl TreeEntry {
    pub fn directory(path: impl Into<SourcePath>) -> Self {
        Self {
            path: path.into(),
            kind: TreeEntryKind::Directory,
            mode: 0o040755,
            link_target: None,
            submodule_commit: None,
        }
    }

    pub fn file(path: impl Into<SourcePath>, mode: u32) -> Self {
        Self {
            path: path.into(),
            kind: TreeEntryKind::File,
            mode,
            link_target: None,
            submodule_commit: None,
        }
    }

    pub fn symlink(path: impl Into<SourcePath>, target: impl Into<Vec<u8>>) -> Self {
        Self {
            path: path.into(),
            kind: TreeEntryKind::Symlink,
            mode: 0o120000,
            link_target: Some(target.into()),
            submodule_commit: None,
        }
    }
}

pub trait TreeReader {
    /// Return a stable snapshot as raw source-relative paths. Adapters must not follow symlinks.
    fn entries(&self) -> Result<Vec<TreeEntry>, InventoryError>;

    /// Open a regular file from that snapshot without following a path that changed kind.
    fn open<'a>(&'a self, path: &SourcePath) -> Result<Box<dyn Read + 'a>, InventoryError>;
}
