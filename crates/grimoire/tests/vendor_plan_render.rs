use std::collections::BTreeMap;

use grimoire_core::{Action, ExitClass, Plan, Preconditions, Scope};

#[test]
fn vendor_plan_render_names_digests_and_sorted_paths_without_file_bytes() {
    let plan = Plan {
        actions: vec![Action::ReplaceVendor {
            scope: Scope::Project,
            source: "a".try_into().unwrap(),
            skill: "one".try_into().unwrap(),
            path: "vendor/grimoire/a/one".into(),
            before: format!("sha256:{}", "1".repeat(64)),
            after: format!("sha256:{}", "2".repeat(64)),
            added: vec!["a.txt".into(), "b.txt".into()],
            removed: vec!["old.txt".into()],
            changed: vec!["SKILL.md".into()],
        }],
        blockers: Vec::new(),
        preconditions: Preconditions {
            manifest: None,
            lock: None,
            candidates: BTreeMap::new(),
            stores: BTreeMap::new(),
            trust: None,
            projects: None,
            reachability: None,
            links: BTreeMap::new(),
            vendors: BTreeMap::new(),
        },
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    };
    let mut output = Vec::new();
    skill_grimoire::render::plan(&plan, &mut output).unwrap();
    let output = String::from_utf8(output).unwrap();
    assert!(output.contains("vendor/grimoire/a/one"));
    assert!(output.contains(&format!("sha256:{}", "1".repeat(64))));
    assert!(output.contains(&format!("sha256:{}", "2".repeat(64))));
    assert!(output.find("a.txt").unwrap() < output.find("b.txt").unwrap());
    assert!(!output.contains("SECRET_FILE_BYTES"));
}
