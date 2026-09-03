use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{CanonicalIdentity, CoreError, Paths, Result, SourceKey};
use skill_grimoire::command::{run_from, Console};
use skill_grimoire::env::Environment;
use skill_grimoire::runtime::SystemGitRunner;
use tempfile::tempdir;

const REMOTE_URL: &str = "https://fixture.invalid/grimoire-offline.git";

struct FixtureRemoteGit {
    system: SystemGitRunner,
    remote: PathBuf,
    calls: AtomicUsize,
}

impl FixtureRemoteGit {
    fn new(remote: PathBuf) -> Self {
        Self {
            system: SystemGitRunner::default(),
            remote,
            calls: AtomicUsize::new(0),
        }
    }

    fn map_remote(&self, command: GitCommand) -> GitCommand {
        let fixture = self.remote.display().to_string();
        match command {
            GitCommand::LsRemote { repository } => {
                assert_eq!(repository, REMOTE_URL);
                GitCommand::LsRemote {
                    repository: fixture,
                }
            }
            GitCommand::Fetch {
                bare_repository,
                repository,
                source_ref,
            } => {
                assert_eq!(repository, REMOTE_URL);
                GitCommand::Fetch {
                    bare_repository,
                    repository: fixture,
                    source_ref,
                }
            }
            other => other,
        }
    }

    fn calls(&self) -> usize {
        self.calls.load(Ordering::SeqCst)
    }
}

impl GitRunner for FixtureRemoteGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.system.run(self.map_remote(command))
    }

    fn run_until(&self, command: GitCommand, deadline: Instant) -> Result<GitResult> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.system.run_until(self.map_remote(command), deadline)
    }

    fn verify_cache(&self, path: &Path) -> Result<()> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.system.verify_cache(path)
    }

    fn stream(
        &self,
        command: GitCommand,
        maximum_chunk: usize,
        visitor: &mut dyn FnMut(&[u8]) -> Result<bool>,
    ) -> Result<GitResult> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.system
            .stream(self.map_remote(command), maximum_chunk, visitor)
    }
}

#[derive(Default)]
struct FailOnGit {
    calls: AtomicUsize,
}

struct FixedEnvironment {
    root: PathBuf,
    home: PathBuf,
}

impl Environment for FixedEnvironment {
    fn current_dir(&self) -> std::io::Result<PathBuf> {
        Ok(self.root.clone())
    }

    fn var_os(&self, name: &str) -> Option<OsString> {
        (name == "HOME").then(|| self.home.clone().into_os_string())
    }
}

#[derive(Default)]
struct BufferConsole {
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}

impl Console for BufferConsole {
    fn is_terminal(&self) -> bool {
        false
    }

    fn read_line(&mut self, _line: &mut String) -> std::io::Result<usize> {
        Ok(0)
    }

    fn write_stdout(&mut self, bytes: &[u8]) -> std::io::Result<()> {
        self.stdout.extend_from_slice(bytes);
        Ok(())
    }

    fn write_stderr(&mut self, bytes: &[u8]) -> std::io::Result<()> {
        self.stderr.extend_from_slice(bytes);
        Ok(())
    }
}

impl GitRunner for FailOnGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Err(CoreError::Transport(format!(
            "frozen reconciliation attempted Git: {command:?}"
        )))
    }

    fn verify_cache(&self, path: &Path) -> Result<()> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Err(CoreError::Transport(format!(
            "frozen reconciliation inspected Git cache: {}",
            path.display()
        )))
    }
}

