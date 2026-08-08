//! §3: the `grimoire.lock` sidecar. Tools are its only writers; unknown keys
//! are preserved; a newer lock version (or an unparseable file) is read-only.
//! The library takes `installedAt` as a caller-supplied string — no clock here.

use crate::{PackError, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::Path;

pub const LOCK_VERSION: u64 = 1;
pub const LOCK_FILE: &str = "grimoire.lock";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SkillEntry {
    pub hash: String,
    pub required: bool,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PackEntry {
    pub version: String,
    pub source: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub r#ref: Option<String>,
    #[serde(rename = "installedAt")]
    pub installed_at: String,
    #[serde(default)]
    pub skills: BTreeMap<String, SkillEntry>,
    /// Faceless packs cache the decoded manifest frontmatter here (§3).
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub manifest: Option<serde_json::Value>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Lock {
    pub version: u64,
    #[serde(default)]
    pub packs: BTreeMap<String, PackEntry>,
    #[serde(flatten)]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

impl Default for Lock {
    fn default() -> Self {
        Lock {
            version: LOCK_VERSION,
            packs: BTreeMap::new(),
            extra: serde_json::Map::new(),
        }
    }
}

/// `Ok(None)` when the file does not exist. `LockReadOnly` when it cannot be
/// parsed or declares a newer version — the caller must refuse rewrites (§3).
pub fn read(path: &Path) -> Result<Option<Lock>> {
    let text = match std::fs::read_to_string(path) {
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => {
            return Err(PackError::Io {
                path: path.to_path_buf(),
                source: e,
            })
        }
    };
    let value: serde_json::Value = serde_json::from_str(&text)
        .map_err(|e| PackError::LockReadOnly(format!("unparseable: {e}")))?;
    let version = value.get("version").and_then(|v| v.as_u64()).unwrap_or(1);
    if version > LOCK_VERSION {
        return Err(PackError::LockReadOnly(format!(
            "lock version {version} > implemented {LOCK_VERSION}"
        )));
    }
    let lock: Lock = serde_json::from_value(value)
        .map_err(|e| PackError::LockReadOnly(format!("malformed: {e}")))?;
    Ok(Some(lock))
}

/// Serialize and write the lock. No gating happens here: read-only
/// enforcement (§3) is entirely the caller's job — refuse to write a lock
/// whose `read` returned `LockReadOnly`, and never hand-bump `version`.
pub fn write(lock: &Lock, path: &Path) -> Result<()> {
    let mut text = serde_json::to_string_pretty(lock)
        .map_err(|e| PackError::Lock(format!("serialize: {e}")))?;
    text.push('\n');
    std::fs::write(path, text).map_err(|e| PackError::Io {
        path: path.to_path_buf(),
        source: e,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    fn entry() -> PackEntry {
        let mut skills = BTreeMap::new();
        skills.insert(
            "alpha".to_string(),
            SkillEntry {
                hash: "sha256:aa".into(),
                required: true,
                extra: Default::default(),
            },
        );
        skills.insert(
            "gamma".to_string(),
            SkillEntry {
                hash: "sha256:cc".into(),
                required: false,
                extra: Default::default(),
            },
        );
        PackEntry {
            version: "1.0.0".into(),
            source: "github:o/r".into(),
            r#ref: Some("abc1234".into()),
            installed_at: "2026-08-08T00:00:00Z".into(),
            skills,
            manifest: None,
            extra: Default::default(),
        }
    }

    #[test]
    fn roundtrip_preserves_unknown_keys() {
        let t = tempfile::tempdir().unwrap();
        let path = t.path().join("grimoire.lock");
        let json = r#"{
  "version": 1,
  "x-note": "keep me",
  "packs": {
    "other": { "version": "2.0.0", "source": "s", "installedAt": "t",
               "skills": {}, "x-owner": "them" }
  }
}"#;
        std::fs::write(&path, json).unwrap();
        let mut lock = read(&path).unwrap().unwrap();
        lock.packs.insert("alpha".to_string(), entry());
        write(&lock, &path).unwrap();
        let out = std::fs::read_to_string(&path).unwrap();
        assert!(out.contains("\"x-note\": \"keep me\""));
        assert!(out.contains("\"x-owner\": \"them\""));
        assert!(out.contains("\"required\": false"));
        assert!(out.ends_with('\n'));
        let again = read(&path).unwrap().unwrap();
        assert_eq!(again.packs.len(), 2);
        assert_eq!(again.packs["alpha"], entry());
    }

    #[test]
    fn absent_lock_reads_as_none() {
        let t = tempfile::tempdir().unwrap();
        assert!(read(&t.path().join("grimoire.lock")).unwrap().is_none());
    }

    #[test]
    fn newer_version_and_garbage_are_read_only_errors() {
        let t = tempfile::tempdir().unwrap();
        let path = t.path().join("grimoire.lock");
        std::fs::write(&path, r#"{"version": 2, "packs": {}}"#).unwrap();
        assert!(matches!(read(&path), Err(crate::PackError::LockReadOnly(_))));
        std::fs::write(&path, "not json").unwrap();
        assert!(matches!(read(&path), Err(crate::PackError::LockReadOnly(_))));
    }

    #[test]
    fn schema_mismatch_at_current_version_is_read_only() {
        let t = tempfile::tempdir().unwrap();
        let path = t.path().join("grimoire.lock");
        // valid JSON, current version, but a skill entry missing `required`
        std::fs::write(
            &path,
            r#"{"version": 1, "packs": {"p": {"version": "1.0.0", "source": "s",
                "installedAt": "t", "skills": {"a": {"hash": "sha256:aa"}}}}}"#,
        )
        .unwrap();
        assert!(matches!(read(&path), Err(crate::PackError::LockReadOnly(_))));
        // absent top-level version: also unparseable-as-v1 -> read-only
        std::fs::write(&path, r#"{"packs": {}}"#).unwrap();
        assert!(matches!(read(&path), Err(crate::PackError::LockReadOnly(_))));
    }
}
