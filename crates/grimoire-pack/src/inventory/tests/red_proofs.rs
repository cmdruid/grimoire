use yaml_rust2::YamlLoader;

use super::super::scan::{parse_pack, parse_skill_name};
use super::super::yaml::frontmatter;
use super::super::SourcePath;

fn raw_yaml_accepts(yaml: &str) {
    YamlLoader::load_from_str(yaml).expect("upstream parser accepts the construct without policy");
}

#[test]
fn red_proof_event_policy_is_not_upstream_default() {
    for yaml in [
        "a: &x value\nb: *x\n",
        "a: !thing value\n",
        "<<: value\n",
        "? [a, b]\n: value\n",
        "a: .inf\n",
    ] {
        raw_yaml_accepts(yaml);
        assert!(frontmatter(format!("---\n{yaml}---\n").as_bytes()).is_err());
    }
}

#[test]
fn red_proof_pack_schema_unknown_key_and_slug_are_not_yaml_rules() {
    let yaml = "schema: old\nname: Bad_Name\ndescription: Demo\nrequired: []\noptional: [valid]\nextra: true\n";
    raw_yaml_accepts(yaml);
    let (pack, failures) = parse_pack(
        format!("---\n{yaml}---\n").as_bytes(),
        SourcePath::from("PACK.md"),
    );
    assert!(pack.is_none());
    for code in [
        "pack-schema-invalid",
        "pack-name-invalid",
        "pack-unknown-key",
    ] {
        assert!(failures.iter().any(|failure| failure.code == code));
    }
}

#[test]
fn red_proof_skill_slug_is_not_directory_or_yaml_fallback() {
    raw_yaml_accepts("name: Bad_Name\n");
    assert_eq!(
        parse_skill_name(b"---\nname: Bad_Name\n---\n")
            .unwrap_err()
            .code,
        "skill-name-invalid"
    );
}

#[test]
fn red_proof_fixed_limits_reject_what_the_parser_would_accept() {
    let deep = format!("{}x{}", "[".repeat(17), "]".repeat(17));
    raw_yaml_accepts(&deep);
    assert_eq!(
        frontmatter(format!("---\n{deep}\n---\n").as_bytes())
            .unwrap_err()
            .code,
        "yaml-depth-limit"
    );

    let many = "- x\n".repeat(4_096);
    raw_yaml_accepts(&many);
    assert_eq!(
        frontmatter(format!("---\n{many}---\n").as_bytes())
            .unwrap_err()
            .code,
        "yaml-node-limit"
    );
}
