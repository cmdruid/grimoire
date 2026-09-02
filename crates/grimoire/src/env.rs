use std::ffi::{OsStr, OsString};
use std::path::{Path, PathBuf};

use grimoire_core::{CoreError, PathProbe, Paths, Result, ScopePaths};

use crate::args::InitScope;

pub trait Environment {
    fn current_dir(&self) -> std::io::Result<PathBuf>;
    fn var_os(&self, name: &str) -> Option<OsString>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemEnvironment;

impl Environment for SystemEnvironment {
    fn current_dir(&self) -> std::io::Result<PathBuf> {
        std::env::current_dir()
    }

    fn var_os(&self, name: &str) -> Option<OsString> {
        std::env::var_os(name)
    }
}

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemPathProbe;

impl PathProbe for SystemPathProbe {
    fn is_dir(&self, path: &Path) -> bool {
        path.is_dir()
    }

    fn is_file(&self, path: &Path) -> bool {
        path.is_file()
    }
}

pub fn resolve_init_paths(
    environment: &dyn Environment,
    scope: &InitScope,
    probe: &dyn PathProbe,
) -> Result<Paths> {
    let cwd = absolute_current_dir(environment)?;
    let user_home = user_home(environment)?;
    let grimoire_home = grimoire_home(environment, &user_home)?;
    if scope.global {
        return Paths::global(user_home, grimoire_home);
    }
    let project = match scope.project.as_deref() {
        Some(path) => absolute_from(&cwd, path),
        None => cwd,
    };
    let ScopePaths::Project { root } = grimoire_core::resolve_explicit_project(&project, probe)?
    else {
        unreachable!("explicit project resolution always returns project scope")
    };
    Paths::project(root, grimoire_home)
}

fn absolute_current_dir(environment: &dyn Environment) -> Result<PathBuf> {
    let cwd = environment.current_dir().map_err(|error| {
        CoreError::Request(format!("cannot resolve current directory: {error}"))
    })?;
    if cwd.is_absolute() {
        Ok(cwd)
    } else {
        Err(CoreError::Request(
            "resolved current directory is not absolute".into(),
        ))
    }
}

fn user_home(environment: &dyn Environment) -> Result<PathBuf> {
    let home = environment
        .var_os("HOME")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| CoreError::Request("HOME is not set".into()))?;
    if home.is_absolute() {
        Ok(home)
    } else {
        Err(CoreError::Request("HOME must be an absolute path".into()))
    }
}

fn grimoire_home(environment: &dyn Environment, user_home: &Path) -> Result<PathBuf> {
    match environment.var_os("GRIMOIRE_HOME") {
        Some(value) if !value.is_empty() => {
            let path = PathBuf::from(value);
            if path.is_absolute() {
                Ok(path)
            } else {
                Err(CoreError::Request(
                    "GRIMOIRE_HOME must be an absolute path".into(),
                ))
            }
        }
        _ => Ok(user_home.join(OsStr::new(".grimoire"))),
    }
}

fn absolute_from(cwd: &Path, path: &Path) -> PathBuf {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        cwd.join(path)
    }
}
