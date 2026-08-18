//! The event loop — the shape Task 1's spike settled, over the real app.
//!
//! One worker thread, two channels, a 50ms poll. No async runtime: core is
//! synchronous and the UI is modal, so at most one operation is ever in flight.
//! The loop's only jobs are to drain outcomes, translate keys, and redraw —
//! every decision belongs to [`App`].

use std::io;
use std::path::PathBuf;
use std::sync::mpsc::{self, TryRecvError};
use std::time::Duration;

use ratatui::crossterm::event::{self, Event, KeyCode, KeyEventKind};

use crate::app::{App, Key};
use crate::env::AppEnv;
use crate::job::{self, Done};
use crate::worker::{self, Outcome};

/// How long a redraw waits for input. Long enough to be cheap when idle, short
/// enough that a worker outcome is picked up without a perceptible lag.
const TICK: Duration = Duration::from_millis(50);

pub fn run(env: AppEnv, library_root: PathBuf, project_root: Option<PathBuf>) -> io::Result<()> {
    let (job_tx, job_rx) = mpsc::channel();
    let (done_tx, done_rx) = mpsc::channel::<Outcome<Done>>();
    let handle = worker::spawn(job_rx, done_tx, job::run);

    let mut app = App::new(env, library_root, project_root);
    for job in app.launch() {
        let _ = job_tx.send(job);
    }

    let terminal = crate::ui::init()?;
    let result = event_loop(terminal, &mut app, &job_tx, &done_rx);
    crate::ui::restore()?;

    drop(job_tx);
    let _ = handle.join();
    result
}

fn event_loop(
    mut terminal: crate::ui::Tui,
    app: &mut App,
    jobs: &mpsc::Sender<job::Job>,
    done: &mpsc::Receiver<Outcome<Done>>,
) -> io::Result<()> {
    loop {
        terminal.draw(|frame| crate::render::draw(frame, app))?;

        // Drain everything the worker finished, dispatching any follow-up work.
        loop {
            match done.try_recv() {
                Ok(Outcome::Done(msg)) => {
                    for job in app.apply(msg) {
                        let _ = jobs.send(job);
                    }
                }
                // A panicking job is an event, not a death (Task 1). The
                // terminal is still ours because the hook is thread-aware.
                Ok(Outcome::Panicked(what)) => {
                    for job in app.apply(Done::Failed(format!("internal panic: {what}"))) {
                        let _ = jobs.send(job);
                    }
                }
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => break,
            }
        }

        if event::poll(TICK)? {
            if let Event::Key(pressed) = event::read()? {
                if pressed.kind != KeyEventKind::Press {
                    continue;
                }
                let Some(key) = translate(pressed.code) else {
                    continue;
                };
                for job in app.on_key(key) {
                    let _ = jobs.send(job);
                }
                if app.should_quit {
                    return Ok(());
                }
            }
        }
    }
}

/// Key bindings live here, key *meanings* live in [`App`] — so a rebinding is a
/// change to this function and nothing else.
fn translate(code: KeyCode) -> Option<Key> {
    Some(match code {
        KeyCode::Up | KeyCode::Char('k') => Key::Up,
        KeyCode::Down | KeyCode::Char('j') => Key::Down,
        KeyCode::Tab => Key::NextAgent,
        KeyCode::Char('s') => Key::ToggleScope,
        KeyCode::Char('r') => Key::Refresh,
        KeyCode::Enter => Key::Confirm,
        KeyCode::Char('d') => Key::Remove,
        KeyCode::Char('?') => Key::Help,
        KeyCode::Char('q') => Key::Quit,
        KeyCode::Esc => Key::Back,
        _ => return None,
    })
}
