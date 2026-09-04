#[path = "fixtures/tui.rs"]
mod fixture;

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use grimoire_core::{
    attach_inherited_global, PathProbe, ProjectionMode, Scope, ScopePaths, TreeItemKey,
};
use skill_grimoire::env::{resolve_tui_paths, Environment};
use skill_grimoire::tui::{ActiveScope, TuiModel};

#[test]
fn project_and_global_tabs_stage_independently_and_inherited_items_are_read_only() {
    let global = fixture::world(
        Scope::Global,
        "global",
        &["shared"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.global]\nurl = \"github:fixture/global\"\n",
            "[skills]\nshared = { source = \"global\" }\n",
        ),
    );
    let project = fixture::world(
        Scope::Project,
        "project",
        &["local", "shared"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.project]\nurl = \"github:fixture/project\"\n",
            "[skills]\nshared = { source = \"project\" }\n",
        ),
    );
    let project = attach_inherited_global(project, &global).unwrap();
    let mut model = TuiModel::from_scopes(Some(project), global).unwrap();

    assert_eq!(model.active_scope(), ActiveScope::Project);
    let inherited = TreeItemKey::InheritedSkill {
        name: "shared".try_into().unwrap(),
    };
    let inherited_item = model.active_tree().item(&inherited).unwrap();
    assert!(inherited_item.shadowed);
    assert!(!inherited_item.toggleable);

    model
        .toggle(&TreeItemKey::Skill {
            source: "project".try_into().unwrap(),
            name: "local".try_into().unwrap(),
        })
        .unwrap();
    let project_plan = model.plan_bytes().unwrap();
    model.switch_scope();
    assert_eq!(model.active_scope(), ActiveScope::Global);
    assert_ne!(model.plan_bytes().unwrap(), project_plan);
    assert!(
        model
            .active_tree()
            .item(&TreeItemKey::Skill {
                source: "global".try_into().unwrap(),
                name: "shared".try_into().unwrap(),
            })
            .unwrap()
            .selected
    );
}

#[test]
fn missing_project_falls_back_to_global_with_a_typed_remedy() {
    let global = grimoire_core::WorldState::absent(Scope::Global, [], [], None).unwrap();
    let model = TuiModel::from_scopes(None, global).unwrap();

    assert_eq!(model.active_scope(), ActiveScope::Global);
    assert_eq!(
        model.project_remedy(),
        Some(skill_grimoire::tui::ScopeRemedy::FindOrInitializeProject)
    );
}

#[test]
fn pinned_roots_are_link_mode_and_not_toggleable() {
    let project = fixture::world(
        Scope::Project,
        "project",
        &["one"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.project]\nurl = \"github:fixture/project\"\n",
            "[skills]\none = { source = \"project\" }\n",
        ),
    );
    let global = fixture::world(
        Scope::Global,
        "global",
        &["one"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.global]\nurl = \"github:fixture/global\"\n",
            "[skills]\none = { source = \"global\" }\n",
        ),
    );
    let mut model = TuiModel::from_scopes(Some(project), global).unwrap();
    model.select_next();
    assert_eq!(
        model.selected_item().unwrap().mode,
        Some(ProjectionMode::Link)
    );
    assert!(!model.selected_item().unwrap().mode_toggleable);

    model.switch_scope();
    model.select_next();
    assert_eq!(
        model.selected_item().unwrap().mode,
        Some(ProjectionMode::Link)
    );
    assert!(!model.selected_item().unwrap().mode_toggleable);
}

struct TestEnvironment {
    current_dir: PathBuf,
    home: PathBuf,
}

impl Environment for TestEnvironment {
    fn current_dir(&self) -> std::io::Result<PathBuf> {
        Ok(self.current_dir.clone())
    }

    fn var_os(&self, name: &str) -> Option<OsString> {
        (name == "HOME").then(|| self.home.clone().into_os_string())
    }
}

struct TestProbe {
    manifest: PathBuf,
}

impl PathProbe for TestProbe {
    fn is_dir(&self, _path: &Path) -> bool {
        true
    }

    fn is_file(&self, path: &Path) -> bool {
        path == self.manifest
    }
}

#[test]
fn tui_path_resolution_returns_both_independent_scopes() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let nested = project.join("nested");
    let home = root.join("home");
    std::fs::create_dir_all(&nested).unwrap();
    std::fs::create_dir(&home).unwrap();
    let environment = TestEnvironment {
        current_dir: nested,
        home: home.clone(),
    };
    let probe = TestProbe {
        manifest: project.join("grimoire.toml"),
    };

    let paths = resolve_tui_paths(&environment, &probe).unwrap();
    assert!(matches!(
        paths.project.unwrap().scope,
        ScopePaths::Project { root } if root == project
    ));
    assert!(matches!(
        paths.global.scope,
        ScopePaths::Global { user_home } if user_home == home
    ));
}

#[test]
fn navigation_stays_bounded_and_scrolls_the_selected_item_into_view() {
    let global = fixture::world(
        Scope::Global,
        "global",
        &["one", "three", "two"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.global]\nurl = \"github:fixture/global\"\n",
        ),
    );
    let mut model = TuiModel::from_scopes(None, global).unwrap();
    for _ in 0..20 {
        model.select_next();
    }
    model.keep_selection_visible(1);

    assert_eq!(model.visible_items(1).len(), 1);
    assert_eq!(model.visible_items(1)[0].label, "two");
    for _ in 0..20 {
        model.select_previous();
    }
    assert_eq!(model.selected_item().unwrap().label, "global");
}
