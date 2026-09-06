use std::collections::{BTreeMap, BTreeSet};

use crate::{
    check, resolve_manifest_for_scope, source_summaries, Blocker, CheckFinding, DesiredState,
    InstalledLink, InstalledStatus, PackName, ProjectionMode, RequestRoot, Result, Scope,
    SkillName, SourceAlias, TrustMode, WorldState,
};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum TreeItemKey {
    Source(SourceAlias),
    Pack {
        source: SourceAlias,
        name: PackName,
    },
    PackMember {
        source: SourceAlias,
        pack: PackName,
        name: SkillName,
    },
    Skill {
        source: SourceAlias,
        name: SkillName,
    },
    InheritedSkill {
        name: SkillName,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PackSelection {
    Off,
    Partial,
    Full,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SkillAvailability {
    Available,
    Required,
    Optional,
    Unavailable,
    Inherited,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TreeItemKind {
    Source {
        link: bool,
        trust: TrustMode,
        candidate_current: bool,
        has_findings: bool,
    },
    Pack(PackSelection),
    Skill(SkillAvailability),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TreeItem {
    pub key: TreeItemKey,
    pub label: String,
    pub depth: u16,
    pub selected: bool,
    pub toggleable: bool,
    pub mode: Option<ProjectionMode>,
    pub mode_toggleable: bool,
    pub kind: TreeItemKind,
    pub requested_by: BTreeSet<RequestRoot>,
    pub installed: Option<InstalledStatus>,
    pub inert_reason: Option<String>,
    pub shadowed: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TreeProjection {
    pub scope: Scope,
    pub items: Vec<TreeItem>,
    pub blockers: Vec<Blocker>,
    pub findings: Vec<CheckFinding>,
}

impl TreeProjection {
    pub fn item(&self, key: &TreeItemKey) -> Option<&TreeItem> {
        self.items.iter().find(|item| &item.key == key)
    }
}

/// Project immutable source facts together with disposable desired roots.
pub fn project_tree(world: &WorldState, desired: &DesiredState) -> Result<TreeProjection> {
    let desired_manifest =
        if desired.skills == world.manifest.skills && desired.packs == world.manifest.packs {
            world.manifest.clone()
        } else {
            world.manifest.replace_desired(desired)?.manifest
        };
    let resolution = resolve_manifest_for_scope(world.scope, &desired_manifest, &world.snapshots);
    let source_facts = source_summaries(world)?
        .into_iter()
        .map(|summary| (summary.alias.clone(), summary))
        .collect::<BTreeMap<_, _>>();
    let mut items = Vec::new();

    for (alias, declaration) in &world.manifest.sources {
        let facts = source_facts.get(alias);
        items.push(TreeItem {
            key: TreeItemKey::Source(alias.clone()),
            label: alias.to_string(),
            depth: 0,
            selected: false,
            toggleable: false,
            mode: None,
            mode_toggleable: false,
            kind: TreeItemKind::Source {
                link: declaration.link,
                trust: facts.map_or(TrustMode::Untrusted, |facts| facts.trust),
                candidate_current: facts.is_some_and(|facts| facts.candidate_current),
                has_findings: facts.is_some_and(|facts| facts.has_findings),
            },
            requested_by: BTreeSet::new(),
            installed: None,
            inert_reason: None,
            shadowed: false,
        });

        let Some(source) = world.source_states.get(alias) else {
            continue;
        };
        let inventory = &source.snapshot.inventory;
        let available = inventory
            .skills
            .iter()
            .filter_map(|skill| SkillName::new(skill.name.clone()).ok())
            .collect::<BTreeSet<_>>();
        let mut packs = inventory.packs.iter().collect::<Vec<_>>();
        packs.sort_by(|left, right| left.name.cmp(&right.name));
        for pack in packs {
            let name = PackName::new(pack.name.clone())?;
            let request = desired
                .packs
                .get(&name)
                .filter(|request| &request.source == alias);
            let state = pack_selection(pack, request, &available);
            let owner = desired.packs.get(&name).map(|request| &request.source);
            items.push(TreeItem {
                key: TreeItemKey::Pack {
                    source: alias.clone(),
                    name: name.clone(),
                },
                label: name.to_string(),
                depth: 1,
                selected: request.is_some(),
                toggleable: owner.is_none_or(|owner| owner == alias),
                mode: request.map(|request| request.mode),
                mode_toggleable: false,
                kind: TreeItemKind::Pack(state),
                requested_by: BTreeSet::from([RequestRoot::Pack(name.clone())]),
                installed: None,
                inert_reason: owner
                    .filter(|owner| *owner != alias)
                    .map(|owner| format!("requested from {owner}")),
                shadowed: false,
            });

            for member in &pack.required {
                let member = SkillName::new(member.clone())?;
                items.push(pack_member(
                    world,
                    &resolution,
                    alias,
                    &name,
                    member,
                    SkillAvailability::Required,
                    request.is_some(),
                    false,
                    request.map(|request| request.mode),
                    &available,
                ));
            }
            for member in &pack.optional {
                let member = SkillName::new(member.clone())?;
                let enabled = request.is_some_and(|request| !request.exclude.contains(&member));
                items.push(pack_member(
                    world,
                    &resolution,
                    alias,
                    &name,
                    member,
                    SkillAvailability::Optional,
                    enabled,
                    request.is_some(),
                    request.map(|request| request.mode),
                    &available,
                ));
            }
        }

        let mut skills = inventory.skills.iter().collect::<Vec<_>>();
        skills.sort_by(|left, right| left.name.cmp(&right.name));
        for skill in skills {
            let name = SkillName::new(skill.name.clone())?;
            let owner = desired.skills.get(&name);
            items.push(TreeItem {
                key: TreeItemKey::Skill {
                    source: alias.clone(),
                    name: name.clone(),
                },
                label: name.to_string(),
                depth: 1,
                selected: owner.is_some_and(|owner| &owner.source == alias),
                toggleable: owner.is_none_or(|owner| &owner.source == alias),
                mode: owner
                    .filter(|owner| &owner.source == alias)
                    .map(|owner| owner.mode),
                mode_toggleable: false,
                kind: TreeItemKind::Skill(SkillAvailability::Available),
                requested_by: requested_by(&resolution, &name),
                installed: installed_status(world, &resolution, &name),
                inert_reason: owner
                    .filter(|owner| &owner.source != alias)
                    .map(|owner| format!("requested from {}", owner.source)),
                shadowed: false,
            });
        }
    }

    if let Some(global) = &world.inherited_global {
        for name in global.skills.keys() {
            items.push(TreeItem {
                key: TreeItemKey::InheritedSkill { name: name.clone() },
                label: name.to_string(),
                depth: 0,
                selected: true,
                toggleable: false,
                mode: global.lock.skills.get(name).map(|skill| skill.mode),
                mode_toggleable: false,
                kind: TreeItemKind::Skill(SkillAvailability::Inherited),
                requested_by: global
                    .lock
                    .skills
                    .get(name)
                    .map_or_else(BTreeSet::new, |skill| skill.requested_by.clone()),
                installed: Some(InstalledStatus::Current),
                inert_reason: Some("inherited global".into()),
                shadowed: resolution.skills.contains_key(name),
            });
        }
    }

    Ok(TreeProjection {
        scope: world.scope,
        items,
        blockers: resolution.blockers,
        findings: check(world).findings,
    })
}

fn pack_selection(
    pack: &crate::inventory::Pack,
    request: Option<&crate::ManifestPack>,
    available: &BTreeSet<SkillName>,
) -> PackSelection {
    let Some(request) = request else {
        return PackSelection::Off;
    };
    let incomplete = pack.required.iter().any(|name| {
        SkillName::new(name.clone())
            .map(|name| !available.contains(&name))
            .unwrap_or(true)
    }) || pack.optional.iter().any(|name| {
        SkillName::new(name.clone())
            .map(|name| request.exclude.contains(&name) || !available.contains(&name))
            .unwrap_or(true)
    });
    if incomplete {
        PackSelection::Partial
    } else {
        PackSelection::Full
    }
}

#[allow(clippy::too_many_arguments)]
fn pack_member(
    world: &WorldState,
    resolution: &crate::Resolution,
    source: &SourceAlias,
    pack: &PackName,
    name: SkillName,
    intended: SkillAvailability,
    selected: bool,
    optional_toggle: bool,
    mode: Option<ProjectionMode>,
    available: &BTreeSet<SkillName>,
) -> TreeItem {
    let is_available = available.contains(&name);
    let availability = if is_available {
        intended
    } else {
        SkillAvailability::Unavailable
    };
    TreeItem {
        key: TreeItemKey::PackMember {
            source: source.clone(),
            pack: pack.clone(),
            name: name.clone(),
        },
        label: name.to_string(),
        depth: 2,
        selected: selected && is_available,
        toggleable: optional_toggle && is_available,
        mode,
        mode_toggleable: false,
        kind: TreeItemKind::Skill(availability),
        requested_by: requested_by(resolution, &name),
        installed: installed_status(world, resolution, &name),
        inert_reason: if !is_available {
            Some("unavailable".into())
        } else if intended == SkillAvailability::Required {
            Some("required".into())
        } else if !optional_toggle {
            Some("pack not selected".into())
        } else {
            None
        },
        shadowed: false,
    }
}

fn requested_by(resolution: &crate::Resolution, name: &SkillName) -> BTreeSet<RequestRoot> {
    resolution
        .lock
        .skills
        .get(name)
        .map_or_else(BTreeSet::new, |skill| skill.requested_by.clone())
}

fn installed_status(
    world: &WorldState,
    resolution: &crate::Resolution,
    name: &SkillName,
) -> Option<InstalledStatus> {
    let resolved = resolution.skills.get(name)?;
    Some(if resolved.mode == ProjectionMode::Vendor {
        match world.vendors.get(name).map(|vendor| vendor.state) {
            Some(crate::VendorState::OwnedUnchanged) => InstalledStatus::Current,
            Some(crate::VendorState::Absent) | None => InstalledStatus::Missing,
            Some(crate::VendorState::Drifted) => InstalledStatus::Drift,
            Some(crate::VendorState::Foreign) => match world.links.get(name) {
                Some(InstalledLink::File) => InstalledStatus::ForeignFile,
                _ => InstalledStatus::ForeignDirectory,
            },
        }
    } else {
        match world.links.get(name).unwrap_or(&InstalledLink::Absent) {
            InstalledLink::Absent => InstalledStatus::Missing,
            InstalledLink::Symlink(target) if target == &resolved.target => {
                InstalledStatus::Current
            }
            InstalledLink::Symlink(_) => InstalledStatus::Drift,
            InstalledLink::File => InstalledStatus::ForeignFile,
            InstalledLink::Directory => InstalledStatus::ForeignDirectory,
        }
    })
}
