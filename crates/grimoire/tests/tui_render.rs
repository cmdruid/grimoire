#[path = "fixtures/tui.rs"]
mod fixture;

use grimoire_core::Scope;
use ratatui::{backend::TestBackend, Terminal};
use skill_grimoire::tui::{draw, TuiModel};

#[test]
fn small_terminals_render_a_bounded_remedy_instead_of_overflowing() {
    let global = fixture::world(
        Scope::Global,
        "global",
        &["one", "two", "three"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.global]\nurl = \"github:fixture/global\"\n",
        ),
    );
    let model = TuiModel::from_scopes(None, global).unwrap();
    let backend = TestBackend::new(28, 5);
    let mut terminal = Terminal::new(backend).unwrap();
    terminal.draw(|frame| draw(frame, &model)).unwrap();

    let rendered = terminal.backend().to_string();
    assert_eq!(rendered.lines().count(), 5);
    assert!(rendered.contains("Terminal too small"));
}

#[test]
fn representative_tree_buffer_is_stable() {
    let global = fixture::world(
        Scope::Global,
        "global",
        &["journal"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.global]\nurl = \"github:fixture/global\"\n",
        ),
    );
    let model = TuiModel::from_scopes(None, global).unwrap();
    let backend = TestBackend::new(72, 8);
    let mut terminal = Terminal::new(backend).unwrap();
    terminal.draw(|frame| draw(frame, &model)).unwrap();

    let rendered = terminal.backend().to_string();
    assert_eq!(
        rendered,
        concat!(
            "\"Project  [Global]                                                       \"\n",
            "\"┌Tree────────────────────────┐┌Plan────────────────────────────────────┐\"\n",
            "\"│>    global [trusted-all,att││{                                       │\"\n",
            "\"│   [ ] journal              ││  \"actions\": [],                        │\"\n",
            "\"│                            ││  \"blockers\": [],                       │\"\n",
            "\"│                            ││  \"preconditions\": {                    │\"\n",
            "\"│                            ││    \"manifest\":                         │\"\n",
            "\"└────────────────────────────┘└────────────────────────────────────────┘\"\n",
        )
    );
}

#[test]
fn project_request_rows_render_projection_mode_labels() {
    let project = fixture::world(
        Scope::Project,
        "project",
        &["one"],
        concat!(
            "schema = \"grimoire/manifest@3\"\n",
            "[sources.project]\nurl = \"github:fixture/project\"\n",
            "[skills]\none = { source = \"project\" }\n",
        ),
    );
    let model = TuiModel::new(project).unwrap();
    let backend = TestBackend::new(72, 8);
    let mut terminal = Terminal::new(backend).unwrap();
    terminal.draw(|frame| draw(frame, &model)).unwrap();

    assert!(terminal.backend().to_string().contains("one [linked]"));
}
