mod support;

use std::ffi::OsString;
use std::fs;
use std::path::PathBuf;

use skill_grimoire::command::{run_from, Console};
use skill_grimoire::env::Environment;
use tempfile::tempdir;

struct TestEnvironment {
    cwd: PathBuf,
    home: PathBuf,
}

impl Environment for TestEnvironment {
    fn current_dir(&self) -> std::io::Result<PathBuf> {
        Ok(self.cwd.clone())
    }

    fn var_os(&self, name: &str) -> Option<OsString> {
        (name == "HOME").then(|| self.home.clone().into_os_string())
    }
}

struct TestConsole {
    terminal: bool,
    answer: Option<String>,
    reads: usize,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}

impl TestConsole {
    fn new(terminal: bool, answer: Option<&str>) -> Self {
        Self {
            terminal,
            answer: answer.map(str::to_owned),
            reads: 0,
            stdout: Vec::new(),
            stderr: Vec::new(),
        }
    }

    fn stdout(&self) -> String {
        String::from_utf8(self.stdout.clone()).unwrap()
    }

    fn stderr(&self) -> String {
        String::from_utf8(self.stderr.clone()).unwrap()
    }
}

impl Console for TestConsole {
    fn is_terminal(&self) -> bool {
        self.terminal
    }

    fn read_line(&mut self, line: &mut String) -> std::io::Result<usize> {
        self.reads += 1;
        match self.answer.take() {
            Some(answer) => {
                let length = answer.len();
                line.push_str(&answer);
                Ok(length)
            }
            None => Ok(0),
        }
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

fn invoke(environment: &TestEnvironment, console: &mut TestConsole, args: &[&str]) -> u8 {
    run_from(
        std::iter::once("grimoire").chain(args.iter().copied()),
        environment,
        console,
    )
}

#[test]
fn destructive_confirmation_is_tty_owned_and_defaults_to_no() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: fixture\n---\n",
    )
    .unwrap();
    let initialized = support::run(&project, &home, &["init"]);
    assert!(
        initialized.status.success(),
        "{}",
        support::stderr(&initialized)
    );
    assert!(support::stdout(&initialized).contains("Applied."));
    assert!(support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "fixture",
            source.to_str().unwrap(),
            "--live",
            "--trust-all",
        ],
    )
    .status
    .success());
    assert!(
        support::run(&project, &home, &["install", "one", "--source", "fixture"],)
            .status
            .success()
    );
    let environment = TestEnvironment {
        cwd: project.clone(),
        home,
    };

    let mut additive = TestConsole::new(true, Some("should-not-be-read\n"));
    assert_eq!(invoke(&environment, &mut additive, &["install"]), 0);
    assert_eq!(additive.reads, 0);

    let mut dry_run = TestConsole::new(true, Some("should-not-be-read\n"));
    assert_eq!(
        invoke(
            &environment,
            &mut dry_run,
            &["uninstall", "one", "--dry-run"]
        ),
        0
    );
    assert_eq!(dry_run.reads, 0);

    for answer in [Some("n\n"), Some("\n"), None] {
        let mut cancelled = TestConsole::new(true, answer);
        assert_eq!(
            invoke(&environment, &mut cancelled, &["uninstall", "one"]),
            0
        );
        assert!(cancelled.stdout().contains("Apply? [y/N] "));
        assert!(cancelled
            .stdout()
            .contains("Cancelled; no changes applied."));
        assert!(project.join(".agents/skills/one").is_symlink());
    }

    let mut refused = TestConsole::new(false, Some("yes\n"));
    assert_eq!(invoke(&environment, &mut refused, &["uninstall", "one"]), 3);
    assert_eq!(refused.reads, 0);
    assert!(refused.stderr().contains("explicit approval"));

    let mut accepted = TestConsole::new(true, Some("yes\n"));
    assert_eq!(
        invoke(&environment, &mut accepted, &["uninstall", "one"]),
        0
    );
    assert_eq!(accepted.reads, 1);
    assert!(!project.join(".agents/skills/one").exists());
}
