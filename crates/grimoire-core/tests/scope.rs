use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

use grimoire_core::{discover_project, resolve_explicit_project, PathProbe, Paths, ScopePaths};

#[derive(Default)]
struct Probe {
    dirs: BTreeSet<PathBuf>,
    files: BTreeSet<PathBuf>,
}

impl PathProbe for Probe {
    fn is_dir(&self, path: &Path) -> bool {
        self.dirs.contains(path)
    }

    fn is_file(&self, path: &Path) -> bool {
        self.files.contains(path)
    }
}

#[test]
fn discovery_selects_the_nearest_nested_project_and_stops_at_root() {
    let probe = Probe {
        dirs: ["/repo", "/repo/sub", "/repo/sub/deep"]
            .into_iter()
            .map(PathBuf::from)
            .collect(),
        files: ["/repo/grimoire.toml", "/repo/sub/grimoire.toml"]
            .into_iter()
            .map(PathBuf::from)
            .collect(),
    };

    assert_eq!(
        discover_project(Path::new("/repo/sub/deep"), &probe).unwrap(),
        Some(PathBuf::from("/repo/sub"))
    );
    assert_eq!(
        discover_project(Path::new("/elsewhere"), &probe).unwrap(),
        None
    );
}

#[test]
fn explicit_and_global_paths_are_resolved_without_ambient_environment() {
    let probe = Probe {
        dirs: ["/repo"].into_iter().map(PathBuf::from).collect(),
        files: BTreeSet::new(),
    };
    let project = resolve_explicit_project(Path::new("/repo"), &probe).unwrap();
    assert_eq!(
        project,
        ScopePaths::Project {
            root: "/repo".into()
        }
    );
    assert!(resolve_explicit_project(Path::new("/missing"), &probe).is_err());

    let paths = Paths::global("/users/example".into(), "/custom/grimoire".into()).unwrap();
    assert_eq!(
        paths.manifest_path(),
        PathBuf::from("/custom/grimoire/grimoire.toml")
    );
    assert_eq!(
        paths.lock_path(),
        PathBuf::from("/custom/grimoire/grimoire.lock")
    );
    assert_eq!(
        paths.skills_dir(),
        PathBuf::from("/users/example/.agents/skills")
    );
}

#[test]
fn scope_keys_are_stable_and_global_is_literal() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project_root = root.join("project");
    let other_root = root.join("other");
    std::fs::create_dir_all(&project_root).unwrap();
    std::fs::create_dir_all(&other_root).unwrap();
    let project = Paths::project(project_root.clone(), root.join("home-a")).unwrap();
    let same = Paths::project(project_root, root.join("home-b")).unwrap();
    let other = Paths::project(other_root, root.join("home-a")).unwrap();
    let global = Paths::global(PathBuf::from("/home/u"), PathBuf::from("/home/g")).unwrap();
    assert_eq!(project.scope_key(), same.scope_key());
    assert_ne!(project.scope_key(), other.scope_key());
    assert_eq!(project.scope_key().len(), 64);
    assert_eq!(global.scope_key(), "global");
}

#[cfg(unix)]
#[test]
fn project_paths_capture_one_canonical_root() {
    use std::os::unix::fs::symlink;

    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let original = root.join("original");
    let replacement = root.join("replacement");
    let alias = root.join("project-link");
    std::fs::create_dir_all(&original).unwrap();
    std::fs::create_dir_all(&replacement).unwrap();
    symlink(&original, &alias).unwrap();

    let paths = Paths::project(alias.clone(), root.join("home")).unwrap();
    std::fs::remove_file(&alias).unwrap();
    symlink(&replacement, &alias).unwrap();

    assert_eq!(paths.manifest_path(), original.join("grimoire.toml"));
    assert_eq!(
        paths.scope_key(),
        Paths::project(original, root.join("other-home"))
            .unwrap()
            .scope_key()
    );
}
