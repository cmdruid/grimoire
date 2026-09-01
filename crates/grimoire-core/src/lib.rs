//! Pure planning kernel for Grimoire's declarative package-manager domain.

mod error;
mod lockfile;
mod manifest;
mod model;
mod plan;
mod resolve;

pub use error::{CoreError, Result};
pub use grimoire_pack::inventory;
pub use lockfile::{LockPack, LockSkill, LockSource, Lockfile};
pub use manifest::{Manifest, ManifestPack, ManifestSource, SourceLocation};
pub use model::*;
pub use plan::{plan, Action, Blocker, ExitClass, LinkPrecondition, Plan, PlanFact, Preconditions};
