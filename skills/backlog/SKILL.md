---
name: backlog
description: "The records instrument — the single collection front-door for a project's `.records/` stores. Owns the trackers and their wire formats, typed counter IDs, completion (`done` + the done log), the ticket escalation layer with its optional remote mirror, curation, and the deployed record-schema projection. Capture by kind — `/backlog task|bug|issue|note|feedback` — plus `debrief` (sweep finished work), `curate` (store hygiene), `ticket`/`promote`/`close` (escalate to the human and resolve), `sync` (the mirror). Tool-like books-keeping: it captures and completes; what a captured signal means for the system is the improvement loop's judgment, not made at capture time. Use when the user runs `/backlog ...`, files/sweeps/curates a follow-up, marks work done, or escalates to the human."
---

# backlog — the records instrument

One skill: the **single collection front-door** for a project's `.records/` stores. It owns the tracker
artifacts under `.records/trackers/` (`tasks.md`, `issues.md`, `feedback.md`, `notes/`, `bugs/`),
the escalation store (`.records/tickets/`), the completion log (`.records/done/log.md`, via
`done`), their **wire formats**, the deployed **record schema** projection
(`.handbook/rules/RECORDS.md`), the end-of-work **sweep**, and store **hygiene**. Everything that
*captures, completes, or escalates a follow-up* lives here; it is an **instrument** — tool-like
books-keeping a role or the human picks up, owning no judgment beyond its own formats.

