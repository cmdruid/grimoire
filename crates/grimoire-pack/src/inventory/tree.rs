use std::collections::BTreeMap;
use std::io::Read;

use super::unicode17::to_nfkc_casefold;
use super::{Finding, InventoryError, Severity, SourcePath};

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
    pub size: Option<u64>,
    pub link_target: Option<Vec<u8>>,
    pub submodule_commit: Option<String>,
}

impl TreeEntry {
    pub fn directory(path: impl Into<SourcePath>) -> Self {
        Self {
            path: path.into(),
            kind: TreeEntryKind::Directory,
            mode: 0o040755,
            size: None,
            link_target: None,
            submodule_commit: None,
        }
    }

    pub fn file(path: impl Into<SourcePath>, mode: u32) -> Self {
        Self {
            path: path.into(),
            kind: TreeEntryKind::File,
            mode,
            size: None,
            link_target: None,
            submodule_commit: None,
        }
    }

    pub fn symlink(path: impl Into<SourcePath>, target: impl Into<Vec<u8>>) -> Self {
        Self {
            path: path.into(),
            kind: TreeEntryKind::Symlink,
            mode: 0o120000,
            size: None,
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

pub(crate) struct EntryValidator {
    collision_paths: BTreeMap<Vec<Vec<u8>>, SourcePath>,
}

impl EntryValidator {
    pub(crate) fn new() -> Self {
        Self {
            collision_paths: BTreeMap::new(),
        }
    }

    pub(crate) fn validate(&mut self, entry: &TreeEntry) -> Vec<Finding> {
        let mut findings = Vec::new();
        let bytes = entry.path.as_bytes();
        let unsafe_reason = if bytes.starts_with(b"/") {
            Some("absolute")
        } else if bytes.contains(&0) {
            Some("nul")
        } else if bytes
            .split(|byte| *byte == b'/')
            .any(|component| component.is_empty() || matches!(component, b"." | b".."))
        {
            Some("parent")
        } else {
            None
        };
        if let Some(reason) = unsafe_reason {
            findings.push(finding(
                "unsafe-path",
                entry.path.clone(),
                [("reason", reason)],
            ));
        }

        match std::str::from_utf8(bytes) {
            Ok(path) if unsafe_reason.is_none() => {
                let key: Vec<_> = path
                    .split('/')
                    .map(|component| to_nfkc_casefold(component).into_bytes())
                    .collect();
                if let Some(first) = self.collision_paths.get(&key) {
                    if first != &entry.path {
                        let other = first.to_string();
                        findings.push(finding(
                            "case-collision",
                            entry.path.clone(),
                            [("other_path", other.as_str())],
                        ));
                    }
                } else {
                    self.collision_paths.insert(key, entry.path.clone());
                }
            }
            Err(_) => findings.push(finding(
                "invalid-path-utf8",
                entry.path.clone(),
                std::iter::empty::<(&str, &str)>(),
            )),
            Ok(_) => {}
        }

        let kind = match entry.kind {
            TreeEntryKind::Device => Some("device"),
            TreeEntryKind::Fifo => Some("fifo"),
            TreeEntryKind::Socket => Some("socket"),
            _ => None,
        };
        if let Some(kind) = kind {
            findings.push(finding(
                "unsupported-entry",
                entry.path.clone(),
                [("kind", kind)],
            ));
        }
        findings
    }
}

fn finding<'a>(
    code: &str,
    path: SourcePath,
    details: impl IntoIterator<Item = (&'a str, &'a str)>,
) -> Finding {
    Finding {
        code: code.into(),
        path: Some(path),
        severity: Severity::Error,
        details: details
            .into_iter()
            .map(|(key, value)| (key.into(), value.into()))
            .collect(),
        message: code.replace('-', " "),
    }
}
