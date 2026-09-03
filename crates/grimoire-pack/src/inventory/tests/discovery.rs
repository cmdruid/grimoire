use super::super::{scan, SourcePath, TreeEntry, TreeEntryKind};
use super::support::MemoryTree;

fn codes(tree: &MemoryTree) -> Vec<String> {
    scan(tree)
        .unwrap()
        .findings
        .iter()
        .map(|finding| finding.code.clone())
        .collect()
}

#[test]
fn recursive_discovery_obeys_all_outer_boundaries() {
    let mut tree = MemoryTree::default();
    tree.skill("skills/real", "real");
    tree.skill("vendor/hidden", "vendored");
    tree.skill("nested/hidden", "checkout");
    tree.entries.push(TreeEntry::directory("nested/.git"));
    tree.entries
        .push(TreeEntry::symlink("linked", b"skills".to_vec()));
    tree.skill("linked/hidden", "followed");
    tree.skill("skills/real/child", "child");
    let inventory = scan(&tree).unwrap();
    assert_eq!(
        inventory
            .skills
            .iter()
            .map(|skill| skill.name.as_str())
            .collect::<Vec<_>>(),
        ["real"]
    );
    assert!(inventory.skills[0]
        .files
        .iter()
        .any(|file| file.path == SourcePath::from("child/SKILL.md")));
}

#[test]
fn packs_are_discovered_at_any_outer_directory_but_never_inside_a_skill() {
    let mut tree = MemoryTree::default();
    tree.skill("skills/real", "real");
    tree.pack("bundles/team/PACK.md", "team", "real");
    tree.pack("skills/real/PACK.md", "not-a-pack", "real");
    let inventory = scan(&tree).unwrap();
    assert_eq!(
        inventory
            .packs
            .iter()
            .map(|pack| pack.name.as_str())
            .collect::<Vec<_>>(),
        ["team"]
    );
}

#[test]
fn duplicate_identities_and_unicode_collisions_keep_later_evidence() {
    let mut tree = MemoryTree::default();
    tree.skill("skills/a", "same");
    tree.skill("skills/b", "same");
    tree.pack("packs/a/PACK.md", "bundle", "same");
    tree.pack("packs/b/PACK.md", "bundle", "same");
    tree.file("A.txt", b"a".to_vec());
    tree.file("a.txt", b"b".to_vec());
    let inventory = scan(&tree).unwrap();
    assert_eq!(inventory.skills.len(), 2);
    assert_eq!(inventory.packs.len(), 2);
    for code in ["duplicate-skill", "duplicate-pack", "case-collision"] {
        assert!(inventory
            .findings
            .iter()
            .any(|finding| finding.code == code));
    }
}

#[test]
fn hostile_raw_paths_and_special_entries_are_lossless_findings() {
    let mut tree = MemoryTree::default();
    for path in [
        SourcePath::new(vec![b'b', 0xff]),
        SourcePath::from("../escape"),
        SourcePath::from("/absolute"),
        SourcePath::new(b"nul\0path".to_vec()),
    ] {
        tree.entries.push(TreeEntry::file(path.clone(), 0o100644));
        tree.files.insert(path, b"x".to_vec());
    }
    for (path, kind) in [
        ("device", TreeEntryKind::Device),
        ("fifo", TreeEntryKind::Fifo),
        ("socket", TreeEntryKind::Socket),
    ] {
        tree.entries.push(TreeEntry {
            path: SourcePath::from(path),
            kind,
            mode: 0,
            size: None,
            link_target: None,
            submodule_commit: None,
        });
    }
    let found = codes(&tree);
    assert!(found.iter().any(|code| code == "invalid-path-utf8"));
    assert_eq!(
        found.iter().filter(|code| *code == "unsafe-path").count(),
        3
    );
    assert_eq!(
        found
            .iter()
            .filter(|code| *code == "unsupported-entry")
            .count(),
        3
    );
}

