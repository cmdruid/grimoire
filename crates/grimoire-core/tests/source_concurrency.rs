use std::sync::mpsc;
use std::time::Duration;

use grimoire_core::source::{
    CandidateWorkflow, CanonicalIdentity, GitCommand, GitResult, GitRunner, SourceKey,
};
use grimoire_core::{CoreError, Paths, Result, SourceAlias};

struct CacheRunner;

impl GitRunner for CacheRunner {
    fn run(&self, _command: GitCommand) -> Result<GitResult> {
        panic!("cache recovery does not run Git")
    }

    fn verify_cache(&self, path: &std::path::Path) -> Result<()> {
        match std::fs::read(path.join("generation")) {
            Ok(bytes) if bytes.starts_with(b"valid:") => Ok(()),
            _ => Err(CoreError::Source("invalid test cache".into())),
        }
    }
}

#[test]
fn same_scope_alias_candidate_mutex_serializes_the_entire_workflow() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    std::fs::create_dir_all(&project).unwrap();
    std::fs::create_dir_all(&home).unwrap();
    let paths = Paths::project(project, home).unwrap();
    let alias = SourceAlias::new("repo").unwrap();
    let first = CandidateWorkflow::begin(paths.clone(), alias.clone()).unwrap();

    let (started_tx, started_rx) = mpsc::channel();
    let (acquired_tx, acquired_rx) = mpsc::channel();
    let worker = std::thread::spawn(move || {
        started_tx.send(()).unwrap();
        let second = CandidateWorkflow::begin(paths, alias).unwrap();
        acquired_tx.send(()).unwrap();
        drop(second);
    });
    started_rx.recv().unwrap();
    assert!(acquired_rx.recv_timeout(Duration::from_millis(50)).is_err());
    drop(first);
    acquired_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    worker.join().unwrap();
}

#[test]
fn source_key_cache_mutex_serializes_different_scopes() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let first_project = root.join("one");
    let second_project = root.join("two");
    for path in [&home, &first_project, &second_project] {
        std::fs::create_dir_all(path).unwrap();
    }
    let source = SourceKey::derive(&CanonicalIdentity::remote("github:org/repo").unwrap());
    let mut first = CandidateWorkflow::begin(
        Paths::project(first_project, home.clone()).unwrap(),
        SourceAlias::new("one").unwrap(),
    )
    .unwrap();
    let mut second = CandidateWorkflow::begin(
        Paths::project(second_project, home).unwrap(),
        SourceAlias::new("two").unwrap(),
    )
    .unwrap();

    let (entered_tx, entered_rx) = mpsc::channel();
    let (release_tx, release_rx) = mpsc::channel();
    let source_one = source.clone();
    let first_worker = std::thread::spawn(move || {
        first
            .with_cache(&source_one, |_| {
                entered_tx.send(()).unwrap();
                release_rx.recv().unwrap();
                Ok(())
            })
            .unwrap();
    });
    entered_rx.recv().unwrap();

    let (second_tx, second_rx) = mpsc::channel();
    let second_worker = std::thread::spawn(move || {
        second
            .with_cache(&source, |_| {
                second_tx.send(()).unwrap();
                Ok(())
            })
            .unwrap();
    });
    assert!(second_rx.recv_timeout(Duration::from_millis(50)).is_err());
    release_tx.send(()).unwrap();
    second_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    first_worker.join().unwrap();
    second_worker.join().unwrap();
}

#[test]
fn interrupted_cache_swap_recovers_one_generation_before_replacement() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    std::fs::create_dir_all(&project).unwrap();
    let paths = Paths::project(project, home).unwrap();
    let source = SourceKey::derive(&CanonicalIdentity::remote("github:org/repo").unwrap());
    let fixed = paths.git_cache_path(&source);
    let parent = fixed.parent().unwrap();
    let previous = parent.join(format!(".{source}.previous"));
    std::fs::create_dir_all(&previous).unwrap();
    std::fs::write(previous.join("generation"), b"valid:old").unwrap();

    let mut workflow = CandidateWorkflow::begin(paths, SourceAlias::new("repo").unwrap()).unwrap();
    workflow
        .replace_cache(&source, &CacheRunner, |replacement| {
            assert_eq!(
                std::fs::read(fixed.join("generation")).unwrap(),
                b"valid:old"
            );
            std::fs::create_dir(replacement).unwrap();
            std::fs::write(replacement.join("generation"), b"valid:new").unwrap();
            Ok(())
        })
        .unwrap();

    assert_eq!(
        std::fs::read(fixed.join("generation")).unwrap(),
        b"valid:new"
    );
    assert!(!previous.exists());
    assert!(!parent.join(format!(".{source}.replacement")).exists());
}
