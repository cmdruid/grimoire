//! Pure planning kernel for Grimoire's declarative package-manager domain.

mod apply;
mod check;
mod error;
mod lockfile;
mod locks;
mod manifest;
mod model;
mod plan;
mod projects;
mod prune;
mod resolve;
mod scope;
pub mod source;
mod store;
mod transaction;
mod tree;
mod trust;
mod world;

pub use apply::{apply, recover};
pub use check::{check, context_report};
pub use error::{CoreError, Result};
pub use grimoire_pack::inventory;
pub use lockfile::{LockPack, LockSkill, LockSource, Lockfile};
pub use manifest::{
    Manifest, ManifestEdit, ManifestMutation, ManifestPack, ManifestSource, SourceLocation,
};
pub use model::*;
pub use plan::{
    plan, Action, Blocker, ExitClass, LinkPrecondition, LockChange, ManifestChange,
    PackMemberState, Plan, PlanFact, Preconditions, SnapshotPreparation, StorePrecondition,
    TrustChange,
};
pub use prune::observe_reachability;
pub use resolve::{resolve_manifest, Resolution, ResolvedSkill};
pub use scope::{discover_project, resolve_explicit_project, PathProbe, Paths, ScopePaths};
pub use source::{
    load_trust_world, prepare_source_add, refresh_source, source_diff, source_info,
    source_key_for_alias, source_summaries, trust_catalog, CandidateRecord, CanonicalIdentity,
    PreparedSource, ReviewKey, SnapshotKey, SourceDiff, SourceInfo, SourceKey, SourceKind,
    SourceSummary, TrustCatalog, TrustSummary, TrustUse,
};
pub use store::MaterializationIntent;
pub use tree::{project_tree, TreeItem, TreeItemKey, TreeProjection};
pub use trust::{TrustBaseline, TrustMode, TrustMutation, TrustReceipt, TrustRecord, TrustStore};
pub use world::{attach_inherited_global, load_world};
