use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use grimoire_pack::inventory::SourceInventory;
use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};

use crate::{CoreError, Result};

fn valid_slug(value: &str) -> bool {
    !value.is_empty()
        && value.bytes().enumerate().all(|(index, byte)| match byte {
            b'a'..=b'z' | b'0'..=b'9' => true,
            b'-' => index > 0 && !value.as_bytes()[index - 1].eq(&b'-'),
            _ => false,
        })
        && !value.ends_with('-')
}

macro_rules! slug_type {
    ($name:ident, $kind:literal) => {
        #[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(String);

        impl $name {
            pub fn new(value: impl Into<String>) -> Result<Self> {
                let value = value.into();
                if valid_slug(&value) {
                    Ok(Self(value))
                } else {
                    Err(CoreError::InvalidSlug { kind: $kind, value })
                }
            }

            pub fn as_str(&self) -> &str {
                &self.0
            }
        }

        impl TryFrom<&str> for $name {
            type Error = CoreError;

            fn try_from(value: &str) -> Result<Self> {
                Self::new(value)
            }
        }

        impl std::fmt::Display for $name {
            fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                formatter.write_str(&self.0)
            }
        }
    };
}

slug_type!(SourceAlias, "source alias");
slug_type!(SkillName, "skill name");
slug_type!(PackName, "pack name");

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Scope {
    Project,
    Global,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SnapshotKind {
    Git,
    Live,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct SnapshotId {
    pub kind: SnapshotKind,
    pub commit: Option<String>,
    pub tree: Option<String>,
    pub inventory_digest: String,
}

impl SnapshotId {
    pub fn new(
        kind: SnapshotKind,
        commit: Option<String>,
        tree: Option<String>,
        inventory_digest: String,
    ) -> Result<Self> {
        let valid_object = |value: &str| {
            matches!(value.len(), 40 | 64) && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        };
        match kind {
            SnapshotKind::Git => {
                if !commit.as_deref().is_some_and(valid_object)
                    || !tree.as_deref().is_some_and(valid_object)
                {
                    return Err(CoreError::Snapshot(
                        "Git snapshots require full hexadecimal commit and tree IDs".into(),
                    ));
                }
            }
            SnapshotKind::Live if commit.is_some() || tree.is_some() => {
                return Err(CoreError::Snapshot(
                    "live snapshots cannot carry commit or tree IDs".into(),
                ));
            }
            SnapshotKind::Live => {}
        }
        if !inventory_digest.starts_with("sha256:") {
            return Err(CoreError::Snapshot(
                "inventory digest must use the sha256: prefix".into(),
            ));
        }
        Ok(Self {
            kind,
            commit,
            tree,
            inventory_digest,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "kind", content = "name", rename_all = "snake_case")]
pub enum RequestRoot {
    Skill(SkillName),
    Pack(PackName),
}

impl RequestRoot {
    pub fn lock_value(&self) -> String {
        match self {
            Self::Skill(name) => format!("skill:{name}"),
            Self::Pack(name) => format!("pack:{name}"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceSnapshot {
    pub alias: SourceAlias,
    pub id: SnapshotId,
    pub root: PathBuf,
    pub inventory: SourceInventory,
}

impl SourceSnapshot {
    pub fn new(
        alias: SourceAlias,
        id: SnapshotId,
        root: PathBuf,
        inventory: SourceInventory,
    ) -> Self {
        Self {
            alias,
            id,
            root,
            inventory,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "target", rename_all = "snake_case")]
pub enum InstalledLink {
    Absent,
    Symlink(PathBuf),
    File,
    Directory,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ByteHash(String);

impl ByteHash {
    pub fn of(bytes: &[u8]) -> Self {
        Self(format!("{:x}", Sha256::digest(bytes)))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PlanningMode {
    Normal,
    Frozen,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Request {
    Initialize,
    Reconcile,
    AddSource {
        alias: SourceAlias,
        source: crate::ManifestSource,
    },
    RemoveSource {
        alias: SourceAlias,
    },
    InstallSkill {
        name: SkillName,
        source: SourceAlias,
    },
    UninstallSkill {
        name: SkillName,
    },
    InstallPack {
        name: PackName,
        request: crate::ManifestPack,
    },
    UninstallPack {
        name: PackName,
    },
    ReplacePackExclusions {
        name: PackName,
        exclude: BTreeSet<SkillName>,
    },
    UpdateSource {
        alias: SourceAlias,
        snapshot: Box<SourceSnapshot>,
    },
}

#[derive(Debug, Clone)]
pub struct WorldState {
    pub scope: Scope,
    pub manifest_bytes: Vec<u8>,
    pub manifest: crate::Manifest,
    pub lock_bytes: Vec<u8>,
    pub lock: crate::Lockfile,
    pub snapshots: BTreeMap<SourceAlias, SourceSnapshot>,
    pub links: BTreeMap<SkillName, InstalledLink>,
    pub inherited_global: Option<crate::resolve::Resolution>,
    pub manifest_present: bool,
    pub lock_present: bool,
}

impl WorldState {
    pub fn from_bytes<'a>(
        scope: Scope,
        manifest_bytes: Vec<u8>,
        lock_bytes: Vec<u8>,
        snapshots: impl IntoIterator<Item = SourceSnapshot>,
        links: impl IntoIterator<Item = (&'a str, InstalledLink)>,
        inherited_global: Option<crate::resolve::Resolution>,
    ) -> Result<Self> {
        let manifest = crate::Manifest::parse(manifest_bytes.clone())?;
        let lock = crate::Lockfile::parse(&lock_bytes)?;
        let snapshots = snapshots
            .into_iter()
            .map(|snapshot| (snapshot.alias.clone(), snapshot))
            .collect();
        let links = links
            .into_iter()
            .map(|(name, link)| Ok((SkillName::new(name)?, link)))
            .collect::<Result<_>>()?;
        Ok(Self {
            scope,
            manifest_bytes,
            manifest,
            lock_bytes,
            lock,
            snapshots,
            links,
            inherited_global,
            manifest_present: true,
            lock_present: true,
        })
    }

    pub fn absent<'a>(
        scope: Scope,
        snapshots: impl IntoIterator<Item = SourceSnapshot>,
        links: impl IntoIterator<Item = (&'a str, InstalledLink)>,
        inherited_global: Option<crate::resolve::Resolution>,
    ) -> Result<Self> {
        let mut world = Self::from_bytes(
            scope,
            b"schema = \"grimoire/manifest@1\"\n".to_vec(),
            crate::Lockfile::default().to_bytes()?,
            snapshots,
            links,
            inherited_global,
        )?;
        world.manifest_present = false;
        world.lock_present = false;
        Ok(world)
    }
}
