use std::collections::BTreeMap;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::resolve::resolve_manifest;
use crate::{
    ByteHash, CoreError, InstalledLink, LockSource, Lockfile, ManifestMutation, OwnedLinkTarget,
    PlanningMode, Request, RequestRoot, Result, Scope, SkillName, SnapshotKind, SnapshotStore,
    SourceAlias, SourceTrustIntent, TrustMode, WorldState,
};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct Blocker {
    pub code: String,
    pub details: BTreeMap<String, String>,
}

impl Blocker {
    pub fn new<const N: usize>(code: &str, details: [(&str, String); N]) -> Self {
        Self {
            code: code.into(),
            details: details
                .into_iter()
                .map(|(key, value)| (key.into(), value))
                .collect(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ManifestChange {
    AddSource,
    RemoveSource,
    InstallSkill,
    UninstallSkill,
    InstallPack,
    UninstallPack,
    ReplacePackExclusions { removes_desired: bool },
}

impl ManifestChange {
    fn is_destructive(self) -> bool {
        matches!(
            self,
            Self::RemoveSource
                | Self::UninstallSkill
                | Self::UninstallPack
                | Self::ReplacePackExclusions {
                    removes_desired: true
                }
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LockChange {
    Resolve,
    SourceAdvance,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrustChange {
    GrantExact,
    GrantAll,
    Revoke,
    AdvanceBaseline,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SnapshotPreparation {
    Materialize,
    Repair,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Action {
    ReplaceTrust {
        before: Option<Vec<u8>>,
        after: Vec<u8>,
        create_mode: u32,
        change: TrustChange,
    },
    ReplaceCandidate {
        scope: Scope,
        alias: SourceAlias,
        source_key: crate::SourceKey,
        before: Option<Vec<u8>>,
        after: Vec<u8>,
    },
    RemoveCandidate {
        scope: Scope,
        alias: SourceAlias,
        source_key: crate::SourceKey,
        before: Vec<u8>,
    },
    PrepareSnapshot {
        scope: Scope,
        source: SourceAlias,
        source_key: String,
        snapshot_key: String,
        review_key: String,
        operation: SnapshotPreparation,
    },
    CreateManifest {
        scope: Scope,
        after: Vec<u8>,
    },
    ReplaceManifest {
        scope: Scope,
        before: Vec<u8>,
        after: Vec<u8>,
        change: ManifestChange,
    },
    CreateLock {
        scope: Scope,
        after: Vec<u8>,
    },
    ReplaceLock {
        scope: Scope,
        before: Vec<u8>,
        after: Vec<u8>,
        change: LockChange,
    },
    CreateLink {
        scope: Scope,
        skill: SkillName,
        target: OwnedLinkTarget,
    },
    RetainLink {
        scope: Scope,
        skill: SkillName,
        target: OwnedLinkTarget,
    },
    RepointLink {
        scope: Scope,
        skill: SkillName,
        before: OwnedLinkTarget,
        after: OwnedLinkTarget,
    },
    RemoveLink {
        scope: Scope,
        skill: SkillName,
        target: OwnedLinkTarget,
    },
    PruneSnapshot {
        source_key: crate::SourceKey,
        snapshot_key: crate::SnapshotKey,
    },
}

impl Action {
    fn is_mutating(&self) -> bool {
        !matches!(self, Self::RetainLink { .. })
    }

    fn is_destructive(&self) -> bool {
        match self {
            Self::ReplaceManifest { change, .. } => change.is_destructive(),
            Self::ReplaceTrust {
                change: TrustChange::Revoke,
                ..
            } => true,
            Self::ReplaceLock {
                change: LockChange::SourceAdvance,
                ..
            }
            | Self::RepointLink { .. }
            | Self::RemoveLink { .. }
            | Self::PruneSnapshot { .. } => true,
            _ => false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "target", rename_all = "snake_case")]
pub enum LinkPrecondition {
    Absent,
    Symlink(PathBuf),
    File,
    Directory,
}

impl From<&InstalledLink> for LinkPrecondition {
    fn from(link: &InstalledLink) -> Self {
        match link {
            InstalledLink::Absent => Self::Absent,
            InstalledLink::Symlink(target) => Self::Symlink(target.clone()),
            InstalledLink::File => Self::File,
            InstalledLink::Directory => Self::Directory,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Preconditions {
    pub manifest: Option<ByteHash>,
    pub lock: Option<ByteHash>,
    pub candidates: BTreeMap<SourceAlias, Option<ByteHash>>,
    pub stores: BTreeMap<SourceAlias, StorePrecondition>,
    pub trust: Option<ByteHash>,
    pub projects: Option<ByteHash>,
    pub reachability: Option<ByteHash>,
    pub links: BTreeMap<SkillName, LinkPrecondition>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StorePrecondition {
    pub source_key: crate::SourceKey,
    pub snapshot_key: crate::SnapshotKey,
    pub inventory: String,
    pub state: SnapshotStore,
}

impl Preconditions {
    pub fn absent() -> Self {
        Self {
            manifest: None,
            lock: None,
            candidates: BTreeMap::new(),
            stores: BTreeMap::new(),
            trust: None,
            projects: None,
            reachability: None,
            links: BTreeMap::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum PlanFact {
    ResolvedRoot {
        root: RequestRoot,
        source: SourceAlias,
    },
    SourceContribution {
        source: SourceAlias,
    },
    PackMember {
        pack: crate::PackName,
        skill: SkillName,
        state: PackMemberState,
    },
    ShadowedGlobal {
        skill: SkillName,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PackMemberState {
    Required,
    Enabled,
    Excluded,
    Unavailable,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExitClass {
    Success,
    Findings,
    Usage,
    Blocked,
    Transport,
    Io,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Plan {
    pub actions: Vec<Action>,
    pub blockers: Vec<Blocker>,
    pub preconditions: Preconditions,
    pub facts: Vec<PlanFact>,
    pub exit_class: ExitClass,
}

impl Plan {
    pub fn has_changes(&self) -> bool {
        self.actions.iter().any(Action::is_mutating)
    }

    pub fn is_destructive(&self) -> bool {
        self.actions.iter().any(Action::is_destructive)
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let mut bytes = serde_json::to_vec_pretty(self)?;
        bytes.push(b'\n');
        Ok(bytes)
    }
}

pub fn plan(world: &WorldState, request: Request, mode: PlanningMode) -> Result<Plan> {
    if request == Request::Prune {
        return crate::prune::plan_prune(world);
    }
    match &request {
        Request::TrustSource { alias, mode } => {
            return plan_trust_source(world, alias, *mode);
        }
        Request::RevokeTrust { source } => {
            return plan_trust_mutation(world, TrustChange::Revoke, |store, before| {
                store.revoke(source, before)
            });
        }
        _ => {}
    }
    if request == Request::Initialize {
        return initialize(world, mode);
    }
    if !world.manifest_present || !world.lock_present {
        return Err(CoreError::Request(
            "scope is not initialized; initialize it before planning changes".into(),
        ));
    }

    let mut desired_snapshots = world.snapshots.clone();
    if mode == PlanningMode::Frozen {
        for (alias, state) in &world.locked_states {
            desired_snapshots.insert(alias.clone(), state.snapshot.clone());
        }
    }
    let mut selected_candidates = BTreeMap::new();
    let mut candidate_preconditions = BTreeMap::new();
    let mut request_blockers = Vec::new();
    let mut manifest_change = None;
    let mut requested_candidate_action = None;
    let mut requested_trust_action = None;
    let manifest_edit = match request {
        Request::Initialize => unreachable!(),
        Request::Reconcile => None,
        Request::AddSource { prepared, trust } => {
            let alias = prepared.alias().clone();
            let source = prepared.source().clone();
            manifest_change = Some(ManifestChange::AddSource);
            let edit = world.manifest.mutate(ManifestMutation::AddSource {
                alias: alias.clone(),
                source,
            })?;
            if prepared.manifest_before() != world.manifest_bytes
                || prepared.manifest_after() != edit.after
                || prepared.declaration_hash() != edit.manifest.source_declaration_hash(&alias)?
                || prepared.info().alias != alias
                || prepared.info().candidate.declaration_hash != prepared.declaration_hash()
            {
                return Err(CoreError::Request(
                    "prepared source no longer matches the immutable world".into(),
                ));
            }
            if world
                .source_states
                .values()
                .any(|state| state.identity.as_ref() == Some(&prepared.info().candidate.identity))
            {
                return Err(CoreError::Request(
                    "source canonical identity is already registered in this scope".into(),
                ));
            }
            let candidate_bytes = prepared.info().candidate.to_bytes()?;
            requested_candidate_action = Some(Action::ReplaceCandidate {
                scope: world.scope,
                alias: alias.clone(),
                source_key: prepared.info().candidate.source_key(),
                before: None,
                after: candidate_bytes,
            });
            candidate_preconditions.insert(alias, None);
            if trust != SourceTrustIntent::Untrusted {
                requested_trust_action = Some(trust_action_from_candidate(
                    world,
                    &prepared.info().candidate,
                    trust,
                )?);
            }
            Some(edit)
        }
        Request::RemoveSource { alias } => {
            manifest_change = Some(ManifestChange::RemoveSource);
            if let Some(candidate) = world.candidates.get(&alias) {
                let before = candidate.candidate_bytes.clone().ok_or_else(|| {
                    CoreError::Request("candidate observation lacks exact bytes".into())
                })?;
                let identity = candidate.identity.clone().ok_or_else(|| {
                    CoreError::Request("candidate observation lacks identity".into())
                })?;
                requested_candidate_action = Some(Action::RemoveCandidate {
                    scope: world.scope,
                    alias: alias.clone(),
                    source_key: crate::SourceKey::derive(&identity),
                    before: before.clone(),
                });
                candidate_preconditions.insert(alias.clone(), Some(ByteHash::of(&before)));
            } else {
                candidate_preconditions.insert(alias.clone(), None);
            }
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::RemoveSource { alias })?,
            )
        }
        Request::InstallSkill { name, source } => {
            manifest_change = Some(ManifestChange::InstallSkill);
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::InstallSkill { name, source })?,
            )
        }
        Request::UninstallSkill { name } => {
            manifest_change = Some(ManifestChange::UninstallSkill);
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::UninstallSkill { name })?,
            )
        }
        Request::InstallPack { name, request } => {
            manifest_change = Some(ManifestChange::InstallPack);
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::InstallPack { name, request })?,
            )
        }
        Request::UninstallPack { name } => {
            manifest_change = Some(ManifestChange::UninstallPack);
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::UninstallPack { name })?,
            )
        }
        Request::ReplacePackExclusions { name, exclude } => {
            let previous = &world
                .manifest
                .packs
                .get(&name)
                .ok_or_else(|| CoreError::Request(format!("pack `{name}` is not requested")))?
                .exclude;
            manifest_change = Some(ManifestChange::ReplacePackExclusions {
                removes_desired: !exclude.is_subset(previous),
            });
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::ReplacePackExclusions { name, exclude })?,
            )
        }
        Request::UpdateSource { alias } => {
            if !world.manifest.sources.contains_key(&alias) {
                return Err(CoreError::Request(format!(
                    "source `{alias}` is not declared"
                )));
            }
            if let Some(candidate) = world
                .candidates
                .get(&alias)
                .filter(|candidate| candidate.candidate_current)
            {
                desired_snapshots.insert(alias.clone(), candidate.snapshot.clone());
                selected_candidates.insert(alias, candidate.clone());
            } else if world.candidates.contains_key(&alias) {
                request_blockers.push(Blocker::new(
                    "source-candidate-stale",
                    [("source", alias.to_string())],
                ));
            } else {
                request_blockers.push(Blocker::new(
                    "source-candidate-missing",
                    [("source", alias.to_string())],
                ));
            }
            None
        }
        Request::TrustSource { .. } | Request::RevokeTrust { .. } | Request::Prune => {
            unreachable!("handled before scope planning")
        }
    };
    let desired_manifest = manifest_edit
        .as_ref()
        .map_or(&world.manifest, |edit| &edit.manifest);
    let mut resolution = resolve_manifest(desired_manifest, &desired_snapshots);
    add_shadowing_facts(world, &mut resolution.facts, &resolution.skills);

    let mut actions = Vec::new();
    let mut blockers = resolution.blockers;
    blockers.append(&mut request_blockers);
    if mode == PlanningMode::Frozen
        && (manifest_edit.is_some()
            || world.lock != resolution.lock
            || resolution
                .lock
                .sources
                .values()
                .any(|source| matches!(source, LockSource::Live { .. })))
    {
        blockers.push(Blocker::new("frozen-mismatch", []));
    }

    let mut store_preconditions = BTreeMap::new();

    if let (Some(edit), Some(change)) = (&manifest_edit, manifest_change) {
        actions.push(Action::ReplaceManifest {
            scope: world.scope,
            before: edit.before.clone(),
            after: edit.after.clone(),
            change,
        });
    }
    if let Some(action) = requested_candidate_action {
        actions.push(action);
    }
    if let Some(action) = requested_trust_action {
        actions.push(action);
    }

    if world.lock != resolution.lock {
        actions.push(Action::ReplaceLock {
            scope: world.scope,
            before: world.lock_bytes.clone(),
            after: resolution.lock.to_bytes()?,
            change: if source_advanced(&world.lock, &resolution.lock) {
                LockChange::SourceAdvance
            } else {
                LockChange::Resolve
            },
        });
    }

    let mut links = BTreeMap::new();
    for (name, resolved) in &resolution.skills {
        let observed = world
            .links
            .get(name)
            .cloned()
            .unwrap_or(InstalledLink::Absent);
        links.insert(name.clone(), LinkPrecondition::from(&observed));
        let old_target = incumbent_target(world, name);
        let planned_target = owned_target(&resolution.lock, &desired_snapshots, world, name)?;
        match observed {
            InstalledLink::Absent => actions.push(Action::CreateLink {
                scope: world.scope,
                skill: name.clone(),
                target: planned_target,
            }),
            InstalledLink::Symlink(target) if target == resolved.target => {
                actions.push(Action::RetainLink {
                    scope: world.scope,
                    skill: name.clone(),
                    target: planned_target,
                });
            }
            InstalledLink::Symlink(target) if old_target.as_ref() == Some(&target) => {
                actions.push(Action::RepointLink {
                    scope: world.scope,
                    skill: name.clone(),
                    before: incumbent_owned_target(world, name)?,
                    after: planned_target,
                });
            }
            InstalledLink::Symlink(target) if old_target.is_some() => blockers.push(Blocker::new(
                "link-drift",
                [
                    ("skill", name.to_string()),
                    ("target", target.display().to_string()),
                ],
            )),
            InstalledLink::Symlink(target) => blockers.push(Blocker::new(
                "foreign-link",
                [
                    ("skill", name.to_string()),
                    ("target", target.display().to_string()),
                ],
            )),
            InstalledLink::File => {
                blockers.push(Blocker::new("foreign-file", [("skill", name.to_string())]))
            }
            InstalledLink::Directory => blockers.push(Blocker::new(
                "foreign-directory",
                [("skill", name.to_string())],
            )),
        }
    }

    for name in world.lock.skills.keys() {
        if resolution.skills.contains_key(name) {
            continue;
        }
        let observed = world
            .links
            .get(name)
            .cloned()
            .unwrap_or(InstalledLink::Absent);
        links.insert(name.clone(), LinkPrecondition::from(&observed));
        let old_target = incumbent_target(world, name);
        match observed {
            InstalledLink::Absent => {}
            InstalledLink::Symlink(target) if old_target.as_ref() == Some(&target) => {
                actions.push(Action::RemoveLink {
                    scope: world.scope,
                    skill: name.clone(),
                    target: incumbent_owned_target(world, name)?,
                });
            }
            InstalledLink::Symlink(target) => blockers.push(Blocker::new(
                "link-drift",
                [
                    ("skill", name.to_string()),
                    ("target", target.display().to_string()),
                ],
            )),
            InstalledLink::File => {
                blockers.push(Blocker::new("foreign-file", [("skill", name.to_string())]))
            }
            InstalledLink::Directory => blockers.push(Blocker::new(
                "foreign-directory",
                [("skill", name.to_string())],
            )),
        }
    }

    let activating_sources = actions
        .iter()
        .filter_map(|action| match action {
            Action::CreateLink { skill, .. } | Action::RepointLink { skill, .. } => resolution
                .skills
                .get(skill)
                .map(|resolved| resolved.source.clone()),
            _ => None,
        })
        .collect::<std::collections::BTreeSet<_>>();
    let trust_store = world
        .trust_bytes
        .as_deref()
        .map(crate::TrustStore::parse)
        .transpose()?;
    let mut materializations = Vec::new();
    let mut baseline_updates = Vec::new();
    for alias in resolution.lock.sources.keys() {
        let state = if mode == PlanningMode::Frozen {
            world.locked_states.get(alias)
        } else {
            selected_candidates
                .get(alias)
                .or_else(|| world.source_states.get(alias))
        };
        let Some(state) = state else {
            blockers.push(Blocker::new(
                "source-observation-missing",
                [("source", alias.to_string())],
            ));
            continue;
        };
        if !state.snapshot.inventory.is_valid() {
            blockers.push(Blocker::new(
                "source-validation-invalid",
                [("source", alias.to_string())],
            ));
            continue;
        }
        let Some(identity) = state.identity.as_ref() else {
            blockers.push(Blocker::new(
                "source-identity-missing",
                [("source", alias.to_string())],
            ));
            continue;
        };
        let key = crate::SourceKey::derive(identity);
        let receipt = match state.snapshot.id.kind {
            SnapshotKind::Git => Some(crate::TrustReceipt {
                commit: state
                    .snapshot
                    .id
                    .commit
                    .clone()
                    .expect("validated Git snapshot"),
                tree: state
                    .snapshot
                    .id
                    .tree
                    .clone()
                    .expect("validated Git snapshot"),
                inventory: state.snapshot.id.inventory_digest.clone(),
            }),
            SnapshotKind::Live => None,
        };
        let effective_trust = trust_store
            .as_ref()
            .and_then(|store| store.records.get(&key))
            .map_or(TrustMode::Untrusted, |record| {
                record.mode_for(receipt.as_ref())
            });
        if state.snapshot.id.kind == SnapshotKind::Live {
            if activating_sources.contains(alias) && effective_trust != TrustMode::All {
                blockers.push(Blocker::new(
                    "live-source-requires-all-trust",
                    [("source", alias.to_string())],
                ));
            }
            continue;
        }
        let snapshot_key = crate::SnapshotKey::derive(
            crate::SourceKind::Git,
            state
                .snapshot
                .id
                .commit
                .as_deref()
                .expect("validated Git snapshot"),
            state
                .snapshot
                .id
                .tree
                .as_deref()
                .expect("validated Git snapshot"),
            &state.snapshot.id.inventory_digest,
        )?;
        store_preconditions.insert(
            alias.clone(),
            StorePrecondition {
                source_key: key.clone(),
                snapshot_key,
                inventory: state.snapshot.id.inventory_digest.clone(),
                state: state.store,
            },
        );
        if activating_sources.contains(alias) && effective_trust == TrustMode::Untrusted {
            blockers.push(Blocker::new(
                "source-untrusted",
                [("source", alias.to_string())],
            ));
        }
        if activating_sources.contains(alias) && effective_trust == TrustMode::All {
            if let (Some(identity), Some(review_tree)) = (&state.identity, &state.review_tree) {
                baseline_updates.push((
                    crate::SourceKey::derive(identity),
                    crate::TrustBaseline {
                        commit: state.snapshot.id.commit.clone(),
                        tree: state.snapshot.id.tree.clone(),
                        inventory: state.snapshot.id.inventory_digest.clone(),
                        review_tree: review_tree.clone(),
                    },
                ));
            }
        }
        match state.store {
            SnapshotStore::Valid => {}
            SnapshotStore::Absent
                if activating_sources.contains(alias)
                    && state.materializable
                    && mode == PlanningMode::Normal
                    && effective_trust != TrustMode::Untrusted =>
            {
                let review_tree = state.review_tree.as_deref().ok_or_else(|| {
                    CoreError::Snapshot("materializable snapshot has no review identity".into())
                })?;
                let commit = state.snapshot.id.commit.as_deref().ok_or_else(|| {
                    CoreError::Snapshot("materializable snapshot has no commit".into())
                })?;
                let tree = state.snapshot.id.tree.as_deref().ok_or_else(|| {
                    CoreError::Snapshot("materializable snapshot has no tree".into())
                })?;
                let snapshot_key = crate::SnapshotKey::derive(
                    crate::SourceKind::Git,
                    commit,
                    tree,
                    &state.snapshot.id.inventory_digest,
                )?;
                let review_key = crate::ReviewKey::derive(
                    crate::SourceKind::Git,
                    Some(commit),
                    Some(tree),
                    &state.snapshot.id.inventory_digest,
                    review_tree,
                )?;
                materializations.push(Action::PrepareSnapshot {
                    scope: world.scope,
                    source: alias.clone(),
                    source_key: key.to_string(),
                    snapshot_key: snapshot_key.to_string(),
                    review_key: review_key.to_string(),
                    operation: SnapshotPreparation::Materialize,
                });
            }
            SnapshotStore::Corrupt
                if activating_sources.contains(alias)
                    && state.materializable
                    && mode == PlanningMode::Normal
                    && effective_trust != TrustMode::Untrusted =>
            {
                let review_tree = state.review_tree.as_deref().ok_or_else(|| {
                    CoreError::Snapshot("repairable snapshot has no review identity".into())
                })?;
                let commit = state.snapshot.id.commit.as_deref().ok_or_else(|| {
                    CoreError::Snapshot("repairable snapshot has no commit".into())
                })?;
                let tree =
                    state.snapshot.id.tree.as_deref().ok_or_else(|| {
                        CoreError::Snapshot("repairable snapshot has no tree".into())
                    })?;
                let snapshot_key = crate::SnapshotKey::derive(
                    crate::SourceKind::Git,
                    commit,
                    tree,
                    &state.snapshot.id.inventory_digest,
                )?;
                let review_key = crate::ReviewKey::derive(
                    crate::SourceKind::Git,
                    Some(commit),
                    Some(tree),
                    &state.snapshot.id.inventory_digest,
                    review_tree,
                )?;
                materializations.push(Action::PrepareSnapshot {
                    scope: world.scope,
                    source: alias.clone(),
                    source_key: key.to_string(),
                    snapshot_key: snapshot_key.to_string(),
                    review_key: review_key.to_string(),
                    operation: SnapshotPreparation::Repair,
                });
            }
            SnapshotStore::Absent => blockers.push(Blocker::new(
                "snapshot-store-absent",
                [("source", alias.to_string())],
            )),
            SnapshotStore::Corrupt => blockers.push(Blocker::new(
                "snapshot-store-corrupt",
                [("source", alias.to_string())],
            )),
        }
    }
    if !baseline_updates.is_empty() {
        match world.trust_bytes.as_deref() {
            None => blockers.push(Blocker::new("trust-observation-missing", [])),
            Some(bytes) => {
                let mut store = crate::TrustStore::parse(bytes)?;
                let mut after = None;
                for (source, baseline) in baseline_updates {
                    let record = store.records.get(&source).ok_or_else(|| {
                        CoreError::Trust("all-trusted source has no trust record".into())
                    })?;
                    if record.baseline.as_ref() == Some(&baseline) {
                        continue;
                    }
                    let mutation = store.advance_baseline(
                        &source,
                        baseline,
                        Some(after.clone().unwrap_or_else(|| bytes.to_vec())),
                    )?;
                    store = crate::TrustStore::parse(&mutation.after)?;
                    after = Some(mutation.after);
                }
                if let Some(after) = after {
                    materializations.push(Action::ReplaceTrust {
                        before: Some(bytes.to_vec()),
                        after,
                        create_mode: 0o600,
                        change: TrustChange::AdvanceBaseline,
                    });
                }
            }
        }
    }
    actions.splice(0..0, materializations);

    blockers.sort();
    blockers.dedup();
    let exit_class = if blockers.is_empty() {
        ExitClass::Success
    } else {
        ExitClass::Blocked
    };
    Ok(Plan {
        actions,
        blockers,
        preconditions: Preconditions {
            manifest: Some(ByteHash::of(&world.manifest_bytes)),
            lock: Some(ByteHash::of(&world.lock_bytes)),
            candidates: {
                candidate_preconditions.extend(selected_candidates.into_iter().filter_map(
                    |(alias, state)| {
                        state
                            .candidate_bytes
                            .map(|bytes| (alias, Some(ByteHash::of(&bytes))))
                    },
                ));
                candidate_preconditions
            },
            stores: store_preconditions,
            trust: world.trust_bytes.as_deref().map(ByteHash::of),
            projects: (world.scope == Scope::Project)
                .then(|| world.project_index_bytes.as_deref().map(ByteHash::of))
                .flatten(),
            reachability: None,
            links,
        },
        facts: resolution.facts,
        exit_class,
    })
}

fn plan_trust_mutation(
    world: &WorldState,
    change: TrustChange,
    mutate: impl FnOnce(&crate::TrustStore, Option<Vec<u8>>) -> Result<crate::TrustMutation>,
) -> Result<Plan> {
    let before = world.trust_bytes.clone();
    let store = match before.as_deref() {
        Some(bytes) => crate::TrustStore::parse(bytes)?,
        None => crate::TrustStore::default(),
    };
    let mutation = mutate(&store, before.clone())?;
    Ok(Plan {
        actions: vec![Action::ReplaceTrust {
            before: mutation.before,
            after: mutation.after,
            create_mode: mutation.create_mode,
            change,
        }],
        blockers: Vec::new(),
        preconditions: Preconditions {
            trust: before.as_deref().map(ByteHash::of),
            ..Preconditions::absent()
        },
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    })
}

fn plan_trust_source(
    world: &WorldState,
    alias: &SourceAlias,
    intent: SourceTrustIntent,
) -> Result<Plan> {
    let candidate = world
        .candidates
        .get(alias)
        .filter(|candidate| candidate.candidate_current)
        .ok_or_else(|| CoreError::Request(format!("source `{alias}` has no current candidate")))?;
    let bytes = candidate
        .candidate_bytes
        .as_deref()
        .ok_or_else(|| CoreError::Request("candidate observation lacks exact bytes".into()))?;
    let record = crate::CandidateRecord::parse(bytes, None)?;
    if candidate.identity.as_ref() != Some(&record.identity)
        || candidate.snapshot.id.commit != record.commit
        || candidate.snapshot.id.tree != record.tree
        || candidate.snapshot.id.inventory_digest != record.inventory
    {
        return Err(CoreError::Request(
            "candidate bytes and observed candidate disagree".into(),
        ));
    }
    let action = trust_action_from_candidate(world, &record, intent)?;
    Ok(Plan {
        actions: vec![action],
        blockers: Vec::new(),
        preconditions: Preconditions {
            candidates: BTreeMap::from([(alias.clone(), Some(ByteHash::of(bytes)))]),
            trust: world.trust_bytes.as_deref().map(ByteHash::of),
            ..Preconditions::absent()
        },
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    })
}

fn trust_action_from_candidate(
    world: &WorldState,
    candidate: &crate::CandidateRecord,
    intent: SourceTrustIntent,
) -> Result<Action> {
    let before = world.trust_bytes.clone();
    let store = before
        .as_deref()
        .map(crate::TrustStore::parse)
        .transpose()?
        .unwrap_or_default();
    let receipt = match candidate.identity.kind() {
        crate::SourceKind::Git => Some(crate::TrustReceipt {
            commit: candidate.commit.clone().expect("validated Git candidate"),
            tree: candidate.tree.clone().expect("validated Git candidate"),
            inventory: candidate.inventory.clone(),
        }),
        crate::SourceKind::Live => None,
    };
    let baseline = crate::TrustBaseline {
        commit: candidate.commit.clone(),
        tree: candidate.tree.clone(),
        inventory: candidate.inventory.clone(),
        review_tree: candidate.review_tree.clone(),
    };
    let (change, mutation) = match intent {
        SourceTrustIntent::Exact => (
            TrustChange::GrantExact,
            store.grant_exact(
                candidate.identity.clone(),
                receipt.ok_or_else(|| {
                    CoreError::Trust("live sources cannot receive exact trust".into())
                })?,
                baseline,
                before,
            )?,
        ),
        SourceTrustIntent::All => (
            TrustChange::GrantAll,
            store.grant_all(candidate.identity.clone(), receipt, baseline, before)?,
        ),
        SourceTrustIntent::Untrusted => {
            return Err(CoreError::Request(
                "untrusted is not a trust mutation".into(),
            ))
        }
    };
    Ok(Action::ReplaceTrust {
        before: mutation.before,
        after: mutation.after,
        create_mode: mutation.create_mode,
        change,
    })
}

fn initialize(world: &WorldState, mode: PlanningMode) -> Result<Plan> {
    if world.manifest_present || world.lock_present {
        return Err(CoreError::Request("scope is already initialized".into()));
    }
    if mode == PlanningMode::Frozen {
        return Ok(Plan {
            actions: Vec::new(),
            blockers: vec![Blocker::new("frozen-mismatch", [])],
            preconditions: initialization_preconditions(world),
            facts: Vec::new(),
            exit_class: ExitClass::Blocked,
        });
    }
    Ok(Plan {
        actions: vec![
            Action::CreateManifest {
                scope: world.scope,
                after: world.manifest_bytes.clone(),
            },
            Action::CreateLock {
                scope: world.scope,
                after: world.lock_bytes.clone(),
            },
        ],
        blockers: Vec::new(),
        preconditions: initialization_preconditions(world),
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    })
}

fn initialization_preconditions(world: &WorldState) -> Preconditions {
    Preconditions {
        projects: (world.scope == Scope::Project)
            .then(|| world.project_index_bytes.as_deref().map(ByteHash::of))
            .flatten(),
        ..Preconditions::absent()
    }
}

fn add_shadowing_facts(
    world: &WorldState,
    facts: &mut Vec<PlanFact>,
    skills: &BTreeMap<SkillName, crate::ResolvedSkill>,
) {
    if world.scope != Scope::Project {
        return;
    }
    if let Some(global) = &world.inherited_global {
        for skill in skills.keys() {
            if global.skills.contains_key(skill) {
                facts.push(PlanFact::ShadowedGlobal {
                    skill: skill.clone(),
                });
            }
        }
        facts.sort();
        facts.dedup();
    }
}

fn incumbent_target(world: &WorldState, name: &SkillName) -> Option<PathBuf> {
    let skill = world.lock.skills.get(name)?;
    let snapshot = world.snapshots.get(&skill.source)?;
    Some(snapshot.root.join(&skill.path))
}

fn owned_target(
    lock: &Lockfile,
    snapshots: &BTreeMap<SourceAlias, crate::SourceSnapshot>,
    world: &WorldState,
    name: &SkillName,
) -> Result<OwnedLinkTarget> {
    let skill = lock
        .skills
        .get(name)
        .ok_or_else(|| CoreError::Request(format!("resolved skill `{name}` has no lock entry")))?;
    let snapshot = snapshots.get(&skill.source).ok_or_else(|| {
        CoreError::Request(format!("resolved skill `{name}` has no source snapshot"))
    })?;
    let identity = [
        world.candidates.get(&skill.source),
        world.source_states.get(&skill.source),
        world.locked_states.get(&skill.source),
    ]
    .into_iter()
    .flatten()
    .find_map(|state| state.identity.clone())
    .ok_or_else(|| {
        CoreError::Request(format!(
            "source `{}` has no canonical identity",
            skill.source
        ))
    })?;
    match snapshot.id.kind {
        SnapshotKind::Git => Ok(OwnedLinkTarget::Stored {
            source_key: crate::SourceKey::derive(&identity),
            snapshot_key: crate::SnapshotKey::derive(
                crate::SourceKind::Git,
                snapshot
                    .id
                    .commit
                    .as_deref()
                    .expect("validated Git snapshot"),
                snapshot.id.tree.as_deref().expect("validated Git snapshot"),
                &snapshot.id.inventory_digest,
            )?,
            skill_path: skill.path.clone(),
        }),
        SnapshotKind::Live => Ok(OwnedLinkTarget::Live {
            identity,
            skill_path: skill.path.clone(),
        }),
    }
}

fn incumbent_owned_target(world: &WorldState, name: &SkillName) -> Result<OwnedLinkTarget> {
    owned_target(&world.lock, &world.snapshots, world, name)
}

fn source_advanced(before: &Lockfile, after: &Lockfile) -> bool {
    before.sources.iter().any(|(alias, old)| {
        let Some(new) = after.sources.get(alias) else {
            return false;
        };
        match (old, new) {
            (
                LockSource::Git {
                    commit: old_commit,
                    tree: old_tree,
                    inventory: old_inventory,
                    ..
                },
                LockSource::Git {
                    commit: new_commit,
                    tree: new_tree,
                    inventory: new_inventory,
                    ..
                },
            ) => old_commit != new_commit || old_tree != new_tree || old_inventory != new_inventory,
            _ => false,
        }
    })
}
