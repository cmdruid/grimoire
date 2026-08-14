---
name: backlog
description: "The follow-up lifecycle over a project's records layer — capture by kind (`/backlog task|bug|issue|note|feedback` → tracker lines + dated records), `ticket` (escalate to the human), `debrief` (sweep a finished body of work; route every byproduct to its durable home), and tracker-side `curate` (groom the Backlog/Issues/Feedback trackers). Use when the user runs `/backlog ...`, files a follow-up, defect, fact, or observation, escalates to the human, sweeps finished work before a reset, or grooms the trackers. Requires a stood-up records layer — it guards rather than standing one up."
---

# backlog — the follow-up lifecycle

One skill: the loop that keeps follow-ups from evaporating — **debrief** a finished body of
work, **file** each item by kind, **curate** the trackers so they stay actionable. It runs *on*
a project's records layer as a **client** of the format: the stores, the record front-matter
contract, and the tracker-line form are defined by `journal` (the format authority — its
SKILL.md's *The record contract* section is the one citable spec; this skill cites it, never
restates it). At runtime every call goes to the **deployed** tool
`<records-root>/scripts/records.sh` — it travels with the records layer itself, so filing works
wherever the layer is stood up, with or without any skill installed beside it. **It captures;
it never drains** — what a captured signal means for the system is judged downstream, and
draining trackers into scheduled work is deliberately out of scope.

_Lineage: the name is re-minted. v1's `backlog` skill was the whole records instrument (renamed
`journal` in v2); this `backlog` is the tracker workflow only, named for the capital-B
**Backlog** tracker it manages. History docs keep the v1 meaning as dated record._

## Guard — the records layer must already exist

Resolve the records root: the project's declared `records-root:` (front-door `AGENTS.md`
declaration), else `.records/`. If `<records-root>/scripts/records.sh` is absent, **STOP in one
breath**: say the records layer isn't stood up and point at `/journal setup`. Backlog never
stands the layer up and never degrades into a second storage format.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in `verbs/<verb>.md`, **read on demand**. When a verb is
selected, **read `verbs/<verb>.md` and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/backlog task` | `verbs/task.md` | Capture a thing to build → a **Backlog** tracker line | "put X in the backlog", "remind me to…" |
| `/backlog bug` | `verbs/bug.md` | File a reproducible **defect** → a dated `bugs/` record (+ a tracker line when it needs scheduling) | "file a bug", "this is broken — repro" |
| `/backlog issue` | `verbs/issue.md` | Capture a **project** problem/concern/limitation → an **Issues** tracker line | "known limitation", "architectural risk" |
| `/backlog feedback` | `verbs/feedback.md` | Capture a **dev-experience** observation → a **Feedback** tracker line | "the gate is too slow", "docs heavy" |
| `/backlog note` | `verbs/note.md` | Capture a durable **project fact** → a dated `notes/` record | "capture this fact", "write down how this works" |
| `/backlog ticket` | `verbs/ticket.md` | **Escalate to the human** → a dated `tickets/` record (ask + context; resolution closes it) | "escalate this to me", "needs my sign-off" |
| `/backlog debrief` | `verbs/debrief.md` | **Sweep** a finished body of work; route every byproduct to its home | "wrap up before I reset", "capture what surfaced" |
| `/backlog curate` | `verbs/curate.md` | **Groom the trackers** — dedupe, sharpen, re-rank, flip stale line-items (hygiene, never draining) | "tidy the backlog", "reprioritize what's left" |

**No default lane.** `/backlog` with no recognized verb is ambiguous — ask which kind the item
is (or run the debrief if the intent is "capture everything that surfaced").

## Shared discipline (every verb relies on this — stated here once)

- **Guard first** (above), then let the deployed `records.sh` own the facts — every date, path,
  and conformance fact (`new`/`touch`/`done`/`list`/`check`); never guess a date, never
  hand-stamp front-matter, never write `history.tsv` by hand (per the contract, `records.sh
  done` is its sole writer).
- **Backlog owns its stores' templates and lazy-deploys them** (the contract's template
  convention): before minting into `bugs`, `notes`, `tickets`, or `trackers`, copy this skill's
  bundled `templates/<doctype>.md` into `<records-root>/templates/` when absent — the deployed
  copy is what `records.sh new` mints from, and it travels with the layer thereafter.
- **The three canonical trackers**, found by title and created lazily on first capture
  (`records.sh new trackers --title "<Title>"`): **Backlog** (things to build), **Issues**
  (project problems/concerns), **Feedback** (dev-experience observations). Line-items follow
  the contract's tracker-line form — one line per item under `## Items`, newest last, linking a
  dated record when detail doesn't fit the line.
- **Commit on the integration trunk, never a work branch.** A capture writes shared records, so
  it lands on the root checkout's current branch, which must be the integration trunk (never
  hardcode `main`). Guard: if `git -C <root> branch --show-current` is empty (detached HEAD) or
  a work branch (`stream/*`, `feature/*`), STOP and say so. **Exception:** capture inside an
  active workstream worktree writes + commits on the stream's branch; its ship lands it.
- **Pathspec-atomic commit (the shared root index is contended).** Stage *and* commit scoped to
  exactly the paths you wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>"
  <paths…>`. Never `git add -A`, never `commit -a`, never leave staged work in the root index
  across steps. No `Co-Authored-By` trailer.
- **Capture-commit policy.** A capture verb invoked **standalone** makes its own scoped commit,
  then runs the host's cheap doc gate if it has one. A capture verb invoked **inside a sweep**
  (`debrief`) only writes — the sweep makes the single atomic multi-file commit.

## Scope boundary + host conduct

`backlog` files, escalates, sweeps, and keeps the trackers sharp. Defining the record format
and standing the layer up belong to the format authority; closing records through the ledger is
its lifecycle surface too (the sweep and writebacks invoke it). Draining the captured signal
into doctrine, routing work, and the development itself each belong to another skill; the
workshop's handbook owns that composition where one is deployed.

**Standalone by default, framework-aware when present.** Every verb works on any repo whose
records layer is stood up — no workshop is a precondition. On a workshop host the deployed
handbook's routing applies downstream; elsewhere it is simply absent.
