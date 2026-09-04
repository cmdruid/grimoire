use grimoire_core::{CoreError, Lockfile};

const EMPTY: &[u8] = include_bytes!("fixtures/lock/empty.json");
const FULL: &[u8] = include_bytes!("fixtures/lock/full.json");
const ALPHA: &[u8] = include_bytes!("fixtures/lock/alpha.json");

#[test]
fn canonical_goldens_round_trip_byte_and_value_exactly() {
    for bytes in [EMPTY, FULL] {
        let lock = Lockfile::parse(bytes).unwrap();
        assert_eq!(lock.to_bytes().unwrap(), bytes);
        assert_eq!(Lockfile::parse(&lock.to_bytes().unwrap()).unwrap(), lock);
    }
    assert!(FULL.ends_with(b"\n"));
    assert!(!FULL.ends_with(b"\n\n"));
}

#[test]
fn schema_three_derives_mode_from_source_kind_and_rejects_v2() {
    let body = br#"{
      "schema": "grimoire/lock@3",
      "sources": {
        "a": {
          "declared": "github:org/a",
          "kind": "git",
          "commit": "1111111111111111111111111111111111111111",
          "tree": "2222222222222222222222222222222222222222",
          "inventory": "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
        }
      },
      "packs": {},
      "skills": {
        "one": {
          "source": "a",
          "path": "skills/one",
          "content": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "requested_by": ["skill:one"]
        }
      }
    }"#;
    let lock = Lockfile::parse(body).unwrap();
    assert_eq!(
        format!("{:?}", lock.skills.values().next().unwrap().mode),
        "Link"
    );

    let v2 = String::from_utf8(body.to_vec())
        .unwrap()
        .replace("grimoire/lock@3", "grimoire/lock@2");
    let error = Lockfile::parse(v2.as_bytes()).unwrap_err();
    assert!(matches!(error, CoreError::LockSchemaUnsupported { .. }));
    assert!(error.to_string().contains("change the manifest schema"));
    assert!(error.to_string().contains("reinstall"));

    let with_mode = String::from_utf8(body.to_vec()).unwrap().replace(
        "\"source\": \"a\",",
        "\"source\": \"a\", \"mode\": \"vendor\",",
    );
    assert!(Lockfile::parse(with_mode.as_bytes()).is_err());
}

#[test]
fn noncanonical_whitespace_and_object_order_write_canonically() {
    let input = br#"{"skills":{},"packs":{},"sources":{},"schema":"grimoire/lock@3"}"#;
    assert_eq!(Lockfile::parse(input).unwrap().to_bytes().unwrap(), EMPTY);
}

#[test]
fn alpha_schema_guard_is_the_only_difference_in_the_red_proof() {
    let error = Lockfile::parse(ALPHA).unwrap_err();
    assert!(matches!(error, CoreError::LockSchemaUnsupported { .. }));
    let v1 = String::from_utf8(ALPHA.to_vec())
        .unwrap()
        .replace("grimoire/lock@alpha", "grimoire/lock@3");
    assert!(Lockfile::parse(v1.as_bytes()).is_ok());
}

#[test]
fn malformed_and_noncanonical_domain_values_are_rejected() {
    let valid = String::from_utf8(FULL.to_vec()).unwrap();
    let cases = [
        valid.replace(
            "\"tree\": \"2222222222222222222222222222222222222222\"",
            "\"tree\": \"short\"",
        ),
        valid.replace(
            "\"kind\": \"link\"",
            "\"kind\": \"link\", \"commit\": \"1111111111111111111111111111111111111111\"",
        ),
        valid.replace(
            "\"path\": \"skills/local\"",
            "\"path\": \"/derived/store/skills/local\"",
        ),
        valid.replace(
            "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
            "sha256:bad",
        ),
        valid.replace(
            "\"requested_by\": [\n        \"pack:bundle\",\n        \"skill:core\"\n      ]",
            "\"requested_by\": [\n        \"skill:core\",\n        \"pack:bundle\"\n      ]",
        ),
        valid.replace(
            "\"optional\": [\n        \"extra\",\n        \"missing\"\n      ]",
            "\"optional\": [\n        \"missing\",\n        \"extra\"\n      ]",
        ),
        valid.replace(
            "\"unavailable\": [\n        \"missing\"\n      ]",
            "\"unavailable\": [\n        \"core\"\n      ]",
        ),
        valid.replace(
            "\"source\": \"live-local\",\n      \"path\": \"skills/local\"",
            "\"source\": \"unknown\",\n      \"path\": \"skills/local\"",
        ),
        valid.replacen("\"kind\": \"link\"", "\"kind\": \"live\"", 1),
        valid.replace(
            "\"source\": \"live-local\",\n      \"path\": \"skills/local\"",
            "\"source\": \"live-local\",\n      \"mode\": \"vendor\",\n      \"path\": \"skills/local\"",
        ),
        valid.replace(
            "\"kind\": \"git\",",
            "\"kind\": \"git\", \"cache_path\": \"/tmp/cache\",",
        ),
    ];
    for case in cases {
        assert!(Lockfile::parse(case.as_bytes()).is_err(), "{case}");
    }
}

#[test]
fn duplicate_object_keys_and_array_members_are_rejected() {
    let duplicate_source = br#"{
      "schema":"grimoire/lock@3",
      "sources":{"a":{"declared":"x","kind":"link"},"a":{"declared":"y","kind":"link"}},
      "packs":{},
      "skills":{"x":{"source":"a","path":"skills/x","content":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","requested_by":["skill:x"]}}
    }"#;
    assert!(Lockfile::parse(duplicate_source).is_err());

    let duplicate_root = String::from_utf8(FULL.to_vec()).unwrap().replace(
        "\"pack:bundle\",\n        \"skill:core\"",
        "\"pack:bundle\",\n        \"pack:bundle\"",
    );
    assert!(Lockfile::parse(duplicate_root.as_bytes()).is_err());
}
