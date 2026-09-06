use grimoire_core::source::CandidateWorkflow;
use grimoire_core::{CandidateRecord, CanonicalIdentity, Paths, SourceAlias};

#[test]
fn strict_candidate_round_trips_and_cross_checks_its_source_key() {
    let candidate = CandidateRecord::new(
        "a".repeat(64),
        CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap(),
        Some("b".repeat(40)),
        Some("c".repeat(40)),
        format!("sha256:{}", "d".repeat(64)),
        format!("sha256:{}", "e".repeat(64)),
    )
    .unwrap();
    let bytes = candidate.to_bytes().unwrap();
    let expected = format!(
        concat!(
            "{{\n",
            "  \"schema\": \"grimoire/candidate@1\",\n",
            "  \"declaration_hash\": \"{}\",\n",
            "  \"source_key\": \"{}\",\n",
            "  \"kind\": \"git\",\n",
            "  \"canonical\": \"https://github.com/cmdruid/grimoire.git\",\n",
            "  \"commit\": \"{}\",\n",
            "  \"tree\": \"{}\",\n",
            "  \"inventory\": \"sha256:{}\",\n",
            "  \"review_tree\": \"sha256:{}\"\n",
            "}}\n"
        ),
        "a".repeat(64),
        candidate.source_key(),
        "b".repeat(40),
        "c".repeat(40),
        "d".repeat(64),
        "e".repeat(64),
    );
    assert_eq!(bytes, expected.as_bytes());
    assert_eq!(
        CandidateRecord::parse(&bytes, Some(&candidate.source_key())).unwrap(),
        candidate
    );

    let tampered = String::from_utf8(bytes)
        .unwrap()
        .replace(&candidate.source_key().to_string(), &"f".repeat(64));
    assert!(CandidateRecord::parse(tampered.as_bytes(), None).is_err());
}

#[test]
fn live_candidate_rejects_git_only_fields() {
    #[cfg(unix)]
    {
        use grimoire_core::SourceKind;
        use std::path::Path;

        let identity = CanonicalIdentity::local(SourceKind::Link, Path::new("/tmp/live")).unwrap();
        assert!(CandidateRecord::new(
            "a".repeat(64),
            identity,
            Some("b".repeat(40)),
            None,
            format!("sha256:{}", "d".repeat(64)),
            format!("sha256:{}", "e".repeat(64)),
        )
        .is_err());
    }
}

#[test]
fn publication_revalidates_declaration_and_preserves_the_previous_generation_when_stale() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    std::fs::create_dir_all(&project).unwrap();
    std::fs::create_dir_all(&home).unwrap();
    let manifest_bytes = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.repo]\nurl = \"github:org/repo\"\nref = \"main\"\n",
    )
    .as_bytes()
    .to_vec();
    std::fs::write(project.join("grimoire.toml"), &manifest_bytes).unwrap();
    let manifest = grimoire_core::Manifest::parse(manifest_bytes).unwrap();
    let alias = SourceAlias::new("repo").unwrap();
    let candidate = CandidateRecord::new(
        manifest.source_declaration_hash(&alias).unwrap(),
        CanonicalIdentity::remote("github:org/repo").unwrap(),
        Some("1".repeat(40)),
        Some("2".repeat(40)),
        format!("sha256:{}", "3".repeat(64)),
        format!("sha256:{}", "4".repeat(64)),
    )
    .unwrap();
    let paths = Paths::project(project.clone(), home).unwrap();
    let destination = CandidateWorkflow::begin(paths.clone(), alias.clone())
        .unwrap()
        .publish(&candidate)
        .unwrap();
    let before = std::fs::read(&destination).unwrap();

    let stale_workflow = CandidateWorkflow::begin(paths, alias).unwrap();
    std::fs::write(
        project.join("grimoire.toml"),
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.repo]\nurl = \"github:org/other\"\nref = \"main\"\n",
        ),
    )
    .unwrap();
    assert!(stale_workflow.publish(&candidate).is_err());
    assert_eq!(std::fs::read(destination).unwrap(), before);
}

#[test]
fn one_scope_rejects_two_aliases_for_the_same_identity() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    std::fs::create_dir_all(&project).unwrap();
    std::fs::create_dir_all(&home).unwrap();
    let bytes = concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.one]\nurl = \"github:org/repo\"\n",
        "[sources.two]\nurl = \"https://github.com/org/repo.git\"\n",
    )
    .as_bytes()
    .to_vec();
    std::fs::write(project.join("grimoire.toml"), &bytes).unwrap();
    let manifest = grimoire_core::Manifest::parse(bytes).unwrap();
    let alias = SourceAlias::new("one").unwrap();
    let candidate = CandidateRecord::new(
        manifest.source_declaration_hash(&alias).unwrap(),
        CanonicalIdentity::remote("github:org/repo").unwrap(),
        Some("1".repeat(40)),
        Some("2".repeat(40)),
        format!("sha256:{}", "3".repeat(64)),
        format!("sha256:{}", "4".repeat(64)),
    )
    .unwrap();
    let paths = Paths::project(project, home).unwrap();
    assert!(CandidateWorkflow::begin(paths, alias)
        .unwrap()
        .publish(&candidate)
        .is_err());
}
