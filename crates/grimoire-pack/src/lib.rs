//! Reference library for the pack format, revision 1
//! (`docs/spec/pack-format.md`): `PACK.md` manifests, `grimoire.lock`,
//! member content hashing (Appendix A), and discovery (Appendix B).

use std::path::PathBuf;

pub mod frontmatter;

#[derive(Debug, thiserror::Error)]
pub enum PackError {
    #[error("io error at {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("invalid frontmatter: {0}")]
    Frontmatter(String),
    #[error("invalid manifest: {0}")]
    Manifest(String),
    #[error("unsupported pack format {0} (this library implements format 1)")]
    UnsupportedFormat(u64),
    #[error("invalid pack shape: {0}")]
    Shape(String),
    #[error("lock is read-only: {0}")]
    LockReadOnly(String),
    #[error("invalid lock: {0}")]
    Lock(String),
}

pub type Result<T> = std::result::Result<T, PackError>;
