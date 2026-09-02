mod candidate;
mod diff;
mod git;
pub(crate) mod identity;
mod info;
mod local;
mod review;
mod workflow;

pub use candidate::CandidateRecord;
pub use diff::{DiffChange, SourceDiff};
pub use git::{
    fetch_remote, GitCommand, GitResult, GitRunner, GitSnapshot, GitTreeReader, CONTROL_LIMIT,
    PRIVATE_REF,
};
pub use identity::{
    validate_ref, CanonicalIdentity, ReviewKey, SnapshotKey, SourceKey, SourceKind,
};
pub use info::SourceInfo;
pub use local::{inspect_pinned_git, HeldDirectoryReader};
pub use review::{ReviewEntry, ReviewExport, ReviewPayload};
pub use workflow::{fetch_source, inspect_live_source, inspect_pinned_source, CandidateWorkflow};
