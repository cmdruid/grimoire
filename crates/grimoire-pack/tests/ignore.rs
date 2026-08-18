//! Consumer ignore rules: a mechanism, not a spec case (Appendix B leaves the
//! recursive bound to implementations), so these trees are built hermetically
//! here rather than added to `tests/fixtures/` — which is itself exactly the
//! kind of tree a consumer needs to exclude.

use grimoire_pack::discovery::Ignore;
use grimoire_pack::pack::{enumerate, enumerate_with};
use std::fs;
use std::path::Path;

fn skill(root: &Path, rel: &str, name: &str) {
    let d = root.join(rel);
    fs::create_dir_all(&d).unwrap();
    fs::write(
        d.join("SKILL.md"),
        format!("---\nname: {name}\ndescription: t\n---\n"),
    )
    .unwrap();
}

fn faced_pack(root: &Path, rel: &str, name: &str, required: &str) {
    skill(root, rel, name);
    fs::write(
        root.join(rel).join("PACK.md"),
        format!("---\nname: {name}\nversion: 1.0.0\ndescription: d\nrequired: {required}\n---\n"),
    )
    .unwrap();
}

#[test]
fn ignored_trees_yield_neither_packs_nor_issues() {
    let t = tempfile::tempdir().unwrap();
    let root = t.path();

    // the repository's own content: one valid pack and its member
    faced_pack(root, "skills/real", "real", "member");
    skill(root, "skills/member", "member");

    // a fixtures tree carrying BOTH a valid pack and a broken manifest
    // (member `ghost` resolves nowhere) — neither may surface once ignored
    faced_pack(root, "fixtures/sample/skills/alpha", "alpha", "member");
    faced_pack(root, "fixtures/broken/skills/x", "x", "ghost");

    let e = enumerate_with(root, &Ignore::new().with_path("fixtures")).unwrap();
    let names: Vec<_> = e.packs.iter().map(|p| p.manifest.name.as_str()).collect();
    assert_eq!(names, vec!["real"], "only the repository's own pack");
    assert!(
        e.issues.is_empty(),
        "ignored trees must not report issues either: {:?}",
        e.issues
    );

    // without the rule, all three manifests are seen — the bare behavior is
    // unchanged, which is what keeps `enumerate` backward compatible
    let bare = enumerate(root).unwrap();
    assert_eq!(bare.packs.len() + bare.issues.len(), 3);
}

#[test]
fn nested_checkouts_are_not_this_repositorys_content() {
    let t = tempfile::tempdir().unwrap();
    let root = t.path();
    faced_pack(root, "skills/real", "real", "member");
    skill(root, "skills/member", "member");

    // a vendored clone: `.git` is a DIRECTORY
    faced_pack(root, "vendor/other-repo/skills/alpha", "alpha", "member");
    fs::create_dir_all(root.join("vendor/other-repo/.git")).unwrap();

    // a linked worktree: `.git` is a FILE holding a gitdir: pointer. This is
    // the case that bit us — a worktree under the repo it belongs to carries a
    // full copy of the tree, so its packs (including a duplicate of the repo's
    // own) enumerate as if they were this repository's.
    faced_pack(root, "worktrees/wt/skills/real", "real", "member");
    skill(root, "worktrees/wt/skills/member", "member");
    fs::write(root.join("worktrees/wt/.git"), "gitdir: /elsewhere/.git\n").unwrap();

    let e = enumerate(root).unwrap();
    let names: Vec<_> = e.packs.iter().map(|p| p.manifest.name.as_str()).collect();
    assert_eq!(names, vec!["real"], "only this repository's own pack");
    assert_eq!(
        e.packs[0].manifest_path,
        root.join("skills/real/PACK.md"),
        "and it must be THIS tree's copy, not the worktree's"
    );
    assert!(
        e.issues.is_empty(),
        "no dup-name issue either: {:?}",
        e.issues
    );
}

#[test]
fn ignoring_a_tree_does_not_hide_a_nested_manifest_elsewhere() {
    let t = tempfile::tempdir().unwrap();
    let root = t.path();
    faced_pack(root, "skills/real", "real", "member");
    skill(root, "skills/member", "member");
    // a genuine violation OUTSIDE the ignored tree still reports (§1: nothing
    // nests below a faced pack dir) — the rule narrows scope, never silences
    skill(root, "skills/real/nested", "nested");

    let e = enumerate_with(root, &Ignore::new().with_path("fixtures")).unwrap();
    assert!(e.packs.is_empty(), "the violation invalidates the pack");
    assert_eq!(e.issues.len(), 1);
    assert!(
        e.issues[0].error.to_string().contains("nested"),
        "got: {}",
        e.issues[0].error
    );
}
