# `/backlog issue` — capture a project problem / concern / limitation

File a **project problem, concern, or limitation** into `.records/trackers/issues.md` the moment it
surfaces — a known limitation, an architectural concern, a risk, a non-code problem that isn't a
reproducible defect and isn't a build item. This is the quick, one-shot path to the issues log; the
full end-of-work sweep is `/backlog debrief`.

**A project problem, not a defect and not a build item.** `issues.md` is "something about the project
is wrong, risky, or limited." Anything else goes to its own tracker — the taxonomy is canonical in
`docs/TAXONOMY.md` (a reproducible code defect → `/backlog bug`, a thing to build → `/backlog task`, a
durable fact → `/backlog note`, a dev-experience observation → `/backlog feedback`).

**`bug` vs `issue` — the classifier.** A **reproducible code defect** (a crash, wrong output, dropped
state, flaky behavior — something with a repro) → `/backlog bug`. A **broader or non-code project
problem** (a limitation, a design concern, a risk, a gap without a single repro) → `issue`. If you can
write a repro, it's a bug; if it's a concern about the project rather than a defect you can reproduce,
it's an issue.

The model owns that **bug-vs-issue call** and the **impact ranking** (HIGH / MEDIUM / LOW).

## When to use

- A project problem/concern/limitation surfaces and you want it logged before it's lost — a known
  limitation, an architectural risk, a gap, a non-code problem without a clean repro.
- The user says: "/backlog issue", "log this concern", "this is a known limitation", "note this risk".

**Do NOT use** for a reproducible code defect (`/backlog bug`), a thing to build (`/backlog task`), a
durable project fact (`/backlog note`), or a dev-experience observation about skills / tooling /
workflow (`/backlog feedback`). A durable *gotcha* discovered here should **also** be captured as a
`/backlog note` — the improvement loop lands proven traps in `.handbook/rules/GOTCHAS.md` so the next
agent avoids the trap.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Issues log: `<root>/.records/trackers/issues.md`. It is a flat markdown log, **not** a store dir — no
  per-file frontmatter. If the trackers are missing — run `/backlog setup` first (lazily; it
  scaffolds the trackers at the records root and registers the route), then continue.

## Issues structure & numbering

`.records/trackers/issues.md` groups `### I-n` entries under `##` category sections — the wire
format (schema: the installation's `.handbook/rules/RECORDS.md`) is
`### I-017 — <title> (HIGH|MEDIUM|LOW)`. **ID allocation is trunk-side only:** take the next free
`I-` number scanning the live file *and* the done log (IDs are never reused; never renumber);
capturing where the trunk is unreachable, write `((pending: <slug>))` in the ID position —
`/backlog curate` stamps the real ID at landing. A migrated entry keeps its old identifier as
`(alias <old>)` on the heading line. **Follow the file's existing category sections** — pick the
one that fits; add a section only when nothing fits.

## Procedure

1. **Confirm it's an issue.** A project problem/concern/limitation — not a reproducible defect (that's
   `/backlog bug`), a build item (`/backlog task`), a fact (`/backlog note`), or a dev-experience
   observation (`/backlog feedback`); route those to their home and stop. If it's a working-as-coded
   trap, capture it as a `/backlog note` (the improvement loop lands proven traps in
   `.handbook/rules/GOTCHAS.md`).
2. **Form the entry.** Pick the category section and allocate the next free `I-` number (or the
   pending placeholder off-trunk). Write:
   - `### I-<n> — <short title> (<HIGH|MEDIUM|LOW>)`
   - **What's wrong** — the concrete problem/concern/limitation, with `file:line` / context where it
     applies.
   - **Impact** — who/what it affects, how badly.
   - **Suggested direction** — the change or investigation that would address it (one or two lines).
3. **Dedupe** against existing entries — if the problem is already logged, sharpen that entry
   rather than adding a near-duplicate.
4. **Append** under the right category section. Never edit unrelated entries.
5. **Capture a durable trap as a `/backlog note`** if one surfaced — the improvement loop lands
   it in `.handbook/rules/GOTCHAS.md`.
6. **Commit (standalone only).** Invoked **standalone**, scoped-commit via
   `scripts/scoped-commit.sh <root> "Issue I-<n>: <short what>" .records/trackers/issues.md` (+ the
   note file under `.records/trackers/notes/` if you captured a trap), then run the host's cheap doc gate if it has one. Invoked **inside `/backlog debrief` or a drain
   sweep**, do **not** commit — only write; the sweep makes the single atomic commit.
7. **Report** the entry id (`I-n`) and the path.

## Relationship to neighboring verbs

- **`/backlog debrief`** routes *all* byproducts of a finished body of work, project problems included,
  in one sweep. `issue` is the in-the-moment, single-problem path to the same `issues.md` log.
- **The improvement loop** drains system-relevant signal from the stores into the handbook. Capture is this
  verb's job; draining is the loop's.
- **`/backlog bug`** is the reproducible-defect sibling; **`/backlog feedback`** is the dev-experience
  channel; **`/auditor`** may surface problems it routes here.

## Done when

The problem is an impact-ranked `issues.md` entry (what's wrong · impact · suggested direction) under
the right category, continuing the numbering, deduped against what's there — any durable trap
captured as a `/backlog note` (for the improvement loop to land in the gotchas chapter) — and the chat names the
entry id and path.
