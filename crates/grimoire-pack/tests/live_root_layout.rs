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
fn root_discovery_excludes_nested_streams() {
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
                .any(|part| part == b".streams"),
            "nested stream content escaped discovery: {path}"
        );
    }
}
