# Capture taxonomy — the five kinds, their subjects, stores, formats, and frontmatter

The **canonical capture schema** for `.records/`: what kinds of follow-up exist, how to tell
them apart, where each one lands, the shape each store takes, and the per-file frontmatter the two
store dirs carry. Every `/backlog` verb defers to this doc, and other skills reference it rather than
restating it. `/backlog` owns this schema.

This is a **capture-only** schema. It says where a signal *lands* and in what shape — never how it is
later worked or folded into doctrine. Draining is a **consumer's** job (pointers below), never
described here.

## The five kinds

Capture is **uniform**: every byproduct lands in exactly one durable home by its **kind**, and the
cut between kinds is by **subject** — is this about the *project* being built, or the *dev experience*
of building it? Four kinds are project-subject; one (`feedback`) is the single dev-experience channel.

| kind | subject | nature | store |
|---|---|---|---|
| `note` | project | a durable fact / piece of knowledge | `.records/trackers/notes/<slug>.md` |
| `task` | project | an action to build / do | `.records/trackers/tasks.md` |
| `issue` | project | a problem / concern / limitation | `.records/trackers/issues.md` |
| `bug` | project | a reproducible code defect | `.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md` |
| `feedback` | dev-experience | any observation (skills / tooling / env / workflow) | `.records/trackers/feedback.md` |

These five kinds and their stores are the same set the `SKILL.md` verb-dispatch table routes to;
keep the two identical. A host does **not** extend this set — the five kinds are the whole taxonomy.

## The classifiers (how to tell the kinds apart)

Most captures are obvious. Three boundaries carry real judgment; the model makes the call.

- **`bug` vs `issue` (both project problems).** A **reproducible code defect** — a crash, wrong
  output, dropped state, flaky behavior, *something you can write a repro for* → **`bug`**. A
  **broader or non-code project problem** — a known limitation, a design concern, an architectural
  risk, a gap without a single repro → **`issue`**. Rule of thumb: if you can write a repro, it's a
  `bug`; if it's a concern *about* the project rather than a defect you can reproduce, it's an
  `issue`.

