use std::net::Ipv6Addr;
use std::path::Path;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use sha2::{Digest as _, Sha256};

use crate::{CoreError, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceKind {
    Git,
    Link,
}

impl SourceKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Git => "git",
            Self::Link => "link",
        }
    }
}

#[derive(Debug, Clone)]
pub struct CanonicalIdentity {
    kind: SourceKind,
    canonical: Vec<u8>,
    repository: Option<String>,
}

impl PartialEq for CanonicalIdentity {
    fn eq(&self, other: &Self) -> bool {
        (self.kind, &self.canonical) == (other.kind, &other.canonical)
    }
}

impl Eq for CanonicalIdentity {}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct CanonicalIdentityDto {
    kind: SourceKind,
    canonical: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    canonical_bytes_base64: Option<String>,
}

impl Serialize for CanonicalIdentity {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        let (canonical, canonical_bytes_base64) = match self.canonical_utf8() {
            Some(value) => (Some(value.to_owned()), None),
            None => (None, Some(BASE64.encode(self.canonical_bytes()))),
        };
        CanonicalIdentityDto {
            kind: self.kind,
            canonical,
            canonical_bytes_base64,
        }
        .serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for CanonicalIdentity {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> std::result::Result<Self, D::Error> {
        let dto = CanonicalIdentityDto::deserialize(deserializer)?;
        let canonical = match (dto.canonical, dto.canonical_bytes_base64) {
            (Some(value), None) => value.into_bytes(),
            (None, Some(value)) => BASE64.decode(value).map_err(serde::de::Error::custom)?,
            _ => {
                return Err(serde::de::Error::custom(
                    "canonical identity requires exactly one byte projection",
                ))
            }
        };
        Self::from_parts(dto.kind, canonical).map_err(serde::de::Error::custom)
    }
}

impl std::hash::Hash for CanonicalIdentity {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.kind.hash(state);
        self.canonical.hash(state);
    }
}

impl PartialOrd for CanonicalIdentity {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for CanonicalIdentity {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        (self.kind, &self.canonical).cmp(&(other.kind, &other.canonical))
    }
}

impl CanonicalIdentity {
    pub fn remote(value: &str) -> Result<Self> {
        let (canonical, repository) = if let Some(shorthand) = value.strip_prefix("github:") {
            let (owner, repo) = shorthand.split_once('/').ok_or_else(|| {
                CoreError::Source("GitHub shorthand must be github:<owner>/<repo>".into())
            })?;
            if shorthand.matches('/').count() != 1
                || !github_owner(owner)
                || !github_repo(repo)
                || repo.ends_with(".git")
            {
                return Err(CoreError::Source("invalid GitHub shorthand".into()));
            }
            let expanded = format!("https://github.com/{owner}/{repo}.git");
            (expanded.clone(), expanded)
        } else if value.starts_with("https://") {
            validate_uri(value, "https")?
        } else if value.starts_with("ssh://") {
            validate_uri(value, "ssh")?
        } else {
            validate_scp(value)?
        };
        if repository.starts_with('-') {
            return Err(CoreError::Source(
                "repository operand cannot begin with `-`".into(),
            ));
        }
        Ok(Self {
            kind: SourceKind::Git,
            canonical: canonical.into_bytes(),
            repository: Some(repository),
        })
    }

    #[cfg(unix)]
    pub fn local(kind: SourceKind, path: &Path) -> Result<Self> {
        use std::os::unix::ffi::OsStrExt;

        if !path.is_absolute() {
            return Err(CoreError::Source("local identity must be absolute".into()));
        }
        Ok(Self {
            kind,
            canonical: path.as_os_str().as_bytes().to_vec(),
            repository: None,
        })
    }

    pub fn kind(&self) -> SourceKind {
        self.kind
    }

    pub fn canonical_bytes(&self) -> &[u8] {
        &self.canonical
    }

    pub fn canonical_utf8(&self) -> Option<&str> {
        std::str::from_utf8(&self.canonical).ok()
    }

