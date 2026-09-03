use std::path::PathBuf;

use grimoire_core::inventory::{
    compute_inventory_digest, compute_review_tree_digest, Pack, Skill, SourceInventory, SourcePath,
};
use grimoire_core::{
    attach_inherited_global, context_report, InstalledLink, InstalledStatus, RequestRoot, Scope,
    SnapshotId, SnapshotKind, SnapshotStore, SourceAlias, SourceSnapshot, SourceState, WorldState,
};

const EMPTY_LOCK: &[u8] = include_bytes!("fixtures/lock/empty.json");

fn snapshot(alias: &str, skills: &[&str], pack: Option<(&str, &[&str], &[&str])>) -> SourceState {
    let content = compute_inventory_digest(&[], &[], &[]);
    let skills = skills
        .iter()
        .map(|name| Skill {
            name: (*name).into(),
            path: SourcePath::from(format!("skills/{name}").as_str()),
            content_digest: content,
            files: Vec::new(),
            symlinks: Vec::new(),
            submodules: Vec::new(),
        })
        .collect::<Vec<_>>();
    let packs = pack
        .into_iter()
        .map(|(name, required, optional)| Pack {
            name: name.into(),
            path: SourcePath::from("PACK.md"),
            digest: content,
            description: "fixture".into(),
            required: required.iter().map(|name| (*name).into()).collect(),
            optional: optional.iter().map(|name| (*name).into()).collect(),
            missing_required: Vec::new(),
            missing_optional: Vec::new(),
        })
        .collect::<Vec<_>>();
    let inventory = SourceInventory {
        inventory_digest: compute_inventory_digest(&skills, &packs, &[]),
        review_tree_digest: compute_review_tree_digest(&[]),
        skills,
        packs,
        findings: Vec::new(),
        reviewed_entries: Vec::new(),
    };
    let root = PathBuf::from(format!("/store/{alias}"));
    SourceState::new(
        SourceSnapshot::new(
            SourceAlias::new(alias).unwrap(),
            SnapshotId::new(
                SnapshotKind::Git,
                Some("1".repeat(40)),
                Some("2".repeat(40)),
                inventory.inventory_digest.to_string(),
            )
            .unwrap(),
            root,
            inventory,
        ),
        SnapshotStore::Valid,
        false,
    )
}

fn world(
    scope: Scope,
    manifest: &str,
    state: SourceState,
    links: &[(&str, InstalledLink)],
) -> WorldState {
    WorldState::from_bytes(
        scope,
        manifest.as_bytes().to_vec(),
        EMPTY_LOCK.to_vec(),
        [state],
        links.iter().cloned(),
        None,
    )
    .unwrap()
}

#[test]
fn report_keeps_project_roots_and_inherited_globals_independent() {
    let global = world(
        Scope::Global,
        concat!(
            "schema = \"grimoire/manifest@2\"\n",
            "[sources.global]\nurl = \"github:org/global\"\n",
            "[skills]\nshared = { source = \"global\" }\n",
        ),
        snapshot("global", &["shared"], None),
        &[("shared", InstalledLink::Absent)],
    );
    let project_state = snapshot(
        "project",
        &["local", "shared"],
        Some(("bundle", &["local"], &["missing"])),
    );
    let project = world(
        Scope::Project,
        concat!(
            "schema = \"grimoire/manifest@2\"\n",
            "[sources.project]\nurl = \"github:org/project\"\n",
            "[packs]\nbundle = { source = \"project\" }\n",
            "[skills]\nshared = { source = \"project\" }\n",
        ),
        project_state,
        &[
            (
                "local",
                InstalledLink::Symlink(PathBuf::from("/store/project/skills/local")),
            ),
            ("shared", InstalledLink::Absent),
        ],
    );

    let report = context_report(&attach_inherited_global(project, &global).unwrap());

    assert_eq!(report.desired_roots.len(), 2);
    let local = report
        .skills
        .iter()
        .find(|skill| skill.name.as_str() == "local")
        .unwrap();
    assert_eq!(local.installed, InstalledStatus::Current);
    assert_eq!(
        local.requested_by,
        [RequestRoot::Pack("bundle".try_into().unwrap())]
            .into_iter()
            .collect()
    );
    assert_eq!(report.unavailable[0].skill.as_str(), "missing");
    assert_eq!(report.inherited[0].name.as_str(), "shared");
    assert!(report.inherited[0].shadowed);
    assert!(report
        .findings
        .iter()
        .any(|finding| finding.code == "global-skill-shadowed"));
}

#[test]
fn attaching_context_rejects_reversed_scope_ownership() {
    let project = world(
        Scope::Project,
        "schema = \"grimoire/manifest@2\"\n",
        snapshot("project", &[], None),
        &[],
    );
    assert!(attach_inherited_global(project.clone(), &project).is_err());
}
