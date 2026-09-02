use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::marker::PhantomData;
use std::path::{Component, Path, PathBuf};

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use serde::de::{MapAccess, Visitor};
use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

use crate::transaction::replace;
use crate::{
    ByteHash, CoreError, LockSource, Lockfile, Manifest, Paths, ProjectRecord, ProjectReference,
    Result, ScopePaths, SnapshotKey, SourceKey, SourceKind,
};

const PROJECTS_SCHEMA: &str = "grimoire/projects@1";
const PROJECTS_LIMIT: u64 = 16 * 1024 * 1024;

impl crate::ProjectIndex {
    pub fn parse(bytes: &[u8]) -> Result<Self> {
        let dto: ProjectsDto = serde_json::from_slice(bytes)
            .map_err(|error| CoreError::Request(format!("invalid project index: {error}")))?;
        if dto.schema != PROJECTS_SCHEMA {
            return Err(CoreError::Request(
                "unsupported project index schema".into(),
            ));
        }
        let mut records = BTreeMap::new();
        for (scope_key, record) in dto.projects.0 {
            validate_scope_key(&scope_key)?;
            let path = record.path()?;
            if crate::scope::project_scope_key(&path) != scope_key {
                return Err(CoreError::Request(
                    "project index scope-key mismatch".into(),
                ));
            }
            if record.last_observed < 0 {
                return Err(CoreError::Request(
                    "project index timestamp is negative".into(),
                ));
            }
            let mut references = BTreeSet::new();
            let mut previous = None;
            for reference in record.references {
                let value = ProjectReference {
                    source_key: SourceKey::parse(reference.source_key)?,
                    snapshot_key: SnapshotKey::parse(reference.snapshot_key)?,
                };
                if previous.as_ref().is_some_and(|previous| previous >= &value)
                    || !references.insert(value.clone())
                {
                    return Err(CoreError::Request(
                        "project references are not strictly sorted".into(),
                    ));
                }
                previous = Some(value);
            }
            records.insert(
                scope_key.clone(),
                ProjectRecord {
                    path,
                    scope_key,
                    lock_hash: ByteHash::parse(record.lock_hash)?,
                    references,
                    last_observed: record.last_observed,
                },
            );
        }
        Ok(Self { records })
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let mut projects = BTreeMap::new();
        for (scope_key, record) in &self.records {
            validate_scope_key(scope_key)?;
            validate_path(&record.path)?;
            if record.last_observed < 0 {
                return Err(CoreError::Request(
                    "project index timestamp is negative".into(),
                ));
            }
            if record.scope_key != *scope_key
                || crate::scope::project_scope_key(&record.path) != *scope_key
            {
                return Err(CoreError::Request(
                    "project record identity mismatch".into(),
                ));
            }
            projects.insert(scope_key.clone(), ProjectDto::from(record));
        }
        let mut bytes = serde_json::to_vec_pretty(&ProjectsDto {
            schema: PROJECTS_SCHEMA.into(),
            projects: UniqueMap(projects),
        })?;
        bytes.push(b'\n');
        Ok(bytes)
    }
}

pub(crate) fn read(paths: &Paths) -> Result<Option<Vec<u8>>> {
    let path = paths.projects_path();
    let metadata = match std::fs::symlink_metadata(&path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(crate::transaction::io_error(&path, error)),
    };
    if !metadata.is_file() || metadata.file_type().is_symlink() || metadata.len() > PROJECTS_LIMIT {
        return Err(CoreError::Request(
            "project index is not a bounded regular file".into(),
        ));
    }
    match std::fs::read(&path) {
        Ok(bytes) => {
            crate::ProjectIndex::parse(&bytes)?;
            Ok(Some(bytes))
        }
        Err(error) => Err(crate::transaction::io_error(&path, error)),
    }
}

pub(crate) fn refresh_locked(
    paths: &Paths,
    manifest: &Manifest,
    lock: &Lockfile,
    lock_bytes: &[u8],
    unix_time: i64,
    nonce: &str,
) -> Result<Vec<u8>> {
    if unix_time < 0 {
        return Err(CoreError::Transaction(
            "project observation time is negative".into(),
        ));
    }
    let ScopePaths::Project { root } = &paths.scope else {
        return Err(CoreError::Transaction(
            "global scope cannot refresh the project index".into(),
        ));
    };
    validate_nonce(nonce)?;
    let canonical = root
        .canonicalize()
        .map_err(|error| crate::transaction::io_error(root, error))?;
    let scope_key = crate::scope::project_scope_key(&canonical);
    if scope_key != paths.scope_key() {
        return Err(CoreError::Transaction(
            "resolved project path is not canonical".into(),
        ));
    }
    let mut index = match read(paths)? {
        Some(bytes) => crate::ProjectIndex::parse(&bytes)?,
        None => crate::ProjectIndex::default(),
    };
    let references = references(paths, manifest, lock)?;
    index.records.insert(
        scope_key.clone(),
        ProjectRecord {
            path: canonical,
            scope_key,
            lock_hash: ByteHash::of(lock_bytes),
            references,
            last_observed: unix_time,
        },
    );
    let bytes = index.to_bytes()?;
    replace(&paths.projects_path(), &bytes, nonce, Some(0o600))?;
    Ok(bytes)
}

