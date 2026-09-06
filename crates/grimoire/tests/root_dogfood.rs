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
        .map(|parent| parent.join("grove"))
        .expect("repository has a parent directory");
    if sibling
        .join("packs")
        .join("clankshop")
        .join("PACK.md")
        .is_file()
    {
        return sibling;
    }
    panic!(
        "set GRIMOIRE_LIVE_ROOT to the skills catalog (sibling ../grove with packs/clankshop/PACK.md not found)"
    );
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
#[ignore = "live catalog dogfood; run with --ignored"]
fn root_clankshop_pack_installs_checks_and_uninstalls_through_the_cli() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let source = selected_root();
    let project = root.join("project");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    let source_status = git_output(&source, &["status", "--short"]);

    let inventory = scan(&HeldDirectoryReader::open(&source).unwrap()).unwrap();
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
    success(&support::run(
        &project,
        &home,
        &[
            "source",
            "add",
            "grove",
            source.to_str().unwrap(),
            "--link",
            "--trust-all",
        ],
    ));
    success(&support::run(
        &project,
        &home,
        &["install", "clankshop", "--pack", "--source", "grove"],
    ));

    for member in &members {
        let installed = project.join(".agents/skills").join(member);
        assert!(
            installed
                .symlink_metadata()
                .unwrap()
                .file_type()
                .is_symlink(),
            "missing installed member {member}"
        );
        assert_eq!(
            fs::read_link(&installed).unwrap(),
            source.join("skills").join(member)
        );
    }
    assert!(!project.join(".agents/skills/clankshop").exists());
    assert!(!project.join("vendor/grimoire").exists());
    assert!(!project_has_committed_agents(&project));

    let checked = support::run(&project, &home, &["check"]);
    success(&checked);
    assert_eq!(support::stdout(&checked), "");

    let info = support::run(&project, &home, &["source", "info", "grove", "--json"]);
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

fn project_has_committed_agents(project: &Path) -> bool {
    if !project.join(".git").exists() {
        return false;
    }
    let output = Command::new("git")
        .current_dir(project)
        .args(["ls-files", ".agents"])
        .output()
        .unwrap();
    output.status.success() && !output.stdout.is_empty()
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
