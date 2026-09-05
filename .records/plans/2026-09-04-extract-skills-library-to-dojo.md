---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Extract skills library to dojo — Implementation Plan

Working name for the library repo was `dojo` (`~/Repos/dojo`, likely `github:cmdruid/dojo`).
Renamed to `grove` (`~/Repos/grove`, eventually `github:cmdruid/grove`) on 2026-09-05, before GitHub publish.

Snapshot copy, not `git filter-repo`. Library blame remains in grimoire after `git rm`.
Dojo has a clean identity.

## Scope

- Outcome: A standalone skills library at `~/Repos/dojo`, and this repo focused on the Grimoire
  app. `github:cmdruid/grimoire` stops being a skill source.
- Affected surface: `skills/`, root `PACK.md`, library README / `AGENTS.md`, portable skill-contract
  tests, Grimoire live-root dogfood, app README, host skill symlinks.
- Non-goals / constraints: Publishing to GitHub. Renaming off `dojo`. History rewrite. Moving
  `.records/`, `docs/design/`, or the Cargo workspace. Making Grimoire a consuming project of dojo
  was out of this job (follow-up).

## Implementation

- [x] Seed `~/Repos/dojo` from the library surface
  - Where: `/Users/cscott/Repos/dojo` on `main` (`97b3472` initial import, 22 skills including
    `gcloud-operator` and `inspector`).
  - Copied: tracked `skills/`, `PACK.md`, `LICENSE`, library `AGENTS.md`, `RUBRIC.md`, and the
    portable contract tests (`configure-clankshop-test.sh`, `backlog-provider-contract-test.sh`,
    `project-layer-anchor-contract-test.sh`, `agent-feedback-hard-cut-test.sh`, nested chiropractor
    tests). Workstream hard-cut copied with an optional crates census (`436fcf5`).
  - Did not copy: `crates/`, `Cargo.*`, `target/`, `.records/`, `docs/`, `.trackers/`,
    `.workstreams/`, `repos/`, `scripts/debt-census.py`, or `scripts/tests/` wholesale
    (`workstream-hard-cut-contract-test.sh` scanned `crates/`; `canonical-provider-parity-test.sh`
    compared this repo's deployed providers to in-tree `skills/`; `clankshop-contract-test.sh`
    grepped `docs/boundary-audit.md`).
  - Dojo README install lines use a filesystem path (no `path:` scheme) and `--live` for a local
    source (`723d518`). GitHub publish was left off.
  - Verify: dojo `skills/skill-builder/scripts/skills-lint.sh`,
    `skills/skill-builder/scripts/tests/run.sh`, and `scripts/tests/run.sh` green.

- [x] Retarget Grimoire live-root tests before deleting `skills/`
  - Where: `crates/grimoire-pack/tests/live_root_layout.rs` and
    `crates/grimoire/tests/root_dogfood.rs`.
  - Change: catalog root is `GRIMOIRE_LIVE_ROOT`, else sibling `../dojo` when that directory
    contains `PACK.md`, else panic. This repository root is not a skills source.

- [x] Cut the catalog out of Grimoire
  - Where: commit `111b436`. Deleted `skills/`, `PACK.md`, `RUBRIC.md`, and `scripts/tests/`.
    `scripts/debt-census.py` remains. Empty leftover fixture dirs removed from the working tree.
  - Rewrote `README.md` and `AGENTS.md` app-first. Local source line:

```sh
grimoire source add dojo /Users/cscott/Repos/dojo --live --trust
grimoire install clankshop --pack --source dojo
```

  - Host skill links: `~/.agents/skills` → `/Users/cscott/Repos/dojo/skills`. Claude per-skill
    links retargeted through that directory. Dangling Claude names removed (`blueprint`,
    `calibrator`, `clankshop`, `feature`, `guardian`). Did not add Claude links for skills Claude
    never had.

- [x] Prove the two-repo install path
  - Throwaway project: `grimoire init`, then
    `grimoire source add dojo /Users/cscott/Repos/dojo --live --trust-all`, then
    `grimoire install journal --source dojo --yes` and
    `grimoire install clankshop --pack --source dojo --yes`.
  - Pack members linked to `/Users/cscott/Repos/dojo/skills/<name>`. A git snapshot of the same
    path without `--live` is a pinned commit, not the working tree.

- [ ] Optional: publish `cmdruid/grove`
  - Not this job. Keep the GitHub repo private until publish.

## Done when

- `~/Repos/dojo` is a git repo whose installable unit is `skills/<name>/SKILL.md` plus root
  `PACK.md` (`clankshop`), and its library gates are green.
- `~/Repos/grimoire` has no `skills/` catalog, no `PACK.md`, and the Cargo gate is green with
  live-root tests pointed at dojo.
- A throwaway project can install `clankshop` from dojo through Grimoire with `--live`.
- This repo's README no longer tells people `github:cmdruid/grimoire` is the skill source.

## Follow-ups (not this job)

- Rename `dojo` → `grove` before making the GitHub repo public. Done 2026-09-05 (`~/Repos/grove`).
- Publish `github:cmdruid/grove`.
- Decide whether to add Claude links for skills Claude never had.
