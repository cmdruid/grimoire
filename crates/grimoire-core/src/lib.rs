//! Pure planning kernel for Grimoire's declarative package-manager domain.

mod error;
mod lockfile;
#[allow(dead_code)] // The ordered coordinator is exercised before scope-apply wiring exists.
mod locks;
mod manifest;
mod model;
mod plan;
mod resolve;
mod scope;
pub mod source;
#[allow(dead_code)] // Phase 4 will connect these verified executor primitives.
mod store;
mod trust;

pub use error::{CoreError, Result};
pub use grimoire_pack::inventory;
pub use lockfile::{LockPack, LockSkill, LockSource, Lockfile};
pub use manifest::{
    Manifest, ManifestEdit, ManifestMutation, ManifestPack, ManifestSource, SourceLocation,
};
pub use model::*;
pub use plan::{
    plan, Action, Blocker, ExitClass, LinkPrecondition, LockChange, ManifestChange,
    PackMemberState, Plan, PlanFact, Preconditions, TrustChange,
};
pub use resolve::{resolve_manifest, Resolution, ResolvedSkill};
pub use scope::{discover_project, resolve_explicit_project, PathProbe, Paths, ScopePaths};
pub use source::{
    CandidateRecord, CanonicalIdentity, ReviewKey, SnapshotKey, SourceInfo, SourceKey, SourceKind,
};
pub use store::MaterializationIntent;
pub use trust::{TrustBaseline, TrustMode, TrustMutation, TrustReceipt, TrustRecord, TrustStore};
