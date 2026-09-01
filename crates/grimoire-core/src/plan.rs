use std::collections::BTreeMap;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::resolve::resolve_manifest;
use crate::{
    ByteHash, InstalledLink, ManifestMutation, PlanningMode, Request, RequestRoot, Result, Scope,
    SkillName, SourceAlias, WorldState,
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Action {
    ReplaceManifest {
        scope: Scope,
        before: Vec<u8>,
        after: Vec<u8>,
    },
    ReplaceLock {
        scope: Scope,
        before: Vec<u8>,
        after: Vec<u8>,
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
        matches!(self, Self::RepointLink { .. } | Self::RemoveLink { .. })
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
}

pub fn plan(world: &WorldState, request: Request, mode: PlanningMode) -> Result<Plan> {
    let manifest_edit = match request {
        Request::Reconcile => None,
        Request::AddSource { alias, source } => Some(
            world
                .manifest
                .mutate(ManifestMutation::AddSource { alias, source })?,
        ),
        Request::RemoveSource { alias } => Some(
            world
                .manifest
                .mutate(ManifestMutation::RemoveSource { alias })?,
        ),
        Request::InstallSkill { name, source } => Some(
            world
                .manifest
                .mutate(ManifestMutation::InstallSkill { name, source })?,
        ),
        Request::UninstallSkill { name } => Some(
            world
                .manifest
                .mutate(ManifestMutation::UninstallSkill { name })?,
        ),
        Request::InstallPack { name, request } => Some(
            world
                .manifest
                .mutate(ManifestMutation::InstallPack { name, request })?,
        ),
        Request::UninstallPack { name } => Some(
            world
                .manifest
                .mutate(ManifestMutation::UninstallPack { name })?,
        ),
        Request::ReplacePackExclusions { name, exclude } => Some(
            world
                .manifest
                .mutate(ManifestMutation::ReplacePackExclusions { name, exclude })?,
        ),
    };
    let desired_manifest = manifest_edit
        .as_ref()
        .map_or(&world.manifest, |edit| &edit.manifest);
    let mut resolution = resolve_manifest(desired_manifest, &world.snapshots);
    if world.scope == Scope::Project {
        if let Some(global) = &world.inherited_global {
            for skill in resolution.skills.keys() {
                if global.skills.contains_key(skill) {
                    resolution.facts.push(PlanFact::ShadowedGlobal {
                        skill: skill.clone(),
                    });
                }
            }
            resolution.facts.sort();
            resolution.facts.dedup();
        }
    }
    let mut actions = Vec::new();
    let mut blockers = resolution.blockers;

    if mode == PlanningMode::Frozen && (manifest_edit.is_some() || world.lock != resolution.lock) {
        blockers.push(Blocker::new("frozen-mismatch", []));
    }

    if let Some(edit) = &manifest_edit {
        actions.push(Action::ReplaceManifest {
            scope: world.scope,
            before: edit.before.clone(),
            after: edit.after.clone(),
        });
    }

    if blockers.is_empty() && world.lock != resolution.lock {
        actions.push(Action::ReplaceLock {
            scope: world.scope,
            before: world.lock_bytes.clone(),
            after: resolution.lock.to_bytes()?,
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
        match observed {
            InstalledLink::Absent if blockers.is_empty() => actions.push(Action::CreateLink {
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
            InstalledLink::Absent => {}
        }
    }
    blockers.sort();
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
