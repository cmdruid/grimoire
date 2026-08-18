//! Appendix B: discovery. A skill directory is a directory containing
//! `SKILL.md`. Shallow discovery scans the root + fixed priority directories
//! one level deep; full-depth (used for pack enumeration and member
//! resolution, §1/§2) recurses. First-seen wins on duplicate names; identity
//! is `name:` in `SKILL.md` frontmatter, directory name as fallback.
//!
//! Appendix B leaves the recursive scan's bound to implementations. [`Ignore`]
//! is ours: a built-in floor of never-scanned directory names plus whatever
//! repo-relative paths the consumer excludes — the way a tool keeps vendored
//! clones and test fixtures (real, well-formed skill trees) out of a
//! repository's own inventory.

use crate::{PackError, Result};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct Skill {
    pub name: String,
    pub dir: PathBuf,
}

/// The priority directories scanned one level deep (Appendix B step 2).
const PRIORITY_DIRS: &[&str] = &[
    "skills",
    ".agents/skills",
    ".claude/skills",
    ".codex/skills",
];

/// Directory names skipped by every scan, at any depth (the built-in floor).
const DEFAULT_IGNORED_DIRS: &[&str] = &[".git", "node_modules", "target"];

/// Which directories a scan must not descend into.
///
/// The default is the built-in floor above. A consumer adds repo-relative
/// paths for trees that are structurally valid but are not the repository's
/// own content — conformance fixtures, vendored clones, sample repos — so they
/// neither enumerate as packs nor report issues.
#[derive(Debug, Clone, Default)]
pub struct Ignore {
    rel_paths: Vec<PathBuf>,
}

impl Ignore {
    /// The built-in floor only.
    pub fn new() -> Self {
        Self::default()
    }

    /// Also skip `path`, interpreted relative to the scan root.
    pub fn with_path(mut self, path: impl Into<PathBuf>) -> Self {
        self.rel_paths.push(path.into());
        self
    }

    /// Should the scan skip `dir` (a path under `root`)? Lexical: no
    /// canonicalization, consistent with the crate's symlink stance.
    pub fn skips(&self, root: &Path, dir: &Path) -> bool {
        if let Some(base) = dir.file_name() {
            if DEFAULT_IGNORED_DIRS.iter().any(|d| base == *d) {
                return true;
            }
        }
        let Ok(rel) = dir.strip_prefix(root) else {
            return false;
        };
        self.rel_paths.iter().any(|p| rel.starts_with(p))
    }
}

pub fn is_skill_dir(dir: &Path) -> bool {
    dir.join("SKILL.md").is_file()
}

/// Is `dir` a separate checkout? A directory holding a `.git` entry belongs to
/// another repository — a vendored clone or submodule (`.git` is a directory)
/// or a **linked worktree** (`.git` is a *file* holding a `gitdir:` pointer).
///
/// Scans never descend into one. A linked worktree placed under the repository
/// it belongs to is the sharp case: it carries a full copy of the tree, so
/// without this rule every pack in it enumerates a second time — including a
/// duplicate of the repository's own, which then wins or collides by scan
/// order. This is a filesystem question, so it lives here rather than in the
/// lexical [`Ignore`] predicate; the scan root itself is never tested (only
/// directories a walk is about to descend into).
pub fn is_nested_checkout(dir: &Path) -> bool {
    dir.join(".git").exists()
}

/// `name:` from SKILL.md frontmatter, directory basename as fallback.
/// Lenient by design: SKILL.md is a foreign format — a first `name:` line
/// inside the fence is taken as-is, malformed files fall back.
pub fn skill_name(dir: &Path) -> String {
    let fallback = || {
        dir.file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default()
    };
    let Ok(text) = fs::read_to_string(dir.join("SKILL.md")) else {
        return fallback();
    };
    let mut lines = text.lines();
    if lines.next().map(str::trim_end) != Some("---") {
        return fallback();
    }
    for line in lines {
        if line.trim_end() == "---" {
            break;
        }
        if let Some(rest) = line.strip_prefix("name:") {
            let v = rest.trim();
            if !v.is_empty() {
                return v.to_string();
            }
        }
    }
    fallback()
}

pub fn discover(root: &Path, full_depth: bool) -> Result<Vec<Skill>> {
    discover_with(root, full_depth, &Ignore::new())
}

/// [`discover`], honoring consumer ignore rules — Appendix B leaves the
/// recursive bound to implementations, and this is ours.
pub fn discover_with(root: &Path, full_depth: bool, ignore: &Ignore) -> Result<Vec<Skill>> {
    let mut found: Vec<Skill> = Vec::new();
    if is_skill_dir(root) && !full_depth {
        push(&mut found, root);
        return Ok(found);
    }
    if !full_depth {
        for child in children(root)? {
            if !ignore.skips(root, &child) && is_skill_dir(&child) {
                push(&mut found, &child);
            }
        }
        for p in PRIORITY_DIRS {
            let dir = root.join(p);
            if !dir.is_dir() {
                continue;
            }
            for child in children(&dir)? {
                if !ignore.skips(root, &child) && is_skill_dir(&child) {
                    push(&mut found, &child);
                }
            }
        }
        if !found.is_empty() {
            return Ok(found);
        }
    }
    // Full-depth (or shallow-found-nothing fallback): bounded recursive scan.
    walk(root, root, 0, ignore, &mut found)?;
    Ok(found)
}

