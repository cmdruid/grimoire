use std::ffi::OsString;
use std::io::{self, IsTerminal, Write};

use clap::{error::ErrorKind, Parser};
use grimoire_core::{apply, load_world, plan, Approval, CoreError, PlanningMode, Request};

use crate::args::{Cli, Command};
use crate::env::{resolve_init_paths, Environment, SystemPathProbe};
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
    }
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
        CoreError::Store(_)
        | CoreError::Locking(_)
        | CoreError::Transaction(_)
        | CoreError::RecoveryRequired(_)
        | CoreError::Io { .. } => 5,
    }
}
