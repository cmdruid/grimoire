use std::collections::{BTreeMap, BTreeSet};
use std::ops::Range;
use std::path::{Path, PathBuf};

use toml_edit::{Document, Item, TableLike, Value};

use crate::{CoreError, PackName, ProjectionMode, Result, SkillName, SourceAlias};

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

    pub fn from_cli(
        location: impl Into<String>,
        reference: Option<String>,
        live: bool,
    ) -> Result<Self> {
        let location = location.into();
        let remote_shaped = location.starts_with("github:")
            || location.contains("://")
            || location
                .split_once('@')
                .and_then(|(_, rest)| rest.split_once(':'))
                .is_some();
        if remote_shaped {
            crate::CanonicalIdentity::remote(&location)?;
            if live {
                return Err(CoreError::Source("remote sources cannot be live".into()));
            }
            return Ok(Self {
                location: SourceLocation::Url(location),
                reference,
                live: false,
            });
        }
        if live && reference.is_some() {
            return Err(CoreError::Source(
                "live sources cannot declare a Git ref".into(),
            ));
        }
        if location.is_empty() {
            return Err(CoreError::Source("local source path is empty".into()));
        }
        Ok(Self {
            location: SourceLocation::Path(location),
            reference,
            live,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestSkill {
    pub source: SourceAlias,
    pub mode: ProjectionMode,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestPack {
    pub source: SourceAlias,
    pub mode: ProjectionMode,
    pub exclude: BTreeSet<SkillName>,
}

#[derive(Debug, Clone)]
pub struct Manifest {
    original: Vec<u8>,
    document: Document<String>,
    pub sources: BTreeMap<SourceAlias, ManifestSource>,
    pub skills: BTreeMap<SkillName, ManifestSkill>,
    pub packs: BTreeMap<PackName, ManifestPack>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ManifestMutation {
    AddSource {
        alias: SourceAlias,
        source: ManifestSource,
    },
    RemoveSource {
        alias: SourceAlias,
    },
    InstallSkill {
        name: SkillName,
        request: ManifestSkill,
    },
    UninstallSkill {
        name: SkillName,
    },
    ReplaceSkillMode {
        name: SkillName,
        mode: ProjectionMode,
    },
    InstallPack {
        name: PackName,
        request: ManifestPack,
    },
    UninstallPack {
        name: PackName,
    },
    ReplacePackExclusions {
        name: PackName,
        exclude: BTreeSet<SkillName>,
    },
    ReplacePackMode {
        name: PackName,
        mode: ProjectionMode,
    },
}

#[derive(Debug, Clone)]
pub struct ManifestEdit {
    pub before: Vec<u8>,
    pub after: Vec<u8>,
    pub manifest: Manifest,
}

impl Manifest {
    pub fn parse(bytes: Vec<u8>) -> Result<Self> {
        let text = String::from_utf8(bytes.clone())?;
        let document = Document::parse(text)?;
        let root = document.as_table();
        reject_unknown(root, &["schema", "sources", "skills", "packs"], "top level")?;
        let schema = root.get("schema").and_then(Item::as_str);
        if schema != Some("grimoire/manifest@2") {
            let message = if schema == Some("grimoire/manifest@1") {
                "schema grimoire/manifest@1 is unsupported; change it to grimoire/manifest@2, delete the generated v1 lock, and run a non-frozen install"
            } else {
                "schema must equal grimoire/manifest@2"
            };
            return Err(CoreError::Manifest(message.into()));
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
                reject_unknown_values(request.iter(), &["source", "mode"], "skill request")?;
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
                let mode = projection_mode(request.get("mode"), "skill request")?;
                skills.insert(name, ManifestSkill { source, mode });
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
                reject_unknown_values(
                    request.iter(),
                    &["source", "mode", "exclude"],
                    "pack request",
                )?;
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
                    Some(Value::Array(values)) => {
                        let mut exclude = BTreeSet::new();
                        for value in values.iter() {
                            let value = value.as_str().ok_or_else(|| {
                                CoreError::Manifest(format!(
                                    "pack `{name}` exclusions must be strings"
                                ))
                            })?;
                            let value = SkillName::new(value)?;
                            if !exclude.insert(value.clone()) {
                                return Err(CoreError::Manifest(format!(
                                    "pack `{name}` repeats exclusion `{value}`"
                                )));
                            }
                        }
                        exclude
                    }
                    Some(_) => {
                        return Err(CoreError::Manifest(format!(
                            "pack `{name}` exclude must be an array"
                        )))
                    }
                };
                let mode = projection_mode(request.get("mode"), "pack request")?;
                packs.insert(
                    name,
                    ManifestPack {
                        source,
                        mode,
                        exclude,
                    },
                );
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

    pub fn source_declaration_hash(&self, alias: &SourceAlias) -> Result<String> {
        let sources = self
            .document
            .as_table()
            .get("sources")
            .and_then(Item::as_table_like)
            .ok_or_else(|| CoreError::Manifest("manifest has no sources table".into()))?;
        let source = sources
            .get(alias.as_str())
            .and_then(Item::as_table_like)
            .ok_or_else(|| CoreError::Manifest(format!("source `{alias}` is not declared")))?;
        let mut fields = vec![Some(alias.as_str().as_bytes())];
        for name in ["live", "path", "ref", "url"] {
            let Some((key, value)) = source.get_key_value(name) else {
                continue;
            };
            let key_span = key
                .span()
                .ok_or_else(|| CoreError::Manifest("source key has no input span".into()))?;
            let value_span = value
                .span()
                .ok_or_else(|| CoreError::Manifest("source value has no input span".into()))?;
            fields.push(Some(&self.original[key_span]));
            fields.push(Some(&self.original[value_span]));
        }
        Ok(crate::source::identity::hash_key(
            b"grimoire/source-declaration@1",
            fields,
        ))
    }

    pub fn resolve_declared_path(
        &self,
        alias: &SourceAlias,
        manifest_dir: &Path,
    ) -> Option<PathBuf> {
        let source = self.sources.get(alias)?;
        let SourceLocation::Path(declared) = &source.location else {
            return None;
        };
        let declared = Path::new(declared);
        Some(if declared.is_absolute() {
            declared.to_path_buf()
        } else {
            manifest_dir.join(declared)
        })
    }

    pub fn mutate(&self, mutation: ManifestMutation) -> Result<ManifestEdit> {
        let mut expected_sources = self.sources.clone();
        let mut expected_skills = self.skills.clone();
        let mut expected_packs = self.packs.clone();
        let mut after = self.original.clone();

        match mutation {
            ManifestMutation::AddSource { alias, source } => {
                if expected_sources
                    .insert(alias.clone(), source.clone())
                    .is_some()
                {
                    return Err(CoreError::Manifest(format!(
                        "source `{alias}` already exists"
                    )));
                }
                let mut fragment = format!("[sources.{alias}]\n");
                match &source.location {
                    SourceLocation::Url(value) => {
                        fragment.push_str(&format!("url = {}\n", toml_string(value)));
                    }
                    SourceLocation::Path(value) => {
                        fragment.push_str(&format!("path = {}\n", toml_string(value)));
                    }
                }
                if let Some(reference) = &source.reference {
                    fragment.push_str(&format!("ref = {}\n", toml_string(reference)));
                }
                if source.live {
                    fragment.push_str("live = true\n");
                }
                append_fragment(&mut after, &fragment);
            }
            ManifestMutation::RemoveSource { alias } => {
                if expected_skills
                    .values()
                    .any(|request| request.source == alias)
                    || expected_packs
                        .values()
                        .any(|request| request.source == alias)
                {
                    return Err(CoreError::Manifest(format!(
                        "source `{alias}` is still referenced"
                    )));
                }
                if expected_sources.remove(&alias).is_none() {
                    return Err(CoreError::Manifest(format!(
                        "source `{alias}` does not exist"
                    )));
                }
                remove_ranges(&mut after, self.entry_ranges("sources", alias.as_str())?);
            }
            ManifestMutation::InstallSkill { name, request } => {
                if !expected_sources.contains_key(&request.source) {
                    return Err(CoreError::Manifest(format!(
                        "skill `{name}` references unknown source `{}`",
                        request.source
                    )));
                }
                if expected_skills
                    .insert(name.clone(), request.clone())
                    .is_some()
                {
                    return Err(CoreError::Manifest(format!(
                        "skill `{name}` is already requested"
                    )));
                }
                insert_table_entry(
                    &mut after,
                    &self.document,
                    "skills",
                    &format!("{name} = {}\n", render_skill(&request)),
                )?;
            }
            ManifestMutation::UninstallSkill { name } => {
                if expected_skills.remove(&name).is_none() {
                    return Err(CoreError::Manifest(format!(
                        "skill `{name}` is not requested"
                    )));
                }
                remove_ranges(&mut after, self.entry_ranges("skills", name.as_str())?);
            }
            ManifestMutation::ReplaceSkillMode { name, mode } => {
                let request = expected_skills.get_mut(&name).ok_or_else(|| {
                    CoreError::Manifest(format!("skill `{name}` is not requested"))
                })?;
                if request.mode == mode {
                    return Err(CoreError::Manifest(format!(
                        "skill `{name}` projection mode is unchanged"
                    )));
                }
                request.mode = mode;
                let item = nested_item(&self.document, "skills", name.as_str())?;
                let span = item.span().ok_or_else(|| {
                    CoreError::Manifest(format!("skill `{name}` has no editable source span"))
                })?;
                after.splice(span, render_skill(request).bytes());
            }
            ManifestMutation::InstallPack { name, request } => {
                if !expected_sources.contains_key(&request.source) {
                    return Err(CoreError::Manifest(format!(
                        "pack `{name}` references unknown source `{}`",
                        request.source
                    )));
                }
                if expected_packs
                    .insert(name.clone(), request.clone())
                    .is_some()
                {
                    return Err(CoreError::Manifest(format!(
                        "pack `{name}` is already requested"
                    )));
                }
                insert_table_entry(
                    &mut after,
                    &self.document,
                    "packs",
                    &format!("{name} = {}\n", render_pack(&request)),
                )?;
            }
            ManifestMutation::UninstallPack { name } => {
                if expected_packs.remove(&name).is_none() {
                    return Err(CoreError::Manifest(format!(
                        "pack `{name}` is not requested"
                    )));
                }
                remove_ranges(&mut after, self.entry_ranges("packs", name.as_str())?);
            }
            ManifestMutation::ReplacePackExclusions { name, exclude } => {
                let request = expected_packs.get_mut(&name).ok_or_else(|| {
                    CoreError::Manifest(format!("pack `{name}` is not requested"))
                })?;
                if request.exclude == exclude {
                    return Err(CoreError::Manifest(format!(
                        "pack `{name}` exclusions are unchanged"
                    )));
                }
                request.exclude = exclude;
                let item = nested_item(&self.document, "packs", name.as_str())?;
                let span = item.span().ok_or_else(|| {
                    CoreError::Manifest(format!("pack `{name}` has no editable source span"))
                })?;
                after.splice(span, render_pack(request).bytes());
            }
            ManifestMutation::ReplacePackMode { name, mode } => {
                let request = expected_packs.get_mut(&name).ok_or_else(|| {
                    CoreError::Manifest(format!("pack `{name}` is not requested"))
                })?;
                if request.mode == mode {
                    return Err(CoreError::Manifest(format!(
                        "pack `{name}` projection mode is unchanged"
                    )));
                }
                request.mode = mode;
                let item = nested_item(&self.document, "packs", name.as_str())?;
                let span = item.span().ok_or_else(|| {
                    CoreError::Manifest(format!("pack `{name}` has no editable source span"))
                })?;
                after.splice(span, render_pack(request).bytes());
            }
        }

        let manifest = Self::parse(after.clone())?;
        if manifest.sources != expected_sources
            || manifest.skills != expected_skills
            || manifest.packs != expected_packs
        {
            return Err(CoreError::Manifest(
                "targeted edit changed semantics outside its addressed key".into(),
            ));
        }
        Ok(ManifestEdit {
            before: self.original.clone(),
            after,
            manifest,
        })
    }

    pub(crate) fn replace_desired(&self, desired: &crate::DesiredState) -> Result<ManifestEdit> {
        let mut current = self.clone();

        for (name, request) in self.skills.iter().rev() {
            if desired
                .skills
                .get(name)
                .is_none_or(|desired| desired.source != request.source)
            {
                current = current
                    .mutate(ManifestMutation::UninstallSkill { name: name.clone() })?
                    .manifest;
            }
        }
        for (name, request) in self.packs.iter().rev() {
            if desired
                .packs
                .get(name)
                .is_none_or(|desired| desired.source != request.source)
            {
                current = current
                    .mutate(ManifestMutation::UninstallPack { name: name.clone() })?
                    .manifest;
            }
        }
        for (name, request) in &desired.packs {
            match current.packs.get(name) {
                None => {
                    current = current
                        .mutate(ManifestMutation::InstallPack {
                            name: name.clone(),
                            request: request.clone(),
                        })?
                        .manifest;
                }
                Some(existing) => {
                    if existing.mode != request.mode {
                        current = current
                            .mutate(ManifestMutation::ReplacePackMode {
                                name: name.clone(),
                                mode: request.mode,
                            })?
                            .manifest;
                    }
                    if current.packs[name].exclude != request.exclude {
                        current = current
                            .mutate(ManifestMutation::ReplacePackExclusions {
                                name: name.clone(),
                                exclude: request.exclude.clone(),
                            })?
                            .manifest;
                    }
                }
            }
        }
        for (name, request) in &desired.skills {
            match current.skills.get(name) {
                None => {
                    current = current
                        .mutate(ManifestMutation::InstallSkill {
                            name: name.clone(),
                            request: request.clone(),
                        })?
                        .manifest;
                }
                Some(existing) if existing.mode != request.mode => {
                    current = current
                        .mutate(ManifestMutation::ReplaceSkillMode {
                            name: name.clone(),
                            mode: request.mode,
                        })?
                        .manifest;
                }
                Some(_) => {}
            }
        }

        Ok(ManifestEdit {
            before: self.original.clone(),
            after: current.original.clone(),
            manifest: current,
        })
    }

    fn entry_ranges(&self, table_name: &str, key: &str) -> Result<Vec<Range<usize>>> {
        let table = self
            .document
            .get(table_name)
            .and_then(Item::as_table_like)
            .ok_or_else(|| CoreError::Manifest(format!("{table_name} table is absent")))?;
        let (key_token, item) = table
            .get_key_value(key)
            .ok_or_else(|| CoreError::Manifest(format!("{table_name} entry `{key}` is absent")))?;
        if let Some(table) = item.as_table() {
            if !table.is_implicit() && !table.is_dotted() {
                let key_span = key_token.span().ok_or_else(|| {
                    CoreError::Manifest(format!("{table_name} entry `{key}` has no key span"))
                })?;
                let mut leaves = Vec::new();
                collect_leaf_ranges(&self.original, item, &mut leaves);
                let body_end = leaves.iter().map(|range| range.end).max().ok_or_else(|| {
                    CoreError::Manifest(format!("{table_name} entry `{key}` has no value spans"))
                })?;
                let header_start = line_range(&self.original, key_span).start;
                return Ok(std::iter::once(header_start..body_end).collect());
            }
            let mut ranges = Vec::new();
            collect_leaf_ranges(&self.original, item, &mut ranges);
            if ranges.is_empty() {
                return Err(CoreError::Manifest(format!(
                    "{table_name} entry `{key}` has no editable spans"
                )));
            }
            return Ok(ranges);
        }
        let span = item.span().or_else(|| key_token.span()).ok_or_else(|| {
            CoreError::Manifest(format!("{table_name} entry `{key}` has no editable span"))
        })?;
        Ok(vec![line_range(&self.original, span)])
    }
}

fn nested_item<'a>(document: &'a Document<String>, table: &str, key: &str) -> Result<&'a Item> {
    document
        .get(table)
        .and_then(Item::as_table_like)
        .and_then(|table| table.get(key))
        .ok_or_else(|| CoreError::Manifest(format!("{table} entry `{key}` is absent")))
}

fn collect_leaf_ranges(bytes: &[u8], item: &Item, ranges: &mut Vec<Range<usize>>) {
    if let Some(table) = item.as_table_like() {
        for (_, child) in table.iter() {
            collect_leaf_ranges(bytes, child, ranges);
        }
    } else if let Some(span) = item.span() {
        ranges.push(line_range(bytes, span));
    }
}

fn line_range(bytes: &[u8], span: Range<usize>) -> Range<usize> {
    let start = bytes[..span.start]
        .iter()
        .rposition(|byte| *byte == b'\n')
        .map_or(0, |position| position + 1);
    let end = bytes[span.end..]
        .iter()
        .position(|byte| *byte == b'\n')
        .map_or(bytes.len(), |position| span.end + position + 1);
    start..end
}

fn remove_ranges(bytes: &mut Vec<u8>, mut ranges: Vec<Range<usize>>) {
    ranges.sort_by_key(|range| range.start);
    for range in ranges.into_iter().rev() {
        bytes.drain(range);
    }
}

fn insert_table_entry(
    bytes: &mut Vec<u8>,
    document: &Document<String>,
    table_name: &str,
    line: &str,
) -> Result<()> {
    match document.get(table_name) {
        None => append_fragment(bytes, &format!("[{table_name}]\n{line}")),
        Some(item) => {
            let table = item.as_table().ok_or_else(|| {
                CoreError::Manifest(format!(
                    "{table_name} must be an explicit table for targeted insertion"
                ))
            })?;
            if table.is_implicit() || table.is_dotted() {
                append_fragment(bytes, &format!("{table_name}.{line}"));
            } else {
                let span = table.span().ok_or_else(|| {
                    CoreError::Manifest(format!("{table_name} table has no editable span"))
                })?;
                let insertion = line_range(bytes, span).end;
                bytes.splice(insertion..insertion, line.bytes());
            }
        }
    }
    Ok(())
}

fn append_fragment(bytes: &mut Vec<u8>, fragment: &str) {
    if !bytes.is_empty() && !bytes.ends_with(b"\n") {
        bytes.push(b'\n');
    }
    if !bytes.is_empty() && !bytes.ends_with(b"\n\n") {
        bytes.push(b'\n');
    }
    bytes.extend_from_slice(fragment.as_bytes());
}

fn toml_string(value: &str) -> String {
    Value::from(value).to_string()
}

fn render_pack(request: &ManifestPack) -> String {
    let mut value = format!("{{ source = {}", toml_string(request.source.as_str()));
    if request.mode == ProjectionMode::Vendor {
        value.push_str(", mode = \"vendor\"");
    }
    if !request.exclude.is_empty() {
        value.push_str(", exclude = [");
        for (index, name) in request.exclude.iter().enumerate() {
            if index > 0 {
                value.push_str(", ");
            }
            value.push_str(&toml_string(name.as_str()));
        }
        value.push(']');
    }
    value.push_str(" }");
    value
}

fn render_skill(request: &ManifestSkill) -> String {
    let mut value = format!("{{ source = {}", toml_string(request.source.as_str()));
    if request.mode == ProjectionMode::Vendor {
        value.push_str(", mode = \"vendor\"");
    }
    value.push_str(" }");
    value
}

fn projection_mode(value: Option<&Value>, where_: &str) -> Result<ProjectionMode> {
    match value.and_then(Value::as_str) {
        None => Ok(ProjectionMode::Link),
        Some("link") => Ok(ProjectionMode::Link),
        Some("vendor") => Ok(ProjectionMode::Vendor),
        Some(value) => Err(CoreError::Manifest(format!(
            "{where_} has unknown projection mode `{value}`"
        ))),
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
