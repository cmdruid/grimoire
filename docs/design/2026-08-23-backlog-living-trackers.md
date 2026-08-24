---
doctype: specs
status: published
created: 2026-08-23
updated: 2026-08-24
tags: [spec]
---

# Backlog living trackers — workspace TSV + debrief cookbook — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here. It doubles as the implementation plan.

Kinds (land first):
`docs/design/2026-08-23-workspace-kinds.md`. This spec **consumes**
those paths; it does not redefine the closed set.

Sibling:
`docs/design/2026-08-23-delegate-byproducts-hook.md` — publishes
`hooks/delegate/byproducts.md`. This spec only *reads* that file
when present (missing or empty → skip).

Settled 2026-08-23 in conversation (grill + split + workspace
kinds). Every branch below is resolved. Small-to-medium feature:
slices live in this file.

Lineage this amends, not replaces:
`docs/design/2026-08-18-backlog-tracker-scope.md` (backlog as tracker
lifecycle over three *record* trackers; `promote`; `task` / `issue` /
`feedback`). Phase 6
(`docs/design/2026-08-14-journal-backlog-split-design.md`) split
journal = format, backlog = follow-up workflow. This spec moves the
lists off the records layer and drops the taxonomy verbs.

## Problem

Trackers are living lists. They wear record clothes: a dated filename,
`doctype: trackers`, `status: draft` forever, identity by H1 title.
`history.tsv` never logged a checkbox flip (journal says line-items
are not records). The real log is git plus the dates already on each
line. `journal done` writeback, `records.sh list`, and analyst are
the only records-layer gifts, and they do not justify the costume.

The skill is also a closed taxonomy. `task` / `issue` / `feedback`
and a hardcoded debrief routing table encode three titles. Adding a
fourth tracker means editing the package. `promote` is a fourth verb
for a judgment (move a row between stems) the agent can perform with
list + file + complete. Debrief routing prose sitting on the list
file (or in the verb) pollutes every agent that is only filing or
curating.

Leaves name `/backlog task` / `/backlog issue` / `/backlog debrief`.
That glue belongs in the project (`hooks/<skill>/<seam>.md`, pack
seed), not in the leaves. Performing the work and *when* to debrief
are glue. They are not this skill.

## Goal

After this feature:

- Trackers are living lists at
  `<agent-workspace>/trackers/<stem>.tsv` (default
  `.dev/trackers/`). The staged CRUD script
  (`<agent-workspace>/scripts/backlog/trackers.sh`) is the only
  writer. Agents read `list` output, never the raw TSV.
- Debrief routing lives in one cookbook:
  `<agent-workspace>/hooks/backlog/debrief.md`. `compile` parses
  that file (H2 per stem). File / curate / list never open it.
- The skill is a tracker engine plus the debrief verb: `setup`,
  `tracker add|remove|list`, `file`, `debrief`, `curate`. No
  `task` / `issue` / `feedback` / `promote`. No bundled silent
  defaults. Builtin **suggestions** are `tasks`, `issues`,
  `feedback` (stem `tasks` replaces the old title `Backlog`).
- `/backlog setup` is a one-shot menu over those suggestions.
  Clankshop `setup` / `migrate` apply the three non-interactively
  through the same script when the member is installed.
- No standing adopt engine. Alpha: this skill does not read, write,
  convert, or delete `doctype: trackers` records. Organic brownfield
  lists are a **clankshop migrate** mapping-table row onto TSVs, not
  a backlog feature.
- Leaves never name `/backlog`. Only the pack face, seed
  `flows/bug.md`, and `hooks-glue` fills may. Capture language is
  “host’s follow-up lane” / “host’s bug-filing lane.”
- `/backlog debrief` follows the compiled modules. Zero modules →
  gather, file nothing, say so. Does not mint a `reports/` record.
  The sweep list is conversational. (Workstream’s optional ship-time
  report is out of this spec.)
- Delegate does not hard-code a byproducts taxonomy. The third return
  part is `hooks/delegate/byproducts.md` when that file is filled;
  missing or empty → skip. This spec does not publish that hook
  (sibling spec).
- Lint `fails=0`. Backlog and clankshop harnesses green.

