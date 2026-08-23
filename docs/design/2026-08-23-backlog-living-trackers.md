---
doctype: specs
status: draft
created: 2026-08-23
updated: 2026-08-23
tags: [spec]
---

# Backlog living trackers — workspace TSV + debrief modules — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here. It doubles as the implementation plan.

Settled 2026-08-23 in conversation (grill rounds 1–3; Q8 the same
day). Every branch below is resolved. Small-to-medium feature: slices
live in this file.

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
fourth tracker means editing the package. `promote` is an opinionated
drain the agent can already perform with list + file + complete.
Debrief routing prose sitting on the list file (or in the verb)
pollutes every agent that is only filing or curating.

INV-11 still wants every capture surface to have a drain. Performing
the work, leftover host-lane composition, and *when* to debrief are
glue (`hooks/workstream.md`, pack flows). They are not this skill.

## Goal

After this feature:

- Trackers are living lists at
  `<agent-workspace>/backlog/trackers/<stem>.tsv` (default
  `.dev/backlog/trackers/`). A CRUD script is the only writer. Agents
  read `list` output, never the raw TSV.
- Debrief routing lives in
  `<agent-workspace>/backlog/debriefs/<stem>.md`. Compile concatenates
  those files into the prompt the debriefing agent follows. File /
  curate / list never open `debriefs/`.
- The skill is a tracker engine plus the debrief hook: `setup`,
  `tracker add|remove|list`, `file`, `debrief`, `curate`. No
  `task` / `issue` / `feedback` / `promote`. No bundled silent
  defaults. Builtin **suggestions** are `tasks`, `issues`,
  `feedback` (stem `tasks` replaces the old title `Backlog`).
- `/backlog setup` is a one-shot menu over those suggestions.
  Clankshop `setup` / `migrate` apply the three non-interactively
  through the same script when the member is installed.
- Incumbent dated tracker records are adopted into TSVs and archived.
- Leaves say “host’s follow-up lane.” Pack seed may name
  `/backlog file tasks`. Journal does not crawl the workspace.
- `/backlog debrief` does not mint a `reports/` record. The sweep
  list is conversational. (Workstream’s own optional ship-time
  report is out of this spec.)
- Lint `fails=0`. Backlog and clankshop harnesses green.

## Approach

**Chosen: workspace durable home, two sibling dirs, script-owned TSV,
compile-from-debriefs, suggestion catalog, no taxonomy verbs.**

Backlog owns `<agent-workspace>/backlog/` (narrow mkdir, incumbent
wins). Lists and routing are different files so a non-debrief agent
never ingests routing prose. The agent-facing interface is verbs that
call scripts (`list` / `add` / `complete` / `drop` / `reorder` /
`compile` / `setup --apply`). TSV is the store, not the interface.

**Rejected: stay in `<agent-records>/trackers/` as records.** Dated
paths and draft-forever fail the two-roots test (records = dated,
typed, closeable instances). Line-item dates already live on the row.

**Rejected: markdown checklists as the store.** Agents rewrite
sentences and checkbox dialects. A script wants columns and a stable
`id`. Human GitHub readability of the raw file is secondary; `list`
is the view.

**Rejected: `hooks/debrief.md` as the sink table.** Process-keyed
hooks collide with workstream’s skill-keyed empty-H2 overlay.
Parsers must not glob `hooks/`. A per-skill `debriefs/` directory is
the sink table without stretching that convention. Workstream
`hooks/workstream.md` remains *when* to run `/backlog debrief`.

**Rejected: `<agent-workspace>/skills/backlog/…`.** Collides with the
library tree, the install home, and “read the backlog skill.” INV-13:
do not extract a general `skills/` workspace namespace at the first
consumer. Skill-named home `<agent-workspace>/backlog/` matches
`hooks/<skill>.md` and `templates/<skill>/`.

**Rejected: keep `task` / `issue` / `feedback` / `promote`.** The
skill is extensible. Capture is `file <stem>`. Moving a row between
stems is list + file + complete. Taxonomy is pack/suggestion
opinion, not skill law.

**Rejected: leftover prefixes in the debrief envelope.** Prefix
policy, if any, is routing prose inside a debrief module (bundled
with the three suggestions). A host that never applied those
suggestions never files those leads.

**Rejected: silent copy-on-first-use of the three.** A suggestion
catalog plus `/backlog setup` (and clankshop applying the three at
workshop birth) plants them only when chosen.

**Rejected: optional `reports/` page from `/backlog debrief`.** A
second artifact on every wrap-up (or a judgment of “does this unit
warrant narrative?”) is work the cycle does not need. Rows on the
TSVs are the durable follow-ups. Workstream may still mint its own
ship-time `reports/` record; that is not this verb.

## Mechanism

### Homes

