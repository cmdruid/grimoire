//! App state and the transitions over it — no rendering, no terminal, no I/O.
//!
//! Everything here is a pure function of (state, event). Jobs are *returned*
//! rather than dispatched, so a test can drive the whole interaction — pick a
//! scope, install, hit a collision, back out — without a worker or a screen,
//! and the render layer stays a projection of state rather than a place where
//! decisions hide.
//!
//! Two decisions from the plan shape it:
//!
//! - **D2: one picked scope.** The screen shows the library plus *one* target's
//!   installed state. §3 makes an operation target exactly one scope, and
//!   `inventory` answers per target for the same reason. The picker is always
//!   visible so "which scope am I looking at?" is never a question.
//! - **D3: collisions render and stop.** A blocking preflight becomes a screen
//!   the user reads, not a prompt that resolves it — §5 permits adopt/replace
//!   but forbids resolving silently, and core implements no staging to make a
//!   replace safe.

use std::path::PathBuf;

use grimoire_core::agents::Agent;
use grimoire_core::check::CheckReport;
use grimoire_core::install::{InstallOutcome, InstallPlan, MemberDisposition};
use grimoire_core::inventory::Inventory;
use grimoire_core::library::{Library, LibraryView};
use grimoire_core::remove::RemovePlan;
use grimoire_core::target::{Scope, Target};

use crate::env::AppEnv;
use crate::job::{Done, Job};

/// A row on the library screen. Packs first, then loose skills — the order
/// `LibraryView` already returns them in.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Row {
    Pack(String),
    Loose(String),
}

impl Row {
    #[must_use]
    pub fn name(&self) -> &str {
        match self {
            Self::Pack(n) | Self::Loose(n) => n,
        }
    }
}

/// What the user is looking at. Modal on purpose: exactly one operation is ever
/// in flight, which is also why the worker is a single thread.
pub enum Screen {
    Library,
    /// §5's preflight, rendered. Carries whether it is installable — a blocking
    /// plan is shown and dismissed, never silently resolved (D3).
    Confirm(Box<InstallPlan>),
    ConfirmRemove(Box<RemovePlan>),
    Outcome(String),
    Help,
}

pub struct App {
    pub env: AppEnv,
    pub library_root: PathBuf,
    pub project_root: Option<PathBuf>,

    pub agents: Vec<Agent>,
    pub agent_index: usize,
    pub scope: Scope,

    pub view: Option<LibraryView>,
    pub inventory: Option<Inventory>,
    pub report: Option<CheckReport>,

    pub cursor: usize,
    pub screen: Screen,
    pub status: String,
    pub busy: Option<&'static str>,
    pub should_quit: bool,
}

impl App {
    #[must_use]
    pub fn new(env: AppEnv, library_root: PathBuf, project_root: Option<PathBuf>) -> Self {
        let agents = env.agents();
        // Open on a harness that is actually present, if any — the common case
        // is one or two installed, and landing on an absent one looks broken.
        let agent_index = agents.iter().position(Agent::detected).unwrap_or(0);
        Self {
            env,
            library_root,
            project_root,
            agents,
            agent_index,
            scope: Scope::Global,
            view: None,
            inventory: None,
            report: None,
            cursor: 0,
            screen: Screen::Library,
            status: "peruse the library — Enter to learn a pack".to_string(),
            busy: None,
            should_quit: false,
        }
    }

    #[must_use]
    pub fn library(&self) -> Library {
        Library::open(self.library_root.clone())
    }

    #[must_use]
    pub fn agent(&self) -> &Agent {
        &self.agents[self.agent_index]
    }

    /// The one target every operation on this screen uses (D2).
    ///
    /// `None` at project scope with no project opened — the app refuses to
    /// invent a project root, exactly as core refuses to invent a home.
    #[must_use]
    pub fn target(&self) -> Option<Target> {
        match self.scope {
            Scope::Global => Some(self.env.global_target(self.agent())),
            Scope::Project => self
                .project_root
                .as_ref()
                .map(|root| self.env.project_target(self.agent(), root)),
        }
    }

