use std::collections::BTreeMap;
use std::io::Read as _;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use grimoire_pack::inventory::{Boundary, Severity, SourceInventory, SourcePath, SymlinkSafety};
use serde::Serialize;

use super::{CandidateRecord, ReviewExport, ReviewPayload};
use crate::{Result, SourceAlias, TrustBaseline, TrustMode};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceInfo {
    pub alias: SourceAlias,
    pub declared: String,
    pub requested_ref: Option<String>,
    pub candidate: CandidateRecord,
    pub inventory: SourceInventory,
    pub export: ReviewExport,
    pub trust: TrustMode,
    pub baseline: Option<TrustBaseline>,
}

impl SourceInfo {
    #[allow(clippy::too_many_arguments)]
    pub fn from_candidate(
        alias: SourceAlias,
        declared: String,
        requested_ref: Option<String>,
        candidate: CandidateRecord,
        inventory: SourceInventory,
        export: ReviewExport,
        trust: TrustMode,
        baseline: Option<TrustBaseline>,
    ) -> Self {
        Self {
            alias,
            declared,
            requested_ref,
            candidate,
            inventory,
            export,
            trust,
            baseline,
        }
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let (canonical, canonical_bytes_base64) =
            projection(self.candidate.identity.canonical_bytes());
        let document = Document {
            schema: "grimoire/source-info@1",
            alias: self.alias.as_str(),
            source: SourceDto {
                declared: &self.declared,
                canonical,
                canonical_bytes_base64,
                kind: self.candidate.identity.kind().as_str(),
                requested_ref: &self.requested_ref,
            },
            snapshot: SnapshotDto {
                commit: &self.candidate.commit,
                tree: &self.candidate.tree,
                inventory: &self.candidate.inventory,
                review_tree: &self.candidate.review_tree,
                review_path: self.export.root.display().to_string(),
            },
            trust: TrustDto {
                mode: self.trust,
                baseline: &self.baseline,
            },
            skills: self.inventory.skills.iter().map(skill_dto).collect(),
            entries: self
                .export
                .entries
                .iter()
                .filter(|entry| entry.boundary == Boundary::Snapshot)
                .map(|entry| {
                    entry_dto(
                        &self.export,
                        &entry.path,
                        &entry.mode,
                        &entry.payload,
                        entry.safety,
                        entry.reason.as_deref(),
                    )
                })
                .collect::<Result<Vec<_>>>()?,
            packs: self
                .inventory
                .packs
                .iter()
                .map(|pack| PackDto {
                    name: &pack.name,
                    path: path_projection(&pack.path),
                    digest: pack.digest.to_string(),
                    description: &pack.description,
                    required: &pack.required,
                    optional: &pack.optional,
                    missing_required: &pack.missing_required,
                    missing_optional: &pack.missing_optional,
                })
                .collect(),
            findings: self
                .inventory
                .findings
                .iter()
                .map(|finding| FindingDto {
                    code: &finding.code,
                    severity: match finding.severity {
                        Severity::Error => "error",
                        Severity::Warning => "warning",
                    },
                    path: finding.path.as_ref().map(path_projection),
                    details: &finding.details,
                    message: &finding.message,
                })
                .collect(),
        };
        let mut bytes = serde_json::to_vec_pretty(&document)?;
        bytes.push(b'\n');
        Ok(bytes)
    }
}

#[derive(Serialize)]
struct Document<'a> {
    schema: &'static str,
    alias: &'a str,
    source: SourceDto<'a>,
    snapshot: SnapshotDto<'a>,
    trust: TrustDto<'a>,
    skills: Vec<SkillDto<'a>>,
    entries: Vec<EntryDto>,
    packs: Vec<PackDto<'a>>,
    findings: Vec<FindingDto<'a>>,
}

#[derive(Serialize)]
struct SourceDto<'a> {
    declared: &'a str,
    canonical: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    canonical_bytes_base64: Option<String>,
    kind: &'static str,
    requested_ref: &'a Option<String>,
}

#[derive(Serialize)]
struct SnapshotDto<'a> {
    commit: &'a Option<String>,
    tree: &'a Option<String>,
    inventory: &'a str,
    review_tree: &'a str,
    review_path: String,
}

#[derive(Serialize)]
struct TrustDto<'a> {
    mode: TrustMode,
    baseline: &'a Option<TrustBaseline>,
}

#[derive(Serialize)]
struct SkillDto<'a> {
    name: &'a str,
    #[serde(flatten)]
    path: PathProjection,
    content: String,
    files: Vec<EntryDto>,
}

fn skill_dto(skill: &grimoire_pack::inventory::Skill) -> SkillDto<'_> {
    let mut files = Vec::new();
    for file in &skill.files {
        let path = relative_path(&file.path, &skill.path);
        let (shebang, shebang_bytes_base64) = file
            .shebang
            .as_deref()
            .map(projection)
            .unwrap_or((None, None));
        files.push(EntryDto::File {
            path: path_projection(&path),
            size: file.size,
            mode: file.mode.clone(),
            sha256: file.digest.to_string(),
            binary: file.binary,
            executable: file.executable,
            shebang,
            shebang_bytes_base64,
        });
    }
    for link in &skill.symlinks {
        files.push(EntryDto::Symlink {
            path: path_projection(&relative_path(&link.path, &skill.path)),
            mode: link.mode.clone(),
            target: projection(link.target.as_slice()).0,
            target_bytes_base64: projection(link.target.as_slice()).1,
            safety: safety(link.safety),
            reason: link.reason.clone(),
        });
    }
    for submodule in &skill.submodules {
        files.push(EntryDto::Submodule {
            path: path_projection(&relative_path(&submodule.path, &skill.path)),
            mode: "160000".into(),
            commit: submodule.commit.clone(),
        });
    }
    files.sort_by(|left, right| left.path_bytes().cmp(right.path_bytes()));
    SkillDto {
        name: &skill.name,
        path: path_projection(&skill.path),
        content: skill.content_digest.to_string(),
        files,
    }
}

