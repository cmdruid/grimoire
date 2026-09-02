//! Pure planning kernel for Grimoire's declarative package-manager domain.

mod apply;
mod error;
mod lockfile;
mod locks;
mod manifest;
mod model;
mod plan;
mod resolve;
mod scope;
pub mod source;
mod store;
mod transaction;
mod trust;

pub use apply::apply;
pub use error::{CoreError, Result};
pub use grimoire_pack::inventory;
pub use lockfile::{LockPack, LockSkill, LockSource, Lockfile};
pub use manifest::{
    Manifest, ManifestEdit, ManifestMutation, ManifestPack, ManifestSource, SourceLocation,
};
pub use model::*;
pub use plan::{
    plan, Action, Blocker, ExitClass, LinkPrecondition, LockChange, ManifestChange,
    PackMemberState, Plan, PlanFact, Preconditions, SnapshotPreparation, TrustChange,
};
pub use resolve::{resolve_manifest, Resolution, ResolvedSkill};
pub use scope::{discover_project, resolve_explicit_project, PathProbe, Paths, ScopePaths};
pub use source::{
    prepare_source_add, CandidateRecord, CanonicalIdentity, PreparedSource, ReviewKey, SnapshotKey,
    SourceInfo, SourceKey, SourceKind,
};
pub use store::MaterializationIntent;
pub use trust::{TrustBaseline, TrustMode, TrustMutation, TrustReceipt, TrustRecord, TrustStore};
