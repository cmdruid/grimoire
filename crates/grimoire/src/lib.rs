//! `grimoire` the app: the render path over `grimoire-core`'s operations.
//!
//! The binary is thin (`src/main.rs`); everything worth testing lives here.
//!
//! The layering is deliberate and testable end to end without a terminal:
//!
//! - [`env`] — the app's single point of contact with the outside world, and
//!   the only constructor of a `Target`.
//! - [`job`] — what the worker runs; every job owns its inputs.
//! - [`worker`] — one thread, two channels; a panicking job is an event.
//! - [`app`] — state and transitions, pure. Jobs are *returned*, not dispatched.
//! - [`render`] — a projection of `app`, holding no decisions.
//! - [`run`] — the loop that ties them together.
//! - [`ui`] — terminal custody, including a panic hook that restores only for
//!   the thread that owns the terminal.

pub mod app;
pub mod args;
pub mod env;
pub mod job;
pub mod render;
pub mod run;
pub mod ui;
pub mod worker;
