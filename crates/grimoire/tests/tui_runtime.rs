#[path = "fixtures/tui.rs"]
mod fixture;

use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::ffi::OsString;
use std::io;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;

use grimoire_core::{
    CandidateRecord, LockSkill, LockSource, Lockfile, RequestRoot, Scope, SnapshotId, SnapshotKind,
    SourceAlias, TreeItemKey, WorldState,
};
use skill_grimoire::command::{run_from, Console};
use skill_grimoire::env::Environment;
use skill_grimoire::runtime::SystemGitRunner;
use skill_grimoire::tui::{drive, Dialog, Driver, DriverEvent, Effect, JobOutcome, TuiModel};

#[test]
fn additive_destructive_blocked_and_trust_all_use_distinct_ceremonies() {
    let project = with_candidate(
        fixture::world(
            Scope::Project,
            "project",
            &["local"],
            concat!(
                "schema = \"grimoire/manifest@3\"\n",
                "[sources.project]\nurl = \"github:fixture/project\"\n",
            ),
        ),
        "project",
    );
    let mut model = TuiModel::new(project).unwrap();
    let local = TreeItemKey::Skill {
        source: "project".try_into().unwrap(),
        name: "local".try_into().unwrap(),
    };
    model.toggle(&local).unwrap();
    assert!(model.is_staged());
    assert!(matches!(
        model.request_apply(),
        Some(Effect::Apply {
            approval: grimoire_core::Approval::NotRequired,
            ..
        })
    ));

    model
        .accept_reloaded_scope(with_candidate(
            fixture::world(
                Scope::Project,
                "project",
                &["local"],
                concat!(
                    "schema = \"grimoire/manifest@3\"\n",
                    "[sources.project]\nurl = \"github:fixture/project\"\n",
                    "[skills]\nlocal = { source = \"project\" }\n",
                ),
            ),
            "project",
        ))
        .unwrap();
    model.toggle(&local).unwrap();
    assert!(model.request_apply().is_none());
    assert!(matches!(model.dialog(), Some(Dialog::ConfirmDestructive)));
    assert!(matches!(
        model.confirm(true),
        Some(Effect::Apply {
            approval: grimoire_core::Approval::Granted,
            ..
        })
    ));

    let mut untrusted = fixture::world(
        Scope::Project,
        "project",
        &["local"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.project]\nurl = \"github:fixture/project\"\n",
        ),
    );
    untrusted.trust_bytes = None;
    let mut blocked = TuiModel::new(untrusted).unwrap();
    blocked.toggle(&local).unwrap();
    assert!(blocked.request_apply().is_none());
    assert!(matches!(blocked.dialog(), Some(Dialog::Blocked { .. })));

    assert!(model
        .request_trust_all(SourceAlias::new("project").unwrap())
        .unwrap()
        .is_none());
    assert!(matches!(
        model.dialog(),
        Some(Dialog::ConfirmTrustAll {
            source_key,
            baseline,
            ..
        }) if !source_key.as_str().is_empty() && baseline.commit.as_deref() == Some("1111111111111111111111111111111111111111")
    ));
    assert!(matches!(
        model.confirm(true),
        Some(Effect::TrustAll { plan, .. }) if plan.actions.iter().any(|action| matches!(
            action,
            grimoire_core::Action::ReplaceTrust {
                change: grimoire_core::TrustChange::GrantAll,
                ..
            }
        ))
    ));
}

#[test]
fn source_actions_are_explicit_and_staged_quit_discards_in_memory_edits() {
    let project = with_candidate(
        fixture::world(
            Scope::Project,
            "project",
            &["local"],
            concat!(
                "schema = \"grimoire/manifest@3\"\n",
                "[sources.project]\nurl = \"github:fixture/project\"\n",
            ),
        ),
        "project",
    );
    let mut model = TuiModel::new(project).unwrap();
    let alias = SourceAlias::new("project").unwrap();
    assert_eq!(
        model.request_fetch(alias.clone()),
        Effect::Fetch {
            scope: Scope::Project,
            alias: alias.clone()
        }
    );
    assert!(matches!(
        model.request_update(alias.clone()).unwrap(),
        Some(Effect::Update {
            scope: Scope::Project,
            alias: update_alias,
            approval: grimoire_core::Approval::NotRequired,
            ..
        }) if update_alias == alias
    ));

    model
        .toggle(&TreeItemKey::Skill {
            source: "project".try_into().unwrap(),
            name: "local".try_into().unwrap(),
        })
        .unwrap();
    assert_eq!(model.request_quit().unwrap(), Effect::Quit);
    assert!(!model.is_staged());
}

