use std::collections::{BTreeMap, BTreeSet};
use std::io::Read;

use super::digest::{inventory_bytes, review_tree_bytes, sha256, skill_content_bytes};
use super::yaml::{self, Value, YamlFailure};
use super::{
    Boundary, FileFact, Finding, InventoryError, Pack, ReviewedEntry, ReviewedPayload, Severity,
    Skill, SourceInventory, SourcePath, SubmoduleFact, SymlinkFact, SymlinkSafety, TreeEntry,
    TreeEntryKind, TreeReader,
};

pub fn scan(reader: &dyn TreeReader) -> Result<SourceInventory, InventoryError> {
    let mut entries = reader.entries()?;
    entries.sort_by(|left, right| left.path.cmp(&right.path));

    let mut findings = Vec::new();
    let mut skill_roots: Vec<(SourcePath, String)> = Vec::new();
    for entry in &entries {
        if entry.kind != TreeEntryKind::File || entry.path.file_name() != b"SKILL.md" {
            continue;
        }
        let root = entry.path.parent().unwrap_or_else(|| SourcePath::from(""));
        if skill_roots
            .iter()
            .any(|(parent, _)| root.is_descendant_of(parent))
        {
            continue;
        }
        let bytes = read_file(reader, &entry.path)?;
        match parse_skill_name(&bytes) {
            Ok(name) => skill_roots.push((root, name)),
            Err(failure) => findings.push(finding(entry.path.clone(), failure)),
        }
    }
    skill_roots.sort_by(|left, right| left.0.cmp(&right.0));

    let mut skills = Vec::new();
    let mut reviewed_entries = Vec::new();
    for (root, name) in &skill_roots {
        skills.push(scan_skill(
            reader,
            &entries,
            root,
            name,
            &mut reviewed_entries,
        )?);
    }
    skills.sort_by(|left, right| (&left.name, &left.path).cmp(&(&right.name, &right.path)));

    let mut packs = Vec::new();
    for entry in &entries {
        if entry.kind != TreeEntryKind::File || entry.path.file_name() != b"PACK.md" {
            continue;
        }
        if skill_roots
            .iter()
            .any(|(root, _)| entry.path.is_descendant_of(root))
        {
            continue;
        }
        let bytes = read_file(reader, &entry.path)?;
        match parse_pack(&bytes, entry.path.clone()) {
            Ok(pack) => packs.push(pack),
            Err(failure) => findings.push(finding(entry.path.clone(), failure)),
        }
    }
    packs.sort_by(|left, right| (&left.name, &left.path).cmp(&(&right.name, &right.path)));

    let reviewed_paths: BTreeSet<_> = reviewed_entries
        .iter()
        .map(|entry| entry.path.clone())
        .collect();
    for entry in &entries {
        if entry.kind == TreeEntryKind::Directory || reviewed_paths.contains(&entry.path) {
            continue;
        }
        reviewed_entries.push(reviewed_entry(reader, entry, Boundary::Snapshot)?);
    }
    reviewed_entries.sort_by(|left, right| left.path.cmp(&right.path));
    findings.sort_by(finding_order);

    let inventory_digest = sha256(&inventory_bytes(&skills, &packs, &findings));
    let review_tree_digest = sha256(&review_tree_bytes(&reviewed_entries));
    Ok(SourceInventory {
        skills,
        packs,
        findings,
        reviewed_entries,
        inventory_digest,
        review_tree_digest,
    })
}

fn read_file(reader: &dyn TreeReader, path: &SourcePath) -> Result<Vec<u8>, InventoryError> {
    let mut bytes = Vec::new();
    reader
        .open(path)?
        .read_to_end(&mut bytes)
        .map_err(|error| InventoryError::Tree {
            path: path.clone(),
            message: error.to_string(),
        })?;
    Ok(bytes)
}

fn finding(path: SourcePath, failure: YamlFailure) -> Finding {
    Finding {
        code: failure.code.into(),
        path: Some(path),
        severity: Severity::Error,
        details: failure
            .details
            .into_iter()
            .map(|(key, value)| (key.into(), value))
            .collect(),
        message: failure.code.replace('-', " "),
    }
}

fn finding_order(left: &Finding, right: &Finding) -> std::cmp::Ordering {
    (
        left.code.as_bytes(),
        left.path.as_ref(),
        left.severity,
        &left.details,
    )
        .cmp(&(
            right.code.as_bytes(),
            right.path.as_ref(),
            right.severity,
            &right.details,
        ))
}

fn parse_skill_name(bytes: &[u8]) -> Result<String, YamlFailure> {
    let Value::Mapping(fields) = yaml::frontmatter(bytes)? else {
        return Err(YamlFailure {
            code: "frontmatter-root-type",
            details: vec![("actual", "non-mapping".into())],
        });
    };
    let Some((_, value)) = fields.iter().find(|(key, _)| key == "name") else {
        return Err(YamlFailure {
            code: "skill-name-missing",
            details: Vec::new(),
        });
    };
    let Value::String(name) = value else {
        return Err(YamlFailure {
            code: "skill-name-type",
            details: vec![("actual", value.kind().into())],
        });
    };
    if !valid_slug(name) {
        return Err(YamlFailure {
            code: "skill-name-invalid",
            details: vec![("value", name.clone())],
        });
    }
    Ok(name.clone())
}

