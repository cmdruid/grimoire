//! The flagship: this repository's own clankshop pack must enumerate and
//! validate against the library. Runs against the live tree two levels up.

use grimoire_pack::pack::{enumerate, PackShape};
use std::path::PathBuf;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|p| p.parent())
        .expect("crates/grimoire-pack sits two levels below the repo root")
        .to_path_buf()
}

#[test]
fn clankshop_is_a_valid_faced_pack() {
    let e = enumerate(&repo_root()).unwrap();
    let clank = e
        .packs
        .iter()
        .find(|p| p.manifest.name == "clankshop")
        .expect("clankshop pack found");
    assert!(matches!(clank.shape, PackShape::Faced { .. }));
    assert_eq!(clank.manifest.version.to_string(), "1.1.0");
    assert!(clank.manifest.required.iter().any(|m| m == "backlog"));
    assert_eq!(clank.manifest.optional, vec!["bug", "task"]);
    // the author-extension key rides in unknown, preserved
    assert!(clank.manifest.unknown.iter().any(|(k, _)| k == "core"));
    // clankshop is the only pack source outside the crate's own conformance
    // fixtures (which are real trees in this repository and enumerate as such
    // under repo-global member resolution — spec-truthful, pinned here).
    let fixtures = repo_root().join("crates/grimoire-pack/tests/fixtures");
    for p in e.packs.iter().filter(|p| p.manifest.name != "clankshop") {
        assert!(
            p.manifest_path.starts_with(&fixtures),
            "unexpected pack outside fixtures: {:?}",
            p.manifest_path
        );
    }
    for i in &e.issues {
        assert!(
            i.manifest_path.starts_with(&fixtures),
            "unexpected issue outside fixtures: {:?}",
            i.manifest_path
        );
    }
}

#[test]
fn clankshop_member_hashes_compute() {
    let root = repo_root();
    let h = grimoire_pack::hash::member_hash(&root.join("skills/backlog")).unwrap();
    assert!(h.starts_with("sha256:"));
}