    pub fn repository(&self) -> Option<&str> {
        self.repository.as_deref()
    }

    pub(crate) fn from_parts(kind: SourceKind, canonical: Vec<u8>) -> Result<Self> {
        if canonical.is_empty() {
            return Err(CoreError::Source("canonical identity is empty".into()));
        }
        let local = canonical.starts_with(b"/");
        match kind {
            SourceKind::Link if !local => {
                return Err(CoreError::Source(
                    "live canonical identity must be an absolute local path".into(),
                ));
            }
            SourceKind::Git if !local => {
                let text = std::str::from_utf8(&canonical).map_err(|_| {
                    CoreError::Source("remote canonical identity is not UTF-8".into())
                })?;
                let declared = text.strip_prefix("ssh-scp:").unwrap_or(text);
                let parsed = Self::remote(declared)?;
                if parsed.canonical != canonical {
                    return Err(CoreError::Source(
                        "remote canonical identity is not canonical".into(),
                    ));
                }
            }
            _ => {}
        }
        if local
            && canonical != b"/"
            && canonical
                .split(|byte| *byte == b'/')
                .skip(1)
                .any(|part| part.is_empty() || matches!(part, b"." | b".."))
        {
            return Err(CoreError::Source(
                "local canonical identity is not normalized".into(),
            ));
        }
        Ok(Self {
            kind,
            canonical,
            repository: None,
        })
    }
}

macro_rules! key_type {
    ($name:ident) => {
        #[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(String);

        impl $name {
            pub fn as_str(&self) -> &str {
                &self.0
            }

            pub fn parse(value: String) -> Result<Self> {
                if value.len() == 64
                    && value
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
                {
                    Ok(Self(value))
                } else {
                    Err(CoreError::Source(
                        "derived key must be lowercase SHA-256".into(),
                    ))
                }
            }
        }

        impl std::fmt::Display for $name {
            fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                formatter.write_str(&self.0)
            }
        }
    };
}

key_type!(SourceKey);
key_type!(SnapshotKey);
key_type!(ReviewKey);

impl SourceKey {
    pub fn derive(identity: &CanonicalIdentity) -> Self {
        Self(hash_key(
            b"grimoire/source-key@1",
            [
                Some(identity.kind.as_str().as_bytes()),
                Some(&identity.canonical),
            ],
        ))
    }
}

impl SnapshotKey {
    pub fn derive(kind: SourceKind, commit: &str, tree: &str, inventory: &str) -> Result<Self> {
        if kind == SourceKind::Link {
            return Err(CoreError::Source(
                "live sources do not have snapshot keys".into(),
            ));
        }
        validate_object_id(commit)?;
        validate_object_id(tree)?;
        validate_digest(inventory)?;
        Ok(Self(hash_key(
            b"grimoire/snapshot-key@1",
            [
                Some(kind.as_str().as_bytes()),
                Some(commit.as_bytes()),
                Some(tree.as_bytes()),
                Some(inventory.as_bytes()),
            ],
        )))
    }
}

impl ReviewKey {
    pub fn derive(
        kind: SourceKind,
        commit: Option<&str>,
        tree: Option<&str>,
        inventory: &str,
        review_tree: &str,
    ) -> Result<Self> {
        match kind {
            SourceKind::Git => {
                validate_object_id(
                    commit
                        .ok_or_else(|| CoreError::Source("Git review requires a commit".into()))?,
                )?;
                validate_object_id(
                    tree.ok_or_else(|| CoreError::Source("Git review requires a tree".into()))?,
                )?;
            }
            SourceKind::Link if commit.is_some() || tree.is_some() => {
                return Err(CoreError::Source(
                    "live review cannot contain Git object IDs".into(),
                ));
            }
            SourceKind::Link => {}
        }
        validate_digest(inventory)?;
        validate_digest(review_tree)?;
        Ok(Self(hash_key(
            b"grimoire/review-key@1",
            [
                Some(kind.as_str().as_bytes()),
                commit.map(str::as_bytes),
                tree.map(str::as_bytes),
                Some(inventory.as_bytes()),
                Some(review_tree.as_bytes()),
            ],
        )))
    }
}

