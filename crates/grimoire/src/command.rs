use std::ffi::OsString;
use std::io::{self, IsTerminal, Write};

use clap::{error::ErrorKind, Parser};
use grimoire_core::{
    apply, load_trust_world, load_world, plan, prepare_source_add, refresh_source, source_diff,
    source_info, source_key_for_alias, source_summaries, trust_catalog, Approval, CoreError,
    ManifestSource, PlanningMode, Request, SourceAlias, SourceKey, SourceTrustIntent,
};

use crate::args::{Cli, Command, SourceCommand, TrustCommand};
use crate::env::{
    resolve_global_paths, resolve_init_paths, resolve_scope_paths, Environment, SystemPathProbe,
};
use crate::runtime::{SystemGitRunner, SystemRuntime};

pub trait Console {
    fn is_terminal(&self) -> bool;
    fn read_line(&mut self, line: &mut String) -> io::Result<usize>;
    fn write_stdout(&mut self, bytes: &[u8]) -> io::Result<()>;
    fn write_stderr(&mut self, bytes: &[u8]) -> io::Result<()>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemConsole;

impl Console for SystemConsole {
    fn is_terminal(&self) -> bool {
        io::stdin().is_terminal()
    }

    fn read_line(&mut self, line: &mut String) -> io::Result<usize> {
        io::stdin().read_line(line)
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
        Command::Trust { command } => execute_trust(command, environment, console),
    }
}

fn execute_source(
    command: SourceCommand,
    environment: &dyn Environment,
    console: &mut dyn Console,
) -> grimoire_core::Result<u8> {
    let scope = match &command {
        SourceCommand::Add { scope, .. }
        | SourceCommand::Info { scope, .. }
        | SourceCommand::List { scope }
        | SourceCommand::Remove { scope, .. }
        | SourceCommand::Fetch { scope, .. }
        | SourceCommand::Diff { scope, .. }
        | SourceCommand::Trust { scope, .. } => scope,
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
                ApplyOptions::default(),
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
        SourceCommand::List { .. } => {
            let sources = source_summaries(&world)?;
            let mut bytes = Vec::new();
            crate::render::source_list(&sources, &mut bytes).map_err(output_error)?;
            console.write_stdout(&bytes).map_err(output_error)?;
            Ok(u8::from(sources.iter().any(|source| source.has_findings)))
        }
        SourceCommand::Fetch { alias, .. } => {
            let aliases = match alias {
                Some(alias) => vec![SourceAlias::new(alias)?],
                None => world.manifest.sources.keys().cloned().collect(),
            };
            let mut findings = false;
            for alias in aliases {
                let info = refresh_source(paths.clone(), alias, &runner)?;
                let mut bytes = Vec::new();
                crate::render::source_info(&info, &mut bytes).map_err(output_error)?;
                console.write_stdout(&bytes).map_err(output_error)?;
                findings |= !info.inventory.findings.is_empty();
            }
            Ok(u8::from(findings))
        }
        SourceCommand::Diff { alias, .. } => {
            let alias = SourceAlias::new(alias)?;
            let diff = source_diff(&paths, &world, &alias)?;
            let mut bytes = Vec::new();
            crate::render::source_diff(&diff, &mut bytes).map_err(output_error)?;
            console.write_stdout(&bytes).map_err(output_error)?;
            Ok(0)
        }
        SourceCommand::Remove { alias, yes, .. } => apply_request(
            &paths,
            &world,
            Request::RemoveSource {
                alias: SourceAlias::new(alias)?,
            },
            PlanningMode::Normal,
            console,
            &runtime,
            ApplyOptions {
                yes,
                ..ApplyOptions::default()
            },
        ),
        SourceCommand::Trust {
            alias,
            all,
            revoke,
            yes,
            ..
        } => {
            let alias = SourceAlias::new(alias)?;
            if revoke {
                let global_paths = resolve_global_paths(environment)?;
                let catalog = trust_catalog(&global_paths)?;
                let mut bytes = Vec::new();
                crate::render::trust_catalog(&catalog, &mut bytes).map_err(output_error)?;
                console.write_stdout(&bytes).map_err(output_error)?;
                apply_request(
                    &paths,
                    &world,
                    Request::RevokeTrust {
                        source: source_key_for_alias(&world, &alias)?,
                    },
                    PlanningMode::Normal,
                    console,
                    &runtime,
                    ApplyOptions {
                        yes,
                        ..ApplyOptions::default()
                    },
                )
            } else {
                apply_request(
                    &paths,
                    &world,
                    Request::TrustSource {
                        alias,
                        mode: if all {
                            SourceTrustIntent::All
                        } else {
                            SourceTrustIntent::Exact
                        },
                    },
                    PlanningMode::Normal,
                    console,
                    &runtime,
                    ApplyOptions::default(),
                )
            }
        }
    }
}

fn execute_trust(
    command: TrustCommand,
    environment: &dyn Environment,
    console: &mut dyn Console,
) -> grimoire_core::Result<u8> {
    let paths = resolve_global_paths(environment)?;
    let catalog = trust_catalog(&paths)?;
    let mut bytes = Vec::new();
    crate::render::trust_catalog(&catalog, &mut bytes).map_err(output_error)?;
    console.write_stdout(&bytes).map_err(output_error)?;
    match command {
        TrustCommand::List => Ok(u8::from(!catalog.findings.is_empty())),
        TrustCommand::Revoke { source_key, yes } => {
            let world = load_trust_world(&paths)?;
            apply_request(
                &paths,
                &world,
                Request::RevokeTrust {
                    source: SourceKey::parse(source_key)?,
                },
                PlanningMode::Normal,
                console,
                &SystemRuntime,
                ApplyOptions {
                    yes,
                    ..ApplyOptions::default()
                },
            )
        }
    }
}

#[derive(Debug, Clone, Copy, Default)]
struct ApplyOptions {
    dry_run: bool,
    yes: bool,
}

fn apply_request(
    paths: &grimoire_core::Paths,
    world: &grimoire_core::WorldState,
    request: Request,
    mode: PlanningMode,
    console: &mut dyn Console,
    runtime: &SystemRuntime,
    options: ApplyOptions,
) -> grimoire_core::Result<u8> {
    let plan = plan(world, request, mode)?;
    let mut bytes = Vec::new();
    crate::render::plan(&plan, &mut bytes).map_err(output_error)?;
    console.write_stdout(&bytes).map_err(output_error)?;
    if !plan.blockers.is_empty() {
        return Ok(3);
    }
    if options.dry_run {
        return Ok(0);
    }
    let approval = if !plan.is_destructive() {
        Approval::NotRequired
    } else if options.yes {
        Approval::Granted
    } else if !console.is_terminal() {
        return Err(CoreError::ApprovalRequired);
    } else {
        console
            .write_stdout(b"Apply? [y/N] ")
            .map_err(output_error)?;
        let mut answer = String::new();
        console.read_line(&mut answer).map_err(output_error)?;
        if matches!(answer.trim().to_ascii_lowercase().as_str(), "y" | "yes") {
            Approval::Granted
        } else {
            Approval::Declined
        }
    };
    let outcome = apply(paths, &plan, approval, runtime)?;
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
