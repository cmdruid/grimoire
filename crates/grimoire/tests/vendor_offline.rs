#![cfg(unix)]

use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::ffi::OsString;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{
    verify_vendor_tree, CoreError, LockSkill, LockSource, Lockfile, Paths, ProjectionMode,
    RequestRoot, Result, SourceAlias,
};
use skill_grimoire::command::{run_from, Console};
use skill_grimoire::env::Environment;

#[derive(Default)]
struct OfflineGit(AtomicUsize);

impl GitRunner for OfflineGit {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        self.0.fetch_add(1, Ordering::SeqCst);
        Err(CoreError::Transport(format!(
            "offline CLI attempted Git: {command:?}"
        )))
    }

    fn verify_cache(&self, path: &Path) -> Result<()> {
        self.0.fetch_add(1, Ordering::SeqCst);
        Err(CoreError::Transport(format!(
            "offline CLI inspected Git cache: {}",
            path.display()
        )))
    }
}

struct FixedEnvironment {
    project: PathBuf,
    home: PathBuf,
}

impl Environment for FixedEnvironment {
    fn current_dir(&self) -> std::io::Result<PathBuf> {
        Ok(self.project.clone())
    }

    fn var_os(&self, name: &str) -> Option<OsString> {
        (name == "HOME").then(|| self.home.clone().into_os_string())
    }
}

#[derive(Default)]
struct TestConsole {
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    answers: VecDeque<String>,
}

impl Console for TestConsole {
    fn is_terminal(&self) -> bool {
        true
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

#[test]
fn cli_checks_a_committed_copy_offline_and_frozen_does_not_recreate_it() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&home).unwrap();
    let project = project.canonicalize().unwrap();
    let home = home.canonicalize().unwrap();
    let environment = FixedEnvironment {
        project: project.clone(),
        home: home.clone(),
    };
    let paths = Paths::project(project.clone(), home.join(".grimoire")).unwrap();
    let alias = SourceAlias::new("repo").unwrap();
    let skill = grimoire_core::SkillName::new("one").unwrap();
    let vendor = paths.vendor_path(&alias, &skill).unwrap();
    let vendor_bytes = b"---\nname: one\ndescription: committed CLI fixture\n---\n";
    fs::create_dir_all(&vendor).unwrap();
    fs::set_permissions(&vendor, fs::Permissions::from_mode(0o755)).unwrap();
    fs::write(vendor.join("SKILL.md"), vendor_bytes).unwrap();
    fs::set_permissions(vendor.join("SKILL.md"), fs::Permissions::from_mode(0o644)).unwrap();
    let content = verify_vendor_tree(&vendor, &skill).unwrap();

    let manifest = b"schema = \"grimoire/manifest@3\"\n[sources.repo]\nurl = \"github:org/repo\"\nref = \"main\"\n[skills]\none = { source = \"repo\" }\n".to_vec();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            alias.clone(),
            LockSource::Git {
                declared: "github:org/repo".into(),
                reference: Some("main".into()),
                commit: "1".repeat(40),
                tree: "2".repeat(40),
                inventory: format!("sha256:{}", "3".repeat(64)),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            skill.clone(),
            LockSkill {
                source: alias,
                mode: ProjectionMode::Vendor,
                path: "skills/one".into(),
                content,
                requested_by: BTreeSet::from([RequestRoot::Skill(skill)]),
            },
        )]),
    }
    .to_bytes()
    .unwrap();
    fs::write(paths.manifest_path(), &manifest).unwrap();
    fs::write(paths.lock_path(), &lock).unwrap();

    let git = OfflineGit::default();
    let mut install_console = TestConsole::default();
    assert_eq!(
        run(
            &environment,
            &git,
            &mut install_console,
            &["install", "--frozen"]
        ),
        0,
        "{}",
        String::from_utf8_lossy(&install_console.stderr)
    );
    let copy = paths.skills_dir().join("one");
    assert!(copy.is_dir());
    assert!(!copy.symlink_metadata().unwrap().file_type().is_symlink());
    assert!(!copy.join("vendor").exists());

    let mut check_console = TestConsole::default();
    assert_eq!(run(&environment, &git, &mut check_console, &["check"]), 0);
    assert!(check_console.stdout.is_empty());
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
    assert_eq!(fs::read(paths.manifest_path()).unwrap(), manifest);
    assert_eq!(fs::read(paths.lock_path()).unwrap(), lock);
    assert_eq!(fs::read(vendor.join("SKILL.md")).unwrap(), vendor_bytes);
    assert!(!home.join(".grimoire/cache").exists());
    assert!(!home.join(".grimoire/candidates").exists());
    assert!(!home.join(".grimoire/store").exists());
    assert!(!project.join("vendor/grimoire").exists());

    fs::write(vendor.join("SKILL.md"), b"changed\n").unwrap();
    let mut drifted = TestConsole::default();
    assert_eq!(
        run(&environment, &git, &mut drifted, &["install", "--frozen"]),
        3
    );
    assert!(String::from_utf8_lossy(&drifted.stdout).contains("vendor-drift"));
    fs::write(vendor.join("SKILL.md"), vendor_bytes).unwrap();

    fs::remove_dir_all(&copy).unwrap();
    let mut missing = TestConsole::default();
    assert_eq!(
        run(&environment, &git, &mut missing, &["install", "--frozen"]),
        3
    );
    assert!(String::from_utf8_lossy(&missing.stdout).contains("vendor-missing"));
    assert!(!copy.exists());
    assert_eq!(git.0.load(Ordering::SeqCst), 0);
}

fn run(
    environment: &FixedEnvironment,
    git: &OfflineGit,
    console: &mut TestConsole,
    args: &[&str],
) -> u8 {
    run_from(
        std::iter::once("grimoire").chain(args.iter().copied()),
        environment,
        console,
        git,
    )
}
