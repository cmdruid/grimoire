use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::{
    Blocker, LockPack, LockSkill, LockSource, Lockfile, Manifest, PackMemberState, PlanFact,
    RequestRoot, SkillName, SnapshotKind, SourceAlias, SourceLocation, SourceSnapshot,
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResolvedSkill {
    pub source: SourceAlias,
    pub target: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Resolution {
    pub lock: Lockfile,
    pub skills: BTreeMap<SkillName, ResolvedSkill>,
    pub blockers: Vec<Blocker>,
    pub facts: Vec<PlanFact>,
}

#[derive(Debug, Clone)]
struct Candidate {
    source: SourceAlias,
    path: String,
    content: String,
    target: PathBuf,
    roots: BTreeSet<RequestRoot>,
}

pub fn resolve_manifest(
    manifest: &Manifest,
    snapshots: &BTreeMap<SourceAlias, SourceSnapshot>,
) -> Resolution {
    let mut lock = Lockfile::default();
    let mut candidates: BTreeMap<SkillName, BTreeMap<SourceAlias, Candidate>> = BTreeMap::new();
    let mut blockers = Vec::new();
    let mut facts = Vec::new();
    let mut contributing_sources = BTreeSet::new();

    for (name, alias) in &manifest.skills {
        let root = RequestRoot::Skill(name.clone());
        let Some(snapshot) = usable_snapshot(alias, snapshots, &mut blockers) else {
            continue;
        };
        let matches: Vec<_> = snapshot
            .inventory
            .skills
            .iter()
            .filter(|skill| skill.name == name.as_str())
            .collect();
        let skill = match matches.as_slice() {
            [skill] => *skill,
            [] => {
                push_blocker(
                    &mut blockers,
                    Blocker::new(
                        "skill-missing",
                        [("source", alias.to_string()), ("skill", name.to_string())],
                    ),
                );
                continue;
            }
            _ => {
                push_blocker(
                    &mut blockers,
                    Blocker::new("source-inventory-invalid", [("source", alias.to_string())]),
                );
                continue;
            }
        };
        add_candidate(&mut candidates, name, alias, snapshot, skill, root.clone());
        facts.push(PlanFact::ResolvedRoot {
            root,
            source: alias.clone(),
        });
        contributing_sources.insert(alias.clone());
    }

    for (pack_name, request) in &manifest.packs {
        let alias = &request.source;
        let Some(snapshot) = usable_snapshot(alias, snapshots, &mut blockers) else {
            continue;
        };
        let matches: Vec<_> = snapshot
            .inventory
            .packs
            .iter()
            .filter(|pack| pack.name == pack_name.as_str())
            .collect();
        let pack = match matches.as_slice() {
            [pack] => *pack,
            [] => {
                push_blocker(
                    &mut blockers,
                    Blocker::new(
                        "pack-missing",
                        [
                            ("source", alias.to_string()),
                            ("pack", pack_name.to_string()),
                        ],
                    ),
                );
                continue;
            }
            _ => {
                push_blocker(
                    &mut blockers,
                    Blocker::new("source-inventory-invalid", [("source", alias.to_string())]),
                );
                continue;
            }
        };
        let Some(required) = inventory_names(&pack.required) else {
            push_blocker(
                &mut blockers,
                Blocker::new("source-inventory-invalid", [("source", alias.to_string())]),
            );
            continue;
        };
        let Some(optional) = inventory_names(&pack.optional) else {
            push_blocker(
                &mut blockers,
                Blocker::new("source-inventory-invalid", [("source", alias.to_string())]),
            );
            continue;
        };
        if !required.is_disjoint(&optional) {
            push_blocker(
                &mut blockers,
                Blocker::new("source-inventory-invalid", [("source", alias.to_string())]),
            );
            continue;
        }
        if !request.exclude.is_subset(&optional) {
            let invalid = request
                .exclude
                .difference(&optional)
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(",");
            push_blocker(
                &mut blockers,
                Blocker::new(
                    "pack-exclusion-invalid",
                    [("pack", pack_name.to_string()), ("members", invalid)],
                ),
            );
            continue;
        }

        let enabled: BTreeSet<_> = optional.difference(&request.exclude).cloned().collect();
        let mut unavailable = BTreeSet::new();
        for name in &required {
            match unique_skill(snapshot, name) {
                Some(skill) => {
                    add_candidate(
                        &mut candidates,
                        name,
                        alias,
                        snapshot,
                        skill,
                        RequestRoot::Pack(pack_name.clone()),
                    );
                    facts.push(PlanFact::PackMember {
                        pack: pack_name.clone(),
                        skill: name.clone(),
                        state: PackMemberState::Required,
                    });
                }
                None => push_blocker(
                    &mut blockers,
                    Blocker::new(
                        "pack-required-missing",
                        [
                            ("source", alias.to_string()),
                            ("pack", pack_name.to_string()),
                            ("skill", name.to_string()),
                        ],
                    ),
                ),
            }
        }
        for name in &optional {
            if request.exclude.contains(name) {
                facts.push(PlanFact::PackMember {
                    pack: pack_name.clone(),
                    skill: name.clone(),
                    state: PackMemberState::Excluded,
                });
            } else if let Some(skill) = unique_skill(snapshot, name) {
                add_candidate(
                    &mut candidates,
                    name,
                    alias,
                    snapshot,
                    skill,
                    RequestRoot::Pack(pack_name.clone()),
                );
                facts.push(PlanFact::PackMember {
                    pack: pack_name.clone(),
                    skill: name.clone(),
                    state: PackMemberState::Enabled,
                });
            } else {
                unavailable.insert(name.clone());
                facts.push(PlanFact::PackMember {
                    pack: pack_name.clone(),
                    skill: name.clone(),
                    state: PackMemberState::Unavailable,
                });
            }
        }
        lock.packs.insert(
            pack_name.clone(),
            LockPack {
                source: alias.clone(),
                required,
                optional,
                enabled,
                unavailable,
            },
        );
        facts.push(PlanFact::ResolvedRoot {
            root: RequestRoot::Pack(pack_name.clone()),
            source: alias.clone(),
        });
        contributing_sources.insert(alias.clone());
    }

    let mut skills = BTreeMap::new();
    for (name, owners) in candidates {
        if owners.len() != 1 {
            push_blocker(
                &mut blockers,
                Blocker::new(
                    "skill-owner-collision",
                    [
                        ("skill", name.to_string()),
                        (
                            "sources",
                            owners
                                .keys()
                                .map(ToString::to_string)
                                .collect::<Vec<_>>()
                                .join(","),
                        ),
                    ],
                ),
            );
            continue;
        }
        let (_, candidate) = owners.into_iter().next().expect("one owner");
        lock.skills.insert(
            name.clone(),
            LockSkill {
                source: candidate.source.clone(),
                path: candidate.path,
                content: candidate.content,
                requested_by: candidate.roots,
            },
        );
        skills.insert(
            name,
            ResolvedSkill {
                source: candidate.source,
                target: candidate.target,
            },
        );
    }

    for alias in contributing_sources {
        let Some(source) = manifest.sources.get(&alias) else {
            continue;
        };
        let Some(snapshot) = snapshots.get(&alias) else {
            continue;
        };
        if let Some(lock_source) = lock_source(source, snapshot) {
            lock.sources.insert(alias.clone(), lock_source);
            facts.push(PlanFact::SourceContribution { source: alias });
        } else {
            push_blocker(
                &mut blockers,
                Blocker::new(
                    "source-snapshot-kind-mismatch",
                    [("source", alias.to_string())],
                ),
            );
        }
    }

    facts.sort();
    facts.dedup();
    blockers.sort();
    blockers.dedup();
    Resolution {
        lock,
        skills,
        blockers,
        facts,
    }
}

fn usable_snapshot<'a>(
    alias: &SourceAlias,
    snapshots: &'a BTreeMap<SourceAlias, SourceSnapshot>,
    blockers: &mut Vec<Blocker>,
) -> Option<&'a SourceSnapshot> {
    let Some(snapshot) = snapshots.get(alias) else {
        push_blocker(
            blockers,
            Blocker::new("source-snapshot-missing", [("source", alias.to_string())]),
        );
        return None;
    };
    if !snapshot.inventory.is_valid()
        || has_duplicate_names(
            snapshot
                .inventory
                .skills
                .iter()
                .map(|skill| skill.name.as_str()),
        )
        || has_duplicate_names(
            snapshot
                .inventory
                .packs
                .iter()
                .map(|pack| pack.name.as_str()),
        )
    {
        push_blocker(
            blockers,
            Blocker::new("source-inventory-invalid", [("source", alias.to_string())]),
        );
        None
    } else {
        Some(snapshot)
    }
}

