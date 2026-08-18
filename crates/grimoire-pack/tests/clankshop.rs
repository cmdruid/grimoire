//! The flagship: this repository's own clankshop pack must enumerate and
//! validate against the library. Runs against the live tree two levels up.
//!
//! These assertions are deliberately **structural**. An earlier revision
//! pinned the pack's literal version, required/optional rosters, and author
//! extension keys — all content another stream owns and revises freely, which
//! turned every legitimate pack edit into a red gate here (observed: the pack
//! moved 1.1.0 -> 2.3.0 and re-rostered, leaving this test failing on the
//! trunk with nothing actually broken). What grimoire-pack guarantees is that
//! the live pack *parses, validates, and enumerates*; what version it happens
//! to carry today is the pack's business. Hermetic fixtures cover the value
//! level (e.g. unknown-key preservation, `manifest.rs`).

use grimoire_pack::discovery::Ignore;
use grimoire_pack::pack::{enumerate, enumerate_with, PackShape};
use std::path::PathBuf;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|p| p.parent())
        .expect("crates/grimoire-pack sits two levels below the repo root")
        .to_path_buf()
}

/// The crate's own conformance fixtures are real, well-formed pack trees in
/// this repository, so a bare scan enumerates them as repo content. Consumers
/// exclude them by path.
fn fixtures_ignored() -> Ignore {
    Ignore::new().with_path("crates/grimoire-pack/tests/fixtures")
}

#[test]
fn clankshop_is_a_valid_faced_pack() {
    let e = enumerate_with(&repo_root(), &fixtures_ignored()).unwrap();
    let clank = e
        .packs
        .iter()
        .find(|p| p.manifest.name == "clankshop")
        .expect("clankshop pack found");
    assert!(matches!(clank.shape, PackShape::Faced { .. }));
    // The version must parse as semver — the parser's contract. Its value is
    // the pack's to choose.
    assert!(clank.manifest.version.major >= 1, "semver parsed and sane");
    // A pack declares at least one member, and enumeration only yields a pack
    // whose every declared member resolved in this repository (§2).
    assert!(
        clank.manifest.members().next().is_some(),
        "clankshop declares members"
    );
}

#[test]
fn repo_enumerates_exactly_one_pack_when_fixtures_are_ignored() {
    let e = enumerate_with(&repo_root(), &fixtures_ignored()).unwrap();
    let names: Vec<_> = e.packs.iter().map(|p| p.manifest.name.as_str()).collect();
    assert_eq!(
        names,
        vec!["clankshop"],
        "fixture trees must not enumerate as packs of this repository"
    );
    assert!(
        e.issues.is_empty(),
        "ignored trees must not report issues either: {:?}",
        e.issues
    );
}

#[test]
fn without_the_rule_the_fixtures_are_still_visible() {
    // Documents WHY the rule exists (measured 2026-08-15: 3 packs / 8 issues).
    // Deliberately loose — the exact count moves whenever a fixture is added.
    let bare = enumerate(&repo_root()).unwrap();
    assert!(
        bare.packs.len() > 1,
        "a bare scan sees the fixture packs too"
    );
}

#[test]
fn clankshop_member_hashes_compute() {
    let root = repo_root();
    let h = grimoire_pack::hash::member_hash(&root.join("skills/journal")).unwrap();
    assert!(h.starts_with("sha256:"));
}
