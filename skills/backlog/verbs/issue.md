# `/backlog issue` — capture a project problem / concern / limitation

File a **project problem, concern, or limitation** into `.records/issues.md` the moment it
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
`/backlog note` — `/foreman` promotes it to `.agents/dev/docs/GOTCHAS.md` during `tune` so the next
agent avoids the trap.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Issues log: `<root>/.records/issues.md`. It is a flat markdown log, **not** a store dir — no
  per-file frontmatter (the doc-linter does not gate it).

## Issues structure & numbering

`.records/issues.md` groups entries under category sections and gives each a **category-prefixed running
number**:
- **`P#`** — Problem / limitation (a project defect-of-design, a known limitation, a gap).
- **`R#`** — Risk / concern (an architectural risk, a fragility, a concern to revisit).

(Sessions also add dated `## Added <date> — <session>` sections; an entry still takes the next free
number for its category prefix.) **Follow the file's existing scheme** — pick the category that
fits, scan for the **highest existing number** under that prefix, and take the next one. Do not
renumber existing entries.

## Procedure

1. **Confirm it's an issue.** A project problem/concern/limitation — not a reproducible defect (that's
   `/backlog bug`), a build item (`/backlog task`), a fact (`/backlog note`), or a dev-experience
   observation (`/backlog feedback`); route those to their home and stop. If it's a working-as-coded
   trap, capture it as a `/backlog note` (`/foreman` promotes it to `.agents/dev/docs/GOTCHAS.md`
   during `tune`).
2. **Form the entry.** Pick the category (P/R) and the next free number. Write:
   - `### <prefix><n> — <short title> (<HIGH|MEDIUM|LOW>)`
   - **What's wrong** — the concrete problem/concern/limitation, with `file:line` / context where it
     applies.
   - **Impact** — who/what it affects, how badly.
   - **Suggested direction** — the change or investigation that would address it (one or two lines).
3. **Dedupe** against existing entries — if the problem is already logged, sharpen that entry
   rather than adding a near-duplicate.
4. **Append** under the right category section, continuing the numbering. Never edit unrelated
   entries.
5. **Capture a durable trap as a `/backlog note`** if one surfaced — `/foreman` promotes it to
   `.agents/dev/docs/GOTCHAS.md` during `tune`.
6. **Commit (standalone only).** Invoked **standalone**, scoped-commit via
   `scripts/scoped-commit.sh <root> "Issue <prefix><n>: <short what>" .records/issues.md` (+ the
   note file under `.records/notes/` if you captured a trap), then run the host doc-linter. Invoked **inside `/backlog debrief` or a `/foreman tune`
   sweep**, do **not** commit — only write; the sweep makes the single atomic commit.
7. **Report** the entry id (`P#`/`R#`) and the path.

## Relationship to neighboring verbs

- **`/backlog debrief`** routes *all* byproducts of a finished body of work, project problems included,
  in one sweep. `issue` is the in-the-moment, single-problem path to the same `issues.md` log.
- **`/foreman tune`** drains system-relevant signal from the trackers into doctrine. Capture is this
  verb's job; draining is `/foreman`'s.
- **`/backlog bug`** is the reproducible-defect sibling; **`/backlog feedback`** is the dev-experience
  channel; **`/auditor`** may surface problems it routes here.

## Done when

The problem is an impact-ranked `issues.md` entry (what's wrong · impact · suggested direction) under
the right category, continuing the numbering, deduped against what's there — any durable trap
captured as a `/backlog note` (for `/foreman` to promote to `GOTCHAS.md`) — and the chat names the
entry id and path.
