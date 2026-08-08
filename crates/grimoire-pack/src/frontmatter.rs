//! A flat scalar frontmatter block: `key: value` lines between `---` fences.
//! Format-1 manifests are flat string scalars only (spec §2), so this parser is
//! deliberately a strict subset of YAML: `#` comment lines and blanks are
//! skipped, values may be double-quoted (protecting `#` and `:`), an unquoted
//! trailing ` #...` is stripped, and duplicate keys are an error (spec §2).

use crate::{PackError, Result};

pub fn parse(text: &str) -> Result<Vec<(String, String)>> {
    let mut lines = text.lines();
    if lines.next().map(str::trim_end) != Some("---") {
        return Err(PackError::Frontmatter("no opening --- fence".into()));
    }
    let mut pairs: Vec<(String, String)> = Vec::new();
    let mut closed = false;
    for line in lines {
        if line.trim_end() == "---" {
            closed = true;
            break;
        }
        let t = line.trim();
        if t.is_empty() || t.starts_with('#') {
            continue;
        }
        let (key, rest) = t
            .split_once(':')
            .ok_or_else(|| PackError::Frontmatter(format!("not a `key: value` line: {line}")))?;
        let key = key.trim();
        let key_ok = !key.is_empty()
            && key
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_');
        if !key_ok {
            return Err(PackError::Frontmatter(format!("bad key: {key}")));
        }
        if pairs.iter().any(|(k, _)| k == key) {
            return Err(PackError::Frontmatter(format!("duplicate key: {key}")));
        }
        let mut value = rest.trim().to_string();
        if value.len() >= 2 && value.starts_with('"') && value.ends_with('"') {
            value = value[1..value.len() - 1].to_string();
        } else if let Some(i) = value.find(" #") {
            value.truncate(i);
            let trimmed = value.trim_end().len();
            value.truncate(trimmed);
        }
        pairs.push((key.to_string(), value));
    }
    if !closed {
        return Err(PackError::Frontmatter("no closing --- fence".into()));
    }
    Ok(pairs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_flat_pairs_in_order() {
        let fm = "---\nname: alpha\nversion: 1.0.0\n---\nbody\n";
        let pairs = parse(fm).unwrap();
        assert_eq!(
            pairs,
            vec![
                ("name".to_string(), "alpha".to_string()),
                ("version".to_string(), "1.0.0".to_string())
            ]
        );
    }

    #[test]
    fn strips_quotes_comments_and_blanks() {
        let fm = "---\n# a comment\ndescription: \"One: two\"\n\nrequired: a, b  # trailing\n---\n";
        let pairs = parse(fm).unwrap();
        assert_eq!(pairs[0].1, "One: two");
        assert_eq!(pairs[1].1, "a, b");
    }

    #[test]
    fn duplicate_keys_are_an_error() {
        let fm = "---\nname: a\nname: b\n---\n";
        assert!(matches!(parse(fm), Err(crate::PackError::Frontmatter(_))));
    }

    #[test]
    fn unfenced_input_is_an_error() {
        assert!(parse("name: a\n").is_err());
        assert!(parse("---\nname: a\n").is_err()); // no closing fence
    }
}
