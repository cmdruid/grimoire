//! Pure planning kernel for Grimoire's declarative package-manager domain.

mod error;
mod lockfile;
mod manifest;
mod model;
mod plan;
mod resolve;
mod scope;

pub use error::{CoreError, Result};
pub use grimoire_pack::inventory;
pub use lockfile::{LockPack, LockSkill, LockSource, Lockfile};
pub use manifest::{
    Manifest, ManifestEdit, ManifestMutation, ManifestPack, ManifestSource, SourceLocation,
};
pub use model::*;
pub use plan::{plan, Action, Blocker, ExitClass, LinkPrecondition, Plan, PlanFact, Preconditions};
pub use scope::{discover_project, resolve_explicit_project, PathProbe, Paths, ScopePaths};
