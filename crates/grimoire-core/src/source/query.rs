use std::collections::BTreeSet;
use std::path::PathBuf;

use super::{
    fetch_source, inspect_live_source, inspect_pinned_source, CandidateRecord, GitRunner,
    ReviewExport, ReviewKey, SourceDiff, SourceInfo, SourceKind,
};
use crate::{
    CoreError, Paths, RequestRoot, Result, SnapshotKind, SourceAlias, SourceLocation, TrustMode,
    TrustReceipt, TrustStore, WorldState,
};

const QUERY_FILE_LIMIT: u64 = 16 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceSummary {
    pub alias: SourceAlias,
    pub declared: String,
    pub requested_ref: Option<String>,
    pub live: bool,
    pub locked_commit: Option<String>,
    pub candidate_commit: Option<String>,
    pub candidate_current: bool,
    pub trust: TrustMode,
    pub has_findings: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct TrustUse {
    pub scope: String,
    pub alias: SourceAlias,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrustSummary {
    pub source_key: super::SourceKey,
    pub identity: super::CanonicalIdentity,
    pub receipts: BTreeSet<TrustReceipt>,
    pub all_snapshots: bool,
    pub baseline: Option<crate::TrustBaseline>,
    pub uses: BTreeSet<TrustUse>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TrustCatalog {
    pub records: Vec<TrustSummary>,
    pub findings: Vec<String>,
}

pub fn refresh_source(
    paths: Paths,
    alias: SourceAlias,
    runner: &dyn GitRunner,
) -> Result<SourceInfo> {
    let manifest =
        crate::Manifest::parse(std::fs::read(paths.manifest_path()).map_err(|error| {
            CoreError::Io {
                path: paths.manifest_path().display().to_string(),
                message: error.to_string(),
            }
        })?)?;
    let source = manifest
        .sources
        .get(&alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` is not declared")))?;
    match (&source.location, source.live) {
        (SourceLocation::Url(_), false) => fetch_source(paths, alias, runner),
        (SourceLocation::Path(_), true) => inspect_live_source(paths, alias),
        (SourceLocation::Path(_), false) => inspect_pinned_source(paths, alias, runner),
        (SourceLocation::Url(_), true) => Err(CoreError::Source(
            "remote source cannot be refreshed as live".into(),
        )),
    }
}

pub fn source_info(paths: &Paths, world: &WorldState, alias: &SourceAlias) -> Result<SourceInfo> {
    let source = world
        .manifest
        .sources
        .get(alias)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` is not declared")))?;
    let state = world
        .candidates
        .get(alias)
        .filter(|state| state.candidate_current)
        .ok_or_else(|| {
            CoreError::Source(format!(
                "source `{alias}` has no current candidate; run `grimoire source fetch {alias}`"
            ))
        })?;
    let bytes = state
        .candidate_bytes
        .as_deref()
        .ok_or_else(|| CoreError::Source("candidate observation lacks exact bytes".into()))?;
    let candidate = CandidateRecord::parse(bytes, None)?;
    if state.identity.as_ref() != Some(&candidate.identity)
        || state.snapshot.id.commit != candidate.commit
        || state.snapshot.id.tree != candidate.tree
        || state.snapshot.id.inventory_digest != candidate.inventory
        || state.review_tree.as_deref() != Some(candidate.review_tree.as_str())
    {
        return Err(CoreError::Source(
            "candidate bytes disagree with the observed source".into(),
        ));
    }
    let export = ReviewExport::load_for_keys(
        &paths.review_cache_dir(),
        &candidate.source_key(),
        &candidate.review_key()?,
    )?;
    let trust_store = world
        .trust_bytes
        .as_deref()
        .map(TrustStore::parse)
        .transpose()?
        .unwrap_or_default();
    let record = trust_store.records.get(&candidate.source_key());
    let receipt = candidate_receipt(&candidate);
    let trust = record.map_or(TrustMode::Untrusted, |record| {
        record.mode_for(receipt.as_ref())
    });
    Ok(SourceInfo::from_candidate(
        alias.clone(),
        source.declared().into(),
        source.reference.clone(),
        candidate,
        state.snapshot.inventory.clone(),
        export,
        trust,
        record.and_then(|record| record.baseline.clone()),
    ))
}

pub fn source_diff(paths: &Paths, world: &WorldState, alias: &SourceAlias) -> Result<SourceDiff> {
    let info = source_info(paths, world, alias)?;
    let before = info
        .baseline
        .as_ref()
        .map(|baseline| {
            let key = ReviewKey::derive(
                info.candidate.identity.kind(),
                baseline.commit.as_deref(),
                baseline.tree.as_deref(),
                &baseline.inventory,
                &baseline.review_tree,
            )?;
            ReviewExport::load_for_keys(
                &paths.review_cache_dir(),
                &info.candidate.source_key(),
                &key,
            )
        })
        .transpose()?;
    Ok(SourceDiff::between(
        info.baseline
            .as_ref()
            .and_then(|baseline| baseline.commit.clone()),
        before.as_ref(),
        info.candidate.commit.clone(),
        &info.export,
        affected_roots(world, alias),
    ))
}

pub fn source_summaries(world: &WorldState) -> Result<Vec<SourceSummary>> {
    let trust_store = world
        .trust_bytes
        .as_deref()
        .map(TrustStore::parse)
        .transpose()?
        .unwrap_or_default();
    world
        .manifest
        .sources
        .iter()
        .map(|(alias, source)| {
            let candidate = world.candidates.get(alias);
            let identity = candidate
                .and_then(|state| state.identity.as_ref())
                .or_else(|| {
                    world
                        .locked_states
                        .get(alias)
                        .and_then(|state| state.identity.as_ref())
                });
            let receipt = candidate.and_then(|state| state_receipt(state));
            let trust = identity
                .and_then(|identity| trust_store.records.get(&super::SourceKey::derive(identity)))
                .map_or(TrustMode::Untrusted, |record| {
                    record.mode_for(receipt.as_ref())
                });
            Ok(SourceSummary {
                alias: alias.clone(),
                declared: source.declared().into(),
                requested_ref: source.reference.clone(),
                live: source.live,
                locked_commit: world
                    .locked_states
                    .get(alias)
                    .and_then(|state| state.snapshot.id.commit.clone()),
                candidate_commit: candidate.and_then(|state| state.snapshot.id.commit.clone()),
                candidate_current: candidate.is_some_and(|state| state.candidate_current),
                trust,
                has_findings: candidate
                    .or_else(|| world.locked_states.get(alias))
                    .is_some_and(|state| !state.snapshot.inventory.findings.is_empty()),
            })
        })
        .collect()
}

pub fn source_key_for_alias(world: &WorldState, alias: &SourceAlias) -> Result<super::SourceKey> {
    world
        .candidates
        .get(alias)
        .or_else(|| world.locked_states.get(alias))
        .and_then(|state| state.identity.as_ref())
        .map(super::SourceKey::derive)
        .ok_or_else(|| CoreError::Source(format!("source `{alias}` has no observed identity")))
}

pub fn load_trust_world(paths: &Paths) -> Result<WorldState> {
    if !matches!(paths.scope, crate::ScopePaths::Global { .. }) {
        return Err(CoreError::Request(
            "identity trust requires global resolved paths".into(),
        ));
    }
    let mut world = WorldState::absent(crate::Scope::Global, [], [], None)?;
    world.trust_bytes = read_optional_bounded(&paths.trust_path())?;
    if let Some(bytes) = world.trust_bytes.as_deref() {
        TrustStore::parse(bytes)?;
    }
    Ok(world)
}

pub fn trust_catalog(paths: &Paths) -> Result<TrustCatalog> {
    let world = load_trust_world(paths)?;
    let store = world
        .trust_bytes
        .as_deref()
        .map(TrustStore::parse)
        .transpose()?
        .unwrap_or_default();
    let mut records = store
        .records
        .iter()
        .map(|(source_key, record)| TrustSummary {
            source_key: source_key.clone(),
            identity: record.identity.clone(),
            receipts: record.receipts.clone(),
            all_snapshots: record.all_snapshots,
            baseline: record.baseline.clone(),
            uses: BTreeSet::new(),
        })
        .collect::<Vec<_>>();
    let mut findings = Vec::new();
    let mut scopes = vec![("global".into(), paths.clone())];
    if let Some(bytes) = read_optional_bounded(&paths.projects_path())? {
        match crate::ProjectIndex::parse(&bytes) {
            Ok(index) => {
                scopes.extend(index.records.values().filter_map(|record| {
                    Paths::project(record.path.clone(), paths.grimoire_home.clone())
                        .ok()
                        .map(|project| (format!("project:{}", record.path.display()), project))
                }));
            }
            Err(error) => findings.push(format!("project-index: {error}")),
        }
    }
    for (scope, scope_paths) in scopes {
        let Some(bytes) = read_optional_bounded(&scope_paths.manifest_path())? else {
            continue;
        };
        let manifest = match crate::Manifest::parse(bytes) {
            Ok(manifest) => manifest,
            Err(error) => {
                findings.push(format!("{scope}: {error}"));
                continue;
            }
        };
        for alias in manifest.sources.keys() {
            match crate::world::declaration_identity(&scope_paths, &manifest, alias) {
                Ok(identity) => {
                    let key = super::SourceKey::derive(&identity);
                    if let Some(summary) = records.iter_mut().find(|item| item.source_key == key) {
                        summary.uses.insert(TrustUse {
                            scope: scope.clone(),
                            alias: alias.clone(),
                        });
                    }
                }
                Err(error) => findings.push(format!("{scope}/{alias}: {error}")),
            }
        }
    }
    Ok(TrustCatalog { records, findings })
}

fn candidate_receipt(candidate: &CandidateRecord) -> Option<TrustReceipt> {
    (candidate.identity.kind() == SourceKind::Git).then(|| TrustReceipt {
        commit: candidate.commit.clone().expect("validated Git candidate"),
        tree: candidate.tree.clone().expect("validated Git candidate"),
        inventory: candidate.inventory.clone(),
    })
}

fn state_receipt(state: &crate::SourceState) -> Option<TrustReceipt> {
    (state.snapshot.id.kind == SnapshotKind::Git).then(|| TrustReceipt {
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
    })
}

fn affected_roots(world: &WorldState, alias: &SourceAlias) -> BTreeSet<String> {
    let mut roots = world
        .manifest
        .skills
        .iter()
        .filter(|(_, source)| *source == alias)
        .map(|(name, _)| RequestRoot::Skill(name.clone()).lock_value())
        .collect::<BTreeSet<_>>();
    roots.extend(
        world
            .manifest
            .packs
            .iter()
            .filter(|(_, request)| &request.source == alias)
            .map(|(name, _)| RequestRoot::Pack(name.clone()).lock_value()),
    );
    roots
}

fn read_optional_bounded(path: &PathBuf) -> Result<Option<Vec<u8>>> {
    let metadata = match std::fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => {
            return Err(CoreError::Io {
                path: path.display().to_string(),
                message: error.to_string(),
            })
        }
    };
    if !metadata.file_type().is_file() || metadata.len() > QUERY_FILE_LIMIT {
        return Err(CoreError::Request(format!(
            "query state is not a bounded regular file: {}",
            path.display()
        )));
    }
    std::fs::read(path)
        .map(Some)
        .map_err(|error| CoreError::Io {
            path: path.display().to_string(),
            message: error.to_string(),
        })
}
