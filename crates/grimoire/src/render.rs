//! Drawing — a projection of [`App`], holding no decisions of its own.
//!
//! **Themed verbs** (roadmap, binding): `learn`/install, `forget`/remove,
//! `peruse`/list are the action labels; the plain aliases appear in help. The
//! theming stops at labels — everything machine-facing (lock keys, pack and
//! member names, `check`'s findings) stays plain, because those are the words a
//! user has to match against files and the spec.

use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};
use ratatui::Frame;

use grimoire_core::target::Scope;

use crate::app::{describe_disposition, describe_finding, App, Row, Screen};

const HELP: &str = "\
grimoire — keys

  up / down     move
  enter         learn (install) the selected pack or skill
  d             forget (remove) the selected pack
  tab           next agent
  s             switch scope (global / project)
  r             re-peruse (refresh) the library
  ?             this help
  q             quit

Themed verbs are labels only: learn = install, forget = remove,
peruse = list. Pack and member names, and check's findings, are
always plain.
";

pub fn draw(frame: &mut Frame, app: &App) {
    let areas = Layout::vertical([
        Constraint::Length(3), // scope picker
        Constraint::Min(6),    // the library
        Constraint::Length(3), // status
    ])
    .split(frame.area());

    draw_scope(frame, areas[0], app);
    draw_library(frame, areas[1], app);
    draw_status(frame, areas[2], app);

    match &app.screen {
        Screen::Library => {}
        Screen::Confirm(plan) => {
            let mut lines = vec![
                Line::from(Span::styled(
                    format!("learn {} v{}", plan.pack, version_of(app, &plan.pack)),
                    Style::default().add_modifier(Modifier::BOLD),
                )),
                Line::from(format!("into {}", plan.target.skills_dir.display())),
                Line::from(""),
            ];
            // §5: a reinstall must surface a backward version or a changed
            // source, and say what it will drop. Never silent.
            if let Some(replacing) = &plan.replacing {
                lines.push(Line::from(Span::styled(
                    "reinstall over an existing entry:",
                    Style::default().fg(Color::Yellow),
                )));
                lines.push(Line::from(format!(
                    "  was v{} from {}",
                    replacing.previous_version, replacing.previous_source
                )));
                if replacing.version_moves_backward {
                    lines.push(Line::from(Span::styled(
                        "  the version moves BACKWARD",
                        Style::default().fg(Color::Yellow),
                    )));
                }
                if replacing.source_changed {
                    lines.push(Line::from(Span::styled(
                        "  the source has CHANGED",
                        Style::default().fg(Color::Yellow),
                    )));
                }
                if !replacing.dropped.is_empty() {
                    lines.push(Line::from(format!(
                        "  will drop: {}",
                        replacing.dropped.join(", ")
                    )));
                }
                lines.push(Line::from(""));
            }
            for (member, disposition) in &plan.members {
                let text = format!(
                    "  {:<24} {}{}",
                    member.name,
                    describe_disposition(disposition),
                    if member.is_face {
                        "  [face]"
                    } else if member.required {
                        "  [required]"
                    } else {
                        "  [optional]"
                    }
                );
                let style = if disposition.is_blocking() {
                    Style::default().fg(Color::Red)
                } else {
                    Style::default()
                };
                lines.push(Line::from(Span::styled(text, style)));
            }
            lines.push(Line::from(""));
            lines.push(if plan.is_installable() {
                Line::from(Span::styled(
                    "enter = learn it    any other key = back",
                    Style::default().fg(Color::Green),
                ))
            } else {
                // D3: no key resolves this. Say what the user can actually do.
                Line::from(Span::styled(
                    "blocked — clear the collision by hand or pick another scope. \
                     any key = back",
                    Style::default().fg(Color::Red),
                ))
            });
            overlay(frame, " confirm ", lines);
        }
        Screen::ConfirmRemove(plan) => {
            let mut lines = vec![
                Line::from(Span::styled(
                    format!("forget {}", plan.pack),
                    Style::default().add_modifier(Modifier::BOLD),
                )),
                Line::from(""),
            ];
            for (member, _) in &plan.unlink {
                lines.push(Line::from(format!("  unlink  {member}")));
            }
            for (member, holder) in &plan.retained {
                lines.push(Line::from(format!(
                    "  keep    {member} — {holder} still holds it"
                )));
            }
            for (member, at) in &plan.foreign {
                lines.push(Line::from(Span::styled(
                    format!("  leave   {member} — not ours ({})", at.display()),
                    Style::default().fg(Color::Yellow),
                )));
            }
            // §5 MUST: say this BEFORE anything is deleted, while the face is
            // still there to be read.
            if let Some(face) = &plan.face_warning {
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled(
                    "this pack may have set things up in your project; removing it",
                    Style::default().fg(Color::Yellow),
                )));
                lines.push(Line::from(Span::styled(
                    "does not undo that. Its face has any teardown guidance:",
                    Style::default().fg(Color::Yellow),
                )));
                lines.push(Line::from(format!("  {}", face.display())));
            }
            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                "enter = forget it    any other key = back",
                Style::default().fg(Color::Green),
            )));
            overlay(frame, " confirm ", lines);
        }
        Screen::Outcome(text) => overlay(
            frame,
            " done ",
            vec![
                Line::from(text.as_str()),
                Line::from(""),
                Line::from(Span::styled(
                    "any key = back",
                    Style::default().fg(Color::Green),
                )),
            ],
        ),
        Screen::Help => overlay(frame, " help ", HELP.lines().map(Line::from).collect()),
    }
}

