# AGENTS.md — working on the Grimoire package manager

This repository is the **Grimoire** skill package manager (Rust workspace under `crates/`).
The installable skills catalog is **dojo** (`~/Repos/dojo`). Do not author skills into this tree.

## Gate

From the checkout root:

```sh
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test --all
RUSTC_WRAPPER= cargo clippy --all --all-targets -- -D warnings
```

Live-root dogfood (`crates/grimoire-pack/tests/live_root_layout.rs`,
`crates/grimoire/tests/root_dogfood.rs`) reads the catalog from `GRIMOIRE_LIVE_ROOT`, or sibling
`../dojo` when that directory contains `PACK.md`. It does not treat this repository root as a
skills source.

Library authoring doctrine, the lint gate, and skill-contract tests live in dojo
(`AGENTS.md`, `skills/skill-builder/docs/DOCTRINE.md`).

## Workstream compaction recovery

Applies only when your context has just been compacted or summarized, and only to the current Git
top level:

- If that top level has no `WORKSTREAM.md`, this route is inert.
- If `WORKSTREAM.md` exists at that top level, STOP before further work. Invoke Workstream's helper
  with `read-current <current-top-level>`. Resume the reported local action; if it would land or
  mutate the primary or target, stop and ask.
