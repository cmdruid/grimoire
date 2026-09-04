mod support;

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use grimoire_core::inventory::scan;
use grimoire_core::source::HeldDirectoryReader;
use tempfile::tempdir;

fn selected_root() -> PathBuf {
    catalog_root()
        .canonicalize()
        .expect("selected catalog root")
}

fn catalog_root() -> PathBuf {
    if let Some(path) = std::env::var_os("GRIMOIRE_LIVE_ROOT") {
        return PathBuf::from(path);
    }
    let repo = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|path| path.parent())
        .expect("skill-grimoire sits two levels below the repository root")
        .to_path_buf();
    let sibling = repo
        .parent()
        .map(|parent| parent.join("dojo"))
        .expect("repository has a parent directory");
    if sibling.join("PACK.md").is_file() {
        return sibling;
    }
    panic!("set GRIMOIRE_LIVE_ROOT to the skills catalog (sibling ../dojo with PACK.md not found)");
}

fn success(output: &std::process::Output) {
    assert!(
        output.status.success(),
        "stdout:\n{}\nstderr:\n{}",
        support::stdout(output),
        support::stderr(output)
    );
}

#[test]
fn root_clankshop_pack_installs_checks_and_uninstalls_through_the_cli() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let source = selected_root();
    let project = root.join("self-host");
    fs::create_dir_all(&home).unwrap();
    let source_status = git_output(&source, &["status", "--short"]);

    let inventory = scan(&HeldDirectoryReader::open(&source).unwrap()).unwrap();
    git(
        &root,
        &[
            "clone",
            "-q",
            source.to_str().unwrap(),
            project.to_str().unwrap(),
        ],
    );
    let exclude_path = project.join(".git/info/exclude");
    let mut exclude = fs::read_to_string(&exclude_path).unwrap_or_default();
    exclude.push_str("\n/.agents/\n/vendor/\n");
    fs::write(&exclude_path, exclude).unwrap();

    let pack = inventory
        .packs
        .iter()
        .find(|pack| pack.name == "clankshop")
        .expect("root clankshop pack");
    assert!(pack.missing_required.is_empty());
    let available = inventory
        .skills
        .iter()
        .map(|skill| skill.name.as_str())
        .collect::<std::collections::BTreeSet<_>>();
    let members = pack
        .required
        .iter()
        .chain(&pack.optional)
        .filter(|member| available.contains(member.as_str()))
        .collect::<Vec<_>>();

    success(&support::run(&project, &home, &["init"]));
    commit_paths(
        &project,
        &["grimoire.toml", "grimoire.lock"],
        "project state",
    );
    success(&support::run(
        &project,
        &home,
        &["source", "add", "grimoire", ".", "--trust-all"],
    ));
    commit_paths(&project, &["grimoire.toml"], "pinned self source");
    success(&support::run(
        &project,
        &home,
        &["install", "clankshop", "--pack", "--source", "grimoire"],
    ));

    for member in &members {
        assert!(
            project.join(".agents/skills").join(member).is_symlink(),
            "missing installed member {member}"
        );
    }
    assert!(!project.join(".agents/skills/clankshop").exists());
    assert!(!project.join("vendor/grimoire").exists());
    commit_paths(
        &project,
        &["grimoire.toml", "grimoire.lock"],
        "installed clankshop",
    );

    success(&support::run(
        &project,
        &home,
        &["source", "fetch", "grimoire"],
    ));
    success(&support::run(
        &project,
        &home,
        &["source", "diff", "grimoire"],
    ));
    success(&support::run(&project, &home, &["update", "--yes"]));
    commit_paths(&project, &["grimoire.lock"], "advance pinned self source");
    success(&support::run(
        &project,
        &home,
        &["source", "fetch", "grimoire"],
    ));
    let checked = support::run(&project, &home, &["check"]);
    success(&checked);
    assert_eq!(support::stdout(&checked), "");
    success(&support::run(&project, &home, &["install", "--frozen"]));

    let info = support::run(&project, &home, &["source", "info", "grimoire", "--json"]);
    success(&info);
    let value: serde_json::Value = serde_json::from_slice(&info.stdout).unwrap();
    let names = value["skills"]
        .as_array()
        .unwrap()
        .iter()
        .map(|skill| skill["name"].as_str().unwrap())
        .collect::<std::collections::BTreeSet<_>>();
    assert_eq!(names.len(), inventory.skills.len());
    assert!(!names.contains("clankshop"));

    let after = scan(&HeldDirectoryReader::open(&source).unwrap()).unwrap();
    assert_eq!(after.inventory_digest, inventory.inventory_digest);
    assert_eq!(git_output(&source, &["status", "--short"]), source_status);

    success(&support::run(
        &project,
        &home,
        &["uninstall", "clankshop", "--pack", "--yes"],
    ));
    for member in members {
        assert!(!project.join(".agents/skills").join(member).exists());
    }
}

fn commit_paths(repository: &Path, paths: &[&str], message: &str) {
    let mut add = vec!["add"];
    add.extend_from_slice(paths);
    git(repository, &add);
    git(
        repository,
        &[
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            message,
        ],
    );
}

fn git(directory: &Path, args: &[&str]) {
    assert!(Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap()
        .success());
}

fn git_output(directory: &Path, args: &[&str]) -> Vec<u8> {
    let output = Command::new("git")
        .current_dir(directory)
        .args(args)
        .output()
        .unwrap();
    assert!(output.status.success());
    output.stdout
}
