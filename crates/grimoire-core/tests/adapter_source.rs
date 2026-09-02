use grimoire_core::{ManifestSource, SourceLocation};

#[test]
fn cli_source_constructor_owns_location_classification() {
    let remote = ManifestSource::from_cli("github:org/repo", Some("main".into()), false).unwrap();
    assert!(matches!(remote.location, SourceLocation::Url(_)));
    assert_eq!(remote.reference.as_deref(), Some("main"));

    let local = ManifestSource::from_cli("../skills", None, true).unwrap();
    assert!(matches!(local.location, SourceLocation::Path(_)));
    assert!(local.live);

    assert!(ManifestSource::from_cli("https://example.com/repo.git", None, true).is_err());
    assert!(ManifestSource::from_cli("./skills", Some("main".into()), true).is_err());
    assert!(ManifestSource::from_cli("http://example.com/repo", None, false).is_err());
}
