#![cfg(unix)]

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::os::unix::fs::{symlink, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{
    check, load_world, plan, verify_vendor_tree, Action, CanonicalIdentity, CoreError,
    FaultDisposition, LockSkill, LockSource, Lockfile, Paths, PlanningMode, ProjectionMode,
    Request, RequestRoot, Result, SourceAlias, TransactionRuntime, VendorState,
};

#[derive(Default)]
struct OfflineGit(AtomicUsize);

impl GitRunner for OfflineGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        self.0.fetch_add(1, Ordering::SeqCst);
        Err(CoreError::Transport(format!(
            "offline vendor flow attempted Git: {command:?}"
        )))
    }

    fn verify_cache(&self, path: &Path) -> Result<()> {
        self.0.fetch_add(1, Ordering::SeqCst);
        Err(CoreError::Transport(format!(
            "offline vendor flow inspected Git cache: {}",
            path.display()
        )))
    }
}

#[derive(Default)]
struct Runtime(AtomicUsize);

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok(format!(
            "vendor-tracer-{}",
            self.0.fetch_add(1, Ordering::SeqCst)
        ))
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

struct Fixture {
    paths: Paths,
    alias: SourceAlias,
    skill: grimoire_core::SkillName,
    _identity: CanonicalIdentity,
    _manifest: Vec<u8>,
    _lock: Vec<u8>,
    _vendor_file: Vec<u8>,
}

impl Fixture {
    fn new(root: &Path) -> Self {
        let project = root.join("project");
        let home = root.join("home/.grimoire");
        fs::create_dir_all(&project).unwrap();
        fs::create_dir_all(&home).unwrap();
        let paths = Paths::project(
            project.canonicalize().unwrap(),
            home.canonicalize().unwrap(),
        )
        .unwrap();
        let alias = SourceAlias::new("repo").unwrap();
        let skill = grimoire_core::SkillName::new("one").unwrap();
        let identity = CanonicalIdentity::remote("github:org/repo").unwrap();
        let vendor = paths.vendor_path(&alias, &skill).unwrap();
        let vendor_file = b"---\nname: one\ndescription: committed vendor fixture\n---\n".to_vec();
        write_skill(&vendor, &vendor_file);
        let content = verify_vendor_tree(&vendor, &skill).unwrap();
        let inventory = format!("sha256:{}", "3".repeat(64));
        let manifest = b"schema = \"grimoire/manifest@3\"\n[sources.repo]\nurl = \"github:org/repo\"\nref = \"main\"\n[skills]\none = { source = \"repo\" }\n".to_vec();
        let lock = Lockfile {
            sources: BTreeMap::from([(
                alias.clone(),
                LockSource::Git {
                    declared: "github:org/repo".into(),
                    reference: Some("main".into()),
                    commit: "1".repeat(40),
                    tree: "2".repeat(40),
                    inventory,
                },
            )]),
            packs: BTreeMap::new(),
            skills: BTreeMap::from([(
                skill.clone(),
                LockSkill {
                    source: alias.clone(),
                    mode: ProjectionMode::Vendor,
                    path: "skills/one".into(),
                    content,
                    requested_by: BTreeSet::from([RequestRoot::Skill(skill.clone())]),
                },
            )]),
        }
        .to_bytes()
        .unwrap();
        fs::write(paths.manifest_path(), &manifest).unwrap();
        fs::write(paths.lock_path(), &lock).unwrap();
        Self {
            paths,
            alias,
            skill,
            _identity: identity,
            _manifest: manifest,
            _lock: lock,
            _vendor_file: vendor_file,
        }
    }

    fn vendor_path(&self) -> PathBuf {
        self.paths.vendor_path(&self.alias, &self.skill).unwrap()
    }
}

