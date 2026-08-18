//! The crate's architectural invariants, as tests rather than comments.
//!
//! Phase 2's dependency decision (plan, *Finding 2*) and its no-UI rule are
//! only durable if violating them fails the suite. A comment saying "no tokio
//! here" does not survive a well-meaning refactor; this file does.

use std::path::{Path, PathBuf};
use std::process::Command;

/// Crates that must never appear in `grimoire-core`'s dependency tree.
///
/// - `skill` / `tokio`: the vendoring decision — a pinned `=0.8.3` freezes the
///   agent table it exists to provide, and its 47 rows contradict spec §3's
///   four recognized agent dirs. Dropping it removed the async justification
///   with it.
/// - UI crates: `grimoire-core` holds operations; rendering is the frontend's.
const FORBIDDEN: &[&str] = &["skill", "tokio", "ratatui", "crossterm", "termion"];

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

#[test]
fn the_dependency_tree_stays_inside_its_floor() {
    let output = Command::new(env!("CARGO"))
        .args([
            "tree",
            "-p",
            "grimoire-core",
            "--edges",
            "normal",
            "--prefix",
            "none",
            "--no-dedupe",
        ])
        .current_dir(manifest_dir())
        .output()
        .expect("cargo tree runs");
    assert!(
        output.status.success(),
        "cargo tree failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    let tree = String::from_utf8_lossy(&output.stdout);

    for forbidden in FORBIDDEN {
        let present = tree
            .lines()
            .filter_map(|l| l.split_whitespace().next())
            .any(|name| name == *forbidden);
        assert!(
            !present,
            "`{forbidden}` is back in grimoire-core's dependency tree — see the \
             Phase 2 plan's Finding 2 before re-adding it.\n{tree}"
        );
    }
}

/// The crate is *homeless*: operations take their environment as parameters.
/// `AgentEnv::from_process` is the one documented exception, so the process
/// environment may be read there and nowhere else.
#[test]
fn only_the_documented_constructor_reads_the_environment() {
    let src = manifest_dir().join("src");
    for entry in std::fs::read_dir(&src).unwrap().filter_map(Result::ok) {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        let text = std::fs::read_to_string(&path).unwrap();
        let reads_env = text.contains("std::env::var");
        if path.file_name().unwrap() == "agents.rs" {
            assert!(
                reads_env,
                "agents.rs should hold the one environment read (from_process)"
            );
            assert!(
                env_reads_are_inside_from_process(&text),
                "an environment read escaped `AgentEnv::from_process` in agents.rs"
            );
        } else {
            assert!(
                !reads_env,
                "{} reads the process environment — operations must take it as a \
                 parameter, or hermetic tests become impossible",
                path.display()
            );
        }
    }
}

/// Every `std::env::var` occurrence in agents.rs must sit after the
/// `from_process` signature and before the next item at the same level.
fn env_reads_are_inside_from_process(text: &str) -> bool {
    let Some(start) = text.find("pub fn from_process()") else {
        return false;
    };
    // The function ends at the first line that closes it at 4-space indent.
    let after = &text[start..];
    let end = after.find("\n    }\n").map_or(after.len(), |i| i + 6);
    let body = &after[..end];
    let occurrences = text.matches("std::env::var").count();
    occurrences > 0 && body.matches("std::env::var").count() == occurrences
}

/// The seam that made `install.sh` parity possible: nothing in this crate may
/// copy a skill tree into place. Installs are symlinks; a copy would break the
/// live-edit dogfood property Phase 4's gate depends on.
#[test]
fn install_never_copies_a_tree() {
    let install_rs = std::fs::read_to_string(manifest_dir().join("src/install.rs")).unwrap();
    assert!(
        install_rs.contains("std::os::unix::fs::symlink"),
        "install must link"
    );
    for copier in ["fs::copy", "copy_dir", "copy_directory"] {
        assert!(
            !install_rs.contains(copier),
            "install.rs mentions `{copier}` — see Finding 1: copying is exactly \
             what made the upstream installer unusable here"
        );
    }
}

/// A guard for the guard: the forbidden list is only meaningful if the parse it
/// runs against actually contains crate names.
#[test]
fn the_dependency_scan_can_see_real_crates() {
    let output = Command::new(env!("CARGO"))
        .args(["tree", "-p", "grimoire-core", "--prefix", "none"])
        .current_dir(manifest_dir())
        .output()
        .expect("cargo tree runs");
    let tree = String::from_utf8_lossy(&output.stdout);
    let names: Vec<&str> = tree
        .lines()
        .filter_map(|l| l.split_whitespace().next())
        .collect();
    assert!(
        names.contains(&"grimoire-pack") && names.contains(&"serde_json"),
        "the scan parsed no recognizable crate names — it would pass vacuously:\n{tree}"
    );
}

#[test]
fn the_vendored_table_and_the_spec_agree_on_which_dirs_are_global() {
    // The same invariant `target::tests::every_agent_is_globally_scoped`
    // asserts, restated at the boundary: adding an agent here without an
    // AGENT_DIRS entry in grimoire-pack silently misplaces its lock.
    let home = Path::new("/home/u");
    let env = grimoire_core::agents::AgentEnv::rooted(home);
    for agent in grimoire_core::agents::table(&env) {
        assert_eq!(
            grimoire_pack::lock::scope_for(&agent.global_skills_dir, home),
            grimoire_pack::lock::Scope::Global,
            "{} is not covered by grimoire_pack::lock::AGENT_DIRS",
            agent.id
        );
    }
}
