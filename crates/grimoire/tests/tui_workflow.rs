mod support;

use std::fs;
use std::path::Path;
use std::process::Command;

use grimoire_core::{
    apply, attach_inherited_global, load_world, refresh_source, Approval, InstalledStatus,
    LockSource, PackName, PackSelection, Paths, Scope, SkillName, SourceAlias, TreeItemKey,
    TreeItemKind, WorldState,
};
use skill_grimoire::runtime::{SystemGitRunner, SystemRuntime};
use skill_grimoire::tui::{Dialog, Effect, TuiModel};
use tempfile::tempdir;

#[test]
fn project_and_global_tree_workflow_stays_staged_explicit_and_offline() {
    let temporary = tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let home = root.join("home");
    let project = root.join("project");
    let source = root.join("source");
    create_source(&source);
    fs::create_dir_all(&home).unwrap();
    fs::create_dir_all(&project).unwrap();

    success(&support::run(&project, &home, &["init"]));
    success(&support::run(&project, &home, &["init", "--global"]));
    for scope in [Vec::new(), vec!["--global"]] {
        let mut args = vec![
            "source",
            "add",
            "fixture",
            source.to_str().unwrap(),
            "--trust-all",
        ];
        args.extend(scope);
        success(&support::run(&project, &home, &args));
    }
    success(&support::run(
        &project,
        &home,
        &["install", "one", "--source", "fixture", "--global"],
    ));

    let project_paths = Paths::project(project.clone(), home.join(".grimoire")).unwrap();
    let global_paths = Paths::global(home.clone(), home.join(".grimoire")).unwrap();
    let (project_world, global_world) = load_scopes(&project_paths, &global_paths);
    let inherited = TreeItemKey::InheritedSkill {
        name: SkillName::new("one").unwrap(),
    };
    let pack = TreeItemKey::Pack {
        source: SourceAlias::new("fixture").unwrap(),
        name: PackName::new("bundle").unwrap(),
    };
    let optional = TreeItemKey::PackMember {
        source: SourceAlias::new("fixture").unwrap(),
        pack: PackName::new("bundle").unwrap(),
        name: SkillName::new("two").unwrap(),
    };
    let loose = TreeItemKey::Skill {
        source: SourceAlias::new("fixture").unwrap(),
        name: SkillName::new("one").unwrap(),
    };

    let mut model = TuiModel::from_scopes(Some(project_world), global_world).unwrap();
    assert!(model
        .tree()
        .item(&inherited)
        .is_some_and(|item| !item.toggleable));

    model.toggle(&pack).unwrap();
    assert!(matches!(
        model.tree().item(&pack).map(|item| &item.kind),
        Some(TreeItemKind::Pack(PackSelection::Full))
    ));
    model.toggle(&optional).unwrap();
    assert!(matches!(
        model.tree().item(&pack).map(|item| &item.kind),
        Some(TreeItemKind::Pack(PackSelection::Partial))
    ));

    // A Global reload updates inherited facts without throwing away Project staging.
    model.switch_scope();
    let reloaded_global = execute(
        model.request_fetch(SourceAlias::new("fixture").unwrap()),
        &project_paths,
        &global_paths,
    );
    model.accept_reloaded_scope(reloaded_global).unwrap();
    model.switch_scope();
    assert!(model.is_staged());
    model.cancel().unwrap();
    assert!(!model.is_staged());

    model.toggle(&loose).unwrap();
    let install = model.request_apply().expect("trusted install is additive");
    let reloaded_project = execute(install, &project_paths, &global_paths);
    model.accept_reloaded_scope(reloaded_project).unwrap();
    assert!(model
        .tree()
        .item(&inherited)
        .is_some_and(|item| item.shadowed));

    let locked_before = locked_commit(&project_paths, "fixture");
    commit_skill(&source, "second");

    // Update consumes only the cached candidate. It does not discover the new commit.
    let cached = model
        .request_update(SourceAlias::new("fixture").unwrap())
        .unwrap()
        .expect("unchanged cached candidate needs no confirmation");
    let reloaded_project = execute(cached, &project_paths, &global_paths);
    model.accept_reloaded_scope(reloaded_project).unwrap();
    assert_eq!(locked_commit(&project_paths, "fixture"), locked_before);

    let fetched = execute(
        model.request_fetch(SourceAlias::new("fixture").unwrap()),
        &project_paths,
        &global_paths,
    );
    model.accept_reloaded_scope(fetched).unwrap();
    assert!(model
        .request_trust_all(SourceAlias::new("fixture").unwrap())
        .unwrap()
        .is_none());
    assert!(matches!(
        model.dialog(),
        Some(Dialog::ConfirmTrustAll { .. })
    ));
    assert!(model.confirm(false).is_none());

    assert!(model
        .request_update(SourceAlias::new("fixture").unwrap())
        .unwrap()
        .is_none());
    assert!(matches!(model.dialog(), Some(Dialog::ConfirmDestructive)));
    let update = model.confirm(true).expect("confirmed cached update");
    let reloaded_project = execute(update, &project_paths, &global_paths);
    model.accept_reloaded_scope(reloaded_project).unwrap();
    assert_ne!(locked_commit(&project_paths, "fixture"), locked_before);

    let installed = project.join(".agents/skills/one");
    if installed
        .symlink_metadata()
        .unwrap()
        .file_type()
        .is_symlink()
    {
        fs::remove_file(&installed).unwrap();
    } else {
        fs::remove_dir_all(&installed).unwrap();
    }
    fs::write(&installed, "foreign\n").unwrap();
    let (project_world, _) = load_scopes(&project_paths, &global_paths);
    model.accept_reloaded_scope(project_world).unwrap();
    assert_eq!(
        model.tree().item(&loose).and_then(|item| item.installed),
        Some(InstalledStatus::ForeignFile)
    );

    // World loading is cache/store-only: the declared repository may be offline.
    fs::rename(&source, root.join("source-offline")).unwrap();
    fs::create_dir(&source).unwrap();
    let (offline, _) = load_scopes(&project_paths, &global_paths);
    model.accept_reloaded_scope(offline).unwrap();
    assert!(model.tree().item(&loose).is_some());
}

