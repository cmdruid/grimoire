# `/backlog feedback` — capture a qualitative / directional note

Capture the agent's **qualitative voice** on the project, process, docs, or tools into
`.agents/dev/FEEDBACK.md` — what worked, what didn't, a directional suggestion, a surprise that isn't a bug.
This is the quick, one-shot path to the feedback log (the new sibling of `/backlog backlog`); the full
end-of-work sweep is `/backlog debrief`.

**Qualitative, not actionable.** `FEEDBACK.md` is **not** a task tracker. An actionable thing goes
to its real home — the taxonomy is canonical in `.agents/dev/docs/DEVELOPMENT.md` → *Capture follow-ups*
(feature → `/backlog backlog`, defect → `/backlog bug`, dev-friction → `/backlog issue`).

This file is for observations, praise, critique, and open musings the owner reviews: "the
ADR→plan→worktree flow felt great", "the docs are getting heavy", "consider leaning into direction
Y", "this surprised me but isn't a bug".

## When to use

- A qualitative reaction or directional idea surfaces and is worth recording before it's lost —
  "this felt great", "this is getting heavy", "we might lean into Y".
- The user says: "/backlog feedback", "log this feedback", "note how that felt", "capture this observation".

**Do NOT use** for anything actionable — a feature wish (`/backlog backlog`), a defect (`/backlog bug`),
dev-friction (`/backlog issue`) — or for the end-of-work multi-tracker sweep (`/backlog debrief`). If a note
is *partly* actionable, file the action in its real home and keep only the qualitative residue here.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Feedback: `<root>/dev/FEEDBACK.md`. Create it if missing (`# FEEDBACK` header + the one-line note
  that actionable items go to their real home). It is a flat log, **not** a store dir — no per-file
  frontmatter.

## Feedback structure

`.agents/dev/FEEDBACK.md` is a single **flat** list of dated entries — **no sections**, newest added at the
bottom of the live region. Each entry follows `.agents/dev/templates/feedback.md`:

```
### <short title> · YYYY-MM-DD

<The observation / suggestion / what worked or didn't — keep it short. Note whether it's positive,
a concern, or a directional idea, and where it might lead if anywhere (a `BACKLOG`/`bugs`/`ISSUES`
item it should become, or "just an observation").>
```

The **feedback audit** (`/foreman tune`'s `feedback` pass) periodically *drains* this file — routing
each item to its real home or acting on it — so it stays a live signal, not a graveyard.

## Procedure

1. **Sanity check.** If there's nothing real to capture — or it's actually actionable — write
   nothing here (route the actionable part to its home) and say so.
2. **Form the entry** from `templates/feedback.md`: `### <short title> · <date>` + a short body
   noting whether it's praise / a concern / a directional idea, and where it might lead.
   **Grounding:** the note ties to something that actually came up — don't manufacture sentiment.
3. **Dedupe** against existing entries — if the observation is already logged, sharpen it rather than
   adding a near-duplicate.
4. **Append** the dated entry to the live region (don't disturb the drained-marker history above).
5. **Commit (standalone only).** Invoked **standalone**, scoped-commit via
   `scripts/scoped-commit.sh <root> "Feedback: <short title>" .agents/dev/FEEDBACK.md`, then run the host
   doc-linter. Invoked **inside `/backlog debrief` or a `/foreman tune` sweep**, do **not** commit —
   only write; the sweep makes the single atomic commit.
6. **Report** the entry title and the path.

## Relationship to neighboring verbs

- **`/backlog debrief`** — the completion sweep across *all* trackers; it routes the qualitative share
  here. `feedback` is the anytime, FEEDBACK-only, direct add.
- **`/foreman tune`** (its `feedback` pass) drains `FEEDBACK.md` — routing actionable items to their
  real home, clearing absorbed ones. Capture is this verb's job; draining is `/foreman tune`'s.
- **`/backlog backlog`**, **`/backlog bug`**, **`/backlog issue`** — the actionable homes; this verb is the
  qualitative residue only.

## Style notes

- Keep it short; one dated entry per observation. Quote paths exactly; omit a line number rather than
  guess.
- This is a record, not a commitment — don't promise to act on it yourself afterward.

## Done when

The qualitative note is a dated `.agents/dev/FEEDBACK.md` entry (positive / concern / directional, with where
it might lead), deduped against what's there, with any actionable part routed to its real home — and
the chat names the entry and path.
