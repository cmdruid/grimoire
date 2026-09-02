use clap::Parser;
use skill_grimoire::args::Cli;

const SOURCE_KEY: &str = "1111111111111111111111111111111111111111111111111111111111111111";

fn parses(args: &[&str]) -> bool {
    Cli::try_parse_from(std::iter::once("grimoire").chain(args.iter().copied())).is_ok()
}

#[test]
fn canonical_command_productions_parse() {
    for args in [
        vec![],
        vec!["init"],
        vec!["init", "--global"],
        vec!["init", "--project", "."],
        vec!["source", "add", "repo", "github:org/repo"],
        vec!["source", "list", "--global"],
        vec!["source", "remove", "repo", "--yes"],
        vec!["source", "fetch"],
        vec!["source", "fetch", "repo"],
        vec!["source", "info", "repo", "--json"],
        vec!["source", "diff", "repo"],
        vec!["source", "trust", "repo"],
        vec!["source", "trust", "repo", "--all"],
        vec!["source", "trust", "repo", "--revoke", "--yes"],
        vec!["trust", "list"],
        vec!["trust", "revoke", SOURCE_KEY, "--yes"],
        vec!["install"],
        vec!["install", "--frozen", "--global"],
        vec!["install", "one", "--source", "repo"],
        vec!["install", "bundle", "--pack", "--source", "repo"],
        vec!["uninstall", "one"],
        vec!["remove", "bundle", "--pack", "--yes"],
        vec!["update"],
        vec!["update", "repo", "--dry-run"],
        vec!["list", "--project", "."],
        vec!["check", "--global"],
        vec!["store", "prune", "--project", ".", "--dry-run"],
    ] {
        assert!(parses(&args), "canonical production rejected: {args:?}");
    }
}

#[test]
fn conflicting_missing_and_forbidden_productions_are_rejected() {
    for args in [
        vec!["init", "--global", "--project", "."],
        vec!["source"],
        vec!["source", "add", "repo"],
        vec!["source", "add", "repo", ".", "--trust", "--trust-all"],
        vec!["source", "trust", "repo", "--all", "--revoke"],
        vec!["source", "trust", "repo", "--yes"],
        vec!["trust", "revoke"],
        vec!["install", "--pack"],
        vec!["install", "one", "--source", "repo", "--frozen"],
        vec!["uninstall"],
        vec!["update", "repo", "extra"],
        vec!["update", "--frozen"],
        vec!["check", "--global", "--project", "."],
        vec!["store", "prune", "--global"],
        vec![concat!("--lib", "rary"), "old"],
        vec!["install", "one", concat!("--fo", "rce")],
    ] {
        assert!(!parses(&args), "forbidden production accepted: {args:?}");
    }
}