pub fn validate_ref(value: &str) -> Result<String> {
    if (value.len() == 40 || value.len() == 64)
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
    {
        return Ok(value.to_ascii_lowercase());
    }
    if value.is_empty()
        || value.starts_with('-')
        || value.starts_with('.')
        || value.ends_with('.')
        || value.ends_with('/')
        || value.contains("..")
        || value.contains("@{")
        || value.contains("//")
        || value.bytes().any(|byte| {
            byte.is_ascii_control()
                || matches!(byte, b' ' | b'~' | b'^' | b':' | b'?' | b'*' | b'[' | b'\\')
        })
    {
        return Err(CoreError::Source("invalid Git reference".into()));
    }
    if value.starts_with("refs/") {
        if value.starts_with("refs/heads/") || value.starts_with("refs/tags/") {
            Ok(value.into())
        } else {
            Err(CoreError::Source(
                "only fully qualified heads and tags are accepted".into(),
            ))
        }
    } else if value.contains('/') {
        Err(CoreError::Source(
            "short references cannot contain `/`".into(),
        ))
    } else {
        Ok(format!("refs/heads/{value}"))
    }
}

pub(crate) fn validate_digest(value: &str) -> Result<()> {
    let Some(hex) = value.strip_prefix("sha256:") else {
        return Err(CoreError::Source("digest must use sha256:".into()));
    };
    if hex.len() != 64
        || !hex
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        return Err(CoreError::Source("digest must be lowercase SHA-256".into()));
    }
    Ok(())
}

pub(crate) fn validate_object_id(value: &str) -> Result<()> {
    if matches!(value.len(), 40 | 64)
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(())
    } else {
        Err(CoreError::Source(
            "Git object ID must be full lowercase hexadecimal".into(),
        ))
    }
}

pub(crate) fn hash_key<'a>(
    schema: &[u8],
    fields: impl IntoIterator<Item = Option<&'a [u8]>>,
) -> String {
    let mut digest = Sha256::new();
    digest.update(schema);
    digest.update([0]);
    for field in fields {
        match field {
            None => digest.update([0]),
            Some(bytes) => {
                digest.update([1]);
                digest.update((bytes.len() as u64).to_be_bytes());
                digest.update(bytes);
            }
        }
    }
    format!("{:x}", digest.finalize())
}

fn github_owner(value: &str) -> bool {
    (1..=39).contains(&value.len())
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
        && value
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphanumeric)
        && value
            .as_bytes()
            .last()
            .is_some_and(u8::is_ascii_alphanumeric)
}

fn github_repo(value: &str) -> bool {
    (1..=100).contains(&value.len())
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
        && value
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphanumeric)
        && value
            .as_bytes()
            .last()
            .is_some_and(u8::is_ascii_alphanumeric)
}

fn validate_uri(value: &str, scheme: &str) -> Result<(String, String)> {
    reject_common(value)?;
    let rest = value
        .strip_prefix(&format!("{scheme}://"))
        .ok_or_else(|| CoreError::Source("invalid source scheme".into()))?;
    let slash = rest
        .find('/')
        .ok_or_else(|| CoreError::Source("remote source requires a path".into()))?;
    let authority = &rest[..slash];
    let path = &rest[slash + 1..];
    validate_path(path, false)?;

    let (userinfo, host_port) = authority
        .rsplit_once('@')
        .map_or((None, authority), |(user, host)| (Some(user), host));
    match scheme {
        "https" if userinfo.is_some() => {
            return Err(CoreError::Source(
                "HTTPS source cannot contain userinfo".into(),
            ));
        }
        "ssh" => {
            if let Some(user) = userinfo {
                if user.is_empty()
                    || !user.bytes().all(|byte| {
                        byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-')
                    })
                {
                    return Err(CoreError::Source("invalid SSH username".into()));
                }
            }
        }
        _ => {}
    }
    let (host, port) = split_host_port(host_port)?;
    let host = normalize_host(host)?;
    let canonical_authority = match (userinfo, port) {
        (Some(user), Some(port)) => format!("{user}@{host}:{port}"),
        (Some(user), None) => format!("{user}@{host}"),
        (None, Some(port)) => format!("{host}:{port}"),
        (None, None) => host,
    };
    let canonical = format!("{scheme}://{canonical_authority}/{path}");
    Ok((canonical, value.into()))
}