fn relative_path(path: &SourcePath, root: &SourcePath) -> SourcePath {
    path.strip_prefix(root).unwrap_or_else(|| path.clone())
}

#[derive(Debug, Clone, Serialize)]
struct PathProjection {
    path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    path_bytes_base64: Option<String>,
    #[serde(skip)]
    raw: Vec<u8>,
}

fn path_projection(path: &SourcePath) -> PathProjection {
    let (path_text, path_bytes_base64) = projection(path.as_bytes());
    PathProjection {
        path: path_text,
        path_bytes_base64,
        raw: path.as_bytes().to_vec(),
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
enum EntryDto {
    File {
        #[serde(flatten)]
        path: PathProjection,
        size: u64,
        mode: String,
        sha256: String,
        binary: bool,
        executable: bool,
        shebang: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        shebang_bytes_base64: Option<String>,
    },
    Symlink {
        #[serde(flatten)]
        path: PathProjection,
        mode: String,
        target: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        target_bytes_base64: Option<String>,
        safety: &'static str,
        #[serde(skip_serializing_if = "Option::is_none")]
        reason: Option<String>,
    },
    Submodule {
        #[serde(flatten)]
        path: PathProjection,
        mode: String,
        commit: String,
    },
}

impl EntryDto {
    fn path_bytes(&self) -> &[u8] {
        match self {
            Self::File { path, .. } | Self::Symlink { path, .. } | Self::Submodule { path, .. } => {
                &path.raw
            }
        }
    }
}

fn entry_dto(
    export: &ReviewExport,
    path: &SourcePath,
    mode: &str,
    payload: &ReviewPayload,
    link_safety: Option<SymlinkSafety>,
    reason: Option<&str>,
) -> Result<EntryDto> {
    Ok(match payload {
        ReviewPayload::File { size, digest } => {
            let (binary, shebang, shebang_bytes_base64) = file_capabilities(export, digest, *size)?;
            EntryDto::File {
                path: path_projection(path),
                size: *size,
                mode: mode.into(),
                sha256: digest.clone(),
                binary,
                executable: mode == "100755",
                shebang,
                shebang_bytes_base64,
            }
        }
        ReviewPayload::Symlink { target } => {
            let (target, target_bytes_base64) = projection(target);
            EntryDto::Symlink {
                path: path_projection(path),
                mode: mode.into(),
                target,
                target_bytes_base64,
                safety: safety(link_safety.expect("reviewed link has safety")),
                reason: reason.map(str::to_owned),
            }
        }
        ReviewPayload::Submodule { commit } => EntryDto::Submodule {
            path: path_projection(path),
            mode: mode.into(),
            commit: commit.clone(),
        },
    })
}

fn file_capabilities(
    export: &ReviewExport,
    digest: &str,
    size: u64,
) -> Result<(bool, Option<String>, Option<String>)> {
    let path = export.object_path(digest)?;
    let mut prefix = Vec::with_capacity((size as usize).min(8 * 1024));
    std::fs::File::open(&path)
        .map_err(|error| crate::CoreError::Io {
            path: path.display().to_string(),
            message: error.to_string(),
        })?
        .take(size.min(8 * 1024))
        .read_to_end(&mut prefix)
        .map_err(|error| crate::CoreError::Io {
            path: path.display().to_string(),
            message: error.to_string(),
        })?;
    let shebang = prefix.starts_with(b"#!").then(|| {
        &prefix[..prefix
            .iter()
            .position(|byte| *byte == b'\n')
            .unwrap_or(prefix.len())
            .min(512)]
    });
    let (shebang, shebang_bytes_base64) = shebang.map(projection).unwrap_or((None, None));
    Ok((prefix.contains(&0), shebang, shebang_bytes_base64))
}

fn safety(value: SymlinkSafety) -> &'static str {
    match value {
        SymlinkSafety::Internal => "internal",
        SymlinkSafety::Escaping => "escaping",
        SymlinkSafety::Invalid => "invalid",
    }
}

fn projection(bytes: &[u8]) -> (Option<String>, Option<String>) {
    match std::str::from_utf8(bytes) {
        Ok(text) => (Some(text.into()), None),
        Err(_) => (None, Some(BASE64.encode(bytes))),
    }
}

#[derive(Serialize)]
struct PackDto<'a> {
    name: &'a str,
    #[serde(flatten)]
    path: PathProjection,
    digest: String,
    description: &'a str,
    required: &'a [String],
    optional: &'a [String],
    missing_required: &'a [String],
    missing_optional: &'a [String],
}

#[derive(Serialize)]
struct FindingDto<'a> {
    code: &'a str,
    severity: &'static str,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    path: Option<PathProjection>,
    details: &'a BTreeMap<String, String>,
    message: &'a str,
}
