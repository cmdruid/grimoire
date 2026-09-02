use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};

use grimoire_core::inventory::scan;
use grimoire_core::source::{GitCommand, GitResult, GitRunner, HeldDirectoryReader};
use grimoire_core::{
    apply, check, load_world, plan, Approval, CandidateRecord, CanonicalIdentity, FaultDisposition,
    InstalledLink, LockSkill, LockSource, Lockfile, Manifest, Paths, PlanningMode, Request,
    RequestRoot, Result, SnapshotKey, SnapshotStore, SourceAlias, SourceKey, SourceKind,
    TransactionRuntime, TrustBaseline, TrustReceipt, TrustStore,
};

#[derive(Default)]
struct NoGit(AtomicUsize);

impl GitRunner for NoGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        self.0.fetch_add(1, Ordering::SeqCst);
        panic!("world loading unexpectedly invoked Git: {command:?}")
    }
}

struct Runtime;

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("world-fixture".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

fn write_skill(root: &Path) {
    fs::create_dir_all(root.join("skills/one")).unwrap();
    fs::write(
        root.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: fixture\n---\n",
    )
    .unwrap();
}

fn scan_inventory(root: &Path) -> grimoire_core::inventory::SourceInventory {
    scan(&HeldDirectoryReader::open(root).unwrap()).unwrap()
}

fn project_paths(root: &Path) -> Paths {
    let project = root.join("project");
    let home = root.join("home");
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&home).unwrap();
    Paths::project(
        project.canonicalize().unwrap(),
        home.canonicalize().unwrap(),
    )
    .unwrap()
}

#[test]
fn absent_scopes_and_malformed_initialized_state_are_explicit() {
    let temporary = tempfile::tempdir().unwrap();
    let project = project_paths(temporary.path());
    let global_home = temporary.path().join("global-home");
    let global_state = temporary.path().join("global-state");
    fs::create_dir_all(&global_home).unwrap();
    let global = Paths::global(global_home.canonicalize().unwrap(), global_state).unwrap();
    let git = NoGit::default();

    assert!(
        !load_world(&project, &git, &Runtime)
            .unwrap()
            .manifest_present
    );
    assert!(!load_world(&global, &git, &Runtime).unwrap().lock_present);

    fs::write(
        project.manifest_path(),
        b"schema = \"grimoire/manifest@1\"\n",
    )
    .unwrap();
    let error = load_world(&project, &git, &Runtime).unwrap_err();
    assert!(error.to_string().contains("partially initialized"));

    fs::write(project.lock_path(), b"not-json\n").unwrap();
    assert!(load_world(&project, &git, &Runtime).is_err());
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
}

