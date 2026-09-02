use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

use grimoire_core::{
    apply, Action, ApplyOutcome, Approval, ByteHash, FaultDisposition, LinkPrecondition, Lockfile,
    OwnedLinkTarget, Paths, Plan, Preconditions, Result, Scope, SnapshotKey, SourceKey,
    TransactionRuntime,
};
use tempfile::TempDir;

struct Runtime {
    race_path: Option<PathBuf>,
    raced: AtomicBool,
}

impl Runtime {
    fn plain() -> Self {
        Self {
            race_path: None,
            raced: AtomicBool::new(false),
        }
    }

    fn racing(path: PathBuf) -> Self {
        Self {
            race_path: Some(path),
            raced: AtomicBool::new(false),
        }
    }
}

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("transaction-tracer".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name == "before-link-ownership" && !self.raced.swap(true, Ordering::SeqCst) {
            if let Some(path) = &self.race_path {
                fs::write(path, b"foreign\n").unwrap();
            }
        }
        Ok(FaultDisposition::Continue)
    }
}

fn fixture() -> (TempDir, Paths, OwnedLinkTarget, Plan) {
    let temporary = tempfile::tempdir().unwrap();
    let project = temporary.path().join("project");
    let home = temporary.path().join("home");
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
    fs::write(
        paths
            .store_path(&source_key, &snapshot_key)
            .join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: one\n---\n",
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
            projects: None,
            links: BTreeMap::from([("one".try_into().unwrap(), LinkPrecondition::Absent)]),
        },
        facts: Vec::new(),
        exit_class: grimoire_core::ExitClass::Success,
    };
    (temporary, paths, target, plan)
}

#[test]
fn one_direct_skill_crosses_the_transaction_boundary() {
    let (_temporary, paths, target, plan) = fixture();
    assert_eq!(
        apply(&paths, &plan, Approval::NotRequired, &Runtime::plain()).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );
    assert_eq!(
        fs::read_link(paths.skills_dir().join("one")).unwrap(),
        target.resolve(&paths).unwrap()
    );
    assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());

    let settled = Plan {
        actions: vec![Action::RetainLink {
            scope: Scope::Project,
            skill: "one".try_into().unwrap(),
            target: target.clone(),
        }],
        blockers: Vec::new(),
        preconditions: Preconditions {
            manifest: Some(ByteHash::of(&fs::read(paths.manifest_path()).unwrap())),
            lock: Some(ByteHash::of(&fs::read(paths.lock_path()).unwrap())),
            candidates: BTreeMap::new(),
            stores: BTreeMap::new(),
            trust: None,
            projects: Some(ByteHash::of(&fs::read(paths.projects_path()).unwrap())),
            links: BTreeMap::from([(
                "one".try_into().unwrap(),
                LinkPrecondition::Symlink(target.resolve(&paths).unwrap()),
            )]),
        },
        facts: Vec::new(),
        exit_class: grimoire_core::ExitClass::Success,
    };
    assert_eq!(
        apply(&paths, &settled, Approval::NotRequired, &Runtime::plain()).unwrap(),
        ApplyOutcome::Applied { changed: false }
    );
}

#[test]
fn stale_and_foreign_state_are_inert() {
    let (_temporary, paths, _target, plan) = fixture();
    fs::write(paths.manifest_path(), b"foreign\n").unwrap();
    assert!(matches!(
        apply(&paths, &plan, Approval::NotRequired, &Runtime::plain()),
        Err(grimoire_core::CoreError::StalePlan(_))
    ));
    assert!(!paths.skills_dir().join("one").exists());
}

#[test]
fn final_link_revalidation_preserves_a_racing_foreign_entry() {
    let (_temporary, paths, _target, plan) = fixture();
    let destination = paths.skills_dir().join("one");
    let runtime = Runtime::racing(destination.clone());
    assert!(matches!(
        apply(&paths, &plan, Approval::NotRequired, &runtime),
        Err(grimoire_core::CoreError::StalePlan(_))
    ));
    assert_eq!(fs::read(destination).unwrap(), b"foreign\n");
    assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
}
