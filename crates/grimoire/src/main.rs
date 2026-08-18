//! `grimoire` — the TUI.
//!
//! Thin by design: parse the trivia flags, resolve the one [`AppEnv`], hand off.
//! Everything testable lives in the library half of this crate.

use std::process::ExitCode;

use skill_grimoire::args::{self, Parsed};
use skill_grimoire::env::AppEnv;

fn main() -> ExitCode {
    let parsed = args::parse(std::env::args().skip(1));
    let args = match parsed {
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
    println!(
        "grimoire {} — screens land in Phase 3 Tasks 4-7.\n\
         home:        {}\n\
         config:      {}\n\
         agents:      {}\n\
         library:     {}\n\
         project:     {}\n\n\
         The event loop is runnable today: cargo run -p skill-grimoire --example spike",
        env!("CARGO_PKG_VERSION"),
        env.home().display(),
        env.config_home().display(),
        env.agents()
            .iter()
            .map(|a| format!(
                "{}{}",
                a.id,
                if a.detected() { " (detected)" } else { "" }
            ))
            .collect::<Vec<_>>()
            .join(", "),
        args.library
            .as_ref()
            .map_or_else(|| "(unset)".to_string(), |p| p.display().to_string()),
        args.project
            .as_ref()
            .map_or_else(|| "(unset)".to_string(), |p| p.display().to_string()),
    );
    ExitCode::SUCCESS
}
