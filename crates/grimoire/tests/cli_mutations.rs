mod support;

use std::fs;
use std::process::Command;

use tempfile::tempdir;

fn git(directory: &std::path::Path, args: &[&str]) {
    let status = Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap();
    assert!(status.success(), "git {args:?}");
}

fn commit(source: &std::path::Path, body: &str) {
    fs::write(
        source.join("skills/one/SKILL.md"),
        format!("---\nname: one\ndescription: fixture\n---\n{body}\n"),
    )
    .unwrap();
    fs::write(
        source.join("skills/two/SKILL.md"),
        format!("---\nname: two\ndescription: fixture\n---\n{body}\n"),
    )
    .unwrap();
    git(source, &["add", "."]);
    git(
        source,
        &[
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            body,
        ],
    );
}

#[test]
fn install_update_frozen_and_uninstall_share_the_transaction_path() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::create_dir_all(source.join("skills/two")).unwrap();
    fs::write(
        source.join("PACK.md"),
        b"---\nschema: grimoire/pack@1\nname: bundle\ndescription: Fixture bundle.\nrequired:\n  - one\noptional:\n  - two\n---\n",
    )
    .unwrap();
    git(&source, &["init", "-q"]);
    commit(&source, "first");

    assert!(support::run(&project, &home, &["init"]).status.success());
    let added = support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "fixture",
            source.to_str().unwrap(),
            "--trust-all",
        ],
    );
    assert!(added.status.success(), "{}", support::stderr(&added));

    let installed = support::run(
        &project,
        &home,
        &["install", "bundle", "--pack", "--source", "fixture"],
    );
    assert!(
        installed.status.success(),
        "{}",
        support::stderr(&installed)
    );
    assert!(project.join(".agents/skills/one").is_symlink());
    assert!(project.join(".agents/skills/two").is_symlink());
    assert!(!fs::read_to_string(project.join("grimoire.toml"))
        .unwrap()
        .contains("mode ="));

    commit(&source, "second");
    assert!(
        support::run(&project, &home, &["source", "fetch", "fixture"])
            .status
            .success()
    );
    let refused = support::run(&project, &home, &["update"]);
    assert_eq!(refused.status.code(), Some(3));
    let updated = support::run(&project, &home, &["update", "--yes"]);
    assert!(updated.status.success(), "{}", support::stderr(&updated));
    assert!(support::stdout(&updated).contains("source_advance"));

    fs::remove_file(project.join(".agents/skills/two")).unwrap();
    let restored = support::run(&project, &home, &["install", "--frozen"]);
    assert!(restored.status.success(), "{}", support::stderr(&restored));
    assert!(project.join(".agents/skills/two").is_symlink());

    let dry = support::run(
        &project,
        &home,
        &["uninstall", "bundle", "--pack", "--dry-run"],
    );
    assert!(dry.status.success(), "{}", support::stderr(&dry));
    assert!(project.join(".agents/skills/one").is_symlink());

    let removed = support::run(&project, &home, &["remove", "bundle", "--pack", "--yes"]);
    assert!(removed.status.success(), "{}", support::stderr(&removed));
    assert!(!project.join(".agents/skills/one").exists());
    assert!(!project.join(".agents/skills/two").exists());
}

#[test]
fn invalid_install_flag_combinations_are_usage_errors() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    for args in [
        vec!["install", "one"],
        vec!["install", "--source", "fixture"],
        vec!["install", "one", "--source", "fixture", "--frozen"],
        vec![
            "install", "one", "--source", "fixture", "--link", "--vendor",
        ],
        vec![
            "install", "one", "--source", "fixture", "--vendor", "--global",
        ],
    ] {
        let output = support::run(&project, &home, &args);
        assert_eq!(output.status.code(), Some(2), "{args:?}");
    }
}
