//! `grimoire` the app: the render path over `grimoire-core`'s operations.
//!
//! The binary is thin (`src/main.rs`); everything worth testing lives here.
//! Phase 3 Task 1 settled the two modules below — the worker seam and terminal
//! custody — before any screen was written, because both are failure-mode
//! questions that a screen would only obscure.

pub mod ui;
pub mod worker;
