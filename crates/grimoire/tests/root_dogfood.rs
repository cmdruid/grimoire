mod support;

use std::fs;
use std::path::PathBuf;

use grimoire_core::inventory::scan;
use grimoire_core::source::HeldDirectoryReader;
use tempfile::tempdir;

fn selected_root() -> PathBuf {
    std::env::var_os("GRIMOIRE_LIVE_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .parent()
                .and_then(|path| path.parent())
                .expect("skill-grimoire sits two levels below the repository root")
                .to_path_buf()
        })
        .canonicalize()
        .expect("selected repository root")
}

fn success(output: &std::process::Output) {
    assert!(output.status.success(), "{}", support::stderr(output));
}

#[test]
fn root_clankshop_pack_installs_checks_and_uninstalls_through_the_cli() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = selected_root();
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();

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
            "grimoire",
            source.to_str().unwrap(),
            "--live",
            "--trust-all",
        ],
    ));
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
    let checked = support::run(&project, &home, &["check"]);
    success(&checked);
    assert_eq!(support::stdout(&checked), "");

    success(&support::run(
        &project,
        &home,
        &["uninstall", "clankshop", "--pack", "--yes"],
    ));
    for member in members {
        assert!(!project.join(".agents/skills").join(member).exists());
    }
}
