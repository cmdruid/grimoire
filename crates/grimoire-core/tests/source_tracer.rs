use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::Instant;

use grimoire_core::inventory::scan;
use grimoire_core::source::{
    fetch_remote, fetch_source, GitCommand, GitResult, GitRunner, GitSnapshot, GitTreeReader,
    ReviewExport,
};
use grimoire_core::{CandidateRecord, CanonicalIdentity, Paths, Result, SourceAlias};

struct FixtureGit {
    blobs: BTreeMap<String, Vec<u8>>,
    tree: Vec<u8>,
}

struct PrunableGit {
    trees: BTreeMap<String, Vec<u8>>,
    blobs: BTreeMap<String, Vec<u8>>,
    visited: Mutex<Vec<String>>,
}

#[derive(Default)]
struct DeadlineGit {
    deadlines: Mutex<Vec<Instant>>,
}

impl GitRunner for DeadlineGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        let stdout = match command {
            GitCommand::LsRemote { .. } => {
                format!("ref: refs/heads/main\tHEAD\n{}\tHEAD\n", "3".repeat(40)).into_bytes()
            }
            GitCommand::InitBare { repository } => {
                std::fs::create_dir_all(repository).unwrap();
                Vec::new()
            }
            GitCommand::Fetch { .. } => Vec::new(),
            GitCommand::RevParse { revision, .. } if revision.ends_with("^{commit}") => {
                format!("{}\n", "3".repeat(40)).into_bytes()
            }
            GitCommand::RevParse { .. } => format!("{}\n", "4".repeat(40)).into_bytes(),
            other => panic!("unexpected deadline fixture command: {other:?}"),
        };
        Ok(GitResult {
            stdout,
            stderr: Vec::new(),
        })
    }

    fn run_until(&self, command: GitCommand, deadline: Instant) -> Result<GitResult> {
        self.deadlines.lock().unwrap().push(deadline);
        self.run(command)
    }
}

impl GitRunner for FixtureGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        let stdout = match command {
            GitCommand::InitBare { repository } => {
                std::fs::create_dir_all(&repository).unwrap();
                Vec::new()
            }
            GitCommand::Fetch {
                bare_repository, ..
            } => {
                std::fs::write(bare_repository.join("valid"), b"cache").unwrap();
                Vec::new()
            }
            GitCommand::RevParse { revision, .. } if revision.ends_with("^{commit}") => {
                format!("{}\n", "3".repeat(40)).into_bytes()
            }
            GitCommand::RevParse { .. } => format!("{}\n", "4".repeat(40)).into_bytes(),
            GitCommand::LsTree { .. } => self.tree.clone(),
            GitCommand::CatBlob { object, .. } => self.blobs[&object].clone(),
            GitCommand::LsRemote { .. } => panic!("named-ref fixture does not discover HEAD"),
            GitCommand::WorktreeInfo { .. } | GitCommand::WorktreeStatus { .. } => {
                panic!("remote fixture does not inspect a worktree")
            }
        };
        Ok(GitResult {
            stdout,
            stderr: Vec::new(),
        })
    }

    fn verify_cache(&self, path: &std::path::Path) -> Result<()> {
        if path.join("valid").is_file() {
            Ok(())
        } else {
            Err(grimoire_core::CoreError::Source(
                "invalid fixture cache".into(),
            ))
        }
    }
}

impl GitRunner for PrunableGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        let stdout = match command {
            GitCommand::LsTree { tree, .. } => {
                self.visited.lock().unwrap().push(tree.clone());
                self.trees
                    .get(&tree)
                    .unwrap_or_else(|| panic!("visited pruned tree {tree}"))
                    .clone()
            }
            GitCommand::CatBlob { object, .. } => self.blobs[&object].clone(),
            other => panic!("unexpected prunable fixture command: {other:?}"),
        };
        Ok(GitResult {
            stdout,
            stderr: Vec::new(),
        })
    }
}

#[test]
fn git_tree_walk_never_enumerates_an_ignored_subtree() {
    let root = "4".repeat(40);
    let target = "5".repeat(40);
    let skills = "6".repeat(40);
    let fixture = "7".repeat(40);
    let manifest = "8".repeat(40);
    let manifest_bytes = b"---\nname: fixture\n---\n".to_vec();
    let git = PrunableGit {
        trees: BTreeMap::from([
            (
                root.clone(),
                format!(
                    "040000 tree {skills} -\tskills\0\
                     040000 tree {target} -\ttarget\0"
                )
                .into_bytes(),
            ),
            (
                skills.clone(),
                format!("040000 tree {fixture} -\tfixture\0").into_bytes(),
            ),
            (
                fixture.clone(),
                format!(
                    "100644 blob {manifest} {}\tSKILL.md\0",
                    manifest_bytes.len()
                )
                .into_bytes(),
            ),
        ]),
        blobs: BTreeMap::from([(manifest, manifest_bytes)]),
        visited: Mutex::new(Vec::new()),
    };
    let snapshot = GitSnapshot {
        identity: CanonicalIdentity::remote("github:example/fixture").unwrap(),
        requested_ref: Some("main".into()),
        fetched_ref: "refs/heads/main".into(),
        commit: "3".repeat(40),
        tree: root.clone(),
        bare_repository: PathBuf::from("/fixture.git"),
    };

    let inventory = scan(&GitTreeReader::new(&git, &snapshot)).unwrap();

    assert_eq!(inventory.skills[0].name, "fixture");
    let visited = git.visited.lock().unwrap();
    assert_eq!(visited.iter().filter(|tree| *tree == &root).count(), 2);
    assert_eq!(visited.iter().filter(|tree| *tree == &skills).count(), 2);
    assert_eq!(visited.iter().filter(|tree| *tree == &fixture).count(), 2);
    assert!(!visited.contains(&target));
}

