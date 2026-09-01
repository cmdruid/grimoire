use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::{
    Blocker, LockSkill, LockSource, Lockfile, Manifest, PlanFact, RequestRoot, SkillName,
    SnapshotKind, SourceAlias, SourceLocation, SourceSnapshot,
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

pub(crate) fn resolve(
    manifest: &Manifest,
    snapshots: &BTreeMap<SourceAlias, SourceSnapshot>,
) -> Resolution {
    let mut lock = Lockfile::default();
    let mut skills = BTreeMap::new();
    let mut blockers = Vec::new();
    let mut facts = Vec::new();

    for (name, alias) in &manifest.skills {
        let root = RequestRoot::Skill(name.clone());
        let Some(snapshot) = snapshots.get(alias) else {
            blockers.push(Blocker::new(
                "source-snapshot-missing",
                [("source", alias.to_string()), ("skill", name.to_string())],
            ));
            continue;
        };
        if !snapshot.inventory.is_valid() {
            blockers.push(Blocker::new(
                "source-inventory-invalid",
                [("source", alias.to_string())],
            ));
            continue;
        }
        let Some(skill) = snapshot
            .inventory
            .skills
            .iter()
            .find(|skill| skill.name == name.as_str())
        else {
            blockers.push(Blocker::new(
                "skill-missing",
                [("source", alias.to_string()), ("skill", name.to_string())],
            ));
            continue;
        };
        let Some(source) = manifest.sources.get(alias) else {
            continue;
        };
        let lock_source = match (&source.location, snapshot.id.kind) {
            (SourceLocation::Url(declared), SnapshotKind::Git)
            | (SourceLocation::Path(declared), SnapshotKind::Git) => LockSource::Git {
                declared: declared.clone(),
                reference: source.reference.clone(),
                commit: snapshot.id.commit.clone().unwrap_or_default(),
                tree: snapshot.id.tree.clone().unwrap_or_default(),
            },
            (SourceLocation::Path(declared), SnapshotKind::Live) if source.live => {
                LockSource::Live {
                    declared: declared.clone(),
                }
            }
            _ => {
                blockers.push(Blocker::new(
                    "source-snapshot-kind-mismatch",
                    [("source", alias.to_string())],
                ));
                continue;
            }
        };
        lock.sources.insert(alias.clone(), lock_source);
        lock.skills.insert(
            name.clone(),
            LockSkill {
                source: alias.clone(),
                path: skill.path.to_string(),
                content: skill.content_digest.to_string(),
                requested_by: BTreeSet::from([root.clone()]),
            },
        );
        skills.insert(
            name.clone(),
            ResolvedSkill {
                source: alias.clone(),
                target: snapshot.root.join(skill.path.to_string()),
            },
        );
        facts.push(PlanFact::ResolvedRoot {
            root,
            source: alias.clone(),
        });
    }
    facts.sort();
    blockers.sort();
    Resolution {
        lock,
        skills,
        blockers,
        facts,
    }
}