fn draw_scope(frame: &mut Frame, area: Rect, app: &App) {
    let agent = app.agent();
    let scope = match app.scope {
        Scope::Global => "global".to_string(),
        Scope::Project => format!(
            "project {}",
            crate::job::project_label(app.project_root.as_ref())
        ),
    };
    let where_to = app.target().map_or_else(
        || "— no destination".to_string(),
        |t| format!("→ {}", t.skills_dir.display()),
    );
    let line = Line::from(vec![
        Span::styled(
            format!(" {} ", agent.display_name),
            Style::default().add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            if agent.detected() {
                "(detected) "
            } else {
                "(not detected) "
            },
            Style::default().fg(if agent.detected() {
                Color::Green
            } else {
                Color::DarkGray
            }),
        ),
        Span::raw(format!("{scope}  {where_to}")),
    ]);
    frame.render_widget(
        Paragraph::new(line).block(
            Block::default()
                .borders(Borders::ALL)
                .title(" scope — tab: agent, s: global/project "),
        ),
        area,
    );
}

fn draw_library(frame: &mut Frame, area: Rect, app: &App) {
    let rows = app.rows();
    if rows.is_empty() {
        let msg = if app.busy.is_some() {
            "perusing…"
        } else {
            "nothing here — is --library pointing at a skills tree?"
        };
        frame.render_widget(
            Paragraph::new(msg).block(Block::default().borders(Borders::ALL).title(" library ")),
            area,
        );
        return;
    }

    let items: Vec<ListItem> = rows
        .iter()
        .map(|row| {
            let (kind, name) = match row {
                Row::Pack(n) => ("pack ", n),
                Row::Loose(n) => ("skill", n),
            };
            let installed = matches!(row, Row::Pack(_)) && app.is_installed(name);
            let mut spans = vec![
                Span::styled(format!(" {kind} "), Style::default().fg(Color::DarkGray)),
                Span::raw(format!("{name:<28}")),
            ];
            if installed {
                spans.push(Span::styled(
                    "installed here",
                    Style::default().fg(Color::Green),
                ));
            }
            if let Some(members) = members_of(app, row) {
                spans.push(Span::styled(
                    format!("  {members}"),
                    Style::default().fg(Color::DarkGray),
                ));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();

    let mut state = ListState::default();
    state.select(Some(app.cursor.min(rows.len().saturating_sub(1))));
    frame.render_stateful_widget(
        List::new(items)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(" library — enter: learn, d: forget, r: re-peruse, ?: help "),
            )
            .highlight_style(Style::default().add_modifier(Modifier::REVERSED))
            .highlight_symbol("> "),
        area,
        &mut state,
    );
}

fn draw_status(frame: &mut Frame, area: Rect, app: &App) {
    let text = match app.busy {
        Some(what) => format!("… {what}"),
        None => app.status.clone(),
    };
    // The ambient check's findings live here (facts, not verdicts).
    frame.render_widget(
        Paragraph::new(text)
            .wrap(Wrap { trim: true })
            .block(Block::default().borders(Borders::ALL).title(" status ")),
        area,
    );
}

/// A pack's member roster, abbreviated for the list row.
fn members_of(app: &App, row: &Row) -> Option<String> {
    let Row::Pack(name) = row else { return None };
    let view = app.view.as_ref()?;
    let pack = view.packs.iter().find(|p| &p.name == name)?;
    let required = pack.members.iter().filter(|m| m.required).count();
    let optional = pack.members.len() - required;
    Some(if optional > 0 {
        format!(
            "v{} · {required} required + {optional} optional",
            pack.version
        )
    } else {
        format!("v{} · {required} members", pack.version)
    })
}

fn version_of(app: &App, pack: &str) -> String {
    app.view
        .as_ref()
        .and_then(|v| v.packs.iter().find(|p| p.name == pack))
        .map_or_else(|| "?".to_string(), |p| p.version.to_string())
}

/// A centred panel over the screen. `Clear` first — without it the list bleeds
/// through, which reads as corruption rather than a dialog.
fn overlay(frame: &mut Frame, title: &str, lines: Vec<Line>) {
    let area = frame.area();
    let width = area.width.saturating_sub(8).max(20);
    let inner = usize::from(width.saturating_sub(2)).max(1);

    // Wrap here rather than letting `Paragraph` do it, so the panel's height is
    // the exact row count instead of a guess. Sizing by `lines.len()` clipped
    // the last line off a collision dialog — and that line is the one saying
    // what the user can do about it. Estimating with `ceil(len / width)` was
    // still short, because greedy word wrap cannot pack a long path that
    // tightly. Pre-wrapping removes the estimate entirely. Caught, both times,
    // by `tests/render.rs`.
    let lines = wrap_lines(lines, inner);
    let height = u16::try_from(lines.len() + 2)
        .unwrap_or(u16::MAX)
        .min(area.height.saturating_sub(2))
        .max(3);
    let panel = Rect {
        x: area.x + (area.width.saturating_sub(width)) / 2,
        y: area.y + (area.height.saturating_sub(height)) / 2,
        width,
        height,
    };
    frame.render_widget(Clear, panel);
    frame.render_widget(
        Paragraph::new(lines).block(
            Block::default()
                .borders(Borders::ALL)
                .title(title.to_string()),
        ),
        panel,
    );
}

/// Greedy word wrap to `inner` columns, keeping each source line's style.
///
/// A word longer than the width (a long path, which is most of what wraps here)
/// is split rather than allowed to overflow.
fn wrap_lines(lines: Vec<Line>, inner: usize) -> Vec<Line<'static>> {
    let mut out = Vec::new();
    for line in lines {
        let style = line.spans.first().map_or_else(Style::default, |s| s.style);
        let text = line.to_string();
        if text.trim().is_empty() {
            out.push(Line::from(""));
            continue;
        }
        let mut current = String::new();
        for word in text.split_whitespace() {
            let mut word = word;
            // Oversized token: emit full-width chunks until it fits.
            while word.chars().count() > inner {
                if !current.is_empty() {
                    out.push(Line::from(Span::styled(
                        std::mem::take(&mut current),
                        style,
                    )));
                }
                let split = word
                    .char_indices()
                    .nth(inner)
                    .map_or(word.len(), |(i, _)| i);
                let (head, tail) = word.split_at(split);
                out.push(Line::from(Span::styled(head.to_string(), style)));
                word = tail;
            }
            let needed = if current.is_empty() {
                word.chars().count()
            } else {
                current.chars().count() + 1 + word.chars().count()
            };
            if needed > inner {
                out.push(Line::from(Span::styled(
                    std::mem::take(&mut current),
                    style,
                )));
                current.push_str(word);
            } else {
                if !current.is_empty() {
                    current.push(' ');
                }
                current.push_str(word);
            }
        }
        if !current.is_empty() {
            out.push(Line::from(Span::styled(current, style)));
        }
    }
    out
}

/// The findings list, for a caller that wants them all rather than the one-line
/// summary the status bar shows.
#[must_use]
pub fn all_findings(app: &App) -> Vec<String> {
    app.report
        .as_ref()
        .map(|r| r.findings.iter().map(describe_finding).collect())
        .unwrap_or_default()
}
