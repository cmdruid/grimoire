use std::string::FromUtf8Error;

pub type Result<T> = std::result::Result<T, CoreError>;

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("invalid {kind} slug `{value}`")]
    InvalidSlug { kind: &'static str, value: String },
    #[error("manifest is not UTF-8: {0}")]
    ManifestUtf8(#[from] FromUtf8Error),
    #[error("invalid manifest TOML: {0}")]
    ManifestToml(#[from] toml_edit::TomlError),
    #[error("invalid manifest: {0}")]
    Manifest(String),
    #[error("invalid lock JSON: {0}")]
    LockJson(#[from] serde_json::Error),
    #[error("unsupported lock schema `{found}`; delete the old lock and run a non-frozen install")]
    LockSchemaUnsupported { found: String },
    #[error("invalid lock: {0}")]
    Lock(String),
    #[error("invalid snapshot: {0}")]
    Snapshot(String),
    #[error("planning request is not available for this world: {0}")]
    Request(String),
    #[error("invalid source: {0}")]
    Source(String),
    #[error("source transport failure: {0}")]
    Transport(String),
    #[error("invalid trust state: {0}")]
    Trust(String),
    #[error("invalid store state: {0}")]
    Store(String),
    #[error("lock custody failure: {0}")]
    Locking(String),
    #[error("plan is stale: {0}")]
    StalePlan(String),
    #[error("blocked plan cannot be applied")]
    BlockedPlan,
    #[error("destructive plan requires explicit approval")]
    ApprovalRequired,
    #[error("invalid transaction: {0}")]
    Transaction(String),
    #[error("transaction recovery required: {0}")]
    RecoveryRequired(String),
    #[error("I/O failure at {path}: {message}")]
    Io { path: String, message: String },
}