## Approach

**Chosen: workspace kinds (`trackers/` + `hooks/backlog/debrief.md`),
staged `trackers.sh`, suggestion catalog, no taxonomy verbs, no
adopt, leaf independence.**

Lists and routing are different files so a non-debrief agent never
ingests routing prose. Verbs call the **staged** script. TSV is the
store, not the interface. Debrief *is* following the compiled
cookbook — not a second envelope policy for “unmatched” leftovers.

**Rejected: stay in `<agent-records>/trackers/` as records.** Dated
paths and draft-forever fail the two-roots test (records = dated,
typed, closeable instances). Line-item dates already live on the row.

**Rejected: markdown checklists as the store.** Agents rewrite
sentences and checkbox dialects. A script wants columns and a stable
`id`. Human GitHub readability of the raw file is secondary; `list`
is the view.

**Rejected: `hooks/debrief.md` (process-keyed, no skill stem).**
Parsers must not glob `hooks/`. Routing is
`hooks/backlog/debrief.md` (skill folder, known seam). Workstream
`hooks/workstream/feature-completion.md` remains *when* to run
`/backlog debrief`.

**Rejected: `<agent-workspace>/skills/<name>/` and
`<agent-workspace>/backlog/` as a skill-named island.** Package and
install already use `skills/`. Living lists are the kind `trackers/`.
Two-roots holds-column gains `trackers/`, not `backlog/`.

**Rejected: `debriefs/*.md` plus glob-compile.** One cookbook file,
script-spliced sections, is enough to guard and debug.

**Rejected: running `trackers.sh` from the package path only.**
Stage it at `scripts/backlog/trackers.sh` (workspace kinds: refresh
from package; executor sandbox).

**Rejected: keep `task` / `issue` / `feedback` / `promote`.** The
skill is extensible. Capture is `file <stem>`. Moving a row between
stems is list + file + complete, not a verb. Taxonomy is
pack/suggestion opinion, not skill law. Alpha: hard-cut, no aliases.

**Rejected: leftover prefixes in the debrief envelope.** Prefix
policy, if any, is routing prose inside a debrief module (bundled
with the three suggestions). A host that never applied those
suggestions never files those leads. Unmatched leftovers are ordinary
judgment against the compiled files, not a fourth envelope.

**Rejected: silent copy-on-first-use of the three.** A suggestion
catalog plus `/backlog setup` (and clankshop applying the three at
workshop birth) plants them only when chosen. Already-seeded
workshops are not planted by `check`; operators run `/backlog setup`.

**Rejected: optional `reports/` page from `/backlog debrief`.** Rows
on the TSVs are the durable follow-ups.

**Rejected: standing adopt engine** (`/backlog adopt`, `trackers.sh
adopt`, skip-if-any-row conversion). Alpha: hard-cut; this package
does not read, write, convert, or clean those files. Clankshop
migrate already converts organic lists — that row retargets onto
TSVs.

**Rejected: workstream (or any leaf) calling `complete` / `/backlog
file`.** Leaves stay prose. Ship does not complete TSV rows. Glue is
`<agent-workspace>/hooks/workstream/feature-completion.md`.

**Rejected: journal naming or crawling backlog.** Live journal has
zero `backlog` hits; this spec adds none. `done` writeback stays on
leftover record `## Items` lines. Workspace rows complete when
someone already running `curate` / `debrief` uses `complete --link`.

**Rejected: `/backlog debrief` on every `/delegate` return.** Wrong
grain. Persistence is the host close-the-books sweep. Delegate’s
byproducts *definition* is a project hook (sibling spec).

## Mechanism

### Homes

Resolve `<agent-workspace>` from the door (first line-start
`agent-workspace:` in `AGENTS.md` then `CLAUDE.md`, else `.dev`).
Scripts take `--root` and `--workspace`; they do not scan the door.

```
<root>/<agent-workspace>/trackers/<stem>.tsv
<root>/<agent-workspace>/hooks/backlog/debrief.md
<root>/<agent-workspace>/scripts/backlog/trackers.sh
```

