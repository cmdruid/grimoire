//! Terminal setup, teardown, and the panic hook — the part that decides whether
//! a crash leaves the user's shell usable.
//!
//! **Why this is not just `ratatui::init()`.** That helper installs a panic hook
//! which restores the terminal, which is right for a single-threaded app and
//! wrong for this one. [`catch_unwind`](std::panic::catch_unwind) stops an
//! unwind; it does **not** stop the panic *hook* from running first. So a worker
//! job that panics — caught, reported, survived, per [`crate::worker`] — would
//! still have run ratatui's hook on the worker thread: raw mode off, alternate
//! screen left, while the render loop happily keeps drawing frames into the
//! user's normal shell. A live UI painting over a cooked terminal.
//!
//! The hook installed here restores **only when the panicking thread is the one
//! that owns the terminal**. A worker panic then stays what it should be: an
//! event on screen.

use std::io::{self, Stdout};
use std::panic;
use std::thread::{self, ThreadId};

use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::prelude::CrosstermBackend;
use ratatui::Terminal;

pub type Tui = Terminal<CrosstermBackend<Stdout>>;

/// Enter the TUI: install the thread-aware panic hook, then raw mode and the
/// alternate screen. The hook goes first so a failure in setup is still cleaned
/// up.
pub fn init() -> io::Result<Tui> {
    install_panic_hook(thread::current().id(), || {
        let _ = restore();
    });
    enable_raw_mode()?;
    let mut out = io::stdout();
    execute!(out, EnterAlternateScreen)?;
    Terminal::new(CrosstermBackend::new(out))
}

/// Leave the TUI. Safe to call twice — the second call is a no-op in practice,
/// which matters because the panic path and the normal path can both reach it.
pub fn restore() -> io::Result<()> {
    // Raw mode first: it has the wider side effects.
    disable_raw_mode()?;
    execute!(io::stdout(), LeaveAlternateScreen)?;
    Ok(())
}

/// Wrap the current panic hook so `restore` runs **only** for panics on
/// `ui_thread`. Every panic still reaches the previous hook, so nothing is
/// swallowed — a worker panic is reported by the worker and printed by the
/// default hook, but does not tear down a terminal it does not own.
///
/// Separated from [`init`] with an injected `restore` so it can be tested
/// without a terminal (`tests/panic_hook.rs`).
pub fn install_panic_hook<F>(ui_thread: ThreadId, restore: F)
where
    F: Fn() + Send + Sync + 'static,
{
    let previous = panic::take_hook();
    panic::set_hook(Box::new(move |info| {
        if thread::current().id() == ui_thread {
            restore();
        }
        previous(info);
    }));
}
