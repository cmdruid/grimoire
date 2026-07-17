# `/backlog issue` — capture dev-experience friction

File a **dev-experience friction** point into `dev/ISSUES.md` the moment it bites — slow/opaque
iteration, a silent failure, missing/wrong docs, a harness or workflow papercut. This is the
quick, one-shot path to the friction log (the new sibling of `/backlog bug`); the full end-of-work sweep
is `/backlog debrief`.

**Friction, not a defect.** `ISSUES.md` is "the dev experience got in my way." Anything else goes
to its own tracker — the taxonomy is canonical in `dev/docs/DEVELOPMENT.md` → *Capture follow-ups*
(defect → `/backlog bug`, feature → `/backlog backlog`, qualitative → `/backlog feedback`).

The model owns the **friction-vs-bug call** (does this break the *product*, or just slow the
*developer*?) and the **impact ranking** (HIGH / MEDIUM / LOW).

## When to use

- Tooling/harness/docs/workflow friction surfaces **mid-work** and you want it logged before it's
  lost — a gate that's too slow, a silent capture drop, a doc that misled you, a papercut.
- The user says: "/backlog issue", "log this friction", "the tooling got in my way", "this workflow is
  painful — note it".

**Do NOT use** for a product defect (`/backlog bug`), a feature wish (`/backlog backlog`), or a purely
qualitative note (`/backlog feedback`). A durable *gotcha* discovered here should **also** be added to
`dev/docs/GOTCHAS.md` so the next agent avoids the trap.

## File location

Project-relative. Resolve the root + real date with `date +%Y-%m-%d` — don't guess.

- Issues log: `<root>/dev/ISSUES.md`. It is a flat markdown log, **not** a store dir — no
  per-file frontmatter (the doc-linter does not gate it).

## Issues structure & numbering

`dev/ISSUES.md` groups entries under category sections and gives each a **category-prefixed running
number**:
- **`E#`** — Environment / Tooling (build, harness, render, scenario papercuts).
- **`W#`** — Workflow / workstream (the worktree pipeline, landing, the skills themselves).

(Sessions also add dated `## Added <date> — <session>` sections; an entry still takes the next free
number for its category prefix.) **Follow the file's existing scheme** — pick the category that
fits, scan for the **highest existing number** under that prefix, and take the next one. Do not
renumber existing entries.

## Procedure

1. **Confirm it's friction.** Dev-experience pain, not a product defect / feature / qualitative item
   (route those to their home and stop). If it's a working-as-coded trap, add it to
   `dev/docs/GOTCHAS.md` (and optionally log the friction of hitting it blind).
2. **Form the entry.** Pick the category (E/W) and the next free number. Write:
   - `### <prefix><n> — <short title> (<HIGH|MEDIUM|LOW>)`
   - **What happened** — the concrete friction, with `file:line` / command / log line where it
     applies.
   - **Impact** — who/what it slows, how often.
   - **Suggested fix** — the concrete change that would remove it (one or two lines).
3. **Dedupe** against existing entries — if the friction is already logged, sharpen that entry
   rather than adding a near-duplicate.
4. **Append** under the right category section, continuing the numbering. Never edit unrelated
   entries.
5. **Promote a durable trap** to `dev/docs/GOTCHAS.md` if one surfaced.
6. **Commit (standalone only).** Invoked **standalone**, scoped-commit via
   `scripts/scoped-commit.sh <root> "Issue <prefix><n>: <short what>" dev/ISSUES.md` (+ `GOTCHAS.md` if you
   touched it), then run the host doc-linter. Invoked **inside `/backlog debrief` or a `/foreman tune`
   sweep**, do **not** commit — only write; the sweep makes the single atomic commit.
7. **Report** the entry id (`E#`/`W#`) and the path.

## Relationship to neighboring verbs

- **`/backlog debrief`** routes *all* byproducts of a finished body of work, friction included, in one
  sweep. `issue` is the in-the-moment, single-friction path to the same `ISSUES.md` log.
- **`/foreman tune`** (its `issues` pass) drains `ISSUES.md` — resolved entries → `dev/done/`, durable
  gotchas → `GOTCHAS.md`. Capture is this verb's job; draining is `/foreman tune`'s.
- **`/backlog bug`** is the product-defect sibling; **`/auditor`** may surface friction it routes here.

## Done when

The friction is an impact-ranked `ISSUES.md` entry (what happened · impact · suggested fix) under
the right category, continuing the numbering, deduped against what's there — any durable trap also in
`GOTCHAS.md` — and the chat names the entry id and path.
