//! The §5 transaction's edges: collision predicate, rollback, the read-only
//! lock, reinstall facts, and §5's reference counting.

mod sandbox;

use grimoire_core::install::{self, MemberDisposition};
use grimoire_core::inventory;
use grimoire_core::remove;
use grimoire_core::CoreError;
use sandbox::{install_alpha, Sandbox};

/// Set an explicit unix mode. `Permissions::set_readonly(false)` would make the
/// path world-writable (clippy rejects it, rightly) — an install target's
/// permissions are exactly the thing this test must control precisely.
fn set_mode(path: &std::path::Path, mode: u32) {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(mode)).unwrap();
}

#[test]
fn a_link_through_an_intermediate_symlink_is_not_a_collision() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    std::fs::create_dir_all(&target.skills_dir).unwrap();

    // Point at the library through an alias directory: physically the same
    // source, so install.sh calls this "already installed", not a collision.
    let alias = sb.dir.path().join("alias");
    std::os::unix::fs::symlink(sb.library_root(), &alias).unwrap();
    std::os::unix::fs::symlink(
        alias.join("skills/beta"),
        target.skills_dir.join("beta"),
    )
    .unwrap();

    let plan = install::preflight(&sb.library(), "alpha", &target).unwrap();
    let beta = plan
        .members
        .iter()
        .find(|(m, _)| m.name == "beta")
        .map(|(_, d)| d)
        .unwrap();
    assert_eq!(
        *beta,
        MemberDisposition::AlreadyInstalled,
        "physical-path compare: an alias chain to the same source is the same install"
    );
    assert!(plan.is_installable());
}

#[test]
fn a_foreign_symlink_blocks_the_whole_install() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    std::fs::create_dir_all(&target.skills_dir).unwrap();
    let elsewhere = sb.dir.path().join("elsewhere");
    std::fs::create_dir_all(&elsewhere).unwrap();
    std::os::unix::fs::symlink(&elsewhere, target.skills_dir.join("beta")).unwrap();

    let plan = install::preflight(&sb.library(), "alpha", &target).unwrap();
    assert!(!plan.is_installable());
    assert_eq!(plan.blocking().count(), 1);

    let library = sb.library();
    let err = install::install(install::InstallRequest {
        library: &library,
        pack: "alpha",
        target: &target,
        installed_at: sb.timestamp(),
        source_ref: None,
        skip_optional: Vec::new(),
    })
    .unwrap_err();
    assert!(matches!(err, CoreError::Preflight(1)));

    // "no partial install": nothing else was linked, no lock was written.
    assert!(!target.skills_dir.join("alpha").exists());
    assert!(!target.skills_dir.join("gamma").exists());
    assert!(!target.lock_path.exists());
}

#[test]
fn the_face_is_never_adoptable() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    std::fs::create_dir_all(target.skills_dir.join("alpha")).unwrap();

    let plan = install::preflight(&sb.library(), "alpha", &target).unwrap();
    let (_, face) = plan.members.iter().find(|(m, _)| m.is_face).unwrap();
    match face {
        MemberDisposition::Collision { adoptable, .. } => {
            assert!(!adoptable, "§5: the face MUST come from the pack's source")
        }
        other => panic!("expected a collision at the face, got {other:?}"),
    }
}

#[test]
fn a_read_only_lock_rolls_the_links_back() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");

    // §3: a lock declaring a newer version is read-only.
    std::fs::create_dir_all(target.lock_path.parent().unwrap()).unwrap();
    std::fs::write(&target.lock_path, "{\"version\": 2, \"packs\": {}}\n").unwrap();

    let library = sb.library();
    let err = install::install(install::InstallRequest {
        library: &library,
        pack: "alpha",
        target: &target,
        installed_at: sb.timestamp(),
        source_ref: None,
        skip_optional: Vec::new(),
    })
    .unwrap_err();
    assert!(matches!(err, CoreError::LockReadOnly(_)), "got {err:?}");

    // The rollback is the point: a linked-but-unlocked pack is the "silently
    // plausible partial pack" §5 forbids.
    for member in ["alpha", "beta", "gamma"] {
        assert!(
            !target.skills_dir.join(member).exists(),
            "{member} survived a rolled-back install"
        );
    }
    assert_eq!(
        std::fs::read_to_string(&target.lock_path).unwrap(),
        "{\"version\": 2, \"packs\": {}}\n",
        "the read-only lock must be left byte-identical"
    );
}

/// A link failure aborts the whole install: no lock, no surviving links.
///
/// Note what this does NOT prove: with the skills dir read-only the *first*
/// symlink fails, so no link is ever created and the rollback loop has nothing
/// to undo. Rollback's real property — "remove exactly this run's links, never
/// a pre-existing one" — is proven directly in `install.rs`'s unit tests, where
/// a partial set can be constructed deterministically.
#[test]
fn a_link_failure_aborts_with_no_lock_and_no_partial_links() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    std::fs::create_dir_all(&target.skills_dir).unwrap();

    // A pre-existing, unrelated link that this run must NOT remove.
    let bystander = target.skills_dir.join("bystander");
    std::os::unix::fs::symlink(sb.skill_dir("solo"), &bystander).unwrap();

    let plan_ok = install::preflight(&sb.library(), "alpha", &target).unwrap();
    assert!(plan_ok.is_installable());
    // A read-only skills dir makes symlink() fail.

    set_mode(&target.skills_dir, 0o555);

    let library = sb.library();
    let result = install::install(install::InstallRequest {
        library: &library,
        pack: "alpha",
        target: &target,
        installed_at: sb.timestamp(),
        source_ref: None,
        skip_optional: Vec::new(),
    });

    // Restore before asserting, so a failure leaves a readable tree (and so
    // TempDir's cleanup can actually remove the directory).
    set_mode(&target.skills_dir, 0o755);

    assert!(result.is_err(), "a read-only skills dir must fail the install");
    for member in ["alpha", "beta", "gamma"] {
        assert!(
            !target.skills_dir.join(member).exists(),
            "{member} survived the rollback"
        );
    }
    assert!(
        bystander.exists(),
        "rollback removed a link this run did not create"
    );
    assert!(!target.lock_path.exists());
}

