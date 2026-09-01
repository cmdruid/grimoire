//! Phase 3, Task 1 — the event-loop spike. The visual half of the proof.
//!
//! The claims it demonstrates are unit-proven in `tests/worker.rs` and
//! `tests/panic_hook.rs`; what a test cannot show is whether the UI *feels*
//! responsive while a blocking core operation runs. That is what this is for:
//! run it, press `s`, and watch the spinner keep turning.
//!
//! Run:   cargo run -p skill-grimoire --example spike [library-root]
//! Keys:  l enumerate the library (real core work)   s slow job (3s)
//!        w panic the worker (must stay usable)      p panic the UI (must restore)
//!        q quit

use std::io;
use std::path::PathBuf;
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::thread;
use std::time::{Duration, Instant};

use ratatui::crossterm::event::{self, Event as TermEvent, KeyCode, KeyEventKind};
use ratatui::layout::{Constraint, Layout};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph};
use ratatui::Frame;

use grimoire_core::library::Library;
use skill_grimoire::ui;
use skill_grimoire::worker::{self, Outcome};

enum Job {
    Enumerate(PathBuf),
    Slow,
    Panic,
}

enum Done {
    Enumerated {
        packs: usize,
        loose: usize,
        issues: usize,
        took: Duration,
    },
    Slept(Duration),
    Failed(String),
}

fn run_job(job: Job) -> Done {
    let started = Instant::now();
    match job {
        Job::Enumerate(root) => match Library::open(root).enumerate() {
            Ok(view) => Done::Enumerated {
                packs: view.packs.len(),
                loose: view.loose.len(),
                issues: view.issues.len(),
                took: started.elapsed(),
            },
            Err(e) => Done::Failed(e.to_string()),
        },
        Job::Slow => {
            thread::sleep(Duration::from_secs(3));
            Done::Slept(started.elapsed())
        }
        Job::Panic => panic!("deliberate worker panic (spike)"),
    }
}

struct App {
    frames: u64,
    started: Instant,
    busy: Option<&'static str>,
    log: Vec<String>,
}

impl App {
    fn note(&mut self, s: impl Into<String>) {
        self.log.push(format!(
            "[{:>6.2}s] {}",
            self.started.elapsed().as_secs_f32(),
            s.into()
        ));
        if self.log.len() > 10 {
            self.log.remove(0);
        }
    }
}

fn main() -> io::Result<()> {
    let library_root = std::env::args()
        .nth(1)
        .map_or_else(|| std::env::current_dir().unwrap(), PathBuf::from);

    let (job_tx, job_rx) = mpsc::channel::<Job>();
    let (done_tx, done_rx) = mpsc::channel::<Outcome<Done>>();
    let handle = worker::spawn(job_rx, done_tx, run_job);

    let terminal = ui::init()?;
    let result = event_loop(terminal, &library_root, &job_tx, &done_rx);
    ui::restore()?;

    // Clean shutdown: close the job channel, then actually join. A detached
    // worker is how an exit that looks clean still leaves a thread mid-write.
    drop(job_tx);
    let joined = handle.join().is_ok();

    result?;
    println!("worker joined cleanly: {joined}");
    Ok(())
}

fn event_loop(
    mut terminal: ui::Tui,
    library_root: &std::path::Path,
    jobs: &Sender<Job>,
    done: &Receiver<Outcome<Done>>,
) -> io::Result<()> {
    let mut app = App {
        frames: 0,
        started: Instant::now(),
        busy: None,
        log: Vec::new(),
    };
    app.note(format!("library root: {}", library_root.display()));

    loop {
        terminal.draw(|f| draw(f, &app))?;
        app.frames += 1;

        // Drain the worker without blocking. This, plus the poll timeout below,
        // is the entire concurrency story — no async runtime involved.
        loop {
            match done.try_recv() {
                Ok(Outcome::Done(msg)) => {
                    app.busy = None;
                    match msg {
                        Done::Enumerated {
                            packs,
                            loose,
                            issues,
                            took,
                        } => app.note(format!(
                            "enumerate: {packs} packs, {loose} loose, {issues} issues in {}ms",
                            took.as_millis()
                        )),
                        Done::Slept(d) => app.note(format!("slow job finished after {d:?}")),
                        Done::Failed(e) => app.note(format!("job failed: {e}")),
                    }
                }
                Ok(Outcome::Panicked(p)) => {
                    app.busy = None;
                    app.note(format!("worker PANICKED and survived: {p}"));
                    app.note("...and this terminal is still ours — press l, it still works");
                }
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => {
                    app.busy = None;
                    app.note("worker is gone");
                    break;
                }
            }
        }

        // 50ms keeps the spinner visibly turning and caps input latency well
        // below perception.
        if event::poll(Duration::from_millis(50))? {
            if let TermEvent::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue;
                }
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                    KeyCode::Char('l') => {
                        app.busy = Some("enumerating");
                        app.note("dispatched: enumerate");
                        let _ = jobs.send(Job::Enumerate(library_root.to_path_buf()));
                    }
                    KeyCode::Char('s') => {
                        app.busy = Some("slow job");
                        app.note("dispatched: slow job (3s)");
                        let _ = jobs.send(Job::Slow);
                    }
                    KeyCode::Char('w') => {
                        app.busy = Some("panicking worker");
                        app.note("dispatched: worker panic");
                        let _ = jobs.send(Job::Panic);
                    }
                    KeyCode::Char('p') => panic!("deliberate main-thread panic (spike)"),
                    _ => {}
                }
            }
        }
    }
}

fn draw(frame: &mut Frame, app: &App) {
    const SPINNER: [char; 4] = ['|', '/', '-', '\\'];
    let areas = Layout::vertical([
        Constraint::Length(3),
        Constraint::Length(3),
        Constraint::Min(5),
    ])
    .split(frame.area());

    let spin = SPINNER[(app.frames as usize) % SPINNER.len()];
    let status = match app.busy {
        Some(what) => Line::from(vec![
            Span::styled(
                format!(" {spin} {what} "),
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw("— still animating while the worker blocks. That is the claim."),
        ]),
        None => Line::from(vec![
            Span::styled(format!(" {spin} idle "), Style::default().fg(Color::Green)),
            Span::raw(format!("— frame {}", app.frames)),
        ]),
    };
    frame.render_widget(
        Paragraph::new(status).block(Block::default().borders(Borders::ALL).title(" status ")),
        areas[0],
    );

    frame.render_widget(
        Paragraph::new(Line::from(
            "l enumerate   s slow job   w panic the worker   p panic the UI   q quit",
        ))
        .block(Block::default().borders(Borders::ALL).title(" keys ")),
        areas[1],
    );

    let log: Vec<Line> = app.log.iter().map(|l| Line::from(l.as_str())).collect();
    frame.render_widget(
        Paragraph::new(log).block(Block::default().borders(Borders::ALL).title(" events ")),
        areas[2],
    );
}
