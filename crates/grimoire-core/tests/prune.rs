use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};

use grimoire_core::inventory::scan;
use grimoire_core::source::HeldDirectoryReader;
use grimoire_core::{
    apply, observe_reachability, plan, Action, Approval, ByteHash, CandidateRecord,
    CanonicalIdentity, ExitClass, FaultDisposition, LinkPrecondition, LockSkill, LockSource,
    Lockfile, OwnedLinkTarget, Paths, Plan, PlanningMode, Preconditions, ProjectIndex,
    ProjectRecord, ProjectReference, Request, RequestRoot, Result, Scope, SnapshotKey, SourceKey,
    SourceKind, TransactionRuntime, WorldState,
};

struct Runtime;

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("prune-fixture".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

struct CrashJournal;

impl TransactionRuntime for CrashJournal {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("prune-journal".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        Ok(if name == "journal-created" {
            FaultDisposition::Crash
        } else {
            FaultDisposition::Continue
        })
    }
}

struct SwapAtPrune {
    target: std::path::PathBuf,
    canary: std::path::PathBuf,
    swapped: AtomicBool,
}

impl TransactionRuntime for SwapAtPrune {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("prune-swap".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, name: &'static str) -> Result<FaultDisposition> {
        if name == "before-prune-snapshot" && !self.swapped.swap(true, Ordering::SeqCst) {
            fs::rename(&self.target, self.target.with_extension("parked")).unwrap();
            std::os::unix::fs::symlink(&self.canary, &self.target).unwrap();
        }
        Ok(FaultDisposition::Continue)
    }
}

struct Fixture {
    _temporary: tempfile::TempDir,
    paths: Paths,
    global: ProjectReference,
    project: ProjectReference,
    candidate: ProjectReference,
    repair: ProjectReference,
    journal: ProjectReference,
    isolated: ProjectReference,
    candidate_path: std::path::PathBuf,
    repair_path: std::path::PathBuf,
}

fn reference(source: char, snapshot: char) -> ProjectReference {
    ProjectReference {
        source_key: SourceKey::parse(source.to_string().repeat(64)).unwrap(),
        snapshot_key: SnapshotKey::parse(snapshot.to_string().repeat(64)).unwrap(),
    }
}

fn write_skill(root: &Path) {
    fs::create_dir_all(root.join("skills/one")).unwrap();
    fs::write(
        root.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: prune fixture\n---\n",
    )
    .unwrap();
}

fn create_store(paths: &Paths, reference: &ProjectReference) {
    write_skill(&paths.store_path(&reference.source_key, &reference.snapshot_key));
}

fn fixture() -> Fixture {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let user = root.join("user");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&user).unwrap();
    let paths = Paths::global(user, home).unwrap();

    let staging = root.join("staging");
    write_skill(&staging);
    let inventory = scan(&HeldDirectoryReader::open(&staging).unwrap()).unwrap();
    let identity = CanonicalIdentity::remote("github:org/global").unwrap();
    let commit = "1".repeat(40);
    let tree = "2".repeat(40);
    let global = ProjectReference {
        source_key: SourceKey::derive(&identity),
        snapshot_key: SnapshotKey::derive(
            SourceKind::Git,
            &commit,
            &tree,
            &inventory.inventory_digest.to_string(),
        )
        .unwrap(),
    };
    create_store(&paths, &global);
    fs::write(
        paths.manifest_path(),
        b"schema = \"grimoire/manifest@1\"\n[sources.repo]\nurl = \"github:org/global\"\n[skills]\none = { source = \"repo\" }\n",
    )
    .unwrap();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            "repo".try_into().unwrap(),
            LockSource::Git {
                declared: "github:org/global".into(),
                reference: None,
                commit,
                tree,
                inventory: inventory.inventory_digest.to_string(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            "one".try_into().unwrap(),
            LockSkill {
                source: "repo".try_into().unwrap(),
                path: "skills/one".into(),
                content: inventory.skills[0].content_digest.to_string(),
                requested_by: BTreeSet::from([RequestRoot::Skill("one".try_into().unwrap())]),
            },
        )]),
    };
    fs::write(paths.lock_path(), lock.to_bytes().unwrap()).unwrap();

    let project = reference('a', 'b');
    create_store(&paths, &project);
    let missing_project = root.join("missing-project");
    let project_paths =
        Paths::project(missing_project.clone(), paths.grimoire_home.clone()).unwrap();
    let record = ProjectRecord {
        path: missing_project,
        scope_key: project_paths.scope_key(),
        lock_hash: ByteHash::of(b"last observed lock"),
        references: [project.clone()].into_iter().collect(),
        last_observed: 1_600_000_000,
    };
    let index = ProjectIndex {
        records: BTreeMap::from([(record.scope_key.clone(), record)]),
    };
    fs::write(paths.projects_path(), index.to_bytes().unwrap()).unwrap();

    let candidate_identity = CanonicalIdentity::remote("github:org/candidate").unwrap();
    let candidate_record = CandidateRecord::new(
        "3".repeat(64),
        candidate_identity,
        Some("4".repeat(40)),
        Some("5".repeat(40)),
        inventory.inventory_digest.to_string(),
        inventory.review_tree_digest.to_string(),
    )
    .unwrap();
    let candidate = ProjectReference {
        source_key: candidate_record.source_key(),
        snapshot_key: candidate_record.snapshot_key().unwrap().unwrap(),
    };
    create_store(&paths, &candidate);
    let candidate_path = paths.grimoire_home.join("candidates/global/repo.json");
    fs::create_dir_all(candidate_path.parent().unwrap()).unwrap();
    fs::write(&candidate_path, candidate_record.to_bytes().unwrap()).unwrap();

    let repair = reference('c', 'd');
    create_store(&paths, &repair);
    let repair_path = paths.store_repair_path(&repair.source_key, &repair.snapshot_key);
    fs::create_dir_all(repair_path.parent().unwrap()).unwrap();
    fs::write(&repair_path, b"active repair\n").unwrap();

    let journal = reference('8', '9');
    create_store(&paths, &journal);
    let journal_plan = Plan {
        actions: vec![Action::CreateLink {
            scope: Scope::Global,
            skill: "journal".try_into().unwrap(),
            target: OwnedLinkTarget::Stored {
                source_key: journal.source_key.clone(),
                snapshot_key: journal.snapshot_key.clone(),
                skill_path: "skills/one".into(),
            },
        }],
        blockers: Vec::new(),
        preconditions: Preconditions {
            manifest: Some(ByteHash::of(&fs::read(paths.manifest_path()).unwrap())),
            lock: Some(ByteHash::of(&fs::read(paths.lock_path()).unwrap())),
            candidates: BTreeMap::new(),
            stores: BTreeMap::new(),
            trust: None,
            projects: None,
            reachability: None,
            links: BTreeMap::from([("journal".try_into().unwrap(), LinkPrecondition::Absent)]),
        },
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    };
    assert!(matches!(
        apply(&paths, &journal_plan, Approval::NotRequired, &CrashJournal).unwrap(),
        grimoire_core::ApplyOutcome::Interrupted { .. }
    ));

    let isolated = reference('e', 'f');
    create_store(&paths, &isolated);
    fs::write(
        paths
            .store_path(&isolated.source_key, &isolated.snapshot_key)
            .join("skills/one/payload"),
        b"payload\n",
    )
    .unwrap();
    std::os::unix::fs::symlink(
        "payload",
        paths
            .store_path(&isolated.source_key, &isolated.snapshot_key)
            .join("skills/one/link"),
    )
    .unwrap();

    Fixture {
        _temporary: temporary,
        paths,
        global,
        project,
        candidate,
        repair,
        journal,
        isolated,
        candidate_path,
        repair_path,
    }
}

