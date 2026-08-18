//! `check`'s fact table (spec §5). Facts, not verdicts — every case below is
//! something the TUI renders and offers an action for, never something core
//! decides on the user's behalf.

mod sandbox;

use grimoire_core::check::{self, Finding};
use grimoire_core::install;
use sandbox::{install_alpha, Sandbox};

#[test]
fn a_missing_required_member_is_broken() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    std::fs::remove_file(target.skills_dir.join("beta")).unwrap();

    let report = check::check(&sb.library(), &target).unwrap();
    assert!(!report.is_clean());
    assert!(report.findings.contains(&Finding::RequiredMemberMissing {
        pack: "alpha".to_string(),
        member: "beta".to_string(),
    }));
}

#[test]
fn a_missing_optional_member_is_fine() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    std::fs::remove_file(target.skills_dir.join("gamma")).unwrap();

    let report = check::check(&sb.library(), &target).unwrap();
    assert!(report.findings.contains(&Finding::OptionalMemberAbsent {
        pack: "alpha".to_string(),
        member: "gamma".to_string(),
    }));
    assert!(
        report.is_clean(),
        "§5: an optional member's absence is *fine*, never drift: {:?}",
        report.findings
    );
}

#[test]
fn edited_bytes_are_moved_since_install_not_an_error() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // §4: hashes are authoritative over version for installed content.
    std::fs::write(
        sb.skill_dir("beta").join("SKILL.md"),
        "---\nname: beta\ndescription: moved\n---\ndifferent bytes\n",
    )
    .unwrap();

    let report = check::check(&sb.library(), &target).unwrap();
    let moved = report
        .findings
        .iter()
        .find(|f| matches!(f, Finding::MemberMoved { member, .. } if member == "beta"))
        .expect("a hash mismatch is a *moved since install* fact");
    match moved {
        Finding::MemberMoved { locked, actual, .. } => {
            assert_ne!(locked, actual);
            assert!(locked.starts_with("sha256:"), "Appendix A hash shape");
        }
        other => panic!("unexpected finding {other:?}"),
    }
}

#[test]
fn a_vanished_pack_directory_is_orphaned() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // The pack dir (face + installed PACK.md) goes away; the lock entry stays.
    std::fs::remove_file(target.skills_dir.join("alpha")).unwrap();

    let report = check::check(&sb.library(), &target).unwrap();
    assert!(report.findings.contains(&Finding::OrphanedPack {
        pack: "alpha".to_string()
    }));
}

#[test]
fn two_packs_locking_different_hashes_for_one_member_disagree() {
    let sb = Sandbox::new();
    sb.add_sharing_pack();
    let target = sb.global_target("claude-code");
    let library = sb.library();

    install_alpha(&sb, &target, Vec::new());
    // Move beta's bytes between the two installs, so the two lock entries
    // record different hashes for the same member (§5's shared-member case:
    // "last install won the bytes on disk").
    std::fs::write(
        sb.skill_dir("beta").join("SKILL.md"),
        "---\nname: beta\ndescription: changed between installs\n---\nbody\n",
    )
    .unwrap();
    install::install(install::InstallRequest {
        library: &library,
        pack: "delta",
        target: &target,
        installed_at: sb.timestamp(),
        source_ref: None,
        skip_optional: Vec::new(),
    })
    .unwrap();

    let report = check::check(&library, &target).unwrap();
    let disagreement = report
        .findings
        .iter()
        .find(|f| matches!(f, Finding::SharedMemberDisagreement { member, .. } if member == "beta"))
        .expect("§5: check reports the mismatch against each lock's expectation");
    match disagreement {
        Finding::SharedMemberDisagreement { packs, .. } => {
            assert_eq!(packs.len(), 2);
        }
        other => panic!("unexpected finding {other:?}"),
    }
}

#[test]
fn check_needs_no_source_and_surfaces_library_issues() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    // A broken manifest in the library is a library issue, not a lock finding.
    sb.write_skill("broken", "a skill whose pack manifest is unresolvable");
    sb.write_manifest("broken", "1.0.0", "broken", "no-such-member", None);

    let report = check::check(&sb.library(), &target).unwrap();
    assert_eq!(report.library_issues.len(), 1, "{:?}", report.library_issues);
    assert!(report.library_issues[0].contains("no-such-member"));
    assert!(
        report
            .findings
            .iter()
            .all(|f| !matches!(f, Finding::RequiredMemberMissing { .. })),
        "a library issue must not be reported as installed-state drift"
    );
}
