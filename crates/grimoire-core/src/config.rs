//! The tiny config: one key, the default library path.
//!
//! TOML, hand-editable. Parsed by a single-key reader rather than adding
//! `toml` + `serde`: v0.1 has exactly one key and the dependency floor is an
//! invariant (`tests/boundary.rs`). Unknown keys are preserved verbatim on
//! save — the same posture the pack format takes toward keys it does not know.
//! When a second structured key arrives, adopt `toml` then.

use std::path::{Path, PathBuf};

use crate::{io_err, CoreError, Result};

const FILE: &str = "config.toml";
const DIR: &str = "grimoire";

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Config {
    pub library: Option<PathBuf>,
    /// Lines we did not interpret, kept so `save` never eats a key it does not
    /// understand.
    unknown: Vec<String>,
}

/// `<config_home>/grimoire/config.toml`. `config_home` is a **parameter** —
/// the crate reads no environment; the binary passes XDG's.
#[must_use]
pub fn config_path(config_home: &Path) -> PathBuf {
    config_home.join(DIR).join(FILE)
}

/// An absent file is not an error: it is the default config.
pub fn load(config_home: &Path) -> Result<Config> {
    let path = config_path(config_home);
    let text = match std::fs::read_to_string(&path) {
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Config::default()),
        Err(e) => return Err(io_err(&path, e)),
    };
    parse(&text, &path)
}

pub fn save(config_home: &Path, config: &Config) -> Result<()> {
    let path = config_path(config_home);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| io_err(parent, e))?;
    }
    let mut out = String::new();
    if let Some(library) = &config.library {
        out.push_str(&format!("library = \"{}\"\n", library.display()));
    }
    for line in &config.unknown {
        out.push_str(line);
        out.push('\n');
    }
    std::fs::write(&path, out).map_err(|e| io_err(&path, e))
}

fn parse(text: &str, path: &Path) -> Result<Config> {
    let mut config = Config::default();
    for (n, line) in text.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            config.unknown.push(line.to_string());
            continue;
        }
        let Some((key, value)) = trimmed.split_once('=') else {
            return Err(CoreError::Config {
                path: path.to_path_buf(),
                reason: format!("line {}: not a `key = value` pair", n + 1),
            });
        };
        if key.trim() != "library" {
            config.unknown.push(line.to_string());
            continue;
        }
        let value = value.trim();
        let unquoted = value
            .strip_prefix('"')
            .and_then(|v| v.strip_suffix('"'))
            .ok_or_else(|| CoreError::Config {
                path: path.to_path_buf(),
                reason: format!("line {}: library must be a quoted string", n + 1),
            })?;
        config.library = Some(PathBuf::from(unquoted));
    }
    Ok(config)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn absent_file_is_the_default() {
        let tmp = tempfile::tempdir().unwrap();
        assert_eq!(load(tmp.path()).unwrap(), Config::default());
    }

    #[test]
    fn round_trips_the_library_path() {
        let tmp = tempfile::tempdir().unwrap();
        let config = Config {
            library: Some(PathBuf::from("/home/u/Repos/grimoire")),
            unknown: Vec::new(),
        };
        save(tmp.path(), &config).unwrap();
        assert_eq!(load(tmp.path()).unwrap().library, config.library);
        assert_eq!(
            config_path(tmp.path()),
            tmp.path().join("grimoire/config.toml")
        );
    }

    #[test]
    fn unknown_keys_survive_a_save() {
        let tmp = tempfile::tempdir().unwrap();
        let path = config_path(tmp.path());
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, "# a note\nlibrary = \"/lib\"\nfuture = 3\n").unwrap();

        let loaded = load(tmp.path()).unwrap();
        assert_eq!(loaded.library, Some(PathBuf::from("/lib")));
        save(tmp.path(), &loaded).unwrap();

        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("future = 3"), "unknown key was eaten: {text}");
        assert!(text.contains("# a note"), "comment was eaten: {text}");
    }

    #[test]
    fn a_malformed_line_is_an_error_not_a_panic() {
        let tmp = tempfile::tempdir().unwrap();
        let path = config_path(tmp.path());
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, "library\n").unwrap();
        assert!(matches!(
            load(tmp.path()),
            Err(CoreError::Config { .. })
        ));
    }

    #[test]
    fn an_unquoted_library_value_is_an_error() {
        let tmp = tempfile::tempdir().unwrap();
        let path = config_path(tmp.path());
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, "library = /lib\n").unwrap();
        assert!(matches!(load(tmp.path()), Err(CoreError::Config { .. })));
    }
}
