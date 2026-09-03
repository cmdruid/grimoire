use std::collections::BTreeMap;
use std::fs;
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::Mutex;
use std::time::Duration;

use grimoire_core::{
    apply, observe_reachability, plan, Action, Approval, FaultDisposition, Lockfile, Paths, Plan,
    PlanningMode, Preconditions, ProjectReference, Request, Result, Scope, SnapshotKey, SourceKey,
    TransactionRuntime, TrustChange, TrustStore, WorldState,
};

struct PausingRuntime {
    arrived: Sender<&'static str>,
    release: Mutex<Receiver<()>>,
    nonce: &'static str,
}

impl TransactionRuntime for PausingRuntime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok(self.nonce.into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name == "journal-created" {
            self.arrived.send(name).unwrap();
            self.release.lock().unwrap().recv().unwrap();
        }
        Ok(FaultDisposition::Continue)
    }
}

struct Runtime(&'static str);

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok(self.0.into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

struct PausingPruneRuntime {
    arrived: Sender<()>,
    release: Mutex<Receiver<()>>,
}

impl TransactionRuntime for PausingPruneRuntime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("prune-concurrency".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name == "before-prune-snapshot" {
            self.arrived.send(()).unwrap();
            self.release.lock().unwrap().recv().unwrap();
        }
        Ok(FaultDisposition::Continue)
    }
}

fn initialize(scope: Scope) -> Plan {
    Plan {
        actions: vec![
            Action::CreateManifest {
                scope,
                after: b"schema = \"grimoire/manifest@2\"\n".to_vec(),
            },
            Action::CreateLock {
                scope,
                after: Lockfile::default().to_bytes().unwrap(),
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
            reachability: None,
            links: BTreeMap::new(),
            vendors: BTreeMap::new(),
        },
        facts: Vec::new(),
        exit_class: grimoire_core::ExitClass::Success,
    }
}

#[test]
fn project_and_global_transactions_overlap_under_shared_custody() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let user = root.join("user");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&user).unwrap();
    let project_paths = Paths::project(project, home.clone()).unwrap();
    let global_paths = Paths::global(user, home).unwrap();
    let (arrived_tx, arrived_rx) = mpsc::channel();
    let (project_release_tx, project_release_rx) = mpsc::channel();
    let (global_release_tx, global_release_rx) = mpsc::channel();
    let project_arrived_tx = arrived_tx.clone();

    let project = std::thread::spawn(move || {
        apply(
            &project_paths,
            &initialize(Scope::Project),
            Approval::NotRequired,
            &PausingRuntime {
                arrived: project_arrived_tx,
                release: Mutex::new(project_release_rx),
                nonce: "project-overlap",
            },
        )
    });
    arrived_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    let global = std::thread::spawn(move || {
        apply(
            &global_paths,
            &initialize(Scope::Global),
            Approval::NotRequired,
            &PausingRuntime {
                arrived: arrived_tx,
                release: Mutex::new(global_release_rx),
                nonce: "global-overlap",
            },
        )
    });
    arrived_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    project_release_tx.send(()).unwrap();
    global_release_tx.send(()).unwrap();
    project.join().unwrap().unwrap();
    global.join().unwrap().unwrap();
}

#[test]
fn same_scope_transactions_serialize_and_the_waiter_revalidates() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    let paths = Paths::project(project, home).unwrap();
    let first_paths = paths.clone();
    let second_paths = paths.clone();
    let plan = initialize(Scope::Project);
    let second_plan = plan.clone();
    let (arrived_tx, arrived_rx) = mpsc::channel();
    let (release_tx, release_rx) = mpsc::channel();

    let first = std::thread::spawn(move || {
        apply(
            &first_paths,
            &plan,
            Approval::NotRequired,
            &PausingRuntime {
                arrived: arrived_tx,
                release: Mutex::new(release_rx),
                nonce: "scope-first",
            },
        )
    });
    arrived_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    let second = std::thread::spawn(move || {
        apply(
            &second_paths,
            &second_plan,
            Approval::NotRequired,
            &Runtime("scope-second"),
        )
    });
    std::thread::sleep(Duration::from_millis(100));
    assert!(!second.is_finished());
    release_tx.send(()).unwrap();
    first.join().unwrap().unwrap();
    assert!(matches!(
        second.join().unwrap(),
        Err(grimoire_core::CoreError::StalePlan(_))
    ));
}

