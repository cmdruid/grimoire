#[path = "support/inventory.rs"]
mod support;

#[cfg(unix)]
use grimoire_pack::inventory::scan;
#[cfg(unix)]
use std::path::PathBuf;
#[cfg(unix)]
use support::FsTree;

#[cfg(unix)]
fn selected_root() -> PathBuf {
    std::env::var_os("GRIMOIRE_LIVE_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .parent()
                .and_then(|path| path.parent())
                .expect("grimoire-pack sits two levels below the repository root")
                .to_path_buf()
        })
}

#[cfg(unix)]
#[test]
fn root_discovery_excludes_nested_workstreams() {
    let inventory = scan(&FsTree::new(selected_root())).expect("scan selected root");
    let names: Vec<_> = inventory
        .skills
        .iter()
        .map(|skill| skill.name.as_str())
        .collect();
    assert!(names.contains(&"architect"));
    assert!(names.contains(&"workstream"));
    for path in inventory
        .skills
        .iter()
        .map(|skill| &skill.path)
        .chain(inventory.packs.iter().map(|pack| &pack.path))
        .chain(inventory.reviewed_entries.iter().map(|entry| &entry.path))
    {
        assert!(
            !path
                .as_bytes()
                .split(|byte| *byte == b'/')
                .any(|part| matches!(part, b".workstreams" | b".agents" | b"vendor")),
            "managed or nested projection content escaped discovery: {path}"
        );
    }
}

#[cfg(unix)]
#[test]
fn managed_activation_and_vendor_trees_are_discovery_boundaries() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path();
    write_skill(&root.join("skills/visible"), "visible");
    std::fs::create_dir_all(root.join(".agents/skills")).unwrap();
    std::os::unix::fs::symlink(
        "../../skills/visible",
        root.join(".agents/skills/activated"),
    )
    .unwrap();
    write_skill(&root.join("vendor/grimoire/repo/vendored"), "vendored");

    let inventory = scan(&FsTree::new(root)).unwrap();
    let names = inventory
        .skills
        .iter()
        .map(|skill| skill.name.as_str())
        .collect::<Vec<_>>();
    assert_eq!(names, vec!["visible"]);
}

#[cfg(unix)]
fn write_skill(directory: &std::path::Path, name: &str) {
    std::fs::create_dir_all(directory).unwrap();
    std::fs::write(
        directory.join("SKILL.md"),
        format!("---\nname: {name}\ndescription: fixture\n---\n"),
    )
    .unwrap();
}
