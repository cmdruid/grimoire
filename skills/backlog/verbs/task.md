# `/backlog task` — capture a task (product/feature follow-up)

Capture follow-up work into `.agents/backlog/TASKS.md`. TASKS is the one tracker with a **human producer** —
"put this in the backlog" is something *you* say — alongside agents. This verb is the quick, anytime
way to add a well-formed item.

It **only adds to** `TASKS.md`. Tidying the list — dedupe / rank / weed — is the sibling
`/backlog curate`; turning a task into shipped work is `/feature` / `/workstream`; draining
system-relevant signal back into doctrine is `/foreman tune`; the end-of-work sweep that routes
byproducts across *all* trackers is `/backlog debrief`.

## When to use

- "put this in the backlog", "add a task: X", "remind me to …", "/backlog task", or "any
  follow-ups worth capturing from this?" — anytime, by you or an agent.

**Do NOT use** for: a defect (`/backlog bug` → `.agents/backlog/bugs/`), a project problem/concern/limitation
(`/backlog issue` → `.agents/backlog/ISSUES.md`), a durable project fact (`/backlog note` →
`.agents/backlog/notes/`), a dev-experience observation (`/backlog feedback` → `.agents/backlog/FEEDBACK.md`),
the end-of-work multi-tracker sweep (`/backlog debrief`), or tidying the list (`/backlog curate`).
Don't invoke it mid-task for routine status checks.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Tasks: `<root>/.agents/backlog/TASKS.md`. Create it if missing (`# Tasks` header + a one-line note that
  an item is *removed when it ships*, recorded in `.agents/dev/done/`).

## Tasks structure

`.agents/backlog/TASKS.md` is a single **living** list — one top-level header, one section per group. Items
are plain `-` bullets (**no checkboxes**): an item is *open* while it's listed and simply **removed
when it ships** — the commit, plus any `.agents/dev/done/` stream digest, is the record (turning it into
work is `/feature` / `/workstream`; the periodic relevance pass is `/foreman tune`, not a checkbox).

**Follow the file's existing groups.** If `TASKS.md` exists, adopt its group headings and heading
level exactly — extend them, don't restructure. Add a new group only when nothing fits. A long-lived
task list is organized by durable **domain / milestone groups** (e.g. `Performance`, `Tooling / CI`, a
milestone, `Known limitations`), so let the project's shape lead. Seed a *fresh* file with these
buckets only, skipping any that's empty:

1. **Loose ends** — in-scope work that didn't get done.
2. **Adjacent improvements** — cleanups/polish in code that was touched (optional).
3. **Open questions** — decisions deferred to the user, or clarifications the next agent needs.
4. **Future scope** — larger items discussed but explicitly out of the current batch.

(A problem observed but *not* a build item is a `/backlog issue`, not a task; a reproducible defect is
a `/backlog bug`.)

**Per-item:** concrete description (with `file:line` where it applies) · **why** (one line) ·
**effort** `(S/M/L)` · trailing `· added YYYY-MM-DD`. Mark a genuine maybe `(unsure)` and say why.

## Capture

Two paths — the first is the headline:

1. **Direct (common case).** You or an agent *names* an item — "put X in the backlog." Turn it into
   a well-formed item and add it. Keep it quick; don't over-ceremony a single add.
2. **Sweep (secondary).** "Any follow-ups from this?" — scan the conversation for task-worthy
   items and add them. (The end-of-work sweep across *all* trackers is `/backlog debrief`; this is the
   TASKS-only, invoke-anytime version.)

Procedure:
1. **Sanity check.** If there's nothing real to capture, write nothing and say so.
2. **Form each item** (description · why · effort · added-date). **Grounding:** every item ties to
   something real — named by the user, or that actually came up. Do **not** pad with pattern-matched
   generics ("add tests", "add logging") unless they specifically surfaced.
3. **Categorize** into the file's groups (or the seed buckets for a fresh file). If an item fits
   several, pick the most actionable.
4. **Merge.** Append under the right group heading (creating it if absent), preserving group order.
   **Dedupe** against existing items — skip a near-duplicate rather than add it. Never edit or
   remove existing items in capture; you only add. (To *reshape* the list, that's `/backlog curate`.)
5. **Commit (standalone only).** Invoked **standalone**, scoped-commit the tasks change via
   `scripts/scoped-commit.sh <root> "Tasks: <short what>" .agents/backlog/TASKS.md`, then run the host doc-linter.
   Invoked **inside `/backlog debrief`**, do **not** commit — only write; the sweep makes the
   single atomic commit. (This standalone self-commit is a deliberate refinement: a `/backlog task`
   add now lands on its own rather than waiting for an unrelated commit.)
6. **Report** what you added and the path.

## Removal — a pointer, not a mode

A shipped or abandoned item is **removed**, not checked off: delete the bullet (in the commit that
ships the work, or when `/backlog curate` weeds a dead one). There is no `prune` step and no `[x]` —
the commit history plus any `.agents/dev/done/` stream digest are the record, and the periodic relevance
pass is `/foreman tune`. **This verb never writes `.agents/dev/done/`.**

## Relationship to neighboring verbs

- **`/backlog curate`** — the tidy sibling: dedupe, re-rank, sharpen, and weed the existing list. This
  verb only adds; `curate` reshapes.
- **`/backlog debrief`** — the completion sweep across *all* trackers; it defers TASKS item-format
  to this verb. `task` is the anytime, TASKS-only, direct add.
- **`/foreman tune`** — drains system-relevant signal into doctrine (the curation loop). `task` itself
  never drains; it only captures.
- **`/backlog bug`**, **`/backlog issue`**, **`/backlog feedback`**, **`/backlog note`** — the other capture
  homes; this verb is `TASKS.md` only.

## Style notes

- Items are forward-looking action descriptions, not past-tense recaps.
- Plain `-` bullets — no checkboxes. Quote paths exactly; omit a line number rather than guess.
- This is a record, not a commitment — don't promise to do the items yourself afterward.

## Done when

The named follow-up(s) are in `.agents/backlog/TASKS.md` as well-formed, deduped, grouped bullets — and nothing
shipped is left lingering (that removal is on-ship + `/backlog curate` hygiene, never this verb). To reshape or
weed the list, run `/backlog curate`.
