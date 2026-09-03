mod support;

use std::fs;
use std::path::Path;
use std::process::Command;

use clap::Parser;
use grimoire_core::{load_world, plan, Paths, SkillName, SourceAlias, TreeItemKey, WorldState};
use skill_grimoire::args::Cli;
use skill_grimoire::command::desired_command_input;
use skill_grimoire::runtime::{SystemGitRunner, SystemRuntime};
use skill_grimoire::tui::TuiModel;
use tempfile::tempdir;

#[test]
fn direct_core_cli_and_tui_emit_identical_blocked_additive_and_destructive_plans() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: parity fixture\n---\n",
    )
    .unwrap();
    git(&source, &["init", "-q"]);
    git(&source, &["add", "."]);
    git(
        &source,
        &[
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            "initial",
        ],
    );

    success(&support::run(&project, &home, &["init"]));
    success(&support::run(
        &project,
        &home,
        &["source", "add", "fixture", source.to_str().unwrap()],
    ));

    let paths = Paths::project(project.clone(), home.join(".grimoire")).unwrap();
    let key = TreeItemKey::Skill {
        source: SourceAlias::new("fixture").unwrap(),
        name: SkillName::new("one").unwrap(),
    };

    let blocked = assert_parity(
        load(&paths),
        &project,
        &home,
        &key,
        &["install", "one", "--source", "fixture", "--dry-run"],
    );
    assert!(!blocked.blockers.is_empty());
    assert!(!blocked.is_destructive());

    success(&support::run(
        &project,
        &home,
        &["source", "trust", "fixture"],
    ));
    let additive = assert_parity(
        load(&paths),
        &project,
        &home,
        &key,
        &["install", "one", "--source", "fixture", "--dry-run"],
    );
    assert!(additive.blockers.is_empty());
    assert!(!additive.is_destructive());

    success(&support::run(
        &project,
        &home,
        &["install", "one", "--source", "fixture"],
    ));
    let uninstall = assert_parity(
        load(&paths),
        &project,
        &home,
        &key,
        &["uninstall", "one", "--dry-run"],
    );
    assert!(uninstall.blockers.is_empty());
    assert!(uninstall.is_destructive());
}

fn assert_parity(
    world: WorldState,
    project: &Path,
    home: &Path,
    key: &TreeItemKey,
    cli: &[&str],
) -> grimoire_core::Plan {
    let parsed = Cli::try_parse_from(std::iter::once("grimoire").chain(cli.iter().copied()))
        .unwrap()
        .command
        .unwrap();
    let input = desired_command_input(&world, &parsed).unwrap();

    let direct = plan(&world, input.request.clone(), input.mode).unwrap();
    let mut tui = TuiModel::new(world).unwrap();
    tui.toggle(key).unwrap();
    assert_eq!(tui.staged_request(), input.request);
    assert_eq!(tui.plan(), &direct);
    assert_eq!(tui.plan().is_destructive(), direct.is_destructive());

    let bytes = direct.to_bytes().unwrap();

    let output = support::run(project, home, cli);
    assert_eq!(
        output.status.code(),
        Some(if direct.blockers.is_empty() { 0 } else { 3 })
    );
    let stdout = support::stdout(&output);
    let cli: serde_json::Value = serde_json::from_str(&stdout).unwrap();
    let core: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    for field in ["actions", "blockers", "exit_class"] {
        assert_eq!(cli[field], core[field], "CLI/core mismatch in {field}");
    }
    direct
}

fn load(paths: &Paths) -> WorldState {
    load_world(paths, &SystemGitRunner::default(), &SystemRuntime).unwrap()
}

fn git(directory: &Path, args: &[&str]) {
    assert!(Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap()
        .success());
}

fn success(output: &std::process::Output) {
    assert!(output.status.success(), "{}", support::stderr(output));
}
