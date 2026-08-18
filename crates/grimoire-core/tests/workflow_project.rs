//! Workflow (b), end to end at PROJECT scope, plus §3's scope isolation:
//! "Every pack operation targets **exactly one scope**."

mod sandbox;

use grimoire_core::check;
use grimoire_core::inventory;
use grimoire_core::remove;
use sandbox::{install_alpha, Sandbox};

#[test]
fn install_list_check_remove_at_project_scope() {
    let sb = Sandbox::new();
    let target = sb.project_target("claude-code");

    assert_eq!(target.skills_dir, sb.project().join(".claude/skills"));
    assert_eq!(
        target.lock_path,
        sb.project().join(".claude/grimoire.lock"),
        "§3: a project install locks beside the agent dir (install.sh's `dirname $target`)"
    );

    install_alpha(&sb, &target, Vec::new());

    for member in ["alpha", "beta", "gamma"] {
        assert_eq!(
            sb.resolve_link(&target.skills_dir.join(member)),
            std::fs::canonicalize(sb.skill_dir(member)).unwrap()
        );
    }
    assert_eq!(inventory::inventory(&target).unwrap().packs.len(), 1);
    assert!(check::check(&sb.library(), &target).unwrap().is_clean());

    let plan = remove::plan_remove(&target, "alpha").unwrap();
    remove::remove(&target, &plan).unwrap();
    assert!(inventory::inventory(&target).unwrap().packs.is_empty());
}

#[test]
fn project_and_global_installs_do_not_see_each_other() {
    let sb = Sandbox::new();
    let global = sb.global_target("claude-code");
    let project = sb.project_target("claude-code");

    install_alpha(&sb, &global, Vec::new());
    install_alpha(&sb, &project, Vec::new());

    assert_ne!(global.lock_path, project.lock_path);
    assert_eq!(inventory::inventory(&global).unwrap().packs.len(), 1);
    assert_eq!(inventory::inventory(&project).unwrap().packs.len(), 1);

    // Removing at project scope must leave the global install fully intact.
    let plan = remove::plan_remove(&project, "alpha").unwrap();
    remove::remove(&project, &plan).unwrap();

    assert!(inventory::inventory(&project).unwrap().packs.is_empty());
    let still = inventory::inventory(&global).unwrap();
    assert_eq!(still.packs.len(), 1, "the global scope is a different world");
    for member in ["alpha", "beta", "gamma"] {
        assert!(global.skills_dir.join(member).exists());
        assert!(!project.skills_dir.join(member).exists());
    }
}

#[test]
fn a_universal_agent_installs_into_the_shared_project_dir() {
    let sb = Sandbox::new();
    let codex = sb.project_target("codex");
    let cursor = sb.project_target("cursor");

    // Upstream models codex/cursor as reading `.agents/skills` at project
    // scope — so both resolve to the SAME directory and the same lock.
    assert_eq!(codex.skills_dir, sb.project().join(".agents/skills"));
    assert_eq!(codex.skills_dir, cursor.skills_dir);
    assert_eq!(codex.lock_path, cursor.lock_path);

    install_alpha(&sb, &codex, Vec::new());
    // Installing "for cursor" therefore finds the pack already present rather
    // than colliding with itself.
    let outcome = install_alpha(&sb, &cursor, Vec::new());
    assert_eq!(outcome.already_present.len(), 3);
    assert!(outcome.linked.is_empty());
}
