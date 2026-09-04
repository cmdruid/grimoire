use std::io::{self, IsTerminal};
use std::panic::{catch_unwind, resume_unwind, AssertUnwindSafe};
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::thread::JoinHandle;
use std::time::Duration;

use grimoire_core::{
    apply, attach_inherited_global, load_world, refresh_source, CoreError, Paths, Result, Scope,
    SourceAlias, WorldState,
};
use ratatui::crossterm::event::{self, Event, KeyCode, KeyEventKind};

use super::{Effect, TuiModel};
use crate::env::{resolve_tui_paths, Environment, SystemPathProbe, TuiPaths};
use crate::runtime::{SystemGitRunner, SystemRuntime};
use crate::worker::{self, Outcome};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DriverEvent {
    Tick,
    Quit,
    Resize(u16, u16),
    Next,
    Previous,
    Toggle,
    SwitchScope,
    Cancel,
    Apply,
    Confirm(bool),
    Fetch(SourceAlias),
    Update(SourceAlias),
    TrustAll(SourceAlias),
}

pub enum JobOutcome {
    Unchanged,
    ReloadScope(Box<WorldState>),
}

pub trait Driver {
    fn is_terminal(&self) -> bool;
    fn enter(&mut self) -> io::Result<()>;
    fn draw(&mut self, model: &TuiModel) -> io::Result<()>;
    fn next_event(&mut self) -> io::Result<DriverEvent>;
    fn restore(&mut self) -> io::Result<()>;
}

pub fn drive<D, F>(driver: &mut D, model: &mut TuiModel, mut run: F) -> Result<()>
where
    D: Driver,
    F: FnMut(Effect) -> Result<JobOutcome>,
{
    if !driver.is_terminal() {
        return Err(CoreError::Request(
            "bare grimoire requires an interactive terminal".into(),
        ));
    }
    driver.enter().map_err(io_error)?;

    let result = catch_unwind(AssertUnwindSafe(|| run_loop(driver, model, &mut run)));
    let restore = driver.restore().map_err(io_error);
    match result {
        Ok(loop_result) => loop_result.and(restore),
        Err(payload) => {
            let _ = restore;
            resume_unwind(payload)
        }
    }
}

fn run_loop<D, F>(driver: &mut D, model: &mut TuiModel, run: &mut F) -> Result<()>
where
    D: Driver,
    F: FnMut(Effect) -> Result<JobOutcome>,
{
    loop {
        driver.draw(model).map_err(io_error)?;
        let effect = transition(model, driver.next_event().map_err(io_error)?)?;

        let Some(effect) = effect else {
            continue;
        };
        if effect == Effect::Quit {
            return Ok(());
        }
        if let JobOutcome::ReloadScope(world) = run(effect)? {
            model.accept_reloaded_scope(*world)?;
        }
    }
}

fn transition(model: &mut TuiModel, event: DriverEvent) -> Result<Option<Effect>> {
    Ok(match event {
        DriverEvent::Tick => None,
        DriverEvent::Quit => Some(model.request_quit()?),
        DriverEvent::Resize(_, _) => None,
        DriverEvent::Next => {
            model.select_next();
            None
        }
        DriverEvent::Previous => {
            model.select_previous();
            None
        }
        DriverEvent::Toggle => {
            model.toggle_selected()?;
            None
        }
        DriverEvent::SwitchScope => {
            model.switch_scope();
            None
        }
        DriverEvent::Cancel => {
            model.cancel()?;
            None
        }
        DriverEvent::Apply => model.request_apply(),
        DriverEvent::Confirm(accepted) => model.confirm(accepted),
        DriverEvent::Fetch(alias) => Some(model.request_fetch(alias)),
        DriverEvent::Update(alias) => model.request_update(alias)?,
        DriverEvent::TrustAll(alias) => model.request_trust_all(alias)?,
    })
}

fn io_error(error: io::Error) -> CoreError {
    CoreError::Io {
        path: "<terminal>".into(),
        message: error.to_string(),
    }
}

pub fn run_system(environment: &dyn Environment) -> Result<()> {
    let paths = resolve_tui_paths(environment, &SystemPathProbe)?;
    let (jobs, outcomes, worker) = start_worker(paths);
    let result = (|| -> Result<()> {
        jobs.send(SystemJob::Load).map_err(worker_stopped)?;
        let (project, global) = match outcomes.recv().map_err(worker_stopped)? {
            Outcome::Done(Ok(SystemDone::Loaded { project, global })) => (project, global),
            Outcome::Done(Ok(SystemDone::Reloaded { .. })) => {
                unreachable!("load returned reload")
            }
            Outcome::Done(Err(error)) => return Err(error),
            Outcome::Panicked(message) => {
                return Err(CoreError::Transaction(format!(
                    "TUI worker panicked during load: {message}"
                )))
            }
        };
        let mut model = TuiModel::from_scopes(project.map(|world| *world), *global)?;
        let mut driver = SystemDriver::default();
        run_system_loop(&mut driver, &mut model, &jobs, &outcomes)
    })();
    drop(jobs);
    if worker.join().is_err() && result.is_ok() {
        return Err(CoreError::Transaction(
            "TUI worker did not shut down cleanly".into(),
        ));
    }
    result
}

