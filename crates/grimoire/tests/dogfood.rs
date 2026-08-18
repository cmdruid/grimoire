//! The dogfood loop, driven through the app against THIS repository.
//!
//! Phase 3's gate asks for "a real dogfood install of a skill and a pack from
//! this clone through the TUI". The half a test can own is this one: the same
//! `App` transitions a keypress produces, run against real library content
//! rather than a fixture. The half it cannot own is whether the thing is
//! *usable*, which is what a human at a terminal is for.
//!
//! **It never touches the real home.** The destination is a `TempDir` reached
//! through `AppEnv::rooted`, which is the whole reason core takes its
//! environment as a parameter. A test that installed into `~/.claude/skills`
//! would be indistinguishable from a real install gone wrong.
//!
//! Same `GRIMOIRE_LIVE_ROOT` convention as `grimoire-core`'s `live_repo`, so it
//! can be pointed at the ROOT CHECKOUT from inside a worktree:
//!
//! ```text
//! GRIMOIRE_LIVE_ROOT=/path/to/root-checkout cargo test -p skill-grimoire --test dogfood
//! ```

use std::collections::VecDeque;
use std::path::{Path, PathBuf};

use skill_grimoire::app::{App, Key, Row, Screen};
use skill_grimoire::env::AppEnv;
use skill_grimoire::job;

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

fn settle(app: &mut App, jobs: Vec<job::Job>) {
    let mut queue = VecDeque::from(jobs);
    while let Some(job) = queue.pop_front() {
        queue.extend(app.apply(job::run(job)));
    }
}

fn select(app: &mut App, name: &str) {
    let index = app
        .rows()
        .iter()
        .position(|r| r.name() == name)
        .unwrap_or_else(|| panic!("{name} is not listed"));
    app.cursor = index;
}

/// Install the real `clankshop` pack, and a real loose skill, from this clone.
#[test]
fn a_pack_and_a_skill_install_from_this_clone() {
    let fake_home = tempfile::tempdir().unwrap();
    let mut app = App::new(
        AppEnv::rooted(fake_home.path()),
        repo_root(),
        None, // global scope into the fake home
    );

    let launch = app.launch();
    settle(&mut app, launch);

    let rows = app.rows();
    assert!(
        rows.contains(&Row::Pack("clankshop".into())),
        "the flagship pack should be browsable: {rows:?}"
    );
    assert!(
        rows.iter().any(|r| matches!(r, Row::Loose(_))),
        "the library should surface loose skills too: {rows:?}"
    );

    // --- learn the pack -------------------------------------------------
    select(&mut app, "clankshop");
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    let Screen::Confirm(plan) = &app.screen else {
        panic!("expected the confirm screen, real content should preflight");
    };
    assert!(
        plan.is_installable(),
        "a fresh temp home cannot collide: {:?}",
        plan.blocking().collect::<Vec<_>>()
    );
    let member_count = plan.members.len();
    assert!(member_count > 1, "clankshop has a real roster");

    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);

    let target = app.target().unwrap();
    assert!(app.is_installed("clankshop"), "the lock should record it");
    assert!(
        target.lock_path.is_file(),
        "the global lock lands in the fake home, never the real one: {}",
        target.lock_path.display()
    );
    assert!(
        target.lock_path.starts_with(fake_home.path()),
        "SAFETY: the install must stay inside the temp home"
    );

    // Symlinks, not copies — the property the whole install model rests on.
    let face = target.skills_dir.join("clankshop");
    assert!(
        std::fs::symlink_metadata(&face).unwrap().file_type().is_symlink(),
        "members must be links into the clone"
    );
    assert!(
        std::fs::canonicalize(&face)
            .unwrap()
            .starts_with(std::fs::canonicalize(repo_root()).unwrap()),
        "and they must point back into this repository"
    );

    // The ambient check agrees the install is sound.
    assert!(
        app.report.as_ref().unwrap().is_clean(),
        "a fresh install of real content should be clean: {:?}",
        app.report.as_ref().unwrap().findings
    );

    // --- learn a loose skill --------------------------------------------
    let loose = app
        .rows()
        .iter()
        .find_map(|r| match r {
            Row::Loose(n) => Some(n.clone()),
            Row::Pack(_) => None,
        })
        .expect("at least one loose skill");
    select(&mut app, &loose);
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);
    assert!(
        target.skills_dir.join(&loose).exists(),
        "the loose skill {loose} should be installed"
    );

    // --- forget the pack ------------------------------------------------
    select(&mut app, "clankshop");
    let jobs = app.on_key(Key::Remove);
    settle(&mut app, jobs);
    let Screen::ConfirmRemove(plan) = &app.screen else {
        panic!("expected the remove confirm");
    };
    assert!(
        plan.face_warning.is_some(),
        "§5: the teardown warning must appear while the face still exists"
    );
    let jobs = app.on_key(Key::Confirm);
    settle(&mut app, jobs);
    app.on_key(Key::Back);

    assert!(!app.is_installed("clankshop"), "the entry should be gone");
    assert!(!face.exists(), "and the face unlinked");
}

/// The Phase 1 trap, at app altitude: nothing the user can select may resolve
/// into a nested checkout. In the root checkout `.workstreams/` holds live
/// worktrees; running there is what makes this real.
#[test]
fn nothing_browsable_lives_in_a_nested_checkout() {
    let fake_home = tempfile::tempdir().unwrap();
    let root = repo_root();
    let mut app = App::new(AppEnv::rooted(fake_home.path()), root.clone(), None);
    let launch = app.launch();
    settle(&mut app, launch);

    let view = app.view.as_ref().unwrap();
    let mut offenders = Vec::new();
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
        "the library screen would offer content from a nested checkout:\n{}",
        offenders.join("\n")
    );
}
