use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use serde::{Deserialize, Serialize};

use super::identity::{validate_digest, validate_object_id};
use super::{CanonicalIdentity, ReviewKey, SnapshotKey, SourceKey, SourceKind};
use crate::{CoreError, Result};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CandidateRecord {
    pub declaration_hash: String,
    pub identity: CanonicalIdentity,
    pub commit: Option<String>,
    pub tree: Option<String>,
    pub inventory: String,
    pub review_tree: String,
}

impl CandidateRecord {
    pub fn new(
        declaration_hash: String,
        identity: CanonicalIdentity,
        commit: Option<String>,
        tree: Option<String>,
        inventory: String,
        review_tree: String,
    ) -> Result<Self> {
        validate_hex(&declaration_hash, "declaration hash")?;
        validate_digest(&inventory)?;
        validate_digest(&review_tree)?;
        match identity.kind() {
            SourceKind::Git => {
                validate_object_id(
                    commit
                        .as_deref()
                        .ok_or_else(|| CoreError::Source("Git candidate requires commit".into()))?,
                )?;
                validate_object_id(
                    tree.as_deref()
                        .ok_or_else(|| CoreError::Source("Git candidate requires tree".into()))?,
                )?;
            }
            SourceKind::Live if commit.is_some() || tree.is_some() => {
                return Err(CoreError::Source(
                    "live candidate cannot carry Git object IDs".into(),
                ));
            }
            SourceKind::Live => {}
        }
        Ok(Self {
            declaration_hash,
            identity,
            commit,
            tree,
            inventory,
            review_tree,
        })
    }

    pub fn source_key(&self) -> SourceKey {
        SourceKey::derive(&self.identity)
    }

    pub fn snapshot_key(&self) -> Result<Option<SnapshotKey>> {
        match self.identity.kind() {
            SourceKind::Live => Ok(None),
            SourceKind::Git => SnapshotKey::derive(
                SourceKind::Git,
                self.commit.as_deref().expect("validated Git commit"),
                self.tree.as_deref().expect("validated Git tree"),
                &self.inventory,
            )
            .map(Some),
        }
    }

    pub fn review_key(&self) -> Result<ReviewKey> {
        ReviewKey::derive(
            self.identity.kind(),
            self.commit.as_deref(),
            self.tree.as_deref(),
            &self.inventory,
            &self.review_tree,
        )
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let dto = CandidateDto::from(self);
        let mut bytes = serde_json::to_vec_pretty(&dto)?;
        bytes.push(b'\n');
        Ok(bytes)
    }

    pub fn parse(bytes: &[u8], expected_source: Option<&SourceKey>) -> Result<Self> {
        let dto: CandidateDto = serde_json::from_slice(bytes)?;
        if dto.schema != "grimoire/candidate@1" {
            return Err(CoreError::Source("unsupported candidate schema".into()));
        }
        let kind = match dto.kind.as_str() {
            "git" => SourceKind::Git,
            "live" => SourceKind::Live,
            _ => return Err(CoreError::Source("invalid candidate kind".into())),
        };
        let canonical = match (dto.canonical, dto.canonical_bytes_base64) {
            (Some(text), None) => text.into_bytes(),
            (None, Some(raw)) => BASE64
                .decode(raw)
                .map_err(|_| CoreError::Source("invalid canonical base64".into()))?,
            _ => {
                return Err(CoreError::Source(
                    "candidate identity requires one canonical projection".into(),
                ))
            }
        };
        let identity = CanonicalIdentity::from_parts(kind, canonical)?;
        let candidate = Self::new(
            dto.declaration_hash,
            identity,
            dto.commit,
            dto.tree,
            dto.inventory,
            dto.review_tree,
        )?;
        let actual = candidate.source_key();
        let encoded = SourceKey::parse(dto.source_key)?;
        if actual != encoded || expected_source.is_some_and(|expected| expected != &actual) {
            return Err(CoreError::Source("candidate source-key mismatch".into()));
        }
        Ok(candidate)
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct CandidateDto {
    schema: String,
    declaration_hash: String,
    source_key: String,
    kind: String,
    canonical: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    canonical_bytes_base64: Option<String>,
    commit: Option<String>,
    tree: Option<String>,
    inventory: String,
    review_tree: String,
}

impl From<&CandidateRecord> for CandidateDto {
    fn from(candidate: &CandidateRecord) -> Self {
        let (canonical, canonical_bytes_base64) = match candidate.identity.canonical_utf8() {
            Some(text) => (Some(text.into()), None),
            None => (
                None,
                Some(BASE64.encode(candidate.identity.canonical_bytes())),
            ),
        };
        Self {
            schema: "grimoire/candidate@1".into(),
            declaration_hash: candidate.declaration_hash.clone(),
            source_key: candidate.source_key().to_string(),
            kind: candidate.identity.kind().as_str().into(),
            canonical,
            canonical_bytes_base64,
            commit: candidate.commit.clone(),
            tree: candidate.tree.clone(),
            inventory: candidate.inventory.clone(),
            review_tree: candidate.review_tree.clone(),
        }
    }
}

fn validate_hex(value: &str, name: &str) -> Result<()> {
    if value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(())
    } else {
        Err(CoreError::Source(format!(
            "{name} must be lowercase SHA-256"
        )))
    }
}
