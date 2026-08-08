//! Appendix B: discovery. A skill directory is a directory containing
//! `SKILL.md`. Shallow discovery scans the root + fixed priority directories
//! one level deep; full-depth (used for pack enumeration and member
//! resolution, §1/§2) recurses. First-seen wins on duplicate names; identity
//! is `name:` in `SKILL.md` frontmatter, directory name as fallback.

use crate::{PackError, Result};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct Skill {
    pub name: String,
    pub dir: PathBuf,
}

/// The priority directories scanned one level deep (Appendix B step 2).
const PRIORITY_DIRS: &[&str] = &["skills", ".agents/skills", ".claude/skills", ".codex/skills"];

pub fn is_skill_dir(dir: &Path) -> bool {
    dir.join("SKILL.md").is_file()
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
    let mut found: Vec<Skill> = Vec::new();
    if is_skill_dir(root) && !full_depth {
        push(&mut found, root);
        return Ok(found);
    }
    if !full_depth {
        for child in children(root)? {
            if is_skill_dir(&child) {
                push(&mut found, &child);
            }
        }
        for p in PRIORITY_DIRS {
            let dir = root.join(p);
            if !dir.is_dir() {
                continue;
            }
            for child in children(&dir)? {
                if is_skill_dir(&child) {
                    push(&mut found, &child);
                }
            }
        }
        if !found.is_empty() {
            return Ok(found);
        }
    }
    // Full-depth (or shallow-found-nothing fallback): bounded recursive scan.
    walk(root, 0, &mut found)?;
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

fn walk(dir: &Path, depth: usize, found: &mut Vec<Skill>) -> Result<()> {
    if depth > MAX_DEPTH {
        return Ok(());
    }
    if is_skill_dir(dir) && depth > 0 {
        push(found, dir);
        // skills do not nest in discovery: don't descend into a skill dir
        return Ok(());
    }
    for child in children(dir)? {
        let base = child.file_name().unwrap_or_default();
        if base == ".git" || base == "node_modules" || base == "target" {
            continue;
        }
        walk(&child, depth + 1, found)?;
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
