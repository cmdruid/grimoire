use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use grimoire_pack::inventory::SourceInventory;
use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};

use crate::{CoreError, Result};

fn valid_slug(value: &str) -> bool {
    !value.is_empty()
        && value.bytes().enumerate().all(|(index, byte)| match byte {
            b'a'..=b'z' | b'0'..=b'9' => true,
            b'-' => index > 0 && !value.as_bytes()[index - 1].eq(&b'-'),
            _ => false,
        })
        && !value.ends_with('-')
}

macro_rules! slug_type {
    ($name:ident, $kind:literal) => {
        #[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(String);

        impl $name {
            pub fn new(value: impl Into<String>) -> Result<Self> {
                let value = value.into();
                if valid_slug(&value) {
                    Ok(Self(value))
                } else {
                    Err(CoreError::InvalidSlug { kind: $kind, value })
                }
            }

            pub fn as_str(&self) -> &str {
                &self.0
            }
        }

        impl TryFrom<&str> for $name {
            type Error = CoreError;

            fn try_from(value: &str) -> Result<Self> {
                Self::new(value)
            }
        }

        impl std::fmt::Display for $name {
            fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                formatter.write_str(&self.0)
            }
        }
    };
}

slug_type!(SourceAlias, "source alias");
slug_type!(SkillName, "skill name");
slug_type!(PackName, "pack name");

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Scope {
    Project,
    Global,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProjectionMode {
    Link,
    Vendor,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SnapshotKind {
    Git,
    Live,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct SnapshotId {
    pub kind: SnapshotKind,
    pub commit: Option<String>,
    pub tree: Option<String>,
    pub inventory_digest: String,
}

impl SnapshotId {
    pub fn new(
        kind: SnapshotKind,
        commit: Option<String>,
        tree: Option<String>,
        inventory_digest: String,
    ) -> Result<Self> {
        let valid_object = |value: &str| {
            matches!(value.len(), 40 | 64) && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        };
        match kind {
            SnapshotKind::Git => {
                if !commit.as_deref().is_some_and(valid_object)
                    || !tree.as_deref().is_some_and(valid_object)
                {
                    return Err(CoreError::Snapshot(
                        "Git snapshots require full hexadecimal commit and tree IDs".into(),
                    ));
                }
            }
            SnapshotKind::Live if commit.is_some() || tree.is_some() => {
                return Err(CoreError::Snapshot(
                    "live snapshots cannot carry commit or tree IDs".into(),
                ));
            }
            SnapshotKind::Live => {}
        }
        if !inventory_digest.starts_with("sha256:") {
            return Err(CoreError::Snapshot(
                "inventory digest must use the sha256: prefix".into(),
            ));
        }
        Ok(Self {
            kind,
            commit,
            tree,
            inventory_digest,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "kind", content = "name", rename_all = "snake_case")]
pub enum RequestRoot {
    Skill(SkillName),
    Pack(PackName),
}

impl RequestRoot {
    pub fn lock_value(&self) -> String {
        match self {
            Self::Skill(name) => format!("skill:{name}"),
            Self::Pack(name) => format!("pack:{name}"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceSnapshot {
    pub alias: SourceAlias,
    pub id: SnapshotId,
    pub root: PathBuf,
    pub inventory: SourceInventory,
}

impl SourceSnapshot {
    pub fn new(
        alias: SourceAlias,
        id: SnapshotId,
        root: PathBuf,
        inventory: SourceInventory,
    ) -> Self {
        Self {
            alias,
            id,
            root,
            inventory,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SnapshotStore {
    Absent,
    Valid,
    Corrupt,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceState {
    pub snapshot: SourceSnapshot,
    pub store: SnapshotStore,
    pub materializable: bool,
    pub candidate_bytes: Option<Vec<u8>>,
    pub candidate_current: bool,
    pub identity: Option<crate::CanonicalIdentity>,
    pub review_tree: Option<String>,
}

impl SourceState {
    pub fn new(snapshot: SourceSnapshot, store: SnapshotStore, materializable: bool) -> Self {
        Self {
            snapshot,
            store,
            materializable,
            candidate_bytes: None,
            candidate_current: true,
            identity: None,
            review_tree: None,
        }
    }

    pub fn candidate(mut self, bytes: Vec<u8>) -> Self {
        self.candidate_bytes = Some(bytes);
        self
    }

    pub fn stale_candidate(mut self) -> Self {
        self.candidate_current = false;
        self
    }

    pub fn source_identity(
        mut self,
        identity: crate::CanonicalIdentity,
        review_tree: String,
    ) -> Self {
        self.identity = Some(identity);
        self.review_tree = Some(review_tree);
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "target", rename_all = "snake_case")]
pub enum InstalledLink {
    Absent,
    Symlink(PathBuf),
    File,
    Directory,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VendorState {
    Absent,
    OwnedUnchanged,
    Drifted,
    Foreign,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VendorPrecondition {
    pub state: VendorState,
    pub content: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum OwnedLinkTarget {
    Stored {
        source_key: crate::SourceKey,
        snapshot_key: crate::SnapshotKey,
        skill_path: String,
    },
    Live {
        identity: crate::CanonicalIdentity,
        skill_path: String,
    },
    Vendor {
        source: SourceAlias,
        skill: SkillName,
    },
}

impl OwnedLinkTarget {
    pub fn resolve(&self, paths: &crate::Paths) -> Result<PathBuf> {
        let (root, skill_path) = match self {
            Self::Stored {
                source_key,
                snapshot_key,
                skill_path,
            } => (paths.store_path(source_key, snapshot_key), skill_path),
            Self::Live {
                identity,
                skill_path,
            } => {
                if identity.kind() != crate::SourceKind::Live {
                    return Err(CoreError::Request(
                        "live link target requires a live source identity".into(),
                    ));
                }
                #[cfg(unix)]
                {
                    use std::os::unix::ffi::OsStrExt;
                    (
                        PathBuf::from(std::ffi::OsStr::from_bytes(identity.canonical_bytes())),
                        skill_path,
                    )
                }
                #[cfg(not(unix))]
                unreachable!("Grimoire supports Unix hosts")
            }
            Self::Vendor { source, skill } => {
                return paths.vendor_activation_target(source, skill);
            }
        };
        validate_skill_path(skill_path)?;
        Ok(root.join(skill_path))
    }
}

fn validate_skill_path(value: &str) -> Result<()> {
    let path = Path::new(value);
    if value.is_empty()
        || path.is_absolute()
        || path
            .components()
            .any(|component| !matches!(component, std::path::Component::Normal(_)))
    {
        return Err(CoreError::Request(format!(
            "owned skill path is not a normalized relative path: {value}"
        )));
    }
    Ok(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Approval {
    NotRequired,
    Granted,
    Declined,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FaultDisposition {
    Continue,
    Crash,
}

pub trait TransactionRuntime {
    fn transaction_nonce(&self) -> Result<String>;
    fn unix_time(&self) -> Result<i64>;
    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition>;
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum ApplyOutcome {
    Applied { changed: bool },
    Cancelled,
    Interrupted { checkpoint: String },
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "disposition", rename_all = "snake_case")]
pub enum RecoveryDisposition {
    RolledBack { scope_key: String },
    RolledForward { scope_key: String },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecoveryOutcome {
    pub dispositions: Vec<RecoveryDisposition>,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct WorldObservation {
    pub code: String,
    pub details: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CheckSeverity {
    Error,
    Warning,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct CheckFinding {
    pub code: String,
    pub severity: CheckSeverity,
    pub details: BTreeMap<String, String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CheckReport {
    pub findings: Vec<CheckFinding>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InstalledStatus {
    Current,
    Missing,
    Drift,
    ForeignFile,
    ForeignDirectory,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct DesiredRootSummary {
    pub root: RequestRoot,
    pub source: SourceAlias,
    pub mode: ProjectionMode,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResolvedSkillSummary {
    pub name: SkillName,
    pub source: SourceAlias,
    pub mode: ProjectionMode,
    pub snapshot: Option<String>,
    pub vendor_path: Option<String>,
    pub inventory: Option<String>,
    pub requested_by: BTreeSet<RequestRoot>,
    pub installed: InstalledStatus,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct UnavailableMemberSummary {
    pub pack: PackName,
    pub skill: SkillName,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct InheritedSkillSummary {
    pub name: SkillName,
    pub source: SourceAlias,
    pub shadowed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextReport {
    pub desired_roots: Vec<DesiredRootSummary>,
    pub skills: Vec<ResolvedSkillSummary>,
    pub unavailable: Vec<UnavailableMemberSummary>,
    pub inherited: Vec<InheritedSkillSummary>,
    pub blockers: Vec<crate::Blocker>,
    pub findings: Vec<CheckFinding>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ByteHash(String);

impl ByteHash {
    pub fn of(bytes: &[u8]) -> Self {
        Self(format!("{:x}", Sha256::digest(bytes)))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn parse(value: impl Into<String>) -> Result<Self> {
        let value = value.into();
        if value.len() == 64
            && value
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
        {
            Ok(Self(value))
        } else {
            Err(CoreError::Request("invalid byte hash".into()))
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct ProjectReference {
    pub source_key: crate::SourceKey,
    pub snapshot_key: crate::SnapshotKey,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectRecord {
    pub path: PathBuf,
    pub scope_key: String,
    pub lock_hash: ByteHash,
    pub references: BTreeSet<ProjectReference>,
    pub last_observed: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct ProjectIndex {
    pub records: BTreeMap<String, ProjectRecord>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReachabilityObservation {
    pub generation: ByteHash,
    pub snapshots: BTreeSet<ProjectReference>,
    pub reachable: BTreeSet<ProjectReference>,
    pub findings: Vec<WorldObservation>,
    pub retain_all: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PlanningMode {
    Normal,
    Frozen,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceTrustIntent {
    Untrusted,
    Exact,
    All,
    Vendor,
}

/// The complete desired roots staged by an adapter before one atomic replan.
///
/// It deliberately excludes source declarations: source custody has its own
/// review and fetch ceremonies and cannot be changed by a tree toggle.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesiredState {
    pub skills: BTreeMap<SkillName, crate::ManifestSkill>,
    pub packs: BTreeMap<PackName, crate::ManifestPack>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DesiredEdit {
    SetSkill {
        name: SkillName,
        source: SourceAlias,
        enabled: bool,
    },
    SetPack {
        name: PackName,
        source: SourceAlias,
        enabled: bool,
    },
    SetPackOptional {
        pack: PackName,
        skill: SkillName,
        enabled: bool,
    },
    SetSkillMode {
        name: SkillName,
        mode: ProjectionMode,
    },
    SetPackMode {
        name: PackName,
        mode: ProjectionMode,
    },
}

impl DesiredState {
    pub fn from_world(world: &WorldState) -> Self {
        Self {
            skills: world.manifest.skills.clone(),
            packs: world.manifest.packs.clone(),
        }
    }

    pub fn apply(&mut self, edit: DesiredEdit) -> Result<()> {
        match edit {
            DesiredEdit::SetSkill {
                name,
                source,
                enabled,
            } => {
                if enabled {
                    if let Some(current) = self.skills.get(&name) {
                        if current.source != source {
                            return Err(CoreError::Request(format!(
                                "skill `{name}` is already staged from source `{}`",
                                current.source
                            )));
                        }
                    }
                    self.skills.entry(name).or_insert(crate::ManifestSkill {
                        source,
                        mode: ProjectionMode::Link,
                    });
                } else if self
                    .skills
                    .get(&name)
                    .is_some_and(|request| request.source == source)
                {
                    self.skills.remove(&name);
                }
            }
            DesiredEdit::SetPack {
                name,
                source,
                enabled,
            } => {
                if enabled {
                    if let Some(current) = self.packs.get(&name) {
                        if current.source != source {
                            return Err(CoreError::Request(format!(
                                "pack `{name}` is already staged from source `{}`",
                                current.source
                            )));
                        }
                    }
                    self.packs.entry(name).or_insert(crate::ManifestPack {
                        source,
                        mode: ProjectionMode::Link,
                        exclude: BTreeSet::new(),
                    });
                } else if self
                    .packs
                    .get(&name)
                    .is_some_and(|pack| pack.source == source)
                {
                    self.packs.remove(&name);
                }
            }
            DesiredEdit::SetPackOptional {
                pack,
                skill,
                enabled,
            } => {
                let request = self
                    .packs
                    .get_mut(&pack)
                    .ok_or_else(|| CoreError::Request(format!("pack `{pack}` is not staged")))?;
                if enabled {
                    request.exclude.remove(&skill);
                } else {
                    request.exclude.insert(skill);
                }
            }
            DesiredEdit::SetSkillMode { name, mode } => {
                let request = self
                    .skills
                    .get_mut(&name)
                    .ok_or_else(|| CoreError::Request(format!("skill `{name}` is not staged")))?;
                request.mode = mode;
            }
            DesiredEdit::SetPackMode { name, mode } => {
                let request = self
                    .packs
                    .get_mut(&name)
                    .ok_or_else(|| CoreError::Request(format!("pack `{name}` is not staged")))?;
                request.mode = mode;
            }
        }
        Ok(())
    }

    pub fn into_request(self) -> Request {
        Request::ReplaceDesiredState { desired: self }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Request {
    Initialize,
    Reconcile,
    AddSource {
        prepared: Box<crate::PreparedSource>,
        trust: SourceTrustIntent,
    },
    RemoveSource {
        alias: SourceAlias,
    },
    InstallSkill {
        name: SkillName,
        request: crate::ManifestSkill,
    },
    UninstallSkill {
        name: SkillName,
    },
    InstallPack {
        name: PackName,
        request: crate::ManifestPack,
    },
    UninstallPack {
        name: PackName,
    },
    ReplacePackExclusions {
        name: PackName,
        exclude: BTreeSet<SkillName>,
    },
    ReplaceDesiredState {
        desired: DesiredState,
    },
    UpdateSource {
        alias: SourceAlias,
    },
    UpdateAll,
    TrustSource {
        alias: SourceAlias,
        mode: SourceTrustIntent,
    },
    RevokeTrust {
        source: crate::SourceKey,
    },
    Prune,
}

#[derive(Debug, Clone)]
pub struct WorldState {
    pub scope: Scope,
    pub manifest_bytes: Vec<u8>,
    pub manifest: crate::Manifest,
    pub lock_bytes: Vec<u8>,
    pub lock: crate::Lockfile,
    pub snapshots: BTreeMap<SourceAlias, SourceSnapshot>,
    pub source_states: BTreeMap<SourceAlias, SourceState>,
    pub locked_states: BTreeMap<SourceAlias, SourceState>,
    pub candidates: BTreeMap<SourceAlias, SourceState>,
    pub trust_bytes: Option<Vec<u8>>,
    pub links: BTreeMap<SkillName, InstalledLink>,
    pub vendors: BTreeMap<SkillName, VendorPrecondition>,
    pub inherited_global: Option<crate::resolve::Resolution>,
    pub manifest_present: bool,
    pub lock_present: bool,
    pub observations: Vec<WorldObservation>,
    pub project_index_bytes: Option<Vec<u8>>,
    pub reachability: Option<ReachabilityObservation>,
}

impl WorldState {
    pub fn from_bytes<'a>(
        scope: Scope,
        manifest_bytes: Vec<u8>,
        lock_bytes: Vec<u8>,
        sources: impl IntoIterator<Item = SourceState>,
        links: impl IntoIterator<Item = (&'a str, InstalledLink)>,
        inherited_global: Option<crate::resolve::Resolution>,
    ) -> Result<Self> {
        let manifest = crate::Manifest::parse(manifest_bytes.clone())?;
        let lock = crate::Lockfile::parse(&lock_bytes)?;
        let source_states: BTreeMap<_, _> = sources
            .into_iter()
            .map(|state| (state.snapshot.alias.clone(), state))
            .collect();
        let snapshots = source_states
            .iter()
            .map(|(alias, state)| (alias.clone(), state.snapshot.clone()))
            .collect();
        let links = links
            .into_iter()
            .map(|(name, link)| Ok((SkillName::new(name)?, link)))
            .collect::<Result<_>>()?;
        Ok(Self {
            scope,
            manifest_bytes,
            manifest,
            lock_bytes,
            lock,
            snapshots,
            source_states,
            locked_states: BTreeMap::new(),
            candidates: BTreeMap::new(),
            trust_bytes: None,
            links,
            vendors: BTreeMap::new(),
            inherited_global,
            manifest_present: true,
            lock_present: true,
            observations: Vec::new(),
            project_index_bytes: None,
            reachability: None,
        })
    }

    pub fn absent<'a>(
        scope: Scope,
        sources: impl IntoIterator<Item = SourceState>,
        links: impl IntoIterator<Item = (&'a str, InstalledLink)>,
        inherited_global: Option<crate::resolve::Resolution>,
    ) -> Result<Self> {
        let mut world = Self::from_bytes(
            scope,
            b"schema = \"grimoire/manifest@2\"\n".to_vec(),
            crate::Lockfile::default().to_bytes()?,
            sources,
            links,
            inherited_global,
        )?;
        world.manifest_present = false;
        world.lock_present = false;
        Ok(world)
    }

    pub fn with_candidate(mut self, candidate: SourceState) -> Result<Self> {
        if candidate.candidate_bytes.is_none() {
            return Err(CoreError::Request(
                "candidate observation requires exact candidate bytes".into(),
            ));
        }
        self.candidates
            .insert(candidate.snapshot.alias.clone(), candidate);
        Ok(self)
    }

    pub fn with_locked_snapshot(mut self, state: SourceState) -> Self {
        self.locked_states
            .insert(state.snapshot.alias.clone(), state);
        self
    }

    pub fn with_trust_bytes(mut self, bytes: Option<Vec<u8>>) -> Self {
        self.trust_bytes = bytes;
        self
    }

    pub fn with_project_index_bytes(mut self, bytes: Option<Vec<u8>>) -> Self {
        self.project_index_bytes = bytes;
        self
    }

    pub fn with_reachability(mut self, observation: ReachabilityObservation) -> Self {
        self.reachability = Some(observation);
        self
    }
}
