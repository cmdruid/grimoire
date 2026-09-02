use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::{CoreError, Result, SnapshotKey, SourceKey};

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct RepairJournal {
    schema: String,
    source_key: String,
    snapshot_key: String,
    fixed: String,
    quarantine: String,
    replacement: String,
}

impl RepairJournal {
    pub(super) fn new(source: &SourceKey, snapshot: &SnapshotKey, nonce: &str) -> Self {
        Self {
            schema: "grimoire/store-repair@1".into(),
            source_key: source.to_string(),
            snapshot_key: snapshot.to_string(),
            fixed: format!("store/checkouts/{source}/{snapshot}"),
            quarantine: format!("store/checkouts/{source}/.{snapshot}.quarantine-{nonce}"),
            replacement: format!("store/checkouts/{source}/.{snapshot}.replacement-{nonce}"),
        }
    }

    pub(super) fn validate(
        &self,
        home: &Path,
        source: &SourceKey,
        snapshot: &SnapshotKey,
    ) -> Result<(PathBuf, PathBuf, PathBuf)> {
        if self.schema != "grimoire/store-repair@1"
            || self.source_key != source.as_str()
            || self.snapshot_key != snapshot.as_str()
        {
            return Err(CoreError::Store("repair journal identity mismatch".into()));
        }
        let expected = Self::new(source, snapshot, suffix(&self.quarantine)?);
        if self.fixed != expected.fixed
            || self.quarantine != expected.quarantine
            || self.replacement != expected.replacement
        {
            return Err(CoreError::Store("repair journal path mismatch".into()));
        }
        let fixed = contained(home, &self.fixed)?;
        let quarantine = contained(home, &self.quarantine)?;
        let replacement = contained(home, &self.replacement)?;
        Ok((fixed, quarantine, replacement))
    }

    pub(super) fn to_bytes(&self) -> Result<Vec<u8>> {
        let mut bytes = serde_json::to_vec_pretty(self)?;
        bytes.push(b'\n');
        Ok(bytes)
    }

    pub(super) fn from_bytes(bytes: &[u8]) -> Result<Self> {
        serde_json::from_slice(bytes).map_err(CoreError::from)
    }
}

fn suffix(path: &str) -> Result<&str> {
    path.rsplit_once(".quarantine-")
        .map(|(_, suffix)| suffix)
        .filter(|suffix| !suffix.is_empty() && !suffix.contains('/'))
        .ok_or_else(|| CoreError::Store("invalid repair nonce".into()))
}

fn contained(home: &Path, relative: &str) -> Result<PathBuf> {
    let path = Path::new(relative);
    if path.is_absolute()
        || path.components().any(|component| {
            matches!(
                component,
                std::path::Component::ParentDir | std::path::Component::RootDir
            )
        })
    {
        return Err(CoreError::Store("repair path escapes home".into()));
    }
    Ok(home.join(path))
}

#[allow(dead_code)]
fn _remove_file_if_present(path: &Path) -> Result<()> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(CoreError::Io {
            path: path.display().to_string(),
            message: error.to_string(),
        }),
    }
}