#[test]
fn committed_copy_checks_without_store_or_vendor_trust() {
    let temporary = tempfile::tempdir().unwrap();
    let fixture = Fixture::new(temporary.path());
    let git = OfflineGit::default();
    let runtime = Runtime::default();

    let world = load_world(&fixture.paths, &git, &runtime).unwrap();
    assert_eq!(
        world.vendors[&fixture.skill].state,
        VendorState::OwnedUnchanged
    );
    assert!(world.candidates.is_empty());
    assert!(world
        .locked_states
        .values()
        .all(|state| state.store == grimoire_core::SnapshotStore::Absent));
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
    let copy = fixture.vendor_path();
    assert!(copy.is_dir());
    assert!(!copy.symlink_metadata().unwrap().file_type().is_symlink());
    assert!(!fixture
        .paths
        .skills_dir()
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .join("vendor/grimoire")
        .exists());

    let frozen = plan(&world, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(frozen.blockers.is_empty(), "{:?}", frozen.blockers);
    assert!(frozen.preconditions.stores.is_empty());
    assert!(!frozen.actions.iter().any(|action| matches!(
        action,
        Action::CreateVendor { .. } | Action::PrepareVendor { .. } | Action::CreateLink { .. }
    )));
    let report = check(&world);
    assert!(
        !report
            .findings
            .iter()
            .any(|finding| finding.code == "vendor-missing" || finding.code == "vendor-untrusted"),
        "{:?}",
        report.findings
    );
}

#[test]
fn verifier_rejects_identity_modes_links_special_entries_and_limits() {
    let temporary = tempfile::tempdir().unwrap();
    let expected = grimoire_core::SkillName::new("one").unwrap();

    let wrong_name = temporary.path().join("wrong-name");
    write_skill(
        &wrong_name,
        b"---\nname: other\ndescription: wrong identity\n---\n",
    );
    assert_error_contains(&wrong_name, &expected, "skill-name-mismatch");

    let bad_mode = temporary.path().join("bad-mode");
    write_skill(
        &bad_mode,
        b"---\nname: one\ndescription: invalid mode\n---\n",
    );
    fs::set_permissions(bad_mode.join("SKILL.md"), fs::Permissions::from_mode(0o600)).unwrap();
    assert_error_contains(&bad_mode, &expected, "invalid-entry-mode");

    let escaping = temporary.path().join("escaping-link");
    write_skill(
        &escaping,
        b"---\nname: one\ndescription: escaping link\n---\n",
    );
    symlink("../outside", escaping.join("escape")).unwrap();
    assert_error_contains(&escaping, &expected, "escaping-symlink");

    let special = temporary.path().join("special-entry");
    write_skill(
        &special,
        b"---\nname: one\ndescription: socket entry\n---\n",
    );
    assert!(Command::new("mkfifo")
        .arg(special.join("pipe"))
        .status()
        .unwrap()
        .success());
    assert_error_contains(&special, &expected, "unsupported-entry");

    let too_deep = temporary.path().join("too-deep");
    write_skill(
        &too_deep,
        b"---\nname: one\ndescription: excessive depth\n---\n",
    );
    let mut directory = too_deep.clone();
    for _ in 0..34 {
        directory.push("d");
        fs::create_dir(&directory).unwrap();
        fs::set_permissions(&directory, fs::Permissions::from_mode(0o755)).unwrap();
    }
    fs::write(directory.join("leaf"), b"deep").unwrap();
    fs::set_permissions(directory.join("leaf"), fs::Permissions::from_mode(0o644)).unwrap();
    assert_error_contains(&too_deep, &expected, "discovery-depth-limit");

    let too_large = temporary.path().join("too-large");
    write_skill(
        &too_large,
        b"---\nname: one\ndescription: excessive bytes\n---\n",
    );
    let large = fs::File::create(too_large.join("large.bin")).unwrap();
    large.set_len(128 * 1024 * 1024 + 1).unwrap();
    fs::set_permissions(
        too_large.join("large.bin"),
        fs::Permissions::from_mode(0o644),
    )
    .unwrap();
    assert_error_contains(&too_large, &expected, "review-byte-limit");
}

fn write_skill(root: &Path, manifest: &[u8]) {
    fs::create_dir_all(root).unwrap();
    fs::set_permissions(root, fs::Permissions::from_mode(0o755)).unwrap();
    fs::write(root.join("SKILL.md"), manifest).unwrap();
    fs::set_permissions(root.join("SKILL.md"), fs::Permissions::from_mode(0o644)).unwrap();
}

fn assert_error_contains(root: &Path, expected: &grimoire_core::SkillName, code: &str) {
    let root = root.canonicalize().unwrap();
    let error = verify_vendor_tree(&root, expected).unwrap_err();
    assert!(
        error.to_string().contains(code),
        "expected {code}, got {error}"
    );
}
