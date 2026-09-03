mod support;

use std::fs;

use tempfile::tempdir;

fn write_source(root: &std::path::Path, skills: &[&str]) {
    for skill in skills {
        let directory = root.join("skills").join(skill);
        fs::create_dir_all(&directory).unwrap();
        fs::write(
            directory.join("SKILL.md"),
            format!("---\nname: {skill}\ndescription: fixture\n---\n"),
        )
        .unwrap();
    }
}

fn assert_success(output: &std::process::Output) {
    assert!(output.status.success(), "{}", support::stderr(output));
}

#[test]
fn list_check_and_prune_project_core_projections() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let global_source = root.join("global-source");
    let project_source = root.join("project-source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    write_source(&global_source, &["shared"]);
    write_source(&project_source, &["local", "shared"]);

    assert_success(&support::run(&project, &home, &["init", "--global"]));
    assert_success(&support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "global",
            global_source.to_str().unwrap(),
            "--live",
            "--trust-all",
            "--global",
        ],
    ));
    assert_success(&support::run(
        &project,
        &home,
        &["install", "shared", "--source", "global", "--global"],
    ));

    assert_success(&support::run(&project, &home, &["init"]));
    assert_success(&support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "project",
            project_source.to_str().unwrap(),
            "--live",
            "--trust-all",
        ],
    ));
    assert_success(&support::run(
        &project,
        &home,
        &["install", "local", "--source", "project"],
    ));
    assert_success(&support::run(
        &project,
        &home,
        &["install", "shared", "--source", "project"],
    ));

    let listed = support::run(&project, &home, &["list"]);
    assert_eq!(listed.status.code(), Some(1));
    let stdout = support::stdout(&listed);
    assert!(stdout.contains("desired\tskill:local\tproject\tmode=link"));
    assert!(stdout.contains("skill\tlocal\tproject\tmode=link\tprojection=live"));
    assert!(stdout.contains("requested_by=skill:local"));
    assert!(stdout.contains("inherited\tshared\tglobal\tshadowed=true"));
    assert!(stdout.contains("finding\tWarning\tglobal-skill-shadowed"));

    fs::remove_file(project.join(".agents/skills/local")).unwrap();
    let checked = support::run(&project, &home, &["check"]);
    assert_eq!(checked.status.code(), Some(1));
    assert!(support::stdout(&checked).contains("link-missing"));

    let pruned = support::run(
        &project,
        &home,
        &[
            "store",
            "prune",
            "--project",
            project.to_str().unwrap(),
            "--dry-run",
        ],
    );
    assert_success(&pruned);
    assert!(support::stdout(&pruned).contains("\"actions\""));
}
