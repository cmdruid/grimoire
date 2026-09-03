use std::ffi::OsString;
use std::io::{self, IsTerminal, Write};

use clap::{error::ErrorKind, Parser};
use grimoire_core::source::GitRunner;
use grimoire_core::{
    apply, attach_inherited_global, check, context_report, load_trust_world, load_world,
    observe_reachability, plan, prepare_source_add, refresh_source, source_diff, source_info,
    source_key_for_alias, source_summaries, trust_catalog, Approval, CoreError, DesiredEdit,
    DesiredState, ManifestSource, PackName, PlanningMode, ProjectionMode, Request, ScopePaths,
    SkillName, SourceAlias, SourceKey, SourceTrustIntent, WorldState,
};

use crate::args::{Cli, Command, SourceCommand, StoreCommand, TrustCommand};
use crate::env::{
    resolve_global_paths, resolve_init_paths, resolve_scope_paths, Environment, SystemPathProbe,
};
use crate::runtime::SystemRuntime;

/// The exact core request and mode produced by a desired-state CLI command.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanningInput {
    pub request: Request,
    pub mode: PlanningMode,
}

/// Normalizes parsed install, reconcile, or uninstall intent against one immutable world.
pub fn desired_command_input(
    world: &WorldState,
    command: &Command,
) -> grimoire_core::Result<PlanningInput> {
    let (edit, mode) = match command {
        Command::Install {
            name: None,
            pack: false,
            source: None,
            frozen,
            ..
        } => {
            return Ok(PlanningInput {
                request: Request::Reconcile,
                mode: if *frozen {
                    PlanningMode::Frozen
                } else {
                    PlanningMode::Normal
                },
            });
        }
        Command::Install {
            name: Some(name),
            pack: false,
            source: Some(source),
            frozen,
            ..
        } => (
            DesiredEdit::SetSkill {
                name: SkillName::new(name.clone())?,
                source: SourceAlias::new(source.clone())?,
                enabled: true,
            },
            if *frozen {
                PlanningMode::Frozen
            } else {
                PlanningMode::Normal
            },
        ),
        Command::Install {
            name: Some(name),
            pack: true,
            source: Some(source),
            frozen,
            ..
        } => (
            DesiredEdit::SetPack {
                name: PackName::new(name.clone())?,
                source: SourceAlias::new(source.clone())?,
                enabled: true,
            },
            if *frozen {
                PlanningMode::Frozen
            } else {
                PlanningMode::Normal
            },
        ),
        Command::Uninstall {
            name, pack: false, ..
        } => {
            let name = SkillName::new(name.clone())?;
            let source = world
                .manifest
                .skills
                .get(&name)
                .map(|request| request.source.clone())
                .ok_or_else(|| CoreError::Manifest(format!("skill `{name}` is not requested")))?;
            (
                DesiredEdit::SetSkill {
                    name,
                    source,
                    enabled: false,
                },
                PlanningMode::Normal,
            )
        }
        Command::Uninstall {
            name, pack: true, ..
        } => {
            let name = PackName::new(name.clone())?;
            let source = world
                .manifest
                .packs
                .get(&name)
                .map(|request| request.source.clone())
                .ok_or_else(|| CoreError::Manifest(format!("pack `{name}` is not requested")))?;
            (
                DesiredEdit::SetPack {
                    name,
                    source,
                    enabled: false,
                },
                PlanningMode::Normal,
            )
        }
        Command::Install { .. } => {
            return Err(CoreError::Request(
                "operand installs require `--source <alias>`".into(),
            ));
        }
        _ => {
            return Err(CoreError::Request(
                "command does not express desired-state input".into(),
            ));
        }
    };
    let mut desired = DesiredState::from_world(world);
    desired.apply(edit)?;
    if let Command::Install {
        name: Some(name),
        pack,
        link,
        vendor,
        ..
    } = command
    {
        let requested_mode = match (*link, *vendor) {
            (false, false) => None,
            (true, false) => Some(ProjectionMode::Link),
            (false, true) => Some(ProjectionMode::Vendor),
            (true, true) => {
                return Err(CoreError::Request(
                    "`--link` and `--vendor` are mutually exclusive".into(),
                ))
            }
        };
        if let Some(mode) = requested_mode {
            desired.apply(if *pack {
                DesiredEdit::SetPackMode {
                    name: PackName::new(name.clone())?,
                    mode,
                }
            } else {
                DesiredEdit::SetSkillMode {
                    name: SkillName::new(name.clone())?,
                    mode,
                }
            })?;
        }
    }
    Ok(PlanningInput {
        request: desired.into_request(),
        mode,
    })
}

pub trait Console {
    fn is_terminal(&self) -> bool;
    fn read_line(&mut self, line: &mut String) -> io::Result<usize>;
    fn write_stdout(&mut self, bytes: &[u8]) -> io::Result<()>;
    fn write_stderr(&mut self, bytes: &[u8]) -> io::Result<()>;

    fn run_tui(&mut self, _environment: &dyn Environment) -> grimoire_core::Result<u8> {
        Err(CoreError::Request(
            "this console has no interactive TUI driver".into(),
        ))
    }
}

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemConsole;

