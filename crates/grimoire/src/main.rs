//! `grimoire` — the TUI.
//!
//! Thin by design: parse the trivia flags, resolve the one [`AppEnv`], resolve
//! the library, hand off to the loop. Everything testable lives in the library
//! half of this crate.

use std::path::PathBuf;
use std::process::ExitCode;

use skill_grimoire::args::{self, Parsed};
use skill_grimoire::env::AppEnv;

fn main() -> ExitCode {
    let args = match args::parse(std::env::args().skip(1)) {
        Parsed::Run(args) => args,
        Parsed::Print(msg) => {
            println!("{msg}");
            return ExitCode::SUCCESS;
        }
        Parsed::Error(msg) => {
            eprintln!("error: {msg}");
            return ExitCode::from(2);
        }
    };

    let env = AppEnv::from_process();
    let library_root = match resolve_library(&env, args.library) {
        Ok(root) => root,
        Err(msg) => {
            eprintln!("error: {msg}");
            return ExitCode::from(2);
        }
    };

    match skill_grimoire::run::run(env, library_root, args.project) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::FAILURE
        }
    }
}

/// `--library`, else the configured default, else the working directory.
///
/// The working-directory fallback is what makes the dogfood loop work from
/// inside a clone with no setup at all — the same thing `install.sh` does by
/// living in the tree it installs from.
fn resolve_library(env: &AppEnv, flag: Option<PathBuf>) -> Result<PathBuf, String> {
    if let Some(path) = flag {
        return if path.is_dir() {
            Ok(path)
        } else {
            Err(format!("--library {} is not a directory", path.display()))
        };
    }
    let configured = grimoire_core::config::load(env.config_home())
        .map_err(|e| e.to_string())?
        .library;
    match configured {
        Some(path) if path.is_dir() => Ok(path),
        Some(path) => Err(format!(
            "the configured library {} is not a directory (edit {})",
            path.display(),
            grimoire_core::config::config_path(env.config_home()).display()
        )),
        None => std::env::current_dir().map_err(|e| format!("no library and no cwd: {e}")),
    }
}
