//! `grimoire` the app: the render path over `grimoire-core`'s operations.
//!
//! The binary is thin (`src/main.rs`); everything worth testing lives here.
//! Phase 3 Task 1 settled [`worker`] and [`ui`] — the worker seam and terminal
//! custody — before any screen was written, because both are failure-mode
//! questions a screen would only obscure. [`env`] is the app's single point of
//! contact with the outside world, for the reasons its own docs give.

pub mod args;
pub mod env;
pub mod ui;
pub mod worker;
