use std::collections::{BTreeMap, BTreeSet};

use grimoire_pack::inventory::SourcePath;

use super::{ReviewExport, ReviewPayload};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct DiffChange {
    pub path: SourcePath,
    pub kind: String,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct FactChange {
    pub fact: String,
    pub kind: String,
    pub before: Option<String>,
    pub after: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceDiff {
    pub commit_before: Option<String>,
    pub commit_after: Option<String>,
    pub changes: Vec<DiffChange>,
    pub fact_changes: Vec<FactChange>,
    pub affected_roots: BTreeSet<String>,
}

impl SourceDiff {
    pub fn between(
        before_commit: Option<String>,
        before: Option<&ReviewExport>,
        after_commit: Option<String>,
        after: &ReviewExport,
        affected_roots: impl IntoIterator<Item = String>,
    ) -> Self {
        let left = before.map(index).unwrap_or_default();
        let right = index(after);
        let mut paths: BTreeSet<_> = left.keys().cloned().collect();
        paths.extend(right.keys().cloned());
        let mut changes = Vec::new();
        for path in paths {
            let kind = match (left.get(&path), right.get(&path)) {
                (None, Some(_)) => Some("added"),
                (Some(_), None) => Some("removed"),
                (Some(left), Some(right)) if left != right => Some("changed"),
                _ => None,
            };
            if let Some(kind) = kind {
                changes.push(DiffChange {
                    path,
                    kind: kind.into(),
                });
            }
        }
        let mut fact_names: BTreeSet<_> = before
            .map(|export| export.facts.values.keys().cloned().collect())
            .unwrap_or_default();
        fact_names.extend(after.facts.values.keys().cloned());
        let fact_changes = fact_names
            .into_iter()
            .filter_map(|fact| {
                let left = before.and_then(|export| export.facts.values.get(&fact));
                let right = after.facts.values.get(&fact);
                let kind = match (left, right) {
                    (None, Some(_)) => "added",
                    (Some(_), None) => "removed",
                    (Some(left), Some(right)) if left != right => "changed",
                    _ => return None,
                };
                Some(FactChange {
                    fact,
                    kind: kind.into(),
                    before: left.map(ToOwned::to_owned),
                    after: right.map(ToOwned::to_owned),
                })
            })
            .collect();
        Self {
            commit_before: before_commit,
            commit_after: after_commit,
            changes,
            fact_changes,
            affected_roots: affected_roots.into_iter().collect(),
        }
    }
}

fn index(export: &ReviewExport) -> BTreeMap<SourcePath, String> {
    export
        .entries
        .iter()
        .map(|entry| {
            let payload = match &entry.payload {
                ReviewPayload::File { size, digest } => {
                    format!("file:{size}:{digest}:{}", entry.mode)
                }
                ReviewPayload::Symlink { target } => format!("link:{target:?}"),
                ReviewPayload::Submodule { commit } => format!("submodule:{commit}"),
            };
            (entry.path.clone(), payload)
        })
        .collect()
}