fn execute(effect: Effect, project: &Paths, global: &Paths) -> WorldState {
    let runtime = SystemRuntime;
    let runner = SystemGitRunner::default();
    let scope = match &effect {
        Effect::Apply { scope, .. }
        | Effect::Fetch { scope, .. }
        | Effect::Update { scope, .. }
        | Effect::TrustAll { scope, .. } => *scope,
        Effect::Quit => panic!("quit is not a worker job"),
    };
    let paths = match scope {
        Scope::Project => project,
        Scope::Global => global,
    };
    match effect {
        Effect::Apply { plan, approval, .. } | Effect::Update { plan, approval, .. } => {
            apply(paths, &plan, approval, &runtime).unwrap();
        }
        Effect::TrustAll { plan, .. } => {
            apply(paths, &plan, Approval::NotRequired, &runtime).unwrap();
        }
        Effect::Fetch { alias, .. } => {
            refresh_source(paths.clone(), alias, &runner).unwrap();
        }
        Effect::Quit => unreachable!(),
    }
    match scope {
        Scope::Global => load_world(global, &runner, &runtime).unwrap(),
        Scope::Project => {
            let project = load_world(project, &runner, &runtime).unwrap();
            let global = load_world(global, &runner, &runtime).unwrap();
            attach_inherited_global(project, &global).unwrap()
        }
    }
}

fn load_scopes(project: &Paths, global: &Paths) -> (WorldState, WorldState) {
    let runner = SystemGitRunner::default();
    let runtime = SystemRuntime;
    let global = load_world(global, &runner, &runtime).unwrap();
    let project = load_world(project, &runner, &runtime).unwrap();
    (attach_inherited_global(project, &global).unwrap(), global)
}

fn locked_commit(paths: &Paths, alias: &str) -> String {
    let alias = SourceAlias::new(alias).unwrap();
    let lock = grimoire_core::Lockfile::parse(&fs::read(paths.lock_path()).unwrap()).unwrap();
    match lock.sources.get(&alias).unwrap() {
        LockSource::Git { commit, .. } => commit.clone(),
        LockSource::Link { .. } => panic!("workflow source must be pinned"),
    }
}

fn create_source(source: &Path) {
    for skill in ["one", "two"] {
        fs::create_dir_all(source.join("skills").join(skill)).unwrap();
        fs::write(
            source.join("skills").join(skill).join("SKILL.md"),
            format!("---\nname: {skill}\ndescription: workflow fixture\n---\nfirst\n"),
        )
        .unwrap();
    }
    fs::write(
        source.join("PACK.md"),
        b"---\nschema: grimoire/pack@1\nname: bundle\ndescription: Workflow fixture.\nrequired:\n  - one\noptional:\n  - two\n---\n",
    )
    .unwrap();
    git(source, &["init", "-q"]);
    git(source, &["add", "."]);
    commit(source, "initial");
}

fn commit_skill(source: &Path, body: &str) {
    fs::write(
        source.join("skills/one/SKILL.md"),
        format!("---\nname: one\ndescription: workflow fixture\n---\n{body}\n"),
    )
    .unwrap();
    git(source, &["add", "."]);
    commit(source, body);
}

fn commit(source: &Path, message: &str) {
    git(
        source,
        &[
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            message,
        ],
    );
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
    assert!(
        output.status.success(),
        "{}\n{}",
        support::stderr(output),
        support::stdout(output)
    );
}
