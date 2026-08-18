//! §1: pack shapes and enumeration. A faced pack is a skill directory that
//! also contains `PACK.md` (its `SKILL.md` is the face); a faceless pack is a
//! `PACK.md` at the repository root with no sibling `SKILL.md` —
//! manifest-only. Enumeration is a full-depth operation.
//!
//! Enumeration reports per-manifest outcomes — valid packs plus issues; one
//! broken or foreign manifest never hides the rest of the repository.

use crate::discovery::{self, Ignore, Skill};
use crate::manifest::Manifest;
use crate::{PackError, Result};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub enum PackShape {
    Faced { dir: PathBuf },
    Faceless,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Pack {
    pub manifest: Manifest,
    pub manifest_path: PathBuf,
    pub shape: PackShape,
}

/// One manifest that did not yield a valid pack, and why.
#[derive(Debug)]
pub struct Issue {
    pub manifest_path: PathBuf,
    pub error: PackError,
}

/// Everything `enumerate` learned about the repository's packs.
///
/// Dup-name note: the FIRST manifest to validate wins its name; a later
/// same-named manifest becomes an issue — so while a "two manifests declare
/// the pack name" issue is present, the surviving pack should not be treated
/// as install-ready.
#[derive(Debug, Default)]
pub struct Enumeration {
    pub packs: Vec<Pack>,
    pub issues: Vec<Issue>,
}

/// Enumerate every pack in the repository (spec §1, §2). A manifest that
/// fails validation becomes an [`Issue`] rather than aborting the whole scan
/// — [`Err`] is reserved for walk-level I/O failure.
pub fn enumerate(root: &Path) -> Result<Enumeration> {
    enumerate_with(root, &Ignore::new())
}

/// [`enumerate`], honoring consumer ignore rules — the way a consumer keeps
/// vendored clones and test fixtures (real, well-formed pack trees) out of a
/// repository's own pack list.
pub fn enumerate_with(root: &Path, ignore: &Ignore) -> Result<Enumeration> {
    let skills = discovery::discover_with(root, true, ignore)?;
    let mut manifests: Vec<PathBuf> = Vec::new();
    for s in &skills {
        let m = s.dir.join("PACK.md");
        if m.is_file() {
            manifests.push(m);
        }
    }
    // The root's own PACK.md never arrives via discovery (full-depth excludes
    // the root): push it unconditionally — validate_one decides its shape. A
    // root that is also a skill dir (root-faced) is always invalid (§1: a
    // faced pack's members live outside it), and must error loudly here
    // rather than vanish.
    let root_manifest = root.join("PACK.md");
    if root_manifest.is_file() {
        manifests.push(root_manifest);
    }
    // A PACK.md beside no SKILL.md anywhere below the root is invalid — find those too.
    find_stray_manifests(root, root, 0, ignore, &mut manifests)?;

    let mut out = Enumeration::default();
    for path in manifests {
        match validate_one(root, &path, &skills, ignore) {
            Ok(pack) => {
                if out
                    .packs
                    .iter()
                    .any(|p| p.manifest.name == pack.manifest.name)
                {
                    out.issues.push(Issue {
                        manifest_path: path,
                        error: PackError::Shape(format!(
                            "two manifests declare the pack name {}",
                            pack.manifest.name
                        )),
                    });
                } else {
                    out.packs.push(pack);
                }
            }
            Err(error) => out.issues.push(Issue {
                manifest_path: path,
                error,
            }),
        }
    }
    Ok(out)
}

fn validate_one(
    root: &Path,
    manifest_path: &Path,
    skills: &[Skill],
    ignore: &Ignore,
) -> Result<Pack> {
    let text = std::fs::read_to_string(manifest_path).map_err(|e| PackError::Io {
        path: manifest_path.to_path_buf(),
        source: e,
    })?;
    let manifest = Manifest::parse(&text)?;
    let dir = manifest_path.parent().expect("manifest has a parent");

    let shape = if discovery::is_skill_dir(dir) {
        if dir == root {
            return Err(PackError::Shape(
                "the repository root cannot be a faced pack -- a faced pack's members live outside its directory (spec 1)".into(),
            ));
        }
        // Faced: face name must equal manifest name; nothing nests below (§1).
        let face = discovery::skill_name(dir);
        if face != manifest.name {
            return Err(PackError::Shape(format!(
                "face name {face} != pack name {}",
                manifest.name
            )));
        }
        assert_nothing_nested(dir, root, ignore)?;
        if manifest.members().any(|m| m == manifest.name) {
            return Err(PackError::Shape(format!(
                "face {} must not be listed as a member (it is implicit)",
                manifest.name
            )));
        }
        PackShape::Faced {
            dir: dir.to_path_buf(),
        }
    } else {
        // Faceless: only valid at the repository root (§1).
        if dir != root {
            return Err(PackError::Shape(format!(
                "faceless PACK.md off the repository root: {}",
                manifest_path.display()
            )));
        }
        if manifest.members().any(|m| m == manifest.name) {
            return Err(PackError::Shape(format!(
                "faceless pack {} lists a member with its own name",
                manifest.name
            )));
        }
        PackShape::Faceless
    };

    for member in manifest.members() {
        if !skills.iter().any(|s| s.name == member) {
            return Err(PackError::Shape(format!(
                "member {member} does not resolve in this repository"
            )));
        }
    }
    Ok(Pack {
        manifest,
        manifest_path: manifest_path.to_path_buf(),
        shape,
    })
}

/// §1: a faced pack directory MUST NOT contain further SKILL.md or PACK.md below it.
fn assert_nothing_nested(pack_dir: &Path, root: &Path, ignore: &Ignore) -> Result<()> {
    fn walk(dir: &Path, top: bool, root: &Path, ignore: &Ignore) -> Result<()> {
        for entry in std::fs::read_dir(dir)
            .map_err(|e| PackError::Io {
                path: dir.to_path_buf(),
                source: e,
            })?
            .filter_map(|e| e.ok())
        {
            let Ok(ft) = entry.file_type() else { continue };
            let base = entry.file_name();
            if ft.is_dir() {
                if ignore.skips(root, &entry.path()) || discovery::is_nested_checkout(&entry.path())
                {
                    continue;
                }
                walk(&entry.path(), false, root, ignore)?;
            } else if ft.is_file() && !top && (base == "SKILL.md" || base == "PACK.md") {
                return Err(PackError::Shape(format!(
                    "nested {} below a faced pack dir: {}",
                    base.to_string_lossy(),
                    entry.path().display()
                )));
            }
            // symlinks and other entry types: skipped, never followed
        }
        Ok(())
    }
    walk(pack_dir, true, root, ignore)
}

/// A PACK.md that is neither beside a SKILL.md nor at the root is invalid (§1).
fn find_stray_manifests(
    root: &Path,
    dir: &Path,
    depth: usize,
    ignore: &Ignore,
    manifests: &mut Vec<PathBuf>,
) -> Result<()> {
    if depth > discovery::MAX_DEPTH {
        return Ok(());
    }
    let mut entries: Vec<_> = std::fs::read_dir(dir)
        .map_err(|e| PackError::Io {
            path: dir.to_path_buf(),
            source: e,
        })?
        .filter_map(|e| e.ok())
        .collect();
    entries.sort_by_key(|e| e.file_name());
    for entry in entries {
        let Ok(ft) = entry.file_type() else { continue };
        let base = entry.file_name();
        if ft.is_dir() {
            if ignore.skips(root, &entry.path()) || discovery::is_nested_checkout(&entry.path()) {
                continue;
            }
            find_stray_manifests(root, &entry.path(), depth + 1, ignore, manifests)?;
        } else if ft.is_file()
            && base == "PACK.md"
            && depth > 0
            && !manifests.contains(&entry.path())
        {
            manifests.push(entry.path());
        }
    }
    Ok(())
}
