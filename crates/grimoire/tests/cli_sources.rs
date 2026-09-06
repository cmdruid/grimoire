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
fn source_review_trust_refresh_revoke_and_remove_workflow() {
    let temporary = tempdir().unwrap();
    let home = temporary.path().join("home");
    let project = temporary.path().join("project");
    let source = temporary.path().join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(source.join("skills/one")).unwrap();
    git(&source, &["init", "-q"]);
    commit(&source, "first");

    assert!(support::run(&project, &home, &["init"]).status.success());
    assert!(support::run(
        &project,
        &home,
        &["source", "add", "fixture", source.to_str().unwrap()]
    )
    .status
    .success());

    let listed = support::run(&project, &home, &["source", "list"]);
    assert!(listed.status.success(), "{}", support::stderr(&listed));
    assert!(support::stdout(&listed).contains("fixture\tpinned"));

    let initial_diff = support::run(&project, &home, &["source", "diff", "fixture"]);
    assert!(initial_diff.status.success());
    assert!(support::stdout(&initial_diff).contains("added\tskill/one"));

    let trusted = support::run(&project, &home, &["source", "trust", "fixture"]);
    assert!(trusted.status.success(), "{}", support::stderr(&trusted));
    let catalog = support::run(&project, &home, &["trust", "list"]);
    let catalog_text = support::stdout(&catalog);
    assert!(catalog.status.success(), "{}", support::stderr(&catalog));
    assert!(catalog_text.contains("receipts=1"));
    assert!(catalog_text.contains("fixture"));

    commit(&source, "second");
    let fetched = support::run(&project, &home, &["source", "fetch", "fixture"]);
    assert!(fetched.status.success(), "{}", support::stderr(&fetched));
    let changed = support::run(&project, &home, &["source", "diff", "fixture"]);
    assert!(changed.status.success(), "{}", support::stderr(&changed));
    assert!(support::stdout(&changed).contains("changed\tskill/one"));

    let all = support::run(&project, &home, &["source", "trust", "fixture", "--all"]);
    assert!(all.status.success(), "{}", support::stderr(&all));
    let catalog = support::run(&project, &home, &["trust", "list"]);
    assert!(support::stdout(&catalog).contains("all=true"));

    let rejected = support::run(&project, &home, &["source", "trust", "fixture", "--yes"]);
    assert_eq!(rejected.status.code(), Some(2));

    let revoke = support::run(
        &project,
        &home,
        &["source", "trust", "fixture", "--revoke", "--yes"],
    );
    assert!(revoke.status.success(), "{}", support::stderr(&revoke));

    let refused = support::run(&project, &home, &["source", "remove", "fixture"]);
    assert_eq!(refused.status.code(), Some(3));
    assert!(support::stderr(&refused).contains("explicit approval"));
    let removed = support::run(&project, &home, &["source", "remove", "fixture", "--yes"]);
    assert!(removed.status.success(), "{}", support::stderr(&removed));
    let listed = support::run(&project, &home, &["source", "list"]);
    assert!(listed.status.success());
    assert!(!support::stdout(&listed).contains("fixture"));
}