#[derive(Debug)]
enum SystemJob {
    Load,
    Run(Box<Effect>),
}

enum SystemDone {
    Loaded {
        project: Option<Box<WorldState>>,
        global: Box<WorldState>,
    },
    Reloaded {
        world: Box<WorldState>,
        error: Option<String>,
    },
}

type SystemOutcome = Outcome<Result<SystemDone>>;

fn start_worker(paths: TuiPaths) -> (Sender<SystemJob>, Receiver<SystemOutcome>, JoinHandle<()>) {
    let (job_tx, job_rx) = mpsc::channel();
    let (out_tx, out_rx) = mpsc::channel();
    let worker = worker::spawn(job_rx, out_tx, move |job| run_system_job(&paths, job));
    (job_tx, out_rx, worker)
}

fn run_system_job(paths: &TuiPaths, job: SystemJob) -> Result<SystemDone> {
    let runner = SystemGitRunner::default();
    let runtime = SystemRuntime;
    match job {
        SystemJob::Load => {
            let global = load_world(&paths.global, &runner, &runtime)?;
            let project = paths
                .project
                .as_ref()
                .map(|project_paths| {
                    load_world(project_paths, &runner, &runtime)
                        .and_then(|project| attach_inherited_global(project, &global))
                })
                .transpose()?;
            Ok(SystemDone::Loaded {
                project: project.map(Box::new),
                global: Box::new(global),
            })
        }
        SystemJob::Run(effect) => {
            let scope = effect_scope(&effect).expect("quit never reaches worker");
            let scope_paths = paths_for_scope(paths, scope)?;
            let execution = (|| -> Result<()> {
                match *effect {
                    Effect::Apply { plan, approval, .. } => {
                        apply(scope_paths, &plan, approval, &runtime)?;
                    }
                    Effect::Fetch { alias, .. } => {
                        refresh_source(scope_paths.clone(), alias, &runner)?;
                    }
                    Effect::Update { plan, approval, .. } => {
                        apply(scope_paths, &plan, approval, &runtime)?;
                    }
                    Effect::TrustAll { plan, .. } => {
                        apply(
                            scope_paths,
                            &plan,
                            grimoire_core::Approval::NotRequired,
                            &runtime,
                        )?;
                    }
                    Effect::Quit => unreachable!("quit never reaches worker"),
                }
                Ok(())
            })();
            Ok(SystemDone::Reloaded {
                world: Box::new(load_scope(paths, scope, &runner, &runtime)?),
                error: execution.err().map(|error| error.to_string()),
            })
        }
    }
}

fn load_scope(
    paths: &TuiPaths,
    scope: Scope,
    runner: &SystemGitRunner,
    runtime: &SystemRuntime,
) -> Result<WorldState> {
    match scope {
        Scope::Global => load_world(&paths.global, runner, runtime),
        Scope::Project => {
            let project_paths = paths_for_scope(paths, Scope::Project)?;
            let project = load_world(project_paths, runner, runtime)?;
            let global = load_world(&paths.global, runner, runtime)?;
            attach_inherited_global(project, &global)
        }
    }
}

fn paths_for_scope(paths: &TuiPaths, scope: Scope) -> Result<&Paths> {
    match scope {
        Scope::Global => Ok(&paths.global),
        Scope::Project => paths.project.as_ref().ok_or_else(|| {
            CoreError::Request("project scope is unavailable; initialize a project first".into())
        }),
    }
}

fn effect_scope(effect: &Effect) -> Option<Scope> {
    match effect {
        Effect::Apply { scope, .. }
        | Effect::Fetch { scope, .. }
        | Effect::Update { scope, .. }
        | Effect::TrustAll { scope, .. } => Some(*scope),
        Effect::Quit => None,
    }
}

fn run_system_loop(
    driver: &mut SystemDriver,
    model: &mut TuiModel,
    jobs: &Sender<SystemJob>,
    outcomes: &Receiver<SystemOutcome>,
) -> Result<()> {
    if !driver.is_terminal() {
        return Err(CoreError::Request(
            "bare grimoire requires interactive stdin and stdout".into(),
        ));
    }
    driver.enter().map_err(io_error)?;
    let result = catch_unwind(AssertUnwindSafe(|| {
        system_event_loop(driver, model, jobs, outcomes)
    }));
    let restore = driver.restore().map_err(io_error);
    match result {
        Ok(loop_result) => loop_result.and(restore),
        Err(payload) => {
            let _ = restore;
            resume_unwind(payload)
        }
    }
}