fn prune_plan(fixture: &Fixture) -> grimoire_core::Plan {
    let observation = observe_reachability(&fixture.paths, &[], &Runtime).unwrap();
    plan(
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
    .unwrap()
}

#[test]
fn prune_retains_every_reference_source_and_removes_only_the_isolated_snapshot() {
    let fixture = fixture();
    let plan = prune_plan(&fixture);
    assert_eq!(
        plan.actions,
        vec![Action::PruneSnapshot {
            source_key: fixture.isolated.source_key.clone(),
            snapshot_key: fixture.isolated.snapshot_key.clone(),
        }]
    );
    assert!(plan.is_destructive());

    assert_eq!(
        apply(&fixture.paths, &plan, Approval::Declined, &Runtime).unwrap(),
        grimoire_core::ApplyOutcome::Cancelled
    );
    assert!(fixture
        .paths
        .store_path(&fixture.isolated.source_key, &fixture.isolated.snapshot_key)
        .exists());
    assert!(matches!(
        apply(&fixture.paths, &plan, Approval::NotRequired, &Runtime),
        Err(grimoire_core::CoreError::ApprovalRequired)
    ));
    apply(&fixture.paths, &plan, Approval::Granted, &Runtime).unwrap();

    for retained in [
        &fixture.global,
        &fixture.project,
        &fixture.candidate,
        &fixture.repair,
        &fixture.journal,
    ] {
        assert!(fixture
            .paths
            .store_path(&retained.source_key, &retained.snapshot_key)
            .is_dir());
    }
    assert!(!fixture
        .paths
        .store_path(&fixture.isolated.source_key, &fixture.isolated.snapshot_key)
        .exists());
}

#[test]
fn explicit_project_is_refreshed_and_remains_reachable_when_later_only_indexed() {
    let fixture = fixture();
    let root = fixture.paths.grimoire_home.parent().unwrap();
    let project = root.join("explicit-project");
    fs::create_dir_all(&project).unwrap();
    let identity = CanonicalIdentity::remote("github:org/explicit").unwrap();
    let commit = "a".repeat(40);
    let tree = "b".repeat(40);
    let staging = root.join("explicit-staging");
    write_skill(&staging);
    let inventory = scan(&HeldDirectoryReader::open(&staging).unwrap()).unwrap();
    let reference = ProjectReference {
        source_key: SourceKey::derive(&identity),
        snapshot_key: SnapshotKey::derive(
            SourceKind::Git,
            &commit,
            &tree,
            &inventory.inventory_digest.to_string(),
        )
        .unwrap(),
    };
    create_store(&fixture.paths, &reference);
    fs::write(
        project.join("grimoire.toml"),
        b"schema = \"grimoire/manifest@1\"\n[sources.repo]\nurl = \"github:org/explicit\"\n[skills]\none = { source = \"repo\" }\n",
    )
    .unwrap();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            "repo".try_into().unwrap(),
            LockSource::Git {
                declared: "github:org/explicit".into(),
                reference: None,
                commit,
                tree,
                inventory: inventory.inventory_digest.to_string(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            "one".try_into().unwrap(),
            LockSkill {
                source: "repo".try_into().unwrap(),
                path: "skills/one".into(),
                content: inventory.skills[0].content_digest.to_string(),
                requested_by: BTreeSet::from([RequestRoot::Skill("one".try_into().unwrap())]),
            },
        )]),
    };
    fs::write(project.join("grimoire.lock"), lock.to_bytes().unwrap()).unwrap();

    let first = observe_reachability(&fixture.paths, &[project], &Runtime).unwrap();
    assert!(first.reachable.contains(&reference));
    let second = observe_reachability(&fixture.paths, &[], &Runtime).unwrap();
    assert!(second.reachable.contains(&reference));
}

