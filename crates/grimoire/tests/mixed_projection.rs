mod support;

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use tempfile::tempdir;

#[test]
fn linked_and_vendored_skills_share_one_symlink_only_activation_surface() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    for skill in ["linked", "vendored"] {
        let directory = source.join("skills").join(skill);
        fs::create_dir_all(&directory).unwrap();
        fs::write(
            directory.join("SKILL.md"),
            format!("---\nname: {skill}\ndescription: mixed projection fixture\n---\n"),
        )
        .unwrap();
    }
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
            "mixed projections",
        ],
    );

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
        &["install", "linked", "--source", "fixture"],
    ));
    success(&support::run(
        &project,
        &home,
        &["install", "vendored", "--source", "fixture", "--vendor"],
    ));

    let skills = project.join(".agents/skills");
    let mut entries = fs::read_dir(&skills)
        .unwrap()
        .collect::<Result<Vec<_>, _>>()
        .unwrap();
    entries.sort_by_key(fs::DirEntry::file_name);
    assert_eq!(entries.len(), 2);
    assert!(entries.iter().all(|entry| entry.path().is_symlink()));

    let linked_target = fs::read_link(skills.join("linked")).unwrap();
    assert!(linked_target.is_absolute());
    assert!(linked_target.starts_with(home.join(".grimoire/store/checkouts")));
    let vendored_target = fs::read_link(skills.join("vendored")).unwrap();
    assert_eq!(
        vendored_target,
        PathBuf::from("../../vendor/grimoire/fixture/vendored")
    );
    assert!(project
        .join("vendor/grimoire/fixture/vendored/SKILL.md")
        .is_file());

    let listed = support::run(&project, &home, &["list"]);
    success(&listed);
    let output = support::stdout(&listed);
    assert!(output.contains("skill\tlinked\tfixture\tmode=link\tprojection="));
    assert!(output.contains(
        "skill\tvendored\tfixture\tmode=vendor\tprojection=vendor/grimoire/fixture/vendored"
    ));
    success(&support::run(&project, &home, &["check"]));
}

fn git(directory: &Path, args: &[&str]) {
    assert!(Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap()
        .success());
}

fn success(output: &std::process::Output) {
    assert!(output.status.success(), "{}", support::stderr(output));
}
