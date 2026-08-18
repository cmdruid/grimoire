//! Install: preflight as data, then the spec §5 transaction.
//!
//! Symlink semantics are `install.sh`'s (`install.sh:197-275`): a member is a
//! symlink from the target scope's skills dir to the member's directory **in
//! the library**, so the clone stays canonical and edits in it are live. The
//! upstream `skill` crate copies instead — the Phase 2 plan's *Finding 1*
//! records why that made it unusable here.
//!
//! The transaction: preflight (no mutation) → link every member, tracking what
//! this run created → write the lock. Any failure before the lock write rolls
//! the run's links back. Spec §3: "A pack's lock state is one bit" — an entry
//! exists only for a fully installed pack, never for a partial one.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use grimoire_pack::lock::{self, Lock, PackEntry, SkillEntry};

use crate::library::{Library, LibraryPack, Member};
use crate::target::Target;
use crate::time::Timestamp;
use crate::{io_err, CoreError, Result};

/// What preflight found at one member's destination.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MemberDisposition {
    /// Nothing there — link it.
    Fresh,
    /// A symlink already resolving to this exact source. A no-op, not a
    /// collision — including when it resolves through an intermediate symlink
    /// (`install.sh:210-218` compares physical paths for exactly this reason).
    AlreadyInstalled,
    /// Occupied by something else. Blocking by default: spec §5 permits a tool
    /// to resolve a collision (adopt/replace) but forbids doing it *silently*,
    /// so v0.1 reports and aborts — resolution is a TUI interaction.
    Collision {
        at: PathBuf,
        points_to: Option<PathBuf>,
        /// The face is never adoptable (§5): it must come from the pack's source.
        adoptable: bool,
    },
    /// The member does not exist in the library.
    Missing,
}

impl MemberDisposition {
    #[must_use]
    pub fn is_blocking(&self) -> bool {
        matches!(self, Self::Collision { .. } | Self::Missing)
    }
}

/// Facts about reinstalling over an existing lock entry (spec §5). Every field
/// is something the caller MUST be able to surface — §5 forbids a silent
/// version regression or source change.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReplacePlan {
    pub previous_version: String,
    pub previous_source: String,
    pub version_moves_backward: bool,
    pub source_changed: bool,
    /// Members in the old entry that the new release no longer lists.
    pub dropped: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct InstallPlan {
    pub pack: String,
    pub target: Target,
    pub members: Vec<(Member, MemberDisposition)>,
    pub replacing: Option<ReplacePlan>,
}

impl InstallPlan {
    pub fn blocking(&self) -> impl Iterator<Item = &(Member, MemberDisposition)> {
        self.members.iter().filter(|(_, d)| d.is_blocking())
    }

    #[must_use]
    pub fn is_installable(&self) -> bool {
        self.blocking().next().is_none()
    }
}

/// Inspect the destination without touching it. The TUI renders this and asks.
pub fn preflight(lib: &Library, pack: &str, target: &Target) -> Result<InstallPlan> {
    let resolved = lib.resolve_pack(pack)?;
    let mut members = Vec::new();
    for m in &resolved.members {
        members.push((m.clone(), disposition(m, target)?));
    }
    Ok(InstallPlan {
        pack: resolved.name.clone(),
        target: target.clone(),
        members,
        replacing: replace_plan(lib, target, &resolved)?,
    })
}

fn disposition(member: &Member, target: &Target) -> Result<MemberDisposition> {
    if !member.dir.join("SKILL.md").is_file() {
        return Ok(MemberDisposition::Missing);
    }
    let link = target.skills_dir.join(&member.name);
    let meta = match std::fs::symlink_metadata(&link) {
        Ok(m) => m,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(MemberDisposition::Fresh),
        Err(e) => return Err(io_err(&link, e)),
    };
    if meta.file_type().is_symlink() {
        // Physical compare, per install.sh: a chain through an intermediate
        // symlink is the same install, not a collision.
        let want = std::fs::canonicalize(&member.dir).ok();
        let got = std::fs::canonicalize(&link).ok();
        if want.is_some() && want == got {
            return Ok(MemberDisposition::AlreadyInstalled);
        }
        return Ok(MemberDisposition::Collision {
            points_to: std::fs::read_link(&link).ok(),
            at: link,
            adoptable: !member.is_face,
        });
    }
    Ok(MemberDisposition::Collision {
        at: link,
        points_to: None,
        adoptable: !member.is_face,
    })
}

