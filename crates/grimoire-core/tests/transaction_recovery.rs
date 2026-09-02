use std::collections::BTreeMap;
use std::fs;
use std::sync::atomic::{AtomicUsize, Ordering};

use grimoire_core::{
    apply, recover, Action, ApplyOutcome, Approval, ByteHash, CandidateRecord, CanonicalIdentity,
    FaultDisposition, LinkPrecondition, Lockfile, ManifestChange, OwnedLinkTarget, Paths, Plan,
    Preconditions, RecoveryDisposition, Result, Scope, SnapshotKey, SourceAlias, SourceKey,
    TransactionRuntime, TrustBaseline, TrustReceipt, TrustStore,
};

struct CrashAt {
    name: &'static str,
    occurrence: usize,
    seen: AtomicUsize,
}

impl CrashAt {
    fn new(name: &'static str, occurrence: usize) -> Self {
        Self {
            name,
            occurrence,
            seen: AtomicUsize::new(0),
        }
    }
}

impl TransactionRuntime for CrashAt {
    fn transaction_nonce(&self) -> Result<String> {
        Ok(format!("recovery-{}-{}", self.name, self.occurrence))
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name != self.name {
            return Ok(FaultDisposition::Continue);
        }
        let occurrence = self.seen.fetch_add(1, Ordering::SeqCst) + 1;
        Ok(if occurrence == self.occurrence {
            FaultDisposition::Crash
        } else {
            FaultDisposition::Continue
        })
    }
}

struct Continue;

