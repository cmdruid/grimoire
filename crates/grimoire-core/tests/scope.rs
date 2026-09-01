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
