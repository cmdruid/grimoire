# `/backlog debrief` — sweep a finished body of work, route every byproduct

The **single end-of-work sweep**: right after a body of work finishes — when the conversation still
holds everything that happened — walk it once and route every byproduct it surfaced to its **one
durable home** in `.records/`, so nothing evaporates on the next reset. This is the moment
context is richest; a follow-up, a friction point, or a directional idea not captured now is usually
lost.

`debrief` is an **orchestrator**, not a new tracker. It fans out across the five-kind capture
taxonomy (the record schema — the installation's `.handbook/rules/RECORDS.md`) and defers item-format to the capture verbs:
`/backlog task` for `tasks.md`, `/backlog issue` for `issues.md`, `/backlog bug` for a `bugs/`
report, `/backlog note` for a `notes/` fact, `/backlog feedback` for `feedback.md`. It **writes only
backlog's five stores** — never a `.handbook/` chapter. On an **unstamped root** it refuses:
report `unstamped` and point at the clankshop onramps (the sweep presumes the stores exist).

## When to use

- **The moment a plan completes** — an implementation plan or feature brief meets its **Done when**,
  or a roadmap phase its **Definition of done**. This is the primary trigger: the work is finished
  and the context is at its richest. It is tied to the work being *done*, **not** to *landing* it
  (how/whether it merges) — run it at completion, before any transport step, not as part of one.
- A **spike** wraps up, or any **context-rich session** ends — before the context is reset or
  handed off.
- The user asks to capture/log what came up: "/backlog debrief", "capture what surfaced", "log the issues
  and feedback", "debrief this", "wrap up before I reset", "anything worth recording from this?".

**Do NOT invoke** at session start, in the middle of an active task, or for a trivial / pure-Q&A
exchange where nothing surfaced. And it is **not** the "what shipped" record — recording what shipped
is the shipping lane's (`/backlog done` per item + the stream's own done-record), not this verb's; `debrief` captures the *byproducts*
of the work, never the shipped-record.

## What it routes — the five-kind taxonomy

Every surfaced thing has **exactly one home**, and every home is a backlog store. Pick the most
actionable. The **five-kind taxonomy** (task / bug / issue / note / feedback — what counts as each,
its store, its format, and the store-dir frontmatter rules) is the record schema — canonical in
the doctrine, deployed as `.handbook/rules/RECORDS.md` — apply it as written; each home's format
authority is its capture verb.

| Surfaced thing | Home | Capture verb |
|---|---|---|
| a thing to build / an unfinished or adjacent action | `.records/trackers/tasks.md` | `/backlog task` |
| a reproducible code defect | `.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md` | `/backlog bug` |
| a project problem / concern / limitation | `.records/trackers/issues.md` | `/backlog issue` |
| a durable project fact / knowledge — including a would-be **invariant or gotcha** | `.records/trackers/notes/<slug>.md` | `/backlog note` |
| a dev-experience observation (skills / tooling / env / workflow) | `.records/trackers/feedback.md` | `/backlog feedback` |

**Would-be invariant or gotcha → a `note`.** A load-bearing invariant or a working-as-coded trap
that surfaces is captured as a `/backlog note` (a durable project fact) — `debrief` never writes
the `.handbook/` rules chapters. The note-vs-INVARIANTS classifier is the schema's: capture never
promotes; landing a proven note in `INVARIANTS.md`/`GOTCHAS.md` is improvement-loop work,
dispatched to the rules steward — not this sweep's.

**Frontmatter is mandatory on any store-dir file you create here** (`.records/trackers/bugs/`,
`.records/trackers/notes/`): start it with that type's frontmatter block — copying from the named
template gives it to you. The store-dir frontmatter is mandatory — the deployed check chain
flags a store-dir file without it. Schema: the installation's `.handbook/rules/RECORDS.md`.

## The rules that keep it honest

- **One home each.** If something could fit two buckets, file it in the most *actionable* one and
  cross-link rather than duplicating. One source of truth per fact.
- **Grounding.** Every entry must tie back to something that **actually came up** in this
  conversation — code touched, a defect observed, a decision deferred, a tool that fought you, an
  idea the user floated. Do **not** pad with pattern-matched generics ("add more tests"). Mark a
  genuine maybe `(unsure)` and say why; surfacing uncertainty beats false confidence.
- **`bugs/` is a store, not a queue.** A defect → file the **report** in `.records/trackers/bugs/` *and*
  create the actionable item (a `tasks.md` line, or an `issues.md` entry) that **links** it. The
  report is the evidence; the linked item is what gets worked. Never leave a report with nothing
  pointing at it.
- **`note` is lower-bar than an invariant.** A `note` just captures a durable fact worth remembering;
  it never promotes. A would-be invariant or gotcha lands here as a note for the improvement loop —
  don't try to reach the `.handbook/` rules chapters from the sweep.
- **Don't double-log.** Dedupe against entries already in each file — including anything you captured
  along the way during the work. `debrief` reconciles; it doesn't re-append.

## File locations

All paths project-relative. Resolve the project root + real date with `date +%Y-%m-%d` — don't guess.

