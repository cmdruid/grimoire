//! The flag surface — deliberately tiny.
//!
//! v0.1 is TUI-only (brainstorm, binding): `grimoire` launches straight into the
//! TUI and there are no verbs. These three flags are trivia, not a CLI, and they
//! are hand-parsed for the same reason `config` has no `toml` dependency — three
//! flags do not justify a parser, and the moment a fourth kind arrives, adopt
//! `clap` then.

use std::path::PathBuf;

pub const USAGE: &str = "\
grimoire — browse a skills library and install packs

usage: grimoire [--library <path>] [--project <dir>] [--version] [--help]

  --library <path>   the skills library to browse (default: the configured one)
  --project <dir>    open this project for project-scope installs
  --version          print the version and exit
  --help             print this message and exit
";

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Args {
    pub library: Option<PathBuf>,
    pub project: Option<PathBuf>,
}

/// What the binary should do about the command line before starting the TUI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Parsed {
    Run(Args),
    /// Print this and exit 0.
    Print(String),
    /// Print this to stderr and exit 2.
    Error(String),
}

pub fn parse<I, S>(argv: I) -> Parsed
where
    I: IntoIterator<Item = S>,
    S: Into<String>,
{
    let mut args = Args::default();
    let mut it = argv.into_iter().map(Into::into);

    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--version" | "-V" => {
                return Parsed::Print(format!("grimoire {}", env!("CARGO_PKG_VERSION")))
            }
            "--help" | "-h" => return Parsed::Print(USAGE.to_string()),
            "--library" => match it.next() {
                Some(v) => args.library = Some(PathBuf::from(v)),
                None => return Parsed::Error("--library needs a path".into()),
            },
            "--project" => match it.next() {
                Some(v) => args.project = Some(PathBuf::from(v)),
                None => return Parsed::Error("--project needs a directory".into()),
            },
            other => {
                return Parsed::Error(format!(
                    "unknown argument: {other}\n\n{USAGE}\n\
                     (v0.1 is TUI-only — there are no verbs)"
                ))
            }
        }
    }
    Parsed::Run(args)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_arguments_runs_with_nothing_set() {
        assert_eq!(parse(Vec::<String>::new()), Parsed::Run(Args::default()));
    }

    #[test]
    fn library_and_project_take_values() {
        let parsed = parse(["--library", "/lib", "--project", "/proj"]);
        assert_eq!(
            parsed,
            Parsed::Run(Args {
                library: Some(PathBuf::from("/lib")),
                project: Some(PathBuf::from("/proj")),
            })
        );
    }

    #[test]
    fn a_flag_missing_its_value_is_an_error_not_a_panic() {
        assert!(matches!(parse(["--library"]), Parsed::Error(_)));
        assert!(matches!(parse(["--project"]), Parsed::Error(_)));
    }

    /// v0.1 has no verbs, so a bare word is a mistake worth naming — silently
    /// ignoring it would look like the flag worked.
    #[test]
    fn an_unknown_argument_is_refused() {
        match parse(["install"]) {
            Parsed::Error(msg) => assert!(msg.contains("TUI-only"), "{msg}"),
            other => panic!("expected an error, got {other:?}"),
        }
    }

    #[test]
    fn version_and_help_short_circuit() {
        assert!(matches!(parse(["--version"]), Parsed::Print(s) if s.starts_with("grimoire ")));
        assert!(matches!(parse(["--help"]), Parsed::Print(s) if s.contains("usage:")));
        // ...even with other arguments after them
        assert!(matches!(parse(["--version", "--library"]), Parsed::Print(_)));
    }
}
