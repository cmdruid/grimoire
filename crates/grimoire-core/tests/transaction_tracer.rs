use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

use grimoire_core::inventory::scan;
use grimoire_core::source::HeldDirectoryReader;
use grimoire_core::{
    apply, Action, ApplyOutcome, Approval, ByteHash, FaultDisposition, LinkPrecondition, Lockfile,
    OwnedLinkTarget, Paths, Plan, Preconditions, Result, Scope, SnapshotKey, SourceKey,
    StorePrecondition, TransactionRuntime,
};
use tempfile::TempDir;

struct Runtime {
    race_path: Option<PathBuf>,
    race_checkpoint: &'static str,
    replace_existing: bool,
    raced: AtomicBool,
}

impl Runtime {
    fn plain() -> Self {
        Self {
            race_path: None,
            race_checkpoint: "",
            replace_existing: false,
            raced: AtomicBool::new(false),
        }
    }

    fn racing(path: PathBuf, checkpoint: &'static str, replace_existing: bool) -> Self {
        Self {
            race_path: Some(path),
            race_checkpoint: checkpoint,
            replace_existing,
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
        if name == self.race_checkpoint && !self.raced.swap(true, Ordering::SeqCst) {
            if let Some(path) = &self.race_path {
                if self.replace_existing {
                    fs::remove_file(path).unwrap();
                }
                fs::write(path, b"foreign\n").unwrap();
            }
        }
        Ok(FaultDisposition::Continue)
    }
}

fn fixture() -> (TempDir, Paths, OwnedLinkTarget, Plan) {
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
    fs::write(
        paths
            .store_path(&source_key, &snapshot_key)
            .join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: one\n---\n",
    )
    .unwrap();
    let inventory =
        scan(&HeldDirectoryReader::open(&paths.store_path(&source_key, &snapshot_key)).unwrap())
            .unwrap();
    let manifest = b"schema = \"grimoire/manifest@3\"\n".to_vec();
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
            candidates: BTreeMap::from([("source".try_into().unwrap(), None)]),
            stores: BTreeMap::from([(
                "source".try_into().unwrap(),
                StorePrecondition {
                    source_key,
                    snapshot_key,
                    inventory: inventory.inventory_digest.to_string(),
                    state: grimoire_core::SnapshotStore::Valid,
                },
            )]),
            trust: None,
            projects: None,
            reachability: None,
            links: BTreeMap::from([("one".try_into().unwrap(), LinkPrecondition::Absent)]),
            vendors: BTreeMap::new(),
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
            candidates: plan.preconditions.candidates.clone(),
            stores: plan.preconditions.stores.clone(),
            trust: None,
            projects: Some(ByteHash::of(&fs::read(paths.projects_path()).unwrap())),
            reachability: None,
            links: BTreeMap::from([(
                "one".try_into().unwrap(),
                LinkPrecondition::Symlink(target.resolve(&paths).unwrap()),
            )]),
            vendors: BTreeMap::new(),
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
    for changed in [
        "manifest",
        "lock",
        "trust",
        "project-index",
        "candidate",
        "link",
        "store",
    ] {
        let (_temporary, paths, target, plan) = fixture();
        match changed {
            "manifest" => fs::write(paths.manifest_path(), b"foreign\n").unwrap(),
            "lock" => fs::write(paths.lock_path(), b"foreign\n").unwrap(),
            "trust" => {
                fs::create_dir_all(paths.trust_path().parent().unwrap()).unwrap();
                fs::write(paths.trust_path(), b"foreign\n").unwrap();
            }
            "project-index" => {
                fs::create_dir_all(paths.projects_path().parent().unwrap()).unwrap();
                fs::write(paths.projects_path(), b"foreign\n").unwrap();
            }
            "candidate" => {
                let alias = "source".try_into().unwrap();
                let candidate = paths.candidate_path(&paths.scope_key(), &alias);
                fs::create_dir_all(candidate.parent().unwrap()).unwrap();
                fs::write(candidate, b"foreign\n").unwrap();
            }
            "link" => {
                fs::create_dir_all(paths.skills_dir()).unwrap();
                fs::write(paths.skills_dir().join("one"), b"foreign\n").unwrap();
            }
            "store" => {
                let OwnedLinkTarget::Stored {
                    source_key,
                    snapshot_key,
                    skill_path,
                } = target
                else {
                    unreachable!()
                };
                fs::write(
                    paths
                        .store_path(&source_key, &snapshot_key)
                        .join(skill_path)
                        .join("SKILL.md"),
                    b"changed\n",
                )
                .unwrap();
            }
            _ => unreachable!(),
        }
        assert!(
            matches!(
                apply(&paths, &plan, Approval::NotRequired, &Runtime::plain()),
                Err(grimoire_core::CoreError::StalePlan(_))
            ),
            "changed precondition: {changed}"
        );
        if changed != "link" {
            assert!(!paths.skills_dir().join("one").exists());
        }
    }
}

#[test]
fn final_link_revalidation_preserves_a_racing_foreign_entry() {
    for checkpoint in ["before-link-ownership", "before-link-mutation"] {
        let (_temporary, paths, _target, plan) = fixture();
        let destination = paths.skills_dir().join("one");
        let runtime = Runtime::racing(destination.clone(), checkpoint, false);
        assert!(matches!(
            apply(&paths, &plan, Approval::NotRequired, &runtime),
            Err(grimoire_core::CoreError::StalePlan(_))
        ));
        assert_eq!(fs::read(destination).unwrap(), b"foreign\n");
        assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
    }
}

#[test]
fn repoint_and_remove_capture_the_owned_link_before_mutating_it() {
    for operation in ["repoint", "remove"] {
        let (_temporary, paths, old, initial) = fixture();
        apply(&paths, &initial, Approval::NotRequired, &Runtime::plain()).unwrap();
        let destination = paths.skills_dir().join("one");
        let action = match operation {
            "repoint" => {
                let new = OwnedLinkTarget::Stored {
                    source_key: SourceKey::parse("3".repeat(64)).unwrap(),
                    snapshot_key: SnapshotKey::parse("4".repeat(64)).unwrap(),
                    skill_path: "skills/one".into(),
                };
                fs::create_dir_all(new.resolve(&paths).unwrap()).unwrap();
                Action::RepointLink {
                    scope: Scope::Project,
                    skill: "one".try_into().unwrap(),
                    before: old.clone(),
                    after: new,
                }
            }
            "remove" => Action::RemoveLink {
                scope: Scope::Project,
                skill: "one".try_into().unwrap(),
                target: old.clone(),
            },
            _ => unreachable!(),
        };
        let plan = Plan {
            actions: vec![action],
            blockers: Vec::new(),
            preconditions: Preconditions {
                manifest: Some(ByteHash::of(&fs::read(paths.manifest_path()).unwrap())),
                lock: Some(ByteHash::of(&fs::read(paths.lock_path()).unwrap())),
                candidates: BTreeMap::new(),
                stores: BTreeMap::new(),
                trust: None,
                projects: Some(ByteHash::of(&fs::read(paths.projects_path()).unwrap())),
                reachability: None,
                links: BTreeMap::from([(
                    "one".try_into().unwrap(),
                    LinkPrecondition::Symlink(old.resolve(&paths).unwrap()),
                )]),
                vendors: BTreeMap::new(),
            },
            facts: Vec::new(),
            exit_class: grimoire_core::ExitClass::Success,
        };
        let runtime = Runtime::racing(destination.clone(), "before-link-mutation", true);

        assert!(
            matches!(
                apply(&paths, &plan, Approval::Granted, &runtime),
                Err(grimoire_core::CoreError::StalePlan(_))
            ),
            "racing foreign entry survived {operation} ownership"
        );
        assert_eq!(fs::read(&destination).unwrap(), b"foreign\n", "{operation}");
    }
}

#[test]
fn a_late_link_race_rolls_back_earlier_owned_changes() {
    let (_temporary, paths, old, initial) = fixture();
    apply(&paths, &initial, Approval::NotRequired, &Runtime::plain()).unwrap();
    let destination = paths.skills_dir().join("one");
    let new = OwnedLinkTarget::Stored {
        source_key: SourceKey::parse("3".repeat(64)).unwrap(),
        snapshot_key: SnapshotKey::parse("4".repeat(64)).unwrap(),
        skill_path: "skills/one".into(),
    };
    fs::create_dir_all(new.resolve(&paths).unwrap()).unwrap();
    let plan = Plan {
        actions: vec![
            Action::CreateLink {
                scope: Scope::Project,
                skill: "two".try_into().unwrap(),
                target: old.clone(),
            },
            Action::RepointLink {
                scope: Scope::Project,
                skill: "one".try_into().unwrap(),
                before: old.clone(),
                after: new,
            },
        ],
        blockers: Vec::new(),
        preconditions: Preconditions {
            manifest: Some(ByteHash::of(&fs::read(paths.manifest_path()).unwrap())),
            lock: Some(ByteHash::of(&fs::read(paths.lock_path()).unwrap())),
            candidates: BTreeMap::new(),
            stores: BTreeMap::new(),
            trust: None,
            projects: Some(ByteHash::of(&fs::read(paths.projects_path()).unwrap())),
            reachability: None,
            links: BTreeMap::from([
                (
                    "one".try_into().unwrap(),
                    LinkPrecondition::Symlink(old.resolve(&paths).unwrap()),
                ),
                ("two".try_into().unwrap(), LinkPrecondition::Absent),
            ]),
            vendors: BTreeMap::new(),
        },
        facts: Vec::new(),
        exit_class: grimoire_core::ExitClass::Success,
    };
    let runtime = Runtime::racing(destination.clone(), "before-link-mutation", true);

    assert!(matches!(
        apply(&paths, &plan, Approval::Granted, &runtime),
        Err(grimoire_core::CoreError::StalePlan(_))
    ));
    assert_eq!(fs::read(&destination).unwrap(), b"foreign\n");
    assert!(!paths.skills_dir().join("two").exists());
    assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
}
