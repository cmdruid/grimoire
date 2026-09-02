use std::collections::{BTreeMap, BTreeSet};

use grimoire_pack::inventory::SourcePath;

use super::{ReviewExport, ReviewPayload};

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct DiffChange {
    pub path: SourcePath,
    pub kind: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceDiff {
    pub commit_before: Option<String>,
    pub commit_after: Option<String>,
    pub changes: Vec<DiffChange>,
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
        Self {
            commit_before: before_commit,
            commit_after: after_commit,
            changes,
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
