//! The worker seam: blocking core operations, off the render thread.
//!
//! `grimoire-core` is synchronous by design (Phase 2 amended the roadmap's async
//! posture), and its long operations — `enumerate`, `check`, `install` — hash
//! member trees. Running one on the render thread freezes the UI, so they run
//! here and come back as events.
//!
//! No async runtime is involved. One thread, one job at a time, two channels.
//! The UI is modal — you install one pack at a time — so there is never more
//! than one operation in flight, and a runtime would buy nothing.
//!
//! Two properties this module exists to guarantee, both proven in
//! `tests/worker.rs`:
//!
//! - **A panicking job does not take the worker with it.** A panic becomes
//!   [`Outcome::Panicked`], an ordinary event; the worker accepts the next job.
//!   (Panic *hook* behavior is a separate problem — see [`crate::ui`].)
//! - **Shutdown is by channel close.** Dropping the job sender ends the loop, so
//!   the UI can join the worker instead of detaching it.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::mpsc::{Receiver, Sender};
use std::thread::{self, JoinHandle};

/// A job's result, or the panic that replaced it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome<D> {
    Done(D),
    /// The job panicked. The worker caught it, reported it, and stayed alive.
    Panicked(String),
}

/// Run `run` over every job that arrives, sending each outcome back.
///
/// The loop ends when the job channel closes (the UI dropped its sender) or the
/// outcome channel closes (the UI is gone) — never by panicking.
pub fn spawn<J, D, F>(jobs: Receiver<J>, out: Sender<Outcome<D>>, run: F) -> JoinHandle<()>
where
    J: Send + 'static,
    D: Send + 'static,
    F: Fn(J) -> D + Send + 'static,
{
    thread::spawn(move || {
        for job in jobs {
            let outcome = match catch_unwind(AssertUnwindSafe(|| run(job))) {
                Ok(done) => Outcome::Done(done),
                Err(payload) => Outcome::Panicked(panic_message(&payload)),
            };
            // A closed receiver means the UI is shutting down. Stop quietly:
            // sending into the void is not an error worth panicking over.
            if out.send(outcome).is_err() {
                break;
            }
        }
    })
}

/// Best-effort text from a panic payload — `panic!("literal")` yields `&str`,
/// `panic!("{formatted}")` yields `String`, and anything else is opaque.
fn panic_message(payload: &Box<dyn std::any::Any + Send>) -> String {
    payload
        .downcast_ref::<&str>()
        .map(|s| (*s).to_string())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "non-string panic payload".to_string())
}