fn parse_pack(bytes: &[u8], path: SourcePath) -> Result<Pack, YamlFailure> {
    let Value::Mapping(fields) = yaml::frontmatter(bytes)? else {
        return Err(YamlFailure {
            code: "frontmatter-root-type",
            details: vec![("actual", "non-mapping".into())],
        });
    };
    let map: BTreeMap<_, _> = fields.into_iter().collect();
    let scalar = |field: &'static str| -> Result<String, YamlFailure> {
        match map.get(field) {
            Some(Value::String(value)) => Ok(value.clone()),
            Some(value) => Err(YamlFailure {
                code: "pack-field-type",
                details: vec![
                    ("field", field.into()),
                    ("expected", "string".into()),
                    ("actual", value.kind().into()),
                ],
            }),
            None => Err(YamlFailure {
                code: "pack-field-missing",
                details: vec![("field", field.into())],
            }),
        }
    };
    let sequence = |field: &'static str| -> Result<Vec<String>, YamlFailure> {
        match map.get(field) {
            Some(Value::Sequence(values)) => values
                .iter()
                .enumerate()
                .map(|(index, value)| match value {
                    Value::String(value) => Ok(value.clone()),
                    value => Err(YamlFailure {
                        code: "pack-member-type",
                        details: vec![
                            ("field", field.into()),
                            ("index", index.to_string()),
                            ("actual", value.kind().into()),
                        ],
                    }),
                })
                .collect(),
            Some(value) => Err(YamlFailure {
                code: "pack-field-type",
                details: vec![
                    ("field", field.into()),
                    ("expected", "sequence".into()),
                    ("actual", value.kind().into()),
                ],
            }),
            None => Err(YamlFailure {
                code: "pack-field-missing",
                details: vec![("field", field.into())],
            }),
        }
    };
    let schema = scalar("schema")?;
    if schema != "grimoire/pack@1" {
        return Err(YamlFailure {
            code: "pack-schema-invalid",
            details: vec![("value", schema)],
        });
    }
    let name = scalar("name")?;
    let description = scalar("description")?;
    let required = sequence("required")?;
    let optional = sequence("optional")?;
    Ok(Pack {
        name,
        path,
        digest: sha256(bytes),
        description,
        required,
        optional,
        missing_required: Vec::new(),
        missing_optional: Vec::new(),
    })
}

fn scan_skill(
    reader: &dyn TreeReader,
    entries: &[TreeEntry],
    root: &SourcePath,
    name: &str,
    reviewed: &mut Vec<ReviewedEntry>,
) -> Result<Skill, InventoryError> {
    let mut files = Vec::new();
    let mut symlinks = Vec::new();
    let mut submodules = Vec::new();
    let mut digest_records: Vec<(u8, Vec<u8>, Vec<u8>, Vec<u8>)> = Vec::new();
    for entry in entries
        .iter()
        .filter(|entry| entry.path.is_descendant_of(root))
    {
        let relative = entry.path.strip_prefix(root).expect("filtered descendant");
        match entry.kind {
            TreeEntryKind::Directory => {}
            TreeEntryKind::File => {
                let bytes = read_file(reader, &entry.path)?;
                let mode = normalized_file_mode(entry.mode).to_owned();
                let digest = sha256(&bytes);
                digest_records.push((
                    b'F',
                    relative.as_bytes().to_vec(),
                    mode.as_bytes().to_vec(),
                    bytes.clone(),
                ));
                let shebang = bytes.starts_with(b"#!").then(|| {
                    bytes[..bytes
                        .iter()
                        .position(|byte| *byte == b'\n')
                        .unwrap_or(bytes.len())
                        .min(512)]
                        .to_vec()
                });
                files.push(FileFact {
                    path: relative,
                    size: bytes.len() as u64,
                    mode: mode.clone(),
                    digest,
                    binary: bytes.iter().take(8 * 1024).any(|byte| *byte == 0),
                    executable: mode == "100755",
                    shebang,
                });
                reviewed.push(ReviewedEntry {
                    path: entry.path.clone(),
                    mode,
                    payload: ReviewedPayload::File {
                        size: bytes.len() as u64,
                        digest,
                    },
                    boundary: Boundary::Skill(root.clone()),
                    safety: None,
                    reason: None,
                });
            }
            TreeEntryKind::Symlink => {
                let target = entry.link_target.clone().unwrap_or_default();
                let (safety, reason) = classify_link(root, &entry.path, &target);
                digest_records.push((
                    b'L',
                    relative.as_bytes().to_vec(),
                    b"120000".to_vec(),
                    target.clone(),
                ));
                symlinks.push(SymlinkFact {
                    path: relative,
                    target: target.clone(),
                    mode: "120000".into(),
                    safety,
                    reason: reason.clone(),
                });
                reviewed.push(ReviewedEntry {
                    path: entry.path.clone(),
                    mode: "120000".into(),
                    payload: ReviewedPayload::Symlink { target },
                    boundary: Boundary::Skill(root.clone()),
                    safety: Some(safety),
                    reason,
                });
            }
            TreeEntryKind::Submodule => {
                let commit = entry.submodule_commit.clone().unwrap_or_default();
                submodules.push(SubmoduleFact {
                    path: relative,
                    commit: commit.clone(),
                });
                reviewed.push(ReviewedEntry {
                    path: entry.path.clone(),
                    mode: "160000".into(),
                    payload: ReviewedPayload::Submodule { commit },
                    boundary: Boundary::Skill(root.clone()),
                    safety: None,
                    reason: None,
                });
            }
            TreeEntryKind::Device | TreeEntryKind::Fifo | TreeEntryKind::Socket => {}
        }
    }
    digest_records.sort_by(|left, right| left.1.cmp(&right.1));
    let refs: Vec<_> = digest_records
        .iter()
        .map(|(kind, path, mode, payload)| {
            (*kind, path.as_slice(), mode.as_slice(), payload.as_slice())
        })
        .collect();
    files.sort_by(|left, right| left.path.cmp(&right.path));
    symlinks.sort_by(|left, right| left.path.cmp(&right.path));
    submodules.sort_by(|left, right| left.path.cmp(&right.path));
    Ok(Skill {
        name: name.into(),
        path: root.clone(),
        content_digest: sha256(&skill_content_bytes(&refs)),
        files,
        symlinks,
        submodules,
    })
}