#[test]
fn stale_store_or_candidate_generation_aborts_before_deletion() {
    let base = fixture();
    let plan = prune_plan(&base);
    let concurrent = reference('6', '7');
    create_store(&base.paths, &concurrent);

    assert!(matches!(
        apply(&base.paths, &plan, Approval::Granted, &Runtime),
        Err(grimoire_core::CoreError::StalePlan(_))
    ));
    assert!(base
        .paths
        .store_path(&base.isolated.source_key, &base.isolated.snapshot_key)
        .is_dir());

    for mutate in ["candidate", "projects", "repair", "journal"] {
        let fixture = fixture();
        let plan = prune_plan(&fixture);
        let path = match mutate {
            "candidate" => fixture.candidate_path.clone(),
            "projects" => fixture.paths.projects_path(),
            "repair" => fixture.repair_path.clone(),
            "journal" => fixture
                .paths
                .transaction_journal_path(&fixture.paths.scope_key()),
            _ => unreachable!(),
        };
        let mut bytes = fs::read(&path).unwrap();
        bytes.push(b'\n');
        fs::write(path, bytes).unwrap();
        assert!(matches!(
            apply(&fixture.paths, &plan, Approval::Granted, &Runtime),
            Err(grimoire_core::CoreError::StalePlan(_))
        ));
        assert!(fixture
            .paths
            .store_path(&fixture.isolated.source_key, &fixture.isolated.snapshot_key)
            .is_dir());
    }
}

