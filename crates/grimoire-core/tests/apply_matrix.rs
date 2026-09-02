use std::fs;

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{
    apply, plan, prepare_source_add, Action, ApplyOutcome, Approval, FaultDisposition,
    InstalledLink, Lockfile, ManifestSource, Paths, PlanningMode, Request, Result, Scope,
    SnapshotId, SnapshotKind, SnapshotStore, SourceAlias, SourceLocation, SourceSnapshot,
    SourceState, SourceTrustIntent, TransactionRuntime, WorldState,
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
    let manifest_bytes = b"schema = \"grimoire/manifest@1\"\n".to_vec();
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