#[test]
fn one_untrusted_git_tree_becomes_a_verified_review_and_candidate() {
    let skill_oid = "1".repeat(40);
    let script_oid = "2".repeat(40);
    let skill = b"---\nname: fixture\n---\n".to_vec();
    let script = b"#!/bin/sh\necho SHOULD_NOT_RUN\n".to_vec();
    let tree = format!(
        "100644 blob {skill_oid} {}\tfixture/SKILL.md\0\
         100755 blob {script_oid} {}\tfixture/run.sh\0",
        skill.len(),
        script.len()
    )
    .into_bytes();
    let git = FixtureGit {
        blobs: BTreeMap::from([(skill_oid, skill), (script_oid, script)]),
        tree,
    };
    let snapshot = GitSnapshot {
        identity: CanonicalIdentity::remote("github:example/fixture").unwrap(),
        requested_ref: Some("main".into()),
        fetched_ref: "refs/heads/main".into(),
        commit: "3".repeat(40),
        tree: "4".repeat(40),
        bare_repository: PathBuf::from("/fixture.git"),
    };
    let reader = GitTreeReader::new(&git, &snapshot);
    let inventory = scan(&reader).unwrap();
    assert!(inventory.is_valid());
    assert_eq!(inventory.skills[0].name, "fixture");
    assert!(inventory.skills[0].files[1].executable);

    let candidate = CandidateRecord::new(
        "a".repeat(64),
        snapshot.identity,
        Some(snapshot.commit),
        Some(snapshot.tree),
        inventory.inventory_digest.to_string(),
        inventory.review_tree_digest.to_string(),
    )
    .unwrap();
    let temp = tempfile::tempdir().unwrap();
    let export = ReviewExport::write(
        temp.path(),
        candidate.source_key(),
        candidate.review_key().unwrap(),
        &inventory,
        &reader,
    )
    .unwrap();
    assert_eq!(export.entries.len(), 2);
    assert!(!export.root.join("tree").exists());
    assert_eq!(
        CandidateRecord::parse(
            &candidate.to_bytes().unwrap(),
            Some(&candidate.source_key())
        )
        .unwrap()
        .review_key()
        .unwrap(),
        export.review_key
    );
}

#[test]
fn remote_fetch_workflow_is_inert_until_candidate_publication() {
    let skill_oid = "1".repeat(40);
    let skill = b"---\nname: fixture\n---\n".to_vec();
    let git = FixtureGit {
        blobs: BTreeMap::from([(skill_oid.clone(), skill.clone())]),
        tree: format!(
            "100644 blob {skill_oid} {}\tfixture/SKILL.md\0",
            skill.len()
        )
        .into_bytes(),
    };
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    std::fs::create_dir_all(&project).unwrap();
    std::fs::create_dir_all(&home).unwrap();
    let manifest = b"schema = \"grimoire/manifest@2\"\n[sources.repo]\nurl = \"github:example/fixture\"\nref = \"main\"\n";
    std::fs::write(project.join("grimoire.toml"), manifest).unwrap();
    let paths = Paths::project(project.clone(), home.clone()).unwrap();

    let info = fetch_source(paths.clone(), SourceAlias::new("repo").unwrap(), &git).unwrap();

    assert_eq!(info.inventory.skills[0].name, "fixture");
    assert_eq!(
        std::fs::read(project.join("grimoire.toml")).unwrap(),
        manifest
    );
    assert!(paths
        .candidate_path(&paths.scope_key(), &SourceAlias::new("repo").unwrap())
        .is_file());
    assert!(paths.git_cache_path(&info.candidate.source_key()).is_dir());
    assert!(!paths.trust_path().exists());
    assert!(!paths.lock_path().exists());
    assert!(!home.join("store/checkouts").exists());
}

#[test]
fn omitted_head_discovery_and_fetch_share_one_deadline() {
    let runner = DeadlineGit::default();
    let temporary = tempfile::tempdir().unwrap();

    let snapshot = fetch_remote(
        &runner,
        "github:example/fixture",
        None,
        &temporary.path().join("candidate.git"),
    )
    .unwrap();

    assert_eq!(snapshot.fetched_ref, "refs/heads/main");
    let deadlines = runner.deadlines.lock().unwrap();
    assert_eq!(deadlines.len(), 5);
    assert!(deadlines.iter().all(|deadline| *deadline == deadlines[0]));
}
