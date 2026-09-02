use std::collections::BTreeMap;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use grimoire_pack::inventory::{
    compute_review_tree_digest, Boundary, ReviewedEntry, ReviewedPayload, SourceInventory,
    SourcePath, SymlinkSafety, TreeReader,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};

use super::{ReviewKey, SourceKey};
use crate::{CoreError, Result};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReviewPayload {
    File { size: u64, digest: String },
    Symlink { target: Vec<u8> },
    Submodule { commit: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReviewEntry {
    pub path: SourcePath,
    pub mode: String,
    pub boundary: Boundary,
    pub payload: ReviewPayload,
    pub safety: Option<SymlinkSafety>,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReviewExport {
    pub root: PathBuf,
    pub source_key: SourceKey,
    pub review_key: ReviewKey,
    pub review_tree: String,
    pub entries: Vec<ReviewEntry>,
    pub facts: ReviewFacts,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct ReviewFacts {
    pub values: BTreeMap<String, String>,
}

impl ReviewFacts {
    pub fn from_inventory(inventory: &SourceInventory) -> Self {
        let mut values = BTreeMap::new();
        for skill in &inventory.skills {
            values.insert(
                format!("skill/{}", skill.name),
                format!(
                    "path={};content={}",
                    BASE64.encode(skill.path.as_bytes()),
                    skill.content_digest
                ),
            );
            for file in &skill.files {
                values.insert(
                    format!("file/{}", BASE64.encode(file.path.as_bytes())),
                    format!(
                        "size={};mode={};sha256={};binary={};executable={};shebang={}",
                        file.size,
                        file.mode,
                        file.digest,
                        file.binary,
                        file.executable,
                        file.shebang
                            .as_deref()
                            .map(|bytes| BASE64.encode(bytes))
                            .unwrap_or_default()
                    ),
                );
            }
            for link in &skill.symlinks {
                values.insert(
                    format!("symlink/{}", BASE64.encode(link.path.as_bytes())),
                    format!(
                        "mode={};target={};safety={:?};reason={}",
                        link.mode,
                        BASE64.encode(&link.target),
                        link.safety,
                        link.reason.as_deref().unwrap_or_default()
                    ),
                );
            }
            for submodule in &skill.submodules {
                values.insert(
                    format!("submodule/{}", BASE64.encode(submodule.path.as_bytes())),
                    format!("commit={}", submodule.commit),
                );
            }
        }
        for pack in &inventory.packs {
            values.insert(
                format!("pack/{}", pack.name),
                format!(
                    "path={};digest={};description={};required={:?};optional={:?};missing_required={:?};missing_optional={:?}",
                    BASE64.encode(pack.path.as_bytes()),
                    pack.digest,
                    pack.description,
                    pack.required,
                    pack.optional,
                    pack.missing_required,
                    pack.missing_optional
                ),
            );
        }
        for (index, finding) in inventory.findings.iter().enumerate() {
            values.insert(
                format!("finding/{index:08}"),
                format!(
                    "code={};severity={:?};path={};details={:?}",
                    finding.code,
                    finding.severity,
                    finding
                        .path
                        .as_ref()
                        .map(|path| BASE64.encode(path.as_bytes()))
                        .unwrap_or_default(),
                    finding.details
                ),
            );
        }
        Self { values }
    }
}

impl ReviewExport {
    pub fn load_for_keys(
        cache_review: &Path,
        source_key: &SourceKey,
        review_key: &ReviewKey,
    ) -> Result<Self> {
        let root = cache_review
            .join(source_key.as_str())
            .join(review_key.as_str());
        let index_path = root.join("index.json");
        let bytes = fs::read(&index_path).map_err(|error| io_error(&index_path, error))?;
        let value: serde_json::Value = serde_json::from_slice(&bytes)?;
        let review_tree = value
            .as_object()
            .and_then(|object| object.get("review_tree"))
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| CoreError::Source("review index lacks review-tree identity".into()))?;
        Self::load(&root, source_key, review_key, review_tree)
    }

    pub fn write(
        cache_review: &Path,
        source_key: SourceKey,
        review_key: ReviewKey,
        inventory: &SourceInventory,
        reader: &dyn TreeReader,
    ) -> Result<Self> {
        let root = cache_review
            .join(source_key.as_str())
            .join(review_key.as_str());
        if root.exists() {
            return Self::load(
                &root,
                &source_key,
                &review_key,
                &inventory.review_tree_digest.to_string(),
            );
        }
        let parent = root.parent().expect("review path has parent");
        fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
        let mut temporary =
            TemporaryDirectory::new(unique_temporary_directory(parent, &review_key)?);
        let objects = temporary.path().join("objects");
        fs::create_dir(&objects).map_err(|error| io_error(&objects, error))?;

        let mut entries = Vec::with_capacity(inventory.reviewed_entries.len());
        for entry in &inventory.reviewed_entries {
            let payload = match &entry.payload {
                ReviewedPayload::File { size, digest } => {
                    let digest = digest.to_string();
                    let object =
                        objects.join(digest.strip_prefix("sha256:").expect("digest prefix"));
                    write_verified_object(reader, &entry.path, *size, &digest, &object)?;
                    ReviewPayload::File {
                        size: *size,
                        digest,
                    }
                }
                ReviewedPayload::Symlink { target } => ReviewPayload::Symlink {
                    target: target.clone(),
                },
                ReviewedPayload::Submodule { commit } => ReviewPayload::Submodule {
                    commit: commit.clone(),
                },
            };
            entries.push(ReviewEntry {
                path: entry.path.clone(),
                mode: entry.mode.clone(),
                boundary: entry.boundary.clone(),
                payload,
                safety: entry.safety,
                reason: entry.reason.clone(),
            });
        }
        entries.sort_by(|left, right| left.path.cmp(&right.path));
        let dto = ReviewIndexDto::from_entries(
            &inventory.review_tree_digest.to_string(),
            &entries,
            &ReviewFacts::from_inventory(inventory),
        );
        let mut bytes = serde_json::to_vec_pretty(&dto)?;
        bytes.push(b'\n');
        write_new_file(&temporary.path().join("index.json"), &bytes, 0o444)?;
        sync_directory(temporary.path())?;
        if let Err(error) = fs::rename(temporary.path(), &root) {
            if error.kind() == std::io::ErrorKind::AlreadyExists || root.exists() {
                return Self::load(
                    &root,
                    &source_key,
                    &review_key,
                    &inventory.review_tree_digest.to_string(),
                );
            }
            return Err(io_error(&root, error));
        }
        temporary.disarm();
        sync_directory(parent)?;
        Self::load(
            &root,
            &source_key,
            &review_key,
            &inventory.review_tree_digest.to_string(),
        )
    }

    pub fn load(
        root: &Path,
        source_key: &SourceKey,
        review_key: &ReviewKey,
        expected_review_tree: &str,
    ) -> Result<Self> {
        if root.file_name().and_then(|name| name.to_str()) != Some(review_key.as_str())
            || root
                .parent()
                .and_then(Path::file_name)
                .and_then(|name| name.to_str())
                != Some(source_key.as_str())
        {
            return Err(CoreError::Source(
                "review export path identity mismatch".into(),
            ));
        }
        let index_path = root.join("index.json");
        let bytes = fs::read(&index_path).map_err(|error| io_error(&index_path, error))?;
        let dto: ReviewIndexDto = serde_json::from_slice(&bytes)?;
        if dto.schema != "grimoire/review-index@1" || dto.review_tree != expected_review_tree {
            return Err(CoreError::Source("review index identity mismatch".into()));
        }
        let facts = dto.facts.clone();
        let entries = dto.into_entries()?;
        let reviewed = entries
            .iter()
            .map(ReviewEntry::to_reviewed)
            .collect::<Vec<_>>();
        if compute_review_tree_digest(&reviewed).to_string() != expected_review_tree {
            return Err(CoreError::Source("review-tree digest mismatch".into()));
        }
        for entry in &entries {
            if let ReviewPayload::File { size, digest } = &entry.payload {
                let object = root
                    .join("objects")
                    .join(digest.strip_prefix("sha256:").ok_or_else(|| {
                        CoreError::Source("review object digest is malformed".into())
                    })?);
                verify_object(&object, *size, digest)?;
                let metadata =
                    fs::symlink_metadata(&object).map_err(|error| io_error(&object, error))?;
                if !metadata.file_type().is_file() || !readonly_nonexecutable(&metadata) {
                    return Err(CoreError::Source(
                        "review object is not a read-only regular file".into(),
                    ));
                }
            }
        }
        Ok(Self {
            root: root.to_path_buf(),
            source_key: source_key.clone(),
            review_key: review_key.clone(),
            review_tree: expected_review_tree.into(),
            entries,
            facts,
        })
    }

    pub fn object_path(&self, digest: &str) -> Result<PathBuf> {
        let hex = digest
            .strip_prefix("sha256:")
            .ok_or_else(|| CoreError::Source("review object digest is malformed".into()))?;
        if hex.len() != 64
            || !hex
                .bytes()
                .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
        {
            return Err(CoreError::Source(
                "review object digest is malformed".into(),
            ));
        }
        Ok(self.root.join("objects").join(hex))
    }
}

struct TemporaryDirectory {
    path: PathBuf,
    armed: bool,
}

impl TemporaryDirectory {
    fn new(path: PathBuf) -> Self {
        Self { path, armed: true }
    }

    fn path(&self) -> &Path {
        &self.path
    }

    fn disarm(&mut self) {
        self.armed = false;
    }
}

impl Drop for TemporaryDirectory {
    fn drop(&mut self) {
        if self.armed {
            let _ = fs::remove_dir_all(&self.path);
        }
    }
}

fn unique_temporary_directory(parent: &Path, review_key: &ReviewKey) -> Result<PathBuf> {
    for nonce in 0..100u32 {
        let path = parent.join(format!(
            ".{}.tmp-{}-{nonce}",
            review_key,
            std::process::id()
        ));
        match fs::create_dir(&path) {
            Ok(()) => return Ok(path),
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(io_error(&path, error)),
        }
    }
    Err(CoreError::Source(
        "cannot allocate review-export temporary directory".into(),
    ))
}

impl ReviewEntry {
    fn to_reviewed(&self) -> ReviewedEntry {
        ReviewedEntry {
            path: self.path.clone(),
            mode: self.mode.clone(),
            payload: match &self.payload {
                ReviewPayload::File { size, digest } => ReviewedPayload::File {
                    size: *size,
                    digest: parse_digest(digest),
                },
                ReviewPayload::Symlink { target } => ReviewedPayload::Symlink {
                    target: target.clone(),
                },
                ReviewPayload::Submodule { commit } => ReviewedPayload::Submodule {
                    commit: commit.clone(),
                },
            },
            boundary: self.boundary.clone(),
            safety: self.safety,
            reason: self.reason.clone(),
        }
    }
}

fn parse_digest(value: &str) -> grimoire_pack::inventory::Digest {
    let hex = value
        .strip_prefix("sha256:")
        .expect("review digest validated before conversion");
    let mut bytes = [0u8; 32];
    for (index, pair) in hex.as_bytes().chunks_exact(2).enumerate() {
        bytes[index] = u8::from_str_radix(std::str::from_utf8(pair).expect("ASCII hex"), 16)
            .expect("validated hex");
    }
    grimoire_pack::inventory::Digest::from_bytes(bytes)
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ReviewIndexDto {
    schema: String,
    review_tree: String,
    entries: Vec<ReviewEntryDto>,
    #[serde(default)]
    facts: ReviewFacts,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ReviewEntryDto {
    path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    path_bytes_base64: Option<String>,
    mode: String,
    boundary: String,
    owner_skill: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    owner_skill_bytes_base64: Option<String>,
    kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    size: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    sha256: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(default, deserialize_with = "double_option::deserialize")]
    target: Option<Option<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    target_bytes_base64: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    commit: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    safety: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
}

impl ReviewIndexDto {
    fn from_entries(review_tree: &str, entries: &[ReviewEntry], facts: &ReviewFacts) -> Self {
        Self {
            schema: "grimoire/review-index@1".into(),
            review_tree: review_tree.into(),
            entries: entries.iter().map(ReviewEntryDto::from).collect(),
            facts: facts.clone(),
        }
    }

    fn into_entries(self) -> Result<Vec<ReviewEntry>> {
        let mut entries: Vec<ReviewEntry> = self
            .entries
            .into_iter()
            .map(ReviewEntryDto::try_into)
            .collect::<Result<Vec<_>>>()?;
        if !entries.windows(2).all(|pair| pair[0].path < pair[1].path) {
            return Err(CoreError::Source(
                "review entries are not strictly raw-path sorted".into(),
            ));
        }
        entries.shrink_to_fit();
        Ok(entries)
    }
}

impl From<&ReviewEntry> for ReviewEntryDto {
    fn from(entry: &ReviewEntry) -> Self {
        let (path, path_bytes_base64) = raw_projection(entry.path.as_bytes());
        let (boundary, owner_skill, owner_skill_bytes_base64) = match &entry.boundary {
            Boundary::Snapshot => ("snapshot".into(), None, None),
            Boundary::Skill(path) => {
                let (owner, raw) = raw_projection(path.as_bytes());
                ("skill".into(), owner, raw)
            }
        };
        let (kind, size, sha256, target, target_bytes_base64, commit) = match &entry.payload {
            ReviewPayload::File { size, digest } => (
                "file".into(),
                Some(*size),
                Some(digest.clone()),
                None,
                None,
                None,
            ),
            ReviewPayload::Symlink { target } => {
                let (text, raw) = raw_projection(target);
                ("symlink".into(), None, None, Some(text), raw, None)
            }
            ReviewPayload::Submodule { commit } => (
                "submodule".into(),
                None,
                None,
                None,
                None,
                Some(commit.clone()),
            ),
        };
        Self {
            path,
            path_bytes_base64,
            mode: entry.mode.clone(),
            boundary,
            owner_skill,
            owner_skill_bytes_base64,
            kind,
            size,
            sha256,
            target,
            target_bytes_base64,
            commit,
            safety: entry.safety.map(|safety| {
                match safety {
                    SymlinkSafety::Internal => "internal",
                    SymlinkSafety::Escaping => "escaping",
                    SymlinkSafety::Invalid => "invalid",
                }
                .into()
            }),
            reason: entry.reason.clone(),
        }
    }
}

impl TryFrom<ReviewEntryDto> for ReviewEntry {
    type Error = CoreError;

    fn try_from(dto: ReviewEntryDto) -> Result<Self> {
        let path = raw_value(dto.path, dto.path_bytes_base64, "path")?;
        let boundary = match (
            dto.boundary.as_str(),
            dto.owner_skill,
            dto.owner_skill_bytes_base64,
        ) {
            ("snapshot", None, None) => Boundary::Snapshot,
            ("skill", text, raw) => {
                Boundary::Skill(SourcePath::new(raw_value(text, raw, "owner skill")?))
            }
            _ => return Err(CoreError::Source("invalid review boundary".into())),
        };
        let payload = match dto.kind.as_str() {
            "file"
                if dto.target.is_none()
                    && dto.target_bytes_base64.is_none()
                    && dto.commit.is_none()
                    && dto.safety.is_none()
                    && dto.reason.is_none()
                    && matches!(dto.mode.as_str(), "100644" | "100755") =>
            {
                let digest = dto
                    .sha256
                    .ok_or_else(|| CoreError::Source("file digest missing".into()))?;
                super::identity::validate_digest(&digest)?;
                ReviewPayload::File {
                    size: dto
                        .size
                        .ok_or_else(|| CoreError::Source("file size missing".into()))?,
                    digest,
                }
            }
            "symlink"
                if dto.size.is_none()
                    && dto.sha256.is_none()
                    && dto.commit.is_none()
                    && dto.mode == "120000" =>
            {
                ReviewPayload::Symlink {
                    target: raw_value(
                        dto.target.flatten(),
                        dto.target_bytes_base64,
                        "link target",
                    )?,
                }
            }
            "submodule"
                if dto.size.is_none()
                    && dto.sha256.is_none()
                    && dto.target.is_none()
                    && dto.target_bytes_base64.is_none()
                    && dto.safety.is_none()
                    && dto.reason.is_none()
                    && dto.mode == "160000" =>
            {
                ReviewPayload::Submodule {
                    commit: dto
                        .commit
                        .ok_or_else(|| CoreError::Source("submodule commit missing".into()))?,
                }
            }
            _ => return Err(CoreError::Source("invalid review entry variant".into())),
        };
        let safety = match dto.safety.as_deref() {
            None => None,
            Some("internal") => Some(SymlinkSafety::Internal),
            Some("escaping") => Some(SymlinkSafety::Escaping),
            Some("invalid") => Some(SymlinkSafety::Invalid),
            Some(_) => return Err(CoreError::Source("invalid link safety".into())),
        };
        Ok(Self {
            path: SourcePath::new(path),
            mode: dto.mode,
            boundary,
            payload,
            safety,
            reason: dto.reason,
        })
    }
}

mod double_option {
    use serde::{Deserialize, Deserializer};

    pub fn deserialize<'de, D, T>(deserializer: D) -> Result<Option<Option<T>>, D::Error>
    where
        D: Deserializer<'de>,
        T: Deserialize<'de>,
    {
        Option::<T>::deserialize(deserializer).map(Some)
    }
}

fn raw_projection(bytes: &[u8]) -> (Option<String>, Option<String>) {
    match std::str::from_utf8(bytes) {
        Ok(text) => (Some(text.into()), None),
        Err(_) => (None, Some(BASE64.encode(bytes))),
    }
}

fn raw_value(text: Option<String>, raw: Option<String>, name: &str) -> Result<Vec<u8>> {
    match (text, raw) {
        (Some(text), None) => Ok(text.into_bytes()),
        (None, Some(raw)) => BASE64
            .decode(raw)
            .map_err(|_| CoreError::Source(format!("invalid {name} base64"))),
        _ => Err(CoreError::Source(format!(
            "{name} requires one byte projection"
        ))),
    }
}

fn write_verified_object(
    reader: &dyn TreeReader,
    path: &SourcePath,
    expected_size: u64,
    expected_digest: &str,
    destination: &Path,
) -> Result<()> {
    if destination.exists() {
        return verify_object(destination, expected_size, expected_digest);
    }
    let mut source = reader
        .open(path)
        .map_err(|error| CoreError::Source(error.to_string()))?;
    let mut output = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(destination)
        .map_err(|error| io_error(destination, error))?;
    let mut digest = Sha256::new();
    let mut size = 0u64;
    let mut buffer = [0u8; 64 * 1024];
    loop {
        let read = source
            .read(&mut buffer)
            .map_err(|error| CoreError::Source(error.to_string()))?;
        if read == 0 {
            break;
        }
        size = size.saturating_add(read as u64);
        if size > expected_size {
            return Err(CoreError::Source(
                "review object exceeded declared size".into(),
            ));
        }
        digest.update(&buffer[..read]);
        output
            .write_all(&buffer[..read])
            .map_err(|error| io_error(destination, error))?;
    }
    output
        .sync_all()
        .map_err(|error| io_error(destination, error))?;
    if size != expected_size || format!("sha256:{:x}", digest.finalize()) != expected_digest {
        return Err(CoreError::Source("review object digest mismatch".into()));
    }
    set_mode(destination, 0o444)?;
    Ok(())
}

fn verify_object(path: &Path, expected_size: u64, expected_digest: &str) -> Result<()> {
    let mut input = File::open(path).map_err(|error| io_error(path, error))?;
    let mut digest = Sha256::new();
    let size = std::io::copy(&mut input, &mut digest).map_err(|error| io_error(path, error))?;
    if size == expected_size && format!("sha256:{:x}", digest.finalize()) == expected_digest {
        Ok(())
    } else {
        Err(CoreError::Source("review object digest mismatch".into()))
    }
}

fn write_new_file(path: &Path, bytes: &[u8], mode: u32) -> Result<()> {
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
        .map_err(|error| io_error(path, error))?;
    file.write_all(bytes)
        .map_err(|error| io_error(path, error))?;
    file.sync_all().map_err(|error| io_error(path, error))?;
    set_mode(path, mode)
}

#[cfg(unix)]
fn set_mode(path: &Path, mode: u32) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(mode))
        .map_err(|error| io_error(path, error))
}

#[cfg(unix)]
fn readonly_nonexecutable(metadata: &fs::Metadata) -> bool {
    use std::os::unix::fs::PermissionsExt;
    metadata.permissions().mode() & 0o333 == 0
}

fn sync_directory(path: &Path) -> Result<()> {
    File::open(path)
        .and_then(|file| file.sync_all())
        .map_err(|error| io_error(path, error))
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
