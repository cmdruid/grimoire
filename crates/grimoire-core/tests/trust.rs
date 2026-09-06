use grimoire_core::{
    plan, Action, CandidateRecord, CanonicalIdentity, PlanningMode, Request, Scope, SnapshotId,
    SnapshotKind, SnapshotStore, SourceAlias, SourceKey, SourceKind, SourceSnapshot, SourceState,
    SourceTrustIntent, TrustBaseline, TrustChange, TrustMode, TrustReceipt, TrustStore, WorldState,
};
use grimoire_pack::inventory::{
    compute_inventory_digest, compute_review_tree_digest, SourceInventory,
};

fn receipt(seed: char) -> TrustReceipt {
    TrustReceipt {
        commit: seed.to_string().repeat(40),
        tree: "2".repeat(40),
        inventory: format!("sha256:{}", "3".repeat(64)),
    }
}

fn baseline() -> TrustBaseline {
    TrustBaseline {
        commit: Some("1".repeat(40)),
        tree: Some("2".repeat(40)),
        inventory: format!("sha256:{}", "3".repeat(64)),
        review_tree: format!("sha256:{}", "4".repeat(64)),
    }
}

#[test]
fn exact_all_and_revoke_preserve_identity_and_baseline() {
    let identity = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let key = SourceKey::derive(&identity);
    let exact = receipt('1');
    let granted = TrustStore::default()
        .grant_exact(identity.clone(), exact.clone(), baseline(), None)
        .unwrap();
    assert_eq!(granted.create_mode, 0o600);
    let exact_store = TrustStore::parse(&granted.after).unwrap();
    assert_eq!(
        exact_store.records[&key].mode_for(Some(&exact)),
        TrustMode::Snapshot
    );

    let all = exact_store
        .grant_all(
            identity,
            Some(receipt('1')),
            baseline(),
            Some(granted.after),
        )
        .unwrap();
    let all_store = TrustStore::parse(&all.after).unwrap();
    assert_eq!(all_store.records[&key].mode_for(None), TrustMode::All);

    let revoked = all_store.revoke(&key, Some(all.after)).unwrap();
    let revoked_store = TrustStore::parse(&revoked.after).unwrap();
    let record = &revoked_store.records[&key];
    assert_eq!(record.mode_for(None), TrustMode::Untrusted);
    assert!(record.baseline.is_some());
}

#[test]
fn trust_three_rejects_v1_v2_and_vendor_receipt_fields() {
    assert!(TrustStore::parse(br#"{"schema":"grimoire/trust@1","records":{}}"#).is_err());
    assert!(TrustStore::parse(br#"{"schema":"grimoire/trust@2","records":{}}"#).is_err());

    let identity = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let granted = TrustStore::default()
        .grant_exact(identity, receipt('1'), baseline(), None)
        .unwrap();
    assert!(String::from_utf8_lossy(&granted.after).contains("grimoire/trust@3"));
    assert!(!String::from_utf8_lossy(&granted.after).contains("vendor_receipts"));
    let mut value: serde_json::Value = serde_json::from_slice(&granted.after).unwrap();
    value["records"]
        .as_object_mut()
        .unwrap()
        .values_mut()
        .next()
        .unwrap()
        .as_object_mut()
        .unwrap()
        .insert("vendor_receipts".into(), serde_json::json!([]));
    assert!(TrustStore::parse(&serde_json::to_vec(&value).unwrap()).is_err());
}

#[cfg(unix)]
#[test]
fn live_trust_requires_all_and_never_writes_an_exact_receipt() {
    use std::path::Path;

    let identity = CanonicalIdentity::local(SourceKind::Link, Path::new("/tmp/live")).unwrap();
    assert!(TrustStore::default()
        .grant_exact(identity.clone(), receipt('1'), baseline(), None)
        .is_err());
    assert!(TrustStore::default()
        .grant_all(identity.clone(), Some(receipt('1')), baseline(), None)
        .is_err());
    let mutation = TrustStore::default()
        .grant_all(
            identity,
            None,
            TrustBaseline {
                commit: None,
                tree: None,
                ..baseline()
            },
            None,
        )
        .unwrap();
    let store = TrustStore::parse(&mutation.after).unwrap();
    assert!(store.records.values().next().unwrap().receipts.is_empty());
}

#[test]
fn planner_proposes_trust_bytes_without_inferring_activation_or_uninstall() {
    let identity = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let key = SourceKey::derive(&identity);
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&[], &[], &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills: Vec::new(),
        packs: Vec::new(),
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
    };
    let alias = SourceAlias::new("grimoire").unwrap();
    let snapshot = SourceSnapshot::new(
        alias.clone(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some("1".repeat(40)),
            Some("2".repeat(40)),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        "/unused".into(),
        inventory,
    );
    let candidate = CandidateRecord::new(
        "0".repeat(64),
        identity.clone(),
        snapshot.id.commit.clone(),
        snapshot.id.tree.clone(),
        snapshot.id.inventory_digest.clone(),
        format!("sha256:{}", "4".repeat(64)),
    )
    .unwrap();
    let candidate_bytes = candidate.to_bytes().unwrap();
    let world = WorldState::absent(
        Scope::Global,
        std::iter::empty::<SourceState>(),
        std::iter::empty::<(&str, grimoire_core::InstalledLink)>(),
        None,
    )
    .unwrap()
    .with_candidate(
        SourceState::new(snapshot, SnapshotStore::Absent, false)
            .source_identity(identity, format!("sha256:{}", "4".repeat(64)))
            .candidate(candidate_bytes),
    )
    .unwrap();
    let granted = plan(
        &world,
        Request::TrustSource {
            alias,
            mode: SourceTrustIntent::Exact,
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert_eq!(granted.actions.len(), 1);
    let trust_bytes = match &granted.actions[0] {
        Action::ReplaceTrust {
            after,
            create_mode,
            change: TrustChange::GrantExact,
            ..
        } => {
            assert_eq!(*create_mode, 0o600);
            after.clone()
        }
        action => panic!("unexpected trust action: {action:?}"),
    };

    let revoked = plan(
        &world.with_trust_bytes(Some(trust_bytes)),
        Request::RevokeTrust { source: key },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(revoked.is_destructive());
    assert!(matches!(
        revoked.actions.as_slice(),
        [Action::ReplaceTrust {
            change: TrustChange::Revoke,
            ..
        }]
    ));
    assert!(!revoked.actions.iter().any(|action| matches!(
        action,
        Action::RemoveLink { .. } | Action::ReplaceLock { .. }
    )));
}