fn push(found: &mut Vec<Skill>, dir: &Path) {
    let name = skill_name(dir);
    if !found.iter().any(|s| s.name == name) {
        found.push(Skill {
            name,
            dir: dir.to_path_buf(),
        });
    }
}

fn children(dir: &Path) -> Result<Vec<PathBuf>> {
    let rd = fs::read_dir(dir).map_err(|e| PackError::Io {
        path: dir.to_path_buf(),
        source: e,
    })?;
    // file_type() does not follow symlinks, so symlinked directories are
    // intentionally invisible here — consistent with Appendix A's symlink stance.
    let mut out: Vec<PathBuf> = rd
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map(|t| t.is_dir()).unwrap_or(false))
        .map(|e| e.path())
        .collect();
    out.sort(); // deterministic first-seen order
    Ok(out)
}

// Conservative default; Appendix B leaves the fallback bound to implementations.
pub const MAX_DEPTH: usize = 12;

fn walk(
    root: &Path,
    dir: &Path,
    depth: usize,
    ignore: &Ignore,
    found: &mut Vec<Skill>,
) -> Result<()> {
    if depth > MAX_DEPTH {
        return Ok(());
    }
    if is_skill_dir(dir) && depth > 0 {
        push(found, dir);
        // skills do not nest in discovery: don't descend into a skill dir
        return Ok(());
    }
    for child in children(dir)? {
        if ignore.skips(root, &child) || is_nested_checkout(&child) {
            continue;
        }
        walk(root, &child, depth + 1, ignore, found)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::Path;

    fn skill(root: &Path, rel: &str, name: Option<&str>) {
        let d = root.join(rel);
        fs::create_dir_all(&d).unwrap();
        let fm = match name {
            Some(n) => format!("---\nname: {n}\ndescription: t\n---\n"),
            None => "no frontmatter here".to_string(),
        };
        fs::write(d.join("SKILL.md"), fm).unwrap();
    }

    #[test]
    fn ignore_floor_covers_default_dirs_at_any_depth() {
        let ig = Ignore::new();
        let root = Path::new("/r");
        assert!(ig.skips(root, Path::new("/r/.git")));
        assert!(ig.skips(root, Path::new("/r/a/b/node_modules")));
        assert!(ig.skips(root, Path::new("/r/crates/x/target")));
        assert!(!ig.skips(root, Path::new("/r/skills/alpha")));
    }

    #[test]
    fn ignore_rel_path_covers_the_dir_and_everything_below() {
        let ig = Ignore::new().with_path("crates/grimoire-pack/tests/fixtures");
        let root = Path::new("/r");
        assert!(ig.skips(root, Path::new("/r/crates/grimoire-pack/tests/fixtures")));
        assert!(ig.skips(
            root,
            Path::new("/r/crates/grimoire-pack/tests/fixtures/faced-valid/skills/alpha")
        ));
        assert!(!ig.skips(root, Path::new("/r/crates/grimoire-pack/tests")));
        assert!(!ig.skips(root, Path::new("/r/skills/clankshop")));
    }

    #[test]
    fn ignore_never_skips_outside_the_root() {
        let ig = Ignore::new().with_path("fixtures");
        assert!(!ig.skips(Path::new("/r"), Path::new("/elsewhere/fixtures")));
    }

    #[test]
    fn root_skill_dir_is_the_sole_discovery() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), ".", Some("root-skill"));
        skill(t.path(), "skills/inner", Some("inner"));
        let found = discover(t.path(), false).unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].name, "root-skill");
    }

    #[test]
    fn priority_dirs_one_level_deep_with_name_fallback() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), "skills/alpha", Some("alpha"));
        skill(t.path(), "skills/noname", None); // falls back to dir name
        skill(t.path(), ".claude/skills/beta", Some("beta"));
        skill(t.path(), "skills/alpha/nested", Some("hidden")); // 2 levels: not seen shallow
        let names: Vec<_> = discover(t.path(), false)
            .unwrap()
            .into_iter()
            .map(|s| s.name)
            .collect();
        assert!(names.contains(&"alpha".to_string()));
        assert!(names.contains(&"noname".to_string()));
        assert!(names.contains(&"beta".to_string()));
        assert!(!names.contains(&"hidden".to_string()));
    }

    #[test]
    fn full_depth_skips_ignored_trees() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), "skills/real", Some("real"));
        skill(t.path(), "tests/fixtures/sample/skills/fake", Some("fake"));
        let ig = Ignore::new().with_path("tests/fixtures");
        let names: Vec<_> = discover_with(t.path(), true, &ig)
            .unwrap()
            .into_iter()
            .map(|s| s.name)
            .collect();
        assert!(names.contains(&"real".to_string()));
        assert!(!names.contains(&"fake".to_string()));
        // the default wrapper still sees both — behavior is unchanged there
        let all: Vec<_> = discover(t.path(), true)
            .unwrap()
            .into_iter()
            .map(|s| s.name)
            .collect();
        assert!(all.contains(&"fake".to_string()));
    }

    #[test]
    fn full_depth_finds_nested_and_first_seen_wins_on_dup_names() {
        let t = tempfile::tempdir().unwrap();
        skill(t.path(), "skills/alpha", Some("twin"));
        skill(t.path(), "skills/beta", Some("twin"));
        skill(t.path(), "deep/down/gamma", Some("gamma"));
        let found = discover(t.path(), true).unwrap();
        let twins: Vec<_> = found.iter().filter(|s| s.name == "twin").collect();
        assert_eq!(twins.len(), 1); // first-seen wins
        assert!(found.iter().any(|s| s.name == "gamma"));
    }
}
