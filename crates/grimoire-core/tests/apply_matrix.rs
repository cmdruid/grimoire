use std::fs;

use grimoire_core::inventory::scan;
use grimoire_core::source::{GitCommand, GitResult, GitRunner, HeldDirectoryReader, ReviewExport};
use grimoire_core::{
    apply, plan, prepare_source_add, Action, ApplyOutcome, Approval, CanonicalIdentity,
    FaultDisposition, InstalledLink, Lockfile, ManifestSource, Paths, PlanningMode, Request,
    Result, ReviewKey, Scope, SnapshotId, SnapshotKey, SnapshotKind, SnapshotStore, SourceAlias,
    SourceKey, SourceLocation, SourceSnapshot, SourceState, SourceTrustIntent, TransactionRuntime,
    TrustBaseline, TrustReceipt, TrustStore, WorldState,
};

struct NoGit;

impl GitRunner for NoGit {
    fn run(&self, _command: GitCommand) -> Result<GitResult> {
        panic!("live source preparation must not invoke Git")
    }
}

struct Runtime;

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("apply-matrix".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

#[test]
fn prepared_source_registration_and_removal_cross_only_the_action_interpreter() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    let source = root.join("source");
    fs::create_dir_all(&project).unwrap();
    fs::create_dir_all(&source).unwrap();
    fs::write(
        source.join("SKILL.md"),
        b"---\nname: local\ndescription: local fixture\n---\n",
    )
    .unwrap();
    let paths = Paths::project(project, home).unwrap();
    let manifest_bytes = b"schema = \"grimoire/manifest@2\"\n".to_vec();
    let lock_bytes = Lockfile::default().to_bytes().unwrap();
    fs::write(paths.manifest_path(), &manifest_bytes).unwrap();
    fs::write(paths.lock_path(), &lock_bytes).unwrap();
    let world = WorldState::from_bytes(
        Scope::Project,
        manifest_bytes,
        lock_bytes,
        [],
        std::iter::empty::<(&str, InstalledLink)>(),
        None,
    )
    .unwrap();
    let alias = SourceAlias::new("local").unwrap();
    let prepared = prepare_source_add(
        paths.clone(),
        &world,
        alias.clone(),
        ManifestSource {
            location: SourceLocation::Path("../source".into()),
            reference: None,
            live: true,
        },
        &NoGit,
    )
    .unwrap();
    assert!(!paths.candidate_path(&paths.scope_key(), &alias).exists());
    assert!(!paths.trust_path().exists());

    let add = plan(
        &world,
        Request::AddSource {
            prepared: Box::new(prepared.clone()),
            trust: SourceTrustIntent::All,
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(matches!(
        add.actions.as_slice(),
        [
            Action::ReplaceManifest { .. },
            Action::ReplaceCandidate { .. },
            Action::ReplaceTrust { .. }
        ]
    ));
    assert_eq!(
        apply(&paths, &add, Approval::NotRequired, &Runtime).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );
    assert!(paths.candidate_path(&paths.scope_key(), &alias).is_file());
    assert!(paths.trust_path().is_file());
    assert!(!paths.skills_dir().exists());

    let candidate = prepared.info().candidate.clone();
    let snapshot = SourceSnapshot::new(
        alias.clone(),
        SnapshotId::new(SnapshotKind::Live, None, None, candidate.inventory.clone()).unwrap(),
        source,
        prepared.info().inventory.clone(),
    );
    let candidate_bytes = fs::read(paths.candidate_path(&paths.scope_key(), &alias)).unwrap();
    let current = WorldState::from_bytes(
        Scope::Project,
        fs::read(paths.manifest_path()).unwrap(),
        fs::read(paths.lock_path()).unwrap(),
        [SourceState::new(snapshot, SnapshotStore::Valid, false)
            .source_identity(candidate.identity, candidate.review_tree)
            .candidate(candidate_bytes)],
        std::iter::empty::<(&str, InstalledLink)>(),
        None,
    )
    .unwrap()
    .with_candidate(
        SourceState::new(
            SourceSnapshot::new(
                alias.clone(),
                SnapshotId::new(
                    SnapshotKind::Live,
                    None,
                    None,
                    prepared.info().inventory.inventory_digest.to_string(),
                )
                .unwrap(),
                prepared
                    .info()
                    .candidate
                    .identity
                    .canonical_utf8()
                    .unwrap()
                    .into(),
                prepared.info().inventory.clone(),
            ),
            SnapshotStore::Valid,
            false,
        )
        .source_identity(
            prepared.info().candidate.identity.clone(),
            prepared.info().candidate.review_tree.clone(),
        )
        .candidate(fs::read(paths.candidate_path(&paths.scope_key(), &alias)).unwrap()),
    )
    .unwrap()
    .with_trust_bytes(Some(fs::read(paths.trust_path()).unwrap()))
    .with_project_index_bytes(Some(fs::read(paths.projects_path()).unwrap()));
    let remove = plan(
        &current,
        Request::RemoveSource {
            alias: alias.clone(),
        },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(remove.is_destructive());
    assert_eq!(
        apply(&paths, &remove, Approval::Declined, &Runtime).unwrap(),
        ApplyOutcome::Cancelled
    );
    assert!(paths.candidate_path(&paths.scope_key(), &alias).exists());
    assert_eq!(
        apply(&paths, &remove, Approval::Granted, &Runtime).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );
    assert!(!paths.candidate_path(&paths.scope_key(), &alias).exists());
    assert!(!fs::read_to_string(paths.manifest_path())
        .unwrap()
        .contains("[sources.local]"));
}

#[test]
fn planned_snapshot_preparation_materializes_and_repairs_before_link_activation() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    let source = root.join("source");
    fs::create_dir_all(source.join("skills/one")).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: materialize fixture\n---\n",
    )
    .unwrap();
    let paths = Paths::project(project, home).unwrap();
    let reader = HeldDirectoryReader::open(&source).unwrap();
    let inventory = scan(&reader).unwrap();
    let identity = CanonicalIdentity::remote("github:org/a").unwrap();
    let source_key = SourceKey::derive(&identity);
    let commit = "1".repeat(40);
    let tree = "2".repeat(40);
    let snapshot_key = SnapshotKey::derive(
        grimoire_core::SourceKind::Git,
        &commit,
        &tree,
        &inventory.inventory_digest.to_string(),
    )
    .unwrap();
    let review_key = ReviewKey::derive(
        grimoire_core::SourceKind::Git,
        Some(&commit),
        Some(&tree),
        &inventory.inventory_digest.to_string(),
        &inventory.review_tree_digest.to_string(),
    )
    .unwrap();
    ReviewExport::write(
        &paths.review_cache_dir(),
        source_key.clone(),
        review_key,
        &inventory,
        &reader,
    )
    .unwrap();

    let manifest = concat!(
        "schema = \"grimoire/manifest@2\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[skills]\none = { source = \"a\" }\n"
    )
    .as_bytes()
    .to_vec();
    let lock = Lockfile::default().to_bytes().unwrap();
    fs::write(paths.manifest_path(), &manifest).unwrap();
    fs::write(paths.lock_path(), &lock).unwrap();
    let snapshot = SourceSnapshot::new(
        SourceAlias::new("a").unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some(commit.clone()),
            Some(tree.clone()),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        paths.store_path(&source_key, &snapshot_key),
        inventory.clone(),
    );
    let trust = TrustStore::default()
        .grant_exact(
            identity.clone(),
            TrustReceipt {
                commit: commit.clone(),
                tree: tree.clone(),
                inventory: inventory.inventory_digest.to_string(),
            },
            TrustBaseline {
                commit: Some(commit.clone()),
                tree: Some(tree.clone()),
                inventory: inventory.inventory_digest.to_string(),
                review_tree: inventory.review_tree_digest.to_string(),
            },
            None,
        )
        .unwrap()
        .after;
    fs::create_dir_all(paths.trust_path().parent().unwrap()).unwrap();
    fs::write(paths.trust_path(), &trust).unwrap();
    let world = WorldState::from_bytes(
        Scope::Project,
        manifest,
        lock,
        [SourceState::new(snapshot, SnapshotStore::Absent, true)
            .source_identity(identity.clone(), inventory.review_tree_digest.to_string())],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(Some(trust.clone()));
    let materialize_plan = plan(&world, Request::Reconcile, PlanningMode::Normal).unwrap();
    assert!(matches!(
        materialize_plan.actions.first(),
        Some(Action::PrepareSnapshot { .. })
    ));

    assert_eq!(
        apply(&paths, &materialize_plan, Approval::NotRequired, &Runtime,).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );
    assert!(paths.store_path(&source_key, &snapshot_key).is_dir());
    assert_eq!(
        fs::read_link(paths.skills_dir().join("one")).unwrap(),
        paths
            .store_path(&source_key, &snapshot_key)
            .join("skills/one")
    );

    let stored = paths.store_path(&source_key, &snapshot_key);
    let stored_skill = stored.join("skills/one/SKILL.md");
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&stored_skill, fs::Permissions::from_mode(0o644)).unwrap();
    }
    fs::write(&stored_skill, b"corrupt\n").unwrap();
    fs::remove_file(paths.skills_dir().join("one")).unwrap();
    let repair_snapshot = SourceSnapshot::new(
        SourceAlias::new("a").unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some(commit),
            Some(tree),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        stored,
        inventory.clone(),
    );
    let repair_world = WorldState::from_bytes(
        Scope::Project,
        fs::read(paths.manifest_path()).unwrap(),
        fs::read(paths.lock_path()).unwrap(),
        [
            SourceState::new(repair_snapshot, SnapshotStore::Corrupt, true)
                .source_identity(identity, inventory.review_tree_digest.to_string()),
        ],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(Some(trust))
    .with_project_index_bytes(Some(fs::read(paths.projects_path()).unwrap()));
    let repair_plan = plan(&repair_world, Request::Reconcile, PlanningMode::Normal).unwrap();
    assert!(matches!(
        repair_plan.actions.first(),
        Some(Action::PrepareSnapshot {
            operation: grimoire_core::SnapshotPreparation::Repair,
            ..
        })
    ));
    assert_eq!(
        apply(&paths, &repair_plan, Approval::NotRequired, &Runtime,).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );
    assert_eq!(
        fs::read(stored_skill).unwrap(),
        b"---\nname: one\ndescription: materialize fixture\n---\n"
    );
}
