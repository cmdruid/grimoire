use std::collections::BTreeMap;
use std::path::Path;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;

use crate::{
    resolve_manifest, CheckFinding, CheckReport, CheckSeverity, InstalledLink, LockSource,
    PackMemberState, PlanFact, SnapshotKind, SnapshotStore, SourceKey, TrustMode, TrustReceipt,
    TrustStore, WorldState,
};

pub fn check(world: &WorldState) -> CheckReport {
    let mut findings = world
        .observations
        .iter()
        .map(|observation| CheckFinding {
            code: observation.code.clone(),
            severity: CheckSeverity::Error,
            details: observation.details.clone(),
        })
        .collect::<Vec<_>>();

    if !world.manifest_present && !world.lock_present {
        return report(findings);
    }

    check_resolution(world, &mut findings);
    check_sources(world, &mut findings);
    check_links(world, &mut findings);
    check_context(world, &mut findings);
    report(findings)
}

fn check_resolution(world: &WorldState, findings: &mut Vec<CheckFinding>) {
    let snapshots = if world.locked_states.is_empty() {
        &world.snapshots
    } else {
        // An observed lock must be checked against its own snapshots, not a newer candidate.
        // This is also the same source of truth used by frozen reconciliation.
        return check_locked_resolution(world, findings);
    };
    let resolution = resolve_manifest(&world.manifest, snapshots);
    record_resolution(world, resolution, findings);
}

fn check_locked_resolution(world: &WorldState, findings: &mut Vec<CheckFinding>) {
    let snapshots = world
        .locked_states
        .iter()
        .map(|(alias, state)| (alias.clone(), state.snapshot.clone()))
        .collect();
    let resolution = resolve_manifest(&world.manifest, &snapshots);
    record_resolution(world, resolution, findings);
}

fn record_resolution(
    world: &WorldState,
    resolution: crate::Resolution,
    findings: &mut Vec<CheckFinding>,
) {
    for blocker in resolution.blockers {
        findings.push(finding(
            &blocker.code,
            CheckSeverity::Error,
            blocker.details,
        ));
    }
    if resolution.lock != world.lock {
        findings.push(finding(
            "manifest-lock-mismatch",
            CheckSeverity::Error,
            BTreeMap::new(),
        ));
    }
    for fact in resolution.facts {
        if let PlanFact::PackMember {
            pack,
            skill,
            state: PackMemberState::Unavailable,
        } = fact
        {
            findings.push(finding(
                "optional-member-unavailable",
                CheckSeverity::Warning,
                BTreeMap::from([
                    ("pack".into(), pack.to_string()),
                    ("skill".into(), skill.to_string()),
                ]),
            ));
        }
    }
}

fn check_sources(world: &WorldState, findings: &mut Vec<CheckFinding>) {
    let trust = world
        .trust_bytes
        .as_deref()
        .and_then(|bytes| TrustStore::parse(bytes).ok())
        .unwrap_or_default();

    for (alias, source) in &world.lock.sources {
        let Some(state) = world.locked_states.get(alias) else {
            findings.push(details_finding(
                "locked-source-missing",
                CheckSeverity::Error,
                [("source", alias.to_string())],
            ));
            continue;
        };
        match state.store {
            SnapshotStore::Absent => findings.push(details_finding(
                "store-missing",
                CheckSeverity::Error,
                [("source", alias.to_string())],
            )),
            SnapshotStore::Corrupt => findings.push(details_finding(
                "store-corrupt",
                CheckSeverity::Error,
                [("source", alias.to_string())],
            )),
            SnapshotStore::Valid => {}
        }

        let Some(identity) = state.identity.as_ref() else {
            findings.push(details_finding(
                "source-identity-missing",
                CheckSeverity::Error,
                [("source", alias.to_string())],
            ));
            continue;
        };
        let key = SourceKey::derive(identity);
        let receipt = match &state.snapshot.id.kind {
            SnapshotKind::Git => Some(TrustReceipt {
                commit: state.snapshot.id.commit.clone().unwrap_or_default(),
                tree: state.snapshot.id.tree.clone().unwrap_or_default(),
                inventory: state.snapshot.id.inventory_digest.clone(),
            }),
            SnapshotKind::Live => None,
        };
        let mode = trust
            .records
            .get(&key)
            .map_or(TrustMode::Untrusted, |record| {
                record.mode_for(receipt.as_ref())
            });
        let required = if matches!(source, LockSource::Live { .. }) {
            mode == TrustMode::All
        } else {
            mode != TrustMode::Untrusted
        };
        if !required {
            findings.push(details_finding(
                if matches!(source, LockSource::Live { .. }) {
                    "live-source-requires-all-trust"
                } else {
                    "source-untrusted"
                },
                CheckSeverity::Error,
                [("source", alias.to_string())],
            ));
        }
    }
}