#[test]
fn live_world_observes_exact_link_without_following_it() {
    let temporary = tempfile::tempdir().unwrap();
    let paths = project_paths(temporary.path());
    let source = temporary.path().join("source");
    write_skill(&source);
    let source = source.canonicalize().unwrap();
    let inventory = scan_inventory(&source);
    let alias = SourceAlias::new("local").unwrap();
    let manifest = b"schema = \"grimoire/manifest@1\"\n[sources.local]\npath = \"../source\"\nlive = true\n[skills]\none = { source = \"local\" }\n";
    fs::write(paths.manifest_path(), manifest).unwrap();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            alias.clone(),
            LockSource::Live {
                declared: "../source".into(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            "one".try_into().unwrap(),
            LockSkill {
                source: alias,
                path: "skills/one".into(),
                content: inventory.skills[0].content_digest.to_string(),
                requested_by: BTreeSet::from([RequestRoot::Skill("one".try_into().unwrap())]),
            },
        )]),
    };
    fs::write(paths.lock_path(), lock.to_bytes().unwrap()).unwrap();
    let identity = CanonicalIdentity::local(SourceKind::Live, &source).unwrap();
    let trust = TrustStore::default()
        .grant_all(
            identity.clone(),
            None,
            TrustBaseline {
                commit: None,
                tree: None,
                inventory: inventory.inventory_digest.to_string(),
                review_tree: inventory.review_tree_digest.to_string(),
            },
            None,
        )
        .unwrap();
    fs::create_dir_all(paths.trust_path().parent().unwrap()).unwrap();
    fs::write(paths.trust_path(), trust.after).unwrap();
    fs::create_dir_all(paths.skills_dir()).unwrap();
    std::os::unix::fs::symlink(source.join("skills/one"), paths.skills_dir().join("one")).unwrap();

    let world = load_world(&paths, &NoGit::default(), &Runtime).unwrap();
    assert_eq!(world.lock, lock);
    assert_eq!(
        world.links[&"one".try_into().unwrap()],
        InstalledLink::Symlink(source.join("skills/one"))
    );
    assert!(world.observations.is_empty());

    use std::os::unix::ffi::OsStrExt;
    fs::remove_file(paths.skills_dir().join("one")).unwrap();
    let raw_target = std::ffi::OsStr::from_bytes(b"foreign-\xff");
    std::os::unix::fs::symlink(raw_target, paths.skills_dir().join("one")).unwrap();
    let world = load_world(&paths, &NoGit::default(), &Runtime).unwrap();
    assert_eq!(
        world.links[&"one".try_into().unwrap()],
        InstalledLink::Symlink(raw_target.into())
    );
    assert!(check(&world)
        .findings
        .iter()
        .any(|finding| finding.code == "link-drift"));
}

#[test]
fn candidate_without_its_private_cache_is_an_observation_not_a_fetch() {
    let temporary = tempfile::tempdir().unwrap();
    let paths = project_paths(temporary.path());
    let manifest_bytes = b"schema = \"grimoire/manifest@1\"\n[sources.repo]\nurl = \"github:org/repo\"\nref = \"main\"\n";
    fs::write(paths.manifest_path(), manifest_bytes).unwrap();
    fs::write(paths.lock_path(), Lockfile::default().to_bytes().unwrap()).unwrap();
    let alias = SourceAlias::new("repo").unwrap();
    let manifest = Manifest::parse(manifest_bytes.to_vec()).unwrap();
    let candidate = CandidateRecord::new(
        manifest.source_declaration_hash(&alias).unwrap(),
        CanonicalIdentity::remote("github:org/repo").unwrap(),
        Some("1".repeat(40)),
        Some("2".repeat(40)),
        format!("sha256:{}", "3".repeat(64)),
        format!("sha256:{}", "4".repeat(64)),
    )
    .unwrap();
    let candidate_path = paths.candidate_path(&paths.scope_key(), &alias);
    fs::create_dir_all(candidate_path.parent().unwrap()).unwrap();
    fs::write(candidate_path, candidate.to_bytes().unwrap()).unwrap();

    let git = NoGit::default();
    let world = load_world(&paths, &git, &Runtime).unwrap();
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
    assert_eq!(world.observations[0].code, "candidate-invalid");
    assert!(world.observations[0].details["message"].contains("cache is missing"));
    assert_eq!(check(&world).findings[0].code, "candidate-invalid");
}