fn validate_scp(value: &str) -> Result<(String, String)> {
    reject_common(value)?;
    let (left, path) = value
        .split_once(':')
        .ok_or_else(|| CoreError::Source("unsupported source location".into()))?;
    let (user, host) = left
        .split_once('@')
        .ok_or_else(|| CoreError::Source("invalid SCP source".into()))?;
    if user.is_empty()
        || !user.as_bytes()[0].is_ascii_alphanumeric()
        || !user
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'-'))
    {
        return Err(CoreError::Source("invalid SCP username".into()));
    }
    validate_path(path, true)?;
    let host = normalize_dns(host)?;
    Ok((format!("ssh-scp:{user}@{host}:{path}"), value.into()))
}

fn reject_common(value: &str) -> Result<()> {
    if value.is_empty()
        || value.starts_with('-')
        || value.contains('%')
        || value.contains('?')
        || value.contains('#')
        || value
            .bytes()
            .any(|byte| byte.is_ascii_control() || byte == b' ')
    {
        Err(CoreError::Source("invalid source location bytes".into()))
    } else {
        Ok(())
    }
}

fn validate_path(path: &str, scp: bool) -> Result<()> {
    if path.is_empty()
        || path.ends_with('/')
        || (scp && (path.starts_with('/') || path.starts_with('-')))
        || path
            .split('/')
            .any(|component| component.is_empty() || matches!(component, "." | ".."))
    {
        Err(CoreError::Source("invalid source path".into()))
    } else {
        Ok(())
    }
}

fn split_host_port(value: &str) -> Result<(&str, Option<u16>)> {
    if value.starts_with('[') {
        let end = value
            .find(']')
            .ok_or_else(|| CoreError::Source("unterminated IPv6 host".into()))?;
        let host = &value[..=end];
        let suffix = &value[end + 1..];
        let port = if suffix.is_empty() {
            None
        } else {
            Some(parse_port(suffix.strip_prefix(':').ok_or_else(|| {
                CoreError::Source("invalid IPv6 authority".into())
            })?)?)
        };
        Ok((host, port))
    } else if let Some((host, port)) = value.rsplit_once(':') {
        Ok((host, Some(parse_port(port)?)))
    } else {
        Ok((value, None))
    }
}

fn parse_port(value: &str) -> Result<u16> {
    if value.is_empty() || !value.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(CoreError::Source("invalid port".into()));
    }
    value
        .parse::<u16>()
        .map_err(|_| CoreError::Source("invalid port".into()))
}

fn normalize_host(value: &str) -> Result<String> {
    if let Some(inner) = value
        .strip_prefix('[')
        .and_then(|host| host.strip_suffix(']'))
    {
        let address = inner
            .parse::<Ipv6Addr>()
            .map_err(|_| CoreError::Source("invalid IPv6 host".into()))?;
        Ok(format!("[{address}]"))
    } else {
        normalize_dns(value)
    }
}

fn normalize_dns(value: &str) -> Result<String> {
    if value.is_empty()
        || value.ends_with('.')
        || !value.is_ascii()
        || value.split('.').any(|label| {
            label.is_empty()
                || label.len() > 63
                || !label
                    .bytes()
                    .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
                || !label
                    .as_bytes()
                    .first()
                    .is_some_and(u8::is_ascii_alphanumeric)
                || !label
                    .as_bytes()
                    .last()
                    .is_some_and(u8::is_ascii_alphanumeric)
        })
    {
        Err(CoreError::Source("invalid DNS host".into()))
    } else {
        Ok(value.to_ascii_lowercase())
    }
}
