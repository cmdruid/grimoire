//! `install.sh` parity: the install *shape*, not just its outcome.
//!
//! This is the dogfood property Phase 4's gate depends on ("a full dogfood
//! session replacing `install.sh` for machine installs"). The `skill` crate
//! copies the tree instead (Phase 2 plan, Finding 1); asserting the shape here
//! is what stops a future refactor from quietly reintroducing copy semantics.

mod sandbox;

use std::path::Path;
use std::process::Command;

use sandbox::{install_alpha, Sandbox};

/// §3's project-lock rule now has **two** implementations — `lock::project_root`
/// and `install.sh`'s `write_lock` — and a rule implemented twice drifts unless
/// something executes both. Every other test in this file asserts that core's
/// semantics *match* `install.sh`'s; none of them ever ran the shell. This one
/// does, and compares where it puts the lock against where `Target` says it is.
#[test]
fn install_sh_and_core_agree_on_the_project_lock_location() {
    let sb = Sandbox::new();
    // install.sh installs from the tree it lives in, so it has to run from
    // inside the fixture library.
    let script = sb.library_root().join("install.sh");
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../install.sh"),
        &script,
    )
    .expect("install.sh is two levels up from this crate");

    let target = sb.project_target("claude-code");
    let out = Command::new("bash")
        .arg(&script)
        .args(["--pack", "alpha", "--target"])
        .arg(&target.skills_dir)
        .env("HOME", sb.home())
        .output()
        .expect("bash runs install.sh");
    assert!(
        out.status.success(),
        "install.sh failed:\n{}",
        String::from_utf8_lossy(&out.stderr)
    );

    assert!(
        target.lock_path.is_file(),
        "install.sh must write the project lock where core reads it ({})\nstdout: {}",
        target.lock_path.display(),
        String::from_utf8_lossy(&out.stdout)
    );
    let beside_agent_dir = sb.project().join(".claude/grimoire.lock");
    assert!(
        !beside_agent_dir.exists(),
        "the pre-D5 location must stay empty — a lock at {} is invisible to the \
         other agent dirs in this project",
        beside_agent_dir.display()
    );
}

#[test]
fn an_edit_in_the_library_is_live_through_the_installed_path() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // Edit the library AFTER installing.
    let source = sb.skill_dir("beta").join("SKILL.md");
    std::fs::write(
        &source,
        "---\nname: beta\ndescription: edited in the clone\n---\nnew body\n",
    )
    .unwrap();

    let through_install = std::fs::read_to_string(target.skills_dir.join("beta/SKILL.md")).unwrap();
    assert!(
        through_install.contains("edited in the clone"),
        "the install must be a live view of the library, not a copy"
    );
}

#[test]
fn a_new_file_in_the_library_appears_through_the_installed_path() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    std::fs::write(sb.skill_dir("beta").join("REFERENCE.md"), "added later\n").unwrap();
    assert!(
        target.skills_dir.join("beta/REFERENCE.md").is_file(),
        "a copy would not have grown the new file"
    );
}

#[test]
fn nothing_is_ever_written_into_the_library() {
    let sb = Sandbox::new();
    let before = tree(&sb.library_root());
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());
    let plan = grimoire_core::remove::plan_remove(&target, "alpha").unwrap();
    grimoire_core::remove::remove(&target, &plan).unwrap();

    assert_eq!(
        before,
        tree(&sb.library_root()),
        "install/remove must never mutate the library — the clone is canonical"
    );
}

/// Every path under `root`, sorted — a cheap structural fingerprint.
fn tree(root: &std::path::Path) -> Vec<String> {
    let mut out = Vec::new();
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        for entry in std::fs::read_dir(&dir).unwrap().filter_map(Result::ok) {
            let path = entry.path();
            out.push(
                path.strip_prefix(root)
                    .unwrap()
                    .to_string_lossy()
                    .into_owned(),
            );
            if path.is_dir() {
                stack.push(path);
            }
        }
    }
    out.sort();
    out
}
