//! The `PACK.md` machine surface: frontmatter model + §2 grammar validation.

use crate::{frontmatter, PackError, Result};

pub const FORMAT: u64 = 1;

#[derive(Debug, Clone, PartialEq)]
pub struct Manifest {
    pub name: String,
    pub version: semver::Version,
    pub description: String,
    pub required: Vec<String>,
    pub optional: Vec<String>,
    /// Declared format revision; `None` means absent = format 1 (spec §2).
    pub format: Option<u64>,
    /// Keys this format does not claim, in file order (spec §2: preserved).
    pub unknown: Vec<(String, String)>,
}

/// Skill-name grammar: `[a-z0-9-]+` (spec §2).
pub fn is_valid_name(s: &str) -> bool {
    !s.is_empty()
        && s.chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

fn split_list(key: &str, raw: &str) -> Result<Vec<String>> {
    let mut out = Vec::new();
    for tok in raw.split(',') {
        let t = tok.trim();
        if t.is_empty() {
            return Err(PackError::Manifest(format!("{key}: empty token")));
        }
        if !is_valid_name(t) {
            return Err(PackError::Manifest(format!("{key}: bad skill name: {t}")));
        }
        out.push(t.to_string());
    }
    Ok(out)
}

impl Manifest {
    /// Parse and validate a `PACK.md`'s machine surface per §2.
    ///
    /// A manifest declaring a `format:` this library does not implement fails
    /// with [`PackError::UnsupportedFormat`] *before* grammar validation — a
    /// foreign revision's grammar is unknown here, so no validated `Manifest`
    /// can honestly be constructed from it. Spec §2 permits tools to still
    /// enumerate/display such packs; a tool wanting that reads the raw
    /// [`crate::frontmatter`] pairs itself (name/version at face value, no
    /// grammar claims).
    pub fn parse(text: &str) -> Result<Manifest> {
        let pairs = frontmatter::parse(text)?;
        // The format gate runs before everything else: a foreign revision's
        // grammar is unknown, so no other key is validated until the revision
        // is known to be ours (doc comment above; spec 2).
        let mut format = None;
        for (k, v) in &pairs {
            if k == "format" {
                let n: u64 = v
                    .parse()
                    .map_err(|_| PackError::Manifest(format!("format: not an integer: {v}")))?;
                if n == 0 {
                    return Err(PackError::Manifest("format: must be positive".into()));
                }
                if n != FORMAT {
                    return Err(PackError::UnsupportedFormat(n));
                }
                format = Some(n);
            }
        }
        let mut name = None;
        let mut version = None;
        let mut description = None;
        let mut required = None;
        let mut optional = Vec::new();
        let mut unknown = Vec::new();
        for (k, v) in pairs {
            match k.as_str() {
                "name" => name = Some(v),
                "version" => version = Some(v),
                "description" => description = Some(v),
                "required" => required = Some(split_list("required", &v)?),
                "optional" => optional = split_list("optional", &v)?,
                "format" => {}
                _ => unknown.push((k, v)),
            }
        }
        let name = name.ok_or_else(|| PackError::Manifest("name: missing".into()))?;
        if !is_valid_name(&name) {
            return Err(PackError::Manifest(format!("name: bad pack name: {name}")));
        }
        let version = version.ok_or_else(|| PackError::Manifest("version: missing".into()))?;
        let version = semver::Version::parse(&version)
            .map_err(|e| PackError::Manifest(format!("version: not semver: {e}")))?;
        let description =
            description.ok_or_else(|| PackError::Manifest("description: missing".into()))?;
        let required = required.ok_or_else(|| PackError::Manifest("required: missing".into()))?;
        let mut seen = std::collections::HashSet::new();
        for n in required.iter().chain(optional.iter()) {
            if !seen.insert(n.as_str()) {
                return Err(PackError::Manifest(format!("member listed twice: {n}")));
            }
        }
        Ok(Manifest {
            name,
            version,
            description,
            required,
            optional,
            format,
            unknown,
        })
    }

    /// All declared members, required first (the face is NOT in this list — it
    /// is implicit, spec §2).
    pub fn members(&self) -> impl Iterator<Item = &str> {
        self.required
            .iter()
            .chain(self.optional.iter())
            .map(String::as_str)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const OK: &str = "---\nname: clank\nversion: 1.2.3\ndescription: \"a pack\"\nrequired: alpha, beta\noptional: gamma\ncore: clank, alpha\n---\nbody\n";

    #[test]
    fn parses_a_valid_manifest() {
        let m = Manifest::parse(OK).unwrap();
        assert_eq!(m.name, "clank");
        assert_eq!(m.version.to_string(), "1.2.3");
        assert_eq!(m.required, vec!["alpha", "beta"]);
        assert_eq!(m.optional, vec!["gamma"]);
        assert_eq!(m.format, None);
        assert_eq!(
            m.unknown,
            vec![("core".to_string(), "clank, alpha".to_string())]
        );
    }

    #[test]
    fn format_absent_means_one_and_present_must_be_positive_int() {
        let m = Manifest::parse(&OK.replace("core: clank, alpha", "format: 1")).unwrap();
        assert_eq!(m.format, Some(1));
        assert!(Manifest::parse(&OK.replace("core: clank, alpha", "format: 0")).is_err());
        assert!(Manifest::parse(&OK.replace("core: clank, alpha", "format: x")).is_err());
    }

    #[test]
    fn unsupported_format_is_a_typed_error() {
        let e = Manifest::parse(&OK.replace("core: clank, alpha", "format: 2")).unwrap_err();
        assert!(matches!(e, crate::PackError::UnsupportedFormat(2)));
    }

    #[test]
    fn unsupported_format_gates_before_grammar() {
        let bad_grammar = OK
            .replace("core: clank, alpha", "format: 2")
            .replace("alpha, beta", "Alpha!");
        let e = Manifest::parse(&bad_grammar).unwrap_err();
        assert!(matches!(e, crate::PackError::UnsupportedFormat(2)));
    }

    #[test]
    fn grammar_violations_are_errors() {
        // empty token
        assert!(Manifest::parse(&OK.replace("alpha, beta", "alpha,, beta")).is_err());
        // bad name chars
        assert!(Manifest::parse(&OK.replace("alpha, beta", "Alpha")).is_err());
        // dup across the two lists
        assert!(Manifest::parse(&OK.replace("optional: gamma", "optional: alpha")).is_err());
        // required: missing entirely
        assert!(Manifest::parse(&OK.replace("required: alpha, beta\n", "")).is_err());
        // bad semver
        assert!(Manifest::parse(&OK.replace("1.2.3", "1.2")).is_err());
    }

    #[test]
    fn duplicate_within_one_list_is_an_error() {
        assert!(Manifest::parse(&OK.replace("alpha, beta", "alpha, alpha")).is_err());
    }
}
