use super::super::unicode17::{
    normalize_nfc, to_nfkc_casefold, NFKC_CF_RANGE_COUNT, UNICODE_VERSION,
};

const DERIVED: &str = include_str!("../../../tests/data/unicode-17/DerivedNormalizationProps.txt");
const NORMALIZATION: &str = include_str!("../../../tests/data/unicode-17/NormalizationTest.txt");

fn cps(value: &str) -> String {
    value
        .split_whitespace()
        .filter_map(|part| u32::from_str_radix(part, 16).ok())
        .filter_map(char::from_u32)
        .collect()
}

fn range(value: &str) -> (u32, u32) {
    value.split_once("..").map_or_else(
        || {
            let cp = u32::from_str_radix(value, 16).unwrap();
            (cp, cp)
        },
        |(start, end)| {
            (
                u32::from_str_radix(start, 16).unwrap(),
                u32::from_str_radix(end, 16).unwrap(),
            )
        },
    )
}

#[test]
fn production_unicode_version_and_table_cardinality_are_pinned() {
    assert_eq!(UNICODE_VERSION, "17.0.0");
    assert_eq!(NFKC_CF_RANGE_COUNT, 6_183);
}

#[test]
fn every_explicit_nfkc_casefold_mapping_matches_unicode_17() {
    for line in DERIVED.lines() {
        let data = line.split('#').next().unwrap().trim();
        if data.is_empty() {
            continue;
        }
        let fields: Vec<_> = data.split(';').map(str::trim).collect();
        if fields.get(1) != Some(&"NFKC_CF") {
            continue;
        }
        let expected = normalize_nfc(&cps(fields.get(2).copied().unwrap_or_default()));
        let (start, end) = range(fields[0]);
        for cp in start..=end {
            let Some(ch) = char::from_u32(cp) else {
                continue;
            };
            assert_eq!(to_nfkc_casefold(&ch.to_string()), expected, "U+{cp:04X}");
        }
    }
}

#[test]
fn every_unicode_normalization_vector_matches_nfc() {
    for line in NORMALIZATION.lines() {
        let data = line.split('#').next().unwrap().trim();
        if data.is_empty() || data.starts_with('@') {
            continue;
        }
        let fields: Vec<_> = data.split(';').map(cps).collect();
        if fields.len() < 5 {
            continue;
        }
        assert_eq!(normalize_nfc(&fields[0]), fields[1]);
        assert_eq!(normalize_nfc(&fields[1]), fields[1]);
        assert_eq!(normalize_nfc(&fields[2]), fields[1]);
        assert_eq!(normalize_nfc(&fields[3]), fields[3]);
        assert_eq!(normalize_nfc(&fields[4]), fields[3]);
    }
}

#[test]
fn post_mapping_normalization_and_component_boundaries_are_explicit() {
    assert_eq!(to_nfkc_casefold("A\u{030A}"), "å");
    assert_eq!(to_nfkc_casefold("Straße"), "strasse");
    let separated = [to_nfkc_casefold("a"), to_nfkc_casefold("b")];
    assert_ne!(separated, [to_nfkc_casefold("ab"), String::new()]);
}