#[test]
fn trust_writes_wait_for_an_apply_shared_lease() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let user = root.join("user");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&user).unwrap();
    let project_paths = Paths::project(project, home.clone()).unwrap();
    let trust_paths = Paths::global(user, home).unwrap();
    let (arrived_tx, arrived_rx) = mpsc::channel();
    let (release_tx, release_rx) = mpsc::channel();

    let project = std::thread::spawn(move || {
        apply(
            &project_paths,
            &initialize(Scope::Project),
            Approval::NotRequired,
            &PausingRuntime {
                arrived: arrived_tx,
                release: Mutex::new(release_rx),
                nonce: "trust-project",
            },
        )
    });
    arrived_rx.recv_timeout(Duration::from_secs(2)).unwrap();

    let trust = std::thread::spawn(move || {
        let plan = Plan {
            actions: vec![Action::ReplaceTrust {
                before: None,
                after: TrustStore::default().to_bytes().unwrap(),
                create_mode: 0o600,
                change: TrustChange::GrantAll,
            }],
            blockers: Vec::new(),
            preconditions: Preconditions::absent(),
            facts: Vec::new(),
            exit_class: grimoire_core::ExitClass::Success,
        };
        apply(
            &trust_paths,
            &plan,
            Approval::NotRequired,
            &Runtime("trust-writer"),
        )
    });
    std::thread::sleep(Duration::from_millis(100));
    assert!(!trust.is_finished());
    release_tx.send(()).unwrap();
    project.join().unwrap().unwrap();
    trust.join().unwrap().unwrap();
}

#[test]
fn apply_waits_while_prune_holds_exclusive_store_custody() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let user = root.join("user");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&user).unwrap();
    let paths = Paths::global(user, home).unwrap();
    let reference = ProjectReference {
        source_key: SourceKey::parse("a".repeat(64)).unwrap(),
        snapshot_key: SnapshotKey::parse("b".repeat(64)).unwrap(),
    };
    let snapshot = paths.store_path(&reference.source_key, &reference.snapshot_key);
    fs::create_dir_all(snapshot.join("skill")).unwrap();
    fs::write(
        snapshot.join("skill/SKILL.md"),
        b"---\nname: held\ndescription: held\n---\n",
    )
    .unwrap();
    let observation = observe_reachability(&paths, &[], &Runtime("observe-prune")).unwrap();
    let prune_plan = plan(
        &WorldState::absent(
            Scope::Global,
            [],
            std::iter::empty::<(&str, grimoire_core::InstalledLink)>(),
            None,
        )
        .unwrap()
        .with_reachability(observation),
        Request::Prune,
        PlanningMode::Normal,
    )
    .unwrap();
    let prune_paths = paths.clone();
    let apply_paths = paths.clone();
    let (arrived_tx, arrived_rx) = mpsc::channel();
    let (release_tx, release_rx) = mpsc::channel();
    let prune = std::thread::spawn(move || {
        apply(
            &prune_paths,
            &prune_plan,
            Approval::Granted,
            &PausingPruneRuntime {
                arrived: arrived_tx,
                release: Mutex::new(release_rx),
            },
        )
    });
    arrived_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    let scope_apply = std::thread::spawn(move || {
        apply(
            &apply_paths,
            &initialize(Scope::Global),
            Approval::NotRequired,
            &Runtime("apply-after-prune"),
        )
    });
    std::thread::sleep(Duration::from_millis(100));
    assert!(!scope_apply.is_finished());
    release_tx.send(()).unwrap();
    prune.join().unwrap().unwrap();
    scope_apply.join().unwrap().unwrap();
}
