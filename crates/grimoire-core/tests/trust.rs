use std::collections::{BTreeMap, BTreeSet};

use grimoire_core::{
    plan, Action, CandidateRecord, CanonicalIdentity, PlanningMode, Request, Scope, SnapshotId,
    SnapshotKind, SnapshotStore, SourceAlias, SourceKey, SourceKind, SourceSnapshot, SourceState,
    SourceTrustIntent, TrustBaseline, TrustChange, TrustMode, TrustReceipt, TrustStore,
    VendorTrustReceipt, WorldState,
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

fn vendor_receipt(skill: &str) -> VendorTrustReceipt {
    VendorTrustReceipt {
        commit: "1".repeat(40),
        tree: "2".repeat(40),
        inventory: format!("sha256:{}", "3".repeat(64)),
        skill: skill.try_into().unwrap(),
        path: format!("skills/{skill}"),
        content: format!(
            "sha256:{}",
            if skill == "alpha" { "4" } else { "5" }.repeat(64)
        ),
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
fn vendor_receipts_upgrade_v1_deterministically_and_revoke_without_losing_baseline() {
    let identity = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let key = SourceKey::derive(&identity);
    let exact = receipt('1');
    let accepted = baseline();
    let records = BTreeMap::from([(
        key.to_string(),
        serde_json::json!({
            "kind": "git",
            "canonical": identity.canonical_utf8().unwrap(),
            "receipts": [{
                "commit": exact.commit,
                "tree": exact.tree,
                "inventory": exact.inventory,
            }],
            "all_snapshots": false,
            "baseline": {
                "commit": accepted.commit,
                "tree": accepted.tree,
                "inventory": accepted.inventory,
                "review_tree": accepted.review_tree,
            },
        }),
    )]);
    let v1 = serde_json::to_vec_pretty(&serde_json::json!({
        "schema": "grimoire/trust@1",
        "records": records,
    }))
    .unwrap();
    let loaded = TrustStore::parse(&v1).unwrap();
    assert!(loaded.records[&key].vendor_receipts.is_empty());

    let receipts = BTreeSet::from([vendor_receipt("zeta"), vendor_receipt("alpha")]);
    let upgraded = loaded
        .grant_vendor(identity, receipts.clone(), Some(v1))
        .unwrap();
    let upgraded_store = TrustStore::parse(&upgraded.after).unwrap();
    let record = &upgraded_store.records[&key];
    assert_eq!(record.vendor_receipts, receipts);
    assert_eq!(record.receipts, BTreeSet::from([receipt('1')]));
    assert_eq!(record.baseline.as_ref(), Some(&baseline()));
    assert!(String::from_utf8_lossy(&upgraded.after).contains("grimoire/trust@2"));

    let revoked = upgraded_store
        .revoke(&key, Some(upgraded.after.clone()))
        .unwrap();
    let record = &TrustStore::parse(&revoked.after).unwrap().records[&key];
    assert!(record.receipts.is_empty());
    assert!(record.vendor_receipts.is_empty());
    assert_eq!(record.baseline.as_ref(), Some(&baseline()));
}

#[test]
fn trust_two_rejects_missing_unsorted_and_unknown_vendor_receipt_fields() {
    let identity = CanonicalIdentity::remote("github:cmdruid/grimoire").unwrap();
    let mutation = TrustStore::default()
        .grant_vendor(
            identity,
            BTreeSet::from([vendor_receipt("alpha"), vendor_receipt("zeta")]),
            None,
        )
        .unwrap();
    let mut value: serde_json::Value = serde_json::from_slice(&mutation.after).unwrap();
    let record = value["records"]
        .as_object_mut()
        .unwrap()
        .values_mut()
        .next()
        .unwrap();
    let original = record.clone();

    record.as_object_mut().unwrap().remove("vendor_receipts");
    assert!(TrustStore::parse(&serde_json::to_vec(&value).unwrap()).is_err());

    *value["records"]
        .as_object_mut()
        .unwrap()
        .values_mut()
        .next()
        .unwrap() = original.clone();
    value["records"]
        .as_object_mut()
        .unwrap()
        .values_mut()
        .next()
        .unwrap()["vendor_receipts"]
        .as_array_mut()
        .unwrap()
        .reverse();
    assert!(TrustStore::parse(&serde_json::to_vec(&value).unwrap()).is_err());

    *value["records"]
        .as_object_mut()
        .unwrap()
        .values_mut()
        .next()
        .unwrap() = original;
    value["records"]
        .as_object_mut()
        .unwrap()
        .values_mut()
        .next()
        .unwrap()["vendor_receipts"][0]["unexpected"] = serde_json::Value::Bool(true);
    assert!(TrustStore::parse(&serde_json::to_vec(&value).unwrap()).is_err());
}

#[cfg(unix)]
#[test]
fn live_trust_requires_all_and_never_writes_an_exact_receipt() {
    use std::path::Path;

    let identity = CanonicalIdentity::local(SourceKind::Live, Path::new("/tmp/live")).unwrap();
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