**Narrow mkdir** (workspace kinds): mkdir `trackers/` and
`hooks/backlog/` only when (a) `<root>/<agent-workspace>` already
exists, or (b) the home is the derived default `.dev` and the mkdir
is that kind only (creates `.dev` as a container, never
`doctrine/`). Declared `agent-workspace:` that is absent →
`reason=no-home`, write nothing.

Missing `debrief.md` → compile yields zero sinks (exit 0). A `##
<stem>` section whose TSV is missing → compile fail (exit 1). A TSV
with no section is legal (list exists; the sweep does not fill it).

Stage `trackers.sh` from the package on first need (workspace
refresh policy). Verbs run the **staged** path with `--root` /
`--workspace`. Do not run the package copy against a host project.

No front-door `skill:` registration.

### TSV schema

Header required, tab-separated:

```
id	status	created	text	link	completed
```

Optional comment immediately after the header:

```
# highwater=<n>
```

The script writes and updates that line. Lines starting with `#` are
not data rows. If the comment is missing, high-water is the max
integer suffix among existing data rows (files that predate the
comment). Every write (including `drop`) materializes
`# highwater=<max(existing-comment-or-max-suffix, this-op’s n)>`
**before** rewriting data rows. `drop` still does not decrease
high-water.

| column | rule |
|---|---|
| `id` | `<stem>-<n>` minted by the script (`tasks-1`, `tasks-2`, …). Next `n` is high-water + 1. High-water includes `done` and **dropped** ids. Never reuse. |
| `status` | `open` \| `done` |
| `created` | ISO `YYYY-MM-DD` |
| `text` | one sentence. Tab or newline → script refuses. |
| `link` | empty, or a records-root-relative path (`bugs/2026-08-01-foo.md`). No `→` prefix. |
| `completed` | empty while `open`; ISO date when `done`. |

File order is display order (newest last on `add`). `curate` may
`reorder`. Default `list` is `status=open`, same columns. Verbs never
`read_file` the TSV. Skill prose: never hand-edit the TSV (same rule
as `history.tsv`).

### Scripts (facts + mechanical writes)

Package source: `skills/backlog/scripts/trackers.sh`. Invoked path:
`<agent-workspace>/scripts/backlog/trackers.sh` (materialize first).
Subcommands (stable argv for approval allowlists). Stderr tokens
`reason=<token>`. `--root` and `--workspace` on every write.

| subcommand | does | exit |
|---|---|---|
| `list --tracker <stem> [--status open\|done\|all] [--link <rel>]` | print data rows, default `--status open` | 0; missing stem → `reason=no-tracker`, 1 |
| `list` (no `--tracker`) | one line per stem: stem, open count, debrief present/absent | 0 |
| `add --tracker <stem> --text <s> [--link <rel>] [--created YYYY-MM-DD]` | append `open` row; print `id=<id>` | 0; tab/newline in text → 2; no-home → `reason=no-home`, 1; missing stem → `reason=no-tracker`, 1 |
| `update <id> [--text <s>] [--link <rel>]` | rewrite fields | 0; unknown id → 1 |
| `complete <id>` | `done` + today’s date | 0; unknown id → 1 |
| `complete --link <rel> [--tracker <stem>]` | complete matching `open` rows (all stems if no `--tracker`) | 0 |
| `drop <id>` | delete the data row; materialize high-water as above (never decreases) | 0; unknown id → 1 |
| `reorder --tracker <stem> --ids <id,id,…>` | rewrite file order | 0; list is not a permutation of **all** ids in the file → 2 |
| `compile` | parse `hooks/backlog/debrief.md` (structural H2 = stem); stem-sort; emit the debrief prompt | 0 if file missing / no H2s; 1 if a section’s TSV is missing |
| `setup --list` | print builtin suggestion ids + `title` / `use-when` | 0 |
| `setup --apply <stems…>` | for each stem: TSV **or** matching H2 in `debrief.md` exists → skip (incumbent). Else splice bundled suggestion as `## <stem>` + write TSV header + `# highwater=0`. Stem not in the catalog → refuse (`reason=unknown-stem`); that is `tracker-add` | 0 or 2 |
| `tracker-add <stem>` | builtin suggestion stem → same as `--apply` (copy payload into the cookbook). Else TSV header + stub `## <stem>` section. Both present → `reason=incumbent`, refuse | 0 or 2 |
| `tracker-remove <stem>` | `open > 0` → print count, `reason=open-rows`, exit 2. Else delete TSV and splice the H2 out of `debrief.md` | 0 or 2 |

