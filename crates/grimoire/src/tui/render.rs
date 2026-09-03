use grimoire_core::{PackSelection, SkillAvailability, TreeItem, TreeItemKind, TrustMode};
use ratatui::layout::{Constraint, Direction, Layout};
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};
use ratatui::Frame;

use super::{ActiveScope, TuiModel};

pub fn draw(frame: &mut Frame<'_>, model: &TuiModel) {
    if frame.area().width < 40 || frame.area().height < 7 {
        frame.render_widget(
            Paragraph::new("Terminal too small (need 40x7)"),
            frame.area(),
        );
        return;
    }

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Min(1)])
        .split(frame.area());
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(42), Constraint::Percentage(58)])
        .split(rows[1]);

    let tabs = match model.active_scope() {
        ActiveScope::Project => "[Project]  Global",
        ActiveScope::Global => "Project  [Global]",
    };
    frame.render_widget(Paragraph::new(tabs), rows[0]);

    let tree_height = usize::from(columns[0].height.saturating_sub(2));
    let tree = model
        .visible_items(tree_height)
        .iter()
        .map(render_item)
        .collect::<Vec<_>>()
        .join("\n");
    frame.render_widget(
        Paragraph::new(tree).block(Block::default().title("Tree").borders(Borders::ALL)),
        columns[0],
    );

    let plan = String::from_utf8_lossy(&model.plan_bytes().unwrap_or_default()).into_owned();
    frame.render_widget(
        Paragraph::new(plan)
            .block(Block::default().title("Plan").borders(Borders::ALL))
            .wrap(Wrap { trim: false }),
        columns[1],
    );
}

fn render_item(item: &TreeItem) -> String {
    let marker = match item.kind {
        TreeItemKind::Source { .. } => "    ",
        TreeItemKind::Pack(PackSelection::Off) => "[ ] ",
        TreeItemKind::Pack(PackSelection::Partial) => "[-] ",
        TreeItemKind::Pack(PackSelection::Full) => "[x] ",
        TreeItemKind::Skill(SkillAvailability::Required) => "[x] ",
        TreeItemKind::Skill(SkillAvailability::Unavailable) => "[!] ",
        TreeItemKind::Skill(SkillAvailability::Inherited) => "[=] ",
        TreeItemKind::Skill(_) if item.selected => "[x] ",
        TreeItemKind::Skill(_) => "[ ] ",
    };
    let facts = match item.kind {
        TreeItemKind::Source {
            live,
            trust,
            candidate_current,
            has_findings,
        } => {
            let trust = match trust {
                TrustMode::Untrusted => "untrusted",
                TrustMode::Snapshot => "trusted-snapshot",
                TrustMode::All => "trusted-all",
            };
            format!(
                " [{}{}{}]",
                if live { "live," } else { "" },
                trust,
                if !candidate_current || has_findings {
                    ",attention"
                } else {
                    ""
                }
            )
        }
        TreeItemKind::Skill(_) if item.shadowed => " [shadowed]".into(),
        _ => item
            .inert_reason
            .as_ref()
            .map(|reason| format!(" [{reason}]"))
            .unwrap_or_default(),
    };
    format!(
        "{}{}{}{}",
        "  ".repeat(item.depth.into()),
        marker,
        item.label,
        facts
    )
}
