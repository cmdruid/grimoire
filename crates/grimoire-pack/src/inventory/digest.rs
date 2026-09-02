use sha2::{Digest as _, Sha256};

use super::{
    Boundary, Digest, Finding, Pack, ReviewedEntry, ReviewedPayload, Skill, SymlinkSafety,
};

#[cfg(test)]
pub(crate) type ContentRecord<'a> = (u8, &'a [u8], &'a [u8], &'a [u8]);

pub(crate) fn sha256(bytes: &[u8]) -> Digest {
    Digest(Sha256::digest(bytes).into())
}

pub fn compute_inventory_digest(skills: &[Skill], packs: &[Pack], findings: &[Finding]) -> Digest {
    sha256(&inventory_bytes(skills, packs, findings))
}

pub fn compute_review_tree_digest(entries: &[ReviewedEntry]) -> Digest {
    sha256(&review_tree_bytes(entries))
}

fn field(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u64).to_be_bytes());
    out.extend_from_slice(bytes);
}

#[cfg(test)]
pub(crate) fn skill_content_bytes(entries: &[ContentRecord<'_>]) -> Vec<u8> {
    let mut out = b"grimoire/skill-content@1\0".to_vec();
    for (kind, path, mode, payload) in entries {
        out.push(*kind);
        field(&mut out, path);
        field(&mut out, mode);
        field(&mut out, payload);
    }
    out
}

pub(crate) fn inventory_bytes(skills: &[Skill], packs: &[Pack], findings: &[Finding]) -> Vec<u8> {
    let mut out = b"grimoire/source-inventory@1\0".to_vec();
    for skill in skills {
        out.push(b'S');
        field(&mut out, skill.name.as_bytes());
        field(&mut out, skill.path.as_bytes());
        field(&mut out, skill.content_digest.to_string().as_bytes());
    }
    for pack in packs {
        out.push(b'P');
        field(&mut out, pack.name.as_bytes());
        field(&mut out, pack.path.as_bytes());
        field(&mut out, pack.digest.to_string().as_bytes());
    }
    for finding in findings {
        out.push(b'F');
        field(&mut out, finding.code.as_bytes());
        let mut path = Vec::new();
        match &finding.path {
            Some(value) => {
                path.push(1);
                path.extend_from_slice(value.as_bytes());
            }
            None => path.push(0),
        }
        field(&mut out, &path);
        field(&mut out, finding.severity.as_bytes());
        out.extend_from_slice(&(finding.details.len() as u64).to_be_bytes());
        for (key, value) in &finding.details {
            field(&mut out, key.as_bytes());
            field(&mut out, value.as_bytes());
        }
    }
    out
}

fn safety(value: Option<SymlinkSafety>) -> &'static [u8] {
    match value {
        None => b"",
        Some(SymlinkSafety::Internal) => b"internal",
        Some(SymlinkSafety::Escaping) => b"escaping",
        Some(SymlinkSafety::Invalid) => b"invalid",
    }
}

pub(crate) fn review_tree_bytes(entries: &[ReviewedEntry]) -> Vec<u8> {
    let mut out = b"grimoire/review-tree@1\0".to_vec();
    for entry in entries {
        field(&mut out, entry.path.as_bytes());
        let (kind, payload): (&[u8], Vec<u8>) = match &entry.payload {
            ReviewedPayload::File { digest, .. } => (b"file", digest.to_string().into_bytes()),
            ReviewedPayload::Symlink { target } => (b"symlink", target.clone()),
            ReviewedPayload::Submodule { commit } => (b"submodule", commit.as_bytes().to_vec()),
        };
        field(&mut out, kind);
        field(&mut out, entry.mode.as_bytes());
        field(&mut out, &payload);
        match &entry.boundary {
            Boundary::Snapshot => field(&mut out, b"snapshot"),
            Boundary::Skill(path) => {
                let mut boundary = b"skill".to_vec();
                boundary.push(0);
                boundary.extend_from_slice(path.as_bytes());
                field(&mut out, &boundary);
            }
        }
        field(&mut out, safety(entry.safety));
        field(
            &mut out,
            entry.reason.as_deref().unwrap_or_default().as_bytes(),
        );
    }
    out
}