fn reviewed_entry(
    reader: &dyn TreeReader,
    entry: &TreeEntry,
    boundary: Boundary,
) -> Result<ReviewedEntry, InventoryError> {
    match entry.kind {
        TreeEntryKind::File => {
            let bytes = read_file(reader, &entry.path)?;
            Ok(ReviewedEntry {
                path: entry.path.clone(),
                mode: normalized_file_mode(entry.mode).into(),
                payload: ReviewedPayload::File {
                    size: bytes.len() as u64,
                    digest: sha256(&bytes),
                },
                boundary,
                safety: None,
                reason: None,
            })
        }
        TreeEntryKind::Symlink => {
            let target = entry.link_target.clone().unwrap_or_default();
            let (safety, reason) = classify_link(&SourcePath::from(""), &entry.path, &target);
            Ok(ReviewedEntry {
                path: entry.path.clone(),
                mode: "120000".into(),
                payload: ReviewedPayload::Symlink { target },
                boundary,
                safety: Some(safety),
                reason,
            })
        }
        TreeEntryKind::Submodule => Ok(ReviewedEntry {
            path: entry.path.clone(),
            mode: "160000".into(),
            payload: ReviewedPayload::Submodule {
                commit: entry.submodule_commit.clone().unwrap_or_default(),
            },
            boundary,
            safety: None,
            reason: None,
        }),
        _ => unreachable!("only non-directories with review payload reach this helper"),
    }
}

fn normalized_file_mode(mode: u32) -> &'static str {
    if mode & 0o111 == 0 {
        "100644"
    } else {
        "100755"
    }
}

fn classify_link(
    boundary: &SourcePath,
    link_path: &SourcePath,
    target: &[u8],
) -> (SymlinkSafety, Option<String>) {
    if target.is_empty() {
        return (SymlinkSafety::Invalid, Some("empty".into()));
    }
    if target.contains(&0) {
        return (SymlinkSafety::Invalid, Some("nul".into()));
    }
    if target.starts_with(b"/") {
        return (SymlinkSafety::Escaping, None);
    }
    let mut components: Vec<Vec<u8>> = link_path
        .parent()
        .map(|path| {
            path.as_bytes()
                .split(|byte| *byte == b'/')
                .map(<[u8]>::to_vec)
                .collect()
        })
        .unwrap_or_default();
    for component in target.split(|byte| *byte == b'/') {
        match component {
            b"" | b"." => {}
            b".." => {
                components.pop();
            }
            value => components.push(value.to_vec()),
        }
    }
    let mut resolved = Vec::new();
    for (index, component) in components.iter().enumerate() {
        if index != 0 {
            resolved.push(b'/');
        }
        resolved.extend_from_slice(component);
    }
    let resolved = SourcePath::new(resolved);
    if boundary.as_bytes().is_empty()
        || resolved == *boundary
        || resolved.is_descendant_of(boundary)
    {
        (SymlinkSafety::Internal, None)
    } else {
        (SymlinkSafety::Escaping, None)
    }
}

fn valid_slug(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 64
        && value.bytes().enumerate().all(|(index, byte)| {
            byte.is_ascii_lowercase()
                || byte.is_ascii_digit()
                || (byte == b'-' && index != 0 && index + 1 != value.len())
        })
        && !value.as_bytes().windows(2).any(|pair| pair == b"--")
}

impl Value {
    fn kind(&self) -> &'static str {
        match self {
            Self::Null => "null",
            Self::Boolean => "boolean",
            Self::Number(_) => "number",
            Self::String(_) => "string",
            Self::Sequence(_) => "sequence",
            Self::Mapping(_) => "mapping",
        }
    }
}
