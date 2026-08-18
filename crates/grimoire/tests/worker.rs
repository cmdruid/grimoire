//! The worker seam's two guarantees, proven rather than commented.

use std::sync::mpsc;
use std::time::{Duration, Instant};

use skill_grimoire::worker::{self, Outcome};

/// Jobs a test can ask for. `Panic` is the interesting one.
enum Job {
    Double(u32),
    Panic(&'static str),
}

fn run(job: Job) -> u32 {
    match job {
        Job::Double(n) => n * 2,
        Job::Panic(msg) => panic!("{msg}"),
    }
}

/// The guarantee: a panicking job is reported as an event and the worker keeps
/// accepting work. Break `catch_unwind` in `worker::spawn` and this fails twice
/// over — no `Panicked` outcome arrives, and the follow-up job never runs
/// because the thread is dead.
#[test]
fn a_panicking_job_is_reported_and_the_worker_survives() {
    // Silence the default hook's stderr dump for the deliberate panic below;
    // this test binary is single-test, so the global hook is not contended.
    let previous = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));

    let (job_tx, job_rx) = mpsc::channel();
    let (out_tx, out_rx) = mpsc::channel();
    let worker = worker::spawn(job_rx, out_tx, run);

    job_tx.send(Job::Panic("deliberate")).unwrap();
    let first = out_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert_eq!(
        first,
        Outcome::Panicked("deliberate".to_string()),
        "a panicking job must arrive as an event, carrying its message"
    );

    // The load-bearing half: the worker is still there.
    job_tx.send(Job::Double(21)).unwrap();
    let second = out_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert_eq!(
        second,
        Outcome::Done(42),
        "the worker must accept the next job after a panic"
    );

    std::panic::set_hook(previous);
    drop(job_tx);
    worker.join().expect("worker thread ended cleanly");
}

/// Shutdown is by channel close, and it is prompt: the UI drops its sender and
/// joins. A worker that only exited on a sentinel message would hang here.
#[test]
fn dropping_the_job_sender_ends_the_worker() {
    let (job_tx, job_rx) = mpsc::channel::<Job>();
    let (out_tx, _out_rx) = mpsc::channel();
    let worker = worker::spawn(job_rx, out_tx, run);

    let started = Instant::now();
    drop(job_tx);
    worker.join().expect("worker thread ended cleanly");
    assert!(
        started.elapsed() < Duration::from_secs(5),
        "join should be immediate once the job channel closes"
    );
}

/// The mirror case: the UI is gone but a job is in flight. The worker must stop
/// quietly rather than panic on a send to a closed channel — otherwise every
/// quit-during-work would end in a thread panic on the way out.
#[test]
fn a_closed_outcome_channel_stops_the_worker_quietly() {
    let (job_tx, job_rx) = mpsc::channel();
    let (out_tx, out_rx) = mpsc::channel();
    let worker = worker::spawn(job_rx, out_tx, run);

    drop(out_rx);
    job_tx.send(Job::Double(1)).unwrap();
    job_tx.send(Job::Double(2)).unwrap();

    worker.join().expect("worker exits without panicking");
}