- `<root>/.records/trackers/tasks.md`, `<root>/.records/trackers/issues.md`, `<root>/.records/trackers/feedback.md`
- `<root>/.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md` (from this skill's `templates/bug-report.md`)
- `<root>/.records/trackers/notes/<slug>.md` (from this skill's `templates/note.md`)

**Landing debrief captures (the root may be off-trunk):** these are **shared `.records/`
files** — cross-cutting captures that must be durable + visible *now*, independent of any stream.
`debrief` writes *new* content, so it can't ride a ref: it commits to the **root checkout's current
branch**, which must be your **integration trunk** (`main` today, `dev` later) — never hardcode
`main`. **This trunk-commit rule is for root-resident debriefs only:** invoked *inside an active
`/workstream` worktree*, write + commit on the stream's branch instead — the workstream's `ship`
lands it. The trunk-branch guard + the pathspec-atomic commit rule are in the router's *shared
discipline*; apply them here. `debrief` is a **sweep**, so it makes **one** atomic commit over
**every** file it touched (the capture verbs it fans out to only *write* — they don't self-commit
inside the sweep): `scripts/scoped-commit.sh <root> "Debrief: route follow-ups" <every file this
debrief wrote>` — list `.records/trackers/tasks.md` `.records/trackers/issues.md`
`.records/trackers/feedback.md`, any bug report, any `.records/trackers/notes/<slug>.md`. The worktree's
ignored hand-off is not a debrief target.

## Procedure

1. **Sanity check.** If the work was trivial or nothing meaningful surfaced, write nothing and reply:
   "Nothing surfaced to debrief." Don't manufacture entries.
2. **Resolve root + date.**
3. **Scan the whole completed body of work** for byproducts: unfinished TODOs, decisions deferred,
   defects noticed in passing, tooling/workflow friction, "out of scope for now" mentions,
   surprises, directional ideas, invariants learned, code touched-but-not-cleaned, files referenced
   but not opened. The scan is primarily over the **conversation** (the richest source), but ground
   it with filesystem facts: `scripts/backlog-health.sh debrief-scan <root> [<trunk-ref>]` emits
   `dirty_backlog:` (uncommitted writes to backlog's own trackers --
   `.records/trackers/tasks.md`/`issues.md`/`feedback.md`/`bugs/`/`notes/` — captured along the way but not
   yet routed) and `new_todos:` (TODO/FIXME/XXX/HACK markers this work added — candidates to route
   or resolve).
4. **Bin each into exactly one home** per the taxonomy. Sketch the routing plan first (what goes
   where) so the user can see it in the report.
5. **Route each bucket** (each capture verb invoked here only *writes* — the single commit is step 7):
   - **TASKS** → apply the `/backlog task` capture convention (group, dedupe, item = concrete
     description + why + effort `(S/M/L)` + `· added YYYY-MM-DD`). For a task-only sweep, just run
     `/backlog task`.
   - **bugs** → write the report from `templates/bug-report.md`; then add the linking actionable item
     (TASKS/ISSUES) per `/backlog bug`. `bugs/` is a store, not a queue — never leave a report
     unlinked.
   - **ISSUES** → the `/backlog issue` convention: an impact-ranked entry (what's wrong · impact ·
     suggested direction), the `I-` wire format, trunk-side ID allocation.
   - **notes** → the `/backlog note` convention: a durable project fact in
     `.records/trackers/notes/<slug>.md` (frontmatter block + `_backs:_` line), linked from the tracker
     entry it backs. A would-be **invariant or gotcha** is captured here as a note for the
     improvement loop to land in the rules chapters.
   - **FEEDBACK** → the `/backlog feedback` convention: a dated entry (`templates/feedback.md`), noting
     whether it's praise, a concern, a friction, or a directional idea, and where it might lead. This
     is the **single dev-experience channel** — a reaction to a *workflow skill you used* (`/foreman`,
     `/feature`, `/workstream`, `/delegate`, …) lands here too, not split off elsewhere.
6. **Dedupe** against existing entries in each file before writing.
7. **Commit once + report.** Make the single atomic scoped commit over every file touched (above),
   then report in chat: a compact table of what went where, with file paths. If nothing fit a bucket,
   say so for that bucket rather than padding.

## Relationship to neighboring verbs

- **`/backlog task`** owns the `tasks.md` bucket; **`/backlog bug`**, **`/backlog issue`**,
  **`/backlog note`**, and **`/backlog feedback`** own `bugs/`, `issues.md`, `notes/`, and
  `feedback.md`. `debrief` routes each share through that verb's convention; for a single-tracker add,
  use the verb directly.
- **The improvement loop** drains the captured signal into the handbook — it is what lands a
  proven `note` in the rules chapters. The shipping lane owns the shipped-record. `debrief`
  captures; the loop drains.
- **`/handoff`** saves the session as a resumable narrative doc. `debrief` is complementary: at a
  checkpoint, `handoff` writes the story, `debrief` drains the byproducts to the trackers. Do both.
- **`/workstream`** drives a stream in a worktree. Run `/backlog debrief` when a feature — or a phase of
  it — meets its Done-when, which is *before* you `/workstream ship` it, **not** as part of that verb.
  Landing the code is transport; debrief is tied to the work being finished. Where a stream runs more
  than one debrief pass around its reset, that sequencing is the workstream skill's to define (see its
  *Reset ritual*).

## Style notes

- Items are forward-looking, not past-tense recaps. Quote file paths exactly; omit a line number
  rather than guess it.
- This is a record, not a commitment — don't promise to do the items yourself afterward.
- Keep `notes/` subordinate (a note backs a tracker entry); keep `bugs/` reports linked.

## Done when

Every byproduct the work surfaced sits in exactly one durable backlog home — with a
`.records/trackers/notes/` fact linked where an entry needed depth (or a would-be invariant/gotcha
parked as a note for the improvement loop) — nothing is double-logged, no `.handbook/` chapter
was written, and the chat report names what went where.