Capture is **uniform** — every byproduct lands in exactly one durable home by its *kind*, cut by
**subject**: a thing to build (`task`), a reproducible defect (`bug`), a project
problem/concern/limitation (`issue`), a durable project fact (`note`), or a dev-experience observation
(`feedback`). The judgment about what a captured item *means for the system* — whether it should
reshape a handbook chapter, whether the change is a bug-lane or feature-lane job — is made
**downstream** (the router routes; the improvement loop drains), never at capture time. `/backlog`
**captures, never drains**. Capture broadly and honestly; let the loop sift.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in its own `verbs/<verb>.md`, **read on demand** — so the
bureau adds no always-on context beyond this file. When a verb is selected, **read `verbs/<verb>.md`
and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/backlog init` | `verbs/init.md` | Stand up backlog's own `.records/` home + register its route into the front-door (idempotent, no external floor) | "set up the trackers", "stand up the backlog" |
| `/backlog bug` | `verbs/bug.md` | File a reproducible **defect** → `.records/trackers/bugs/` (linked from an actionable item) | "file a bug", "this is broken — repro" |
| `/backlog task` | `verbs/task.md` | Capture a thing to build (product/feature follow-up) → `.records/trackers/tasks.md` | "put X in the backlog", "remind me to…" |
| `/backlog issue` | `verbs/issue.md` | Capture a **project** problem/concern/limitation → `.records/trackers/issues.md` | "known limitation", "architectural risk" |
| `/backlog feedback` | `verbs/feedback.md` | Capture a **dev-experience** observation → `.records/trackers/feedback.md` | "felt great", "the gate is too slow", "docs heavy" |
| `/backlog note` | `verbs/note.md` | Capture a durable **project fact** → `.records/trackers/notes/<slug>.md` | "capture this fact", "write down how this works" |
| `/backlog debrief` | `verbs/debrief.md` | **Sweep** a finished body of work; route every byproduct to its tracker | "wrap up before I reset", "capture what surfaced" |
| `/backlog curate` | `verbs/curate.md` | Tidy the lists — dedupe, re-rank, sharpen, weed (hygiene, never draining) | "tidy the backlog", "reprioritize what's left" |
| `/backlog done <id>` | `verbs/done.md` | **Complete** an entry per the schema's completion table + append its one done-log line | "mark T-041 done", "close out that task" |
| `/backlog ticket` | `verbs/ticket.md` | **Direct ticket** — capture-plus-escalation in one motion (no origin) | "escalate this to me", "needs my sign-off, not filed" |
| `/backlog promote <id>` | `verbs/promote.md` | Graduate an entry into a ticket — `origin:` stamped, entry **paused** (trunk-side commit) | "escalate that issue", "make I-017 a ticket" |
| `/backlog close <TK-id>` | `verbs/close.md` | Resolve / wontfix / demote a ticket — writebacks + the due done-log line | "apply my answer", "wontfix that ticket" |
| `/backlog sync` | `verbs/sync.md` | Reconcile the ticket mirror — push on hash change, pull comments, drift facts | "sync the tickets", "check the mirror" |

**No default lane.** `/backlog` with no recognized verb is ambiguous — ask which tracker the item
belongs to (or run `/backlog debrief` if the intent is "capture everything that surfaced").

## The record schema (the authority chain)

The record schema — the five kinds and their classifiers, typed IDs, wire formats, the done log,
tickets, reports — is stated **once in the pack doctrine** and deployed to every installation as
`.handbook/rules/RECORDS.md`, the stamped projection `scripts/records-projection.sh` writes
(backlog is the **sole schema-facing writer**; the pack onramps route their RECORDS step through
it). Every verb defers to the deployed schema; nothing restates it. Backlog is the authority on
capture format and books-keeping; what the captured signal *means* is judged downstream.

## Shared discipline (every verb relies on this — stated here once)

- **Resolve root + real date.** Project-relative paths; resolve the root from a project dir the
  conversation references, else cwd, else ask. Get the date with `date +%Y-%m-%d` — never guess it.
- **Counter IDs are trunk-allocated.** Every entry carries a typed counter ID (`T-`/`I-`/`F-`/
  `B-`/`N-` — the schema's namespace; the installation's `.handbook/rules/RECORDS.md`). Allocate
  only on the trunk checkout, in the capture's own scoped commit: the next free number scanning
  the live store *and* the done log — an ID is never reused and is immutable once published.
  Where the trunk is unreachable (a work branch, detached HEAD), write `((pending: <slug>))` in
  the ID position (flat trackers) or leave `id:` pending (store dirs); `/backlog curate` stamps
  the real ID at landing, before anything cites it.
- **Scripts compute facts; the verb prose decides.** The verb files (and this router) carry the
  *judgment* — what classifies as a bug vs. an issue, how to rank impact, when to dedupe, whether an
  entry is really done, whether the shipped-record exists. The bundled scripts do only the
  deterministic, mechanical work: the **read-only** fact script `scripts/backlog-health.sh` (its
  `debrief-scan` subcommand — uncommitted tracker writes, newly added TODO/FIXME markers, recent
  done-records — for the sweep, emitting compact `key=value` facts + evidence) and the **mutating
  mechanical helper** `scripts/scoped-commit.sh` (the atomic pathspec-scoped commit — it mutates by
  design, but only ever the paths it is handed). **Never push a decision into a script:** a script is
  stateless and can't see session context, so a *verdict* it emits is sometimes confidently wrong
  (worse than none), while a *fact* the prose reasons over is not. Deeper document validation
  (citation resolution, budgets, conformance) belongs to the deployed check chain, never here.
- **Commit on the integration trunk, never a work branch.** A capture commit writes *new* shared
  `.records/` content, so it can't ride a feature ref — it lands on the **root checkout's current branch**,
  which must be the integration **trunk** (`main` today, `dev` later; never hardcode `main`).
  **Guard:** check `git -C <root> branch --show-current`; if it is empty (detached HEAD) or a work
  branch (`stream/*`, `feature/*`), STOP and tell the user to switch the root to its trunk (or run
  from a trunk checkout) — landing captures on a feature branch is the W3 failure. (**Exception:**
  `debrief` invoked *inside an active `/workstream` worktree* writes + commits on the stream's branch;
  the workstream's `ship` lands it — see `verbs/debrief.md`.)
- **Pathspec-atomic commit (the shared root index is contended).** The root index is shared with
  concurrent worktree streams, and `git commit` records the **entire** index — so a bare commit
  sweeps a sibling's staged files. **Always** stage *and* commit scoped to exactly the paths you
  wrote, in one step, via `scripts/scoped-commit.sh <root> "<msg>" <paths…>` (it wraps
  `git -C <root> add -- <paths> && git -C <root> commit -m "<msg>" -- <paths>`). Never `git add -A`,
  never `commit -a`, never leave staged work in the root index across steps. Commits carry **no**
  `Co-Authored-By` trailer.
- **Capture-commit policy (unified across the capture verbs).** A capture verb invoked **standalone**
  (`/backlog task|bug|issue|feedback|note`) makes its **own** doc-only scoped commit (via
  `scripts/scoped-commit.sh`), then runs the host's cheap doc gate if it has one — so a single capture
  lands on its own rather than waiting for an unrelated commit. A capture verb invoked **inside a
  sweep** (`/backlog debrief`) only **writes** — the sweep makes the single atomic multi-file commit
  over every file it touched. `/backlog curate` follows the same rule (standalone self-commits; inside a
  larger sweep it is write-only). Each verb file states which path applies.

## Scope boundary + unstamped conduct

`/backlog` is the **records instrument** — it files, completes, escalates, sweeps, and keeps the
stores tidy, and owns their formats and the schema projection. It **captures; it never drains.**
Draining the captured signal into the handbook, routing the dev system, auditing code, and the
development itself each belong to another pack member — the pack's doctrine and runbook own that
composition.

**On an unstamped root** (no installation block), verb by verb: the **five capture verbs** call
`init` lazily (it creates the trackers skeleton and creates-or-adopts the installation block —
exactly its pre-stamp write license, touching no `.handbook/` chapter); **every other verb** —
`ticket`, `promote`, `sync`, `close`, `done`, `curate`, `debrief` — **refuses**: emit `unstamped`
and point at the clankshop onramps (`setup` / `migrate`).

## Edges

Backlog's **typed edges** — its place in a workflow declared as artifact/capability *types*, never as
sibling names (the typed-edge tenet; `docs/design/2026-07-18-skill-self-init-model.md` §2). A composer
(`/foreman`/runbook) **derives** cross-skill seams by matching these types against other skills' edges;
backlog names no successor of its own. The delimited block is machine-findable and idempotently
rewritten by `init`'s registration.

<!-- edges:backlog -->
- produces: tracker-entry — task/bug/issue/note/feedback rows under `.records/`
- handoff: — (none; a filed item sits until a composer drains it — backlog hands off no baton)
- consumes: — (none; capture is a front-door — inputs come from the human/the work, not another skill)
<!-- /edges:backlog -->

`produces: tracker-entry` is a **data source**: something (a drainer/curator) *may* pick the entry up,
but backlog does not itself hand control onward — hence `handoff: —`. That is the deliberate distinction
between a weak `produces` edge and a strong `handoff` edge (model §2.1).

## Companion skills (separate, not absorbed)

`backlog`'s verbs defer to companion skills where the host has them (its system-relevant signal is
drained into the handbook downstream). The composition and the seams between them live in the
pack's doctrine and runbook and the deployed **stewardship maps** (`.handbook/README.md` /
`.records/README.md`); this file does **not** restate each companion's verbs — that list rots.
Where a companion is absent, the by-hand fallback is the deployed `.handbook/rules/ROUTING.md`
walk.