#[test]
fn reinstalling_surfaces_the_version_and_source_facts() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // The library moves the pack backward and drops the optional member.
    sb.write_manifest("alpha", "0.9.0", "the alpha pack", "beta", None);

    let plan = install::preflight(&sb.library(), "alpha", &target).unwrap();
    let replacing = plan.replacing.expect("an existing entry is a replace (§5)");
    assert_eq!(replacing.previous_version, "1.0.0");
    assert!(
        replacing.version_moves_backward,
        "§5: a backward version MUST be surfaced, never silent"
    );
    assert!(!replacing.source_changed);
    assert_eq!(replacing.dropped, ["gamma"]);
}

#[test]
fn a_shared_member_is_refcounted_at_pack_altitude() {
    let sb = Sandbox::new();
    sb.add_sharing_pack(); // `delta` also requires `beta`
    let target = sb.global_target("claude-code");
    let library = sb.library();

    install_alpha(&sb, &target, Vec::new());
    install::install(install::InstallRequest {
        library: &library,
        pack: "delta",
        target: &target,
        installed_at: sb.timestamp(),
        source_ref: None,
        skip_optional: Vec::new(),
    })
    .unwrap();

    // Removing alpha must RETAIN beta — delta still references it.
    let plan = remove::plan_remove(&target, "alpha").unwrap();
    assert_eq!(
        plan.retained,
        [("beta".to_string(), "delta".to_string())],
        "§5: reference counting at pack altitude"
    );
    assert!(plan.unlink.iter().all(|(m, _)| m != "beta"));
    remove::remove(&target, &plan).unwrap();

    assert!(target.skills_dir.join("beta").exists(), "beta is still delta's");
    assert!(!target.skills_dir.join("alpha").exists());
    let inv = inventory::inventory(&target).unwrap();
    assert_eq!(inv.packs.len(), 1);
    assert_eq!(inv.packs[0].name, "delta");

    // Now delta's removal frees it.
    let plan = remove::plan_remove(&target, "delta").unwrap();
    assert!(plan.unlink.iter().any(|(m, _)| m == "beta"));
    remove::remove(&target, &plan).unwrap();
    assert!(!target.skills_dir.join("beta").exists());
}

#[test]
fn a_foreign_link_is_reported_and_left_alone() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // Someone else's link replaces beta's.
    let elsewhere = sb.dir.path().join("someone-elses-skills/beta");
    std::fs::create_dir_all(&elsewhere).unwrap();
    let link = target.skills_dir.join("beta");
    std::fs::remove_file(&link).unwrap();
    std::os::unix::fs::symlink(&elsewhere, &link).unwrap();

    let plan = remove::plan_remove(&target, "alpha").unwrap();
    assert_eq!(plan.foreign.len(), 1, "install.sh: never remove a link outside the clone");
    assert!(plan.unlink.iter().all(|(m, _)| m != "beta"));
    remove::remove(&target, &plan).unwrap();
    assert!(link.exists(), "a foreign link must survive our removal");
}

#[test]
fn removing_an_optional_member_leaves_no_trace() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    remove::remove_optional_member(&target, "alpha", "gamma").unwrap();

    assert!(!target.skills_dir.join("gamma").exists());
    let inv = inventory::inventory(&target).unwrap();
    assert_eq!(inv.packs.len(), 1, "the pack itself stays installed");
    assert!(!inv.packs[0].entry.skills.contains_key("gamma"));
    assert!(inv.packs[0].entry.skills.contains_key("beta"));
}

#[test]
fn a_required_member_cannot_be_removed_as_if_optional() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // §5 defines no tool operation for this — it is a state `check` reports.
    assert!(remove::remove_optional_member(&target, "alpha", "beta").is_err());
    assert!(target.skills_dir.join("beta").exists());
}

#[test]
fn a_second_packs_install_preserves_the_first_entry_and_unknown_keys() {
    let sb = Sandbox::new();
    sb.add_sharing_pack();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // A future tool's key at the lock's top level.
    let text = std::fs::read_to_string(&target.lock_path).unwrap();
    let mut value: serde_json::Value = serde_json::from_str(&text).unwrap();
    value["futureKey"] = serde_json::json!("keep me");
    std::fs::write(&target.lock_path, serde_json::to_string_pretty(&value).unwrap()).unwrap();

    let library = sb.library();
    install::install(install::InstallRequest {
        library: &library,
        pack: "delta",
        target: &target,
        installed_at: sb.timestamp(),
        source_ref: None,
        skip_optional: Vec::new(),
    })
    .unwrap();

    let after: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(&target.lock_path).unwrap()).unwrap();
    assert_eq!(after["futureKey"], "keep me", "§3: unknown keys are preserved");
    assert!(after["packs"]["alpha"].is_object(), "the first pack survived");
    assert!(after["packs"]["delta"].is_object());
}