#[test]
fn committed_state_reproduces_in_another_home_with_transport_disabled() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let remote = build_remote(&root);

    let home_a = root.join("home-a");
    let project_a = root.join("project-a");
    fs::create_dir_all(&home_a).unwrap();
    fs::create_dir_all(&project_a).unwrap();
    let git_a = FixtureRemoteGit::new(remote.clone());
    succeed(&run_with_git(&project_a, &home_a, &["init"], &git_a));
    succeed(&run_with_git(
        &project_a,
        &home_a,
        &[
            "source", "add", "fixture", REMOTE_URL, "--ref", "main", "--trust",
        ],
        &git_a,
    ));
    succeed(&run_with_git(
        &project_a,
        &home_a,
        &["install", "one", "--source", "fixture"],
        &git_a,
    ));
    let manifest = fs::read(project_a.join("grimoire.toml")).unwrap();
    let lock = fs::read(project_a.join("grimoire.lock")).unwrap();

    let home_b = root.join("home-b");
    let project_b = root.join("project-b");
    fs::create_dir_all(&home_b).unwrap();
    fs::create_dir_all(&project_b).unwrap();
    fs::write(project_b.join("grimoire.toml"), &manifest).unwrap();
    fs::write(project_b.join("grimoire.lock"), &lock).unwrap();
    let git_b = FixtureRemoteGit::new(remote);
    succeed(&run_with_git(
        &project_b,
        &home_b,
        &["source", "fetch", "fixture"],
        &git_b,
    ));
    succeed(&run_with_git(
        &project_b,
        &home_b,
        &["source", "trust", "fixture"],
        &git_b,
    ));
    succeed(&run_with_git(&project_b, &home_b, &["install"], &git_b));
    assert!(git_b.calls() > 0);
    assert_eq!(fs::read(project_b.join("grimoire.toml")).unwrap(), manifest);
    assert_eq!(fs::read(project_b.join("grimoire.lock")).unwrap(), lock);

    let home_b_state = home_b.join(".grimoire");
    let b_link = project_b.join(".agents/skills/one");
    assert_link_in_home(&b_link, &home_b_state);
    fs::remove_file(&b_link).unwrap();
    remove_if_present(&home_b_state.join("candidates"));
    remove_if_present(&home_b_state.join("cache"));
    let trust_before = fs::read(home_b_state.join("trust.json")).unwrap();

    let project_b_frozen = root.join("project-b-frozen");
    fs::create_dir_all(&project_b_frozen).unwrap();
    fs::write(project_b_frozen.join("grimoire.toml"), &manifest).unwrap();
    fs::write(project_b_frozen.join("grimoire.lock"), &lock).unwrap();
    let offline = FailOnGit::default();
    succeed(&run_with_git(
        &project_b_frozen,
        &home_b,
        &["install", "--frozen"],
        &offline,
    ));

    assert_eq!(offline.calls.load(Ordering::SeqCst), 0);
    assert_eq!(
        fs::read(project_b_frozen.join("grimoire.toml")).unwrap(),
        manifest
    );
    assert_eq!(
        fs::read(project_b_frozen.join("grimoire.lock")).unwrap(),
        lock
    );
    assert_eq!(
        fs::read(home_b_state.join("trust.json")).unwrap(),
        trust_before
    );
    assert!(!home_b_state.join("candidates").exists());
    assert!(!home_b_state.join("cache").exists());
    assert_link_in_home(&project_b_frozen.join(".agents/skills/one"), &home_b_state);

    let source_key = SourceKey::derive(&CanonicalIdentity::remote(REMOTE_URL).unwrap());
    let paths = Paths::project(project_b_frozen, home_b_state.clone()).unwrap();
    assert!(paths
        .skills_dir()
        .join("one")
        .read_link()
        .unwrap()
        .starts_with(
            home_b_state
                .join("store/checkouts")
                .join(source_key.as_str())
        ));
}

fn build_remote(root: &Path) -> PathBuf {
    let source = root.join("source");
    let remote = root.join("remote.git");
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: offline fixture\n---\n",
    )
    .unwrap();
    git(&source, &["init", "-q", "-b", "main"]);
    git(&source, &["add", "."]);
    git(
        &source,
        &[
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            "fixture",
        ],
    );
    git(
        root,
        &[
            "clone",
            "-q",
            "--bare",
            source.to_str().unwrap(),
            remote.to_str().unwrap(),
        ],
    );
    remote
}

fn git(directory: &Path, args: &[&str]) {
    assert!(Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap()
        .success());
}

fn run_with_git(
    root: &Path,
    home: &Path,
    args: &[&str],
    git: &dyn GitRunner,
) -> (u8, Vec<u8>, Vec<u8>) {
    let environment = FixedEnvironment {
        root: root.to_path_buf(),
        home: home.to_path_buf(),
    };
    let mut console = BufferConsole::default();
    let code = run_from(
        std::iter::once("grimoire").chain(args.iter().copied()),
        &environment,
        &mut console,
        git,
    );
    (code, console.stdout, console.stderr)
}

fn succeed(output: &(u8, Vec<u8>, Vec<u8>)) {
    assert_eq!(
        output.0,
        0,
        "stdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.1),
        String::from_utf8_lossy(&output.2)
    );
}

fn remove_if_present(path: &Path) {
    if path.exists() {
        fs::remove_dir_all(path).unwrap();
    }
}

fn assert_link_in_home(link: &Path, home: &Path) {
    let target = fs::read_link(link).unwrap();
    assert!(
        target.starts_with(home.join("store/checkouts")),
        "{target:?}"
    );
}