#[test]
fn cached_source_update_uses_its_exact_plan_and_destructive_confirmation() {
    let project = with_updated_candidate(
        with_current_lock(
            fixture::world(
                Scope::Project,
                "project",
                &["local"],
                concat!(
                    "schema = \"grimoire/manifest@3\"\n",
                    "[sources.project]\nurl = \"github:fixture/project\"\n",
                    "[skills]\nlocal = { source = \"project\" }\n",
                ),
            ),
            "project",
            "local",
        ),
        "project",
    );
    let alias = SourceAlias::new("project").unwrap();
    let mut model = TuiModel::new(project).unwrap();
    assert!(model.request_update(alias.clone()).unwrap().is_none());
    assert!(matches!(model.dialog(), Some(Dialog::ConfirmDestructive)));
    assert!(model.confirm(false).is_none());

    assert!(model.request_update(alias.clone()).unwrap().is_none());
    assert!(matches!(
        model.confirm(true),
        Some(Effect::Update {
            alias: update_alias,
            approval: grimoire_core::Approval::Granted,
            plan,
            ..
        }) if update_alias == alias && plan.is_destructive()
    ));
}

fn with_candidate(world: WorldState, alias: &str) -> WorldState {
    let alias = SourceAlias::new(alias).unwrap();
    let mut state = world.source_states.get(&alias).unwrap().clone();
    let record = CandidateRecord::new(
        world.manifest.source_declaration_hash(&alias).unwrap(),
        state.identity.clone().unwrap(),
        state.snapshot.id.commit.clone(),
        state.snapshot.id.tree.clone(),
        state.snapshot.id.inventory_digest.clone(),
        state.review_tree.clone().unwrap(),
    )
    .unwrap();
    state = state.candidate(record.to_bytes().unwrap());
    world.with_candidate(state).unwrap()
}

fn with_updated_candidate(world: WorldState, alias: &str) -> WorldState {
    let alias = SourceAlias::new(alias).unwrap();
    let mut state = world.source_states.get(&alias).unwrap().clone();
    state.snapshot.id = SnapshotId::new(
        SnapshotKind::Git,
        Some("3".repeat(40)),
        Some("4".repeat(40)),
        state.snapshot.id.inventory_digest.clone(),
    )
    .unwrap();
    state.snapshot.root = PathBuf::from(format!("/store/{alias}/updated"));
    let record = CandidateRecord::new(
        world.manifest.source_declaration_hash(&alias).unwrap(),
        state.identity.clone().unwrap(),
        state.snapshot.id.commit.clone(),
        state.snapshot.id.tree.clone(),
        state.snapshot.id.inventory_digest.clone(),
        state.review_tree.clone().unwrap(),
    )
    .unwrap();
    state = state.candidate(record.to_bytes().unwrap());
    world.with_candidate(state).unwrap()
}

fn with_current_lock(mut world: WorldState, alias: &str, skill: &str) -> WorldState {
    let alias = SourceAlias::new(alias).unwrap();
    let state = world.source_states.get(&alias).unwrap();
    let skill_fact = state
        .snapshot
        .inventory
        .skills
        .iter()
        .find(|candidate| candidate.name == skill)
        .unwrap();
    let lock = Lockfile {
        sources: BTreeMap::from([(
            alias.clone(),
            LockSource::Git {
                declared: world
                    .manifest
                    .sources
                    .get(&alias)
                    .unwrap()
                    .declared()
                    .into(),
                reference: None,
                commit: state.snapshot.id.commit.clone().unwrap(),
                tree: state.snapshot.id.tree.clone().unwrap(),
                inventory: state.snapshot.id.inventory_digest.clone(),
            },
        )]),
        packs: BTreeMap::new(),
        skills: BTreeMap::from([(
            skill.try_into().unwrap(),
            LockSkill {
                source: alias,
                mode: grimoire_core::ProjectionMode::Link,
                path: format!("skills/{skill}"),
                content: skill_fact.content_digest.to_string(),
                requested_by: BTreeSet::from([RequestRoot::Skill(skill.try_into().unwrap())]),
            },
        )]),
    };
    world.lock_bytes = lock.to_bytes().unwrap();
    world.lock = lock;
    world
}

#[derive(Default)]
struct ScriptDriver {
    terminal: bool,
    events: VecDeque<DriverEvent>,
    enters: usize,
    draws: usize,
    restores: usize,
    draw_error: bool,
    draw_panic: bool,
}

impl Driver for ScriptDriver {
    fn is_terminal(&self) -> bool {
        self.terminal
    }
    fn enter(&mut self) -> io::Result<()> {
        self.enters += 1;
        Ok(())
    }
    fn draw(&mut self, _model: &TuiModel) -> io::Result<()> {
        self.draws += 1;
        assert!(!self.draw_panic, "deliberate UI panic");
        if self.draw_error {
            Err(io::Error::other("deliberate UI error"))
        } else {
            Ok(())
        }
    }
    fn next_event(&mut self) -> io::Result<DriverEvent> {
        Ok(self.events.pop_front().unwrap())
    }
    fn restore(&mut self) -> io::Result<()> {
        self.restores += 1;
        Ok(())
    }
}