fn check_links(world: &WorldState, findings: &mut Vec<CheckFinding>) {
    for (skill, locked) in &world.lock.skills {
        if !world.lock.sources.contains_key(&locked.source) {
            continue;
        }
        let Some(state) = world.locked_states.get(&locked.source) else {
            continue;
        };
        let target = state
            .identity
            .as_ref()
            .map(|_| state.snapshot.root.join(&locked.path));

        let observed = world.links.get(skill).unwrap_or(&InstalledLink::Absent);
        match (observed, target) {
            (InstalledLink::Absent, _) => findings.push(details_finding(
                "link-missing",
                CheckSeverity::Error,
                [("skill", skill.to_string())],
            )),
            (InstalledLink::Symlink(observed), Some(expected)) if observed == &expected => {}
            (InstalledLink::Symlink(observed), Some(_)) => findings.push(finding(
                "link-drift",
                CheckSeverity::Error,
                link_details(skill.as_str(), observed),
            )),
            (InstalledLink::Symlink(observed), None) => findings.push(finding(
                "foreign-link",
                CheckSeverity::Error,
                link_details(skill.as_str(), observed),
            )),
            (InstalledLink::File, _) => findings.push(details_finding(
                "foreign-file",
                CheckSeverity::Error,
                [("skill", skill.to_string())],
            )),
            (InstalledLink::Directory, _) => findings.push(details_finding(
                "foreign-directory",
                CheckSeverity::Error,
                [("skill", skill.to_string())],
            )),
        }
    }
}

fn check_context(world: &WorldState, findings: &mut Vec<CheckFinding>) {
    for fact in world
        .inherited_global
        .as_ref()
        .into_iter()
        .flat_map(|resolution| &resolution.skills)
    {
        if world.lock.skills.contains_key(fact.0) {
            findings.push(details_finding(
                "global-skill-shadowed",
                CheckSeverity::Warning,
                [("skill", fact.0.to_string())],
            ));
        }
    }
}

fn report(mut findings: Vec<CheckFinding>) -> CheckReport {
    findings.sort();
    findings.dedup();
    CheckReport { findings }
}

fn finding(code: &str, severity: CheckSeverity, details: BTreeMap<String, String>) -> CheckFinding {
    CheckFinding {
        code: code.into(),
        severity,
        details,
    }
}

fn details_finding<const N: usize>(
    code: &str,
    severity: CheckSeverity,
    details: [(&str, String); N],
) -> CheckFinding {
    finding(
        code,
        severity,
        details
            .into_iter()
            .map(|(key, value)| (key.into(), value))
            .collect(),
    )
}

fn link_details(skill: &str, target: &Path) -> BTreeMap<String, String> {
    let mut details = BTreeMap::from([("skill".into(), skill.into())]);
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        match target.as_os_str().to_str() {
            Some(target) => {
                details.insert("target".into(), target.into());
            }
            None => {
                details.insert(
                    "target_bytes_base64".into(),
                    BASE64.encode(target.as_os_str().as_bytes()),
                );
            }
        }
    }
    #[cfg(not(unix))]
    details.insert("target".into(), target.display().to_string());
    details
}