#[test]
fn directory_depth_reports_the_first_rejected_level() {
    let mut tree = MemoryTree::default();
    let deep = (0..33).map(|_| "d").collect::<Vec<_>>().join("/");
    tree.skill(&deep, "deep");
    let inventory = scan(&tree).unwrap();
    let finding = inventory
        .findings
        .iter()
        .find(|finding| finding.code == "discovery-depth-limit")
        .unwrap();
    assert_eq!(finding.details["limit"], "32");
    assert_eq!(finding.details["observed"], "33");
    assert!(inventory.skills.is_empty());
}

#[test]
fn entry_limit_reports_100001_without_partial_identity() {
    let tree = MemoryTree {
        entries: (0..100_001)
            .map(|index| TreeEntry::directory(format!("d{index:06}").as_str()))
            .collect(),
        ..MemoryTree::default()
    };
    let inventory = scan(&tree).unwrap();
    let finding = inventory
        .findings
        .iter()
        .find(|finding| finding.code == "discovery-entry-limit")
        .unwrap();
    assert_eq!(finding.details["observed"], "100001");
    assert!(inventory.skills.is_empty());
    assert!(inventory.packs.is_empty());
}

#[test]
fn ignored_subtree_is_counted_once_and_skill_ignored_names_remain_content() {
    let mut tree = MemoryTree::default();
    tree.entries.push(TreeEntry::directory("target"));
    tree.entries.extend((0..100_001).map(|index| {
        let path = format!("target/object-{index:06}");
        TreeEntry::file(path.as_str(), 0o100644)
    }));
    tree.skill("skills/real", "real");
    tree.entries
        .push(TreeEntry::directory("skills/real/target"));
    tree.file("skills/real/target/kept.txt", b"kept".to_vec());

    let inventory = scan(&tree).unwrap();
    assert!(!inventory
        .findings
        .iter()
        .any(|finding| finding.code == "discovery-entry-limit"));
    assert_eq!(inventory.skills.len(), 1);
    assert!(inventory.skills[0]
        .files
        .iter()
        .any(|file| file.path == SourcePath::from("target/kept.txt")));
    assert!(inventory
        .reviewed_entries
        .iter()
        .all(|entry| !entry.path.as_bytes().starts_with(b"target/")));
}

#[test]
fn submodules_are_inert_outside_skills_and_invalid_inside() {
    let mut tree = MemoryTree::default();
    tree.skill("skills/real", "real");
    for path in ["dependency", "skills/real/dependency"] {
        tree.entries.push(TreeEntry {
            path: SourcePath::from(path),
            kind: TreeEntryKind::Submodule,
            mode: 0o160000,
            size: None,
            link_target: None,
            submodule_commit: Some("0123456789abcdef0123456789abcdef01234567".into()),
        });
    }
    let inventory = scan(&tree).unwrap();
    assert_eq!(
        inventory
            .findings
            .iter()
            .filter(|finding| finding.code == "unsupported-entry")
            .count(),
        1
    );
    assert_eq!(inventory.skills[0].submodules.len(), 1);
}

#[cfg(unix)]
#[test]
fn controlled_filesystem_reader_preserves_invalid_utf8_and_never_follows_links() {
    use std::os::unix::ffi::OsStringExt;
    use std::os::unix::fs::symlink;

    use super::support::FixtureTree;

    let temp = tempfile::tempdir().unwrap();
    let invalid = temp
        .path()
        .join(std::ffi::OsString::from_vec(vec![b'x', 0xff]));
    if let Err(error) = std::fs::write(&invalid, b"bytes") {
        assert_eq!(error.kind(), std::io::ErrorKind::PermissionDenied);
        return;
    }
    std::fs::create_dir(temp.path().join("real")).unwrap();
    std::fs::write(temp.path().join("real/SKILL.md"), b"---\nname: real\n---\n").unwrap();
    symlink("real", temp.path().join("linked")).unwrap();
    let inventory = scan(&FixtureTree::new(temp.path())).unwrap();
    assert!(inventory
        .findings
        .iter()
        .any(|finding| finding.code == "invalid-path-utf8"));
    assert_eq!(inventory.skills.len(), 1);
    assert!(inventory
        .reviewed_entries
        .iter()
        .all(|entry| !entry.path.as_bytes().starts_with(b"linked/")));
}
