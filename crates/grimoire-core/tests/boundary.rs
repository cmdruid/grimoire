use grimoire_core::{plan, InstalledLink, PlanningMode, Request, Scope, WorldState};

const CARGO: &str = include_str!("../Cargo.toml");
const LIB: &str = include_str!("../src/lib.rs");
const MODEL: &str = include_str!("../src/model.rs");
const PLAN: &str = include_str!("../src/plan.rs");

#[test]
fn phase_four_planner_has_no_adapter_or_ambient_dependency() {
    for forbidden in [
        "clap",
        "ratatui",
        "tokio",
        "reqwest",
        "git2",
        "std::env",
        "Command::new",
        "AgentTarget",
        "AgentEnv",
        "LiveLibrary",
        "LibraryConfig",
        "InstallLog",
        "ImmediateInstall",
        "ImmediateRemove",
    ] {
        assert!(
            !format!("{CARGO}\n{LIB}\n{MODEL}\n{PLAN}").contains(forbidden),
            "forbidden Phase 4 planner boundary: {forbidden}"
        );
    }
}

#[test]
fn planning_an_identical_immutable_world_never_refreshes_or_replans() {
    let state = WorldState::from_bytes(
        Scope::Project,
        b"schema = \"grimoire/manifest@2\"\n".to_vec(),
        include_bytes!("fixtures/lock/empty.json").to_vec(),
        [],
        std::iter::empty::<(&str, InstalledLink)>(),
        None,
    )
    .unwrap();
    let first = plan(&state, Request::Reconcile, PlanningMode::Normal).unwrap();
    let second = plan(&state, Request::Reconcile, PlanningMode::Normal).unwrap();
    assert_eq!(first, second);
}