Resolve `<agent-workspace>` from the door (first line-start
`agent-workspace:` in `AGENTS.md` then `CLAUDE.md`, else `.dev`).
Scripts take `--root` and `--workspace`; they do not scan the door.

```
<root>/<agent-workspace>/backlog/trackers/<stem>.tsv
<root>/<agent-workspace>/backlog/debriefs/<stem>.md
```

**Narrow mkdir** (same predicate as hooks / flows): mkdir `backlog/`
only when (a) `<root>/<agent-workspace>` already exists, or (b) the
home is the derived default `.dev` and the mkdir is `backlog/` only
(creates `.dev` as a container, never `doctrine/`). Declared
`agent-workspace:` that is absent → `reason=no-home`, write nothing.
Then mkdir `trackers/` and `debriefs/` inside `backlog/`.

Missing `debriefs/` → compile yields zero sinks (exit 0). A debrief
module whose matching TSV is missing → compile fail (exit 1). A TSV
with no debrief module is legal (list exists; the sweep does not fill
it).

No front-door `skill:` registration (workshop door is a pointer).
Durable home is the workspace tree.

### TSV schema

Header required, tab-separated:

```
id	status	created	text	link	completed
```

| column | rule |
|---|---|
| `id` | `<stem>-<n>` minted by the script, monotonic per file, never reused (`tasks-1`, `tasks-2`, …). Next `n` is max existing integer suffix + 1, including `done` rows. |
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

Resolve from this skill’s own base directory. One program, subcommands
(stable argv for approval allowlists). Names in this spec; the
implementation may be one `trackers.sh` with subcommands:

| subcommand | does |
|---|---|
| `list` | print rows (`--tracker <stem>`, `--status open\|done\|all`, `--link <rel>`). Default open. |
| `add` | append an `open` row; print the new `id`. |
| `complete <id>` | set `done` + today’s date. `--link <rel>` completes matching `open` rows. |
| `drop <id>` | delete the row (hygiene, not the completed form). |
| `reorder` | rewrite file order from a given id list. |
| `compile` | glob `debriefs/*.md` (non-recursive), stem-sort, emit the debrief prompt. |
| `setup --list` | print builtin suggestion ids + `title` / `use-when` from package payload. |
| `setup --apply <stems…>` | for each stem: if TSV or debrief file exists, skip (incumbent). Else copy bundled debrief module + write TSV header. Custom stem not in the catalog → refuse here; that is `tracker add`. |
| `tracker-add <stem>` | create empty TSV (header) + debrief stub if both absent. Incumbent → refuse. |
| `tracker-remove <stem>` | if `open > 0`, print count and exit 2. Else delete TSV and debrief file if present. |

`compile` output, one block per stem (lexicographic), no raw TSV:

```
stem=<stem>
title=<title>
use_when=<use-when>
tracker=<absolute path to tsv>
---
<body of debriefs/<stem>.md after front-matter>
```

Blocks separated by a line that is only `===`. The debriefing agent
follows this prompt and calls `add` / `complete` with the named
`tracker` path (or `--tracker <stem>`). It does not open the debrief
source files if compile already printed them.

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
Compile fails a file with missing front-matter or empty `title`.
Stem = filename stem = TSV stem. No `tracker:` key; the path is
derived.

Package payload (not lock-in templates, not copied until `--apply` or
`tracker add` from a suggestion):

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
| `/backlog tracker add <stem>` | Script `tracker-add`; caller fills the stub routing body (shopbook-create shape). | “add a Research tracker” |
| `/backlog tracker remove <stem>` | Script `tracker-remove`; refuse while `open > 0`. | “drop the feedback tracker” |
| `/backlog tracker list` | Script `list` per stem + which debrief modules exist + open counts. | “what trackers do we have” |
| `/backlog file <stem> <text>` | Stem required and must exist; else print `tracker list` and **ask**. Script `add`. | “file this”, “put this on Research”, “capture a follow-up” |
| `/backlog debrief` | Envelope: gather (status, merge-base diff, conversation) → `compile` → route write-only via `add` / `complete` per compiled blocks → close completed linked rows (`complete --link` for archived records this work finished) → one scoped commit → conversational sweep list. Zero sinks → gather, route nothing, say that. Does not mint `reports/`. Does not invoke `promote` (gone). | “wrap up before I reset”, “capture what surfaced” |
| `/backlog curate` | Walk every TSV (`list --status all`): dedupe, sharpen `text`, reorder, `complete` finished rows, `complete --link` where the linked record is `archived`, `drop` noise. Hygiene, never a drain between stems. | “tidy the trackers” |
| unknown / bare `/backlog` | **ask** which of setup / tracker / file / debrief / curate. No default stem. | |

Deleted: `verbs/task.md`, `issue.md`, `feedback.md`, `promote.md`,
`templates/trackers.md`, `scripts/record-mint.sh` (no record writer
remains on this package; adopt uses deployed `records.sh done` or
file-mode `archived`). `scripts/scoped-commit.sh` stays.
`## Project templates` is none.

