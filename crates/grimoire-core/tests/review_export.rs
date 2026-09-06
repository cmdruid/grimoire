#[cfg(unix)]
mod unix {
    use std::fs;
    use std::os::unix::fs::{symlink, PermissionsExt};

    use grimoire_core::inventory::scan;
    use grimoire_core::source::{
        CanonicalIdentity, HeldDirectoryReader, ReviewExport, ReviewKey, SourceKey, SourceKind,
    };

    #[test]
    fn export_is_lossless_strict_and_object_tamper_evident() {
        let temporary = tempfile::tempdir().unwrap();
        let source = temporary.path().join("source");
        let skill = source.join("skills/one");
        fs::create_dir_all(&skill).unwrap();
        fs::write(skill.join("SKILL.md"), b"---\nname: one\n---\n").unwrap();
        symlink("../../outside", skill.join("escaping")).unwrap();

        let source = source.canonicalize().unwrap();
        let reader = HeldDirectoryReader::open(&source).unwrap();
        let inventory = scan(&reader).unwrap();
        assert!(!inventory.is_valid());
        let identity = CanonicalIdentity::local(SourceKind::Link, &source).unwrap();
        let source_key = SourceKey::derive(&identity);
        let review_key = ReviewKey::derive(
            SourceKind::Link,
            None,
            None,
            &inventory.inventory_digest.to_string(),
            &inventory.review_tree_digest.to_string(),
        )
        .unwrap();
        let export = ReviewExport::write(
            &temporary.path().join("review"),
            source_key.clone(),
            review_key.clone(),
            &inventory,
            &reader,
        )
        .unwrap();
        let index = fs::read_to_string(export.root.join("index.json")).unwrap();
        assert!(index.contains("\"owner_skill\""));
        assert!(index.contains("\"sha256\""));
        assert!(index.contains("\"target\": \"../../outside\""));
        assert!(!index.contains("boundary_path"));

        let file = export
            .entries
            .iter()
            .find_map(|entry| match &entry.payload {
                grimoire_core::source::ReviewPayload::File { digest, .. } => {
                    Some(export.object_path(digest).unwrap())
                }
                _ => None,
            })
            .unwrap();
        fs::set_permissions(&file, fs::Permissions::from_mode(0o644)).unwrap();
        assert!(ReviewExport::load(
            &export.root,
            &source_key,
            &review_key,
            &inventory.review_tree_digest.to_string(),
        )
        .is_err());
    }
}
