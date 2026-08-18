//! `grimoire` — the TUI. Skeleton only: Phase 3 Task 3 fleshes this out with
//! `AppEnv` and the flag surface (`--version`, `--library`, `--project`), Task 4
//! with app state, Task 5 with the library screen.
//!
//! The event-loop shape it will use is settled by `examples/spike.rs`.

fn main() {
    println!(
        "grimoire {} — TUI not wired yet (Phase 3, Task 3).\n\
         The event-loop spike is runnable: cargo run -p skill-grimoire --example spike",
        env!("CARGO_PKG_VERSION")
    );
}