fn references(
    paths: &Paths,
    manifest: &Manifest,
    lock: &Lockfile,
) -> Result<BTreeSet<ProjectReference>> {
    lock.sources
        .iter()
        .filter_map(|(alias, source)| match source {
            LockSource::Git {
                commit,
                tree,
                inventory,
                ..
            } => Some((alias, commit, tree, inventory)),
            LockSource::Live { .. } => None,
        })
        .map(|(alias, commit, tree, inventory)| {
            let identity = crate::world::declaration_identity(paths, manifest, alias)?;
            Ok(ProjectReference {
                source_key: SourceKey::derive(&identity),
                snapshot_key: SnapshotKey::derive(SourceKind::Git, commit, tree, inventory)?,
            })
        })
        .collect()
}

fn validate_scope_key(value: &str) -> Result<()> {
    if value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(())
    } else {
        Err(CoreError::Request("invalid project scope key".into()))
    }
}

fn validate_nonce(value: &str) -> Result<()> {
    if !value.is_empty()
        && value.len() <= 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
    {
        Ok(())
    } else {
        Err(CoreError::Transaction("invalid project-index nonce".into()))
    }
}

fn validate_path(path: &Path) -> Result<()> {
    #[cfg(unix)]
    let contains_nul = {
        use std::os::unix::ffi::OsStrExt;
        path.as_os_str().as_bytes().contains(&0)
    };
    #[cfg(not(unix))]
    let contains_nul = false;
    if path.is_absolute()
        && !contains_nul
        && path
            .components()
            .all(|component| matches!(component, Component::RootDir | Component::Normal(_)))
    {
        Ok(())
    } else {
        Err(CoreError::Request(
            "project index path is not absolute and normalized".into(),
        ))
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ProjectsDto {
    schema: String,
    projects: UniqueMap<ProjectDto>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ProjectDto {
    #[serde(skip_serializing_if = "Option::is_none")]
    path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    path_bytes_base64: Option<String>,
    lock_hash: String,
    references: Vec<ProjectReferenceDto>,
    last_observed: i64,
}

impl ProjectDto {
    fn path(&self) -> Result<PathBuf> {
        let bytes = match (&self.path, &self.path_bytes_base64) {
            (Some(path), None) => path.as_bytes().to_vec(),
            (None, Some(path)) => BASE64
                .decode(path)
                .map_err(|_| CoreError::Request("invalid project path base64".into()))?,
            _ => {
                return Err(CoreError::Request(
                    "project path requires one canonical projection".into(),
                ))
            }
        };
        #[cfg(unix)]
        let path = {
            use std::os::unix::ffi::OsStrExt;
            PathBuf::from(std::ffi::OsStr::from_bytes(&bytes))
        };
        #[cfg(not(unix))]
        let path = PathBuf::from(
            String::from_utf8(bytes)
                .map_err(|_| CoreError::Request("project path is not UTF-8".into()))?,
        );
        validate_path(&path)?;
        Ok(path)
    }
}

impl From<&ProjectRecord> for ProjectDto {
    fn from(record: &ProjectRecord) -> Self {
        #[cfg(unix)]
        let bytes = {
            use std::os::unix::ffi::OsStrExt;
            record.path.as_os_str().as_bytes()
        };
        #[cfg(not(unix))]
        let bytes = record.path.to_string_lossy().as_bytes();
        let (path, path_bytes_base64) = match std::str::from_utf8(bytes) {
            Ok(path) => (Some(path.into()), None),
            Err(_) => (None, Some(BASE64.encode(bytes))),
        };
        Self {
            path,
            path_bytes_base64,
            lock_hash: record.lock_hash.as_str().into(),
            references: record
                .references
                .iter()
                .map(ProjectReferenceDto::from)
                .collect(),
            last_observed: record.last_observed,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ProjectReferenceDto {
    source_key: String,
    snapshot_key: String,
}

impl From<&ProjectReference> for ProjectReferenceDto {
    fn from(reference: &ProjectReference) -> Self {
        Self {
            source_key: reference.source_key.to_string(),
            snapshot_key: reference.snapshot_key.to_string(),
        }
    }
}

#[derive(Debug)]
struct UniqueMap<V>(BTreeMap<String, V>);

impl<V: Serialize> Serialize for UniqueMap<V> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        self.0.serialize(serializer)
    }
}

impl<'de, V: Deserialize<'de>> Deserialize<'de> for UniqueMap<V> {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> std::result::Result<Self, D::Error> {
        struct UniqueMapVisitor<V>(PhantomData<V>);

        impl<'de, V: Deserialize<'de>> Visitor<'de> for UniqueMapVisitor<V> {
            type Value = UniqueMap<V>;

            fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
                formatter.write_str("an object with unique keys")
            }

            fn visit_map<A: MapAccess<'de>>(
                self,
                mut map: A,
            ) -> std::result::Result<Self::Value, A::Error> {
                let mut values = BTreeMap::new();
                while let Some((key, value)) = map.next_entry::<String, V>()? {
                    if values.insert(key.clone(), value).is_some() {
                        return Err(de::Error::custom(format!("duplicate project key `{key}`")));
                    }
                }
                Ok(UniqueMap(values))
            }
        }

        deserializer.deserialize_map(UniqueMapVisitor(PhantomData))
    }
}