fn replace_plan(
    lib: &Library,
    target: &Target,
    pack: &LibraryPack,
) -> Result<Option<ReplacePlan>> {
    let Some(existing) = read_lock(&target.lock_path)? else {
        return Ok(None);
    };
    let Some(entry) = existing.packs.get(&pack.name) else {
        return Ok(None);
    };
    let incoming: Vec<&str> = pack.members.iter().map(|m| m.name.as_str()).collect();
    Ok(Some(ReplacePlan {
        version_moves_backward: semver::Version::parse(&entry.version)
            .map(|prev| pack.version < prev)
            .unwrap_or(false),
        // §3 records a local source verbatim, so a plain path compare is the
        // right test for "this install came from somewhere else".
        source_changed: Path::new(&entry.source) != lib.root(),
        previous_version: entry.version.clone(),
        previous_source: entry.source.clone(),
        dropped: entry
            .skills
            .keys()
            .filter(|k| !incoming.contains(&k.as_str()))
            .cloned()
            .collect(),
    }))
}

/// What one install needs from its caller. Note what is *not* here: a clock and
/// a git invocation. The crate is clockless, and `source_ref` is the caller's
/// fact to supply (`install.sh` shells `git rev-parse`; core does not shell).
pub struct InstallRequest<'a> {
    pub library: &'a Library,
    pub pack: &'a str,
    pub target: &'a Target,
    pub installed_at: Timestamp,
    pub source_ref: Option<String>,
    /// Optional members the user deselected. §5: an optional member absent from
    /// the lock stays uninstalled, and its absence is never drift.
    pub skip_optional: Vec<String>,
}

#[derive(Debug, Clone, Default)]
pub struct InstallOutcome {
    pub linked: Vec<(String, PathBuf)>,
    pub already_present: Vec<String>,
    /// §5 step 4: the face is where any pack setup lives. We surface it; we
    /// never execute anything on the pack's behalf.
    pub face: Option<PathBuf>,
}

/// Install a pack transactionally (spec §5).
pub fn install(req: InstallRequest<'_>) -> Result<InstallOutcome> {
    let pack = req.library.resolve_pack(req.pack)?;
    let selected: Vec<Member> = pack.selected(&req.skip_optional).cloned().collect();

    // 1. Preflight the WHOLE member set before touching anything.
    let mut dispositions = Vec::with_capacity(selected.len());
    let mut blocking = 0usize;
    for m in &selected {
        let d = disposition(m, req.target)?;
        if d.is_blocking() {
            blocking += 1;
        }
        dispositions.push(d);
    }
    if blocking > 0 {
        return Err(CoreError::Preflight(blocking));
    }

    // 2. Link, remembering exactly what this run created.
    std::fs::create_dir_all(&req.target.skills_dir)
        .map_err(|e| io_err(&req.target.skills_dir, e))?;
    let mut created: Vec<PathBuf> = Vec::new();
    let mut outcome = InstallOutcome::default();
    for (m, d) in selected.iter().zip(&dispositions) {
        let link = req.target.skills_dir.join(&m.name);
        match d {
            MemberDisposition::AlreadyInstalled => outcome.already_present.push(m.name.clone()),
            MemberDisposition::Fresh => {
                if let Err(e) = std::os::unix::fs::symlink(&m.dir, &link) {
                    rollback(&created);
                    return Err(io_err(&link, e));
                }
                created.push(link.clone());
                outcome.linked.push((m.name.clone(), link));
            }
            // Unreachable: blocking dispositions returned above. Rolling back
            // rather than panicking keeps a future refactor honest.
            MemberDisposition::Collision { .. } | MemberDisposition::Missing => {
                rollback(&created);
                return Err(CoreError::Preflight(1));
            }
        }
    }

    // 3. Read the lock. Read-only (§3) means roll back — a linked-but-unlocked
    //    pack is precisely the "silently plausible partial pack" §5 forbids.
    let existing = match read_lock(&req.target.lock_path) {
        Ok(v) => v,
        Err(e) => {
            rollback(&created);
            return Err(e);
        }
    };

    // 4. Commit: one entry for a fully installed pack.
    let mut skills = BTreeMap::new();
    for m in &selected {
        let hash = match grimoire_pack::hash::member_hash(&m.dir) {
            Ok(h) => h,
            Err(e) => {
                rollback(&created);
                return Err(e.into());
            }
        };
        skills.insert(
            m.name.clone(),
            SkillEntry {
                hash,
                // §3: the classification AT INSTALL TIME is authoritative for
                // installed state; a later manifest edit reclassifies nothing.
                required: m.required,
                extra: serde_json::Map::new(),
            },
        );
    }
    let mut lock_data = existing.unwrap_or_default();
    lock_data.packs.insert(
        pack.name.clone(),
        PackEntry {
            version: pack.version.to_string(),
            source: req.library.root().display().to_string(),
            r#ref: req.source_ref.clone(),
            installed_at: req.installed_at.as_str().to_string(),
            skills,
            // §3: a faceless pack has no installed PACK.md, so `check` would
            // have nothing to consult — cache the manifest's machine surface.
            manifest: (!pack.faced).then(|| cached_manifest(&pack)),
            extra: serde_json::Map::new(),
        },
    );
    if let Err(e) = write_lock(&lock_data, &req.target.lock_path) {
        rollback(&created);
        return Err(e);
    }

    outcome.face = pack.faced.then(|| pack.dir.clone());
    Ok(outcome)
}