impl Console for SystemConsole {
    fn is_terminal(&self) -> bool {
        io::stdin().is_terminal() && io::stdout().is_terminal()
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

    fn run_tui(&mut self, environment: &dyn Environment) -> grimoire_core::Result<u8> {
        crate::tui::run_system(environment)?;
        Ok(0)
    }
}

pub fn run_from<I, T>(
    args: I,
    environment: &dyn Environment,
    console: &mut dyn Console,
    git: &dyn GitRunner,
) -> u8
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
    match execute(cli, environment, console, git) {
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
    git: &dyn GitRunner,
) -> grimoire_core::Result<u8> {
    let Some(command) = cli.command else {
        if !console.is_terminal() {
            return Err(CoreError::Request(
                "bare grimoire requires interactive stdin and stdout".into(),
            ));
        }
        return console.run_tui(environment);
    };
    if matches!(
        &command,
        Command::Install { .. } | Command::Uninstall { .. }
    ) {
        return execute_desired_command(&command, environment, console, git);
    }
    match command {
        Command::Init { scope } => {
            let paths = resolve_init_paths(environment, &scope, &SystemPathProbe)?;
            let runtime = SystemRuntime;
            let world = load_world(&paths, git, &runtime)?;
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
        Command::Source { command } => execute_source(command, environment, console, git),
        Command::Trust { command } => execute_trust(command, environment, console),
        Command::Install { .. } | Command::Uninstall { .. } => {
            unreachable!("desired commands return before dispatch")
        }
        Command::Update {
            source,
            dry_run,
            yes,
            scope,
        } => execute_scoped_request(
            environment,
            console,
            &scope,
            match source {
                Some(alias) => Request::UpdateSource {
                    alias: SourceAlias::new(alias)?,
                },
                None => Request::UpdateAll,
            },
            PlanningMode::Normal,
            ApplyOptions { dry_run, yes },
            git,
        ),
        Command::List { scope } => {
            let world = load_context_world(environment, &scope, git)?;
            let report = context_report(&world);
            let mut bytes = Vec::new();
            crate::render::context_report(&report, &mut bytes).map_err(output_error)?;
            console.write_stdout(&bytes).map_err(output_error)?;
            Ok(u8::from(
                !report.blockers.is_empty() || !report.findings.is_empty(),
            ))
        }
        Command::Check { scope } => {
            let world = load_context_world(environment, &scope, git)?;
            let report = check(&world);
            let mut bytes = Vec::new();
            crate::render::check_report(&report, &mut bytes).map_err(output_error)?;
            console.write_stdout(&bytes).map_err(output_error)?;
            Ok(u8::from(!report.findings.is_empty()))
        }
        Command::Store { command } => match command {
            StoreCommand::Prune {
                project,
                dry_run,
                yes,
            } => {
                let paths = resolve_global_paths(environment)?;
                let runtime = SystemRuntime;
                let observation = observe_reachability(&paths, &project, &runtime)?;
                let mut bytes = Vec::new();
                crate::render::observations(&observation.findings, &mut bytes)
                    .map_err(output_error)?;
                console.write_stdout(&bytes).map_err(output_error)?;
                let world =
                    load_world(&paths, git, &runtime)?.with_reachability(observation.clone());
                let code = apply_request(
                    &paths,
                    &world,
                    Request::Prune,
                    PlanningMode::Normal,
                    console,
                    &runtime,
                    ApplyOptions { dry_run, yes },
                )?;
                Ok(code.max(u8::from(!observation.findings.is_empty())))
            }
        },
    }
}

fn load_context_world(
    environment: &dyn Environment,
    scope: &crate::args::ScopeArgs,
    git: &dyn GitRunner,
) -> grimoire_core::Result<grimoire_core::WorldState> {
    let paths = resolve_scope_paths(environment, scope, &SystemPathProbe)?;
    let runtime = SystemRuntime;
    let world = load_world(&paths, git, &runtime)?;
    if matches!(paths.scope, ScopePaths::Global { .. }) {
        return Ok(world);
    }
    let global_paths = resolve_global_paths(environment)?;
    let global = load_world(&global_paths, git, &runtime)?;
    attach_inherited_global(world, &global)
}

fn execute_desired_command(
    command: &Command,
    environment: &dyn Environment,
    console: &mut dyn Console,
    git: &dyn GitRunner,
) -> grimoire_core::Result<u8> {
    let (scope, options) = match command {
        Command::Install {
            scope,
            dry_run,
            yes,
            ..
        }
        | Command::Uninstall {
            scope,
            dry_run,
            yes,
            ..
        } => (
            scope,
            ApplyOptions {
                dry_run: *dry_run,
                yes: *yes,
            },
        ),
        _ => unreachable!("desired command dispatch"),
    };
    let paths = resolve_scope_paths(environment, scope, &SystemPathProbe)?;
    let runtime = SystemRuntime;
    let world = load_world(&paths, git, &runtime)?;
    let input = desired_command_input(&world, command)?;
    apply_request(
        &paths,
        &world,
        input.request,
        input.mode,
        console,
        &runtime,
        options,
    )
}

fn execute_scoped_request(
    environment: &dyn Environment,
    console: &mut dyn Console,
    scope: &crate::args::ScopeArgs,
    request: Request,
    mode: PlanningMode,
    options: ApplyOptions,
    git: &dyn GitRunner,
) -> grimoire_core::Result<u8> {
    let paths = resolve_scope_paths(environment, scope, &SystemPathProbe)?;
    let runtime = SystemRuntime;
    let world = load_world(&paths, git, &runtime)?;
    apply_request(&paths, &world, request, mode, console, &runtime, options)
}

fn execute_source(
    command: SourceCommand,
    environment: &dyn Environment,
    console: &mut dyn Console,
    git: &dyn GitRunner,
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
    let runtime = SystemRuntime;
    let world = load_world(&paths, git, &runtime)?;
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
            let prepared = prepare_source_add(paths.clone(), &world, alias, source, git)?;
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
                let info = refresh_source(paths.clone(), alias, git)?;
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
            vendor,
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
                        mode: if vendor {
                            SourceTrustIntent::Vendor
                        } else if all {
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
