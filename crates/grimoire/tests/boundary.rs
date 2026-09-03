use std::fs;
use std::panic::catch_unwind;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
struct Violation {
    path: PathBuf,
    rule: &'static str,
}

fn rust_sources(root: &Path) -> Vec<(PathBuf, String)> {
    fn visit(directory: &Path, sources: &mut Vec<(PathBuf, String)>) {
        let mut entries = fs::read_dir(directory)
            .unwrap_or_else(|error| panic!("cannot read {}: {error}", directory.display()))
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        entries.sort_by_key(std::fs::DirEntry::file_name);
        for entry in entries {
            let path = entry.path();
            if path.is_dir() {
                visit(&path, sources);
            } else if path.extension().is_some_and(|extension| extension == "rs") {
                let source = fs::read_to_string(&path)
                    .unwrap_or_else(|error| panic!("cannot read {}: {error}", path.display()));
                sources.push((path, source));
            }
        }
    }

    let mut sources = Vec::new();
    visit(root, &mut sources);
    sources
}

fn scan<'a>(
    sources: impl IntoIterator<Item = (&'a Path, &'a str)>,
    rules: &[(&'static str, &'static str)],
) -> Vec<Violation> {
    let mut violations = Vec::new();
    for (path, source) in sources {
        for &(rule, needle) in rules {
            if source.contains(needle) {
                violations.push(Violation {
                    path: path.to_path_buf(),
                    rule,
                });
            }
        }
    }
    violations
}

fn section<'a>(source: &'a str, start: &str, end: &str) -> &'a str {
    let (_, tail) = source
        .split_once(start)
        .unwrap_or_else(|| panic!("missing section start: {start}"));
    let (body, _) = tail
        .split_once(end)
        .unwrap_or_else(|| panic!("missing section end: {end}"));
    body
}

#[test]
fn adapter_and_core_ownership_boundaries_are_explicit() {
    let app_root = Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    let core_root = app_root.join("../../grimoire-core/src");
    let app = rust_sources(&app_root);
    let core = rust_sources(&core_root);

    let core_violations = scan(
        core.iter()
            .map(|(path, source)| (path.as_path(), source.as_str())),
        &[
            ("core reads process environment", "std::env::"),
            ("core imports process environment", "use std::env"),
            ("core reads process arguments", "args_os()"),
            ("core owns terminal detection", "IsTerminal"),
            ("core imports the CLI parser", "clap::"),
        ],
    );
    assert!(core_violations.is_empty(), "{core_violations:#?}");

    let app_violations = scan(
        app.iter()
            .map(|(path, source)| (path.as_path(), source.as_str())),
        &[
            ("adapter writes managed bytes", "fs::write("),
            ("adapter creates managed files", "File::create("),
            (
                "adapter opens managed files for mutation",
                "OpenOptions::new(",
            ),
            ("adapter removes managed files", "remove_file("),
            ("adapter removes managed directories", "remove_dir("),
            ("adapter creates managed links", "fs::symlink("),
            ("adapter serializes stable JSON", "serde_json::"),
            (
                "adapter infers errors from text",
                "error.to_string().contains(",
            ),
            (
                "adapter infers plan safety from text",
                "contains(\"destructive\")",
            ),
            ("adapter infers trust from text", "contains(\"trusted\")"),
        ],
    );
    assert!(app_violations.is_empty(), "{app_violations:#?}");

    let command = fs::read_to_string(app_root.join("command.rs")).unwrap();
    let update = section(&command, "Command::Update {", "Command::List {");
    assert!(
        !update.contains("refresh_source("),
        "update refreshed a source"
    );
    assert!(update.contains("Request::UpdateAll"));
    assert!(command.contains("info.to_bytes()?"));
    assert!(command.contains("plan.is_destructive()"));
    assert!(command.contains("match error {"));

    let all_app = app
        .iter()
        .map(|(_, source)| source.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    for former_name in [
        ["Library", "Config"].concat(),
        ["Agent", "Target"].concat(),
        ["Live", "Library"].concat(),
        ["Install", "Log"].concat(),
        ["Immediate", "Install"].concat(),
        ["Immediate", "Remove"].concat(),
    ] {
        assert!(
            !all_app.contains(&former_name),
            "legacy parser name: {former_name}"
        );
    }
}

#[test]
fn controlled_forbidden_import_arm_is_live() {
    let fixture = Path::new("controlled.rs");
    let source = "use std::env;\nfn read() { let _ = std::env::current_dir(); }\n";
    let violations = scan(
        [(fixture, source)],
        &[
            ("core reads process environment", "std::env::"),
            ("core imports process environment", "use std::env"),
        ],
    );
    assert_eq!(
        violations,
        vec![
            Violation {
                path: fixture.to_path_buf(),
                rule: "core reads process environment",
            },
            Violation {
                path: fixture.to_path_buf(),
                rule: "core imports process environment",
            },
        ]
    );
    assert!(catch_unwind(|| assert_no_violations(&violations)).is_err());
}

#[test]
fn tui_keeps_mutation_source_work_inheritance_and_trust_boundaries_separate() {
    let app_root = Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    let driver = fs::read_to_string(app_root.join("tui/driver.rs")).unwrap();
    let model = fs::read_to_string(app_root.join("tui/model.rs")).unwrap();

    let event_loop = section(&driver, "fn system_event_loop(", "#[derive(Default)]");
    assert!(!event_loop.contains("refresh_source("));

    let update = section(
        &driver,
        "Effect::Update { plan, approval, .. } => {",
        "Effect::TrustAll",
    );
    assert!(update.contains("apply("));
    assert!(!update.contains("refresh_source("));

    let trust = section(
        &driver,
        "Effect::TrustAll { plan, .. } => {",
        "Effect::Quit",
    );
    assert!(trust.contains("Approval::NotRequired"));
    assert!(!trust.contains("Approval::Granted"));

    let inherited = section(
        &model,
        "TreeItemKey::Source(_) | TreeItemKey::InheritedSkill { .. } => {",
        "        };",
    );
    assert!(inherited.contains("tree item is not toggleable"));
    assert!(!inherited.contains("DesiredEdit::"));
}

#[test]
fn controlled_tui_absence_arms_are_live() {
    for (rule, source, needle) in [
        (
            "background source work",
            "fn system_event_loop() { refresh_source(); }",
            "refresh_source(",
        ),
        (
            "update-time fetch",
            "Effect::Update => { refresh_source(); }",
            "refresh_source(",
        ),
        (
            "generic trust approval",
            "Effect::TrustAll => apply(Approval::Granted)",
            "Approval::Granted",
        ),
        (
            "inherited desired edit",
            "TreeItemKey::InheritedSkill => DesiredEdit::SetSkill",
            "DesiredEdit::",
        ),
        (
            "adapter-owned mutation",
            "fn mutate() { fs::write(path, bytes); }",
            "fs::write(",
        ),
    ] {
        let violations = scan([(Path::new("controlled.rs"), source)], &[(rule, needle)]);
        assert_eq!(
            violations,
            vec![Violation {
                path: PathBuf::from("controlled.rs"),
                rule,
            }]
        );
        assert!(
            catch_unwind(|| assert_no_violations(&violations)).is_err(),
            "controlled arm did not fail the unchanged {rule} assertion"
        );
    }
}

fn assert_no_violations(violations: &[Violation]) {
    assert!(violations.is_empty(), "{violations:#?}");
}
