use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

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
    sources: BTreeMap<String, SourceDto>,
    packs: BTreeMap<String, PackDto>,
    skills: BTreeMap<String, SkillDto>,
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
            .into_iter()
            .map(|(alias, source)| {
                let alias = SourceAlias::new(alias)?;
                let value = match source.kind.as_str() {
                    "git" => LockSource::Git {
                        declared: source.declared,
                        reference: source.r#ref,
                        commit: source.commit.ok_or_else(|| {
                            CoreError::Lock(format!("Git source `{alias}` is missing commit"))
                        })?,
                        tree: source.tree.ok_or_else(|| {
                            CoreError::Lock(format!("Git source `{alias}` is missing tree"))
                        })?,
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
            .into_iter()
            .map(|(name, pack)| {
                Ok((
                    PackName::new(name)?,
                    LockPack {
                        source: SourceAlias::new(pack.source)?,
                        required: skill_set(pack.required)?,
                        optional: skill_set(pack.optional)?,
                        enabled: skill_set(pack.enabled)?,
                        unavailable: skill_set(pack.unavailable)?,
                    },
                ))
            })
            .collect::<Result<_>>()?;
        let skills = dto
            .skills
            .into_iter()
            .map(|(name, skill)| {
                let requested_by = skill
                    .requested_by
                    .into_iter()
                    .map(parse_root)
                    .collect::<Result<_>>()?;
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
        Ok(Self {
            sources,
            packs,
            skills,
        })
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
                        requested_by: skill
                            .requested_by
                            .iter()
                            .map(RequestRoot::lock_value)
                            .collect(),
                    },
                )
            })
            .collect();
        Self {
            schema: "grimoire/lock@1".into(),
            sources,
            packs,
            skills,
        }
    }
}

fn skill_set(values: Vec<String>) -> Result<BTreeSet<SkillName>> {
    let mut set = BTreeSet::new();
    for value in values {
        if !set.insert(SkillName::new(value.clone())?) {
            return Err(CoreError::Lock(format!("duplicate skill name `{value}`")));
        }
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
