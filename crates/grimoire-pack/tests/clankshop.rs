#[path = "support/inventory.rs"]
mod support;

#[cfg(unix)]
use grimoire_pack::inventory::scan;
#[cfg(unix)]
use std::path::PathBuf;
#[cfg(unix)]
use support::FsTree;

#[cfg(unix)]
fn catalog_root() -> PathBuf {
    if let Some(path) = std::env::var_os("GRIMOIRE_LIVE_ROOT") {
        return PathBuf::from(path);
    }
    let repo = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|path| path.parent())
        .expect("grimoire-pack sits two levels below the repository root")
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

#[cfg(unix)]
#[test]
fn clankshop_is_the_one_valid_root_pack() {
    let inventory = scan(&FsTree::new(catalog_root())).expect("scan the catalog root");
    let packs: Vec<_> = inventory
        .packs
        .iter()
        .map(|pack| pack.name.as_str())
        .collect();
    assert_eq!(packs, ["clankshop"]);
    let clankshop = &inventory.packs[0];
    assert!(clankshop.missing_required.is_empty());
    assert!(clankshop.missing_optional.is_empty());
    assert!(
        inventory.findings.is_empty(),
        "the worktree inventory must have no findings: {:#?}",
        inventory.findings
    );
    assert!(inventory.is_valid());
}