impl TransactionRuntime for Continue {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("recovery-continue".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

fn fixture() -> (tempfile::TempDir, Paths, OwnedLinkTarget, Plan) {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    fs::create_dir_all(&project).unwrap();
    let paths = Paths::project(project, home).unwrap();
    let source_key = SourceKey::parse("1".repeat(64)).unwrap();
    let snapshot_key = SnapshotKey::parse("2".repeat(64)).unwrap();
    let target = OwnedLinkTarget::Stored {
        source_key: source_key.clone(),
        snapshot_key: snapshot_key.clone(),
        skill_path: "skills/one".into(),
    };
    fs::create_dir_all(
        paths
            .store_path(&source_key, &snapshot_key)
            .join("skills/one"),
    )
    .unwrap();
    let manifest = b"schema = \"grimoire/manifest@1\"\n".to_vec();
    let lock = Lockfile::default().to_bytes().unwrap();
    let plan = Plan {
        actions: vec![
            Action::CreateManifest {
                scope: Scope::Project,
                after: manifest,
            },
            Action::CreateLock {
                scope: Scope::Project,
                after: lock,
            },
            Action::CreateLink {
                scope: Scope::Project,
                skill: "one".try_into().unwrap(),
                target: target.clone(),
            },
        ],
        blockers: Vec::new(),
        preconditions: Preconditions {
            manifest: None,
            lock: None,
            candidates: BTreeMap::new(),
            stores: BTreeMap::new(),
            trust: None,
            links: BTreeMap::from([("one".try_into().unwrap(), LinkPrecondition::Absent)]),
        },
        facts: Vec::new(),
        exit_class: grimoire_core::ExitClass::Success,
    };
    (temporary, paths, target, plan)
}

#[test]
fn every_scope_fault_prefix_recovers_to_exact_before_or_complete_after() {
    let cases = [
        ("journal-created", 1, false),
        ("before-link-ownership", 1, false),
        ("before-link-mutation", 1, false),
        ("after-link-mutation", 1, false),
        ("action-marked", 1, false),
        ("before-state-mutation", 1, false),
        ("after-state-mutation", 1, false),
        ("action-marked", 2, false),
        ("before-state-mutation", 2, false),
        ("after-state-mutation", 2, true),
        ("action-marked", 3, true),
        ("before-commit-marker", 1, true),
        ("committed", 1, true),
        ("before-cleanup", 1, true),
    ];
    for (checkpoint, occurrence, forward) in cases {
        let (_temporary, paths, target, plan) = fixture();
        let crashed = apply(
            &paths,
            &plan,
            Approval::NotRequired,
            &CrashAt::new(checkpoint, occurrence),
        )
        .unwrap();
        assert!(matches!(crashed, ApplyOutcome::Interrupted { .. }));
        assert!(paths.transaction_journal_path(&paths.scope_key()).exists());

        let recovered = recover(&paths, &Continue).unwrap();
        assert_eq!(recovered.dispositions.len(), 1, "{checkpoint}/{occurrence}");
        assert_eq!(
            matches!(
                recovered.dispositions[0],
                RecoveryDisposition::RolledForward { .. }
            ),
            forward,
            "{checkpoint}/{occurrence}"
        );
        if forward {
            assert!(paths.manifest_path().is_file());
            assert!(paths.lock_path().is_file());
            assert_eq!(
                fs::read_link(paths.skills_dir().join("one")).unwrap(),
                target.resolve(&paths).unwrap()
            );
        } else {
            assert!(!paths.manifest_path().exists());
            assert!(!paths.lock_path().exists());
            assert!(!paths.skills_dir().join("one").exists());
        }
        assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
        assert!(recover(&paths, &Continue).unwrap().dispositions.is_empty());
    }
}

#[test]
fn source_registration_never_recovers_trust_without_manifest_and_candidate() {
    for (occurrence, forward) in [(1, false), (2, false), (3, true)] {
        let temporary = tempfile::tempdir().unwrap();
        let root = temporary.path().canonicalize().unwrap();
        let project = root.join("project");
        fs::create_dir_all(&project).unwrap();
        let paths = Paths::project(project, root.join("home")).unwrap();
        let before_manifest = b"schema = \"grimoire/manifest@1\"\n".to_vec();
        let after_manifest = concat!(
            "schema = \"grimoire/manifest@1\"\n",
            "[sources.a]\nurl = \"github:org/a\"\nref = \"main\"\n"
        )
        .as_bytes()
        .to_vec();
        let lock = Lockfile::default().to_bytes().unwrap();
        fs::write(paths.manifest_path(), &before_manifest).unwrap();
        fs::write(paths.lock_path(), &lock).unwrap();
        let identity = CanonicalIdentity::remote("github:org/a").unwrap();
        let source_key = SourceKey::derive(&identity);
        let candidate = CandidateRecord::new(
            "0".repeat(64),
            identity.clone(),
            Some("1".repeat(40)),
            Some("2".repeat(40)),
            format!("sha256:{}", "3".repeat(64)),
            format!("sha256:{}", "4".repeat(64)),
        )
        .unwrap()
        .to_bytes()
        .unwrap();
        let trust = TrustStore::default()
            .grant_all(
                identity,
                Some(TrustReceipt {
                    commit: "1".repeat(40),
                    tree: "2".repeat(40),
                    inventory: format!("sha256:{}", "3".repeat(64)),
                }),
                TrustBaseline {
                    commit: Some("1".repeat(40)),
                    tree: Some("2".repeat(40)),
                    inventory: format!("sha256:{}", "3".repeat(64)),
                    review_tree: format!("sha256:{}", "4".repeat(64)),
                },
                None,
            )
            .unwrap()
            .after;
        let alias = SourceAlias::new("a").unwrap();
        let plan = Plan {
            actions: vec![
                Action::ReplaceManifest {
                    scope: Scope::Project,
                    before: before_manifest.clone(),
                    after: after_manifest.clone(),
                    change: ManifestChange::AddSource,
                },
                Action::ReplaceCandidate {
                    scope: Scope::Project,
                    alias: alias.clone(),
                    source_key: source_key.clone(),
                    before: None,
                    after: candidate.clone(),
                },
                Action::ReplaceTrust {
                    before: None,
                    after: trust.clone(),
                    create_mode: 0o600,
                    change: grimoire_core::TrustChange::GrantAll,
                },
            ],
            blockers: Vec::new(),
            preconditions: Preconditions {
                manifest: Some(ByteHash::of(&before_manifest)),
                lock: Some(ByteHash::of(&lock)),
                candidates: BTreeMap::from([(alias.clone(), None)]),
                stores: BTreeMap::new(),
                trust: None,
                links: BTreeMap::new(),
            },
            facts: Vec::new(),
            exit_class: grimoire_core::ExitClass::Success,
        };
        assert!(matches!(
            apply(
                &paths,
                &plan,
                Approval::NotRequired,
                &CrashAt::new("after-state-mutation", occurrence),
            )
            .unwrap(),
            ApplyOutcome::Interrupted { .. }
        ));
        if paths.trust_path().exists() {
            assert_eq!(fs::read(paths.manifest_path()).unwrap(), after_manifest);
            assert!(paths.candidate_path(&paths.scope_key(), &alias).exists());
        }
        let outcome = recover(&paths, &Continue).unwrap();
        assert_eq!(
            matches!(
                outcome.dispositions.as_slice(),
                [RecoveryDisposition::RolledForward { .. }]
            ),
            forward
        );
        assert_eq!(paths.trust_path().exists(), forward);
        assert_eq!(
            paths.candidate_path(&paths.scope_key(), &alias).exists(),
            forward
        );
        assert_eq!(
            fs::read(paths.manifest_path()).unwrap(),
            if forward {
                after_manifest
            } else {
                before_manifest
            }
        );
    }
}

#[test]
fn tampered_journal_identity_cannot_nominate_an_outside_path() {
    let (temporary, paths, _target, plan) = fixture();
    let outside = temporary.path().join("outside");
    fs::write(&outside, b"canary\n").unwrap();
    apply(
        &paths,
        &plan,
        Approval::NotRequired,
        &CrashAt::new("journal-created", 1),
    )
    .unwrap();
    let journal_path = paths.transaction_journal_path(&paths.scope_key());
    let mut value: serde_json::Value =
        serde_json::from_slice(&fs::read(&journal_path).unwrap()).unwrap();
    value["links"][0]["skill"] = serde_json::Value::String("../../outside".into());
    fs::write(&journal_path, serde_json::to_vec_pretty(&value).unwrap()).unwrap();
    assert!(recover(&paths, &Continue).is_err());
    assert_eq!(fs::read(outside).unwrap(), b"canary\n");
}