`compile` output, one block per stem (lexicographic). No absolute TSV
path (agents must not `read_file` the TSV):

```
stem=<stem>
title=<title>
use_when=<use-when>
---
<body of the ## <stem> section after its front-matter / heading>
```

Blocks separated by a line that is only `===`. The debriefing agent
follows this prompt and calls `add` / `complete` with `--tracker
<stem>`. It does not open the debrief source files if compile already
printed them.

### Debrief module format

```markdown
---
title: Tasks
use-when: a leftover is a thing to build
---

# Tasks

<routing prose the debriefing agent follows>
```

Crawl keys `title` / `use-when` match shopbook. Body is the routing.
Compile fails a section with missing front-matter or empty `title`.
Stem = H2 text = TSV stem. No `tracker:` key. The cookbook file may
carry a chrome H1; structural H2s are stems. Duplicate H2 → compile
fail (exit 2).

Package payload (not lock-in templates, not copied until `--apply` or
`tracker-add` of a catalog stem):

`skills/backlog/suggestions/{tasks,issues,feedback}.md`

Suggested routing (pack/suggestion opinion, editable after apply):

- **tasks** — a leftover that is a thing to build. Leftover
  `file repro:` / `write down:` leads, if the host wants them, live
  in this body (shipped in the bundled suggestion).
- **issues** — a project concern / limitation; leftover
  `needs human:` if the host wants it.
- **feedback** — a dev-experience observation.

Those sentences are **not** skill envelope law.

### Verb dispatch

Thin router. When a verb is selected, read `verbs/<verb>.md`.

| Invocation | Does | Trigger |
|---|---|---|
| `/backlog setup` | Menu: print `--list`, ask which suggestions (and any custom stems via `tracker add`), then `--apply`. Non-interactive stems on the invocation skip the ask. | “stand up trackers”, first-run |
| `/backlog tracker add <stem>` | Script `tracker-add`; caller fills a stub routing body (shopbook-create shape) when the stem was not a catalog copy. | “add a Research tracker” |
| `/backlog tracker remove <stem>` | Script `tracker-remove`; refuse while `open > 0`. | “drop the feedback tracker” |
| `/backlog tracker list` | Script `list` with no `--tracker`. | “what trackers do we have” |
| `/backlog file <stem> <text> [--link <rel>]` | Stem required and must exist; else print `tracker list` and **ask**. Script `add`. | “file this”, “put this on Research”, “capture a follow-up” |
| `/backlog debrief` | Envelope: gather (status, merge-base diff, conversation) → `compile` → route write-only via `add` / `complete` / `complete --link` per compiled blocks → one scoped commit → conversational sweep list. Zero modules → gather, file nothing, say so. Does not mint `reports/`. Does not invent unmatched-sink policy beyond the compiled files. | “wrap up before I reset”, “capture what surfaced” |
| `/backlog curate` | Walk `list --status all` (and `list` with no `--tracker` for the catalog): dedupe, `update` to sharpen `text`, `reorder`, `complete` finished rows, `complete --link` where the linked record is `archived`, `drop` noise. Hygiene, never a drain between stems. | “tidy the trackers” |
| unknown / bare `/backlog` | **ask** which of setup / tracker / file / debrief / curate. No default stem. | |

Deleted: `skills/backlog/verbs/task.md`, `issue.md`, `feedback.md`,
`promote.md`, `skills/backlog/templates/trackers.md`,
`skills/backlog/scripts/record-mint.sh` (no record writer remains
on this package). `skills/backlog/scripts/scoped-commit.sh` stays.
`## Project templates` is none.

**Capture-commit policy** unchanged: standalone `file` / `tracker` /
`setup --apply` makes its own scoped commit; inside `debrief` only
writes — the sweep commits once. Commit-tree probe unchanged
(workstream / in-place / trunk; never `stream/*` from a session that
does not hold it). `skills/backlog/scripts/scoped-commit.sh`. No
`Co-Authored-By`.

