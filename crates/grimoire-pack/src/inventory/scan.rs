use std::collections::{BTreeMap, BTreeSet};

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use sha2::{Digest as _, Sha256};

use super::digest::{inventory_bytes, review_tree_bytes, sha256};
use super::tree::EntryValidator;
use super::yaml::{self, Value, YamlFailure};
use super::{
    Boundary, FileFact, Finding, InventoryError, Pack, ReviewedEntry, ReviewedPayload, Severity,
    Skill, SourceInventory, SourcePath, SubmoduleFact, SymlinkFact, SymlinkSafety, TreeEntry,
    TreeEntryKind, TreeReader, VisitDecision,
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
    b".streams",
    b"build",
    b"dist",
    b"vendor",
    b".agents",
    b"fixtures",
];
const FRONTMATTER_BYTE_LIMIT: usize = 65_536;
const REVIEW_BYTE_LIMIT: u64 = 128 * 1024 * 1024;
const DISCOVERY_ENTRY_LIMIT: usize = 100_000;

#[derive(Clone, Copy, PartialEq, Eq)]
enum ScanKind {
    Source,
    SkillTree,
}

pub fn scan(reader: &dyn TreeReader) -> Result<SourceInventory, InventoryError> {
    scan_inner(reader, ScanKind::Source)
}

