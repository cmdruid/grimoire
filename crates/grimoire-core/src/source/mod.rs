mod candidate;
mod diff;
mod git;
pub(crate) mod identity;
mod info;
mod local;
mod query;
mod review;
mod workflow;

pub use candidate::CandidateRecord;
pub use diff::{DiffChange, FactChange, SourceDiff};
pub use git::{
    fetch_remote, GitCommand, GitResult, GitRunner, GitSnapshot, GitTreeReader, CONTROL_LIMIT,
    PRIVATE_REF,
};
pub use identity::{
    validate_ref, CanonicalIdentity, ReviewKey, SnapshotKey, SourceKey, SourceKind,
};
pub use info::SourceInfo;
pub use local::{inspect_pinned_git, HeldDirectoryReader};
pub use query::{
    load_trust_world, refresh_source, source_diff, source_info, source_key_for_alias,
    source_summaries, trust_catalog, SourceSummary, TrustCatalog, TrustSummary, TrustUse,
};
pub use review::{ReviewEntry, ReviewExport, ReviewFacts, ReviewPayload};
pub use workflow::{
    fetch_source, inspect_live_source, inspect_pinned_source, prepare_source_add,
    CandidateWorkflow, PreparedSource,
};
