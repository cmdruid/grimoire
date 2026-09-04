---
doctype: plans
status: draft
schema: contractor/plan@1
tags: [plan]
---

# Extract skills library to dojo — Implementation Plan

Working name for the library repo is `dojo` (`~/Repos/dojo`, likely `github:cmdruid/dojo`).
Renaming before the GitHub repo goes public is cheap and in scope as a follow-up, not this job.

Extract from the library surface you actually want in dojo. At plan time this checkout has dirty
`PACK.md` and `README.md`, untracked `skills/gcloud-operator/`, and is 198 commits ahead of
`origin/main`. Leave `gcloud-operator` out of dojo's first commit unless it is accepted as a
real skill.

Use a snapshot copy, not `git filter-repo`. Library blame remains in grimoire after `git rm`
(`git log -- skills/journal/SKILL.md`). Dojo gets a clean identity. `git-filter-repo` is not
installed, and this history mixes the Rust app with the catalog.

## Scope

- Outcome: A standalone skills library at `~/Repos/dojo`, and this repo focused on the Grimoire
  app. `github:cmdruid/grimoire` stops being a skill source.
- Affected surface: `skills/`, root `PACK.md`, library README / `AGENTS.md`, `scripts/tests/*`
  skill-contract tests, Grimoire live-root dogfood, app README.
- Non-goals / constraints: Publishing to GitHub (optional last step). Renaming off `dojo`.
  History rewrite. Moving `.records/`, `docs/design/`, or the Cargo workspace. Making Grimoire a
  full consuming project of dojo in this job.

## Implementation

- [ ] Seed `~/Repos/dojo` from the library surface
  - Where: new repo at `/Users/cscott/Repos/dojo`
  - Copy: `skills/` (tracked skills only), `PACK.md`, `LICENSE`, `AGENTS.md` (library doctrine;
    keep the patient-zero caveat), `scripts/tests/` (the six contract tests plus `run.sh`),
    `RUBRIC.md` (skill-audit rubric, not an app rubric).
  - Do not copy: `crates/`, `Cargo.*`, `target/`, `.records/`, `docs/`, `.trackers/`,
    `.workstreams/`, `repos/`, `scripts/debt-census.py`.
  - Rewrite in dojo: `README.md` (library only; install lines below), `.gitignore`
    (`.DS_Store`, `.workstreams/`, maybe `.scratch/`), and `scripts/tests/run.sh` so paths stay
    `skills/...` relative to the dojo root with no Cargo workspace next door.
  - Install lines for the dojo README:

```sh
npx skills add cmdruid/dojo
grimoire source add dojo github:cmdruid/dojo --trust
grimoire install clankshop --source dojo
```

  - Verify:

```sh
skills/skill-builder/scripts/skills-lint.sh
skills/skill-builder/scripts/tests/run.sh
scripts/tests/run.sh
```

    All three green on dojo alone. `git init`, one initial commit. No GitHub yet.

- [ ] Retarget Grimoire live-root tests before deleting `skills/`
  - Where: `crates/grimoire-pack/tests/live_root_layout.rs` (asserts `architect` and
    `workstream` exist in the scanned root) and `crates/grimoire/tests/root_dogfood.rs`
    (clones the checkout and installs `clankshop`).
  - Change: resolve the catalog root as `GRIMOIRE_LIVE_ROOT`, else `../dojo` if that directory
    contains `PACK.md`, else skip (or fail with “set GRIMOIRE_LIVE_ROOT”). Do not default to
    the Grimoire repo root.
  - Leave alone: unit tests that already build synthetic trees (`skills/one`, `skills/demo`).
    Fixture strings like `github:cmdruid/grimoire` in identity/trust tests are URL-parsing
    fixtures; they do not need to become `dojo` unless the test documents the blessed source.
  - Verify: `GRIMOIRE_LIVE_ROOT=/Users/cscott/Repos/dojo cargo test --all` while `skills/` still
    exists here, so a red test is the retarget, not the deletion.

- [ ] Cut the catalog out of Grimoire
  - Where: this repo. Delete `skills/`, `PACK.md`, and `scripts/tests/` (the skill-contract
    runner belongs to dojo). If `scripts/` is then only `debt-census.py`, leave it or drop it
    as a follow-up — not required for the cut.
  - Rewrite `README.md`: app first, two identities:

```sh
# app (this repo)
cargo install skill-grimoire   # or whatever the real install is

# library
grimoire source add dojo github:cmdruid/dojo --trust
grimoire install clankshop --source dojo
```

    Local dogfood can use `path:/Users/cscott/Repos/dojo` until GitHub exists.
  - Rewrite `AGENTS.md`: this becomes the app front door (how to work on the Rust package
    manager). Library doctrine lives in dojo. Do not keep skill-authoring bullets here.
  - Rewrite the repo gate. The three library commands currently documented in the README
    (`skills/skill-builder/scripts/skills-lint.sh`, `skills/skill-builder/scripts/tests/run.sh`,
    `scripts/tests/run.sh`) move to dojo's README. Grimoire's gate is cargo fmt / test / clippy
    plus the retargeted live-root tests.
  - Verify:

```sh
test ! -e skills && test ! -e PACK.md
RUSTC_WRAPPER= cargo fmt --all -- --check
RUSTC_WRAPPER= cargo test --all
RUSTC_WRAPPER= cargo clippy --all --all-targets -- -D warnings
```

    Discovery over this tree must not report `architect` / `clankshop`. `GRIMOIRE_LIVE_ROOT`
    still sees them in dojo.

- [ ] Prove the two-repo install path
  - Where: a throwaway project, using the local Grimoire CLI against `~/Repos/dojo`.
  - Verify:

```sh
grimoire init
grimoire source add dojo path:/Users/cscott/Repos/dojo --trust
grimoire install journal --source dojo
grimoire install clankshop --source dojo
grimoire check
```

    Expect `.agents/skills/journal` (and pack members) to link into the dojo snapshot, not into
    `~/Repos/grimoire/skills`.

- [ ] Optional: publish `cmdruid/dojo`
  - Where: GitHub, from `/Users/cscott/Repos/dojo`.

```sh
gh repo create cmdruid/dojo --private --source /Users/cscott/Repos/dojo --remote origin --push
```

    Keep it private until the name is settled. Then flip README source lines from `path:` to
    `github:cmdruid/dojo`. Public comes after the name is settled.

## Done when

- `~/Repos/dojo` is a git repo whose installable unit is `skills/<name>/SKILL.md` plus root
  `PACK.md` (`clankshop`), and its three library gates are green.
- `~/Repos/grimoire` has no `skills/` catalog, no `PACK.md`, and the Cargo gate is green with
  live-root tests pointed at dojo.
- A throwaway project can install `clankshop` from dojo through Grimoire.
- This repo's README no longer tells people `github:cmdruid/grimoire` is the skill source.

## Follow-ups (not this job)

- Rename `dojo` → `grove` or whatever sticks, before making the GitHub repo public.
- Decide whether `gcloud-operator` is a dojo skill.
- Make Grimoire itself a Grimoire client (`grimoire.toml` in the app repo).
- Commit the dirty `PACK.md` / `README.md` in grimoire before the copy if those edits should
  land in dojo's first commit.
