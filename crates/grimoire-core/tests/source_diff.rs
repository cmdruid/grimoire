use grimoire_core::inventory::{Boundary, SourcePath};
use grimoire_core::source::{ReviewEntry, ReviewExport, ReviewPayload, SourceDiff};

fn export(entries: Vec<ReviewEntry>) -> ReviewExport {
    let identity = grimoire_core::source::CanonicalIdentity::remote("github:org/repo").unwrap();
    let source_key = grimoire_core::source::SourceKey::derive(&identity);
    let inventory = format!("sha256:{}", "1".repeat(64));
    let review_tree = format!("sha256:{}", "2".repeat(64));
    let review_key = grimoire_core::source::ReviewKey::derive(
        grimoire_core::source::SourceKind::Git,
        Some(&"3".repeat(40)),
        Some(&"4".repeat(40)),
        &inventory,
        &review_tree,
    )
    .unwrap();
    ReviewExport {
        root: "/review".into(),
        source_key,
        review_key,
        review_tree,
        entries,
    }
}

fn file(path: &'static str, digest_digit: char) -> ReviewEntry {
    ReviewEntry {
        path: SourcePath::from(path),
        mode: "100644".into(),
        boundary: Boundary::Snapshot,
        payload: ReviewPayload::File {
            size: 1,
            digest: format!("sha256:{}", digest_digit.to_string().repeat(64)),
        },
        safety: None,
        reason: None,
    }
}

#[test]
fn diff_reports_only_factual_raw_path_changes_and_affected_roots() {
    let before = export(vec![file("a", '1'), file("gone", '1')]);
    let after = export(vec![file("a", '2'), file("new", '1')]);
    let diff = SourceDiff::between(
        Some("1".repeat(40)),
        Some(&before),
        Some("2".repeat(40)),
        &after,
        ["skill:one".into()],
    );
    assert_eq!(
        diff.changes
            .iter()
            .map(|change| (change.path.to_string(), change.kind.as_str()))
            .collect::<Vec<_>>(),
        vec![
            ("a".into(), "changed"),
            ("gone".into(), "removed"),
            ("new".into(), "added")
        ]
    );
    assert!(diff.affected_roots.contains("skill:one"));
}
