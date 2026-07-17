# `/backlog debrief` — sweep a finished body of work, route every byproduct

The **single end-of-work sweep**: right after a body of work finishes — when the conversation still
holds everything that happened — walk it once and route every byproduct it surfaced to its **one
durable home**, so nothing evaporates on the next reset. This is the moment context is richest; a
follow-up, a friction point, or a directional idea not captured now is usually lost.

`debrief` is an **orchestrator**, not a new tracker. It fans out across the canonical capture
taxonomy (`.agents/dev/docs/DEVELOPMENT.md` → *Capture follow-ups*) and defers item-format to the capture
verbs: `/backlog backlog` for the `BACKLOG.md` bucket, `/backlog issue` for `ISSUES.md`, `/backlog feedback` for
`FEEDBACK.md`, `templates/bug-report.md` for a report.

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
exchange where nothing surfaced. And it is **not** the "what shipped" record — that is the
`.agents/dev/done/` task record, owned by the `/workstream` land step / `/foreman`. `debrief` captures the
*byproducts* of the work, then *verifies* the shipped-record exists (step 7).

## What it routes — the one-home taxonomy

Every surfaced thing has **exactly one home**. Pick the most actionable. The **four-tracker
taxonomy** (backlog / bugs / issues / feedback, each with its drain, plus the notes-spillover rule)
is canonical in `.agents/dev/docs/DEVELOPMENT.md` → *Capture follow-ups* — apply it as written; each home's
format authority is its capture verb (`/backlog backlog | bug | issue | feedback`). Two homes are
**debrief-specific** and not in that table:

| Surfaced thing | Home | Format authority |
|---|---|---|
| strong, concrete feedback about a **workflow skill itself** ("`/feature plan` was ambiguous", "the conflict forecast saved me") | the **skills' own `FEEDBACK.md`** (at their install root, tagged by skill) — **not** `.agents/dev/FEEDBACK.md` | strong + actionable only ("would this change the skill?") |
| a **load-bearing invariant** discovered (high bar) | `.agents/dev/MEMORY.md` | one line; only if it's truly load-bearing |

**Frontmatter is mandatory on any store-dir file you create here** (`.agents/dev/bugs/`, `.agents/dev/notes/`,
`.agents/dev/reports/`): start it with that type's frontmatter block — copying from the named template gives
it to you. The doc-linter gate rejects a store-dir file without it. Schema: `.agents/dev/docs/TAXONOMY.md`.

## The rules that keep it honest

- **One home each.** If something could fit two buckets, file it in the most *actionable* one and
  cross-link rather than duplicating. One source of truth per fact.
- **Grounding.** Every entry must tie back to something that **actually came up** in this
  conversation — code touched, a defect observed, a decision deferred, a tool that fought you, an
  idea the user floated. Do **not** pad with pattern-matched generics ("add more tests"). Mark a
  genuine maybe `(unsure)` and say why; surfacing uncertainty beats false confidence.
- **`bugs/` is a store, not a queue.** A defect → file the **report** in `.agents/dev/bugs/` *and* create
  the actionable item (a `BACKLOG.md` line, or an `ISSUES.md` entry) that **links** it. The report
  is the evidence; the linked item is what gets worked. Never leave a report with nothing pointing at
  it. A durable *gotcha* also belongs in `.agents/dev/docs/GOTCHAS.md`.
- **`MEMORY.md` has a high bar.** Only a sacred invariant the code doesn't already make obvious earns
  a line there. If unsure, it doesn't go — route it elsewhere (a gotcha → `GOTCHAS.md`, a fact's
  detail → a `notes/` file linked from wherever it's referenced).
- **Don't double-log.** Dedupe against entries already in each file — including anything you captured
  along the way during the work. `debrief` reconciles; it doesn't re-append.

## File locations

All paths project-relative. Resolve the project root + real date with `date +%Y-%m-%d` — don't guess.

- `<root>/dev/BACKLOG.md`, `<root>/dev/ISSUES.md`, `<root>/dev/FEEDBACK.md`, `<root>/dev/MEMORY.md`
- `<root>/dev/bugs/<YYYY-MM-DD>-<slug>.md` (from `.agents/dev/templates/bug-report.md`)
- `<root>/dev/notes/<slug>.md` (from `.agents/dev/templates/note.md`)

