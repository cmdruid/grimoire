mod support;

use std::fs;

use tempfile::tempdir;

#[test]
fn exit_classes_preserve_usage_findings_policy_transport_and_io() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();

    let unknown = support::run(&project, &home, &["--unknown"]);
    assert_eq!(unknown.status.code(), Some(2));
    assert!(support::stderr(&unknown).contains("unexpected argument"));
    assert_eq!(
        support::run(&project, &home, &["check"]).status.code(),
        Some(2)
    );

    assert!(support::run(&project, &home, &["init"]).status.success());
    let live = support::run(
        &project,
        &home,
        &["source", "add", "local", ".", "--live", "--trust-all"],
    );
    assert_eq!(live.status.code(), Some(2));
    assert!(support::stderr(&live).contains("`--live` is not accepted; use `--link`"));
    fs::write(
        project.join("grimoire.toml"),
        b"schema = \"grimoire/manifest@3\"\n[sources.repo]\nurl = \"github:org/repo\"\n[skills]\none = { source = \"repo\" }\n",
    )
    .unwrap();
    let findings = support::run(&project, &home, &["check"]);
    assert_eq!(findings.status.code(), Some(1));
    assert!(support::stdout(&findings).contains("source-snapshot-missing"));
    assert_eq!(
        support::run(&project, &home, &["update"]).status.code(),
        Some(3)
    );

    let non_repository = root.join("not-git");
    fs::create_dir_all(&non_repository).unwrap();
    assert_eq!(
        support::run(
            &project,
            &home,
            &["source", "add", "local", non_repository.to_str().unwrap(),],
        )
        .status
        .code(),
        Some(4)
    );

    let file_home = root.join("file-home");
    fs::write(&file_home, b"not a directory\n").unwrap();
    assert_eq!(
        support::run(&project, &file_home, &["init", "--global"])
            .status
            .code(),
        Some(5)
    );
}

#[test]
fn malformed_initialized_state_is_usage_class() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::write(project.join("grimoire.toml"), b"not toml = [\n").unwrap();
    fs::write(
        project.join("grimoire.lock"),
        b"{\"schema\":\"grimoire/lock@3\",\"sources\":{},\"packs\":{},\"skills\":{}}\n",
    )
    .unwrap();

    assert_eq!(
        support::run(&project, &home, &["check"]).status.code(),
        Some(2)
    );
}
