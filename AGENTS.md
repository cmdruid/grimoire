# AGENTS.md — working on the Grimoire package manager

This repository is the **Grimoire** skill package manager (Rust workspace under `crates/`).
The installable skills catalog is **grove** (`~/Repos/grove`). Do not author skills into this tree.

This checkout is `dev`. `main` is a production snapshot. Do not merge `dev` into `main`. The human
map of that split is `DEVELOPMENT.md`.

## Gate

From the checkout root:

```sh
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test --all
RUSTC_WRAPPER= cargo clippy --all --all-targets -- -D warnings
bash scripts/tests/canonical-provider-parity-test.sh
```

The default `cargo test --all` does not run the live clankshop CLI dogfood. To run it:

```sh
RUSTC_WRAPPER= cargo test -p skill-grimoire --test root_dogfood -- --ignored
```

Live-root inventory tests (`crates/grimoire-pack/tests/live_root_layout.rs`) stay on the default
path. They read the catalog from `GRIMOIRE_LIVE_ROOT`, or sibling `../grove` when that directory
contains `packs/clankshop/PACK.md`. They do not treat this repository root as a skills source.

Library authoring doctrine, the lint gate, and skill-contract tests live in the sibling
grove checkout: `~/Repos/grove/AGENTS.md` and
`~/Repos/grove/skills/skill-builder/docs/DOCTRINE.md`.

This repo is a Grimoire client of that catalog. A pinned source copies locked skill trees into
`.agents/skills/`. Add the local checkout with `--link` so install symlinks the working tree:

```sh
grimoire source add grove /Users/cscott/Repos/grove --link --trust-all
grimoire install clankshop --pack --source grove
```

A filesystem path without `--link` is a Git snapshot (clean worktree, pinned commit), not
the tree you are editing.

## Workstream compaction recovery

Applies only when your context has just been compacted or summarized, and only to the current Git
top level:

- If that top level has no `WORKSTREAM.md`, this route is inert.
- If `WORKSTREAM.md` exists at that top level, STOP before further work. Invoke Workstream's helper
  with `read-current <current-top-level>`. Resume the reported local action; if it would land or
  mutate the primary or target, stop and ask.
