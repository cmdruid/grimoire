//! Check: facts, not verdicts (spec §5).
//!
//! | Fact | §5's meaning |
//! |---|---|
//! | required member missing | *broken* — offer reinstall |
//! | member hash ≠ locked hash | *moved since install* — offer re-pin or reinstall |
//! | optional member absent | *fine* |
//! | faced pack's installed manifest missing | *orphaned* — offer removal or reinstall |
//!
//! Local only: "`check` needs neither network access nor the pack's source;
//! every input above is local." A faced pack consults its **installed**
//! `PACK.md`; a faceless pack consults the manifest cached in the lock (§3).

use crate::install::read_lock;
use crate::library::Library;
use crate::target::Target;
use crate::Result;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Finding {
    /// *broken*
    RequiredMemberMissing { pack: String, member: String },
    /// *moved since install* — §4: hashes are authoritative over version, and a
    /// mismatch is a fact for `check`, not an error.
    MemberMoved {
        pack: String,
        member: String,
        locked: String,
        actual: String,
    },
    /// *fine* — reported so a UI can show it, never as drift.
    OptionalMemberAbsent { pack: String, member: String },
    /// *orphaned*
    OrphanedPack { pack: String },
    /// §5 shared members: two packs locking different hashes for one member.
    /// Format 1 defines no resolution — last install won the bytes on disk.
    SharedMemberDisagreement { member: String, packs: Vec<String> },
}

#[derive(Debug, Clone, Default)]
pub struct CheckReport {
    pub findings: Vec<Finding>,
    /// Enumeration issues from the library itself, rendered for display.
    pub library_issues: Vec<String>,
}

impl CheckReport {
    /// Anything that is not *fine*.
    #[must_use]
    pub fn is_clean(&self) -> bool {
        !self
            .findings
            .iter()
            .any(|f| !matches!(f, Finding::OptionalMemberAbsent { .. }))
    }
}

/// Compare one target's lock against that scope's installed skills.
pub fn check(lib: &Library, target: &Target) -> Result<CheckReport> {
    let mut report = CheckReport {
        library_issues: lib.enumerate()?.issues,
        ..CheckReport::default()
    };
    let Some(lock) = read_lock(&target.lock_path)? else {
        return Ok(report);
    };

    // Shared-member disagreement: gather (member -> [(pack, locked hash)]).
    let mut seen: Vec<(String, Vec<(String, String)>)> = Vec::new();

    for (pack_name, entry) in &lock.packs {
        // A faced pack's own directory carries its installed manifest; its
        // absence is *orphaned*. A faceless pack has no directory to lose —
        // its manifest is cached in the lock, so it cannot be orphaned this way.
        let faced = entry.skills.contains_key(pack_name);
        if faced && !target.skills_dir.join(pack_name).join("PACK.md").exists() {
            report.findings.push(Finding::OrphanedPack {
                pack: pack_name.clone(),
            });
        }

        for (member, locked) in &entry.skills {
            match seen.iter_mut().find(|(m, _)| m == member) {
                Some((_, packs)) => packs.push((pack_name.clone(), locked.hash.clone())),
                None => seen.push((
                    member.clone(),
                    vec![(pack_name.clone(), locked.hash.clone())],
                )),
            }

            let installed = target.skills_dir.join(member);
            if !installed.exists() {
                report.findings.push(if locked.required {
                    Finding::RequiredMemberMissing {
                        pack: pack_name.clone(),
                        member: member.clone(),
                    }
                } else {
                    Finding::OptionalMemberAbsent {
                        pack: pack_name.clone(),
                        member: member.clone(),
                    }
                });
                continue;
            }
            let actual = grimoire_pack::hash::member_hash(&installed)?;
            if actual != locked.hash {
                report.findings.push(Finding::MemberMoved {
                    pack: pack_name.clone(),
                    member: member.clone(),
                    locked: locked.hash.clone(),
                    actual,
                });
            }
        }
    }

    for (member, packs) in seen {
        let distinct: Vec<&String> = {
            let mut hashes: Vec<&String> = packs.iter().map(|(_, h)| h).collect();
            hashes.sort();
            hashes.dedup();
            hashes
        };
        if packs.len() > 1 && distinct.len() > 1 {
            report.findings.push(Finding::SharedMemberDisagreement {
                member,
                packs: packs.into_iter().map(|(p, _)| p).collect(),
            });
        }
    }

    Ok(report)
}
