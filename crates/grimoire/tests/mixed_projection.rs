mod support;

use std::fs;
use std::path::Path;
use std::process::Command;

use tempfile::tempdir;

#[test]
fn pinned_copies_and_link_activations_share_one_skills_directory() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    for skill in ["copied", "linked"] {
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
            "pinned",
            source.to_str().unwrap(),
            "--trust-all",
        ],
    ));
    success(&support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "live",
            source.to_str().unwrap(),
            "--link",
            "--trust-all",
        ],
    ));
    success(&support::run(
        &project,
        &home,
        &["install", "copied", "--source", "pinned"],
    ));
    success(&support::run(
        &project,
        &home,
        &["install", "linked", "--source", "live"],
    ));

    let skills = project.join(".agents/skills");
    let copied = skills.join("copied");
    let linked = skills.join("linked");
    assert!(copied.is_dir());
    assert!(!copied.symlink_metadata().unwrap().file_type().is_symlink());
    assert!(copied.join("SKILL.md").is_file());
    assert!(linked.symlink_metadata().unwrap().file_type().is_symlink());
    let linked_target = fs::read_link(&linked).unwrap();
    assert!(linked_target.is_absolute());
    assert_eq!(linked_target, source.join("skills/linked"));
    assert!(!project.join("vendor/grimoire").exists());

    let listed = support::run(&project, &home, &["list"]);
    success(&listed);
    let output = support::stdout(&listed);
    assert!(output.contains("skill\tcopied\tpinned\tmode=copy\tprojection=.agents/skills/copied"));
    assert!(output.contains("skill\tlinked\tlive\tmode=link\t"));
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
