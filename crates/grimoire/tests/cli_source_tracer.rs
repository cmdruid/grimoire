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

#[test]
fn source_add_and_info_json_cross_the_core_review_seam() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    let source = temporary.path().join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: fixture\n---\nfixture\n",
    )
    .unwrap();
    git(&source, &["init", "-q"]);
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

    assert!(support::run(&project, &home, &["init"]).status.success());
    let output = support::run(
        &project,
        &home,
        &["source", "add", "fixture", source.to_str().unwrap()],
    );
    assert!(output.status.success(), "{}", support::stderr(&output));
    assert!(support::stdout(&output).contains("replace_candidate"));

    let output = support::run(&project, &home, &["source", "info", "fixture", "--json"]);
    assert!(output.status.success(), "{}", support::stderr(&output));
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["schema"], "grimoire/source-info@1");
    assert_eq!(value["alias"], "fixture");
    assert_eq!(value["trust"]["mode"], "untrusted");
    assert_eq!(value["skills"][0]["name"], "one");
}

#[test]
fn source_info_requires_an_explicit_current_candidate() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    assert!(support::run(&project, &home, &["init"]).status.success());
    let output = support::run(&project, &home, &["source", "info", "missing", "--json"]);
    assert_eq!(output.status.code(), Some(2));
    assert!(support::stderr(&output).contains("not declared"));
}