    /// The rows currently listed. Recomputed rather than cached: it is a cheap
    /// projection of `view`, and a stale cached list is how a cursor ends up
    /// pointing at a pack that is no longer there.
    #[must_use]
    pub fn rows(&self) -> Vec<Row> {
        let Some(view) = &self.view else {
            return Vec::new();
        };
        view.packs
            .iter()
            .map(|p| Row::Pack(p.name.clone()))
            .chain(view.loose.iter().map(|m| Row::Loose(m.name.clone())))
            .collect()
    }

    #[must_use]
    pub fn selected(&self) -> Option<Row> {
        self.rows().get(self.cursor).cloned()
    }

    /// Is this pack recorded in the current target's lock?
    #[must_use]
    pub fn is_installed(&self, pack: &str) -> bool {
        self.inventory
            .as_ref()
            .is_some_and(|i| i.packs.iter().any(|p| p.name == pack))
    }

    /// The jobs to run at startup: walk the library, then survey the target.
    #[must_use]
    pub fn launch(&mut self) -> Vec<Job> {
        self.busy = Some("perusing the library");
        let mut jobs = vec![Job::Enumerate(self.library())];
        if let Some(target) = self.target() {
            jobs.push(Job::Survey {
                library: self.library(),
                target,
            });
        }
        jobs
    }

    /// Re-survey after the target changes. The library itself has not moved, so
    /// this deliberately does not re-enumerate — that walk is the expensive one.
    #[must_use]
    fn resurvey(&mut self) -> Vec<Job> {
        match self.target() {
            Some(target) => {
                self.busy = Some("reading the scope");
                vec![Job::Survey {
                    library: self.library(),
                    target,
                }]
            }
            None => {
                self.inventory = None;
                self.report = None;
                self.status = "no project opened — pass --project <dir>".to_string();
                Vec::new()
            }
        }
    }

    /// Apply a finished job. Returns any follow-up work.
    pub fn apply(&mut self, done: Done) -> Vec<Job> {
        self.busy = None;
        match done {
            Done::Enumerated(view) => {
                self.view = Some(*view);
                let count = self.rows().len();
                self.cursor = self.cursor.min(count.saturating_sub(1));
                self.status = format!("{count} entries in {}", self.library_root.display());
                Vec::new()
            }
            Done::Surveyed { inventory, report } => {
                self.inventory = Some(*inventory);
                self.report = Some(*report);
                self.status = self.ambient_status();
                Vec::new()
            }
            Done::Preflighted(plan) => {
                self.status = if plan.is_installable() {
                    format!("{} is ready to learn", plan.pack)
                } else {
                    // D3: say what is wrong and stop. The confirm screen renders
                    // each blocking member; it offers no resolution.
                    format!("{} cannot be learned as things stand", plan.pack)
                };
                self.screen = Screen::Confirm(plan);
                Vec::new()
            }
            Done::Installed { pack, outcome } => {
                self.screen = Screen::Outcome(describe_install(&pack, &outcome));
                self.resurvey()
            }
            Done::RemovePlanned(plan) => {
                self.screen = Screen::ConfirmRemove(plan);
                Vec::new()
            }
            Done::Removed { pack } => {
                self.screen = Screen::Outcome(format!("forgot {pack}"));
                self.resurvey()
            }
            Done::Failed(why) => {
                self.screen = Screen::Outcome(format!("failed: {why}"));
                Vec::new()
            }
        }
    }