Description (routing surface): tracker engine + debrief; file /
setup / curate / debrief; no sibling names; no `task` / `issue` /
`feedback` / `promote`; no “three trackers.” Retired verbs are
un-backticked refuse prose (absence grep must stay clean).

```
<!-- edges:backlog -->
- produces: — (TSV rows are not records)
- handoff: — (none; moving a row is list + file + complete)
- consumes: — (debrief/curate/file read `list` output, not records)
<!-- /edges:backlog -->
```

### `/backlog setup`

Not a multi-step human-dashboard wizard. One menu:

1. `setup --list` (facts).
2. Ask which of `tasks` / `issues` / `feedback` to enable; also offer
   custom stems (those run `tracker add`, then the caller authors
   routing).
3. `setup --apply` the chosen suggestion stems. Incumbent wins.

Re-run is safe. `--apply` with no prior ask is the non-interactive
path (clankshop). No adopt step.

### Clankshop

When the backlog member is installed, `setup` and `migrate` gain a
numbered step **after hooks**. Live today (`skills/clankshop/verbs/setup.md`):
walk 5 = Hooks, 6 = Validate (`check`). After this feature: 5 = Hooks,
6 = apply suggestions, 7 = Validate. Guard resume `(1–6)` becomes
`(1–7)`, including already-seeded / resume arms. Harnesses that pin
`(1–6)` (`hooks-fill-test.sh`, `flows-copy-test.sh`) retarget.

**Do not renumber `check.md`.** That walk is already 1–9 (hooks is
step 6). The only `check.md` edit is one sentence: do not report
missing default stems. Unfinished is not “the three are absent.”
Already-seeded STOP does not plant stems.

The apply step runs
`trackers.sh setup --apply tasks issues feedback` with `--root` /
`--workspace`. It does not copy files itself. Incumbent wins per
stem. Presence of the backlog skill package (sibling of the face,
same as hooks fill finding the workstream skeleton) gates the step;
missing member → noop.

Migrate mapping table, live
`skills/clankshop/verbs/migrate.md:58–64`: **hand-rolled
TODO/backlog/issues lists → `trackers` records** becomes →
`setup --apply` the matching suggestion stem (Backlog → `tasks`,
Issues → `issues`, Feedback → `feedback`) + `add` for open lines.
Do not mint `doctype: trackers`. Dated tracker records already in
the tree are not this walk; do not convert or delete them.

PACK.md: roster blurb = tracker engine + debrief, no “three
trackers” / promote. No `version:` bump in **this** spec (member set
unchanged here; workspace skill’s spec bumps when that member
joins). Seam note: face step 6 applies suggestions through
backlog’s **staged** script; leaves do not name each other.
Workstream / backlog seam (fill
`hooks/workstream/feature-completion.md` with `/backlog debrief`)
unchanged in *content*; the path is the folder shape from the
workspace spec. Notes commit pathspec adds
`<agent-workspace>/trackers/` and `hooks/backlog/`.

Two-roots holds-column is the workspace spec’s edit (`trackers/`,
`hooks/` as directories, `scripts/<skill>/`). This spec does not
add `backlog/`.

### Journal

This feature does not edit journal. Live `skills/journal/` contains
zero `backlog` hits; do not add any. `done` writeback stays on
leftover record `## Items` lines and does not gain a workspace crawl.

### Consumers (same feature — otherwise the hole moves)

Leaves stay on the generic **host’s follow-up lane**. They do not
name `/backlog`. Only pack seed / `flows/bug.md` / `hooks-glue` fills
may name `/backlog file` or `/backlog debrief`, and only after those
verbs exist.

Hard-cut: no aliases for deleted verbs. Intermediate HEAD between S2
and S3 may dangle; alpha accepts that. S3 still retargets so the
feature as a whole does not.

