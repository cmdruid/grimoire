//! Enumerate THIS repository — the guard for a trap the fixtures cannot catch.
//!
//! Phase 1 shipped green from a linked worktree and turned `main` red the
//! moment it landed: enumeration descended into `.workstreams/<stream>/` and
//! reported that checkout's packs as the repository's own. A worktree contains
//! no nested checkout, so no hermetic fixture reproduces it — only running
//! against a real repository root does.
//!
//! `grimoire-core` is repo-scanning code and inherits that exposure directly,
//! so this test exists to fail in the root checkout if the protection regresses.
//! It follows `grimoire-pack`'s `tests/clankshop.rs` precedent: pin the live
//! repository *structurally*, never another stream's editable content.

use std::path::{Path, PathBuf};

use grimoire_core::library::Library;

/// The repository root: `<manifest>/../..`, or `$GRIMOIRE_LIVE_ROOT`.
///
/// The override exists so this guard can be pointed at the ROOT CHECKOUT from
/// inside a worktree — the only way to exercise the nested-checkout case
/// *before* landing rather than discovering it on a red trunk afterwards:
///
/// ```text
/// GRIMOIRE_LIVE_ROOT=/path/to/root-checkout cargo test -p grimoire-core --test live_repo
/// ```
fn repo_root() -> PathBuf {
    if let Some(root) = std::env::var_os("GRIMOIRE_LIVE_ROOT") {
        return PathBuf::from(root);
    }
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .expect("crates/<crate> sits two levels below the repo root")
        .to_path_buf()
}

#[test]
fn the_repository_enumerates_as_its_own_content() {
    let root = repo_root();
    let view = Library::open(&root).enumerate().unwrap();

    assert!(
        view.issues.is_empty(),
        "the repository should enumerate cleanly: {:?}",
        view.issues
    );
    let names: Vec<&str> = view.packs.iter().map(|p| p.name.as_str()).collect();
    assert!(
        names.contains(&"clankshop"),
        "the flagship pack should be found, got {names:?}"
    );
}

/// The Phase 1 trap itself: no pack, member, or loose skill may resolve to a
/// path inside a nested checkout. In the root checkout `.workstreams/` holds
/// live worktrees; in a worktree there are none, and the test is a no-op that
/// still documents the rule.
#[test]
fn nothing_resolves_inside_a_nested_checkout() {
    let root = repo_root();
    let view = Library::open(&root).enumerate().unwrap();

    let mut offenders: Vec<String> = Vec::new();
    let mut check = |label: &str, dir: &Path| {
        if dir.strip_prefix(&root).is_ok_and(|rel| {
            rel.components()
                .next()
                .is_some_and(|c| c.as_os_str() == ".workstreams" || c.as_os_str() == "repos")
        }) {
            offenders.push(format!("{label} -> {}", dir.display()));
        }
    };
    for pack in &view.packs {
        check(&pack.name, &pack.dir);
        for member in &pack.members {
            check(&member.name, &member.dir);
        }
    }
    for loose in &view.loose {
        check(&loose.name, &loose.dir);
    }

    assert!(
        offenders.is_empty(),
        "enumeration descended into a nested checkout — the exact failure that \
         turned main red at the Phase 1 land:\n{}",
        offenders.join("\n")
    );
}
