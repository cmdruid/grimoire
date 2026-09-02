#[cfg(unix)]
#[test]
fn held_directory_never_follows_a_symlink_component() {
    use std::fs;
    use std::os::unix::fs::symlink;

    use grimoire_core::inventory::{scan, TreeReader};
    use grimoire_core::source::HeldDirectoryReader;

    let temp = tempfile::tempdir().unwrap();
    let outside = tempfile::tempdir().unwrap();
    fs::write(outside.path().join("canary"), b"secret").unwrap();
    symlink(outside.path(), temp.path().join("escape")).unwrap();

    let root = temp.path().canonicalize().unwrap();
    let held = HeldDirectoryReader::open(&root).unwrap();
    let inventory = scan(&held).unwrap();
    assert!(inventory
        .reviewed_entries
        .iter()
        .all(|entry| { !entry.path.as_bytes().starts_with(b"escape/") }));
    assert!(held.open(&"escape/canary".into()).is_err());
}

#[cfg(unix)]
#[test]
fn live_inspection_publishes_only_review_and_candidate_state() {
    use std::fs;

    use grimoire_core::source::inspect_live_source;
    use grimoire_core::{Paths, SourceAlias};

    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let source = root.join("source");
    let home = root.join("home");
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&source).unwrap();
    fs::create_dir_all(&home).unwrap();
    fs::write(
        project.join("grimoire.toml"),
        b"schema = \"grimoire/manifest@1\"\n[sources.local]\npath = \"../source\"\nlive = true\n",
    )
    .unwrap();
    fs::write(source.join("SKILL.md"), b"---\nname: local\n---\n").unwrap();
    let paths = Paths::project(project.clone(), home.clone()).unwrap();
    let manifest_before = fs::read(project.join("grimoire.toml")).unwrap();

    let info = inspect_live_source(paths.clone(), SourceAlias::new("local").unwrap()).unwrap();

    assert_eq!(info.inventory.skills[0].name, "local");
    assert_eq!(
        fs::read(project.join("grimoire.toml")).unwrap(),
        manifest_before
    );
    assert!(paths
        .candidate_path(&paths.scope_key(), &SourceAlias::new("local").unwrap())
        .is_file());
    assert!(info.export.root.is_dir());
    assert!(!paths.trust_path().exists());
    assert!(!paths.lock_path().exists());
    assert!(!home.join("store/checkouts").exists());
}
