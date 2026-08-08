//! Conformance fixtures: one directory per spec case (§1/§2). These trees are
//! the format's executable examples — extend them as the spec evolves.

use grimoire_pack::pack::{enumerate, PackShape};
use grimoire_pack::PackError;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn faced_pack_enumerates_with_resolved_members() {
    let packs = enumerate(&fixture("faced-valid")).unwrap();
    assert_eq!(packs.len(), 1);
    let p = &packs[0];
    assert_eq!(p.manifest.name, "alpha");
    assert!(matches!(p.shape, PackShape::Faced { .. }));
    assert_eq!(p.manifest.required, vec!["beta"]);
}

#[test]
fn faceless_root_pack_is_manifest_only() {
    let packs = enumerate(&fixture("faceless-valid")).unwrap();
    assert_eq!(packs.len(), 1);
    assert_eq!(packs[0].manifest.name, "bundle");
    assert!(matches!(packs[0].shape, PackShape::Faceless));
}

#[test]
fn nested_skill_below_a_faced_pack_dir_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-nested")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn unresolvable_member_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-unresolvable")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn face_name_mismatch_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-face-mismatch")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn face_listed_as_member_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-listed-face")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn faceless_manifest_off_root_is_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-faceless-nonroot")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn two_manifests_with_one_pack_name_are_invalid() {
    assert!(matches!(
        enumerate(&fixture("invalid-dup-name")),
        Err(PackError::Shape(_))
    ));
}

#[test]
fn root_faced_pack_errors_instead_of_vanishing() {
    assert!(matches!(
        enumerate(&fixture("invalid-root-faced")),
        Err(PackError::Shape(_))
    ));
}
