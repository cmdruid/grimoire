mod support;

use std::fs;
use std::process::Command;

use tempfile::tempdir;

fn git(directory: &std::path::Path, args: &[&str]) {
    assert!(Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap()
        .success());
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

fn success(output: &std::process::Output) {
    assert!(output.status.success(), "{}", support::stderr(output));
}

#[test]
fn cached_source_workflow_never_fetches_during_update() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(source.join("skills/one")).unwrap();
    git(&source, &["init", "-q"]);
    commit(&source, "first");

    success(&support::run(&project, &home, &["init"]));
    success(&support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "fixture",
            source.to_str().unwrap(),
            "--trust-all",
        ],
    ));
    success(&support::run(
        &project,
        &home,
        &["install", "one", "--source", "fixture"],
    ));
    let first: serde_json::Value = serde_json::from_slice(
        &support::run(&project, &home, &["source", "info", "fixture", "--json"]).stdout,
    )
    .unwrap();
    assert_eq!(first["trust"]["mode"], "all");
    assert_eq!(first["trust"]["vendor_receipts"], 0);

    commit(&source, "second");
    success(&support::run(&project, &home, &["update", "--yes"]));
    let still_cached: serde_json::Value = serde_json::from_slice(
        &support::run(&project, &home, &["source", "info", "fixture", "--json"]).stdout,
    )
    .unwrap();
    assert_eq!(
        still_cached["snapshot"]["commit"],
        first["snapshot"]["commit"]
    );
    assert_eq!(still_cached["trust"]["vendor_receipts"], 0);

    success(&support::run(
        &project,
        &home,
        &["source", "fetch", "fixture"],
    ));
    let diff = support::run(&project, &home, &["source", "diff", "fixture"]);
    success(&diff);
    assert!(support::stdout(&diff).contains("changed\tskill/one"));
    success(&support::run(&project, &home, &["update", "--yes"]));
    success(&support::run(&project, &home, &["check"]));

    success(&support::run(
        &project,
        &home,
        &["uninstall", "one", "--yes"],
    ));
    success(&support::run(
        &project,
        &home,
        &["source", "remove", "fixture", "--yes"],
    ));
    let trust = support::run(&project, &home, &["trust", "list"]);
    success(&trust);
    let source_key = support::stdout(&trust)
        .split('\t')
        .next()
        .unwrap()
        .to_owned();
    success(&support::run(
        &project,
        &home,
        &["trust", "revoke", &source_key, "--yes"],
    ));

    success(&support::run(
        &project,
        &home,
        &["store", "prune", "--dry-run"],
    ));
    success(&support::run(&project, &home, &["store", "prune", "--yes"]));
}
