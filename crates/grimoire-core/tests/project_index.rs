use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::sync::atomic::{AtomicBool, Ordering};

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{
    apply, load_world, plan, recover, Approval, ByteHash, CoreError, FaultDisposition, LockSkill,
    LockSource, Lockfile, Paths, PlanningMode, ProjectIndex, ProjectRecord, ProjectReference,
    Request, RequestRoot, Result, Scope, SnapshotKey, SourceKey, SourceKind, TransactionRuntime,
    WorldState,
};

struct NoGit;

impl GitRunner for NoGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        panic!("project indexing unexpectedly invoked Git: {command:?}")
    }
}

struct Runtime {
    time: i64,
    crash_before_refresh: AtomicBool,
}

impl Runtime {
    fn at(time: i64) -> Self {
        Self {
            time,
            crash_before_refresh: AtomicBool::new(false),
        }
    }

    fn crashing_before_refresh(time: i64) -> Self {
        Self {
            time,
            crash_before_refresh: AtomicBool::new(true),
        }
    }
}

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok(format!("project-index-{}", self.time))
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(self.time)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name == "before-project-refresh"
            && self.crash_before_refresh.swap(false, Ordering::SeqCst)
        {
            Ok(FaultDisposition::Crash)
        } else {
            Ok(FaultDisposition::Continue)
        }
    }
}

fn initialized_project(root: &std::path::Path, name: &std::ffi::OsStr) -> Paths {
    let project = root.join(name);
    let home = root.join("home");
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&home).unwrap();
    fs::write(
        project.join("grimoire.toml"),
        b"schema = \"grimoire/manifest@1\"\n",
    )
    .unwrap();
    fs::write(
        project.join("grimoire.lock"),
        Lockfile::default().to_bytes().unwrap(),
    )
    .unwrap();
    Paths::project(
        project.canonicalize().unwrap(),
        home.canonicalize().unwrap(),
    )
    .unwrap()
}

#[test]
fn successful_loads_refresh_utf8_and_raw_project_records_deterministically() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let first = initialized_project(&root, std::ffi::OsStr::new("alpha"));
    let first_world = load_world(&first, &NoGit, &Runtime::at(10)).unwrap();
    let stale_plan = plan(&first_world, Request::Reconcile, PlanningMode::Normal).unwrap();

    let second = initialized_project(&root, std::ffi::OsStr::new("beta"));
    load_world(&second, &NoGit, &Runtime::at(20)).unwrap();
    assert!(matches!(
        apply(&first, &stale_plan, Approval::NotRequired, &Runtime::at(30)),
        Err(CoreError::StalePlan(_))
    ));
    assert!(!first.transaction_journal_path(&first.scope_key()).exists());

    let bytes = fs::read(first.projects_path()).unwrap();
    let mut index = ProjectIndex::parse(&bytes).unwrap();
    assert_eq!(index.records.len(), 2);
    assert_eq!(index.records[&first.scope_key()].last_observed, 10);
    assert_eq!(index.records[&second.scope_key()].last_observed, 20);
    assert_eq!(
        index.records[&first.scope_key()].lock_hash,
        ByteHash::of(&fs::read(first.lock_path()).unwrap())
    );
    assert_eq!(index.to_bytes().unwrap(), bytes);
    let text = String::from_utf8(bytes).unwrap();
    assert!(text.contains("\"path\":"));

    use std::os::unix::ffi::OsStrExt;
    let raw_path = root.join(std::ffi::OsStr::from_bytes(b"raw-\xff"));
    let raw_paths = Paths::project(raw_path.clone(), first.grimoire_home.clone()).unwrap();
    let raw_scope = raw_paths.scope_key();
    index.records.insert(
        raw_scope.clone(),
        ProjectRecord {
            path: raw_path.clone(),
            scope_key: raw_scope.clone(),
            lock_hash: ByteHash::of(b"raw-lock"),
            references: Default::default(),
            last_observed: 30,
        },
    );
    let raw_bytes = index.to_bytes().unwrap();
    assert!(String::from_utf8(raw_bytes.clone())
        .unwrap()
        .contains("\"path_bytes_base64\":"));
    assert_eq!(
        ProjectIndex::parse(&raw_bytes).unwrap().records[&raw_scope].path,
        raw_path
    );
}

