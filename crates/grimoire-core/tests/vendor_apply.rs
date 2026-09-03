use std::fs;

use grimoire_core::inventory::scan;
use grimoire_core::source::HeldDirectoryReader;
use grimoire_core::{
    apply, load_world, plan, Action, ApplyOutcome, Approval, CanonicalIdentity, FaultDisposition,
    InstalledLink, Lockfile, Paths, PlanningMode, ProjectionMode, Request, Result, Scope,
    SnapshotId, SnapshotKey, SnapshotKind, SnapshotStore, SourceAlias, SourceKey, SourceSnapshot,
    SourceState, TransactionRuntime, TrustBaseline, TrustReceipt, TrustStore,
};

struct Runtime;

impl TransactionRuntime for Runtime {
    fn transaction_nonce(&self) -> Result<String> {
        Ok("vendor-apply".into())
    }

    fn unix_time(&self) -> Result<i64> {
        Ok(1_700_000_000)
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

#[derive(Default)]
struct NoGit;

impl grimoire_core::source::GitRunner for NoGit {
    fn run(
        &self,
        _command: grimoire_core::source::GitCommand,
    ) -> Result<grimoire_core::source::GitResult> {
        panic!("vendor apply fixture must not invoke Git")
    }
}

#[test]
fn trusted_store_bytes_create_and_convert_a_vendor_projection_atomically() {
    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    let home = root.join("home");
    let source = root.join("source");
    fs::create_dir_all(source.join("skills/one/bin")).unwrap();
    fs::create_dir_all(&project).unwrap();
    fs::write(
        source.join("skills/one/SKILL.md"),
        b"---\nname: one\ndescription: vendor apply fixture\n---\n",
    )
    .unwrap();
    fs::write(source.join("skills/one/bin/run"), b"#!/bin/sh\n").unwrap();
    executable(&source.join("skills/one/bin/run"));
    #[cfg(unix)]
    std::os::unix::fs::symlink("../SKILL.md", source.join("skills/one/bin/current")).unwrap();

    let inventory = scan(&HeldDirectoryReader::open(&source).unwrap()).unwrap();
    let content = inventory
        .skills
        .iter()
        .find(|skill| skill.name == "one")
        .unwrap()
        .content_digest
        .to_string();
    let review_tree = inventory.review_tree_digest.to_string();
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
    let paths = Paths::project(project, home).unwrap();
    let store = paths.store_path(&source_key, &snapshot_key);
    copy_store_tree(&source, &store);

    let manifest = concat!(
        "schema = \"grimoire/manifest@2\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[skills]\none = { source = \"a\", mode = \"vendor\" }\n"
    )
    .as_bytes()
    .to_vec();
    let lock = Lockfile::default().to_bytes().unwrap();
    fs::write(paths.manifest_path(), &manifest).unwrap();
    fs::write(paths.lock_path(), &lock).unwrap();
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
    let snapshot = SourceSnapshot::new(
        SourceAlias::new("a").unwrap(),
        SnapshotId::new(
            SnapshotKind::Git,
            Some(commit),
            Some(tree),
            inventory.inventory_digest.to_string(),
        )
        .unwrap(),
        store.clone(),
        inventory,
    );
    let world = grimoire_core::WorldState::from_bytes(
        Scope::Project,
        manifest,
        lock,
        [SourceState::new(snapshot, SnapshotStore::Valid, false)
            .source_identity(identity, review_tree)],
        [("one", InstalledLink::Absent)],
        None,
    )
    .unwrap()
    .with_trust_bytes(Some(trust));

    let create = plan(&world, Request::Reconcile, PlanningMode::Normal).unwrap();
    assert!(create.actions.iter().any(|action| matches!(
        action,
        Action::PrepareVendor { skill, .. } if skill.as_str() == "one"
    )));
    assert!(create.actions.iter().any(|action| matches!(
        action,
        Action::CreateVendor { skill, .. } if skill.as_str() == "one"
    )));
    assert_eq!(
        apply(&paths, &create, Approval::NotRequired, &Runtime).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );

    let vendor = paths
        .vendor_path(&"a".try_into().unwrap(), &"one".try_into().unwrap())
        .unwrap();
    assert_eq!(
        grimoire_core::verify_vendor_tree(&vendor, &"one".try_into().unwrap()).unwrap(),
        content
    );
    assert_eq!(
        fs::read(vendor.join("SKILL.md")).unwrap(),
        fs::read(source.join("skills/one/SKILL.md")).unwrap()
    );
    assert_eq!(
        fs::read_link(paths.skills_dir().join("one")).unwrap(),
        std::path::PathBuf::from("../../vendor/grimoire/a/one")
    );
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        assert_ne!(
            fs::metadata(store.join("skills/one/SKILL.md"))
                .unwrap()
                .ino(),
            fs::metadata(vendor.join("SKILL.md")).unwrap().ino()
        );
    }

    let current = load_world(&paths, &NoGit, &Runtime).unwrap();
    let mut desired = grimoire_core::DesiredState::from_world(&current);
    desired
        .skills
        .get_mut(&"one".try_into().unwrap())
        .unwrap()
        .mode = ProjectionMode::Link;
    let convert = plan(
        &current,
        Request::ReplaceDesiredState { desired },
        PlanningMode::Normal,
    )
    .unwrap();
    assert!(convert.actions.iter().any(|action| matches!(
        action,
        Action::RemoveVendor { skill, .. } if skill.as_str() == "one"
    )));
    assert!(convert.is_destructive());
    assert_eq!(
        apply(&paths, &convert, Approval::Granted, &Runtime).unwrap(),
        ApplyOutcome::Applied { changed: true }
    );
    assert!(!vendor.exists());
    assert_eq!(
        fs::read_link(paths.skills_dir().join("one")).unwrap(),
        store.join("skills/one")
    );
}

fn copy_store_tree(source: &std::path::Path, destination: &std::path::Path) {
    fs::create_dir_all(destination.join("skills/one/bin")).unwrap();
    fs::copy(
        source.join("skills/one/SKILL.md"),
        destination.join("skills/one/SKILL.md"),
    )
    .unwrap();
    fs::copy(
        source.join("skills/one/bin/run"),
        destination.join("skills/one/bin/run"),
    )
    .unwrap();
    #[cfg(unix)]
    std::os::unix::fs::symlink("../SKILL.md", destination.join("skills/one/bin/current")).unwrap();
    readonly_tree(destination);
}

#[cfg(unix)]
fn executable(path: &std::path::Path) {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(0o755)).unwrap();
}

#[cfg(unix)]
fn readonly_tree(path: &std::path::Path) {
    use std::os::unix::fs::PermissionsExt;
    for child in fs::read_dir(path).unwrap() {
        let child = child.unwrap().path();
        let metadata = fs::symlink_metadata(&child).unwrap();
        if metadata.is_dir() {
            readonly_tree(&child);
        } else if metadata.is_file() {
            let mode = if metadata.permissions().mode() & 0o111 == 0 {
                0o444
            } else {
                0o555
            };
            fs::set_permissions(&child, fs::Permissions::from_mode(mode)).unwrap();
        }
    }
    fs::set_permissions(path, fs::Permissions::from_mode(0o555)).unwrap();
}
