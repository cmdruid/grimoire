---
name: backlog
description: "The follow-up lifecycle over a project's records layer — file (`/backlog task|issue|feedback` → tracker lines), `promote` (Issues / Feedback → Backlog), `debrief` (sweep a finished body of work onto the three trackers), and `curate` (groom the trackers). Use when the user runs `/backlog ...`, files a follow-up or observation, sweeps finished work before a reset, grooms the trackers, or promotes Issues/Feedback into things to build."
---

# backlog — the follow-up lifecycle

One skill: the loop that keeps follow-ups from evaporating — **file** each item onto the
three trackers, **debrief** a finished body of work, **promote** Issues and Feedback into
things to build, **curate** so the trackers stay actionable. It writes under the
agent-records home and carries its own contract. Missing `records.sh` is not an error;
journal standup is never a precondition. When the tool is present it is used
opportunistically.

_Lineage: the name is re-minted. v1's `backlog` skill was the whole records instrument (renamed
`journal` in v2); this `backlog` is the tracker workflow only, named for the capital-B
**Backlog** tracker it manages. History docs keep the v1 meaning as dated record._

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in `verbs/<verb>.md`, **read on demand**. When a verb is
selected, **read `verbs/<verb>.md` and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/backlog task` | `verbs/task.md` | Capture a thing to build → a **Backlog** tracker line | "put X in the backlog", "remind me to…" |
| `/backlog issue` | `verbs/issue.md` | Capture a **project** problem/concern/limitation → an **Issues** tracker line | "known limitation", "architectural risk" |
| `/backlog feedback` | `verbs/feedback.md` | Capture a **dev-experience** observation → a **Feedback** tracker line | "the gate is too slow", "docs heavy" |
| `/backlog promote` | `verbs/promote.md` | Judgment drain: Issues / Feedback → Backlog tasks | "promote that issue", "drain Issues into the backlog" |
| `/backlog debrief` | `verbs/debrief.md` | **Sweep** a finished body of work; route every byproduct onto the three trackers | "wrap up before I reset", "capture what surfaced" |
| `/backlog curate` | `verbs/curate.md` | **Groom the trackers** — dedupe, sharpen, re-rank, flip stale line-items (hygiene, never draining) | "tidy the backlog", "reprioritize what's left" |

**bug and ticket are not verbs here — not this skill.** A fileable repro is a
Backlog line `file repro: <symptom>` until the host's bug-filing lane writes the
record. An ask that must survive a reset is an Issue line
`needs human: <the ask, one sentence>` — file it with `/backlog issue`.

**No default lane.** `/backlog` with no recognized verb is ambiguous — ask which kind the item
is (or run the debrief if the intent is "capture everything that surfaced").

## Shared discipline (every verb relies on this — stated here once)

- **Resolve both homes, then mint.** Agent-records home: first line-start `agent-records:`
  or `records-root:` in `AGENTS.md`, then `CLAUDE.md`; else `.records`. Agent-templates
  home: first `agent-templates:` in those files; else `<agent-records>/templates`. Pass
  both into every `scripts/record-mint.sh` call. The script does not scan the front door.
- **In-package contract.** Front-matter keys: `doctype`, `status`, `created`, `updated`,
  `tags`. Live statuses: `open`, `current`. Closed: `done`, `dropped`, `superseded`,
  `consumed`. Dated slug `YYYY-MM-DD-<slug>.md`. Record-link form: `→ <dir>/<file>.md`.
  Tracker-line form under `## Items`, newest last (same optional ` → <dir>/<file>.md`
  before the completion date). Do not send the agent to another skill for those bytes.
- **`record-mint.sh` is the one minter.** Always call it (from this skill's own `scripts/`).
  It uses deployed `records.sh` when that file is executable (`new --template <resolved>`);
  otherwise it writes the contract shape (file-mode). Never write `history.tsv` by hand.
  Never write the flat `<agent-records>/templates/<doctype>.md`. File-mode close rewrites
  `status:` / `updated:` only. Minting doctype `tickets` or `bugs` from this
  package is a hard error.
- **List without the tool.** When `records.sh` is missing, scan
  `<agent-records>/<doctype>/*.md` and honor live vs closing `status:`. Find a tracker
  by its H1 title among live `trackers/` records.
- **The three canonical trackers**, found by title and created lazily on first capture
  (`record-mint.sh mint <agent-records> <agent-templates> trackers "<Title>"`): **Backlog**
  (things to build), **Issues** (project problems/concerns), **Feedback** (dev-experience
  observations). **Incumbent-schema guard:** if a tracker's existing items follow a legacy
  per-item shape the migration never normalized, don't silently mix a second schema into
  the file — capture in the incumbent shape when one clearly governs, and flag the drift
  as a `curate` item so normalization happens as one deliberate pass.
- **Resolve the commit tree, then commit there.** `<root>` is `git rev-parse --show-toplevel`
  of the checkout that holds the records you wrote — never a different clone, and never the
  repo's root checkout from inside a stream worktree (that lands the commit on the trunk
  through the shared index). `<branch>` is `git -C <root> branch --show-current`. Then, in
  order: empty `<branch>` (detached HEAD) → STOP. `<root>/WORKSTREAM.md` exists and its
  Coordinates `branch:` equals `<branch>` → this tree is a worktree stream; commit here. A
  `<root>/.workstreams/*/WORKSTREAM.md` records `isolation: in-place` and Coordinates
  `branch:` equals `<branch>` → this tree is an in-place stream holding the root; commit
  here. `<branch>` matches `stream/*` or `feature/*` → STOP (a work branch this session
  does not hold). Otherwise commit here (the current trunk — never hardcode `main`).
- **Pathspec-atomic commit (the shared root index is contended).** Stage *and* commit scoped to
  exactly the paths you wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>"
  <paths…>`. Never `git add -A`, never `commit -a`, never leave staged work in the root index
  across steps. No `Co-Authored-By` trailer.
- **Capture-commit policy.** A capture verb invoked **standalone** makes its own scoped commit,
  then runs the host's cheap doc gate if it has one. A capture verb invoked **inside a sweep**
  (`debrief`) only writes — the sweep makes the single atomic multi-file commit.

## Project templates

- `trackers.md`

## Edges

<!-- edges:backlog -->
- produces: record — tracker records and tracker lines
- handoff: record — promote drains Issues/Feedback onto Backlog
- consumes: record — debrief, curate, and promote read existing
  tracker lines
<!-- /edges:backlog -->

## Scope boundary + host conduct

`backlog` files, sweeps, grooms, and promotes among Backlog / Issues / Feedback. The format
authority owns the contract definition and the tool layer; this skill writes without waiting
for that tool. Performing the work belongs elsewhere; the workshop's doctrine owns that
composition where one is deployed.

**Standalone by default, framework-aware when present.** Every verb works on any repo —
no workshop and no journal standup is a precondition. On a workshop host the deployed
doctrine's routing applies downstream; elsewhere it is simply absent.

## Done when

- **bug or ticket:** refused; pointed at a leftover tracker line. Did not mint
  a bugs or tickets record.
- **No recognized verb:** asked which kind the item is (or whether the intent is a debrief);
  did not file.
- **A verb ran:** that verb file's Done when.
