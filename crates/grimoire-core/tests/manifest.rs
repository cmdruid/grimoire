use std::collections::BTreeSet;
use std::path::Path;

use grimoire_core::{
    Manifest, ManifestMutation, ManifestPack, ManifestSkill, ManifestSource, PackName,
    ProjectionMode, SkillName, SourceAlias, SourceLocation,
};

fn parse(body: &str) -> Manifest {
    Manifest::parse(body.as_bytes().to_vec()).unwrap()
}

#[test]
fn schema_three_drops_mode_and_rejects_v2() {
    let manifest = parse(concat!(
        "schema = \"grimoire/manifest@3\"\n",
        "[sources.a]\nurl = \"github:org/a\"\n",
        "[skills]\nlinked = { source = \"a\" }\n",
        "[packs]\nbundle = { source = \"a\" }\n",
    ));

    assert_eq!(
        manifest.skills[&SkillName::new("linked").unwrap()].mode,
        ProjectionMode::Link
    );
    assert_eq!(
        manifest.packs[&PackName::new("bundle").unwrap()].mode,
        ProjectionMode::Link
    );

    let base = parse("schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\n");
    let linked = base
        .mutate(ManifestMutation::InstallSkill {
            name: SkillName::new("linked").unwrap(),
            request: ManifestSkill {
                source: SourceAlias::new("a").unwrap(),
                mode: ProjectionMode::Link,
            },
        })
        .unwrap();
    let after = String::from_utf8_lossy(&linked.after);
    assert!(after.contains("linked = { source = \"a\" }"));
    assert!(!after.contains("mode"));

    for body in [
        "schema = \"grimoire/manifest@1\"\n",
        "schema = \"grimoire/manifest@2\"\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\n[skills]\none = { source = \"a\", mode = \"vendor\" }\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\n[packs]\none = { source = \"a\", mode = \"link\" }\n",
    ] {
        assert!(Manifest::parse(body.as_bytes().to_vec()).is_err(), "{body}");
    }
}

#[test]
fn manifest_rejects_every_wrong_schema_shape_and_reference() {
    let invalid = [
        "schema = \"old\"\n",
        "schema = \"grimoire/manifest@3\"\nunknown = true\n",
        "schema = \"grimoire/manifest@3\"\n[sources.Bad]\nurl = \"x\"\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\npath = \"x\"\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\nlink = true\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\npath = \"x\"\nref = \"main\"\nlink = true\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\nextra = 1\n",
        "schema = \"grimoire/manifest@3\"\n[skills]\na = { source = \"missing\" }\n",
        "schema = \"grimoire/manifest@3\"\n[sources.a]\nurl = \"x\"\n[packs]\np = { source = \"a\", exclude = [\"x\", \"x\"] }\n",
    ];
    for body in invalid {
        assert!(Manifest::parse(body.as_bytes().to_vec()).is_err(), "{body}");
    }
}

#[test]
fn absent_refs_and_declared_paths_remain_exact_and_resolve_lexically() {
    let manifest = parse(
        "schema = \"grimoire/manifest@3\"\n\
         [sources.remote]\nurl = \"github:org/repo\"\n\
         [sources.local]\npath = \"../skills\"\n\
         [sources.absolute]\npath = \"/srv/skills\"\nlink = true\n",
    );
    assert_eq!(
        manifest.sources[&SourceAlias::new("remote").unwrap()].reference,
        None
    );
    assert_eq!(
        manifest.resolve_declared_path(
            &SourceAlias::new("local").unwrap(),
            Path::new("/work/project")
        ),
        Some(Path::new("/work/project/../skills").to_path_buf())
    );
    assert_eq!(
        manifest.resolve_declared_path(
            &SourceAlias::new("absolute").unwrap(),
            Path::new("/work/project")
        ),
        Some(Path::new("/srv/skills").to_path_buf())
    );
}

#[test]
fn targeted_mutations_preserve_every_unaddressed_byte() {
    let original = concat!(
        "# lead\n",
        "schema = 'grimoire/manifest@3' # schema spelling stays\n",
        "sources.alpha.url = 'github:org/alpha'\n",
        "\n[skills] # scattered table\n",
        "keep = { source='alpha' } # untouched scalar spelling\n",
        "drop = {source = \"alpha\"}\n",
        "\n[packs]\n",
        "bundle = { source = \"alpha\", exclude = [\"old\"] } # addressed only\n",
        "\n[metadata-looking-comment]\n",
    );
    assert!(Manifest::parse(original.as_bytes().to_vec()).is_err());

    let original = original.replace(
        "\n[metadata-looking-comment]\n",
        "\n# [metadata-looking-comment]\n",
    );
    let manifest = parse(&original);
    let edited = manifest
        .mutate(ManifestMutation::UninstallSkill {
            name: SkillName::new("drop").unwrap(),
        })
        .unwrap();
    let expected = original.replace("drop = {source = \"alpha\"}\n", "");
    assert_eq!(edited.after, expected.as_bytes());

    let edited = edited
        .manifest
        .mutate(ManifestMutation::ReplacePackExclusions {
            name: PackName::new("bundle").unwrap(),
            exclude: BTreeSet::from([SkillName::new("new").unwrap()]),
        })
        .unwrap();
    assert!(String::from_utf8(edited.after.clone())
        .unwrap()
        .contains("keep = { source='alpha' } # untouched scalar spelling"));
    assert!(String::from_utf8(edited.after)
        .unwrap()
        .contains("bundle = { source = \"alpha\", exclude = [\"new\"] } # addressed only"));
}

#[test]
fn every_mutation_reparses_to_only_the_intended_semantic_delta() {
    let manifest = parse("schema = \"grimoire/manifest@3\"\n");
    let source = SourceAlias::new("alpha").unwrap();
    let manifest = manifest
        .mutate(ManifestMutation::AddSource {
            alias: source.clone(),
            source: ManifestSource {
                location: SourceLocation::Path("../alpha".into()),
                reference: None,
                link: false,
            },
        })
        .unwrap()
        .manifest;
    let manifest = manifest
        .mutate(ManifestMutation::InstallSkill {
            name: SkillName::new("one").unwrap(),
            request: ManifestSkill {
                source: source.clone(),
                mode: ProjectionMode::Link,
            },
        })
        .unwrap()
        .manifest;
    let manifest = manifest
        .mutate(ManifestMutation::InstallPack {
            name: PackName::new("all").unwrap(),
            request: ManifestPack {
                source: source.clone(),
                mode: ProjectionMode::Link,
                exclude: BTreeSet::new(),
            },
        })
        .unwrap()
        .manifest;
    assert_eq!(manifest.sources.len(), 1);
    assert_eq!(manifest.skills.len(), 1);
    assert_eq!(manifest.packs.len(), 1);

    let manifest = manifest
        .mutate(ManifestMutation::UninstallPack {
            name: PackName::new("all").unwrap(),
        })
        .unwrap()
        .manifest
        .mutate(ManifestMutation::UninstallSkill {
            name: SkillName::new("one").unwrap(),
        })
        .unwrap()
        .manifest
        .mutate(ManifestMutation::RemoveSource { alias: source })
        .unwrap()
        .manifest;
    assert!(manifest.sources.is_empty());
    assert!(manifest.skills.is_empty());
    assert!(manifest.packs.is_empty());
}
