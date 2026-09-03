#![cfg(unix)]

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::os::unix::fs::{symlink, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{
    apply, check, load_world, plan, verify_vendor_tree, Action, Approval, CanonicalIdentity,
    CoreError, FaultDisposition, LockSkill, LockSource, Lockfile, Paths, PlanningMode,
    ProjectionMode, Request, RequestRoot, Result, SourceAlias, SourceKey, SourceTrustIntent,
    TransactionRuntime, TrustChange, TrustMode, TrustReceipt, TrustStore, VendorState,
    VendorTrustReceipt,
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
    identity: CanonicalIdentity,
    manifest: Vec<u8>,
    lock: Vec<u8>,
    vendor_file: Vec<u8>,
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
        let manifest = b"schema = \"grimoire/manifest@2\"\n[sources.repo]\nurl = \"github:org/repo\"\nref = \"main\"\n[skills]\none = { source = \"repo\", mode = \"vendor\" }\n".to_vec();
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
            identity,
            manifest,
            lock,
            vendor_file,
        }
    }

    fn vendor_path(&self) -> PathBuf {
        self.paths.vendor_path(&self.alias, &self.skill).unwrap()
    }
}

#[test]
fn committed_vendor_can_be_approved_and_activated_with_every_source_channel_absent() {
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

    let approval = plan(
        &world,
        Request::TrustSource {
            alias: fixture.alias.clone(),
            mode: SourceTrustIntent::Vendor,
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(approval.is_destructive());
    assert!(approval.blockers.is_empty());
    assert!(approval.preconditions.candidates.is_empty());
    assert!(approval.preconditions.stores.is_empty());
    assert!(matches!(
        approval.actions.as_slice(),
        [Action::ReplaceTrust {
            change: TrustChange::GrantVendor,
            ..
        }]
    ));
    apply(&fixture.paths, &approval, Approval::Granted, &runtime).unwrap();

    let trust_bytes = fs::read(fixture.paths.trust_path()).unwrap();
    let trust = TrustStore::parse(&trust_bytes).unwrap();
    let source_key = SourceKey::derive(&fixture.identity);
    let record = &trust.records[&source_key];
    let source_receipt = TrustReceipt {
        commit: "1".repeat(40),
        tree: "2".repeat(40),
        inventory: format!("sha256:{}", "3".repeat(64)),
    };
    assert_eq!(record.mode_for(Some(&source_receipt)), TrustMode::Untrusted);
    assert_eq!(record.vendor_receipts.len(), 1);
    assert!(record.baseline.is_none());

    let world = load_world(&fixture.paths, &git, &runtime).unwrap();
    let activation = plan(&world, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(activation.blockers.is_empty(), "{:?}", activation.blockers);
    assert!(activation.preconditions.candidates.is_empty());
    assert!(activation.preconditions.stores.is_empty());
    assert!(matches!(
        activation.actions.as_slice(),
        [Action::CreateLink { .. }]
    ));
    apply(&fixture.paths, &activation, Approval::NotRequired, &runtime).unwrap();

    let link = fixture.paths.skills_dir().join("one");
    assert_eq!(
        fs::read_link(&link).unwrap(),
        PathBuf::from("../../vendor/grimoire/repo/one")
    );
    assert_eq!(
        fs::read(fixture.paths.manifest_path()).unwrap(),
        fixture.manifest
    );
    assert_eq!(fs::read(fixture.paths.lock_path()).unwrap(), fixture.lock);
    assert_eq!(
        fs::read(fixture.vendor_path().join("SKILL.md")).unwrap(),
        fixture.vendor_file
    );
    assert_eq!(fs::read(fixture.paths.trust_path()).unwrap(), trust_bytes);
    assert!(check(&load_world(&fixture.paths, &git, &runtime).unwrap())
        .findings
        .is_empty());
    assert_eq!(git.0.load(Ordering::SeqCst), 0);

    fs::remove_file(&link).unwrap();
    let world = load_world(&fixture.paths, &git, &runtime).unwrap();
    let revoke = plan(
        &world,
        Request::RevokeTrust { source: source_key },
        PlanningMode::Normal,
    )
    .unwrap();
    apply(&fixture.paths, &revoke, Approval::Granted, &runtime).unwrap();
    let world = load_world(&fixture.paths, &git, &runtime).unwrap();
    let blocked = plan(&world, Request::Reconcile, PlanningMode::Frozen).unwrap();
    assert!(blocked
        .blockers
        .iter()
        .any(|blocker| blocker.code == "vendor-untrusted"));
    assert!(apply(&fixture.paths, &blocked, Approval::NotRequired, &runtime).is_err());
    assert!(!link.exists());
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
}

#[test]
fn vendor_receipts_do_not_authorize_other_bytes_skills_or_snapshots() {
    let source = TrustReceipt {
        commit: "1".repeat(40),
        tree: "2".repeat(40),
        inventory: format!("sha256:{}", "3".repeat(64)),
    };
    let approved = VendorTrustReceipt {
        commit: source.commit.clone(),
        tree: source.tree.clone(),
        inventory: source.inventory.clone(),
        skill: "one".try_into().unwrap(),
        path: "skills/one".into(),
        content: format!("sha256:{}", "4".repeat(64)),
    };
    let identity = CanonicalIdentity::remote("github:org/repo").unwrap();
    let mutation = TrustStore::default()
        .grant_vendor(identity.clone(), BTreeSet::from([approved.clone()]), None)
        .unwrap();
    let store = TrustStore::parse(&mutation.after).unwrap();
    let record = &store.records[&SourceKey::derive(&identity)];

    for rejected in [
        VendorTrustReceipt {
            content: format!("sha256:{}", "5".repeat(64)),
            ..approved.clone()
        },
        VendorTrustReceipt {
            skill: "two".try_into().unwrap(),
            path: "skills/two".into(),
            ..approved.clone()
        },
        VendorTrustReceipt {
            commit: "6".repeat(40),
            ..approved.clone()
        },
    ] {
        assert!(!record.authorizes_vendor(&source, &rejected));
    }
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
