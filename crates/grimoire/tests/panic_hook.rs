//! Terminal custody on panic: only the thread that owns the terminal restores it.
//!
//! One test function on purpose — a panic hook is process-global, so two tests
//! in this binary would race each other's hooks.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;

use skill_grimoire::ui;

/// A worker panic must NOT restore the terminal — the render loop still owns it
/// and is still drawing. A UI-thread panic must.
///
/// Break it by dropping the `thread::current().id() == ui_thread` guard in
/// `ui::install_panic_hook` and the first assertion fails: the worker's panic
/// restores a terminal it does not own, which in the real app leaves a live UI
/// painting into a cooked shell.
#[test]
fn only_the_ui_thread_restores_the_terminal() {
    let restores = Arc::new(AtomicUsize::new(0));

    let previous = std::panic::take_hook();
    let counter = Arc::clone(&restores);
    ui::install_panic_hook(thread::current().id(), move || {
        counter.fetch_add(1, Ordering::SeqCst);
    });

    // A panic on another thread: caught there, and no restore.
    thread::spawn(|| panic!("worker panic"))
        .join()
        .expect_err("the spawned thread should have panicked");
    assert_eq!(
        restores.load(Ordering::SeqCst),
        0,
        "a non-UI thread's panic must not restore the terminal"
    );

    // A panic on the UI thread: restore fires.
    let _ = catch_unwind(AssertUnwindSafe(|| panic!("ui panic")));
    assert_eq!(
        restores.load(Ordering::SeqCst),
        1,
        "the UI thread's panic must restore the terminal"
    );

    std::panic::set_hook(previous);
}
