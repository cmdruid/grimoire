use std::collections::{BTreeMap, BTreeSet};

use toml_edit::{Document, Item, TableLike, Value};

use crate::{CoreError, PackName, Result, SkillName, SourceAlias};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SourceLocation {
    Url(String),
    Path(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestSource {
    pub location: SourceLocation,
    pub reference: Option<String>,
    pub live: bool,
}

impl ManifestSource {
    pub fn declared(&self) -> &str {
        match &self.location {
            SourceLocation::Url(value) | SourceLocation::Path(value) => value,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestPack {
    pub source: SourceAlias,
    pub exclude: BTreeSet<SkillName>,
}

#[derive(Debug, Clone)]
pub struct Manifest {
    original: Vec<u8>,
    #[allow(dead_code)]
    document: Document<String>,
    pub sources: BTreeMap<SourceAlias, ManifestSource>,
    pub skills: BTreeMap<SkillName, SourceAlias>,
    pub packs: BTreeMap<PackName, ManifestPack>,
}

impl Manifest {
    pub fn parse(bytes: Vec<u8>) -> Result<Self> {
        let text = String::from_utf8(bytes.clone())?;
        let document = Document::parse(text)?;
        let root = document.as_table();
        reject_unknown(root, &["schema", "sources", "skills", "packs"], "top level")?;
        if root.get("schema").and_then(Item::as_str) != Some("grimoire/manifest@1") {
            return Err(CoreError::Manifest(
                "schema must equal grimoire/manifest@1".into(),
            ));
        }

        let mut sources = BTreeMap::new();
        if let Some(item) = root.get("sources") {
            let table = item
                .as_table_like()
                .ok_or_else(|| CoreError::Manifest("sources must be a table".into()))?;
            for (name, source) in table.iter() {
                let alias = SourceAlias::new(name)?;
                let source = source.as_table_like().ok_or_else(|| {
                    CoreError::Manifest(format!("source `{name}` must be a table"))
                })?;
                reject_unknown_like(source, &["url", "path", "ref", "live"], "source")?;
                let url = source.get("url").and_then(Item::as_str);
                let path = source.get("path").and_then(Item::as_str);
                let location = match (url, path) {
                    (Some(value), None) => SourceLocation::Url(value.into()),
                    (None, Some(value)) => SourceLocation::Path(value.into()),
                    _ => {
                        return Err(CoreError::Manifest(format!(
                            "source `{name}` must contain exactly one of url or path"
                        )))
                    }
                };
                let reference = optional_string(source, "ref")?;
                let live = optional_bool(source, "live")?.unwrap_or(false);
                if live && (matches!(location, SourceLocation::Url(_)) || reference.is_some()) {
                    return Err(CoreError::Manifest(format!(
                        "source `{name}` may use live only with path and without ref"
                    )));
                }
                sources.insert(
                    alias,
                    ManifestSource {
                        location,
                        reference,
                        live,
                    },
                );
            }
        }

        let mut skills = BTreeMap::new();
        if let Some(item) = root.get("skills") {
            let table = item
                .as_table_like()
                .ok_or_else(|| CoreError::Manifest("skills must be a table".into()))?;
            for (name, request) in table.iter() {
                let name = SkillName::new(name)?;
                let request = request.as_inline_table().ok_or_else(|| {
                    CoreError::Manifest(format!("skill `{name}` must be an inline table"))
                })?;
                reject_unknown_values(request.iter(), &["source"], "skill request")?;
                let source = request
                    .get("source")
                    .and_then(Value::as_str)
                    .ok_or_else(|| {
                        CoreError::Manifest(format!("skill `{name}` requires string source"))
                    })?;
                let source = SourceAlias::new(source)?;
                if !sources.contains_key(&source) {
                    return Err(CoreError::Manifest(format!(
                        "skill `{name}` references unknown source `{source}`"
                    )));
                }
                skills.insert(name, source);
            }
        }

        let mut packs = BTreeMap::new();
        if let Some(item) = root.get("packs") {
            let table = item
                .as_table_like()
                .ok_or_else(|| CoreError::Manifest("packs must be a table".into()))?;
            for (name, request) in table.iter() {
                let name = PackName::new(name)?;
                let request = request.as_inline_table().ok_or_else(|| {
                    CoreError::Manifest(format!("pack `{name}` must be an inline table"))
                })?;
                reject_unknown_values(request.iter(), &["source", "exclude"], "pack request")?;
                let source = request
                    .get("source")
                    .and_then(Value::as_str)
                    .ok_or_else(|| {
                        CoreError::Manifest(format!("pack `{name}` requires string source"))
                    })?;
                let source = SourceAlias::new(source)?;
                if !sources.contains_key(&source) {
                    return Err(CoreError::Manifest(format!(
                        "pack `{name}` references unknown source `{source}`"
                    )));
                }
                let exclude = match request.get("exclude") {
                    None => BTreeSet::new(),
                    Some(Value::Array(values)) => values
                        .iter()
                        .map(|value| {
                            value
                                .as_str()
                                .ok_or_else(|| {
                                    CoreError::Manifest(format!(
                                        "pack `{name}` exclusions must be strings"
                                    ))
                                })
                                .and_then(SkillName::new)
                        })
                        .collect::<Result<BTreeSet<_>>>()?,
                    Some(_) => {
                        return Err(CoreError::Manifest(format!(
                            "pack `{name}` exclude must be an array"
                        )))
                    }
                };
                packs.insert(name, ManifestPack { source, exclude });
            }
        }

        Ok(Self {
            original: bytes,
            document,
            sources,
            skills,
            packs,
        })
    }

    pub fn original_bytes(&self) -> &[u8] {
        &self.original
    }
}

fn reject_unknown(table: &toml_edit::Table, allowed: &[&str], where_: &str) -> Result<()> {
    reject_unknown_like(table, allowed, where_)
}

fn reject_unknown_like(table: &dyn TableLike, allowed: &[&str], where_: &str) -> Result<()> {
    for (key, _) in table.iter() {
        if !allowed.contains(&key) {
            return Err(CoreError::Manifest(format!("unknown {where_} key `{key}`")));
        }
    }
    Ok(())
}

fn reject_unknown_values<'a>(
    values: impl Iterator<Item = (&'a str, &'a Value)>,
    allowed: &[&str],
    where_: &str,
) -> Result<()> {
    for (key, _) in values {
        if !allowed.contains(&key) {
            return Err(CoreError::Manifest(format!("unknown {where_} key `{key}`")));
        }
    }
    Ok(())
}

fn optional_string(table: &dyn TableLike, key: &str) -> Result<Option<String>> {
    match table.get(key) {
        None => Ok(None),
        Some(item) => {
            item.as_str().map(str::to_owned).map(Some).ok_or_else(|| {
                CoreError::Manifest(format!("source field `{key}` must be a string"))
            })
        }
    }
}

fn optional_bool(table: &dyn TableLike, key: &str) -> Result<Option<bool>> {
    match table.get(key) {
        None => Ok(None),
        Some(item) => item
            .as_bool()
            .map(Some)
            .ok_or_else(|| CoreError::Manifest(format!("source field `{key}` must be a boolean"))),
    }
}