fn has_duplicate_names<'a>(mut values: impl Iterator<Item = &'a str>) -> bool {
    let mut seen = BTreeSet::new();
    values.any(|value| !seen.insert(value))
}

fn inventory_names(values: &[String]) -> Option<BTreeSet<SkillName>> {
    let mut names = BTreeSet::new();
    for value in values {
        let value = SkillName::new(value).ok()?;
        if !names.insert(value) {
            return None;
        }
    }
    Some(names)
}

fn unique_skill<'a>(
    snapshot: &'a SourceSnapshot,
    name: &SkillName,
) -> Option<&'a grimoire_pack::inventory::Skill> {
    let mut matches = snapshot
        .inventory
        .skills
        .iter()
        .filter(|skill| skill.name == name.as_str());
    let first = matches.next()?;
    matches.next().is_none().then_some(first)
}

fn add_candidate(
    candidates: &mut BTreeMap<SkillName, BTreeMap<SourceAlias, Candidate>>,
    name: &SkillName,
    alias: &SourceAlias,
    snapshot: &SourceSnapshot,
    skill: &grimoire_pack::inventory::Skill,
    root: RequestRoot,
) {
    let owner = candidates
        .entry(name.clone())
        .or_default()
        .entry(alias.clone())
        .or_insert_with(|| Candidate {
            source: alias.clone(),
            path: skill.path.to_string(),
            content: skill.content_digest.to_string(),
            target: snapshot.root.join(skill.path.to_string()),
            roots: BTreeSet::new(),
        });
    owner.roots.insert(root);
}

fn lock_source(source: &crate::ManifestSource, snapshot: &SourceSnapshot) -> Option<LockSource> {
    match (&source.location, snapshot.id.kind) {
        (SourceLocation::Url(declared), SnapshotKind::Git)
        | (SourceLocation::Path(declared), SnapshotKind::Git) => Some(LockSource::Git {
            declared: declared.clone(),
            reference: source.reference.clone(),
            commit: snapshot.id.commit.clone()?,
            tree: snapshot.id.tree.clone()?,
        }),
        (SourceLocation::Path(declared), SnapshotKind::Live) if source.live => {
            Some(LockSource::Live {
                declared: declared.clone(),
            })
        }
        _ => None,
    }
}

fn push_blocker(blockers: &mut Vec<Blocker>, blocker: Blocker) {
    if !blockers.contains(&blocker) {
        blockers.push(blocker);
    }
}
