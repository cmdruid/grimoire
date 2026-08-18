//! Conformance fixtures: one directory per spec case (§1/§2). These trees are
//! the format's executable examples — extend them as the spec evolves.

use grimoire_pack::pack::{enumerate, Enumeration, PackShape};
use grimoire_pack::PackError;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

fn sole_issue_msg(e: &Enumeration) -> &str {
    assert_eq!(
        e.issues.len(),
        1,
        "expected exactly one issue, got: {:?}",
        e.issues
    );
    match &e.issues[0].error {
        PackError::Shape(m) => m,
        other => panic!("expected Shape issue, got {other}"),
    }
}

#[test]
fn faced_pack_enumerates_with_resolved_members() {
    let e = enumerate(&fixture("faced-valid")).unwrap();
    assert!(e.issues.is_empty(), "unexpected issues: {:?}", e.issues);
    assert_eq!(e.packs.len(), 1);
    let p = &e.packs[0];
    assert_eq!(p.manifest.name, "alpha");
    assert!(matches!(p.shape, PackShape::Faced { .. }));
    assert_eq!(p.manifest.required, vec!["beta"]);
}

#[test]
fn faceless_root_pack_is_manifest_only() {
    let e = enumerate(&fixture("faceless-valid")).unwrap();
    assert!(e.issues.is_empty(), "unexpected issues: {:?}", e.issues);
    assert_eq!(e.packs.len(), 1);
    assert_eq!(e.packs[0].manifest.name, "bundle");
    assert!(matches!(e.packs[0].shape, PackShape::Faceless));
}

#[test]
fn nested_skill_below_a_faced_pack_dir_is_invalid() {
    let e = enumerate(&fixture("invalid-nested")).unwrap();
    assert!(e.packs.is_empty());
    assert!(sole_issue_msg(&e).contains("nested SKILL.md"));
}

#[test]
fn unresolvable_member_is_invalid() {
    let e = enumerate(&fixture("invalid-unresolvable")).unwrap();
    assert!(e.packs.is_empty());
    assert!(sole_issue_msg(&e).contains("does not resolve"));
}

#[test]
fn face_name_mismatch_is_invalid() {
    let e = enumerate(&fixture("invalid-face-mismatch")).unwrap();
    assert!(e.packs.is_empty());
    assert!(sole_issue_msg(&e).contains("face name wrong"));
}

#[test]
fn face_listed_as_member_is_invalid() {
    let e = enumerate(&fixture("invalid-listed-face")).unwrap();
    assert!(e.packs.is_empty());
    assert!(sole_issue_msg(&e).contains("must not be listed"));
}

#[test]
fn faceless_manifest_off_root_is_invalid() {
    let e = enumerate(&fixture("invalid-faceless-nonroot")).unwrap();
    assert!(e.packs.is_empty());
    assert!(sole_issue_msg(&e).contains("off the repository root"));
}

#[test]
fn two_manifests_with_one_pack_name_are_invalid() {
    let e = enumerate(&fixture("invalid-dup-name")).unwrap();
    assert_eq!(e.packs.len(), 1); // first twin wins deterministically
    assert!(sole_issue_msg(&e).contains("two manifests declare the pack name twin"));
}

#[test]
fn root_faced_pack_errors_instead_of_vanishing() {
    let e = enumerate(&fixture("invalid-root-faced")).unwrap();
    assert!(e.packs.is_empty());
    assert!(sole_issue_msg(&e).contains("root cannot be a faced pack"));
}

#[cfg(unix)]
#[test]
fn symlinks_are_never_followed_by_enumeration() {
    use std::fs;
    let t = tempfile::tempdir().unwrap();
    let sk = |rel: &str, name: &str| {
        let d = t.path().join(rel);
        fs::create_dir_all(&d).unwrap();
        fs::write(
            d.join("SKILL.md"),
            format!("---\nname: {name}\ndescription: t\n---\n"),
        )
        .unwrap();
    };
    sk("skills/alpha", "alpha");
    sk("skills/beta", "beta");
    fs::write(
        t.path().join("skills/alpha/PACK.md"),
        "---\nname: alpha\nversion: 1.0.0\ndescription: \"p\"\nrequired: beta\n---\nrunbook\n",
    )
    .unwrap();
    // a dir-mirror symlink and an intra-pack symlink must both be invisible
    std::os::unix::fs::symlink(t.path().join("skills"), t.path().join("mirror")).unwrap();
    std::os::unix::fs::symlink(
        t.path().join("skills/beta"),
        t.path().join("skills/alpha/link"),
    )
    .unwrap();
    let e = enumerate(t.path()).unwrap();
    assert_eq!(e.packs.len(), 1);
    assert!(
        e.issues.is_empty(),
        "symlink produced issues: {:?}",
        e.issues
    );
}
