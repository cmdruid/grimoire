# ② repo restructure — design brief (doubles as the plan)

**Status:** approved (2026-08-08). Sub-project ② of the grimoire repurpose
(`docs/design/2026-08-07-grimoire-repurpose-design.md`, §2 topology + §6 risks). Small-feature
tier: this brief is also the implementation plan — no separate plan doc.

## Problem

① shipped `crates/grimoire-pack` as an orphan crate: no workspace root, so cargo only runs from
the crate directory, and the crate carries its own `Cargo.lock`, `.gitignore`, and `target/`.
Meanwhile the repo's git state has drifted from the umbrella's approved topology:

- `repos/skill-rs` is a **committed submodule** (`.gitmodules`, pinned at `d420ca2`), but the
  umbrella specifies a *gitignored reading reference* — the real dependency comes from crates.io,
  pinned. The submodule implies a build dependency that doesn't exist and weighs down clones.
- The root `.gitignore` is an untracked 1-line personal file (`TODO.md`); nothing ignores
  `/target` or `/repos/` at root.
- The retired `packs/` shelf survives as an empty untracked directory.
- The crates.io name check the umbrella deferred to ② had not been run.

## Goal

The repo matches umbrella §2: a Cargo workspace over `crates/`, `repos/` ignored, git state
intentional, and the publishing-name question settled with a recorded decision.

## Name check — result (2026-08-08) and decision

- **`grimoire` is TAKEN** on crates.io: jshrake's GLSL live-coding tool, last release 0.2.1
  (2019-03-22), not yanked, ~5.2k downloads. crates.io has no reclaim process short of a
  voluntary owner transfer.
- **Free:** `grimoire-pack`, `grimoire-core`, `grimoire-tui`, `grimoire-cli`, `grimoire-app`
  (all 404 in the sparse index).

**Decision:** the binary stays `grimoire` (umbrella §6: binary name unaffected — set via
`[[bin]] name = "grimoire"`). Library crates publish under their own names (`grimoire-pack`,
`grimoire-core` — both free). The app crate publishes as **`skill-grimoire`** (owner's call at
this design's review gate, 2026-08-08; verified free) — the crate directory stays
`crates/grimoire` per umbrella §2. **No placeholder publishes to reserve names** —
squatting-adjacent, creates maintenance surface for a draft format, and the personal-now pace
accepts the small race risk. (Optional long shot, user's call: ask jshrake about a transfer of
the dormant name.)

## Decisions (with alternatives rejected)

1. **Virtual workspace root.** Root `Cargo.toml` = virtual manifest: `[workspace]`,
   `members = ["crates/*"]`, explicit `resolver = "2"` (virtual manifests default to resolver 1
   regardless of member edition — must be explicit). The glob picks up ③'s `grimoire-core` and
   `grimoire` crates when they appear. *Rejected:* stub crates for the two future members now —
   empty crates are noise and force naming decisions ③ owns (YAGNI).
2. **One lock, one target.** `Cargo.lock` moves to root (committed — the workspace will contain
   a binary); the crate-local `Cargo.lock`, `.gitignore`, and stale `target/` are removed. Root
   `.gitignore` ignores `/target`.
3. **De-submodule `repos/skill-rs`.** `git rm --cached repos/skill-rs` + remove `.gitmodules`
   (its only entry); `/repos/` joins the root `.gitignore`; the on-disk clone stays as the
   reading reference. *Rejected:* keeping the submodule — the umbrella already settled this
   ("gitignored reading reference; the dep comes from crates.io, pinned"), and a submodule
   invites `--recursive` clones of a repo the build never reads.
4. **Commit the root `.gitignore`** with `/target`, `/repos/`, and the existing `TODO.md` line
   (the user's scratch file; machine-local ignores like `.scratch/` stay in `.git/info/exclude`
   where they already live).
5. **Residue:** `rmdir` the empty `packs/` shelf and the empty root `scripts/` dir (both
   untracked, invisible to git — pure disk residue).
6. **README:** add a short repo-layout section covering `crates/` + the workspace, per umbrella
   §2 — a few lines, not a rewrite. The umbrella doc itself is not edited; this record carries
   the ②-deferred name-check outcome.

## Tasks

- [ ] **1. Workspace root.** Write root `Cargo.toml` (virtual manifest per decision 1). Delete
  `crates/grimoire-pack/.gitignore` and `crates/grimoire-pack/target/`. `git rm`
  `crates/grimoire-pack/Cargo.lock`; run `cargo test` from root (generates root `Cargo.lock`;
  expect 36 green) and `cargo clippy --all-targets -- -D warnings`; commit root `Cargo.toml` +
  `Cargo.lock`.
- [ ] **2. Git hygiene.** `git rm --cached repos/skill-rs`; `git rm .gitmodules`; write and
  `git add` the root `.gitignore` (`/target`, `/repos/`, `TODO.md`); verify `git submodule
  status` is empty and `repos/skill-rs/` still on disk; `rmdir packs/ scripts/`; commit.
- [ ] **3. README layout section.** Short `crates/` + workspace + `repos/` note in `README.md`,
  consistent with umbrella §2; commit.

## Verification (done-when)

- `cargo test` and `cargo clippy --all-targets -- -D warnings` green **from the repo root**
  (36 tests, no warnings).
- `git submodule status` empty; `git ls-files repos .gitmodules` empty; `repos/skill-rs/`
  present on disk; `git status` clean after the commits.
- `skills/skill-builder/scripts/skills-lint.sh` unchanged at `fails=0` (no `skills/` surface
  touched).
- A fresh `git clone` (thought experiment, no `--recursive` needed) gets a repo where
  `cargo test` works at root with only the crates.io-pinned deps.
