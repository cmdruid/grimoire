//! grimoire operations: the library model, install scopes and agents, pack
//! install/remove/check, and the tiny config — everything the TUI needs and
//! nothing about rendering.
//!
//! The crate's contract, which its tests enforce:
//!
//! - **Synchronous.** `grimoire-pack` is blocking `std::fs`; keeping long
//!   operations off a render thread is the frontend's job, not an async
//!   colouring of every signature here.
//! - **Clockless and homeless.** No operation calls `now()` or reads the
//!   process environment: `home`, the agent env overrides, and `installed_at`
//!   arrive as parameters ([`agents::AgentEnv::from_process`] is the one
//!   clearly-marked exception, for a binary's convenience).
//! - **No UI, no `tokio`, no `skill`** anywhere in the dependency tree.
//! - **Symlink semantics match `install.sh`** — the library clone stays
//!   canonical and edits in it are live through every install.

use std::path::{Path, PathBuf};

pub mod agents;
pub mod check;
pub mod config;
pub mod install;
pub mod inventory;
pub mod library;
pub mod remove;
pub mod target;
pub mod time;

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("io error at {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("pack error: {0}")]
    Pack(#[from] grimoire_pack::PackError),
    #[error("no pack named {0} in this library")]
    UnknownPack(String),
    #[error("no skill named {0} in this library")]
    UnknownSkill(String),
    #[error("pack {pack} member {member} does not resolve in this library")]
    UnresolvedMember { pack: String, member: String },
    #[error("no pack named {0} is installed here")]
    NotInstalled(String),
    #[error("preflight failed: {0} blocking finding(s)")]
    Preflight(usize),
    /// Spec §3: a lock declaring a newer version, or one we cannot parse, is
    /// read-only — surface the fact and refuse the rewrite.
    #[error("lock is read-only: {0}")]
    LockReadOnly(String),
    #[error("malformed timestamp {0:?} (want RFC3339 UTC, e.g. 2026-08-18T12:00:00Z)")]
    Timestamp(String),
    #[error("malformed config at {path}: {reason}")]
    Config { path: PathBuf, reason: String },
}

pub type Result<T> = std::result::Result<T, CoreError>;

/// Attach a path to an [`std::io::Error`] — the crate reports *where* every
/// failure happened, because a bare "permission denied" is unactionable.
pub(crate) fn io_err(path: &Path, source: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.to_path_buf(),
        source,
    }
}
