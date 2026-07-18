# `/backlog note` — capture a durable project fact / knowledge

Capture a **durable fact or piece of knowledge about the project** — the kind of thing worth
remembering but not yet a load-bearing invariant — into `.records/notes/<slug>.md`. This is the
quick, one-shot path to the notes store; the full end-of-work sweep is `/backlog debrief`.

**A fact about the project, not an action and not the dev experience.** A note records *what is true*
— a design rationale, a worked example, the reasoning behind a decision, a detail that didn't fit one
line on a tracker entry. Anything *to do* goes to its real home (a build item → `/backlog task`, a
problem → `/backlog issue`, a defect → `/backlog bug`), and anything about the **dev experience**
(skills / tooling / workflow) goes to `/backlog feedback`.

A note is **lower-bar than a `MEMORY.md` invariant.** `MEMORY.md` holds only the sacred, load-bearing
rules the code doesn't already make obvious — a very high bar, and `/foreman` is what *promotes* a
note into one. `/backlog note` just captures the fact; it never promotes.

## When to use

- A durable project fact surfaces and is worth recording before it's lost — "the reason we chose X
  over Y", "the detail behind that decision", "how this subsystem actually behaves", a worked example
  that explains a gotcha's context.
- The user says: "/backlog note", "capture this fact", "write this down", "make a note of how this
  works".

**Do NOT use** for anything actionable — a build item (`/backlog task`), a project
problem/concern/limitation (`/backlog issue`), a defect (`/backlog bug`) — for a dev-experience
observation (`/backlog feedback`), or for the end-of-work multi-tracker sweep (`/backlog debrief`). A
note is *subordinate*: it exists to be reached through the tracker entry that links it, never by
browsing. If it reads as a standalone investigation someone would open on its own, it belongs in
`reports/`, not `notes/`.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Note: `<root>/.records/notes/<slug>.md`, from `<root>/.agents/backlog/templates/note.md`. Start
  the file with the template's frontmatter block (`type: note` / `status` / `updated` / `related`) —
  the doc-linter gate rejects a `notes/` store-dir file without it. Schema: `docs/TAXONOMY.md`.

## Note structure

Each `notes/<slug>.md` follows `templates/note.md`: the frontmatter block, a `# <Title> — note`
heading, a `_backs:_` line naming the tracker entry it backs, then the long-form context. A note is
**subordinate** — it is linked from the entry it backs (a `tasks.md` line, an `issues.md` entry, a bug
report, a `MEMORY.md` line), never left orphaned.

## Procedure

1. **Sanity check.** If there's nothing durable to capture — or it's actually actionable, or it's
   really about the dev experience — write no note (route it to its home) and say so.
2. **Confirm the kind.** It's a project *fact*, not a follow-up and not dev-experience feedback; it's
   worth remembering but below the `MEMORY.md` invariant bar.
3. **Slug** the note (short kebab). **Write** it to `.records/notes/<slug>.md` from
   `templates/note.md` — frontmatter block first, then the `_backs:_` line and the long-form context.
4. **Link it** from the tracker entry it backs (fill the `related:` frontmatter and the entry's
   pointer). A note that nothing links to is an orphan — either link it or it doesn't belong here.
5. **Dedupe** against existing notes — if the fact is already recorded, sharpen that note rather than
   adding a near-duplicate.
6. **Commit (standalone only).** Invoked **standalone**, scoped-commit the note + any linking entry in
   one step via `scripts/scoped-commit.sh <root> "Note: <short title>" <paths…>`, then run the host
   doc-linter. Invoked **inside `/backlog debrief` or a `/foreman calibrate` sweep**, do **not** commit —
   only write; the sweep makes the single atomic commit.
7. **Report** the note title and the path.

## Relationship to neighboring verbs

- **`/backlog debrief`** — the completion sweep across *all* trackers; it writes a `notes/` spillover
  file when an entry needs more than a line. `note` is the anytime, direct path to the same store.
- **`/foreman`** promotes a durable fact into a `MEMORY.md` invariant when it earns that bar. Capture
  is this verb's job; promotion is `/foreman`'s.
- **`/backlog task`**, **`/backlog issue`**, **`/backlog bug`**, **`/backlog feedback`** — the actionable and
  dev-experience homes; this verb is the durable project *fact* only.

## Style notes

- Keep it subordinate: a note backs an entry; it is not a standalone report. Quote paths exactly;
  omit a line number rather than guess.
- This is a record of what's true, not a commitment — don't promise to act on it yourself afterward.

## Done when

The durable fact is a `.records/notes/<slug>.md` file with the `templates/note.md` frontmatter,
linked from the tracker entry it backs, deduped against what's there — and the chat names the note
title and path.