**Landing debrief captures (the root may be off-trunk):** these are **shared `.agents/dev/` files** —
cross-cutting captures that must be durable + visible *now*, independent of any stream. `debrief`
writes *new* content, so it can't ride a ref: it commits to the **root checkout's current branch**,
which must be your **integration trunk** (`main` today, `dev` later) — never hardcode `main`.
**This trunk-commit rule is for root-resident debriefs only:** invoked *inside an active
`/workstream` worktree*, write + commit on the stream's branch instead — the workstream's `ship`
lands it. The
trunk-branch guard + the pathspec-atomic commit rule are in the router's *shared discipline*; apply
them here. `debrief` is a **sweep**, so it makes **one** atomic commit over **every** file it
touched (the capture verbs it fans out to only *write* — they don't self-commit inside the sweep):
`scripts/scoped-commit.sh <root> "Debrief: route follow-ups" <every file this debrief wrote>` — list
`.agents/dev/BACKLOG.md` `.agents/dev/ISSUES.md` `.agents/dev/FEEDBACK.md` `.agents/dev/MEMORY.md`, the bug report, any
`.agents/dev/notes/<slug>.md`. The worktree's ignored hand-off is not a debrief target.

## Procedure

1. **Sanity check.** If the work was trivial or nothing meaningful surfaced, write nothing and reply:
   "Nothing surfaced to debrief." Don't manufacture entries.
2. **Resolve root + date.**
3. **Scan the whole completed body of work** for byproducts: unfinished TODOs, decisions deferred,
   defects noticed in passing, tooling/workflow friction, "out of scope for now" mentions,
   surprises, directional ideas, invariants learned, code touched-but-not-cleaned, files referenced
   but not opened. The scan is primarily over the **conversation** (the richest source), but ground
   it with filesystem facts: `scripts/dev-health.sh debrief-scan <root> [<trunk-ref>]` emits
   `dirty_dev:` (uncommitted `.agents/dev/` writes — captured along the way but not yet routed) and
   `new_todos:` (TODO/FIXME/XXX/HACK markers this work added — candidates to route or resolve).
4. **Bin each into exactly one home** per the taxonomy. Sketch the routing plan first (what goes
   where) so the user can see it in the report.
5. **Route each bucket** (each capture verb invoked here only *writes* — the single commit is step 8):
   - **BACKLOG** → apply the `/backlog backlog` capture convention (group, dedupe, item = concrete
     description + why + effort `(S/M/L)` + `· added YYYY-MM-DD`). For a backlog-only sweep, just run
     `/backlog backlog`.
   - **bugs** → write the report from `templates/bug-report.md`; then add the linking actionable item
     (BACKLOG/ISSUES). Promote a durable trap to `GOTCHAS.md`.
   - **ISSUES** → the `/backlog issue` convention: an impact-ranked entry (what happened · impact ·
     suggested fix), continuing the file's numbering scheme.
   - **FEEDBACK** → the `/backlog feedback` convention: a dated entry (`templates/feedback.md`), noting
     whether it's praise, a concern, or a directional idea, and where it might lead.
   - **Skill feedback** → if the strong feedback is about a *workflow skill you used* (`/foreman`,
     `/feature`, `/workstream`, `/delegate`, …) rather than this project, route it to the **skills' own
     `FEEDBACK.md`** (at their install root, tagged by skill), **not** `.agents/dev/FEEDBACK.md` — that's where
     it can fine-tune the skill. Strong + concrete only. (Portable: name "the skills' feedback channel"
     and resolve its path in-session; don't hardcode it here.)
   - **MEMORY** → only a genuine invariant; one line. Otherwise downgrade.
   - **spillover** → for any of the above whose entry needs more than a line, write
     `.agents/dev/notes/<slug>.md` and link it from the entry.
6. **Dedupe** against existing entries in each file before writing.
7. **Verify the shipped-record exists.** Confirm the completed work has its `.agents/dev/done/` record (or
   that the `/workstream` land step / `/foreman` will write it) — `debrief-scan`'s `recent_done:`
   lists the latest records to check against. If it's missing, **flag it** — don't write it here;
   that's not this verb's job.
8. **Commit once + report.** Make the single atomic scoped commit over every file touched (above),
   then report in chat: a compact table of what went where, with file paths. If nothing fit a bucket,
   say so for that bucket rather than padding.

## Relationship to neighboring verbs

- **`/backlog backlog`** owns the `BACKLOG.md` bucket (capture / groom); **`/backlog issue`** and
  **`/backlog feedback`** own `ISSUES.md` / `FEEDBACK.md`. `debrief` routes each share through that verb's
  convention; for a single-tracker add, use the verb directly. (The `.agents/dev/done/` shipped-record is
  written by the land step / `/foreman`, not the capture verbs.)
- **`/handoff`** saves the session as a resumable narrative doc. `debrief` is complementary: at a
  checkpoint, `handoff` writes the story, `debrief` drains the byproducts to the trackers. Do both.
- **`/workstream`** drives a stream in a worktree. Run `/backlog debrief` when a feature — or a phase of
  it — meets its Done-when, which is *before* you `/workstream ship` it, **not** as part of that verb.
  Landing the code is transport; debrief is tied to the work being finished. The workstream sequences
  two passes around the reset: **#1 before `ship`** (rides the ff-merge free), and — only if the ship
  was *eventful* (conflicts, contention retries, multiple syncs) — **#2 after `ship`**, both before
  the pre-reset `save` (see the workstream skill's *Reset ritual*).

## Style notes

- Items are forward-looking, not past-tense recaps. Quote file paths exactly; omit a line number
  rather than guess it.
- This is a record, not a commitment — don't promise to do the items yourself afterward.
- Keep `MEMORY.md` tiny; keep `notes/` subordinate; keep `bugs/` reports linked.

## Done when

Every byproduct the work surfaced sits in exactly one durable home — with `.agents/dev/notes/` spillover
linked where an entry needed depth — nothing is double-logged, the `.agents/dev/done/` shipped-record is
confirmed (or flagged missing), and the chat report names what went where.
