---
name: backlog
description: "The capture bureau — the single collection front-door for a project's `.records/` trackers. Owns the trackers, their formats, and the capture schema (`docs/TAXONOMY.md`). Self-initializing: `/backlog init` stands up its own `.records/` home and registers its route into the project front-door with no external setup step. Five capture verbs take one follow-up by subject/kind — `/backlog task` (a thing to build), `/backlog bug` (a reproducible defect), `/backlog issue` (a project problem/concern/limitation), `/backlog note` (a durable project fact), `/backlog feedback` (a dev-experience observation) — plus `/backlog debrief` (sweep a finished body of work to every tracker) and `/backlog curate` (keep the lists tidy: dedupe/rank/sharpen/weed). Captures uniformly; never drains. Use when the user runs `/backlog ...`, or asks to set up the trackers, file/capture/sweep/curate a follow-up."
---

# backlog — the capture bureau

One skill: the **single collection front-door** for a project's `.records/` stores. It owns the tracker
artifacts under `.records/trackers/` (`tasks.md`, `issues.md`, `feedback.md`, `notes/`, `bugs/`),
the completion log (`.records/done/log.md`, via `done`), their **formats**, the capture
**schema** (`docs/TAXONOMY.md`), the end-of-work **sweep**, and tracker **hygiene**. Everything that
*captures a follow-up* lives here; standing up, routing, and tuning the dev system is a separate
skill, `/foreman`.

Capture is **uniform** — every byproduct lands in exactly one durable home by its *kind*, cut by
**subject**: a thing to build (`task`), a reproducible defect (`bug`), a project
problem/concern/limitation (`issue`), a durable project fact (`note`), or a dev-experience observation
(`feedback`). The judgment about what a captured item *means for the system* — whether it should
reshape doctrine, whether the change is a bug-lane or feature-lane job — is made **downstream by
`/foreman`**, not at capture time. `/backlog` **captures, never drains**; `/foreman` drains. Capture
broadly and honestly; let `/foreman` sift.

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
| `/backlog sync` | *(lands in Task 2.3 of the rollout plan)* | Mirror open tickets to the remote issue system | "sync the tickets" |

**No default lane.** `/backlog` with no recognized verb is ambiguous — ask which tracker the item
belongs to (or run `/backlog debrief` if the intent is "capture everything that surfaced").

## The capture schema (backlog owns it)

The **five-kind taxonomy** — what counts as a task vs. bug vs. issue vs. note vs. feedback, each
tracker's format, plus the store-dir frontmatter rules — is canonical here in
`docs/TAXONOMY.md`. Every verb defers to it, and other skills reference it rather than restating it.
`/backlog` is the authority on capture format; `/foreman` is the authority on what the captured signal
*means for the system* (and it, not `/backlog`, drains it).

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
  (worse than none), while a *fact* the prose reasons over is not. `backlog-health.sh` **complements** the
  host doc-linter (which owns link resolution, indexing, frontmatter); it never re-implements it.
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
  `scripts/scoped-commit.sh`), then runs the host's doc-linter (or its gate) — so a single capture
  lands on its own rather than waiting for an unrelated commit. A capture verb invoked **inside a
  sweep** (`/backlog debrief`) only **writes** — the sweep makes the single atomic multi-file commit
  over every file it touched. `/backlog curate` follows the same rule (standalone self-commits; inside a
  `/foreman calibrate` sweep it is write-only). Each verb file states which path applies.

## Scope boundary

`/backlog` is the **capture bureau** — it files, sweeps, and keeps the trackers tidy, and owns their
formats and schema. It **captures; it never drains.** Draining the captured signal into doctrine,
standing up and routing the dev system, auditing code, and doing the development itself each belong to
another skill — *which* owns *what* is the runbook's seam map (`packs/clankshop.md`) and the deployed
**ownership index**, not this file.

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
drained into doctrine downstream). The composition and the seams between them live in
`packs/clankshop.md` and the deployed **ownership index** (`.agents/README.md` / `.records/README.md`);
this file does **not** restate each companion's verbs — that list rots. Where a companion is absent,
the by-hand fallback is the deployed `.agents/foreman/docs/`.