fn system_event_loop(
    driver: &mut SystemDriver,
    model: &mut TuiModel,
    jobs: &Sender<SystemJob>,
    outcomes: &Receiver<SystemOutcome>,
) -> Result<()> {
    let mut redraw = true;
    loop {
        match outcomes.try_recv() {
            Ok(Outcome::Done(Ok(SystemDone::Reloaded { world, error }))) => {
                model.accept_reloaded_scope(*world)?;
                model.set_status(
                    error
                        .map(|error| format!("Error: {error}"))
                        .unwrap_or_else(|| "Completed".into()),
                );
                redraw = true;
            }
            Ok(Outcome::Done(Ok(SystemDone::Loaded { .. }))) => {
                unreachable!("runtime job returned initial load")
            }
            Ok(Outcome::Done(Err(error))) => {
                model.set_status(format!("Error: {error}"));
                redraw = true;
            }
            Ok(Outcome::Panicked(message)) => {
                model.set_status(format!("Worker panic: {message}"));
                redraw = true;
            }
            Err(TryRecvError::Empty) => {}
            Err(TryRecvError::Disconnected) => {
                return Err(CoreError::Transaction(
                    "TUI worker stopped unexpectedly".into(),
                ))
            }
        }

        if std::mem::take(&mut redraw) {
            driver.draw(model).map_err(io_error)?;
        }
        let event = driver.next_event().map_err(io_error)?;
        if model.is_busy() && !matches!(event, DriverEvent::Quit | DriverEvent::Resize(_, _)) {
            continue;
        }
        redraw = !matches!(event, DriverEvent::Tick);
        let effect = match transition(model, event) {
            Ok(effect) => effect,
            Err(error) => {
                model.set_status(format!("Error: {error}"));
                continue;
            }
        };
        let Some(effect) = effect else {
            continue;
        };
        if effect == Effect::Quit {
            return Ok(());
        }
        jobs.send(SystemJob::Run(Box::new(effect)))
            .map_err(worker_stopped)?;
        model.set_busy(true);
        redraw = true;
    }
}

#[derive(Default)]
struct SystemDriver {
    session: Option<crate::ui::Session>,
    selected_source: Option<SourceAlias>,
    has_dialog: bool,
}

impl Driver for SystemDriver {
    fn is_terminal(&self) -> bool {
        io::stdin().is_terminal() && io::stdout().is_terminal()
    }

    fn enter(&mut self) -> io::Result<()> {
        self.session = Some(crate::ui::init()?);
        Ok(())
    }

    fn draw(&mut self, model: &TuiModel) -> io::Result<()> {
        self.selected_source = model.selected_source();
        self.has_dialog = model.dialog().is_some();
        self.session
            .as_mut()
            .expect("terminal session entered")
            .terminal_mut()
            .draw(|frame| super::draw(frame, model))?;
        Ok(())
    }

    fn next_event(&mut self) -> io::Result<DriverEvent> {
        if !event::poll(Duration::from_millis(50))? {
            return Ok(DriverEvent::Tick);
        }
        match event::read()? {
            Event::Resize(width, height) => Ok(DriverEvent::Resize(width, height)),
            Event::Key(key) if key.kind == KeyEventKind::Press => Ok(match key.code {
                KeyCode::Char('q') => DriverEvent::Quit,
                KeyCode::Tab => DriverEvent::SwitchScope,
                KeyCode::Down | KeyCode::Char('j') => DriverEvent::Next,
                KeyCode::Up | KeyCode::Char('k') => DriverEvent::Previous,
                KeyCode::Char(' ') => DriverEvent::Toggle,
                KeyCode::Esc => {
                    if self.has_dialog {
                        DriverEvent::Confirm(false)
                    } else {
                        DriverEvent::Cancel
                    }
                }
                KeyCode::Char('n') => DriverEvent::Confirm(false),
                KeyCode::Enter => {
                    if self.has_dialog {
                        DriverEvent::Confirm(true)
                    } else {
                        DriverEvent::Apply
                    }
                }
                KeyCode::Char('y') => DriverEvent::Confirm(true),
                KeyCode::Char('a') => DriverEvent::Apply,
                KeyCode::Char('c') => DriverEvent::Cancel,
                KeyCode::Char('f') => self
                    .selected_source
                    .clone()
                    .map(DriverEvent::Fetch)
                    .unwrap_or(DriverEvent::Tick),
                KeyCode::Char('u') => self
                    .selected_source
                    .clone()
                    .map(DriverEvent::Update)
                    .unwrap_or(DriverEvent::Tick),
                KeyCode::Char('t') => self
                    .selected_source
                    .clone()
                    .map(DriverEvent::TrustAll)
                    .unwrap_or(DriverEvent::Tick),
                _ => DriverEvent::Tick,
            }),
            _ => Ok(DriverEvent::Tick),
        }
    }

    fn restore(&mut self) -> io::Result<()> {
        if let Some(session) = self.session.as_mut() {
            session.restore()?;
        }
        self.session = None;
        Ok(())
    }
}

fn worker_stopped<T: std::fmt::Display>(error: T) -> CoreError {
    CoreError::Transaction(format!("TUI worker stopped: {error}"))
}
