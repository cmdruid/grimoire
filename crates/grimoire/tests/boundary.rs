//! The app's architectural invariant, as a test rather than a comment.
//!
//! `grimoire-core` keeps itself homeless so its operations stay hermetic, and
//! `tests/boundary.rs` over there enforces it. The app is where the environment
//! legitimately *is* read — but if it is read in more than one place, the two
//! readings can disagree, and a `home` that disagrees with the one the agent
//! table resolved against misclassifies scope silently (`scope_for` is lexical:
//! a wrong `home` yields a wrong answer, not an error).
//!
//! So `env.rs` is the single door, and this is what keeps it single.

use std::path::PathBuf;

fn src_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("src")
}

/// Every `.rs` under `src/`, as (file name, contents).
fn sources() -> Vec<(String, String)> {
    let mut out = Vec::new();
    let mut stack = vec![src_dir()];
    while let Some(dir) = stack.pop() {
        for entry in std::fs::read_dir(&dir).unwrap().filter_map(Result::ok) {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            if path.extension().and_then(|e| e.to_str()) != Some("rs") {
                continue;
            }
            out.push((
                path.file_name().unwrap().to_string_lossy().into_owned(),
                std::fs::read_to_string(&path).unwrap(),
            ));
        }
    }
    assert!(out.len() > 1, "the scan found nothing to check");
    out
}

/// `env.rs` builds every `Target`. A second construction site is a second
/// `home`, and the disagreement is invisible until an install lands in the
/// wrong scope.
#[test]
fn only_env_rs_constructs_a_target() {
    for (name, text) in sources() {
        let constructs = text.contains("Target::global") || text.contains("Target::project");
        if name == "env.rs" {
            assert!(
                constructs,
                "env.rs should hold the Target constructors (AppEnv::global_target / \
                 project_target)"
            );
        } else {
            assert!(
                !constructs,
                "{name} constructs a Target directly — route it through AppEnv, or the \
                 home it passes can disagree with the one the agent table used"
            );
        }
    }
}

/// The same rule for the environment itself. `main.rs` is allowed exactly one
/// read — `std::env::args`, which is the command line, not the environment.
#[test]
fn only_env_rs_reads_the_environment() {
    for (name, text) in sources() {
        let reads = text.contains("std::env::var");
        if name == "env.rs" {
            assert!(reads, "env.rs should hold the environment reads");
        } else {
            assert!(
                !reads,
                "{name} reads the process environment — it belongs in AppEnv, which is \
                 resolved once so nothing downstream can disagree with it"
            );
        }
    }
}

/// A guard for the guards: both assertions above are vacuous if the scan cannot
/// actually see the strings it is looking for.
#[test]
fn the_scan_can_see_what_it_checks() {
    let files = sources();
    let env_rs = files
        .iter()
        .find(|(n, _)| n == "env.rs")
        .expect("env.rs is in the scan");
    assert!(env_rs.1.contains("std::env::var"));
    assert!(env_rs.1.contains("Target::global"));
    assert!(
        files.iter().any(|(n, _)| n == "main.rs"),
        "the scan must reach main.rs, the most likely place for a second door"
    );
}
