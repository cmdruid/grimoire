//! Remove: reference-counted at pack altitude (spec §5).
//!
//! "delete members not referenced by another installed pack's lock entry **in
//! the same scope**, then drop the lock entry." Plus `install.sh`'s ownership
//! rule (`install.sh:253-262`): a link that does not point into a library is
//! another tool's, and we report it rather than deleting it.

use std::path::{Path, PathBuf};

use crate::install::{read_lock, write_lock};
use crate::target::Target;
use crate::{io_err, CoreError, Result};

#[derive(Debug, Clone, Default)]
pub struct RemovePlan {
    pub pack: String,
    /// Members to unlink: referenced by no other pack entry in this scope.
    pub unlink: Vec<(String, PathBuf)>,
    /// (member, the pack that still references it) — left in place.
    pub retained: Vec<(String, String)>,
    /// Links that do not point into a library — reported, never touched.
    pub foreign: Vec<(String, PathBuf)>,
    /// §5: the tool MUST surface, **before** deleting anything, that pack setup
    /// artifacts may persist, and SHOULD relay the face's teardown guidance
    /// while the face still exists.
    pub face_warning: Option<PathBuf>,
}

/// Compute the removal without performing it.
pub fn plan_remove(target: &Target, pack: &str) -> Result<RemovePlan> {
    let lock = read_lock(&target.lock_path)?
        .ok_or_else(|| CoreError::NotInstalled(pack.to_string()))?;
    let entry = lock
        .packs
        .get(pack)
        .ok_or_else(|| CoreError::NotInstalled(pack.to_string()))?;

    let mut plan = RemovePlan {
        pack: pack.to_string(),
        ..RemovePlan::default()
    };

    for member in entry.skills.keys() {
        let link = target.skills_dir.join(member);
        // Refcount at pack altitude: any OTHER entry in this scope's lock.
        if let Some((other, _)) = lock
            .packs
            .iter()
            .find(|(name, e)| name.as_str() != pack && e.skills.contains_key(member))
        {
            plan.retained.push((member.clone(), other.clone()));
            continue;
        }
        match std::fs::symlink_metadata(&link) {
            Ok(meta) if meta.file_type().is_symlink() => {
                if owned_by(&link, Path::new(&entry.source)) {
                    plan.unlink.push((member.clone(), link));
                } else {
                    plan.foreign.push((member.clone(), link));
                }
            }
            // Already gone, or not a symlink: nothing for us to unlink. A
            // missing required member is `check`'s *broken* fact, not an error
            // to raise while tearing down.
            Ok(_) | Err(_) => {}
        }
    }

    let face = target.skills_dir.join(pack);
    if entry.skills.contains_key(pack) && face.exists() {
        plan.face_warning = Some(face);
    }
    Ok(plan)
}

/// Does `link` point into `source` — i.e. is this link ours to remove?
///
/// Two comparisons, because either can be the honest one:
///
/// - **Canonical** — both sides fully resolved, so a prefix that is itself a
///   symlink (`/var` → `/private/var` on macOS; a symlinked library path)
///   cannot make an owned link look foreign.
/// - **Literal** — the raw `readlink` target against the recorded source,
///   exactly `install.sh:255-259`'s test. This is the arm that still works when
///   the library has been deleted or moved, where canonicalizing a now-broken
///   link fails and the canonical arm goes silent.
///
/// Ownership means *either* holds: a link we created satisfies both while the
/// library is in place, and only the literal one once it is gone.
fn owned_by(link: &Path, source: &Path) -> bool {
    let canonical_source = std::fs::canonicalize(source).unwrap_or_else(|_| source.to_path_buf());
    let canonical_match = std::fs::canonicalize(link)
        .map(|resolved| resolved.starts_with(&canonical_source))
        .unwrap_or(false);
    let literal_match = std::fs::read_link(link)
        .map(|to| to.starts_with(source))
        .unwrap_or(false);
    canonical_match || literal_match
}

/// Execute a plan: unlink, then drop the lock entry.
pub fn remove(target: &Target, plan: &RemovePlan) -> Result<()> {
    for (_, link) in &plan.unlink {
        match std::fs::remove_file(link) {
            Ok(()) => {}
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(io_err(link, e)),
        }
    }
    let Some(mut lock) = read_lock(&target.lock_path)? else {
        return Ok(());
    };
    lock.packs.remove(&plan.pack);
    write_lock(&lock, &target.lock_path)
}

/// Remove one **optional** member (§5): "leaves no trace — drop the member
/// entry from the lock, remove the skill if unreferenced." The pack stays
/// installed, and the member may be reinstalled later from the pack's source.
pub fn remove_optional_member(target: &Target, pack: &str, member: &str) -> Result<()> {
    let mut lock = read_lock(&target.lock_path)?
        .ok_or_else(|| CoreError::NotInstalled(pack.to_string()))?;
    {
        let entry = lock
            .packs
            .get(pack)
            .ok_or_else(|| CoreError::NotInstalled(pack.to_string()))?;
        match entry.skills.get(member) {
            // §5 defines no tool operation for removing a REQUIRED member —
            // that is a state `check` reports as broken, so refuse here.
            Some(s) if s.required => {
                return Err(CoreError::Preflight(1));
            }
            None => return Err(CoreError::NotInstalled(member.to_string())),
            Some(_) => {}
        }
        let referenced_elsewhere = lock
            .packs
            .iter()
            .any(|(name, e)| name.as_str() != pack && e.skills.contains_key(member));
        if !referenced_elsewhere {
            let link = target.skills_dir.join(member);
            match std::fs::remove_file(&link) {
                Ok(()) => {}
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                Err(e) => return Err(io_err(&link, e)),
            }
        }
    }
    if let Some(entry) = lock.packs.get_mut(pack) {
        entry.skills.remove(member);
    }
    write_lock(&lock, &target.lock_path)
}
