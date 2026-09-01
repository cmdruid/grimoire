use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::{CoreError, Result};

pub trait PathProbe {
    fn is_dir(&self, path: &Path) -> bool;
    fn is_file(&self, path: &Path) -> bool;
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ScopePaths {
    Project { root: PathBuf },
    Global { user_home: PathBuf },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Paths {
    pub grimoire_home: PathBuf,
    pub scope: ScopePaths,
}

impl Paths {
    pub fn project(root: PathBuf, grimoire_home: PathBuf) -> Result<Self> {
        require_absolute(&root, "project root")?;
        require_absolute(&grimoire_home, "Grimoire home")?;
        Ok(Self {
            grimoire_home,
            scope: ScopePaths::Project { root },
        })
    }

    pub fn global(user_home: PathBuf, grimoire_home: PathBuf) -> Result<Self> {
        require_absolute(&user_home, "user home")?;
        require_absolute(&grimoire_home, "Grimoire home")?;
        Ok(Self {
            grimoire_home,
            scope: ScopePaths::Global { user_home },
        })
    }

    pub fn manifest_path(&self) -> PathBuf {
        match &self.scope {
            ScopePaths::Project { root } => root.join("grimoire.toml"),
            ScopePaths::Global { .. } => self.grimoire_home.join("grimoire.toml"),
        }
    }

    pub fn lock_path(&self) -> PathBuf {
        match &self.scope {
            ScopePaths::Project { root } => root.join("grimoire.lock"),
            ScopePaths::Global { .. } => self.grimoire_home.join("grimoire.lock"),
        }
    }

    pub fn skills_dir(&self) -> PathBuf {
        match &self.scope {
            ScopePaths::Project { root } => root.join(".agents/skills"),
            ScopePaths::Global { user_home } => user_home.join(".agents/skills"),
        }
    }
}

pub fn discover_project(start: &Path, probe: &dyn PathProbe) -> Result<Option<PathBuf>> {
    require_absolute(start, "project discovery start")?;
    let mut current = start.to_path_buf();
    loop {
        if probe.is_file(&current.join("grimoire.toml")) {
            return Ok(Some(current));
        }
        let Some(parent) = current.parent() else {
            return Ok(None);
        };
        if parent == current {
            return Ok(None);
        }
        current = parent.to_path_buf();
    }
}

pub fn resolve_explicit_project(path: &Path, probe: &dyn PathProbe) -> Result<ScopePaths> {
    require_absolute(path, "explicit project")?;
    if !probe.is_dir(path) {
        return Err(CoreError::Request(format!(
            "explicit project `{}` is not an existing directory",
            path.display()
        )));
    }
    Ok(ScopePaths::Project {
        root: path.to_path_buf(),
    })
}

fn require_absolute(path: &Path, kind: &str) -> Result<()> {
    if path.is_absolute() {
        Ok(())
    } else {
        Err(CoreError::Request(format!(
            "{kind} must be an absolute path: {}",
            path.display()
        )))
    }
}
