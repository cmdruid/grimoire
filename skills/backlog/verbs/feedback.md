# `/backlog feedback` — capture a dev-experience observation

Capture the agent's voice on the **development experience** — the skills, scripts, tooling, and
environment you work *through* — into `.records/feedback.md`. This is the **single dev-experience
channel**: observations, praise, concerns, and the day-to-day frictions (a slow/opaque gate, a silent
failure, a misleading doc, a harness papercut) that used to be filed as `issue`s all land here. This
is the quick, one-shot path to the feedback log; the full end-of-work sweep is `/backlog debrief`.

**About the dev experience, not the project.** `feedback.md` is "how it felt to build here, and what
fought me." Anything *about the project itself* goes to its real home — the taxonomy is canonical in
`docs/TAXONOMY.md` (a thing to build → `/backlog task`, a project problem/concern/limitation →
`/backlog issue`, a reproducible defect → `/backlog bug`, a durable project fact → `/backlog note`).

This file is for reactions to the tooling and workflow the owner reviews: "the ADR→plan→worktree flow
felt great", "the gate is too slow", "this harness papercut cost me ten minutes", "the docs are
getting heavy", "consider leaning into direction Y", "a silent capture drop bit me".

## When to use

- A dev-experience reaction, friction, or directional idea surfaces and is worth recording before
  it's lost — "this felt great", "the tooling got in my way", "this is getting heavy", "we might
  lean into Y".
- The user says: "/backlog feedback", "log this feedback", "note how that felt", "the workflow is
  painful — note it", "capture this observation".

**Do NOT use** for anything about the **project itself** — a thing to build (`/backlog task`), a project
problem/concern/limitation (`/backlog issue`), a reproducible defect (`/backlog bug`), a durable fact
(`/backlog note`) — or for the end-of-work multi-tracker sweep (`/backlog debrief`). If a note is
*partly* a project item, file that part in its real home and keep only the dev-experience residue here.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Feedback: `<root>/.records/feedback.md`. Create it if missing (`# FEEDBACK` header + the one-line note
  that project items go to their real home). It is a flat log, **not** a store dir — no per-file
  frontmatter.

## Feedback structure

`.records/feedback.md` is a single **flat** list of dated entries — **no sections**, newest added at the
bottom of the live region. Each entry follows `templates/feedback.md`:

```
### <short title> · YYYY-MM-DD

<The observation / friction / suggestion — keep it short. Note whether it's positive, a concern, or
a directional idea, and where it might lead if anywhere (a project item it should become, a doctrine
change, or "just an observation").>
```

The **feedback audit** (`/foreman calibrate`) periodically *drains* this file — routing each item to its
real home, folding system-relevant signal into doctrine, or acting on it — so it stays a live signal,
not a graveyard.

## Procedure

1. **Sanity check.** If there's nothing real to capture — or it's actually a project item — write
   nothing here (route the project part to its home) and say so.
2. **Form the entry** from `templates/feedback.md`: `### <short title> · <date>` + a short body
   noting whether it's praise / a concern / a friction / a directional idea, and where it might lead.
   **Grounding:** the note ties to something that actually came up — don't manufacture sentiment.
3. **Dedupe** against existing entries — if the observation is already logged, sharpen it rather than
   adding a near-duplicate.
4. **Append** the dated entry to the live region (don't disturb the drained-marker history above).
5. **Commit (standalone only).** Invoked **standalone**, scoped-commit via
   `scripts/scoped-commit.sh <root> "Feedback: <short title>" .records/feedback.md`, then run the host
   doc-linter. Invoked **inside `/backlog debrief` or a `/foreman calibrate` sweep**, do **not** commit —
   only write; the sweep makes the single atomic commit.
6. **Report** the entry title and the path.

## Relationship to neighboring verbs

- **`/backlog debrief`** — the completion sweep across *all* trackers; it routes the dev-experience
  share here. `feedback` is the anytime, FEEDBACK-only, direct add.
- **`/foreman calibrate`** drains `feedback.md` — routing project items to their real home, folding
  system-relevant signal into doctrine, clearing absorbed ones. Capture is this verb's job; draining
  is `/foreman`'s.
- **`/backlog task`**, **`/backlog issue`**, **`/backlog bug`**, **`/backlog note`** — the project-subject homes;
  this verb is the dev-experience channel only.

## Style notes

- Keep it short; one dated entry per observation. Quote paths exactly; omit a line number rather than
  guess.
- This is a record, not a commitment — don't promise to act on it yourself afterward.

## Done when

The dev-experience note is a dated `.records/feedback.md` entry (positive / concern / friction /
directional, with where it might lead), deduped against what's there, with any project part routed to
its real home — and the chat names the entry and path.