#[test]
fn frozen_restore_uses_only_the_locked_store_snapshot() {
    let temporary = tempfile::tempdir().unwrap();
    let paths = project_paths(temporary.path());
    let source = temporary.path().join("source");
    write_skill(&source);
    let source = source.canonicalize().unwrap();
    let inventory = scan_inventory(&source);
    let identity = CanonicalIdentity::local(SourceKind::Git, &source).unwrap();
    let source_key = SourceKey::derive(&identity);
    let commit = "1".repeat(40);
    let tree = "2".repeat(40);
    let snapshot_key = SnapshotKey::derive(
        SourceKind::Git,
        &commit,
        &tree,
        &inventory.inventory_digest.to_string(),
    )
    .unwrap();
    let stored = paths.store_path(&source_key, &snapshot_key);
    write_skill(&stored);
    assert_eq!(scan_inventory(&stored).skills.len(), 1);

    fs::write(
        paths.manifest_path(),
        b"schema = \"grimoire/manifest@1\"\n[sources.local]\npath = \"../source\"\n[skills]\none = { source = \"local\" }\n",
    )
    .unwrap();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            "local".try_into().unwrap(),
            LockSource::Git {
                declared: "../source".into(),
                reference: None,
                commit: commit.clone(),
                tree: tree.clone(),
                inventory: inventory.inventory_digest.to_string(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            "one".try_into().unwrap(),
            LockSkill {
                source: "local".try_into().unwrap(),
                path: "skills/one".into(),
                content: inventory.skills[0].content_digest.to_string(),
                requested_by: BTreeSet::from([RequestRoot::Skill("one".try_into().unwrap())]),
            },
        )]),
    };
    fs::write(paths.lock_path(), lock.to_bytes().unwrap()).unwrap();
    let trust = TrustStore::default()
        .grant_exact(
            identity.clone(),
            TrustReceipt {
                commit,
                tree,
                inventory: inventory.inventory_digest.to_string(),
            },
            TrustBaseline {
                commit: Some("1".repeat(40)),
                tree: Some("2".repeat(40)),
                inventory: inventory.inventory_digest.to_string(),
                review_tree: inventory.review_tree_digest.to_string(),
            },
            None,
        )
        .unwrap();
    fs::create_dir_all(paths.trust_path().parent().unwrap()).unwrap();
    fs::write(paths.trust_path(), trust.after).unwrap();

    let git = NoGit::default();
    let world = load_world(&paths, &git, &Runtime).unwrap();
    let loaded = &world.locked_states[&SourceAlias::new("local").unwrap()];
    assert_eq!(
        loaded.snapshot.root, stored,
        "identity={:?} expected_identity={identity:?}",
        loaded.identity
    );
    assert!(stored.is_dir());
    assert_eq!(loaded.store, grimoire_core::SnapshotStore::Valid);
    let restore = plan(&world, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(
        restore.blockers.is_empty(),
        "blockers={:?} observations={:?} locked_skills={:?}",
        restore.blockers,
        world.observations,
        world.locked_states[&SourceAlias::new("local").unwrap()]
            .snapshot
            .inventory
            .skills
    );
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
    apply(&paths, &restore, Approval::NotRequired, &Runtime).unwrap();
    assert_eq!(
        fs::read_link(paths.skills_dir().join("one")).unwrap(),
        stored.join("skills/one")
    );

    fs::write(
        stored.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: corrupted\n---\n",
    )
    .unwrap();
    let corrupt = load_world(&paths, &git, &Runtime).unwrap();
    assert_eq!(
        corrupt.locked_states[&SourceAlias::new("local").unwrap()].store,
        SnapshotStore::Corrupt
    );
    assert!(check(&corrupt)
        .findings
        .iter()
        .any(|finding| finding.code == "store-corrupt"));
}

#[test]
fn world_loader_rejects_symlinked_state_files_without_reading_through_them() {
    let temporary = tempfile::tempdir().unwrap();
    let paths = project_paths(temporary.path());
    let outside = temporary.path().join("outside");
    fs::create_dir_all(&outside).unwrap();
    let manifest = outside.join("manifest");
    let lock = outside.join("lock");
    fs::write(&manifest, b"schema = \"grimoire/manifest@1\"\n").unwrap();
    fs::write(&lock, Lockfile::default().to_bytes().unwrap()).unwrap();
    std::os::unix::fs::symlink(&manifest, paths.manifest_path()).unwrap();
    std::os::unix::fs::symlink(&lock, paths.lock_path()).unwrap();

    assert!(load_world(&paths, &NoGit::default(), &Runtime).is_err());
    assert_eq!(
        fs::read(&manifest).unwrap(),
        b"schema = \"grimoire/manifest@1\"\n"
    );
    assert_eq!(
        fs::read(&lock).unwrap(),
        Lockfile::default().to_bytes().unwrap()
    );
}
