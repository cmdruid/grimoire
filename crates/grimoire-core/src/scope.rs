use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::{CoreError, Result};
use crate::{SnapshotKey, SourceAlias, SourceKey};

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
        let root = root.canonicalize().map_err(|error| {
            CoreError::Request(format!(
                "cannot canonicalize project root `{}`: {error}",
                root.display()
            ))
        })?;
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

    pub fn trust_path(&self) -> PathBuf {
        self.grimoire_home.join("trust.json")
    }

    pub fn git_cache_path(&self, source: &SourceKey) -> PathBuf {
        self.grimoire_home
            .join("cache/git")
            .join(format!("{source}.git"))
    }

    pub fn review_cache_dir(&self) -> PathBuf {
        self.grimoire_home.join("cache/review")
    }

    pub fn cache_tmp_dir(&self) -> PathBuf {
        self.grimoire_home.join("cache/tmp")
    }

    pub fn candidate_path(&self, scope_key: &str, alias: &SourceAlias) -> PathBuf {
        self.grimoire_home
            .join("candidates")
            .join(scope_key)
            .join(format!("{alias}.json"))
    }

    pub fn candidate_lock_path(&self, scope_key: &str, alias: &SourceAlias) -> PathBuf {
        self.grimoire_home
            .join("locks/candidates")
            .join(scope_key)
            .join(format!("{alias}.lock"))
    }

    pub fn cache_lock_path(&self, source: &SourceKey) -> PathBuf {
        self.grimoire_home
            .join("locks/cache")
            .join(format!("{source}.lock"))
    }

    pub fn store_lock_path(&self) -> PathBuf {
        self.grimoire_home.join("locks/store.lock")
    }

    pub fn trust_lock_path(&self) -> PathBuf {
        self.grimoire_home.join("locks/trust.lock")
    }

    pub fn projects_lock_path(&self) -> PathBuf {
        self.grimoire_home.join("locks/projects.lock")
    }

    pub fn scope_lock_path(&self, scope_key: &str) -> PathBuf {
        self.grimoire_home
            .join("transactions")
            .join(scope_key)
            .join("scope.lock")
    }

    pub fn transaction_dir(&self, scope_key: &str) -> PathBuf {
        self.grimoire_home.join("transactions").join(scope_key)
    }

    pub fn transaction_journal_path(&self, scope_key: &str) -> PathBuf {
        self.transaction_dir(scope_key).join("journal.json")
    }

    pub fn projects_path(&self) -> PathBuf {
        self.grimoire_home.join("projects.json")
    }

    pub fn store_path(&self, source: &SourceKey, snapshot: &SnapshotKey) -> PathBuf {
        self.grimoire_home
            .join("store/checkouts")
            .join(source.as_str())
            .join(snapshot.as_str())
    }

    pub fn store_repair_path(&self, source: &SourceKey, snapshot: &SnapshotKey) -> PathBuf {
        self.grimoire_home
            .join("transactions/store-repair")
            .join(source.as_str())
            .join(format!("{snapshot}.json"))
    }

    pub fn scope_key(&self) -> String {
        match &self.scope {
            ScopePaths::Global { .. } => "global".into(),
            ScopePaths::Project { root } => project_scope_key(root),
        }
    }
}

pub(crate) fn project_scope_key(root: &Path) -> String {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        crate::source::identity::hash_key(
            b"grimoire/scope-key@1",
            [
                Some(b"project".as_slice()),
                Some(root.as_os_str().as_bytes()),
            ],
        )
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire source custody supports Unix hosts")
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
