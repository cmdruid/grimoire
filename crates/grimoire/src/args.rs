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
}

impl Command {
    pub fn init_scope(&self) -> Option<&InitScope> {
        match self {
            Self::Init { scope } => Some(scope),
        }
    }
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