- **`note` vs `feedback` (the subject cut).** A **`note`** records a durable fact about the *project*
  — a design rationale, a worked example, how a subsystem behaves. **`feedback`** records an
  observation about the *dev experience* — the skills, scripts, tooling, and environment you work
  *through* ("the gate is too slow", "this harness papercut cost me ten minutes", "the ADR→plan flow
  felt great"). `feedback` is the **single dev-experience channel**: praise, concerns, frictions, and
  directional ideas about the tooling all land there, never split across other trackers.

- **`note` vs `MEMORY.md` (the bar).** A `note` is **lower-bar** than a `MEMORY.md` invariant.
  `MEMORY.md` holds only the sacred, load-bearing rules the code doesn't already make obvious — a very
  high bar. `/backlog note` just captures a durable fact worth remembering; it **never** promotes.
  Promoting a note into a `MEMORY.md` invariant is `/foreman`'s job.

## Per-kind detail — what it is, its store, and its format

### `note` — a durable project fact
- **What:** *what is true* about the project — rationale, a worked example, the reasoning behind a
  decision, a detail too long for one tracker line. **Subordinate:** a note exists to be reached
  through the tracker entry that links it, never by browsing. If it reads as a standalone
  investigation someone would open on its own, it belongs in `reports/`, not `notes/`.
- **Store:** `.records/trackers/notes/<slug>.md` (short kebab slug), from `templates/note.md`. A
  **store dir** — carries frontmatter (see below).
- **Format:** the frontmatter block, then a `# <Title> — note` heading, a `_backs:_` line naming the
  tracker entry it backs, then the long-form context. Link it from that entry (fill `related:`) — a
  note nothing links to is an orphan.

### `task` — a thing to build / do
- **What:** a product/feature follow-up — in-scope work not finished, an adjacent cleanup, a deferred
  decision, out-of-batch future scope. (A problem observed but *not* a build item is an `issue`; a
  reproducible defect is a `bug`.) TASKS is the one tracker with a **human producer** ("put this in
  the backlog") alongside agents.
- **Store:** `.records/trackers/tasks.md` — a single **flat living list**, not a store dir (no
  per-file frontmatter). One top-level header, one section per durable **domain / milestone group**
  (e.g. `Performance`, `Tooling / CI`, `Known limitations`); a fresh file seeds from `Loose ends` /
  `Adjacent improvements` / `Open questions` / `Future scope`.
- **Format:** plain `-` bullets, **no checkboxes** — an item is *open* while listed and simply
  **removed** on completion (`/backlog done` — the done-log line in `.records/done/log.md` is the archive).
  Per item: concrete description (with `file:line` where it applies) · **why** (one line) · **effort**
  `(S/M/L)` · trailing `· added YYYY-MM-DD`. Mark a genuine maybe `(unsure)` and say why.

### `issue` — a project problem / concern / limitation
- **What:** "something about the project is wrong, risky, or limited" that isn't a reproducible
  defect and isn't a build item — a known limitation, an architectural risk, a design concern, a gap.
- **Store:** `.records/trackers/issues.md` — a **flat log**, not a store dir (no per-file frontmatter).
- **Format:** entries grouped under category sections with a **category-prefixed running number** —
  `P#` (Problem / limitation) or `R#` (Risk / concern) — taking the next free number under that
  prefix, never renumbering existing entries. Each entry:
  - `### <prefix><n> — <short title> (<HIGH|MEDIUM|LOW>)` — the model owns the impact ranking.
  - **What's wrong** — the concrete problem/concern/limitation, with `file:line` / context.
  - **Impact** — who/what it affects, how badly.
  - **Suggested direction** — the change or investigation that would address it (a line or two).

  A durable *working-as-coded gotcha* discovered here is captured as a `/backlog note`; `/foreman`
  promotes it to `.agents/foreman/docs/GOTCHAS.md` during `calibrate`.

### `bug` — a reproducible code defect
- **What:** an observed, reproducible defect — crash, wrong render/output, dropped state, flaky
  behavior. If it turns out **working-as-coded but surprising**, it's not a bug: capture it as a
  `/backlog note` (`/foreman` promotes it to `.agents/foreman/docs/GOTCHAS.md` during `calibrate`) and file no
  report.
- **Store:** `.records/trackers/bugs/<YYYY-MM-DD>-<slug>.md`, from `templates/bug-report.md`. A
  **store dir** — carries frontmatter (see below). Load-bearing rule: **`bugs/` is a store, not a
  work queue** — a report is tracked from a **linked actionable item** (a `tasks.md` line, or an
  `issues.md` entry when it's a broader project problem), never fished out of `bugs/` for work. Fixed
  reports move to `.records/trackers/bugs/archive/`.
- **Format** (per the template): **Severity** (crash | wrong-output | dropped-state | flaky |
  cosmetic) and **flaky/transient?**; a **Repro** (a seed + scripted scenario, or exact commands +
  steps — a scripted repro the harness can replay is best); **Expected vs actual** with evidence (a
  log line, a captured artifact, a diagnostic reading); **Notes** (diagnosis so far, suspected
  `file:line`).

### `feedback` — a dev-experience observation
- **What:** the agent's voice on the development experience — reactions, frictions, praise, and
  directional ideas about the skills, scripts, tooling, and environment. The **single**
  dev-experience channel (observations that once split into `issue`s now all land here). Anything
  about the *project itself* goes to its project home; keep only the dev-experience residue here.
- **Store:** `.records/trackers/feedback.md` — a **flat list** of dated entries, no sections, not a
  store dir (no per-file frontmatter). Newest added at the bottom of the live region.
- **Format** (per `templates/feedback.md`): `### <short title> · YYYY-MM-DD` + a short body noting
  whether it's positive / a concern / a friction / a directional idea, and where it might lead if
  anywhere (a project item it should become, a doctrine change, or "just an observation").

## Store-dir frontmatter (`bugs/` and `notes/` only)

The two **file-per-item** stores are gated: the host's doc-linter (wired at `/foreman setup`, surfaced
in its `AGENTS.md`) walks each store dir and **fails the gate** on a file with missing or invalid
frontmatter. So every file in `bugs/` and `notes/` must start with its template's block — copy the
shape from `templates/bug-report.md` / `templates/note.md`.

```yaml
# bugs/<YYYY-MM-DD>-<slug>.md
---
type: bug
status: open          # open -> fixed / wontfix
updated: 2026-07-17   # YYYY-MM-DD (shape checked, not calendar-accurate)
---
```
```yaml
# notes/<slug>.md
---
type: note
status: evergreen
updated: 2026-07-17
related: [<the tracker entry this note backs>]   # omit the key if empty
---
```

The three **flat aggregators** — `tasks.md`, `issues.md`, `feedback.md` — hold their entries as
blocks inside one shared file, where per-file frontmatter can't sit; the doc-linter does **not** gate
them. Templates, and any `README.md` / `archive/` inside a store, carry no frontmatter either.

| Carries frontmatter — store dirs | Does NOT — flat aggregators / non-instances |
|---|---|
| `.records/trackers/bugs/`, `.records/trackers/notes/` | `.records/trackers/tasks.md`, `.records/trackers/issues.md`, `.records/trackers/feedback.md`, `templates/*`, a store's `README.md` / `archive/` |

Because coverage of the store dirs is total, the metadata is queryable:

```sh
rg -l '^status: open' .records/trackers/bugs/     # all open bug reports
rg -l '^type: note'   .records/trackers/notes/    # every note
```

## Draining is the consumer's job (this schema captures only)

`/backlog` **captures, never drains.** Each tracker's captured signal is worked *downstream*, not
here:

- **`issues`, `feedback`, and note-promotion** → `/foreman calibrate` (drains system-relevant signal into
  doctrine, routes project items to their home, promotes a durable note to a `MEMORY.md` invariant or
  a working-as-coded gotcha to `.agents/foreman/docs/GOTCHAS.md`).
- **`tasks`** → `/feature` / `/workstream` (turn a captured item into shipped work; the item is
  removed on ship).
- **a `bug`'s fix** → whoever works the linked actionable item (the `tasks.md` line or `issues.md`
  entry that points at the report).

Those consumers own their own procedures — this doc does not restate them.

## Pointer

This skill's bundled `templates/` is where you copy the shape from when capturing a new `bug` or
`note`; this doc is where you learn the taxonomy that shape belongs to. Reach the format from either
direction.
