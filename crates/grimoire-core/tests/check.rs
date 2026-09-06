use std::collections::{BTreeMap, BTreeSet};
use std::fs;

use grimoire_core::inventory::scan;
use grimoire_core::source::{GitCommand, GitResult, GitRunner, HeldDirectoryReader};
use grimoire_core::{
    check, load_world, CanonicalIdentity, CheckSeverity, FaultDisposition, LockSkill, LockSource,
    Lockfile, Paths, RequestRoot, Result, SourceKind, TransactionRuntime, TrustBaseline,
    TrustStore,
};

struct NoGit;

impl GitRunner for NoGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        panic!("check unexpectedly invoked Git: {command:?}")
    }
}

struct Runtime;

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("check-fixture".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

fn fixture() -> (tempfile::TempDir, Paths) {
    let temporary = tempfile::tempdir().unwrap();
    let project = temporary.path().join("project");
    let home = temporary.path().join("home");
    let source = temporary.path().join("source");
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&home).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: fixture\n---\n",
    )
    .unwrap();
    let project = project.canonicalize().unwrap();
    let source = source.canonicalize().unwrap();
    let paths = Paths::project(project, home.canonicalize().unwrap()).unwrap();
    let inventory = scan(&HeldDirectoryReader::open(&source).unwrap()).unwrap();
    fs::write(
        paths.manifest_path(),
        b"schema = \"grimoire/manifest@3\"\n[sources.local]\npath = \"../source\"\nlink = true\n[skills]\none = { source = \"local\" }\n",
    )
    .unwrap();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            "local".try_into().unwrap(),
            LockSource::Link {
                declared: "../source".into(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            "one".try_into().unwrap(),
            LockSkill {
                source: "local".try_into().unwrap(),
                mode: grimoire_core::ProjectionMode::Link,
                path: "skills/one".into(),
                content: inventory.skills[0].content_digest.to_string(),
                requested_by: BTreeSet::from([RequestRoot::Skill("one".try_into().unwrap())]),
            },
        )]),
    };
    fs::write(paths.lock_path(), lock.to_bytes().unwrap()).unwrap();
    let identity = CanonicalIdentity::local(SourceKind::Link, &source).unwrap();
    let trust = TrustStore::default()
        .grant_all(
            identity,
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
    (temporary, paths)
}

#[test]
fn healthy_world_has_no_findings_and_check_is_read_only() {
    let (_temporary, paths) = fixture();
    let before_manifest = fs::read(paths.manifest_path()).unwrap();
    let before_lock = fs::read(paths.lock_path()).unwrap();
    let before_trust = fs::read(paths.trust_path()).unwrap();
    let world = load_world(&paths, &NoGit, &Runtime).unwrap();

    assert!(check(&world).findings.is_empty());
    assert_eq!(fs::read(paths.manifest_path()).unwrap(), before_manifest);
    assert_eq!(fs::read(paths.lock_path()).unwrap(), before_lock);
    assert_eq!(fs::read(paths.trust_path()).unwrap(), before_trust);
}

#[test]
fn findings_are_stable_sorted_and_do_not_follow_foreign_entries() {
    let (temporary, paths) = fixture();
    fs::remove_file(paths.skills_dir().join("one")).unwrap();
    fs::write(paths.skills_dir().join("one"), b"foreign\n").unwrap();
    let journal = paths.transaction_journal_path(&paths.scope_key());
    fs::create_dir_all(journal.parent().unwrap()).unwrap();
    fs::write(&journal, b"unread by check\n").unwrap();
    let canary = temporary.path().join("canary");
    fs::write(&canary, b"untouched\n").unwrap();

    let report = check(&load_world(&paths, &NoGit, &Runtime).unwrap());
    let codes = report
        .findings
        .iter()
        .map(|finding| finding.code.as_str())
        .collect::<Vec<_>>();
    assert_eq!(codes, vec!["foreign-file", "scope-journal-pending"]);
    assert!(report
        .findings
        .iter()
        .all(|finding| finding.severity == CheckSeverity::Error));
    assert_eq!(fs::read(canary).unwrap(), b"untouched\n");
}

#[test]
fn lock_content_and_trust_mismatches_are_reported() {
    let (_temporary, paths) = fixture();
    let mut lock = Lockfile::parse(&fs::read(paths.lock_path()).unwrap()).unwrap();
    lock.skills
        .get_mut(&"one".try_into().unwrap())
        .unwrap()
        .content = format!("sha256:{}", "0".repeat(64));
    fs::write(paths.lock_path(), lock.to_bytes().unwrap()).unwrap();
    fs::remove_file(paths.trust_path()).unwrap();

    let report = check(&load_world(&paths, &NoGit, &Runtime).unwrap());
    let codes = report
        .findings
        .iter()
        .map(|finding| finding.code.as_str())
        .collect::<Vec<_>>();
    assert!(codes.contains(&"manifest-lock-mismatch"));
    assert!(codes.contains(&"live-source-requires-all-trust"));
}
