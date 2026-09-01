use std::collections::{BTreeMap, BTreeSet};
use std::io::Read;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;

use super::digest::{inventory_bytes, review_tree_bytes, sha256, skill_content_bytes};
use super::tree::EntryValidator;
use super::yaml::{self, Value, YamlFailure};
use super::{
    Boundary, FileFact, Finding, InventoryError, Pack, ReviewedEntry, ReviewedPayload, Severity,
    Skill, SourceInventory, SourcePath, SubmoduleFact, SymlinkFact, SymlinkSafety, TreeEntry,
    TreeEntryKind, TreeReader,
};

const IGNORED_DIRECTORIES: &[&[u8]] = &[
    b".git",
    b".hg",
    b".svn",
    b".grimoire",
    b"node_modules",
    b"target",
    b".cache",
    b".tmp",
    b".worktrees",
    b".workstreams",
    b"build",
    b"dist",
    b"vendor",
    b"fixtures",
];

type OwnedContentRecord = (u8, Vec<u8>, Vec<u8>, Vec<u8>);

pub fn scan(reader: &dyn TreeReader) -> Result<SourceInventory, InventoryError> {
    let mut entries = reader.entries()?;
    entries.sort_by(|left, right| left.path.cmp(&right.path));

    let mut findings = Vec::new();
    if entries.len() > 100_000 {
        findings.push(limit_finding(
            "discovery-entry-limit",
            Some(entries[100_000].path.clone()),
            100_000,
            100_001,
        ));
    }
    if let Some(entry) = entries.iter().find(|entry| directory_depth(entry) > 32) {
        findings.push(limit_finding(
            "discovery-depth-limit",
            Some(entry.path.clone()),
            32,
            33,
        ));
    }
    let nested_checkouts: Vec<_> = entries
        .iter()
        .filter(|entry| entry.path.file_name() == b".git")
        .filter_map(|entry| entry.path.parent())
        .filter(|path| !path.as_bytes().is_empty())
        .collect();
    let symlink_paths: Vec<_> = entries
        .iter()
        .filter(|entry| entry.kind == TreeEntryKind::Symlink)
        .map(|entry| entry.path.clone())
        .collect();

    let mut skill_roots: Vec<(SourcePath, String)> = Vec::new();
    let mut skill_manifests: Vec<_> = entries
        .iter()
        .filter(|entry| {
            entry.kind == TreeEntryKind::File
                && entry.path.file_name() == b"SKILL.md"
                && outer_visible(entry, &nested_checkouts, &symlink_paths)
                && path_is_usable(entry)
                && directory_depth(entry) <= 32
        })
        .collect();
    skill_manifests.sort_by(|left, right| {
        directory_depth(left)
            .cmp(&directory_depth(right))
            .then_with(|| left.path.cmp(&right.path))
    });
    for entry in skill_manifests {
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

    let mut validator = EntryValidator::new();
    for entry in &entries {
        let inside_skill = skill_roots
            .iter()
            .any(|(root, _)| entry.path == *root || entry.path.is_descendant_of(root));
        if inside_skill || outer_visible(entry, &nested_checkouts, &symlink_paths) {
            findings.extend(validator.validate(entry));
        }
        if entry.kind == TreeEntryKind::Submodule && inside_skill {
            findings.push(Finding {
                code: "unsupported-entry".into(),
                path: Some(entry.path.clone()),
                severity: Severity::Error,
                details: BTreeMap::from([("kind".into(), "submodule".into())]),
                message: "unsupported entry".into(),
            });
        }
    }
    add_review_byte_limit(
        &entries,
        &skill_roots,
        &nested_checkouts,
        &symlink_paths,
        &mut findings,
    );

    let mut skills = Vec::new();
    let mut reviewed_entries = Vec::new();
    for (root, name) in &skill_roots {
        skills.push(scan_skill(
            reader,
            &entries,
            root,
            name,
            &symlink_paths,
            &mut reviewed_entries,
        )?);
    }
    skills.sort_by(|left, right| (&left.name, &left.path).cmp(&(&right.name, &right.path)));

    let mut packs = Vec::new();
    for entry in &entries {
        if entry.kind != TreeEntryKind::File || entry.path.file_name() != b"PACK.md" {
            continue;
        }
        if !outer_visible(entry, &nested_checkouts, &symlink_paths)
            || !path_is_usable(entry)
            || directory_depth(entry) > 32
        {
            continue;
        }
        if skill_roots
            .iter()
            .any(|(root, _)| entry.path.is_descendant_of(root))
        {
            continue;
        }
        let bytes = read_file(reader, &entry.path)?;
        let (pack, failures) = parse_pack(&bytes, entry.path.clone());
        findings.extend(
            failures
                .into_iter()
                .map(|failure| finding(entry.path.clone(), failure)),
        );
        if let Some(pack) = pack {
            packs.push(pack);
        }
    }
    packs.sort_by(|left, right| (&left.name, &left.path).cmp(&(&right.name, &right.path)));

    let reviewed_paths: BTreeSet<_> = reviewed_entries
        .iter()
        .map(|entry| entry.path.clone())
        .collect();
    for entry in &entries {
        if entry.kind == TreeEntryKind::Directory
            || reviewed_paths.contains(&entry.path)
            || !outer_visible(entry, &nested_checkouts, &symlink_paths)
            || matches!(
                entry.kind,
                TreeEntryKind::Device | TreeEntryKind::Fifo | TreeEntryKind::Socket
            )
        {
            continue;
        }
        reviewed_entries.push(reviewed_entry(reader, entry, Boundary::Snapshot)?);
    }
    reviewed_entries.sort_by(|left, right| left.path.cmp(&right.path));
    add_review_findings(&reviewed_entries, &mut findings);
    add_duplicate_findings(&skills, &packs, &mut findings);
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

fn add_review_byte_limit(
    entries: &[TreeEntry],
    skill_roots: &[(SourcePath, String)],
    nested_checkouts: &[SourcePath],
    symlink_paths: &[SourcePath],
    findings: &mut Vec<Finding>,
) {
    let mut total = 0u64;
    for entry in entries {
        if entry.kind != TreeEntryKind::File {
            continue;
        }
        let inside_skill = skill_roots
            .iter()
            .any(|(root, _)| entry.path.is_descendant_of(root));
        let below_link = symlink_paths
            .iter()
            .any(|link| entry.path != *link && entry.path.is_descendant_of(link));
        if below_link || (!inside_skill && !outer_visible(entry, nested_checkouts, symlink_paths)) {
            continue;
        }
        total = total.saturating_add(entry.size.unwrap_or(0));
        if total > 1_073_741_824 {
            findings.push(limit_finding(
                "review-byte-limit",
                Some(entry.path.clone()),
                1_073_741_824,
                1_073_741_825,
            ));
            break;
        }
    }
}

fn add_review_findings(entries: &[ReviewedEntry], findings: &mut Vec<Finding>) {
    for entry in entries {
        let ReviewedPayload::Symlink { target } = &entry.payload else {
            continue;
        };
        match entry.safety {
            Some(SymlinkSafety::Escaping) => findings.push(Finding {
                code: "escaping-symlink".into(),
                path: Some(entry.path.clone()),
                severity: Severity::Error,
                details: BTreeMap::from([("target_bytes_base64".into(), BASE64.encode(target))]),
                message: "symlink target escapes its owning boundary".into(),
            }),
            Some(SymlinkSafety::Invalid) => findings.push(Finding {
                code: "invalid-symlink-target".into(),
                path: Some(entry.path.clone()),
                severity: Severity::Error,
                details: BTreeMap::from([
                    (
                        "reason".into(),
                        entry.reason.clone().expect("invalid link has a reason"),
                    ),
                    ("target_bytes_base64".into(), BASE64.encode(target)),
                ]),
                message: "invalid symlink target".into(),
            }),
            _ => {}
        }
    }
}

fn path_is_usable(entry: &TreeEntry) -> bool {
    let bytes = entry.path.as_bytes();
    !bytes.starts_with(b"/")
        && !bytes.contains(&0)
        && std::str::from_utf8(bytes).is_ok()
        && !bytes
            .split(|byte| *byte == b'/')
            .any(|component| component.is_empty() || matches!(component, b"." | b".."))
        && !matches!(
            entry.kind,
            TreeEntryKind::Device | TreeEntryKind::Fifo | TreeEntryKind::Socket
        )
}

fn directory_depth(entry: &TreeEntry) -> usize {
    let count = entry.path.as_bytes().split(|byte| *byte == b'/').count();
    count.saturating_sub(usize::from(entry.kind != TreeEntryKind::Directory))
}

fn outer_visible(
    entry: &TreeEntry,
    nested_checkouts: &[SourcePath],
    symlinks: &[SourcePath],
) -> bool {
    let components: Vec<_> = entry.path.as_bytes().split(|byte| *byte == b'/').collect();
    if components
        .iter()
        .any(|component| IGNORED_DIRECTORIES.contains(component))
    {
        return false;
    }
    !nested_checkouts
        .iter()
        .chain(symlinks)
        .any(|boundary| entry.path == *boundary || entry.path.is_descendant_of(boundary))
}

fn limit_finding(code: &str, path: Option<SourcePath>, limit: usize, observed: usize) -> Finding {
    Finding {
        code: code.into(),
        path,
        severity: Severity::Error,
        details: BTreeMap::from([
            ("limit".into(), limit.to_string()),
            ("observed".into(), observed.to_string()),
        ]),
        message: code.replace('-', " "),
    }
}

fn add_duplicate_findings(skills: &[Skill], packs: &[Pack], findings: &mut Vec<Finding>) {
    let mut skill_names: BTreeMap<&str, &SourcePath> = BTreeMap::new();
    for skill in skills {
        if let Some(first) = skill_names.get(skill.name.as_str()) {
            findings.push(Finding {
                code: "duplicate-skill".into(),
                path: Some(skill.path.clone()),
                severity: Severity::Error,
                details: BTreeMap::from([
                    ("name".into(), skill.name.clone()),
                    ("other_path".into(), first.to_string()),
                ]),
                message: "duplicate skill".into(),
            });
        } else {
            skill_names.insert(&skill.name, &skill.path);
        }
    }
    let mut pack_names: BTreeMap<&str, &SourcePath> = BTreeMap::new();
    for pack in packs {
        if let Some(first) = pack_names.get(pack.name.as_str()) {
            findings.push(Finding {
                code: "duplicate-pack".into(),
                path: Some(pack.path.clone()),
                severity: Severity::Error,
                details: BTreeMap::from([
                    ("name".into(), pack.name.clone()),
                    ("other_path".into(), first.to_string()),
                ]),
                message: "duplicate pack".into(),
            });
        } else {
            pack_names.insert(&pack.name, &pack.path);
        }
    }
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

pub(crate) fn parse_skill_name(bytes: &[u8]) -> Result<String, YamlFailure> {
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

pub(crate) fn parse_pack(bytes: &[u8], path: SourcePath) -> (Option<Pack>, Vec<YamlFailure>) {
    let fields = match yaml::frontmatter(bytes) {
        Ok(Value::Mapping(fields)) => fields,
        Ok(value) => {
            return (
                None,
                vec![YamlFailure {
                    code: "frontmatter-root-type",
                    details: vec![("actual", value.kind().into())],
                }],
            )
        }
        Err(failure) => return (None, vec![failure]),
    };
    let map: BTreeMap<_, _> = fields.into_iter().collect();
    let mut failures = Vec::new();
    for key in map.keys().filter(|key| {
        !matches!(
            key.as_str(),
            "schema" | "name" | "description" | "required" | "optional"
        )
    }) {
        failures.push(YamlFailure {
            code: "pack-unknown-key",
            details: vec![("key", key.clone())],
        });
    }
    let scalar = |field: &'static str, failures: &mut Vec<YamlFailure>| -> Option<String> {
        match map.get(field) {
            Some(Value::String(value)) => Some(value.clone()),
            Some(value) => {
                failures.push(YamlFailure {
                    code: "pack-field-type",
                    details: vec![
                        ("field", field.into()),
                        ("expected", "string".into()),
                        ("actual", value.kind().into()),
                    ],
                });
                None
            }
            None => {
                failures.push(YamlFailure {
                    code: "pack-field-missing",
                    details: vec![("field", field.into())],
                });
                None
            }
        }
    };
    let sequence = |field: &'static str, failures: &mut Vec<YamlFailure>| -> Option<Vec<String>> {
        match map.get(field) {
            Some(Value::Sequence(values)) => {
                let mut members = Vec::new();
                for (index, value) in values.iter().enumerate() {
                    if let Value::String(value) = value {
                        members.push(value.clone());
                    } else {
                        failures.push(YamlFailure {
                            code: "pack-member-type",
                            details: vec![
                                ("field", field.into()),
                                ("index", index.to_string()),
                                ("actual", value.kind().into()),
                            ],
                        });
                    }
                }
                Some(members)
            }
            Some(value) => {
                failures.push(YamlFailure {
                    code: "pack-field-type",
                    details: vec![
                        ("field", field.into()),
                        ("expected", "sequence".into()),
                        ("actual", value.kind().into()),
                    ],
                });
                None
            }
            None => {
                failures.push(YamlFailure {
                    code: "pack-field-missing",
                    details: vec![("field", field.into())],
                });
                None
            }
        }
    };
    let schema = scalar("schema", &mut failures);
    if schema
        .as_deref()
        .is_some_and(|value| value != "grimoire/pack@1")
    {
        failures.push(YamlFailure {
            code: "pack-schema-invalid",
            details: vec![("value", schema.clone().unwrap())],
        });
    }
    let name = scalar("name", &mut failures);
    if let Some(name) = &name {
        if !valid_slug(name) {
            failures.push(YamlFailure {
                code: "pack-name-invalid",
                details: vec![("value", name.clone())],
            });
        }
    }
    let description = scalar("description", &mut failures);
    if description.as_deref().is_some_and(str::is_empty) {
        failures.push(YamlFailure {
            code: "pack-description-empty",
            details: Vec::new(),
        });
    }
    let required = sequence("required", &mut failures);
    let optional = sequence("optional", &mut failures);
    for members in [required.as_ref(), optional.as_ref()].into_iter().flatten() {
        for member in members {
            if !valid_slug(member) {
                failures.push(YamlFailure {
                    code: "pack-member-invalid",
                    details: vec![("value", member.clone())],
                });
            }
        }
        let mut seen = BTreeSet::new();
        for member in members {
            if !seen.insert(member) {
                failures.push(YamlFailure {
                    code: "pack-member-duplicate",
                    details: vec![("member", member.clone())],
                });
            }
        }
    }
    if let (Some(required), Some(optional)) = (&required, &optional) {
        let required_set: BTreeSet<_> = required.iter().collect();
        for member in optional {
            if required_set.contains(member) {
                failures.push(YamlFailure {
                    code: "pack-member-overlap",
                    details: vec![("member", member.clone())],
                });
            }
        }
        if required.is_empty() && optional.is_empty() {
            failures.push(YamlFailure {
                code: "pack-empty",
                details: Vec::new(),
            });
        }
    }
    if !failures.is_empty() {
        return (None, failures);
    }
    (
        Some(Pack {
            name: name.unwrap(),
            path,
            digest: sha256(bytes),
            description: description.unwrap(),
            required: required.unwrap(),
            optional: optional.unwrap(),
            missing_required: Vec::new(),
            missing_optional: Vec::new(),
        }),
        Vec::new(),
    )
}

fn scan_skill(
    reader: &dyn TreeReader,
    entries: &[TreeEntry],
    root: &SourcePath,
    name: &str,
    symlink_paths: &[SourcePath],
    reviewed: &mut Vec<ReviewedEntry>,
) -> Result<Skill, InventoryError> {
    let mut files = Vec::new();
    let mut symlinks = Vec::new();
    let mut submodules = Vec::new();
    let mut digest_records: Vec<OwnedContentRecord> = Vec::new();
    for entry in entries
        .iter()
        .filter(|entry| entry.path.is_descendant_of(root))
        .filter(|entry| {
            !symlink_paths
                .iter()
                .any(|link| entry.path != *link && entry.path.is_descendant_of(link))
        })
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
    let boundary_depth = if boundary.as_bytes().is_empty() {
        0
    } else {
        boundary.as_bytes().split(|byte| *byte == b'/').count()
    };
    let mut escaped = false;
    for component in target.split(|byte| *byte == b'/') {
        match component {
            b"" | b"." => {}
            b".." => {
                if components.len() <= boundary_depth {
                    escaped = true;
                } else {
                    components.pop();
                }
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
    if !escaped
        && (boundary.as_bytes().is_empty()
            || resolved == *boundary
            || resolved.is_descendant_of(boundary))
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
