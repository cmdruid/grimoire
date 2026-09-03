use ratatui::layout::{Constraint, Direction, Layout};
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};
use ratatui::Frame;

use super::TuiModel;

pub fn draw(frame: &mut Frame<'_>, model: &TuiModel) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Min(1)])
        .split(frame.area());
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(38), Constraint::Percentage(62)])
        .split(rows[1]);

    frame.render_widget(Paragraph::new("Project  Global"), rows[0]);

    let tree = model
        .tree()
        .items
        .iter()
        .map(|item| {
            let marker = if item.toggleable {
                if item.selected {
                    "[x] "
                } else {
                    "[ ] "
                }
            } else {
                "    "
            };
            format!("{}{}{}", "  ".repeat(item.depth.into()), marker, item.label)
        })
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