#[test]
fn scripted_driver_rejects_non_terminals_and_restores_once() {
    let world = grimoire_core::WorldState::absent(Scope::Global, [], [], None).unwrap();
    let mut model = TuiModel::new(world.clone()).unwrap();
    let mut not_terminal = ScriptDriver::default();
    assert!(drive(&mut not_terminal, &mut model, |_| Ok(JobOutcome::Unchanged)).is_err());
    assert_eq!((not_terminal.enters, not_terminal.restores), (0, 0));

    let mut model = TuiModel::new(world).unwrap();
    let mut terminal = ScriptDriver {
        terminal: true,
        events: VecDeque::from([DriverEvent::Resize(80, 24), DriverEvent::Quit]),
        ..ScriptDriver::default()
    };
    drive(&mut terminal, &mut model, |_| Ok(JobOutcome::Unchanged)).unwrap();
    assert!(terminal.draws >= 1);
    assert_eq!((terminal.enters, terminal.restores), (1, 1));
}

#[test]
fn scripted_driver_restores_once_after_ui_error_and_panic() {
    let world = grimoire_core::WorldState::absent(Scope::Global, [], [], None).unwrap();
    let mut model = TuiModel::new(world.clone()).unwrap();
    let mut error = ScriptDriver {
        terminal: true,
        draw_error: true,
        ..ScriptDriver::default()
    };
    assert!(drive(&mut error, &mut model, |_| Ok(JobOutcome::Unchanged)).is_err());
    assert_eq!((error.enters, error.restores), (1, 1));

    let mut model = TuiModel::new(world).unwrap();
    let mut panic = ScriptDriver {
        terminal: true,
        draw_panic: true,
        ..ScriptDriver::default()
    };
    assert!(catch_unwind(AssertUnwindSafe(|| {
        drive(&mut panic, &mut model, |_| Ok(JobOutcome::Unchanged))
    }))
    .is_err());
    assert_eq!((panic.enters, panic.restores), (1, 1));
}

#[test]
fn accepted_job_reload_discards_stale_staging_before_the_next_event() {
    let world = fixture::world(
        Scope::Project,
        "project",
        &["local"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.project]\nurl = \"github:fixture/project\"\n",
        ),
    );
    let mut model = TuiModel::new(world.clone()).unwrap();
    model
        .toggle(&TreeItemKey::Skill {
            source: "project".try_into().unwrap(),
            name: "local".try_into().unwrap(),
        })
        .unwrap();
    let mut driver = ScriptDriver {
        terminal: true,
        events: VecDeque::from([DriverEvent::Apply, DriverEvent::Quit]),
        ..ScriptDriver::default()
    };
    let mut jobs = 0;
    drive(&mut driver, &mut model, |_| {
        jobs += 1;
        Ok(JobOutcome::ReloadScope(Box::new(world.clone())))
    })
    .unwrap();
    assert_eq!(jobs, 1);
    assert!(!model.is_staged());
    assert_eq!(driver.restores, 1);
}

struct FixedEnvironment;

impl Environment for FixedEnvironment {
    fn current_dir(&self) -> io::Result<PathBuf> {
        Ok(PathBuf::from("/fixture"))
    }

    fn var_os(&self, name: &str) -> Option<OsString> {
        (name == "HOME").then(|| OsString::from("/fixture/home"))
    }
}

#[derive(Default)]
struct RoutingConsole {
    terminal: bool,
    tui_runs: usize,
    stderr: Vec<u8>,
}

impl Console for RoutingConsole {
    fn is_terminal(&self) -> bool {
        self.terminal
    }

    fn read_line(&mut self, _line: &mut String) -> io::Result<usize> {
        Ok(0)
    }

    fn write_stdout(&mut self, _bytes: &[u8]) -> io::Result<()> {
        Ok(())
    }

    fn write_stderr(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.stderr.extend_from_slice(bytes);
        Ok(())
    }

    fn run_tui(&mut self, _environment: &dyn Environment) -> grimoire_core::Result<u8> {
        self.tui_runs += 1;
        Ok(0)
    }
}

#[test]
fn bare_invocation_rejects_nonterminals_before_routing_to_the_driver() {
    let mut nonterminal = RoutingConsole::default();
    assert_eq!(
        run_from(
            ["grimoire"],
            &FixedEnvironment,
            &mut nonterminal,
            &SystemGitRunner::default(),
        ),
        2
    );
    assert_eq!(nonterminal.tui_runs, 0);
    assert!(!nonterminal.stderr.contains(&0x1b));

    let mut terminal = RoutingConsole {
        terminal: true,
        ..RoutingConsole::default()
    };
    assert_eq!(
        run_from(
            ["grimoire"],
            &FixedEnvironment,
            &mut terminal,
            &SystemGitRunner::default(),
        ),
        0
    );
    assert_eq!(terminal.tui_runs, 1);
}
