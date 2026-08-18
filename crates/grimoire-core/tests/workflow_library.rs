//! Workflow (a), end to end at GLOBAL scope: the library screen's loop.
//! discover → preflight → install → list → check → remove, against a fixture
//! library and a fake home.

mod sandbox;

use grimoire_core::check::{self, Finding};
use grimoire_core::install::{self, MemberDisposition};
use grimoire_core::inventory;
use grimoire_core::remove;
use sandbox::{install_alpha, Sandbox};

#[test]
fn discover_install_list_check_remove_at_global_scope() {
    let sb = Sandbox::new();
    let library = sb.library();
    let target = sb.global_target("claude-code");

    // ---- discover
    let view = library.enumerate().unwrap();
    assert!(view.issues.is_empty(), "unexpected issues: {:?}", view.issues);
    assert_eq!(view.packs.len(), 1);
    let pack = &view.packs[0];
    assert_eq!(pack.name, "alpha");
    assert!(pack.faced);
    // face (implicit, §2) + required beta + optional gamma
    assert_eq!(
        pack.members.iter().map(|m| m.name.as_str()).collect::<Vec<_>>(),
        ["alpha", "beta", "gamma"]
    );
    assert!(pack.members[0].is_face);
    assert!(!pack.members[2].required, "gamma is optional");
    assert_eq!(
        view.loose.iter().map(|m| m.name.as_str()).collect::<Vec<_>>(),
        ["solo"],
        "a pack's members must not also appear as loose skills"
    );

    // ---- preflight: nothing installed yet
    let plan = install::preflight(&library, "alpha", &target).unwrap();
    assert!(plan.is_installable());
    assert!(plan.replacing.is_none());
    assert!(plan
        .members
        .iter()
        .all(|(_, d)| *d == MemberDisposition::Fresh));

    // ---- install
    let outcome = install_alpha(&sb, &target, Vec::new());
    assert_eq!(outcome.linked.len(), 3, "face + required + optional");
    assert_eq!(outcome.face, Some(sb.skill_dir("alpha")));

    // every member is a SYMLINK INTO THE LIBRARY (install.sh parity)
    for member in ["alpha", "beta", "gamma"] {
        let link = target.skills_dir.join(member);
        assert_eq!(sb.resolve_link(&link), std::fs::canonicalize(sb.skill_dir(member)).unwrap());
    }

    // the lock landed in the SHARED global lock (§3), not beside .claude
    assert_eq!(target.lock_path, sb.home().join(".agents/grimoire.lock"));
    assert!(target.lock_path.is_file());

    // ---- list
    let inv = inventory::inventory(&target).unwrap();
    assert_eq!(inv.packs.len(), 1);
    let installed = &inv.packs[0];
    assert_eq!(installed.name, "alpha");
    assert!(installed.dir_present);
    assert_eq!(installed.entry.version, "1.0.0");
    assert_eq!(installed.entry.r#ref.as_deref(), Some("abc1234"));
    assert_eq!(installed.entry.installed_at, "2026-08-18T12:00:00Z");
    assert_eq!(installed.entry.source, sb.library_root().display().to_string());
    assert_eq!(installed.entry.skills.len(), 3);
    assert!(installed.entry.skills["beta"].required);
    assert!(!installed.entry.skills["gamma"].required);
    assert!(
        installed.entry.manifest.is_none(),
        "a faced pack's manifest lives in its installed PACK.md, not the lock (§3)"
    );
    assert!(inv.loose.is_empty(), "every link belongs to the pack entry");

    // ---- check: clean
    let report = check::check(&library, &target).unwrap();
    assert!(
        report.is_clean(),
        "fresh install should be clean: {:?}",
        report.findings
    );

    // ---- remove
    let plan = remove::plan_remove(&target, "alpha").unwrap();
    assert_eq!(plan.unlink.len(), 3);
    assert!(plan.retained.is_empty());
    assert!(plan.foreign.is_empty());
    assert!(
        plan.face_warning.is_some(),
        "§5: setup artifacts may persist — the face must be surfaced BEFORE deleting"
    );
    remove::remove(&target, &plan).unwrap();

    for member in ["alpha", "beta", "gamma"] {
        assert!(
            !target.skills_dir.join(member).exists(),
            "{member} should be unlinked"
        );
    }
    assert!(inventory::inventory(&target).unwrap().packs.is_empty());
    // the library itself is untouched — we only ever removed links
    assert!(sb.skill_dir("alpha").join("SKILL.md").is_file());
}

#[test]
fn a_deselected_optional_member_is_never_installed_and_never_drift() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    let outcome = install_alpha(&sb, &target, vec!["gamma".to_string()]);

    assert_eq!(outcome.linked.len(), 2, "face + beta only");
    assert!(!target.skills_dir.join("gamma").exists());

    let inv = inventory::inventory(&target).unwrap();
    assert!(
        !inv.packs[0].entry.skills.contains_key("gamma"),
        "§5: an optional member absent from the lock stays uninstalled"
    );

    // §5: "A missing optional member is never drift."
    let report = check::check(&sb.library(), &target).unwrap();
    assert!(report.is_clean(), "{:?}", report.findings);
    assert!(
        !report
            .findings
            .iter()
            .any(|f| matches!(f, Finding::OptionalMemberAbsent { .. })),
        "a member that was never installed is not an absence to report"
    );
}

#[test]
fn install_is_idempotent() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    install_alpha(&sb, &target, Vec::new());

    let second = install_alpha(&sb, &target, Vec::new());
    assert_eq!(second.already_present.len(), 3);
    assert!(second.linked.is_empty());
    assert!(check::check(&sb.library(), &target).unwrap().is_clean());
}

#[test]
fn an_atom_installs_without_minting_a_lock_entry() {
    let sb = Sandbox::new();
    let target = sb.global_target("claude-code");
    let outcome = install::install_atom(&sb.library(), "solo", &target).unwrap();

    assert_eq!(outcome.linked.len(), 1);
    assert_eq!(
        sb.resolve_link(&target.skills_dir.join("solo")),
        std::fs::canonicalize(sb.skill_dir("solo")).unwrap()
    );
    assert!(
        !target.lock_path.exists(),
        "an atom is not a pack — install.sh locks nothing for a bare skill"
    );

    // it shows up as a loose install, not as pack content
    let inv = inventory::inventory(&target).unwrap();
    assert!(inv.packs.is_empty());
    assert_eq!(inv.loose.len(), 1);
    assert_eq!(inv.loose[0].name, "solo");
}
