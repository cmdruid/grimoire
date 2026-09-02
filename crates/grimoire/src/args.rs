use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};

#[derive(Debug, Clone, PartialEq, Eq, Parser)]
#[command(
    name = "grimoire",
    version,
    about = "Manage project and global agent skills"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Command>,
}

#[derive(Debug, Clone, PartialEq, Eq, Subcommand)]
pub enum Command {
    /// Initialize a project or global Grimoire scope.
    Init {
        #[command(flatten)]
        scope: InitScope,
    },
    /// Manage declared sources and review candidates.
    Source {
        #[command(subcommand)]
        command: SourceCommand,
    },
}

impl Command {
    pub fn init_scope(&self) -> Option<&InitScope> {
        match self {
            Self::Init { scope } => Some(scope),
            Self::Source { .. } => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Subcommand)]
pub enum SourceCommand {
    /// Register and inspect a source candidate.
    Add {
        alias: String,
        location: String,
        #[arg(long = "ref", value_name = "REF")]
        reference: Option<String>,
        #[arg(long)]
        live: bool,
        #[arg(long, conflicts_with = "trust_all")]
        trust: bool,
        #[arg(long = "trust-all", conflicts_with = "trust")]
        trust_all: bool,
        #[command(flatten)]
        scope: ScopeArgs,
    },
    /// Show the current reviewed source candidate.
    Info {
        alias: String,
        #[arg(long)]
        json: bool,
        #[command(flatten)]
        scope: ScopeArgs,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Args)]
#[group(id = "init-scope", multiple = false)]
pub struct InitScope {
    /// Initialize the global scope.
    #[arg(long, group = "init-scope")]
    pub global: bool,

    /// Initialize exactly this existing project directory.
    #[arg(long, value_name = "PATH", group = "init-scope")]
    pub project: Option<PathBuf>,
}

#[derive(Debug, Clone, PartialEq, Eq, Args)]
#[group(id = "scope", multiple = false)]
pub struct ScopeArgs {
    /// Use the global scope.
    #[arg(long, group = "scope")]
    pub global: bool,

    /// Use exactly this existing project directory.
    #[arg(long, value_name = "PATH", group = "scope")]
    pub project: Option<PathBuf>,
}