| Site | Change |
|---|---|
| `workstream` Scope, `verbs/create.md` GUARD, `verbs/sync.md` | Feature-work / issue capture → host’s follow-up lane / host’s bug-filing lane. Purge `/backlog task` and `/backlog issue`. |
| `workstream` `SKILL.md` Host layout | Delete **only** the stamp bullet that permits Backlog tracker lines, and the “Do not mint a Backlog tracker / tracker-line completion” sentences. Stamp is no longer a workstream follow-up probe. Do not mint a tasks TSV. Do not rewrite the `$HOOKS` / `$HOOKS_DIR` paragraph (workspace-kinds S3). |
| `workstream` `verbs/ship.md` | Delete “complete the queue item’s tracker line.” Ship is plan close / hand-off / the project’s own layout. Do not call `complete` / `--link`. |
| `workstream` `templates/design.md` | English “roadmap/backlog” stays (not the skill). |
| `skills/workstream/scripts/tests/hooks-test.sh` | Fixtures that plant `/backlog debrief` as a **filled glue body** stay (they test compile, not a leaf pointer). |
| `delegate` `SKILL.md` | Delete the kinds enum and the `/backlog debrief` drain sentence. Third return part: follow `hooks/delegate/byproducts.md` when filled; missing or empty → skip. Do **not** add that file (sibling spec). |
| `clankshop/flows/bug.md` | Later tracker entry is `/backlog file tasks` (seed may name the verb). File-and-link stays split. |
| `clankshop/seed/core/ROUTING.md` | Keep pack opinion (`needs human:` as a debrief remainder) **or** say “compiled debrief modules.” Do not put `/backlog` in a leaf. |
| `skills-lint.sh` BL-1 comment | Cite `/backlog file` and `/backlog debrief` only (`skills-lint.sh` ~409). |
| `PACK.md` | Blurb + seam as above. |
| `README.md` inventory row | Tracker engine + debrief, no “three trackers” / promote. |
| `setup-journal-test.sh` | Stop minting via `$BACKLOG/templates/trackers.md` (that file is deleted in S2). Retarget at another bundled doctype template or an in-test fixture. |

`feat` / `app` streams are not this change.

Allowed composers of backticked `/backlog …` under `skills/` after
the last slice: this spec; historical `docs/design/`; pack face
(`PACK.md`, setup/migrate, `hooks-glue.sh`); seed `flows/bug.md`;
workstream **test fixtures** that plant a glue *body*; un-backticked
refuse prose that does not contain those tokens.

### Independence

- Description names no sibling and no retired verb (un-backticked
  refuse only).
- Procedures do not invoke debugger, notepad, or journal.
- Leaves say “host’s follow-up lane” / “host’s bug-filing lane.”
- Face may name `/backlog setup`, `/backlog debrief`, `/backlog
  file`.

### Out of scope

- `/backlog next` / performing the work.
- `unhook` (remove debrief module, keep TSV) — remove deletes both
  when empty.
- General `<agent-workspace>/skills/<name>/` namespace.
- Analyst crawling workspace TSVs (analyst stays on records).
- Item-level ledger besides git.
- Standing adopt / conversion of dated tracker records.
- Publishing `hooks/delegate/byproducts.md` (sibling spec).
- Defining workspace kinds / the `workspace` skill (sibling spec).
- Shared skill-builder hooks parser.
- `/backlog debrief` on each `/delegate` return.
- Renumbering `check.md`’s 1–9 walk.
- Running package scripts against a host tree (stage first).

## Verification

**Mechanical**

- New `skills/backlog/scripts/tests/` for the script: header mint,
  `add` / `update` / `complete` / `complete --link` / `drop` /
  refuse tab in `text`, high-water after drop of the max id
  (including a missing-comment file: drop the max id, next `add`
  does not reuse `n`),
  `reorder` partial list refuses, `setup --apply` incumbent skip,
  `tracker-add tasks` copies the suggestion (not a stub),
  `tracker-remove` exit 2 when `open > 0`, compile stem-sort +
  `stem=` only + fail on missing TSV, compile zero sinks when
  `debrief.md` is missing. Prove-by-breaking. Stage path:
  fixture workspace `scripts/backlog/trackers.sh` is what the
  verb runs.
- `skills/backlog/scripts/tests/run.sh` green. S1 wires `run.sh` to
  the new script tests (live harness only runs
  `record-mint-test.sh`). S2 drops the `record-mint-test.sh` line
  with the minter.
