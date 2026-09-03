use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::process::Command;

use grimoire_core::inventory::scan;
use grimoire_core::source::{
    inspect_pinned_source, CanonicalIdentity, GitCommand, GitRunner, GitSnapshot, GitTreeReader,
    PRIVATE_REF,
};
use grimoire_core::{Paths, SourceAlias};
use skill_grimoire::runtime::SystemGitRunner;

#[test]
fn production_runner_fetches_one_named_ref_into_the_private_ref() {
    let fixture = tempfile::tempdir().unwrap();
    let source = fixture.path().join("source");
    let remote = fixture.path().join("remote.git");
    let cache = fixture.path().join("cache.git");
    fs::create_dir(&source).unwrap();
    git(&source, ["init"]);
    git(&source, ["config", "user.name", "Fixture"]);
    git(&source, ["config", "user.email", "fixture@example.com"]);
    let mut skill = b"---\nname: fixture\n---\n".to_vec();
    skill.resize(2 * 1024 * 1024, b'x');
    fs::write(source.join("SKILL.md"), skill).unwrap();
    git(&source, ["add", "SKILL.md"]);
    git(&source, ["commit", "-m", "fixture"]);
    git(
        fixture.path(),
        [
            "clone",
            "--bare",
            source.to_str().unwrap(),
            remote.to_str().unwrap(),
        ],
    );

    let runner = SystemGitRunner::default();
    runner
        .run(GitCommand::InitBare {
            repository: cache.clone(),
        })
        .unwrap();
    runner
        .run(GitCommand::Fetch {
            bare_repository: cache.clone(),
            repository: remote.display().to_string(),
            source_ref: "refs/heads/main".into(),
        })
        .unwrap();
    let resolved = runner
        .run(GitCommand::RevParse {
            bare_repository: cache.clone(),
            revision: format!("{PRIVATE_REF}^{{commit}}"),
        })
        .unwrap();
    let commit = String::from_utf8(resolved.stdout)
        .unwrap()
        .trim()
        .to_owned();
    assert!(commit.bytes().all(|byte| byte.is_ascii_hexdigit()));
    let tree = String::from_utf8(
        runner
            .run(GitCommand::RevParse {
                bare_repository: cache.clone(),
                revision: format!("{PRIVATE_REF}^{{tree}}"),
            })
            .unwrap()
            .stdout,
    )
    .unwrap()
    .trim()
    .to_owned();
    let snapshot = GitSnapshot {
        identity: CanonicalIdentity::remote("github:fixture/source").unwrap(),
        requested_ref: Some("main".into()),
        fetched_ref: "refs/heads/main".into(),
        commit,
        tree,
        bare_repository: cache,
    };
    let inventory = scan(&GitTreeReader::new(&runner, &snapshot)).unwrap();
    assert_eq!(inventory.skills[0].files[0].size, 2 * 1024 * 1024);
}

#[test]
fn production_runner_inspects_only_a_clean_pinned_worktree() {
    let fixture = tempfile::tempdir().unwrap();
    let root = fixture.path().canonicalize().unwrap();
    let source = root.join("source");
    let project = root.join("project");
    let home = root.join("home");
    for path in [&source, &project, &home] {
        fs::create_dir(path).unwrap();
    }
    git(&source, ["init"]);
    git(&source, ["config", "user.name", "Fixture"]);
    git(&source, ["config", "user.email", "fixture@example.com"]);
    fs::write(source.join("SKILL.md"), b"---\nname: pinned\n---\n").unwrap();
    git(&source, ["add", "SKILL.md"]);
    git(&source, ["commit", "-m", "fixture"]);
    fs::write(
        project.join("grimoire.toml"),
        b"schema = \"grimoire/manifest@1\"\n[sources.local]\npath = \"../source\"\n",
    )
    .unwrap();
    let paths = Paths::project(project, home).unwrap();
    let runner = SystemGitRunner::default();

    let info =
        inspect_pinned_source(paths.clone(), SourceAlias::new("local").unwrap(), &runner).unwrap();
    assert_eq!(info.inventory.skills[0].name, "pinned");
    assert!(info.candidate.commit.is_some());

    fs::write(source.join("dirty"), b"untracked").unwrap();
    assert!(inspect_pinned_source(paths, SourceAlias::new("local").unwrap(), &runner).is_err());
}

#[test]
fn production_runner_forwards_only_validated_credentials_into_a_cleared_environment() {
    let fixture = tempfile::tempdir().unwrap();
    let root = fixture.path().canonicalize().unwrap();
    let recorder = root.join("git-recorder");
    let agent = root.join("agent.sock");
    let askpass = root.join("askpass");
    fs::write(
        &recorder,
        b"#!/bin/sh\n\
printf 'home=%s\\n' \"${HOME-unset}\"\n\
printf 'ssh-agent=%s\\n' \"${SSH_AUTH_SOCK-unset}\"\n\
printf 'askpass=%s\\n' \"${GIT_ASKPASS-unset}\"\n\
printf 'global=%s\\n' \"${GIT_CONFIG_GLOBAL-unset}\"\n\
printf 'system=%s\\n' \"${GIT_CONFIG_NOSYSTEM-unset}\"\n\
printf 'count=%s\\n' \"${GIT_CONFIG_COUNT-unset}\"\n\
printf 'ambient-helper=%s\\n' \"${GIT_SSH_COMMAND-unset}\"\n\
printf 'argv='\n\
printf '%s|' \"$@\"\n",
    )
    .unwrap();
    let mut permissions = fs::metadata(&recorder).unwrap().permissions();
    permissions.set_mode(0o700);
    fs::set_permissions(&recorder, permissions).unwrap();

    let runner = SystemGitRunner::new(recorder)
        .unwrap()
        .with_ssh_agent(agent.clone())
        .unwrap()
        .with_askpass(askpass.clone())
        .unwrap();
    let result = runner
        .run(GitCommand::LsRemote {
            repository: "https://example.invalid/repository.git".into(),
        })
        .unwrap();
    let output = String::from_utf8(result.stdout).unwrap();

    assert!(output.contains("home=unset\n"));
    assert!(output.contains(&format!("ssh-agent={}\n", agent.display())));
    assert!(output.contains(&format!("askpass={}\n", askpass.display())));
    assert!(output.contains("global=/dev/null\n"));
    assert!(output.contains("system=1\n"));
    assert!(output.contains("count=9\n"));
    assert!(output.contains("ambient-helper=unset\n"));
    assert!(output
        .contains("argv=ls-remote|--symref|--exit-code|https://example.invalid/repository.git|"));
}

fn git<const N: usize>(directory: &std::path::Path, args: [&str; N]) {
    let status = Command::new("git")
        .current_dir(directory)
        .args(args)
        .status()
        .unwrap();
    assert!(status.success());
}
