---
name: journal
description: "Owns a project's records layer — the `.records/` stores (adr, bugs, design, notes, plans, reports, tickets, trackers), their front-matter contract and templates, `records.sh` (query + lifecycle + the history ledger), and standup. Capture by kind — `/journal task|bug|issue|note|feedback` — plus `ticket` (escalate to the human), `debrief` (sweep finished work), `done` (close a record in place), `curate` (hygiene), `setup` (stand up records, standalone or as the workshop's delegated seam). Use when the user runs `/journal ...`, files/sweeps/curates a follow-up, closes a record, escalates to the human, or stands up the records layer."
---

# journal — the records layer

One skill: the project's **records layer**. It owns the stores under the records root
(default `.records/`), the **front-matter contract** every record carries
(doctype/status/created/updated/tags), the **templates** records are minted from, the deployed
tool **`records.sh`** (query + lifecycle; sole writer of the `history.tsv` closure ledger), and
**standup** — journal stands records up on a bare repo by itself, and the workshop's `setup`
delegates its records step here. Everything that *captures, completes, or escalates a follow-up*
lives here; it is an instrument — tool-like books-keeping a role or the human picks up, owning no
judgment beyond its own formats. **It captures; it never drains** — what a captured signal means
for the system is judged downstream.

The layer's shape (the deployed `.records/README.md` restates it in-project):

- **Stores are directories; the path is the ID.** Eight stores — `adr`, `bugs`, `design`,
  `notes`, `plans`, `reports`, `tickets`, `trackers` — each holding
  `YYYY-MM-DD-<slug>.md` records minted by `records.sh new`. No counters, no typed IDs, no
  stored index: querying is a live front-matter scan. `templates/`, `scripts/`, and
  `history.tsv` are reserved (never scanned).
- **Micro-items are tracker lines, not records.** Quick captures land as one-line items in a
  long-lived tracker record's body (`- [ ] YYYY-MM-DD — <item> [→ linked-record.md]`); the
  canonical trackers are **Backlog** (things to build), **Issues** (project
  problems/concerns), and **Feedback** (dev-experience observations), found by title and
  created lazily on first capture. Detailed material — a bug repro, a durable fact — gets its
  own dated record, linked from a tracker line when it needs scheduling.
- **Closure is in place; history is a ledger.** A finished record never moves: `records.sh
  done` sets the closing status (`done` | `dropped` | `superseded` | `consumed`) and appends
  the one ledger line to `history.tsv` — its sole writer, never hand-edited. A tracker
  *line-item* completes by flipping `[ ]` → `[x]` + a `touch`, not through the ledger.

This `SKILL.md` is a **thin router**: it dispatches and states the discipline every verb shares
**once**. Each verb's procedure lives in `verbs/<verb>.md`, **read on demand**. When a verb is
selected, **read `verbs/<verb>.md` and follow it**; do not reconstruct a procedure from memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Trigger |
|---|---|---|---|
| `/journal setup` | `verbs/setup.md` | Stand up the records layer — stores, templates, `records.sh`, ledger (standalone, or as the workshop `setup`'s delegated records step) | "stand up the records", the workshop's records seam |
| `/journal task` | `verbs/task.md` | Capture a thing to build → a **Backlog** tracker line | "put X in the backlog", "remind me to…" |
| `/journal bug` | `verbs/bug.md` | File a reproducible **defect** → a dated `bugs/` record (+ a tracker line when it needs scheduling) | "file a bug", "this is broken — repro" |
| `/journal issue` | `verbs/issue.md` | Capture a **project** problem/concern/limitation → an **Issues** tracker line | "known limitation", "architectural risk" |
| `/journal feedback` | `verbs/feedback.md` | Capture a **dev-experience** observation → a **Feedback** tracker line | "the gate is too slow", "docs heavy" |
| `/journal note` | `verbs/note.md` | Capture a durable **project fact** → a dated `notes/` record | "capture this fact", "write down how this works" |
| `/journal ticket` | `verbs/ticket.md` | **Escalate to the human** → a dated `tickets/` record (ask + context; resolution closes it) | "escalate this to me", "needs my sign-off" |
| `/journal debrief` | `verbs/debrief.md` | **Sweep** a finished body of work; route every byproduct to its home | "wrap up before I reset", "capture what surfaced" |
| `/journal done <record>` | `verbs/done.md` | **Close** a record in place — disposition + note + the ledger line (or flip a tracker line-item) | "mark that done", "close out that plan" |
| `/journal curate` | `verbs/curate.md` | Tidy the stores — dedupe, re-rank, flip stale items, `check`, propose prunes (hygiene, never draining) | "tidy the backlog", "reprioritize what's left" |

**No default lane.** `/journal` with no recognized verb is ambiguous — ask which kind the item
is (or run `/journal debrief` if the intent is "capture everything that surfaced").

## Shared discipline (every verb relies on this — stated here once)

- **Resolve the records root, then let `records.sh` own the facts.** The root is the project's
  declared `records-root:` (front-door `AGENTS.md` declaration), else `.records/`. The deployed
  tool is `<records-root>/scripts/records.sh` — invoke **it** for every date, path, and
  conformance fact (`new`/`touch`/`done`/`list`/`history`/`prune-candidates`/`check`); never guess a date, never
  hand-stamp front-matter, never write `history.tsv` by hand. Where the layer isn't stood up
  yet, the capture verbs run `setup` lazily rather than stalling.
- **Scripts compute facts; the verb prose decides.** What classifies as a bug vs. an issue, how
  to rank, whether a record is really done and under which disposition — that judgment lives in
  the verb files. The scripts (`records.sh`, `scripts/standup.sh`, `scripts/scoped-commit.sh`)
  do only deterministic mechanics; never push a decision into a script.
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

`journal` files, closes, escalates, sweeps, and keeps the stores tidy. Draining the captured
signal into doctrine, routing work, auditing code, and the development itself each belong to
another skill; the workshop's handbook owns that composition where one is deployed.

**Standalone by default, framework-aware when present.** Every verb works on any repo: the
stores live under the records root, and no verb refuses or stalls for lack of a workshop.
On a workshop host the deployed handbook's routing applies downstream; elsewhere it is simply
absent — never demand the workshop as a precondition.