    /// `check`'s findings as a one-line status. Facts, not verdicts (§5): the
    /// count, and the first finding in full — never a judgement about severity.
    fn ambient_status(&self) -> String {
        let Some(report) = &self.report else {
            return String::new();
        };
        let installed = self.inventory.as_ref().map_or(0, |i| i.packs.len());
        if report.is_clean() {
            return format!("{installed} installed here — check found nothing amiss");
        }
        let notable: Vec<&grimoire_core::check::Finding> = report
            .findings
            .iter()
            .filter(|f| {
                !matches!(
                    f,
                    grimoire_core::check::Finding::OptionalMemberAbsent { .. }
                )
            })
            .collect();
        match notable.first() {
            Some(first) => format!(
                "{installed} installed — {} finding(s): {}",
                notable.len(),
                describe_finding(first)
            ),
            None => format!("{installed} installed here"),
        }
    }

    /// A key press. Returns jobs to dispatch.
    pub fn on_key(&mut self, key: Key) -> Vec<Job> {
        match &self.screen {
            Screen::Library => self.library_key(key),
            Screen::Confirm(_) => self.confirm_key(key),
            Screen::ConfirmRemove(_) => self.confirm_remove_key(key),
            Screen::Outcome(_) | Screen::Help => {
                // Any key returns; the content is already read.
                self.screen = Screen::Library;
                Vec::new()
            }
        }
    }

    fn library_key(&mut self, key: Key) -> Vec<Job> {
        match key {
            Key::Quit => {
                self.should_quit = true;
                Vec::new()
            }
            Key::Help => {
                self.screen = Screen::Help;
                Vec::new()
            }
            Key::Down => {
                let last = self.rows().len().saturating_sub(1);
                self.cursor = (self.cursor + 1).min(last);
                Vec::new()
            }
            Key::Up => {
                self.cursor = self.cursor.saturating_sub(1);
                Vec::new()
            }
            Key::NextAgent => {
                if !self.agents.is_empty() {
                    self.agent_index = (self.agent_index + 1) % self.agents.len();
                }
                self.resurvey()
            }
            Key::ToggleScope => {
                self.scope = match self.scope {
                    Scope::Global => Scope::Project,
                    Scope::Project => Scope::Global,
                };
                self.resurvey()
            }
            Key::Refresh => self.launch(),
            Key::Confirm => self.begin_install(),
            Key::Remove => self.begin_remove(),
            Key::Back => Vec::new(),
        }
    }

    fn begin_install(&mut self) -> Vec<Job> {
        let (Some(row), Some(target)) = (self.selected(), self.target()) else {
            self.status = "nothing to learn here".to_string();
            return Vec::new();
        };
        self.busy = Some("checking the destination");
        match row {
            Row::Pack(pack) => vec![Job::Preflight {
                library: self.library(),
                target,
                pack,
            }],
            // A loose skill is an atom: no lock entry, no preflight screen —
            // install.sh locks nothing for a bare skill either.
            Row::Loose(skill) => vec![Job::InstallAtom {
                library: self.library(),
                target,
                skill,
            }],
        }
    }

    fn begin_remove(&mut self) -> Vec<Job> {
        let (Some(row), Some(target)) = (self.selected(), self.target()) else {
            return Vec::new();
        };
        let Row::Pack(pack) = row else {
            self.status = "only packs can be forgotten — a loose skill has no lock entry"
                .to_string();
            return Vec::new();
        };
        if !self.is_installed(&pack) {
            self.status = format!("{pack} is not installed in this scope");
            return Vec::new();
        }
        self.busy = Some("planning removal");
        vec![Job::PlanRemove { target, pack }]
    }

