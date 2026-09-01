use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::marker::PhantomData;

use serde::de::{MapAccess, Visitor};
use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

use crate::{CoreError, PackName, RequestRoot, Result, SkillName, SourceAlias};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LockSource {
    Git {
        declared: String,
        reference: Option<String>,
        commit: String,
        tree: String,
    },
    Live {
        declared: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LockPack {
    pub source: SourceAlias,
    pub required: BTreeSet<SkillName>,
    pub optional: BTreeSet<SkillName>,
    pub enabled: BTreeSet<SkillName>,
    pub unavailable: BTreeSet<SkillName>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LockSkill {
    pub source: SourceAlias,
    pub path: String,
    pub content: String,
    pub requested_by: BTreeSet<RequestRoot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Lockfile {
    pub sources: BTreeMap<SourceAlias, LockSource>,
    pub packs: BTreeMap<PackName, LockPack>,
    pub skills: BTreeMap<SkillName, LockSkill>,
}

impl Lockfile {
    pub fn parse(bytes: &[u8]) -> Result<Self> {
        let dto: LockDto = serde_json::from_slice(bytes)?;
        if dto.schema != "grimoire/lock@1" {
            return Err(CoreError::LockSchemaUnsupported { found: dto.schema });
        }
        dto.try_into()
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let dto = LockDto::from(self);
        let mut bytes = serde_json::to_vec_pretty(&dto)?;
        bytes.push(b'\n');
        Ok(bytes)
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct LockDto {
    schema: String,
    sources: UniqueMap<SourceDto>,
    packs: UniqueMap<PackDto>,
    skills: UniqueMap<SkillDto>,
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
                        return Err(de::Error::custom(format!("duplicate object key `{key}`")));
                    }
                }
                Ok(UniqueMap(values))
            }
        }

        deserializer.deserialize_map(UniqueMapVisitor(PhantomData))
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct SourceDto {
    declared: String,
    kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    r#ref: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    commit: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    tree: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct PackDto {
    source: String,
    required: Vec<String>,
    optional: Vec<String>,
    enabled: Vec<String>,
    unavailable: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct SkillDto {
    source: String,
    path: String,
    content: String,
    requested_by: Vec<String>,
}

impl TryFrom<LockDto> for Lockfile {
    type Error = CoreError;

    fn try_from(dto: LockDto) -> Result<Self> {
        let sources = dto
            .sources
            .0
            .into_iter()
            .map(|(alias, source)| {
                let alias = SourceAlias::new(alias)?;
                let value = match source.kind.as_str() {
                    "git" => LockSource::Git {
                        declared: source.declared,
                        reference: source.r#ref,
                        commit: checked_object_id(
                            source.commit.ok_or_else(|| {
                                CoreError::Lock(format!("Git source `{alias}` is missing commit"))
                            })?,
                            &format!("source `{alias}` commit"),
                        )?,
                        tree: checked_object_id(
                            source.tree.ok_or_else(|| {
                                CoreError::Lock(format!("Git source `{alias}` is missing tree"))
                            })?,
                            &format!("source `{alias}` tree"),
                        )?,
                    },
                    "live"
                        if source.r#ref.is_none()
                            && source.commit.is_none()
                            && source.tree.is_none() =>
                    {
                        LockSource::Live {
                            declared: source.declared,
                        }
                    }
                    "live" => {
                        return Err(CoreError::Lock(format!(
                            "live source `{alias}` contains Git-only fields"
                        )))
                    }
                    kind => {
                        return Err(CoreError::Lock(format!(
                            "source `{alias}` has unknown kind `{kind}`"
                        )))
                    }
                };
                Ok((alias, value))
            })
            .collect::<Result<_>>()?;
        let packs = dto
            .packs
            .0
            .into_iter()
            .map(|(name, pack)| {
                Ok((
                    PackName::new(name)?,
                    LockPack {
                        source: SourceAlias::new(pack.source)?,
                        required: skill_set(pack.required, "required")?,
                        optional: skill_set(pack.optional, "optional")?,
                        enabled: skill_set(pack.enabled, "enabled")?,
                        unavailable: skill_set(pack.unavailable, "unavailable")?,
                    },
                ))
            })
            .collect::<Result<_>>()?;
        let skills = dto
            .skills
            .0
            .into_iter()
            .map(|(name, skill)| {
                validate_sorted_unique(&skill.requested_by, "requested_by")?;
                if skill.requested_by.is_empty() {
                    return Err(CoreError::Lock(format!(
                        "skill `{name}` has no request roots"
                    )));
                }
                let requested_by = skill
                    .requested_by
                    .into_iter()
                    .map(parse_root)
                    .collect::<Result<_>>()?;
                validate_source_path(&skill.path, &name)?;
                validate_digest(&skill.content, &name)?;
                Ok((
                    SkillName::new(name)?,
                    LockSkill {
                        source: SourceAlias::new(skill.source)?,
                        path: skill.path,
                        content: skill.content,
                        requested_by,
                    },
                ))
            })
            .collect::<Result<_>>()?;
        let lock = Self {
            sources,
            packs,
            skills,
        };
        lock.validate()?;
        Ok(lock)
    }
}

impl From<&Lockfile> for LockDto {
    fn from(lock: &Lockfile) -> Self {
        let sources = lock
            .sources
            .iter()
            .map(|(alias, source)| {
                let dto = match source {
                    LockSource::Git {
                        declared,
                        reference,
                        commit,
                        tree,
                    } => SourceDto {
                        declared: declared.clone(),
                        kind: "git".into(),
                        r#ref: reference.clone(),
                        commit: Some(commit.clone()),
                        tree: Some(tree.clone()),
                    },
                    LockSource::Live { declared } => SourceDto {
                        declared: declared.clone(),
                        kind: "live".into(),
                        r#ref: None,
                        commit: None,
                        tree: None,
                    },
                };
                (alias.to_string(), dto)
            })
            .collect();
        let packs = lock
            .packs
            .iter()
            .map(|(name, pack)| {
                (
                    name.to_string(),
                    PackDto {
                        source: pack.source.to_string(),
                        required: names(&pack.required),
                        optional: names(&pack.optional),
                        enabled: names(&pack.enabled),
                        unavailable: names(&pack.unavailable),
                    },
                )
            })
            .collect();
        let skills = lock
            .skills
            .iter()
            .map(|(name, skill)| {
                (
                    name.to_string(),
                    SkillDto {
                        source: skill.source.to_string(),
                        path: skill.path.clone(),
                        content: skill.content.clone(),
                        requested_by: {
                            let mut roots: Vec<_> = skill
                                .requested_by
                                .iter()
                                .map(RequestRoot::lock_value)
                                .collect();
                            roots.sort();
                            roots
                        },
                    },
                )
            })
            .collect();
        Self {
            schema: "grimoire/lock@1".into(),
            sources: UniqueMap(sources),
            packs: UniqueMap(packs),
            skills: UniqueMap(skills),
        }
    }
}

fn skill_set(values: Vec<String>, field: &str) -> Result<BTreeSet<SkillName>> {
    validate_sorted_unique(&values, field)?;
    let mut set = BTreeSet::new();
    for value in values {
        set.insert(SkillName::new(value)?);
    }
    Ok(set)
}

fn names(values: &BTreeSet<SkillName>) -> Vec<String> {
    values.iter().map(ToString::to_string).collect()
}

fn parse_root(value: String) -> Result<RequestRoot> {
    if let Some(name) = value.strip_prefix("skill:") {
        Ok(RequestRoot::Skill(SkillName::new(name)?))
    } else if let Some(name) = value.strip_prefix("pack:") {
        Ok(RequestRoot::Pack(PackName::new(name)?))
    } else {
        Err(CoreError::Lock(format!("invalid request root `{value}`")))
    }
}

impl Lockfile {
    fn validate(&self) -> Result<()> {
        for (name, pack) in &self.packs {
            if !self.sources.contains_key(&pack.source) {
                return Err(CoreError::Lock(format!(
                    "pack `{name}` references unknown source `{}`",
                    pack.source
                )));
            }
            if !pack.required.is_disjoint(&pack.optional) {
                return Err(CoreError::Lock(format!(
                    "pack `{name}` repeats a member across required and optional"
                )));
            }
            if !pack.enabled.is_subset(&pack.optional) {
                return Err(CoreError::Lock(format!(
                    "pack `{name}` enables a non-optional member"
                )));
            }
            if !pack.unavailable.is_subset(&pack.enabled) {
                return Err(CoreError::Lock(format!(
                    "pack `{name}` marks a disabled member unavailable"
                )));
            }
        }
        for (name, skill) in &self.skills {
            if !self.sources.contains_key(&skill.source) {
                return Err(CoreError::Lock(format!(
                    "skill `{name}` references unknown source `{}`",
                    skill.source
                )));
            }
        }
        for alias in self.sources.keys() {
            if !self.packs.values().any(|pack| &pack.source == alias)
                && !self.skills.values().any(|skill| &skill.source == alias)
            {
                return Err(CoreError::Lock(format!(
                    "source `{alias}` contributes no requested pack or skill"
                )));
            }
        }
        Ok(())
    }
}

fn validate_sorted_unique(values: &[String], field: &str) -> Result<()> {
    if values.windows(2).any(|pair| pair[0] >= pair[1]) {
        return Err(CoreError::Lock(format!(
            "{field} must be lexically sorted and unique"
        )));
    }
    Ok(())
}

fn checked_object_id(value: String, field: &str) -> Result<String> {
    if matches!(value.len(), 40 | 64)
        && value
            .bytes()
            .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f'))
    {
        Ok(value)
    } else {
        Err(CoreError::Lock(format!(
            "{field} must be a full lowercase hexadecimal object ID"
        )))
    }
}

fn validate_digest(value: &str, skill: &str) -> Result<()> {
    let Some(hex) = value.strip_prefix("sha256:") else {
        return Err(CoreError::Lock(format!(
            "skill `{skill}` content is not a sha256 digest"
        )));
    };
    if hex.len() == 64
        && hex
            .bytes()
            .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f'))
    {
        Ok(())
    } else {
        Err(CoreError::Lock(format!(
            "skill `{skill}` content is not a canonical sha256 digest"
        )))
    }
}

fn validate_source_path(value: &str, skill: &str) -> Result<()> {
    if value.is_empty()
        || value.starts_with('/')
        || value
            .split('/')
            .any(|component| component.is_empty() || matches!(component, "." | ".."))
    {
        return Err(CoreError::Lock(format!(
            "skill `{skill}` path must be source-relative"
        )));
    }
    Ok(())
}
