//! What the worker runs, and what comes back.
//!
//! Every job owns its inputs. `grimoire-core`'s operations borrow a `Library`
//! and a `Target`, but a job crosses a thread boundary, so it carries clones —
//! which is why Phase 2 made those types `Clone` and rendered
//! `pack::Issue` down to `String` before it reached the app.
//!
//! Note what the jobs do **not** contain: a clock or an environment read. The
//! two facts core refuses to invent are resolved on the main thread by
//! [`AppEnv`](crate::env::AppEnv) and travel *into* the job, so the worker stays
//! as homeless as core is.

use std::path::PathBuf;

use grimoire_core::check::CheckReport;
use grimoire_core::install::{self, InstallOutcome, InstallPlan, InstallRequest};
use grimoire_core::inventory::{self, Inventory};
use grimoire_core::library::{Library, LibraryView};
use grimoire_core::remove::{self, RemovePlan};
use grimoire_core::target::Target;
use grimoire_core::time::Timestamp;
use grimoire_core::{check, CoreError};

pub enum Job {
    /// Walk the library. The expensive one: two tree walks, and `resolve_pack`
    /// re-runs it internally, so the app enumerates once and holds the result.
    Enumerate(Library),
    /// What is installed at this target, plus drift — the launch status.
    Survey {
        library: Library,
        target: Target,
    },
    Preflight {
        library: Library,
        target: Target,
        pack: String,
    },
    Install {
        library: Library,
        target: Target,
        pack: String,
        skip_optional: Vec<String>,
        installed_at: Timestamp,
        source_ref: Option<String>,
    },
    InstallAtom {
        library: Library,
        target: Target,
        skill: String,
    },
    PlanRemove {
        target: Target,
        pack: String,
    },
    Remove {
        target: Target,
        plan: Box<RemovePlan>,
    },
}

pub enum Done {
    Enumerated(Box<LibraryView>),
    Surveyed {
        inventory: Box<Inventory>,
        report: Box<CheckReport>,
    },
    Preflighted(Box<InstallPlan>),
    Installed {
        pack: String,
        outcome: Box<InstallOutcome>,
    },
    Removed {
        pack: String,
    },
    RemovePlanned(Box<RemovePlan>),
    /// Any `CoreError`, rendered. Failure is a value here — the render loop must
    /// never learn about a problem by dying.
    Failed(String),
}

/// Run one job. Pure dispatch: every arm is a `grimoire-core` call.
#[must_use]
pub fn run(job: Job) -> Done {
    match job {
        Job::Enumerate(library) => match library.enumerate() {
            Ok(view) => Done::Enumerated(Box::new(view)),
            Err(e) => failed(&e),
        },
        Job::Survey { library, target } => {
            let inventory = match inventory::inventory(&target) {
                Ok(i) => i,
                Err(e) => return failed(&e),
            };
            match check::check(&library, &target) {
                Ok(report) => Done::Surveyed {
                    inventory: Box::new(inventory),
                    report: Box::new(report),
                },
                Err(e) => failed(&e),
            }
        }
        Job::Preflight {
            library,
            target,
            pack,
        } => match install::preflight(&library, &pack, &target) {
            Ok(plan) => Done::Preflighted(Box::new(plan)),
            Err(e) => failed(&e),
        },
        Job::Install {
            library,
            target,
            pack,
            skip_optional,
            installed_at,
            source_ref,
        } => {
            let request = InstallRequest {
                library: &library,
                pack: &pack,
                target: &target,
                installed_at,
                source_ref,
                skip_optional,
            };
            match install::install(request) {
                Ok(outcome) => Done::Installed {
                    pack,
                    outcome: Box::new(outcome),
                },
                Err(e) => failed(&e),
            }
        }
        Job::InstallAtom {
            library,
            target,
            skill,
        } => match install::install_atom(&library, &skill, &target) {
            Ok(outcome) => Done::Installed {
                pack: skill,
                outcome: Box::new(outcome),
            },
            Err(e) => failed(&e),
        },
        Job::PlanRemove { target, pack } => match remove::plan_remove(&target, &pack) {
            Ok(plan) => Done::RemovePlanned(Box::new(plan)),
            Err(e) => failed(&e),
        },
        Job::Remove { target, plan } => match remove::remove(&target, &plan) {
            Ok(()) => Done::Removed { pack: plan.pack },
            Err(e) => failed(&e),
        },
    }
}

/// One place to render a `CoreError`, so every failure path reads the same.
fn failed(e: &CoreError) -> Done {
    Done::Failed(e.to_string())
}

/// The library path an install should record as its source, and what a job
/// needs to name it. Kept here so `app` never touches `PathBuf` semantics.
#[must_use]
pub fn library_label(root: &std::path::Path) -> String {
    root.file_name()
        .map_or_else(|| root.display().to_string(), |n| n.to_string_lossy().into_owned())
}

/// Where a project-scope install would land, for display before one happens.
#[must_use]
pub fn project_label(root: Option<&PathBuf>) -> String {
    root.map_or_else(
        || "(no project opened)".to_string(),
        |p| p.display().to_string(),
    )
}