#[test]
fn removing_a_reference_source_exposes_its_snapshot_in_the_red_arm() {
    let candidate = fixture();
    fs::remove_file(&candidate.candidate_path).unwrap();
    let candidate_plan = prune_plan(&candidate);
    assert!(candidate_plan.actions.iter().any(|action| matches!(
        action,
        Action::PruneSnapshot { source_key, snapshot_key }
            if source_key == &candidate.candidate.source_key
                && snapshot_key == &candidate.candidate.snapshot_key
    )));

    let repair = fixture();
    fs::remove_file(&repair.repair_path).unwrap();
    let repair_plan = prune_plan(&repair);
    assert!(repair_plan.actions.iter().any(|action| matches!(
        action,
        Action::PruneSnapshot { source_key, snapshot_key }
            if source_key == &repair.repair.source_key
                && snapshot_key == &repair.repair.snapshot_key
    )));

    let project = fixture();
    fs::remove_file(project.paths.projects_path()).unwrap();
    let project_plan = prune_plan(&project);
    assert!(project_plan.actions.iter().any(|action| matches!(
        action,
        Action::PruneSnapshot { source_key, snapshot_key }
            if source_key == &project.project.source_key
                && snapshot_key == &project.project.snapshot_key
    )));
}

#[test]
fn malformed_or_symlinked_store_names_retain_everything_and_preserve_canaries() {
    let fixture = fixture();
    let canary = fixture
        .paths
        .grimoire_home
        .parent()
        .unwrap()
        .join("outside-canary");
    fs::write(&canary, b"safe\n").unwrap();
    std::os::unix::fs::symlink(
        &canary,
        fixture
            .paths
            .grimoire_home
            .join("store/checkouts/not-a-key"),
    )
    .unwrap();

    let plan = prune_plan(&fixture);
    assert!(plan.actions.is_empty());
    assert!(plan
        .blockers
        .iter()
        .any(|blocker| blocker.code == "prune-reachability-uncertain"));
    assert_eq!(fs::read(canary).unwrap(), b"safe\n");
}

#[test]
fn racing_snapshot_swap_cannot_redirect_directory_relative_prune() {
    let fixture = fixture();
    let plan = prune_plan(&fixture);
    let target = fixture
        .paths
        .store_path(&fixture.isolated.source_key, &fixture.isolated.snapshot_key);
    let canary = fixture
        .paths
        .grimoire_home
        .parent()
        .unwrap()
        .join("outside-directory");
    fs::create_dir_all(&canary).unwrap();
    fs::write(canary.join("canary"), b"safe\n").unwrap();

    assert!(matches!(
        apply(
            &fixture.paths,
            &plan,
            Approval::Granted,
            &SwapAtPrune {
                target,
                canary: canary.clone(),
                swapped: AtomicBool::new(false),
            },
        ),
        Err(grimoire_core::CoreError::StalePlan(_))
    ));
    assert_eq!(fs::read(canary.join("canary")).unwrap(), b"safe\n");
}
