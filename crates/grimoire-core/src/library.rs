//! The local library: a skills tree (this repo, or any Vercel-format clone).
//!
//! v0.1 is local-sources-only, so a library is just a path plus the ignore
//! rules Phase 1 added to `grimoire-pack` — the mechanism that keeps
//! conformance fixtures and vendored clones from enumerating as real content.
//!
//! `grimoire-pack` validates pack shape (§1/§2): a manifest that fails becomes
//! an [`Issue`](grimoire_pack::pack::Issue), never a pack. This module does not
//! re-validate; it maps what enumeration returned into the flat, cloneable
//! shape the TUI renders.

use std::path::{Path, PathBuf};

use grimoire_pack::discovery::{self, Ignore, Skill};
use grimoire_pack::pack::{self, PackShape};

use crate::{CoreError, Result};

/// One member of a pack, or a loose skill. **Flat**: a member's
/// pack-dependence is opaque to the app (brainstorm decision, binding) — we
/// never assume a member is framework-bound or standalone.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Member {
    pub name: String,
    pub dir: PathBuf,
    /// Classification in the manifest. The face counts as required.
    pub required: bool,
    /// The pack's face — spec §5: never adoptable, it must come from source.
    pub is_face: bool,
}

/// A pack as the app renders it.
#[derive(Debug, Clone)]
pub struct LibraryPack {
    pub name: String,
    pub version: semver::Version,
    pub description: String,
    pub faced: bool,
    /// The pack directory (faced) or the library root (faceless).
    pub dir: PathBuf,
    /// Face first (implicit member, §2), then required, then optional.
    pub members: Vec<Member>,
    /// The manifest's decoded machine surface — cached into the lock for a
    /// faceless install (§3), where there is no installed `PACK.md` to consult.
    pub manifest_fields: Vec<(String, String)>,
}

impl LibraryPack {
    /// Members to install, honoring the user's optional deselections.
    pub fn selected<'a>(&'a self, skip_optional: &'a [String]) -> impl Iterator<Item = &'a Member> {
        self.members
            .iter()
            .filter(move |m| m.required || !skip_optional.contains(&m.name))
    }
}

/// Everything one enumeration learned.
#[derive(Debug, Clone, Default)]
pub struct LibraryView {
    pub packs: Vec<LibraryPack>,
    /// Discovered skills claimed by no pack.
    pub loose: Vec<Member>,
    /// Rendered from `grimoire_pack::pack::Issue`, whose `PackError` is not
    /// `Clone` (a recorded Phase 1 limit) — Phase 3 clones app state, so the
    /// non-`Clone` type stops here.
    pub issues: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct Library {
    root: PathBuf,
    ignore: Ignore,
}

impl Library {
    /// Default ignore rules: `grimoire-pack`'s built-in floor plus the two
    /// trees a library clone typically carries that are not its own content —
    /// conformance fixtures and vendored reading clones.
    #[must_use]
    pub fn open(root: impl Into<PathBuf>) -> Self {
        Self::with_ignore(
            root,
            Ignore::new()
                .with_path("tests/fixtures")
                .with_path("crates/grimoire-pack/tests/fixtures")
                .with_path("repos"),
        )
    }

    #[must_use]
    pub fn with_ignore(root: impl Into<PathBuf>, ignore: Ignore) -> Self {
        Self {
            root: root.into(),
            ignore,
        }
    }

    #[must_use]
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// One walk: packs, loose skills, and issues.
    pub fn enumerate(&self) -> Result<LibraryView> {
        let skills = discovery::discover_with(&self.root, true, &self.ignore)?;
        let enumeration = pack::enumerate_with(&self.root, &self.ignore)?;

        let mut view = LibraryView {
            issues: enumeration
                .issues
                .iter()
                .map(|i| format!("{}: {}", i.manifest_path.display(), i.error))
                .collect(),
            ..LibraryView::default()
        };

        let mut claimed: Vec<&str> = Vec::new();
        for p in &enumeration.packs {
            let lp = self.to_library_pack(p, &skills)?;
            view.packs.push(lp);
        }
        for lp in &view.packs {
            for m in &lp.members {
                claimed.push(&m.name);
            }
        }
        view.loose = skills
            .iter()
            .filter(|s| !claimed.contains(&s.name.as_str()))
            .map(|s| Member {
                name: s.name.clone(),
                dir: s.dir.clone(),
                required: false,
                is_face: false,
            })
            .collect();
        Ok(view)
    }

    /// One pack by its manifest `name:` (never by directory name — §1 makes the
    /// manifest's name the identity, and `install.sh --pack` resolves the same
    /// way).
    pub fn resolve_pack(&self, name: &str) -> Result<LibraryPack> {
        self.enumerate()?
            .packs
            .into_iter()
            .find(|p| p.name == name)
            .ok_or_else(|| CoreError::UnknownPack(name.to_string()))
    }

    /// One skill by name, pack member or loose — what an atom install resolves.
    pub fn resolve_skill(&self, name: &str) -> Result<Member> {
        discovery::discover_with(&self.root, true, &self.ignore)?
            .into_iter()
            .find(|s| s.name == name)
            .map(|s| Member {
                name: s.name,
                dir: s.dir,
                required: false,
                is_face: false,
            })
            .ok_or_else(|| CoreError::UnknownSkill(name.to_string()))
    }

    fn to_library_pack(&self, p: &pack::Pack, skills: &[Skill]) -> Result<LibraryPack> {
        let (faced, dir) = match &p.shape {
            PackShape::Faced { dir } => (true, dir.clone()),
            // §1: a faceless manifest is only valid at the library root.
            PackShape::Faceless => (false, self.root.clone()),
        };

        let mut members = Vec::new();
        if faced {
            // §2: the face is an implicit member, and always installed.
            members.push(Member {
                name: p.manifest.name.clone(),
                dir: dir.clone(),
                required: true,
                is_face: true,
            });
        }
        for (names, required) in [(&p.manifest.required, true), (&p.manifest.optional, false)] {
            for name in names {
                let skill = skills.iter().find(|s| &s.name == name).ok_or_else(|| {
                    CoreError::UnresolvedMember {
                        pack: p.manifest.name.clone(),
                        member: name.clone(),
                    }
                })?;
                members.push(Member {
                    name: skill.name.clone(),
                    dir: skill.dir.clone(),
                    required,
                    is_face: false,
                });
            }
        }

        let mut manifest_fields = vec![
            ("name".to_string(), p.manifest.name.clone()),
            ("version".to_string(), p.manifest.version.to_string()),
            ("description".to_string(), p.manifest.description.clone()),
            ("required".to_string(), p.manifest.required.join(", ")),
        ];
        if !p.manifest.optional.is_empty() {
            manifest_fields.push(("optional".to_string(), p.manifest.optional.join(", ")));
        }
        manifest_fields.extend(p.manifest.unknown.iter().cloned());

        Ok(LibraryPack {
            name: p.manifest.name.clone(),
            version: p.manifest.version.clone(),
            description: p.manifest.description.clone(),
            faced,
            dir,
            members,
            manifest_fields,
        })
    }
}