#[test]
fn malformed_or_cross_keyed_project_indexes_fail_closed() {
    let duplicate = br#"{
  "schema": "grimoire/projects@1",
  "projects": {
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": {
      "path": "/one",
      "lock_hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "references": [],
      "last_observed": 1
    },
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": {
      "path": "/two",
      "lock_hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "references": [],
      "last_observed": 1
    }
  }
}
"#;
    assert!(ProjectIndex::parse(duplicate).is_err());

    let wrong_key = br#"{
  "schema": "grimoire/projects@1",
  "projects": {
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": {
      "path": "/project",
      "lock_hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "references": [],
      "last_observed": 1
    }
  }
}
"#;
    assert!(ProjectIndex::parse(wrong_key).is_err());
}

#[test]
fn project_records_derive_pinned_references_from_manifest_and_lock() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let paths = initialized_project(&root, std::ffi::OsStr::new("project"));
    let source = root.join("source");
    fs::create_dir_all(&source).unwrap();
    fs::write(
        paths.manifest_path(),
        b"schema = \"grimoire/manifest@1\"\n[sources.local]\npath = \"../source\"\n[skills]\none = { source = \"local\" }\n",
    )
    .unwrap();
    let commit = "1".repeat(40);
    let tree = "2".repeat(40);
    let inventory = format!("sha256:{}", "3".repeat(64));
    let lock = Lockfile {
        sources: BTreeMap::from([(
            "local".try_into().unwrap(),
            LockSource::Git {
                declared: "../source".into(),
                reference: None,
                commit: commit.clone(),
                tree: tree.clone(),
                inventory: inventory.clone(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            "one".try_into().unwrap(),
            LockSkill {
                source: "local".try_into().unwrap(),
                path: "skills/one".into(),
                content: format!("sha256:{}", "4".repeat(64)),
                requested_by: BTreeSet::from([RequestRoot::Skill("one".try_into().unwrap())]),
            },
        )]),
    };
    fs::write(paths.lock_path(), lock.to_bytes().unwrap()).unwrap();

    load_world(&paths, &NoGit, &Runtime::at(25)).unwrap();
    let index = ProjectIndex::parse(&fs::read(paths.projects_path()).unwrap()).unwrap();
    let identity =
        grimoire_core::CanonicalIdentity::local(SourceKind::Git, &source.canonicalize().unwrap())
            .unwrap();
    assert_eq!(
        index.records[&paths.scope_key()].references,
        [ProjectReference {
            source_key: SourceKey::derive(&identity),
            snapshot_key: SnapshotKey::derive(SourceKind::Git, &commit, &tree, &inventory).unwrap(),
        }]
        .into_iter()
        .collect()
    );
}

#[test]
fn committed_apply_keeps_its_journal_until_project_refresh_recovers() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&home).unwrap();
    let paths = Paths::project(project, home).unwrap();
    let world = WorldState::absent(
        Scope::Project,
        [],
        std::iter::empty::<(&str, grimoire_core::InstalledLink)>(),
        None,
    )
    .unwrap();
    let plan = plan(&world, Request::Initialize, PlanningMode::Normal).unwrap();

    let outcome = apply(
        &paths,
        &plan,
        Approval::NotRequired,
        &Runtime::crashing_before_refresh(30),
    )
    .unwrap();
    assert!(matches!(
        outcome,
        grimoire_core::ApplyOutcome::Interrupted { .. }
    ));
    assert!(paths.transaction_journal_path(&paths.scope_key()).is_file());
    assert!(!paths.projects_path().exists());

    recover(&paths, &Runtime::at(40)).unwrap();
    assert!(!paths.transaction_journal_path(&paths.scope_key()).exists());
    let index = ProjectIndex::parse(&fs::read(paths.projects_path()).unwrap()).unwrap();
    assert_eq!(index.records[&paths.scope_key()].last_observed, 40);
    assert_eq!(
        index.records[&paths.scope_key()].references,
        Default::default()
    );
}

#[test]
fn project_index_domain_rejects_record_map_key_disagreement() {
    let index = ProjectIndex::default();
    assert_eq!(
        index.to_bytes().unwrap(),
        b"{\n  \"schema\": \"grimoire/projects@1\",\n  \"projects\": {}\n}\n"
    );
}
