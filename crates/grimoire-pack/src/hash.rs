//! Appendix A: the member content hash — byte-identical to the ecosystem's
//! skill-folder hash. Regular files only (symlinks skipped, not followed),
//! `.git`/`node_modules` pruned, `/`-joined relative paths sorted by byte
//! order, sha256 over path-bytes + content-bytes per pair, no delimiters.

use crate::{PackError, Result};
use sha2::Digest;
use std::fs;
use std::path::{Path, PathBuf};

pub fn member_hash(dir: &Path) -> Result<String> {
    let mut files: Vec<(String, PathBuf)> = Vec::new();
    collect(dir, dir, &mut files)?;
    files.sort_by(|a, b| a.0.as_bytes().cmp(b.0.as_bytes()));
    let mut h = sha2::Sha256::new();
    for (rel, abs) in &files {
        h.update(rel.as_bytes());
        h.update(fs::read(abs).map_err(|e| PackError::Io {
            path: abs.clone(),
            source: e,
        })?);
    }
    Ok(format!("sha256:{:x}", h.finalize()))
}

fn collect(base: &Path, dir: &Path, out: &mut Vec<(String, PathBuf)>) -> Result<()> {
    let entries = fs::read_dir(dir).map_err(|e| PackError::Io {
        path: dir.to_path_buf(),
        source: e,
    })?;
    for entry in entries {
        let entry = entry.map_err(|e| PackError::Io {
            path: dir.to_path_buf(),
            source: e,
        })?;
        let ft = entry.file_type().map_err(|e| PackError::Io {
            path: entry.path(),
            source: e,
        })?; // file_type() does not follow symlinks
        if ft.is_dir() {
            let name = entry.file_name();
            if name == ".git" || name == "node_modules" {
                continue;
            }
            collect(base, &entry.path(), out)?;
        } else if ft.is_file() {
            let rel = entry
                .path()
                .strip_prefix(base)
                .expect("child of base")
                .components()
                .map(|c| c.as_os_str().to_string_lossy().into_owned())
                .collect::<Vec<_>>()
                .join("/");
            out.push((rel, entry.path()));
        }
        // symlinks and other entry types: skipped (Appendix A)
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    // Computed in plan Task 7 Step 1 via install.sh's algorithm; parity anchor.
    const GOLDEN: &str = "sha256:52b6c46fc5ab6791760af51417e1f929a88dae17aeb43a07b06185d3adc4ce5d";

    fn fixture() -> tempfile::TempDir {
        let t = tempfile::tempdir().unwrap();
        fs::create_dir_all(t.path().join("sub")).unwrap();
        fs::write(t.path().join("a.txt"), "alpha\n").unwrap();
        fs::write(t.path().join("sub/b.txt"), "beta\n").unwrap();
        t
    }

    #[test]
    fn matches_the_ecosystem_hash() {
        assert_eq!(member_hash(fixture().path()).unwrap(), GOLDEN);
    }

    #[test]
    fn ignores_git_and_node_modules() {
        let t = fixture();
        fs::create_dir_all(t.path().join(".git")).unwrap();
        fs::write(t.path().join(".git/junk"), "x").unwrap();
        fs::create_dir_all(t.path().join("node_modules")).unwrap();
        fs::write(t.path().join("node_modules/junk"), "x").unwrap();
        assert_eq!(member_hash(t.path()).unwrap(), GOLDEN);
    }

    #[test]
    fn content_changes_the_hash() {
        let t = fixture();
        fs::write(t.path().join("a.txt"), "ALPHA\n").unwrap();
        assert_ne!(member_hash(t.path()).unwrap(), GOLDEN);
    }
}
