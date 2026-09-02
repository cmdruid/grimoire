mod support;

use std::fs;
use std::process::Command;

use tempfile::tempdir;

#[test]
fn initializes_default_explicit_and_global_scopes_through_core() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    let explicit = temporary.path().join("explicit");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&explicit).unwrap();

    let output = support::run(&project, &home, &["init"]);
    assert!(output.status.success(), "{}", support::stderr(&output));
    assert_eq!(
        fs::read(project.join("grimoire.toml")).unwrap(),
        b"schema = \"grimoire/manifest@1\"\n"
    );
    assert!(fs::read(project.join("grimoire.lock"))
        .unwrap()
        .starts_with(b"{\n  \"schema\": \"grimoire/lock@1\""));
    assert!(support::stdout(&output).contains("Applied."));

    let output = support::run(
        &project,
        &home,
        &["init", "--project", explicit.to_str().unwrap()],
    );
    assert!(output.status.success(), "{}", support::stderr(&output));
    assert!(explicit.join("grimoire.toml").is_file());
    assert!(explicit.join("grimoire.lock").is_file());

    let output = support::run(&project, &home, &["init", "--global"]);
    assert!(output.status.success(), "{}", support::stderr(&output));
    assert!(home.join(".grimoire/grimoire.toml").is_file());
    assert!(home.join(".grimoire/grimoire.lock").is_file());
}

#[test]
fn repeat_init_is_a_usage_failure() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    assert!(support::run(&project, &home, &["init"]).status.success());

    let output = support::run(&project, &home, &["init"]);
    assert_eq!(output.status.code(), Some(2));
    assert!(support::stderr(&output).contains("already initialized"));
}

#[test]
fn help_and_version_exit_before_environment_resolution() {
    let temporary = tempdir().unwrap();
    let missing = temporary.path().join("missing-cwd");
    let binary = env!("CARGO_BIN_EXE_grimoire");

    for argument in ["--help", "--version"] {
        let output = Command::new(binary)
            .env_remove("HOME")
            .env("GRIMOIRE_HOME", "relative")
            .arg(argument)
            .output()
            .unwrap();
        assert!(output.status.success(), "{}", support::stderr(&output));
        assert!(output.stderr.is_empty());
    }

    let output = Command::new(binary)
        .env_remove("HOME")
        .env("GRIMOIRE_HOME", "relative")
        .arg("init")
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert!(support::stderr(&output).contains("HOME is not set"));
    assert!(!missing.exists());
}

#[test]
fn conflicting_init_scope_flags_are_rejected_by_clap() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    let output = support::run(&project, &home, &["init", "--global", "--project", "."]);
    assert_eq!(output.status.code(), Some(2));
    assert!(!project.join("grimoire.toml").exists());
}
