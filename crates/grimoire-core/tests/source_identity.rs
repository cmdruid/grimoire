use std::path::Path;

use grimoire_core::{CanonicalIdentity, ReviewKey, SnapshotKey, SourceKey, SourceKind};

#[test]
fn remote_identity_is_conservative_and_rejects_option_shaped_inputs() {
    let github = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    assert_eq!(
        github.repository(),
        Some("https://github.com/cmdruid/grimoire.git")
    );
    assert_eq!(
        github.canonical_utf8(),
        Some("https://github.com/cmdruid/grimoire.git")
    );

    let scp = CanonicalIdentity::remote("git@Example.com:Org/Repo.git").unwrap();
    assert_eq!(
        scp.canonical_utf8(),
        Some("ssh-scp:git@example.com:Org/Repo.git")
    );
    assert!(CanonicalIdentity::remote("-git@example.com:repo").is_err());
    assert!(CanonicalIdentity::remote("git@example.com:-repo").is_err());
    assert!(CanonicalIdentity::remote("file:///tmp/repo").is_err());
    assert!(CanonicalIdentity::remote("https://user@example.com/repo").is_err());
}

#[test]
fn source_snapshot_and_review_keys_use_distinct_framed_domains() {
    let identity = CanonicalIdentity::remote("https://example.com/org/repo.git").unwrap();
    let source = SourceKey::derive(&identity);
    let snapshot = SnapshotKey::derive(
        SourceKind::Git,
        &"1".repeat(40),
        &"2".repeat(40),
        &format!("sha256:{}", "3".repeat(64)),
    )
    .unwrap();
    let review = ReviewKey::derive(
        SourceKind::Git,
        Some(&"1".repeat(40)),
        Some(&"2".repeat(40)),
        &format!("sha256:{}", "3".repeat(64)),
        &format!("sha256:{}", "4".repeat(64)),
    )
    .unwrap();
    assert_eq!(source.as_str().len(), 64);
    assert_eq!(snapshot.as_str().len(), 64);
    assert_eq!(review.as_str().len(), 64);
    assert_ne!(source.as_str(), snapshot.as_str());
    assert_ne!(snapshot.as_str(), review.as_str());
    assert!(SnapshotKey::derive(
        SourceKind::Git,
        &"A".repeat(40),
        &"2".repeat(40),
        &format!("sha256:{}", "3".repeat(64)),
    )
    .is_err());
}

#[cfg(unix)]
#[test]
fn local_identity_retains_raw_absolute_bytes() {
    let identity = CanonicalIdentity::local(SourceKind::Live, Path::new("/tmp/source")).unwrap();
    assert_eq!(identity.canonical_bytes(), b"/tmp/source");
}
