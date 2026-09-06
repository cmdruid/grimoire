use super::super::yaml::{frontmatter, Value, YamlFailure};

fn code(bytes: &[u8]) -> &'static str {
    frontmatter(bytes).expect_err("fixture must fail").code
}

#[test]
fn markdown_body_is_not_yaml_input() {
    let parsed = frontmatter(b"---\nname: safe\n---\n\xff\0body").expect("body is ignored");
    assert!(matches!(parsed, Value::Mapping(_)));
}

#[test]
fn envelope_failures_are_exclusive() {
    assert_eq!(code(b"name: no-fence\n"), "frontmatter-missing");
    assert_eq!(code(b"---\nname: open\n"), "frontmatter-unclosed");
    assert_eq!(
        code(b"---\na: 1\n...\nb: 2\n---\n"),
        "yaml-multiple-documents"
    );
}

#[test]
fn event_guards_report_the_first_forbidden_form() {
    let cases: &[(&[u8], &str)] = &[
        (b"---\na: &x value\nb: *x\n---\n", "yaml-anchor"),
        (b"---\na: *x\n---\n", "yaml-malformed"),
        (b"---\na: !thing value\n---\n", "yaml-tag"),
        (b"---\n<<: value\n---\n", "yaml-merge-key"),
        (b"---\n? [a, b]\n: value\n---\n", "yaml-non-string-key"),
        (b"---\na: 1\na: 2\n---\n", "yaml-duplicate-key"),
        (b"---\na: .inf\n---\n", "yaml-unsupported-scalar"),
    ];
    for (fixture, expected) in cases {
        assert_eq!(code(fixture), *expected, "fixture: {fixture:?}");
    }
}

#[test]
fn duplicate_key_carries_only_the_key_detail() {
    assert_eq!(
        frontmatter(b"---\na: 1\na: 2\n---\n").unwrap_err(),
        YamlFailure {
            code: "yaml-duplicate-key",
            details: vec![("key", "a".into())],
        }
    );
}

#[test]
fn frontmatter_byte_boundary_accepts_limit_then_rejects_limit_plus_one() {
    fn fixture(total: usize) -> Vec<u8> {
        let mut bytes = b"---\na: \"".to_vec();
        bytes.extend(std::iter::repeat_n(b'x', total - 14));
        bytes.extend_from_slice(b"\"\n---\n");
        assert_eq!(bytes.len(), total);
        bytes
    }
    frontmatter(&fixture(65_536)).expect("exact byte limit accepted");
    assert_eq!(
        frontmatter(&fixture(65_537)).unwrap_err().details,
        [("limit", "65536".into()), ("observed", "65537".into())]
    );
}

#[test]
fn node_boundary_accepts_limit_then_rejects_limit_plus_one() {
    fn fixture(items: usize) -> Vec<u8> {
        let mut text = String::from("---\n");
        for _ in 0..items {
            text.push_str("- x\n");
        }
        text.push_str("---\n");
        text.into_bytes()
    }
    frontmatter(&fixture(4_095)).expect("sequence plus 4095 scalars is 4096 nodes");
    let error = frontmatter(&fixture(4_096)).unwrap_err();
    assert_eq!(error.code, "yaml-node-limit");
    assert_eq!(error.details[1], ("observed", "4097".into()));
}

#[test]
fn depth_boundary_accepts_limit_then_rejects_limit_plus_one() {
    fn fixture(depth: usize) -> Vec<u8> {
        format!("---\n{}x{}\n---\n", "[".repeat(depth), "]".repeat(depth)).into_bytes()
    }
    frontmatter(&fixture(16)).expect("depth 16 accepted");
    let error = frontmatter(&fixture(17)).unwrap_err();
    assert_eq!(error.code, "yaml-depth-limit");
    assert_eq!(error.details[1], ("observed", "17".into()));
}
