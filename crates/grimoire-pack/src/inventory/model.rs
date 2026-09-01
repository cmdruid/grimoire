use std::collections::BTreeMap;
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct SourcePath(Vec<u8>);

impl SourcePath {
    pub fn new(bytes: impl Into<Vec<u8>>) -> Self {
        Self(bytes.into())
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }

    pub fn join(&self, child: &[u8]) -> Self {
        let mut bytes = self.0.clone();
        if !bytes.is_empty() {
            bytes.push(b'/');
        }
        bytes.extend_from_slice(child);
        Self(bytes)
    }

    pub fn strip_prefix(&self, root: &Self) -> Option<Self> {
        if self == root {
            return Some(Self::new(Vec::new()));
        }
        let rest = self.0.strip_prefix(root.as_bytes())?.strip_prefix(b"/")?;
        Some(Self::new(rest))
    }

    pub fn parent(&self) -> Option<Self> {
        let end = self.0.iter().rposition(|byte| *byte == b'/')?;
        Some(Self::new(self.0[..end].to_vec()))
    }

    pub fn file_name(&self) -> &[u8] {
        self.0
            .rsplit(|byte| *byte == b'/')
            .next()
            .unwrap_or_default()
    }

    pub fn is_descendant_of(&self, root: &Self) -> bool {
        self.strip_prefix(root)
            .is_some_and(|path| !path.0.is_empty())
    }
}

impl From<&str> for SourcePath {
    fn from(value: &str) -> Self {
        Self::new(value.as_bytes().to_vec())
    }
}

impl fmt::Display for SourcePath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", String::from_utf8_lossy(&self.0))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Digest(pub(crate) [u8; 32]);

impl Digest {
    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl fmt::Display for Digest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("sha256:")?;
        for byte in self.0 {
            write!(f, "{byte:02x}")?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Severity {
    Error,
    Warning,
}

impl Severity {
    pub(crate) fn as_bytes(self) -> &'static [u8] {
        match self {
            Self::Error => b"error",
            Self::Warning => b"warning",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    pub code: String,
    pub path: Option<SourcePath>,
    pub severity: Severity,
    pub details: BTreeMap<String, String>,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileFact {
    pub path: SourcePath,
    pub size: u64,
    pub mode: String,
    pub digest: Digest,
    pub binary: bool,
    pub executable: bool,
    pub shebang: Option<Vec<u8>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum SymlinkSafety {
    Internal,
    Escaping,
    Invalid,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SymlinkFact {
    pub path: SourcePath,
    pub target: Vec<u8>,
    pub mode: String,
    pub safety: SymlinkSafety,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SubmoduleFact {
    pub path: SourcePath,
    pub commit: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Boundary {
    Snapshot,
    Skill(SourcePath),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReviewedPayload {
    File { size: u64, digest: Digest },
    Symlink { target: Vec<u8> },
    Submodule { commit: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReviewedEntry {
    pub path: SourcePath,
    pub mode: String,
    pub payload: ReviewedPayload,
    pub boundary: Boundary,
    pub safety: Option<SymlinkSafety>,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Skill {
    pub name: String,
    pub path: SourcePath,
    pub content_digest: Digest,
    pub files: Vec<FileFact>,
    pub symlinks: Vec<SymlinkFact>,
    pub submodules: Vec<SubmoduleFact>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Pack {
    pub name: String,
    pub path: SourcePath,
    pub digest: Digest,
    pub description: String,
    pub required: Vec<String>,
    pub optional: Vec<String>,
    pub missing_required: Vec<String>,
    pub missing_optional: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceInventory {
    pub skills: Vec<Skill>,
    pub packs: Vec<Pack>,
    pub findings: Vec<Finding>,
    pub reviewed_entries: Vec<ReviewedEntry>,
    pub inventory_digest: Digest,
    pub review_tree_digest: Digest,
}

#[derive(Debug, thiserror::Error)]
pub enum InventoryError {
    #[error("tree I/O at {path}: {message}")]
    Tree { path: SourcePath, message: String },
}
