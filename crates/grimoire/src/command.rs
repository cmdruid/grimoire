use std::ffi::OsString;
use std::io::{self, IsTerminal, Write};

use clap::{error::ErrorKind, Parser};
use grimoire_core::{
    apply, load_world, plan, prepare_source_add, source_info, Approval, CoreError, ManifestSource,
    PlanningMode, Request, SourceAlias, SourceTrustIntent,
};

use crate::args::{Cli, Command, SourceCommand};
use crate::env::{resolve_init_paths, resolve_scope_paths, Environment, SystemPathProbe};
use crate::runtime::{SystemGitRunner, SystemRuntime};

pub trait Console {
    fn is_terminal(&self) -> bool;
    fn write_stdout(&mut self, bytes: &[u8]) -> io::Result<()>;
    fn write_stderr(&mut self, bytes: &[u8]) -> io::Result<()>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemConsole;

impl Console for SystemConsole {
    fn is_terminal(&self) -> bool {
        io::stdin().is_terminal()
    }

    fn write_stdout(&mut self, bytes: &[u8]) -> io::Result<()> {
        io::stdout().write_all(bytes)
    }

    fn write_stderr(&mut self, bytes: &[u8]) -> io::Result<()> {
        io::stderr().write_all(bytes)
    }
}

pub fn run_from<I, T>(args: I, environment: &dyn Environment, console: &mut dyn Console) -> u8
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    let cli = match Cli::try_parse_from(args) {
        Ok(cli) => cli,
        Err(error) => {
            let exit = if matches!(
                error.kind(),
                ErrorKind::DisplayHelp | ErrorKind::DisplayVersion
            ) {
                0
            } else {
                2
            };
            let rendered = error.to_string();
            let result = if exit == 0 {
                console.write_stdout(rendered.as_bytes())
            } else {
                console.write_stderr(rendered.as_bytes())
            };
            return if result.is_ok() { exit } else { 5 };
        }
    };
    match execute(cli, environment, console) {
        Ok(code) => code,
        Err(error) => {
            let code = exit_for_error(&error);
            if console
                .write_stderr(format!("error: {error}\n").as_bytes())
                .is_err()
            {
                5
            } else {
                code
            }
        }
    }
}

fn execute(
    cli: Cli,
    environment: &dyn Environment,
    console: &mut dyn Console,
) -> grimoire_core::Result<u8> {
    let Some(command) = cli.command else {
        return Err(CoreError::Request(
            "the tree interface is not available until Phase 6".into(),
        ));
    };
    match command {
        Command::Init { scope } => {
            let paths = resolve_init_paths(environment, &scope, &SystemPathProbe)?;
            let runner = SystemGitRunner::default();
            let runtime = SystemRuntime;
            let world = load_world(&paths, &runner, &runtime)?;
            let plan = plan(&world, Request::Initialize, PlanningMode::Normal)?;
            let mut bytes = Vec::new();
            crate::render::plan(&plan, &mut bytes).map_err(output_error)?;
            console.write_stdout(&bytes).map_err(output_error)?;
            let outcome = apply(&paths, &plan, Approval::NotRequired, &runtime)?;
            let mut bytes = Vec::new();
            crate::render::apply_outcome(&outcome, &mut bytes).map_err(output_error)?;
            console.write_stdout(&bytes).map_err(output_error)?;
            Ok(0)
        }
        Command::Source { command } => execute_source(command, environment, console),
    }
}

fn execute_source(
    command: SourceCommand,
    environment: &dyn Environment,
    console: &mut dyn Console,
) -> grimoire_core::Result<u8> {
    let scope = match &command {
        SourceCommand::Add { scope, .. } | SourceCommand::Info { scope, .. } => scope,
    };
    let paths = resolve_scope_paths(environment, scope, &SystemPathProbe)?;
    let runner = SystemGitRunner::default();
    let runtime = SystemRuntime;
    let world = load_world(&paths, &runner, &runtime)?;
    match command {
        SourceCommand::Add {
            alias,
            location,
            reference,
            live,
            trust,
            trust_all,
            ..
        } => {
            let alias = SourceAlias::new(alias)?;
            let source = ManifestSource::from_cli(location, reference, live)?;
            let prepared = prepare_source_add(paths.clone(), &world, alias, source, &runner)?;
            let trust = if trust_all {
                SourceTrustIntent::All
            } else if trust {
                SourceTrustIntent::Exact
            } else {
                SourceTrustIntent::Untrusted
            };
            apply_request(
                &paths,
                &world,
                Request::AddSource {
                    prepared: Box::new(prepared),
                    trust,
                },
                PlanningMode::Normal,
                console,
                &runtime,
            )
        }
        SourceCommand::Info { alias, json, .. } => {
            let alias = SourceAlias::new(alias)?;
            let info = source_info(&paths, &world, &alias)?;
            let mut bytes = Vec::new();
            if json {
                bytes = info.to_bytes()?;
            } else {
                crate::render::source_info(&info, &mut bytes).map_err(output_error)?;
            }
            console.write_stdout(&bytes).map_err(output_error)?;
            Ok(u8::from(!info.inventory.findings.is_empty()))
        }
    }
}

fn apply_request(
    paths: &grimoire_core::Paths,
    world: &grimoire_core::WorldState,
    request: Request,
    mode: PlanningMode,
    console: &mut dyn Console,
    runtime: &SystemRuntime,
) -> grimoire_core::Result<u8> {
    let plan = plan(world, request, mode)?;
    let mut bytes = Vec::new();
    crate::render::plan(&plan, &mut bytes).map_err(output_error)?;
    console.write_stdout(&bytes).map_err(output_error)?;
    if !plan.blockers.is_empty() {
        return Ok(3);
    }
    let outcome = apply(paths, &plan, Approval::NotRequired, runtime)?;
    let mut bytes = Vec::new();
    crate::render::apply_outcome(&outcome, &mut bytes).map_err(output_error)?;
    console.write_stdout(&bytes).map_err(output_error)?;
    Ok(0)
}

fn output_error(error: io::Error) -> CoreError {
    CoreError::Io {
        path: "<standard-stream>".into(),
        message: error.to_string(),
    }
}

fn exit_for_error(error: &CoreError) -> u8 {
    match error {
        CoreError::InvalidSlug { .. }
        | CoreError::ManifestUtf8(_)
        | CoreError::ManifestToml(_)
        | CoreError::Manifest(_)
        | CoreError::LockJson(_)
        | CoreError::LockSchemaUnsupported { .. }
        | CoreError::Lock(_)
        | CoreError::Snapshot(_)
        | CoreError::Request(_)
        | CoreError::Source(_)
        | CoreError::Trust(_) => 2,
        CoreError::StalePlan(_) | CoreError::BlockedPlan | CoreError::ApprovalRequired => 3,
        CoreError::Transport(_) => 4,
        CoreError::Store(_)
        | CoreError::Locking(_)
        | CoreError::Transaction(_)
        | CoreError::RecoveryRequired(_)
        | CoreError::Io { .. } => 5,
    }
}
