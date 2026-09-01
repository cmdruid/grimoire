use std::collections::BTreeMap;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::resolve::resolve_manifest;
use crate::{
    ByteHash, CoreError, InstalledLink, LockSource, Lockfile, ManifestMutation, PlanningMode,
    Request, RequestRoot, Result, Scope, SkillName, SourceAlias, WorldState,
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Action {
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
        target: PathBuf,
    },
    RetainLink {
        scope: Scope,
        skill: SkillName,
        target: PathBuf,
    },
    RepointLink {
        scope: Scope,
        skill: SkillName,
        before: PathBuf,
        after: PathBuf,
    },
    RemoveLink {
        scope: Scope,
        skill: SkillName,
        target: PathBuf,
    },
}

impl Action {
    fn is_mutating(&self) -> bool {
        !matches!(self, Self::RetainLink { .. })
    }

    fn is_destructive(&self) -> bool {
        match self {
            Self::ReplaceManifest { change, .. } => change.is_destructive(),
            Self::ReplaceLock {
                change: LockChange::SourceAdvance,
                ..
            }
            | Self::RepointLink { .. }
            | Self::RemoveLink { .. } => true,
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
    pub links: BTreeMap<SkillName, LinkPrecondition>,
}

impl Preconditions {
    pub fn absent() -> Self {
        Self {
            manifest: None,
            lock: None,
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
    if request == Request::Initialize {
        return initialize(world, mode);
    }
    if !world.manifest_present || !world.lock_present {
        return Err(CoreError::Request(
            "scope is not initialized; initialize it before planning changes".into(),
        ));
    }

    let mut desired_snapshots = world.snapshots.clone();
    let mut manifest_change = None;
    let manifest_edit = match request {
        Request::Initialize => unreachable!(),
        Request::Reconcile => None,
        Request::AddSource { alias, source } => {
            manifest_change = Some(ManifestChange::AddSource);
            Some(
                world
                    .manifest
                    .mutate(ManifestMutation::AddSource { alias, source })?,
            )
        }
        Request::RemoveSource { alias } => {
            manifest_change = Some(ManifestChange::RemoveSource);
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
        Request::UpdateSource { alias, snapshot } => {
            if !world.manifest.sources.contains_key(&alias) {
                return Err(CoreError::Request(format!(
                    "source `{alias}` is not declared"
                )));
            }
            if snapshot.alias != alias {
                return Err(CoreError::Request(format!(
                    "proposed snapshot alias `{}` does not match `{alias}`",
                    snapshot.alias
                )));
            }
            desired_snapshots.insert(alias, *snapshot);
            None
        }
    };
    let desired_manifest = manifest_edit
        .as_ref()
        .map_or(&world.manifest, |edit| &edit.manifest);
    let mut resolution = resolve_manifest(desired_manifest, &desired_snapshots);
    add_shadowing_facts(world, &mut resolution.facts, &resolution.skills);

    let mut actions = Vec::new();
    let mut blockers = resolution.blockers;
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

    if let (Some(edit), Some(change)) = (&manifest_edit, manifest_change) {
        actions.push(Action::ReplaceManifest {
            scope: world.scope,
            before: edit.before.clone(),
            after: edit.after.clone(),
            change,
        });
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
        match observed {
            InstalledLink::Absent => actions.push(Action::CreateLink {
                scope: world.scope,
                skill: name.clone(),
                target: resolved.target.clone(),
            }),
            InstalledLink::Symlink(target) if target == resolved.target => {
                actions.push(Action::RetainLink {
                    scope: world.scope,
                    skill: name.clone(),
                    target,
                });
            }
            InstalledLink::Symlink(target) if old_target.as_ref() == Some(&target) => {
                actions.push(Action::RepointLink {
                    scope: world.scope,
                    skill: name.clone(),
                    before: target,
                    after: resolved.target.clone(),
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
                    target,
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
            links,
        },
        facts: resolution.facts,
        exit_class,
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
            preconditions: Preconditions::absent(),
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
        preconditions: Preconditions::absent(),
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    })
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
                    ..
                },
                LockSource::Git {
                    commit: new_commit,
                    tree: new_tree,
                    ..
                },
            ) => old_commit != new_commit || old_tree != new_tree,
            _ => false,
        }
    })
}