fn scan_inner(reader: &dyn TreeReader, kind: ScanKind) -> Result<SourceInventory, InventoryError> {
    let mut skill_manifests = Vec::new();
    let mut nested_checkouts = Vec::new();
    let mut symlink_paths = Vec::new();
    let mut discovery_entries = 0_usize;
    reader.visit_entries(&mut |entry| {
        discovery_entries += 1;
        if entry.kind == TreeEntryKind::Symlink {
            symlink_paths.push(entry.path.clone());
        }
        if entry.path.file_name() == b".git" {
            if let Some(parent) = entry
                .path
                .parent()
                .filter(|path| !path.as_bytes().is_empty())
            {
                nested_checkouts.push(parent);
            }
        }
        if entry.kind == TreeEntryKind::File && entry.path.file_name() == b"SKILL.md" {
            skill_manifests.push(entry.clone());
        }
        Ok(if discovery_entries > DISCOVERY_ENTRY_LIMIT {
            VisitDecision::Stop
        } else if entry.kind == TreeEntryKind::Directory
            && IGNORED_DIRECTORIES.contains(&entry.path.file_name())
        {
            VisitDecision::SkipSubtree
        } else {
            VisitDecision::Continue
        })
    })?;
    nested_checkouts.sort();
    nested_checkouts.dedup();
    symlink_paths.sort();
    symlink_paths.dedup();

    let mut findings = Vec::new();
    let mut skill_roots: Vec<(SourcePath, String)> = Vec::new();
    skill_manifests.retain(|entry| {
        outer_visible(entry, &nested_checkouts, &symlink_paths)
            && path_is_usable(entry)
            && directory_depth(entry) <= 32
    });
    skill_manifests.sort_by(|left, right| {
        directory_depth(left)
            .cmp(&directory_depth(right))
            .then_with(|| left.path.cmp(&right.path))
    });
    for entry in &skill_manifests {
        let root = entry.path.parent().unwrap_or_else(|| SourcePath::from(""));
        if skill_roots
            .iter()
            .any(|(parent, _)| root.is_descendant_of(parent))
        {
            continue;
        }
        let bytes = read_frontmatter(reader, &entry.path)?;
        match parse_skill_name(&bytes) {
            Ok(name) => skill_roots.push((root, name)),
            Err(failure) => findings.push(finding(entry.path.clone(), failure)),
        }
    }
    skill_roots.sort_by(|left, right| left.0.cmp(&right.0));

    let mut entries = Vec::with_capacity(DISCOVERY_ENTRY_LIMIT + 1);
    reader.visit_entries(&mut |entry| {
        if kind == ScanKind::SkillTree {
            findings.extend(strict_skill_entry_findings(&entry));
        }
        let inside_skill = skill_roots
            .iter()
            .any(|(root, _)| entry.path == *root || entry.path.is_descendant_of(root));
        let behind_boundary = nested_checkouts
            .iter()
            .chain(symlink_paths.iter())
            .any(|boundary| entry.path != *boundary && entry.path.is_descendant_of(boundary));
        if behind_boundary || (!inside_skill && ignored_descendant(&entry.path)) {
            return Ok(if entry.kind == TreeEntryKind::Directory {
                VisitDecision::SkipSubtree
            } else {
                VisitDecision::Continue
            });
        }
        let skip = entry.kind == TreeEntryKind::Directory
            && !inside_skill
            && IGNORED_DIRECTORIES.contains(&entry.path.file_name());
        entries.push(entry);
        Ok(if entries.len() > DISCOVERY_ENTRY_LIMIT {
            VisitDecision::Stop
        } else if skip {
            VisitDecision::SkipSubtree
        } else {
            VisitDecision::Continue
        })
    })?;
    entries.sort_by(|left, right| left.path.cmp(&right.path));

    if entries.len() > DISCOVERY_ENTRY_LIMIT {
        findings.push(limit_finding(
            "discovery-entry-limit",
            Some(entries[DISCOVERY_ENTRY_LIMIT].path.clone()),
            DISCOVERY_ENTRY_LIMIT,
            DISCOVERY_ENTRY_LIMIT + 1,
        ));
        entries.truncate(DISCOVERY_ENTRY_LIMIT);
    }
    if let Some(entry) = entries.iter().find(|entry| directory_depth(entry) > 32) {
        findings.push(limit_finding(
            "discovery-depth-limit",
            Some(entry.path.clone()),
            32,
            33,
        ));
    }

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
    let mut skills = Vec::new();
    let mut reviewed_entries = Vec::new();
    let mut review_budget = ReviewBudget::new();
    for (root, name) in &skill_roots {
        let mut scan = SkillScan {
            reader,
            entries: &entries,
            symlink_paths: &symlink_paths,
            reviewed: &mut reviewed_entries,
            budget: &mut review_budget,
            findings: &mut findings,
        };
        skills.push(build_skill(&mut scan, root, name)?);
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
        let bytes = read_frontmatter(reader, &entry.path)?;
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
    add_pack_availability(&skills, &mut packs, &mut findings);

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
        if let Some(reviewed) = reviewed_entry(
            reader,
            entry,
            Boundary::Snapshot,
            &mut review_budget,
            &mut findings,
        )? {
            reviewed_entries.push(reviewed);
        }
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

/// Inventory one directory whose root is expected to be exactly one skill.
///
/// This reuses the source scanner's canonical content-digest framing while adding the stricter
/// entry-mode and root-identity checks required for a committed projection.
pub fn scan_skill_tree(
    reader: &dyn TreeReader,
    expected_name: &str,
) -> Result<super::SkillTreeInventory, InventoryError> {
    let inventory = scan_inner(reader, ScanKind::SkillTree)?;
    let mut findings = inventory.findings;
    let skill = match inventory.skills.as_slice() {
        [skill] if skill.path.as_bytes().is_empty() => {
            if skill.name != expected_name {
                findings.push(Finding {
                    code: "skill-name-mismatch".into(),
                    path: Some(SourcePath::from("SKILL.md")),
                    severity: Severity::Error,
                    details: BTreeMap::from([
                        ("expected".into(), expected_name.into()),
                        ("observed".into(), skill.name.clone()),
                    ]),
                    message: "skill name mismatch".into(),
                });
            }
            Some(skill.clone())
        }
        [] => {
            findings.push(Finding {
                code: "skill-root-missing".into(),
                path: Some(SourcePath::from("SKILL.md")),
                severity: Severity::Error,
                details: BTreeMap::new(),
                message: "skill root missing".into(),
            });
            None
        }
        _ => {
            findings.push(Finding {
                code: "skill-root-ambiguous".into(),
                path: None,
                severity: Severity::Error,
                details: BTreeMap::new(),
                message: "skill root ambiguous".into(),
            });
            None
        }
    };

    findings.sort_by(finding_order);
    findings.dedup();
    Ok(super::SkillTreeInventory { skill, findings })
}

fn strict_skill_entry_findings(entry: &TreeEntry) -> Vec<Finding> {
    let mut findings = Vec::new();
    let actual = entry.mode & 0o7777;
    let valid_mode = match entry.kind {
        TreeEntryKind::Directory => actual == 0o755,
        TreeEntryKind::File => matches!(actual, 0o644 | 0o755),
        TreeEntryKind::Symlink => true,
        TreeEntryKind::Submodule
        | TreeEntryKind::Device
        | TreeEntryKind::Fifo
        | TreeEntryKind::Socket => false,
    };
    if !valid_mode {
        findings.push(Finding {
            code: "invalid-entry-mode".into(),
            path: Some(entry.path.clone()),
            severity: Severity::Error,
            details: BTreeMap::from([("mode".into(), format!("{actual:04o}"))]),
            message: "invalid entry mode".into(),
        });
    }
    if entry
        .path
        .as_bytes()
        .split(|byte| *byte == b'/')
        .any(|component| component == b".git")
    {
        findings.push(Finding {
            code: "unsupported-entry".into(),
            path: Some(entry.path.clone()),
            severity: Severity::Error,
            details: BTreeMap::from([("kind".into(), "git-metadata".into())]),
            message: "unsupported entry".into(),
        });
    }
    findings
}

fn add_pack_availability(skills: &[Skill], packs: &mut [Pack], findings: &mut Vec<Finding>) {
    let available: BTreeSet<_> = skills.iter().map(|skill| skill.name.as_str()).collect();
    for pack in packs {
        pack.missing_required = pack
            .required
            .iter()
            .filter(|member| !available.contains(member.as_str()))
            .cloned()
            .collect();
        pack.missing_optional = pack
            .optional
            .iter()
            .filter(|member| !available.contains(member.as_str()))
            .cloned()
            .collect();
        for member in &pack.missing_optional {
            findings.push(Finding {
                code: "missing-optional-member".into(),
                path: Some(pack.path.clone()),
                severity: Severity::Warning,
                details: BTreeMap::from([
                    ("member".into(), member.clone()),
                    ("pack".into(), pack.name.clone()),
                ]),
                message: "optional pack member is unavailable in this snapshot".into(),
            });
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

fn ignored_descendant(path: &SourcePath) -> bool {
    let components = path
        .as_bytes()
        .split(|byte| *byte == b'/')
        .collect::<Vec<_>>();
    components[..components.len().saturating_sub(1)]
        .iter()
        .any(|component| IGNORED_DIRECTORIES.contains(component))
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

fn read_frontmatter(reader: &dyn TreeReader, path: &SourcePath) -> Result<Vec<u8>, InventoryError> {
    let mut bytes = Vec::new();
    reader.read_chunks(path, 1, &mut |chunk| {
        bytes.push(chunk[0]);
        Ok(bytes.len() <= FRONTMATTER_BYTE_LIMIT
            && !(bytes.len() > 4 && bytes.ends_with(b"\n---\n")))
    })?;
    Ok(bytes)
}

struct ReviewBudget {
    consumed: u64,
    exhausted: bool,
}

struct FileInspection {
    size: u64,
    digest: super::Digest,
    binary: bool,
    shebang: Option<Vec<u8>>,
}

impl ReviewBudget {
    fn new() -> Self {
        Self {
            consumed: 0,
            exhausted: false,
        }
    }

    fn inspect(
        &mut self,
        reader: &dyn TreeReader,
        path: &SourcePath,
        expected_size: Option<u64>,
        content_record: Option<(&mut Sha256, u8, &[u8], &[u8])>,
        findings: &mut Vec<Finding>,
    ) -> Result<Option<FileInspection>, InventoryError> {
        if self.exhausted {
            return Ok(None);
        }
        let remaining = REVIEW_BYTE_LIMIT.saturating_sub(self.consumed);
        let expected_size = expected_size.ok_or_else(|| InventoryError::Tree {
            path: path.clone(),
            message: "regular file size is unavailable".into(),
        })?;
        if expected_size > remaining {
            self.exhausted = true;
            findings.push(limit_finding(
                "review-byte-limit",
                Some(path.clone()),
                REVIEW_BYTE_LIMIT as usize,
                REVIEW_BYTE_LIMIT as usize + 1,
            ));
            return Ok(None);
        }
        let mut digest = Sha256::new();
        let mut content = content_record.map(|(hasher, kind, record_path, mode)| {
            let mut next = hasher.clone();
            next.update([kind]);
            update_field_prefix(&mut next, record_path.len() as u64);
            next.update(record_path);
            update_field_prefix(&mut next, mode.len() as u64);
            next.update(mode);
            update_field_prefix(&mut next, expected_size);
            (hasher, next)
        });
        let mut prefix = Vec::with_capacity(8 * 1024);
        let mut size = 0u64;
        reader.read_chunks(path, 64 * 1024, &mut |chunk| {
            size = size.saturating_add(chunk.len() as u64);
            if size > expected_size || size > remaining {
                self.exhausted = size > remaining;
                if self.exhausted {
                    findings.push(limit_finding(
                        "review-byte-limit",
                        Some(path.clone()),
                        REVIEW_BYTE_LIMIT as usize,
                        REVIEW_BYTE_LIMIT as usize + 1,
                    ));
                    return Ok(false);
                }
                return Err(InventoryError::Tree {
                    path: path.clone(),
                    message: "regular file grew during inspection".into(),
                });
            }
            digest.update(chunk);
            if let Some((_, hasher)) = &mut content {
                hasher.update(chunk);
            }
            let wanted = (8 * 1024usize)
                .saturating_sub(prefix.len())
                .min(chunk.len());
            prefix.extend_from_slice(&chunk[..wanted]);
            Ok(true)
        })?;
        if self.exhausted {
            return Ok(None);
        }
        if size != expected_size {
            return Err(InventoryError::Tree {
                path: path.clone(),
                message: "regular file size changed during inspection".into(),
            });
        }
        if let Some((target, next)) = content {
            *target = next;
        }
        self.consumed += size;
        let shebang = prefix.starts_with(b"#!").then(|| {
            prefix[..prefix
                .iter()
                .position(|byte| *byte == b'\n')
                .unwrap_or(prefix.len())
                .min(512)]
                .to_vec()
        });
        Ok(Some(FileInspection {
            size,
            digest: super::Digest::from_bytes(digest.finalize().into()),
            binary: prefix.contains(&0),
            shebang,
        }))
    }
}

fn update_field_prefix(hasher: &mut Sha256, size: u64) {
    hasher.update(size.to_be_bytes());
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
    let mut required = sequence("required", &mut failures);
    let mut optional = sequence("optional", &mut failures);
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
    required.as_mut().unwrap().sort();
    optional.as_mut().unwrap().sort();
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

struct SkillScan<'a> {
    reader: &'a dyn TreeReader,
    entries: &'a [TreeEntry],
    symlink_paths: &'a [SourcePath],
    reviewed: &'a mut Vec<ReviewedEntry>,
    budget: &'a mut ReviewBudget,
    findings: &'a mut Vec<Finding>,
}

fn build_skill(
    scan: &mut SkillScan<'_>,
    root: &SourcePath,
    name: &str,
) -> Result<Skill, InventoryError> {
    let mut files = Vec::new();
    let mut symlinks = Vec::new();
    let mut submodules = Vec::new();
    let mut content_digest = Sha256::new();
    content_digest.update(b"grimoire/skill-content@1\0");
    for entry in scan
        .entries
        .iter()
        .filter(|entry| entry.path.is_descendant_of(root))
        .filter(|entry| {
            !scan
                .symlink_paths
                .iter()
                .any(|link| entry.path != *link && entry.path.is_descendant_of(link))
        })
    {
        let relative = entry.path.strip_prefix(root).expect("filtered descendant");
        match entry.kind {
            TreeEntryKind::Directory => {}
            TreeEntryKind::File => {
                let mode = normalized_file_mode(entry.mode).to_owned();
                let Some(inspection) = scan.budget.inspect(
                    scan.reader,
                    &entry.path,
                    entry.size,
                    Some((
                        &mut content_digest,
                        b'F',
                        relative.as_bytes(),
                        mode.as_bytes(),
                    )),
                    scan.findings,
                )?
                else {
                    continue;
                };
                files.push(FileFact {
                    path: relative,
                    size: inspection.size,
                    mode: mode.clone(),
                    digest: inspection.digest,
                    binary: inspection.binary,
                    executable: mode == "100755",
                    shebang: inspection.shebang,
                });
                scan.reviewed.push(ReviewedEntry {
                    path: entry.path.clone(),
                    mode,
                    payload: ReviewedPayload::File {
                        size: inspection.size,
                        digest: inspection.digest,
                    },
                    boundary: Boundary::Skill(root.clone()),
                    safety: None,
                    reason: None,
                });
            }
            TreeEntryKind::Symlink => {
                let target = entry.link_target.clone().unwrap_or_default();
                let (safety, reason) = classify_link(root, &entry.path, &target);
                content_digest.update([b'L']);
                update_field_prefix(&mut content_digest, relative.as_bytes().len() as u64);
                content_digest.update(relative.as_bytes());
                update_field_prefix(&mut content_digest, 6);
                content_digest.update(b"120000");
                update_field_prefix(&mut content_digest, target.len() as u64);
                content_digest.update(&target);
                symlinks.push(SymlinkFact {
                    path: relative,
                    target: target.clone(),
                    mode: "120000".into(),
                    safety,
                    reason: reason.clone(),
                });
                scan.reviewed.push(ReviewedEntry {
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
                scan.reviewed.push(ReviewedEntry {
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
    files.sort_by(|left, right| left.path.cmp(&right.path));
    symlinks.sort_by(|left, right| left.path.cmp(&right.path));
    submodules.sort_by(|left, right| left.path.cmp(&right.path));
    Ok(Skill {
        name: name.into(),
        path: root.clone(),
        content_digest: super::Digest::from_bytes(content_digest.finalize().into()),
        files,
        symlinks,
        submodules,
    })
}

fn reviewed_entry(
    reader: &dyn TreeReader,
    entry: &TreeEntry,
    boundary: Boundary,
    budget: &mut ReviewBudget,
    findings: &mut Vec<Finding>,
) -> Result<Option<ReviewedEntry>, InventoryError> {
    match entry.kind {
        TreeEntryKind::File => {
            let Some(inspection) =
                budget.inspect(reader, &entry.path, entry.size, None, findings)?
            else {
                return Ok(None);
            };
            Ok(Some(ReviewedEntry {
                path: entry.path.clone(),
                mode: normalized_file_mode(entry.mode).into(),
                payload: ReviewedPayload::File {
                    size: inspection.size,
                    digest: inspection.digest,
                },
                boundary,
                safety: None,
                reason: None,
            }))
        }
        TreeEntryKind::Symlink => {
            let target = entry.link_target.clone().unwrap_or_default();
            let (safety, reason) = classify_link(&SourcePath::from(""), &entry.path, &target);
            Ok(Some(ReviewedEntry {
                path: entry.path.clone(),
                mode: "120000".into(),
                payload: ReviewedPayload::Symlink { target },
                boundary,
                safety: Some(safety),
                reason,
            }))
        }
        TreeEntryKind::Submodule => Ok(Some(ReviewedEntry {
            path: entry.path.clone(),
            mode: "160000".into(),
            payload: ReviewedPayload::Submodule {
                commit: entry.submodule_commit.clone().unwrap_or_default(),
            },
            boundary,
            safety: None,
            reason: None,
        })),
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
