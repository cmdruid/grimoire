use std::collections::BTreeMap;

use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Boundary, FileFact, Finding, Severity,
    Skill, SourceInventory, SourcePath,
};
use grimoire_core::source::{
    CandidateRecord, CanonicalIdentity, ReviewExport, ReviewKey, SourceInfo, SourceKey, SourceKind,
};
use grimoire_core::{SourceAlias, TrustMode};

#[test]
fn json_matches_the_additive_source_info_contract() {
    let temporary = tempfile::tempdir().unwrap();
    let review_root = temporary.path().join("review");
    std::fs::create_dir_all(review_root.join("objects")).unwrap();
    let content = compute_inventory_digest(&[], &[], &[]);
    let file = FileFact {
        path: SourcePath::from("skills/one/run.sh"),
        size: 18,
        mode: "100755".into(),
        digest: content,
        binary: false,
        executable: true,
        shebang: Some(b"#!/bin/sh".to_vec()),
    };
    let skills = vec![Skill {
        name: "one".into(),
        path: SourcePath::from("skills/one"),
        content_digest: content,
        files: vec![file],
        symlinks: Vec::new(),
        submodules: Vec::new(),
    }];
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&skills, &[], &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills,
        packs: Vec::new(),
        findings: vec![Finding {
            code: "fixture".into(),
            path: Some(SourcePath::from("skills/one/run.sh")),
            severity: Severity::Warning,
            details: BTreeMap::new(),
            message: "fixture finding".into(),
        }],
        reviewed_entries: Vec::new(),
    };
    let identity = CanonicalIdentity::remote("github:org/repo").unwrap();
    let candidate = CandidateRecord::new(
        "a".repeat(64),
        identity.clone(),
        Some("1".repeat(40)),
        Some("2".repeat(40)),
        inventory.inventory_digest.to_string(),
        inventory.review_tree_digest.to_string(),
    )
    .unwrap();
    let review_key = ReviewKey::derive(
        SourceKind::Git,
        candidate.commit.as_deref(),
        candidate.tree.as_deref(),
        &candidate.inventory,
        &candidate.review_tree,
    )
    .unwrap();
    let export = ReviewExport {
        root: review_root.clone(),
        source_key: SourceKey::derive(&identity),
        review_key,
        review_tree: candidate.review_tree.clone(),
        facts: Default::default(),
        entries: vec![grimoire_core::source::ReviewEntry {
            path: SourcePath::from("README.md"),
            mode: "100644".into(),
            boundary: Boundary::Snapshot,
            payload: grimoire_core::source::ReviewPayload::File {
                size: 0,
                digest: content.to_string(),
            },
            safety: None,
            reason: None,
        }],
    };
    std::fs::write(
        review_root
            .join("objects")
            .join(content.to_string().strip_prefix("sha256:").unwrap()),
        b"",
    )
    .unwrap();
    let info = SourceInfo::from_candidate(
        SourceAlias::new("repo").unwrap(),
        "github:org/repo".into(),
        Some("main".into()),
        candidate,
        inventory,
        export,
        TrustMode::Snapshot,
        None,
    );
    let value: serde_json::Value = serde_json::from_slice(&info.to_bytes().unwrap()).unwrap();
    assert_eq!(value["schema"], "grimoire/source-info@1");
    assert!(value["trust"].get("vendor_receipts").is_none());
    assert_eq!(value["alias"], "repo");
    assert_eq!(
        value["source"]["canonical"],
        "https://github.com/org/repo.git"
    );
    assert_eq!(
        value["snapshot"]["review_path"],
        review_root.display().to_string()
    );
    assert_eq!(value["trust"]["mode"], "snapshot");
    assert_eq!(value["skills"][0]["files"][0]["path"], "run.sh");
    assert_eq!(
        value["skills"][0]["files"][0]["sha256"],
        content.to_string()
    );
    assert_eq!(value["entries"][0]["path"], "README.md");
    assert_eq!(value["findings"][0]["severity"], "warning");
}
