//! `TestBackend` smoke tests — the roadmap's Phase 3 gate item.
//!
//! These assert that each screen *draws* and that what it draws carries the
//! facts the user needs to act. They deliberately check for content, not
//! layout: pinning exact buffer geometry makes every cosmetic change a test
//! failure, and would not have caught a single bug this phase found.

use ratatui::backend::TestBackend;
use ratatui::Terminal;

use skill_grimoire::app::{App, Key, Screen};
use skill_grimoire::env::AppEnv;
use skill_grimoire::{job, render};

mod world;
use world::World;

/// Draw one frame and flatten it to text.
fn screen_text(app: &App) -> String {
    let mut terminal = Terminal::new(TestBackend::new(100, 30)).unwrap();
    terminal
        .draw(|frame| render::draw(frame, app))
        .expect("the screen must draw");
    let buffer = terminal.backend().buffer().clone();
    (0..buffer.area.height)
        .map(|y| {
            (0..buffer.area.width)
                .map(|x| buffer[(x, y)].symbol())
                .collect::<String>()
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Be the worker, **in order**. FIFO matters: the real loop sends jobs in the
/// order the app returned them and applies outcomes in the order they come
/// back, so draining LIFO here would apply `Enumerated` after `Surveyed` and
/// silently test a sequence that never happens.
fn settle(app: &mut App, jobs: Vec<job::Job>) {
    let mut queue = std::collections::VecDeque::from(jobs);
    while let Some(job) = queue.pop_front() {
        queue.extend(app.apply(job::run(job)));
    }
}

#[test]
fn the_library_screen_lists_packs_loose_skills_and_the_scope() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);

    let text = screen_text(&app);
    assert!(text.contains("alpha"), "the pack is listed:\n{text}");
    assert!(text.contains("solo"), "the loose skill is listed:\n{text}");
    assert!(text.contains("pack"), "rows are labelled by kind:\n{text}");
    // D2: the picker is always visible, so which scope is in view is never a
    // question the user has to work out.
    assert!(text.contains("global"), "the scope is shown:\n{text}");
    // Themed verbs are the labels.
    assert!(text.contains("learn"), "themed verbs label the actions:\n{text}");
}

/// An empty frame is drawn before the first enumeration returns — the loop
/// draws immediately and the walk is on the worker, so this state is real.
#[test]
fn the_screen_draws_before_any_job_has_returned() {
    let world = World::new();
    let mut app = world.app();
    let _ = app.launch();
    let text = screen_text(&app);
    assert!(text.contains("perusing"), "a busy hint is shown:\n{text}");
}

#[test]
fn the_confirm_screen_shows_every_member_and_its_disposition() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);
    app.cursor = app
        .rows()
        .iter()
        .position(|r| r.name() == "alpha")
        .unwrap();
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);

    let text = screen_text(&app);
    assert!(matches!(app.screen, Screen::Confirm(_)));
    for member in ["alpha", "beta", "gamma"] {
        assert!(text.contains(member), "{member} is listed:\n{text}");
    }
    assert!(text.contains("will link"), "dispositions are shown:\n{text}");
    assert!(text.contains("face"), "the face is marked:\n{text}");
    assert!(text.contains("optional"), "classification is shown:\n{text}");
}

/// D3 at the pixel level: the collision, where it points, and the fact that
/// v0.1 will not adopt it — plus no offer to resolve.
#[test]
fn a_blocked_confirm_screen_explains_the_collision_and_offers_no_resolution() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);

    let target = app.target().unwrap();
    std::fs::create_dir_all(&target.skills_dir).unwrap();
    let squatter = world.dir.path().join("squatter");
    std::fs::create_dir_all(&squatter).unwrap();
    std::os::unix::fs::symlink(&squatter, target.skills_dir.join("beta")).unwrap();

    app.cursor = app.rows().iter().position(|r| r.name() == "alpha").unwrap();
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);

    let text = screen_text(&app);
    assert!(text.contains("COLLISION"), "the collision is named:\n{text}");
    assert!(text.contains("blocked"), "and the plan is refused:\n{text}");
    assert!(
        !text.contains("adopt it") && !text.contains("replace it"),
        "v0.1 must not offer a resolution it cannot perform:\n{text}"
    );
}

/// §5 MUST: the teardown warning appears *before* anything is deleted.
#[test]
fn the_remove_screen_warns_about_setup_artifacts_before_deleting() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);
    app.cursor = app.rows().iter().position(|r| r.name() == "alpha").unwrap();
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);

    app.cursor = app.rows().iter().position(|r| r.name() == "alpha").unwrap();
    let jobs = app.on_key(Key::Remove);
    settle(&mut app, jobs);

    let text = screen_text(&app);
    assert!(text.contains("forget alpha"), "{text}");
    assert!(text.contains("unlink"), "the plan is shown:\n{text}");
    assert!(
        text.contains("set things up"),
        "§5's teardown warning must appear before deleting:\n{text}"
    );
    // Still nothing removed at this point.
    assert!(app.target().unwrap().skills_dir.join("beta").exists());
}

#[test]
fn the_help_screen_gives_the_plain_aliases() {
    let world = World::new();
    let mut app = world.app();
    app.on_key(Key::Help);
    let text = screen_text(&app);
    assert!(text.contains("install"), "plain aliases in help:\n{text}");
    assert!(text.contains("remove"), "{text}");
}

/// The ambient check's findings reach the status bar as facts (§5), including
/// the *fine* one, which must never be dressed up as drift.
#[test]
fn drift_is_surfaced_on_the_status_line() {
    let world = World::new();
    let mut app = world.app();
    let launch = app.launch();
    settle(&mut app, launch);
    app.cursor = app.rows().iter().position(|r| r.name() == "alpha").unwrap();
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);

    // Break the install the way a user would: delete a required member's link.
    let target = app.target().unwrap();
    std::fs::remove_file(target.skills_dir.join("beta")).unwrap();
    let jobs = app.on_key(Key::Refresh);
    settle(&mut app, jobs);

    let text = screen_text(&app);
    assert!(
        text.contains("broken") || text.contains("finding"),
        "check's fact should reach the status line:\n{text}"
    );
}

#[test]
fn a_failure_is_rendered_rather_than_crashing_the_loop() {
    let world = World::new();
    let mut app = App::new(AppEnv::rooted(world.home()), world.library(), None);
    app.apply(job::Done::Failed("something went wrong".into()));
    let text = screen_text(&app);
    assert!(text.contains("failed"), "{text}");
    assert!(text.contains("something went wrong"), "{text}");
}
