//! What is installed at one target.
//!
//! Spec §3: every operation targets **exactly one scope**, so this answers for
//! one `Target` only. §3's display rule — project shadows global per pack name
//! — is the caller's composition of two targets, deliberately not folded in
//! here (folding it in would make "which scope am I looking at?" unanswerable).

use std::path::PathBuf;

use grimoire_pack::lock::PackEntry;

use crate::install::read_lock;
use crate::target::Target;
use crate::{io_err, Result};

#[derive(Debug, Clone)]
pub struct InstalledPack {
    pub name: String,
    pub entry: PackEntry,
    /// Does the pack directory still exist? (§5's *orphaned* input.)
    pub dir_present: bool,
}

#[derive(Debug, Clone)]
pub struct InstalledMember {
    pub name: String,
    pub link: PathBuf,
    /// Where the link points, resolved. `None` for a broken link — reported
    /// rather than hidden, because a broken link is a fact the user needs.
    pub resolves_to: Option<PathBuf>,
}

#[derive(Debug, Clone, Default)]
pub struct Inventory {
    pub packs: Vec<InstalledPack>,
    /// Links in the skills dir claimed by no pack entry in this scope's lock.
    pub loose: Vec<InstalledMember>,
}

/// Read one target's installed state: its lock's packs, plus the links on disk.
pub fn inventory(target: &Target) -> Result<Inventory> {
    let mut out = Inventory::default();
    let lock = read_lock(&target.lock_path)?;

    let mut claimed: Vec<String> = Vec::new();
    if let Some(lock) = lock {
        for (name, entry) in lock.packs {
            claimed.extend(entry.skills.keys().cloned());
            out.packs.push(InstalledPack {
                dir_present: target.skills_dir.join(&name).exists(),
                name,
                entry,
            });
        }
    }

    match std::fs::read_dir(&target.skills_dir) {
        Ok(entries) => {
            for entry in entries.filter_map(std::result::Result::ok) {
                let name = entry.file_name().to_string_lossy().into_owned();
                if claimed.contains(&name) {
                    continue;
                }
                let link = entry.path();
                let is_link = std::fs::symlink_metadata(&link)
                    .map(|m| m.file_type().is_symlink())
                    .unwrap_or(false);
                if !is_link {
                    continue; // a real directory here is not an install of ours
                }
                out.loose.push(InstalledMember {
                    resolves_to: std::fs::canonicalize(&link).ok(),
                    name,
                    link,
                });
            }
        }
        // A scope with nothing installed yet has no skills dir. Not an error.
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
        Err(e) => return Err(io_err(&target.skills_dir, e)),
    }

    out.loose.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}
