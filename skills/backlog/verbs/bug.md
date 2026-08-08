# `/backlog bug` — file an observed defect

File an observed **defect** the right way, the moment it surfaces — so the repro survives even if
you move on (or can't reproduce it later). Encodes the deployed routing chapter (`.handbook/rules/ROUTING.md`) → *when it’s a bug* and
the `.handbook/testing/DIAGNOSTICS.md` playbook into one pass.

A **bug** is an observed, reproducible defect: a crash, wrong render/output, dropped state, or flaky
behavior. Anything that is *not* a reproducible defect goes to its own tracker — the five-kind
taxonomy is canonical in `docs/TAXONOMY.md` (a thing to build → `/backlog task`, a project
problem/concern/limitation → `/backlog issue`, a durable fact → `/backlog note`, a dev-experience
observation → `/backlog feedback`).

The load-bearing rule: **`.records/trackers/bugs/` is a store, not a work queue.** You file a report there and
track the fix from a **linked actionable item**; you never fish in `bugs/` for work. So a report is
never left with nothing pointing at it.

## When to use

- A defect surfaces **mid-work** and you want it captured before it's lost — especially if it's
  **flaky/transient** (capture everything *now*; you may not repro later).
- The user says: "/backlog bug", "file a bug", "this is broken — here's the repro", "log this defect",
  "report this crash".

**Do NOT use** for a thing to build (`/backlog task`), a project problem/concern/limitation
(`/backlog issue`), a durable fact (`/backlog note`), or a dev-experience observation
(`/backlog feedback`). And if it turns out to be **working-as-coded but surprising**, it's not a
bug — capture it as a `/backlog note` (the improvement loop lands proven traps in
`.handbook/rules/GOTCHAS.md`) and file no report. For the end-of-work *sweep* that routes
many surfaced items at once (including any defects), that's `/backlog debrief`; this verb is the
single-defect, right-now path to the same destination.

## File locations

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` (see the router's shared
discipline) — don't guess.

- Report: `<root>/.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md`, from this skill's `templates/bug-report.md`. Start
  the file with the template's `type: bug` frontmatter block (`type`/`id`/`status`/`updated`) —
  the store-dir frontmatter is mandatory. `id:` takes the next free `B-` counter, **allocated
  trunk-side only** (scan the live store, its `archive/`, *and* the done log; IDs are never
  reused); capturing where the trunk is unreachable, leave `id:` pending — `/backlog curate`
  stamps it at landing. Schema: the installation's `.handbook/rules/RECORDS.md`.
- A fixed report's completion (`/backlog done B-009`) advances its frontmatter; `/backlog curate`
  may age resolved reports into `<root>/.records/trackers/bugs/archive/`.
- If the trackers are missing — or the root carries no installation block at all (unstamped) —
  run `/backlog init` first (lazily; it scaffolds the trackers and creates-or-adopts the
  installation block), then continue.
- The linking actionable item lives in `.records/trackers/tasks.md` (or an `.records/trackers/issues.md` entry if
  it's tracked as a broader project problem) — never in `bugs/` itself.

## Procedure

1. **Confirm it's a bug.** It's an observed, reproducible defect, not a task/issue/note/feedback item
   (route those to their home and stop). **Check `.handbook/rules/GOTCHAS.md` first** (and
   `.records/trackers/notes/` for a trap not yet promoted) — it may be a known trap (working-as-coded).
   If so, it's not a bug: capture it as a `/backlog note` if it isn't one already (the
   improvement loop lands proven traps in the gotchas chapter), and stop.
2. **Diagnose enough to capture a repro** (per the host's `.handbook/testing/DIAGNOSTICS.md`: observe →
   reproduce → isolate). Cheapest first — logs, the host's diagnostic overlays / state dumps; pin any
   seed/state and capture it in the host's scripted scenario/test harness (a scripted repro the
   harness replays *is* the repro); for a render/visual bug, the host's isolated-render tool surfaces
   errors the normal run swallows. **If it's flaky, capture everything the moment it happens** — seed,
   scenario, log line, screenshot — before anything else.
3. **Resolve root + date; slug** the defect (short kebab).
4. **Write the report** to `.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md` from `templates/bug-report.md`:
   - **Status** (open), **Severity** (crash | wrong-output | dropped-state | flaky | cosmetic),
     **Flaky/transient?**
   - **Repro** — seed + scenario or exact commands/steps (a scripted repro is best).
   - **Expected vs actual** — with evidence: a log line, a captured artifact (screenshot / state
     dump), a diagnostic reading.
   - **Notes** — diagnosis so far, suspected area (`file:line`).
5. **Link it from an actionable item** — `bugs/` is a store, so the report must be tracked from
   somewhere actionable:
   - **Fixing now?** Make the fix (patch or feature, by size), note the commit in the report's
     Status, then `git mv` the report to `.records/trackers/bugs/archive/`.
   - **Deferring?** Add a `.records/trackers/tasks.md` line (or an `.records/trackers/issues.md` entry if it's a
     broader project problem) that **links** the report path. Never leave a report unlinked.
6. **Commit (standalone only).** Invoked **standalone**, scoped-commit the report + its linking item
   in one step via `scripts/scoped-commit.sh <root> "File <slug> bug + tracker link" <paths…>`, then run
   the host's cheap doc gate if it has one. Invoked **inside `/backlog debrief`**, do **not**
   commit — only write; the sweep makes the single atomic commit.
7. **Report in chat** — the report path and either the linking item or the fix commit. If a durable
   trap surfaced during diagnosis, note that it was captured as a `/backlog note` (for the
   improvement loop to land in the gotchas chapter).

## Relationship to neighboring verbs

- **`/backlog debrief`** routes *all* byproducts of a finished body of work, defects included, in one
  sweep at plan completion. `bug` is the in-the-moment, single-defect path to the same `bugs/` store
  and the same store-not-queue rule. Use `bug` when something breaks *now*; let `debrief` catch the
  rest.
- **`/backlog task`** owns the linked `tasks.md` item that schedules the fix; **`/backlog issue`** owns the
  `issues.md` entry when the defect is tracked as a broader project problem.
- **`/auditor`** drains code-quality *defects* to `bugs/` too — it can call this flow to file one.

## Done when

The defect has a report in `.records/trackers/bugs/` with a real repro + evidence, that report is **linked from an
actionable item** (or already fixed-and-archived with its commit), no working-as-coded "bug" was
filed (captured as a `/backlog note` instead, for the improvement loop to land in the gotchas chapter), and the chat
names where the report and its tracker live.