/// Install one loose skill. Same linking machinery, and deliberately **no lock
/// entry**: an atom is not a pack, and `install.sh` locks nothing for a bare
/// skill install either.
pub fn install_atom(lib: &Library, skill: &str, target: &Target) -> Result<InstallOutcome> {
    let member = lib.resolve_skill(skill)?;
    let d = disposition(&member, target)?;
    if d.is_blocking() {
        return Err(CoreError::Preflight(1));
    }
    std::fs::create_dir_all(&target.skills_dir).map_err(|e| io_err(&target.skills_dir, e))?;
    let link = target.skills_dir.join(&member.name);
    let mut outcome = InstallOutcome::default();
    match d {
        MemberDisposition::AlreadyInstalled => outcome.already_present.push(member.name.clone()),
        _ => {
            std::os::unix::fs::symlink(&member.dir, &link).map_err(|e| io_err(&link, e))?;
            outcome.linked.push((member.name.clone(), link));
        }
    }
    Ok(outcome)
}

fn cached_manifest(pack: &LibraryPack) -> serde_json::Value {
    let mut map = serde_json::Map::new();
    for (k, v) in &pack.manifest_fields {
        map.insert(k.clone(), serde_json::Value::String(v.clone()));
    }
    serde_json::Value::Object(map)
}

/// Remove exactly the links this run created — never a pre-existing one.
/// Best-effort, like `install.sh`'s `rm -f` rollback: a failure here must not
/// mask the error that triggered the rollback.
fn rollback(created: &[PathBuf]) {
    for link in created {
        let _ = std::fs::remove_file(link);
    }
}
/// `lock::read`, with §3's read-only outcome mapped to our error so callers
/// never confuse it with an I/O failure.
pub(crate) fn read_lock(path: &Path) -> Result<Option<Lock>> {
    lock::read(path).map_err(|e| match e {
        grimoire_pack::PackError::LockReadOnly(why) => CoreError::LockReadOnly(why),
        other => CoreError::Pack(other),
    })
}

/// `lock::write`, creating the lock's parent dir first — a global target's
/// `<home>/.agents/` need not exist yet (`install.sh:141` does the same
/// `mkdir -p`).
pub(crate) fn write_lock(lock_data: &Lock, path: &Path) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| io_err(parent, e))?;
    }
    Ok(lock::write(lock_data, path)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Rollback's contract: remove exactly the links this run created, and
    /// nothing else. Tested directly because a *partial* link set cannot be
    /// forced through the public API deterministically — the read-only-dir
    /// integration test fails on the first link, so it never exercises this.
    #[test]
    fn rollback_removes_only_what_this_run_created() {
        let tmp = tempfile::tempdir().unwrap();
        let source = tmp.path().join("source");
        std::fs::create_dir_all(&source).unwrap();

        let mine = tmp.path().join("mine");
        let bystander = tmp.path().join("bystander");
        std::os::unix::fs::symlink(&source, &mine).unwrap();
        std::os::unix::fs::symlink(&source, &bystander).unwrap();

        rollback(std::slice::from_ref(&mine));

        assert!(!mine.exists(), "this run's link should be gone");
        assert!(
            std::fs::symlink_metadata(&bystander).is_ok(),
            "a link this run did not create must survive"
        );
        assert!(source.is_dir(), "rollback must never touch the library");
    }

    /// A link that vanished before rollback ran is not an error to propagate —
    /// best-effort, like `install.sh`'s `rm -f`.
    #[test]
    fn rollback_tolerates_an_already_missing_link() {
        let tmp = tempfile::tempdir().unwrap();
        rollback(&[tmp.path().join("never-existed")]);
    }
}