    fn confirm_key(&mut self, key: Key) -> Vec<Job> {
        let Screen::Confirm(plan) = &self.screen else {
            return Vec::new();
        };
        match key {
            Key::Confirm if plan.is_installable() => {
                let Some(target) = self.target() else {
                    return Vec::new();
                };
                let pack = plan.pack.clone();
                // The optional members the user left out. v0.1 has no
                // deselection UI, so this is empty — but §5's "recorded optional
                // selections carry over" needs the field threaded from the start.
                let skip_optional = Vec::new();
                self.busy = Some("learning");
                self.screen = Screen::Library;
                vec![Job::Install {
                    library: self.library(),
                    target,
                    pack,
                    skip_optional,
                    installed_at: self.env.now(),
                    source_ref: self.env.source_ref(&self.library_root),
                }]
            }
            // D3: there is no key that resolves a collision.
            Key::Confirm => Vec::new(),
            _ => {
                self.screen = Screen::Library;
                Vec::new()
            }
        }
    }

    fn confirm_remove_key(&mut self, key: Key) -> Vec<Job> {
        let Screen::ConfirmRemove(plan) = &self.screen else {
            return Vec::new();
        };
        match key {
            Key::Confirm => {
                let Some(target) = self.target() else {
                    return Vec::new();
                };
                let plan = plan.clone();
                self.busy = Some("forgetting");
                self.screen = Screen::Library;
                vec![Job::Remove { target, plan }]
            }
            _ => {
                self.screen = Screen::Library;
                Vec::new()
            }
        }
    }
}

/// The keys the app understands, named by intent so the render layer owns the
/// binding and the state machine owns the meaning.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Key {
    Up,
    Down,
    NextAgent,
    ToggleScope,
    Refresh,
    Confirm,
    Remove,
    Back,
    Help,
    Quit,
}

fn describe_install(pack: &str, outcome: &InstallOutcome) -> String {
    let mut parts = vec![format!("learned {pack}")];
    if !outcome.linked.is_empty() {
        parts.push(format!("{} member(s) linked", outcome.linked.len()));
    }
    if !outcome.already_present.is_empty() {
        parts.push(format!("{} already present", outcome.already_present.len()));
    }
    // §5: a reinstall that drops members must say so.
    if !outcome.dropped.is_empty() {
        parts.push(format!("dropped {}", outcome.dropped.join(", ")));
    }
    if let Some(face) = &outcome.face {
        parts.push(format!("face: {}", face.display()));
    }
    parts.join(" · ")
}

/// One finding as a line. Mirrors §5's table wording, deliberately: the spec
/// calls these facts, and the UI must not upgrade them to verdicts.
#[must_use]
pub fn describe_finding(finding: &grimoire_core::check::Finding) -> String {
    use grimoire_core::check::Finding;
    match finding {
        Finding::RequiredMemberMissing { pack, member } => {
            format!("{pack}: required member {member} missing (broken)")
        }
        Finding::MemberMoved { pack, member, .. } => {
            format!("{pack}: {member} moved since install")
        }
        Finding::OptionalMemberAbsent { pack, member } => {
            format!("{pack}: optional member {member} absent (fine)")
        }
        Finding::OrphanedPack { pack } => format!("{pack}: installed manifest missing (orphaned)"),
        Finding::SharedMemberDisagreement { member, packs } => {
            format!("{member}: packs disagree on its hash ({})", packs.join(", "))
        }
    }
}

/// One member's preflight disposition as a line (§5's collision reporting).
#[must_use]
pub fn describe_disposition(disposition: &MemberDisposition) -> String {
    match disposition {
        MemberDisposition::Fresh => "will link".to_string(),
        MemberDisposition::AlreadyInstalled => "already installed".to_string(),
        MemberDisposition::Missing => "MISSING from the library".to_string(),
        MemberDisposition::Collision {
            at,
            points_to,
            adoptable,
        } => {
            let what = points_to.as_ref().map_or_else(
                || format!("something else at {}", at.display()),
                |p| format!("a link to {}", p.display()),
            );
            // `adoptable` is reported, not offered: §5 permits adopt/replace, and
            // v0.1 implements neither (see D3).
            let note = if *adoptable {
                "adoptable, but v0.1 does not adopt"
            } else {
                "the face is never adoptable"
            };
            format!("COLLISION — {what} ({note})")
        }
    }
}
