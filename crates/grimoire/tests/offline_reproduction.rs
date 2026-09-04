use std::collections::VecDeque;
use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{CoreError, Result};
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
    terminal: bool,
    answers: VecDeque<String>,
}

impl BufferConsole {
    fn approving() -> Self {
        Self {
            terminal: true,
            answers: VecDeque::from(["yes\n".into()]),
            ..Self::default()
        }
    }
}

impl Console for BufferConsole {
    fn is_terminal(&self) -> bool {
        self.terminal
    }

    fn read_line(&mut self, line: &mut String) -> std::io::Result<usize> {
        let answer = self.answers.pop_front().unwrap_or_default();
        let length = answer.len();
        line.push_str(&answer);
        Ok(length)
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
#[ignore = "schema 3 drops install --vendor and vendor receipts; unit 3 retargets clone-and-go to copies"]
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
            "source",
            "add",
            "fixture",
            REMOTE_URL,
            "--ref",
            "main",
            "--trust-all",
        ],
        &git_a,
    ));
    succeed(&run_with_git(
        &project_a,
        &home_a,
        &["install", "one", "--source", "fixture", "--vendor"],
        &git_a,
    ));
    assert!(git_a.calls() > 0);

    git(&project_a, &["init", "-q", "-b", "main"]);
    git(
        &project_a,
        &["add", "grimoire.toml", "grimoire.lock", "vendor"],
    );
    git(
        &project_a,
        &[
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            "committed vendor projection",
        ],
    );
    let manifest = fs::read(project_a.join("grimoire.toml")).unwrap();
    let lock = fs::read(project_a.join("grimoire.lock")).unwrap();
    let vendor = fs::read(project_a.join("vendor/grimoire/fixture/one/SKILL.md")).unwrap();

    let home_b = root.join("home-b");
    let project_b = root.join("project-b");
    fs::create_dir_all(&home_b).unwrap();
    git(
        &root,
        &[
            "clone",
            "-q",
            project_a.to_str().unwrap(),
            project_b.to_str().unwrap(),
        ],
    );
    let offline = FailOnGit::default();
    succeed(&run_approving(
        &project_b,
        &home_b,
        &["source", "trust", "fixture", "--vendor"],
        &offline,
    ));
    let trust = fs::read(home_b.join(".grimoire/trust.json")).unwrap();
    succeed(&run_with_git(
        &project_b,
        &home_b,
        &["install", "--frozen"],
        &offline,
    ));
    succeed(&run_with_git(&project_b, &home_b, &["check"], &offline));

    assert_eq!(offline.calls.load(Ordering::SeqCst), 0);
    assert_eq!(fs::read(project_b.join("grimoire.toml")).unwrap(), manifest);
    assert_eq!(fs::read(project_b.join("grimoire.lock")).unwrap(), lock);
    assert_eq!(
        fs::read(project_b.join("vendor/grimoire/fixture/one/SKILL.md")).unwrap(),
        vendor
    );
    assert_eq!(
        fs::read(home_b.join(".grimoire/trust.json")).unwrap(),
        trust
    );
    assert_eq!(
        fs::read_link(project_b.join(".agents/skills/one")).unwrap(),
        PathBuf::from("../../vendor/grimoire/fixture/one")
    );
    assert!(!home_b.join(".grimoire/candidates").exists());
    assert!(!home_b.join(".grimoire/cache").exists());
    assert!(!home_b.join(".grimoire/store").exists());
    assert!(Command::new("git")
        .current_dir(&project_b)
        .args(["diff", "--exit-code"])
        .status()
        .unwrap()
        .success());
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

fn run_approving(
    root: &Path,
    home: &Path,
    args: &[&str],
    git: &dyn GitRunner,
) -> (u8, Vec<u8>, Vec<u8>) {
    let environment = FixedEnvironment {
        root: root.to_path_buf(),
        home: home.to_path_buf(),
    };
    let mut console = BufferConsole::approving();
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