**Capture-commit policy** unchanged: standalone `file` / `tracker` /
`setup --apply` makes its own scoped commit; inside `debrief` only
writes — the sweep commits once. Commit-tree probe unchanged
(workstream / in-place / trunk; never `stream/*` from a session that
does not hold it). `scripts/scoped-commit.sh`. No `Co-Authored-By`.

Description (routing surface): tracker engine + debrief hook; file /
setup / curate / debrief; no sibling names; no `task` / `issue` /
`feedback` / `promote`; no “three trackers.” Retired verbs are
un-backticked refuse prose (absence grep must stay clean).

### `/backlog setup`

Not a multi-step human-dashboard wizard. One menu:

1. `setup --list` (facts).
2. Ask which of `tasks` / `issues` / `feedback` to enable; also offer
   custom stems (those run `tracker add`, then the caller authors
   routing).
3. `setup --apply` the chosen suggestion stems. Incumbent wins.

Re-run is safe. `--apply` with no prior ask is the non-interactive
path (clankshop).

### Clankshop

When the backlog member is installed, `setup` and `migrate` gain a
numbered step **after hooks** (hooks stay step 5; this is step 6;
`check` becomes 7). Guard ranges that today say 1–6 become 1–7,
including already-seeded / resume arms.

The step runs the backlog script
`setup --apply tasks issues feedback` with `--root` / `--workspace`.
It does not copy files itself. Incumbent wins per stem. Presence of
the backlog skill package (sibling of the face, same as hooks fill
finding the workstream skeleton) gates the step; missing member →
noop.

`check` does **not** report missing default stems (a host may have
declined or replaced them). Unfinished is not “the three are
absent.”

PACK.md: roster blurb = tracker engine + debrief hook, no “three
trackers” / promote. No `version:` bump (member set unchanged). Seam
note: face step 6 applies suggestions through backlog’s script;
leaves do not name each other. Workstream / backlog seam (hooks fill
`/backlog debrief`) unchanged.

### Adopt (this spec)

Walk live records with `doctype: trackers` (title match among live
files; `records.sh list --type trackers` when the tool exists).

H1 title map (case-insensitive exact): `Backlog` → `tasks`, `Issues`
→ `issues`, `Feedback` → `feedback`. Any other title → slug of the
title (lowercase, non-alphanumeric runs to `-`, trim).

For each record: if the destination TSV already has **any** row,
skip that record (idempotent; do not duplicate). Else
`setup --apply` the stem when it is a builtin (so the debrief
module exists), or `tracker-add` for other slugs; copy **open**
checkbox lines into `add` (`created` from the line’s leading date,
`text` from the sentence, `link` from `→ <rel>` if present, strip
the arrow). Do not copy completed lines (the archived record + git
remain the trace). Then `records.sh done <record> --as consumed
--note "adopted into backlog/trackers/<stem>.tsv"` when the tool
exists; else file-mode `archived`. One scoped commit per host walk,
or one commit for the whole adopt — implementation picks one; the
spec requires pathspec-atomic, not `git add -A`.

### Journal

Journal does not crawl `<agent-workspace>`. After adopt, live
`doctype: trackers` records should be gone; `done` writeback of
markdown `## Items` lines becomes a no-op on an empty set.

Rewrite journal’s contract bullet “micro-items are tracker lines”
so it does not claim workspace TSVs: micro-items of the follow-up
lifecycle are the follow-up client’s living lists; the markdown
line form is leftover teaching syntax for any un-adopted record
still in the tree. `done` writeback keeps scanning **records** for
that leftover form until none remain; it does not gain a workspace
crawl and does not name `/backlog`.

Closing a linked bug/note/plan still rewrites leftover
record-bodied tracker lines. Workspace rows complete when
`curate` / debrief run `complete --link <rel>`.

### Consumers (same feature — otherwise the hole moves)

Leaves stay on the generic **host’s follow-up lane**. They do not
name `/backlog file`. Only pack seed / ROUTING / `flows/bug.md`
may name `/backlog file tasks`, and only after that verb exists.

| Site | Change |
|---|---|
| `workstream` Scope, `verbs/create.md` GUARD, `verbs/sync.md` | Feature-work / issue capture → host’s follow-up lane, not `/backlog task` / `/backlog issue`. Stamp still a **policy** probe: may write follow-up rows only when stamped **and** the destination TSV already exists. Do not mint a `tasks` tracker. |
| `workstream` `verbs/ship.md` | “Complete the queue item’s tracker line” → `complete <id>` (or `--link`) when the TSV exists; else plan close / hand-off / the project’s own layout. |
| `clankshop/flows/bug.md` | Later tracker entry is `/backlog file tasks` (seed may name the verb). File-and-link stays split. |
| `skills-lint.sh` BL-1 comment | Cite `/backlog file` and `/backlog debrief` only. |
| `PACK.md` | Blurb + seam as above. |
| `README.md` inventory row | Tracker engine + debrief, no “three trackers” / promote. |

