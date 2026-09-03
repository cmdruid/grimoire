use std::fs;
use std::panic::catch_unwind;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
struct Violation {
    path: PathBuf,
    rule: &'static str,
}

#[derive(Clone, Copy)]
struct Rule {
    name: &'static str,
    needle: &'static str,
}

const PRODUCT_RULES: &[Rule] = &[
    Rule {
        name: "alpha lock parser",
        needle: "grimoire/lock@0",
    },
    Rule {
        name: "face behavior",
        needle: "FaceDefinition",
    },
    Rule {
        name: "former target model",
        needle: "AgentTarget",
    },
    Rule {
        name: "former configuration model",
        needle: "LibraryConfig",
    },
    Rule {
        name: "migration reader",
        needle: "read_alpha_lock",
    },
    Rule {
        name: "force or adopt behavior",
        needle: "adopt_foreign_link",
    },
    Rule {
        name: "former CLI grammar",
        needle: "--face",
    },
];

const CORE_RULES: &[Rule] = &[Rule {
    name: "ambient core access",
    needle: "std::env::",
}];

const ADAPTER_RULES: &[Rule] = &[
    Rule {
        name: "adapter-owned file mutation",
        needle: "fs::write(",
    },
    Rule {
        name: "adapter-owned link mutation",
        needle: "fs::symlink(",
    },
];

#[test]
fn production_contains_only_the_v1_model() {
    let workspace = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let app = rust_sources(&workspace.join("crates/grimoire/src"));
    let core = rust_sources(&workspace.join("crates/grimoire-core/src"));
    let pack = rust_sources(&workspace.join("crates/grimoire-pack/src"));

    let mut violations = scan(app.iter().chain(&core).chain(&pack), PRODUCT_RULES);
    violations.extend(scan(&core, CORE_RULES));
    violations.extend(scan(&app, ADAPTER_RULES));
    assert!(violations.is_empty(), "{violations:#?}");
}

#[test]
fn every_hard_cut_rule_has_an_executed_breaking_fixture() {
    for rule in PRODUCT_RULES.iter().chain(CORE_RULES).chain(ADAPTER_RULES) {
        let fixture = PathBuf::from(format!("controlled/{}.rs", rule.name.replace(' ', "-")));
        let source = format!("fn forbidden() {{ /* {} */ }}", rule.needle);
        let violations = scan([&(fixture.clone(), source)], std::slice::from_ref(rule));
        assert_eq!(
            violations,
            vec![Violation {
                path: fixture,
                rule: rule.name,
            }],
            "breaking fixture did not trip {}",
            rule.name
        );
        assert!(
            catch_unwind(|| assert_clean(&violations)).is_err(),
            "breaking fixture did not fail the unchanged {} assertion",
            rule.name
        );
    }
}

fn assert_clean(violations: &[Violation]) {
    assert!(violations.is_empty(), "{violations:#?}");
}

fn rust_sources(root: &Path) -> Vec<(PathBuf, String)> {
    fn visit(directory: &Path, files: &mut Vec<(PathBuf, String)>) {
        let mut entries = fs::read_dir(directory)
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        entries.sort_by_key(fs::DirEntry::file_name);
        for entry in entries {
            let path = entry.path();
            if path.is_dir() {
                visit(&path, files);
            } else if path.extension().is_some_and(|extension| extension == "rs") {
                files.push((path.clone(), fs::read_to_string(path).unwrap()));
            }
        }
    }

    let mut files = Vec::new();
    visit(root, &mut files);
    files
}

fn scan<'a>(
    sources: impl IntoIterator<Item = &'a (PathBuf, String)>,
    rules: &[Rule],
) -> Vec<Violation> {
    let mut violations = Vec::new();
    for (path, source) in sources {
        for rule in rules {
            if source.contains(rule.needle) {
                violations.push(Violation {
                    path: path.clone(),
                    rule: rule.name,
                });
            }
        }
    }
    violations
}