- `skills/clankshop/scripts/tests/` Guard 1–7 + step-6 apply on a
  fixture with backlog present (three TSVs + three modules,
  incumbent skip) and with backlog absent (noop). Existing hooks /
  flows tests stay green after `(1–6)` → `(1–7)` retarget.
- `setup-journal-test.sh` does not mention
  `backlog/templates/trackers.md`.
- `skills/skill-builder/scripts/skills-lint.sh` clean for `backlog`.

**Absence** (population = this library’s `skills/` trees)

After the last slice, zero hits under `skills/` for:

- `/backlog task`
- `/backlog issue`
- `/backlog feedback`
- `/backlog promote`

Allowed remnants: as Consumers *Allowed composers*. Lint comments are
**not** allowed remnants.

Also zero `/backlog` under `skills/workstream/` excluding
`scripts/tests/**`, and zero `/backlog` in `skills/delegate/SKILL.md`.

Red-proof the sweep: plant `/backlog task` under `skills/`, demand
the grep fails, remove the plant.

**Procedure**

- `file`: unknown stem asks and writes nothing; known stem appends
  one row (optional `--link`) and scoped-commits when standalone.
- `debrief`: compile two modules, route one leftover to each TSV,
  one commit; a host with no `debrief.md` reports zero sinks and
  mints no taxonomy and no `reports/` record.
- `setup --apply tasks`: creates `trackers/tasks.tsv` + a `## tasks`
  section in `hooks/backlog/debrief.md` from the suggestion; second
  apply is a no-op.
- Delegate: missing `hooks/delegate/byproducts.md` → skip the
  byproducts overlay (no kinds list, no `/backlog debrief`).
- No adopt fixture.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | Script: schema, high-water, CRUD, compile `stem=`, setup --list/--apply, tracker-add/remove (catalog copy vs stub), tests; wire `scripts/tests/run.sh` to the new suite | `skills/backlog/scripts/tests/run.sh` | `skills/backlog/scripts/**`, `skills/backlog/suggestions/**` |
| S2 | Router + verbs; drop task/issue/feedback/promote; SKILL.md description/edges; delete `templates/trackers.md` and `record-mint.sh`; retarget `setup-journal-test.sh` | lint `backlog`; absence of dropped verb files and minter | `skills/backlog/SKILL.md`, `skills/backlog/verbs/**`, `skills/backlog/templates/trackers.md`, `skills/backlog/scripts/record-mint.sh`, `skills/backlog/scripts/tests/record-mint-test.sh`, `skills/clankshop/scripts/tests/setup-journal-test.sh` |
| S3 | Consumers: workstream purge + stamp bullet + ship; delegate kinds/`/backlog debrief` → skip-if-empty `hooks/delegate/byproducts.md`; seed `bug.md`; lint BL-1; PACK blurb; README; ROUTING if needed | absence grep + red-proof | `skills/workstream/SKILL.md`, `skills/workstream/verbs/**`, `skills/delegate/SKILL.md`, `skills/clankshop/flows/bug.md`, `skills/clankshop/PACK.md`, `skills/clankshop/seed/core/ROUTING.md`, `skills/skill-builder/scripts/skills-lint.sh`, `README.md` |
| S4 | Clankshop setup/migrate step 6 apply; validate = 7; Guard 1–7; migrate maps lists to TSV; check.md one sentence; retarget `(1–6)` expects | clankshop harness | `skills/clankshop/verbs/setup.md`, `skills/clankshop/verbs/migrate.md`, `skills/clankshop/verbs/check.md`, `skills/clankshop/scripts/tests/**` |

Land order S1 → S2 → S3 → S4. S1 is independently testable. S3 names
`/backlog file tasks` in seed only after S2. S4 plants defaults only
after S1. Hard-cut: no aliases; S2 may leave consumer strings dangling
until S3.

## Review history

Split 2026-08-23 from a `needs-rework` draft that also specified
delegate-as-hooks-publisher. That half is the sibling spec. This file
has not been re-reviewed since the split. Caller publishes after a
passing host review they accept.