`feat` / `app` streams are not this change.

### Independence

- Description names no sibling and no retired verb (un-backticked
  refuse only).
- Procedures do not invoke debugger, notepad, or journal except
  opportunistic `records.sh` for adopt/`done` of the old tracker
  record.
- Leaves say “host’s follow-up lane” / “host’s bug-filing lane.”
- Face may name `/backlog setup` and `/backlog debrief` (pack
  faces may name members).

### Out of scope

- `/backlog next` / performing the work.
- `unhook` (remove debrief module, keep TSV) — remove deletes both
  when empty.
- General `<agent-workspace>/skills/<name>/` namespace.
- Analyst crawling workspace TSVs (analyst stays on records).
- Item-level ledger besides git.

## Verification

**Mechanical**

- New `skills/backlog/scripts/tests/` for the script: header mint,
  `add` / `complete` / `complete --link` / `drop` / refuse tab in
  `text`, id monotonic including across `done` rows, `setup --apply`
  incumbent skip, `tracker-remove` exit 2 when `open > 0`, compile
  stem-sort + fail on missing TSV, compile zero sinks when dir
  missing. Prove-by-breaking.
- `skills/backlog/scripts/tests/run.sh` green. Delete
  `record-mint-test.sh` with the minter.
- `skills/clankshop/scripts/tests/` Guard 1–7 + step-6 apply on a
  fixture with backlog present (three TSVs + three modules,
  incumbent skip) and with backlog absent (noop). Existing hooks /
  flows tests stay green.
- `skills/skill-builder/scripts/skills-lint.sh` clean for `backlog`.

**Absence** (population = this library’s `skills/` trees)

After the last slice, zero hits under `skills/` for:

- `/backlog task`
- `/backlog issue`
- `/backlog feedback`
- `/backlog promote`

Allowed remnants: historical `docs/design/`; this spec; un-backticked
refuse prose that does not contain those backticked tokens. Seed
`flows/bug.md` may contain `/backlog file tasks`. Lint comments are
not allowed remnants.

Red-proof the sweep: plant `/backlog task` under `skills/`, demand
the grep fails, remove the plant.

**Procedure**

- `file`: unknown stem asks and writes nothing; known stem appends
  one row and scoped-commits when standalone.
- `debrief`: compile two modules, route one leftover to each TSV,
  one commit; a host with no `debriefs/` reports zero sinks and
  mints no taxonomy and no `reports/` record.
- `setup --apply tasks`: creates `tasks.tsv` + `debriefs/tasks.md`
  from the suggestion; second apply is a no-op.
- Adopt: a fixture `doctype: trackers` titled `Backlog` with one
  open line and one completed line yields `tasks-1` open, no second
  row for the completed line, record `archived` / consumed.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | Script: schema, CRUD, compile, setup --list/--apply, tracker-add/remove, tests | `skills/backlog/scripts/tests/run.sh` | `skills/backlog/scripts/**`, `skills/backlog/suggestions/**` |
| S2 | Router + verbs: setup, tracker, file, debrief, curate; drop task/issue/feedback/promote; SKILL.md description/edges; delete `templates/trackers.md` and `record-mint.sh` | lint `backlog`; absence of dropped verb files and minter | `skills/backlog/SKILL.md`, `skills/backlog/verbs/**`, `skills/backlog/templates/trackers.md`, `skills/backlog/scripts/record-mint.sh`, `skills/backlog/scripts/tests/record-mint-test.sh` |
| S3 | Adopt walk (verb or setup arm) + journal contract sentence + done-writeback scope | fixture adopt test; journal lint | `skills/backlog/**`, `skills/journal/SKILL.md`, `skills/journal/verbs/done.md` |
| S4 | Consumers: workstream generic lane + ship complete; seed `bug.md`; lint BL-1 comment; PACK blurb + seam; README | absence grep + red-proof | `skills/workstream/**`, `skills/clankshop/flows/bug.md`, `skills/clankshop/PACK.md`, `skills/skill-builder/scripts/skills-lint.sh`, `README.md` |
| S5 | Clankshop setup/migrate step 6 apply; check becomes 7; Guard 1–7 | clankshop harness | `skills/clankshop/verbs/setup.md`, `migrate.md`, `check.md`, `skills/clankshop/scripts/tests/**` |

Land order S1 → S2 → S3 → S4 → S5. S1 is independently testable.
S2 does not delete consumer `/backlog task` strings (S4). S5 plants
defaults only after the script exists (S1).

## Review history

None yet. Spec is `status: draft`. Caller publishes after a passing
host review they accept.
