use super::super::scan::{parse_pack, parse_skill_name};
use super::super::SourcePath;

fn pack(
    body: &str,
) -> (
    Option<super::super::Pack>,
    Vec<super::super::yaml::YamlFailure>,
) {
    parse_pack(body.as_bytes(), SourcePath::from("PACK.md"))
}

fn valid(extra: &str) -> String {
    format!(
        "---\nschema: grimoire/pack@1\nname: demo\ndescription: Demo pack\nrequired:\n  - core\noptional:\n  - extra\n{extra}---\n"
    )
}

#[test]
fn exact_pure_pack_grammar_is_accepted() {
    let (pack, failures) = pack(&valid(""));
    assert!(failures.is_empty());
    let pack = pack.expect("valid pack");
    assert_eq!(pack.name, "demo");
    assert_eq!(pack.required, ["core"]);
    assert_eq!(pack.optional, ["extra"]);
}

#[test]
fn face_era_and_unknown_fields_are_hard_errors() {
    for key in ["format: 1\n", "version: 1.0.0\n", "face: demo\n"] {
        let (_, failures) = pack(&valid(key));
        assert_eq!(failures[0].code, "pack-unknown-key");
        assert_eq!(
            failures[0].details,
            [("key", key.split(':').next().unwrap().into())]
        );
    }
}

#[test]
fn comma_members_are_not_sequences() {
    let text = "---\nschema: grimoire/pack@1\nname: demo\ndescription: Demo\nrequired: core, extra\noptional: []\n---\n";
    let (_, failures) = pack(text);
    assert!(failures.iter().any(|failure| {
        failure.code == "pack-field-type"
            && failure.details
                == [
                    ("field", "required".into()),
                    ("expected", "sequence".into()),
                    ("actual", "string".into()),
                ]
    }));
}

#[test]
fn semantic_member_guards_are_exact() {
    let text = "---\nschema: grimoire/pack@1\nname: demo\ndescription: Demo\nrequired:\n  - core\n  - core\n  - Bad\noptional:\n  - core\n---\n";
    let (_, failures) = pack(text);
    let codes: Vec<_> = failures.iter().map(|failure| failure.code).collect();
    assert!(codes.contains(&"pack-member-invalid"));
    assert!(codes.contains(&"pack-member-duplicate"));
    assert!(codes.contains(&"pack-member-overlap"));
}

#[test]
fn empty_pack_and_description_are_rejected() {
    let text = "---\nschema: grimoire/pack@1\nname: demo\ndescription: ''\nrequired: []\noptional: []\n---\n";
    let (_, failures) = pack(text);
    assert_eq!(
        failures
            .iter()
            .map(|failure| failure.code)
            .collect::<Vec<_>>(),
        ["pack-description-empty", "pack-empty"]
    );
}

#[test]
fn skill_identity_comes_only_from_a_valid_name() {
    assert_eq!(
        parse_skill_name(b"---\nname: nested-skill\ndescription: ignored\n---\n").unwrap(),
        "nested-skill"
    );
    for (text, code) in [
        ("---\ndescription: none\n---\n", "skill-name-missing"),
        ("---\nname: 3\n---\n", "skill-name-type"),
        ("---\nname: Bad_Name\n---\n", "skill-name-invalid"),
    ] {
        assert_eq!(parse_skill_name(text.as_bytes()).unwrap_err().code, code);
    }
}
