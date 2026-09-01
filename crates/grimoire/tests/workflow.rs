//! Workflow (a) end to end, headlessly: browse → learn → check → forget.
//!
//! No terminal is involved. `App` returns jobs rather than dispatching them, so
//! a test can be the worker: run the job on the spot, feed the outcome back, and
//! assert on state. That is the whole reason the state machine holds no
//! rendering — the interaction is testable, not just the widgets.

use std::path::Path;

use grimoire_core::target::Scope;
use skill_grimoire::app::{App, Key, Row, Screen};
use skill_grimoire::env::AppEnv;
use skill_grimoire::job;

mod world;
use world::World;

/// Be the worker: run every job the app asked for, feed each outcome back, and
/// keep going until the app stops asking. Mirrors the real loop's drain.
/// FIFO, mirroring the real loop: jobs are dispatched in the order the app
/// returned them, and outcomes applied in the order they come back.
fn settle(app: &mut App, jobs: Vec<job::Job>) {
    let mut queue = std::collections::VecDeque::from(jobs);
    let mut guard = 0;
    while let Some(job) = queue.pop_front() {
        queue.extend(app.apply(job::run(job)));
        guard += 1;
        assert!(guard < 50, "the app kept asking for work — a job loop");
    }
}

fn select(app: &mut App, name: &str) {
    let index = app
        .rows()
        .iter()
        .position(|r| r.name() == name)
        .unwrap_or_else(|| panic!("{name} is not listed: {:?}", app.rows()));
    app.cursor = index;
}

#[test]
fn browse_learn_check_forget_at_global_scope() {
    let world = World::new();
    let mut app = world.app();

    // Browse.
    let launch = app.launch();
    settle(&mut app, launch);
    assert!(
        app.rows().contains(&Row::Pack("alpha".into())),
        "the pack should be listed: {:?}",
        app.rows()
    );
    assert!(
        app.rows().contains(&Row::Loose("solo".into())),
        "the loose skill should be listed too"
    );
    assert!(!app.is_installed("alpha"), "nothing is installed yet");

    // Learn it: enter opens the §5 preflight, enter again commits.
    select(&mut app, "alpha");
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    let Screen::Confirm(plan) = &app.screen else {
        panic!("enter on a pack should open the confirm screen");
    };
    assert!(
        plan.is_installable(),
        "a fresh destination has no collisions"
    );
    assert_eq!(plan.members.len(), 3, "face + required + optional");

    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    assert!(
        matches!(&app.screen, Screen::Outcome(text) if text.contains("learned alpha")),
        "the install should report itself"
    );

    // The install is a live symlink, and the survey saw it.
    let target = app.target().unwrap();
    for member in ["alpha", "beta", "gamma"] {
        let link = target.skills_dir.join(member);
        assert!(
            std::fs::symlink_metadata(&link)
                .unwrap()
                .file_type()
                .is_symlink(),
            "{member} must be a symlink, never a copy"
        );
    }
    app.on_key(Key::Back); // dismiss the outcome
    assert!(app.is_installed("alpha"), "the survey should see it now");

    // Check ran ambiently and found nothing.
    assert!(
        app.report.as_ref().unwrap().is_clean(),
        "a fresh install should be clean: {:?}",
        app.report.as_ref().unwrap().findings
    );

    // Forget it.
    select(&mut app, "alpha");
    let jobs = app.on_key(Key::Remove);
    settle(&mut app, jobs);
    let Screen::ConfirmRemove(plan) = &app.screen else {
        panic!("d on an installed pack should open the remove confirm");
    };
    assert_eq!(plan.unlink.len(), 3);
    assert!(
        plan.face_warning.is_some(),
        "§5 MUST surface that setup artifacts may persist, before deleting"
    );

    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);
    assert!(!app.is_installed("alpha"), "the entry should be gone");
    assert!(
        !target.skills_dir.join("beta").exists(),
        "its members should be unlinked"
    );
}

/// D3: a collision is rendered and the install stops. There is deliberately no
/// key that resolves it — §5 permits adopt/replace, and core implements neither.
#[test]
fn a_collision_is_shown_and_cannot_be_resolved_away() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);

    // Something else already occupies `beta`'s name in the destination.
    let target = app.target().unwrap();
    std::fs::create_dir_all(&target.skills_dir).unwrap();
    let squatter = world.dir.path().join("squatter");
    std::fs::create_dir_all(&squatter).unwrap();
    std::os::unix::fs::symlink(&squatter, target.skills_dir.join("beta")).unwrap();

    select(&mut app, "alpha");
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);

    let Screen::Confirm(plan) = &app.screen else {
        panic!("expected the confirm screen");
    };
    assert!(!plan.is_installable(), "the collision must block");
    assert_eq!(plan.blocking().count(), 1);

    // Enter on a blocked plan does nothing at all — no install, no resolution.
    let jobs = app.on_key(Key::Confirm);
    assert!(jobs.is_empty(), "a blocked plan must dispatch no work");
    assert!(
        matches!(app.screen, Screen::Confirm(_)),
        "and it must stay on screen rather than silently returning"
    );
    assert!(
        !target.skills_dir.join("alpha").exists(),
        "nothing may have been installed"
    );

    // Any other key backs out.
    app.on_key(Key::Back);
    assert!(matches!(app.screen, Screen::Library));
}

/// D2: one picked scope. Switching the picker re-surveys and shows a different
/// installed set — it never merges the two.
#[test]
fn the_two_scopes_are_surveyed_separately() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);

    // Install at global scope.
    select(&mut app, "alpha");
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);
    assert!(app.is_installed("alpha"));

    // Switch to project scope: same library, different destination, and the
    // pack is NOT installed there.
    let jobs = app.on_key(Key::ToggleScope);
    settle(&mut app, jobs);
    assert_eq!(app.scope, Scope::Project);
    assert!(
        !app.is_installed("alpha"),
        "a global install must not show as installed at project scope (§3)"
    );

    // ...and back.
    let jobs = app.on_key(Key::ToggleScope);
    settle(&mut app, jobs);
    assert!(app.is_installed("alpha"));
}

/// Project scope with no project opened has no destination. The app says so
/// rather than inventing a root — the same refusal core makes about `home`.
#[test]
fn project_scope_without_a_project_has_no_target() {
    let world = World::new();
    let mut app = App::new(AppEnv::rooted(world.home()), world.library(), None);
    let launch = app.launch();
    settle(&mut app, launch);

    let jobs = app.on_key(Key::ToggleScope);
    settle(&mut app, jobs);
    assert!(app.target().is_none());
    assert!(app.status.contains("--project"), "status: {}", app.status);

    // And an install attempt is refused rather than panicking on the missing target.
    select(&mut app, "alpha");
    let jobs = app.on_key(Key::Confirm);
    assert!(jobs.is_empty(), "no destination means no work");
}

/// A loose skill is an atom: installed directly, with no lock entry — the same
/// thing `install.sh` does for a bare skill.
#[test]
fn a_loose_skill_installs_without_a_lock_entry() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);

    select(&mut app, "solo");
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);

    let target = app.target().unwrap();
    assert!(target.skills_dir.join("solo").exists(), "the link is made");
    assert!(
        !Path::new(&target.lock_path).exists(),
        "an atom writes no lock (install.sh parity)"
    );
}
