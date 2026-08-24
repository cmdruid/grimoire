---
doctype: specs
status: published
created: 2026-08-23
updated: 2026-08-24
tags: [spec]
---

# Backlog living trackers — skill-owned TSV + debrief cookbook — Spec

This library's design home is `docs/design/` (patient-zero). This spec
lives here. It doubles as the implementation plan.

Dependencies (land first):

- `docs/design/2026-08-24-grimoire-faceless-pack.md` — no assembler or
  pack defaults.
- `docs/design/2026-08-23-workspace-kinds.md` — canonical Backlog paths
  are `backlog/<kind>/`.

This spec owns Backlog only. It does not specify Delegate behavior,
publish another skill's hook, or edit a sibling spec during
implementation.

## Problem

Backlog is currently a fixed taxonomy (`task`, `issue`, `feedback`,
`promote`) implemented through dated tracker records. That makes list
shape skill law, conflates living queues with closeable records, and
forces other skills to name Backlog verbs directly.

The replacement needs extensible living lists and a deliberate
close-the-books sweep. It also needs a complete deployment contract.
The prior draft left the staged engine's materialization ambiguous and
treated a two-file tracker/module pair as one incumbent. An interrupted
setup could therefore leave an H2 without a TSV, after which `compile`
failed while rerun skipped the repair.

## Goal

After this feature:

- Backlog owns one project namespace:

  ```text
  <agent-workspace>/backlog/
    hooks/debrief.md
    scripts/trackers.sh
    trackers/<stem>.tsv
  ```

- `/backlog setup` is the explicit deployment path. It stages
  `scripts/trackers.sh`, offers builtin suggestions (`tasks`, `issues`,
  `feedback`), and creates only the selected tracker/module components.
- When at least one tracker exists, Backlog registers its own durable route
  in the project front door so a bare reader can discover the living lists.
  Removing the final tracker removes only that owned route block.
- The staged script is the only TSV writer. Agents consume `list` and
  `compile` output, never raw TSV bytes.
- The skill surface is `setup`, `tracker add|remove|list`, `file`,
  `debrief`, and `curate`. There is no `task`, `issue`, `feedback`,
  `promote`, or `adopt` verb and no compatibility alias.
- Setup is safely repairable: each TSV and cookbook H2 is an independent
  incumbent. Rerun creates only a missing counterpart and never
  overwrites the present component.
- `/backlog debrief` compiles project routing modules and performs one
  write-only sweep. Zero modules means gather, file nothing, and say so.
  It does not mint a report record.
- Standalone setup and capture operations commit every path they changed,
  including a newly staged or refreshed script, in one scoped commit.
  Inside debrief, the sweep commits once.
- Other skills use the host's follow-up or bug-filing lane in portable
  prose. Backlog does not own or rewrite their return contracts.
- Lint `fails=0`; Backlog and affected consumer harnesses are green.

## Approach

**Chosen: skill-owned TSV trackers plus one project-authored debrief
cookbook.** Tracker storage and routing policy are distinct:

- `backlog/trackers/<stem>.tsv` is mechanical state;
- `backlog/hooks/debrief.md` explains which leftovers belong in each
  stem;
- `backlog/scripts/trackers.sh compile` joins them into an agent prompt.

Builtin suggestions are explicit setup choices, not silent defaults.
The root faceless pack may describe the common three, but installs and
writes nothing.

**Rejected: retain taxonomy verbs.** They freeze suggestion names into
the routing API. Alpha hard-cut to `file <stem>`.

**Rejected: dated `doctype: trackers` records.** A queue is mutable
state, not a closeable record. Journal neither names nor crawls Backlog.

**Rejected: a standing adopt engine.** Brownfield import is a one-time
human mapping exercise using public `add`; it is not permanent runtime
surface.

**Rejected: silent script copy on ordinary verbs.** Deployment is
explicit. A missing staged engine on `file`, `tracker`, `debrief`, or
`curate` refuses with `reason=setup-required` and points to
`/backlog setup`; it never falls back to the package path.

**Rejected: skip the whole tracker when either setup component exists.**
That makes interruption unrecoverable. Incumbency is component-local.

## Mechanism

### Paths and ownership

Package source:

```text
skills/backlog/scripts/trackers.sh
skills/backlog/suggestions/<stem>.md
```

Project surface:

```text
<root>/<agent-workspace>/backlog/scripts/trackers.sh
<root>/<agent-workspace>/backlog/trackers/<stem>.tsv
<root>/<agent-workspace>/backlog/hooks/debrief.md
```

Within `<agent-workspace>`, Backlog may create only `backlog/` and those
owned kinds. Its sole write outside that namespace is the delimited
self-registration block in root `AGENTS.md` defined below. Refuse
symlinked/non-directory parents and root-escaping workspace declarations.
No other skill materializes, validates, or repairs the Backlog workspace
surface.

`<stem>` is a safe basename token matching
`[a-z0-9][a-z0-9-]*`. It contains no slash, dot component, whitespace,
or uppercase byte. Validate the stem before constructing a suggestion,
TSV path, H2 lookup, or id. Builtin suggestion filenames use the same
grammar.

### TSV contract

UTF-8, tab-separated, one header and a high-water comment:

```text
id\tstatus\tcreated\tcompleted\ttext\tlink
# highwater=<n>
```

- `id`: `<stem>-<positive integer>`.
- `status`: `open` or `done`.
- dates: ISO `YYYY-MM-DD`; `completed` empty while open.
- `text`: non-empty, no tab or newline.
- `link`: optional repository-relative path; no tab/newline, absolute
  path, or `..` component.
- high-water never decreases and materializes on every write, including
  `drop`; missing legacy comment is reconstructed from maximum observed
  id before allocating or rewriting.

Malformed header, duplicate id, invalid field, or id/stem mismatch
refuses the write without changing bytes.

### Engine

Every subcommand takes explicit `--root` and `--workspace`. The staged
script never scans the front door. It canonicalizes the existing root,
requires workspace to be a safe repo-relative path, constructs the
Backlog namespace beneath that root, and refuses any root escape,
symlinked parent, or incompatible entry before reading or writing. These
checks live in the writer, not only in the calling verb.

| Subcommand | Behavior |
|---|---|
| `list --tracker <stem> [--status open\|done\|all] [--link <rel>]` | Print matching rows; default open. Missing tracker → `reason=no-tracker`. |
| `list` | Print stem, open count, and debrief-module presence for every tracker. |
| `add --tracker <stem> --text <s> [--link <rel>] [--created <date>]` | Append open row and print `id=<id>`. |
| `update <id> [--text <s>] [--link <rel>]` | Rewrite selected fields. |
| `complete <id>` | Mark done with today's date. |
| `complete --link <rel> [--tracker <stem>]` | Complete matching open rows. |
| `drop <id>` | Delete row; preserve/materialize high-water. |
| `reorder --tracker <stem> --ids <csv>` | Require a permutation of every id in the file. |
| `compile` | Parse structural H2 modules, stem-sort, require each named TSV, and emit routing blocks. Missing cookbook/no H2 → zero blocks. |
| `setup --list` | Print builtin suggestion ids with title/use-when. |
| `setup --apply <stems...>` | Reconcile each builtin tracker's TSV and H2 independently. Unknown builtin → `reason=unknown-stem`. |
| `tracker-add <stem>` | Reconcile builtin from suggestion; custom stem uses header plus stub H2. Both components present → `reason=incumbent`. |
| `tracker-remove <stem>` | Refuse while open rows exist; otherwise remove TSV and matching H2. |

`compile` emits one block per stem and never an absolute TSV path:

```text
stem=<stem>
<project-authored routing body>
```

Duplicate structural H2s or an H2 whose TSV is absent fail. A TSV with
no H2 is legal and omitted from debrief routing.

### Component-local setup repair

For each requested stem, compute two facts before writing:

```text
tracker_present=true|false
module_present=true|false
```

Then:

| State | `setup --apply` / builtin `tracker-add` |
|---|---|
| neither | create both from the suggestion |
| tracker only | preserve TSV byte-for-byte; add only suggestion H2 |
| module only | preserve H2 body byte-for-byte; add only TSV header/high-water |
| both | `setup --apply`: no-op incumbent; `tracker-add`: refuse incumbent |

Custom `tracker-add` uses the same repair matrix, with a stub module
when that component is missing. Never infer that a present component is
safe to replace. A failure after creating one component is recoverable
by rerun.

### Component-local removal

`tracker-remove` uses the same two component facts and validates any
present TSV before changing either component. Open rows refuse the whole
operation without changing the cookbook.

Removal is module-first so every interruption state remains valid:

| Component state | Component action | Registration follow-up after success |
|---|---|---|
| both | atomically remove the matching H2 from the cookbook, then remove the TSV | remove the owned block only when no trackers remain |
| tracker only | refuse on open rows; otherwise remove the TSV | remove the owned block only when no trackers remain |
| module only | remove the orphan H2 as repair | remove a stale owned block when no trackers remain |
| neither | no component write | remove a stale owned block when present; otherwise `reason=no-tracker` |

The cookbook rewrite uses a temporary file beside the destination and an
atomic rename, preserving every byte outside the matching structural H2.
If the command stops after the module removal but before the TSV removal,
the remaining tracker-only state is legal and a rerun completes it. Never
remove the TSV first. Registration reconciliation runs only after the
component action succeeds.

### Front-door registration

Backlog is a durable-home skill. Whenever the first tracker is created,
`setup` or `tracker-add` projects one owned block into the project's
root `AGENTS.md`:

```markdown
<!-- skill:backlog BEGIN built-against:<stamp> -->
### /backlog — project follow-up trackers
Route: Living trackers are under `<resolved-workspace>/backlog/`; run `/backlog tracker list` before filing.
Edges: produces `tracker`.
<!-- skill:backlog END -->
```

The helper substitutes the resolved repo-relative workspace and the
computed stamp before writing the block.

The bundled `scripts/register-route.sh` owns only the bytes between those
delimiters: absent block → append under `## Skill routes
(self-registered)` (creating the file/section if absent); present valid
block → replace only that block; malformed or duplicate delimiters →
refuse. Every setup or tracker operation that may reconcile the block
preflights it before changing tracker data. The stamp is path-scoped to the
installed Backlog package (`git log -1 --format=%h -- .` from that skill
directory), then a package version, then `v0-<date>`.

`tracker-remove` deletes only Backlog's block when it removes the final
tracker; it never removes or rearranges the surrounding section. A
registration change joins the same scoped commit as the tracker operation.
If an interruption removes the final data component but leaves the block,
rerun removes that stale owned block as repair; `reason=no-tracker` applies
only when neither tracker component nor the owned block exists.
This library's patient-zero `AGENTS.md` is never a setup target; registration
tests use throwaway project fixtures.

### `/backlog setup`

1. Resolve root and agent workspace; validate parents. Preflight the
   Backlog registration block before any write.
2. Materialize `backlog/scripts/trackers.sh` from this installed package:
   absent or different → copy package bytes; identical → no change.
3. Run staged `setup --list` and ask which builtin or custom stems to
   enable. A non-interactive invocation may name stems explicitly.
4. Run staged `setup --apply` / `tracker-add`.
5. Reconcile the owned registration block when at least one tracker now
   exists.
6. If standalone, scoped-commit exactly the changed paths among:
   `backlog/scripts/trackers.sh`, `backlog/trackers/`, and
   `backlog/hooks/debrief.md`, plus root `AGENTS.md` when its owned block
   changed. If nothing changed, do not commit.

There is no pack-applied default, later-visit installer, or check that
plants missing stems.

### Verbs and commits

| Invocation | Behavior |
|---|---|
| `/backlog tracker list [<stem>]` | Invoke staged `list`; summarize without reading TSV directly. |
| `/backlog tracker add <stem>` | Invoke staged `tracker-add`; for a new custom stub, caller authors the routing body before commit. |
| `/backlog tracker remove <stem>` | Invoke staged `tracker-remove`; surface open-row refusal. |
| `/backlog file <stem> [text]` | Resolve known stem from `list`; ask if missing/ambiguous; invoke `add`. |
| `/backlog curate [<stem>]` | Work from `list`; complete/drop/reorder through the staged writer. |
| `/backlog debrief` | Gather status/diff/conversation, compile modules, route leftovers through writer commands, and make one scoped commit. |

Standalone `file`, `tracker`, `setup`, and `curate` use the existing
commit-tree probe and `scoped-commit.sh`. The caller supplies every
changed path; the helper stages and commits only those paths in one
operation. Inside debrief, no nested capture commits occur.

### Portable consumer cleanup

Hard-cut leaf references to `/backlog task`, `/backlog issue`,
`/backlog feedback`, `/backlog promote`, and automatic tracker-line
completion. Workstream and other leaves say “host's follow-up lane” or
“host's bug-filing lane.” Workstream hook content is project policy and
is not filled by Backlog.

The root faceless pack runbook may recommend filling
`workstream/hooks/feature-completion.md` with `/backlog debrief`; that is
documentation only. This spec does not write Workstream's workspace.

### Spec ownership

This spec exclusively owns:

- Backlog schema, staged engine, suggestions, verbs, and setup;
- Backlog's three skill-first project kinds;
- removal of the old Backlog taxonomy;
- removal of Backlog-specific calls from portable consumers.
- Backlog's exact roster/seam spans in the root faceless runbook and
  its README inventory row.

It does not own Delegate, Workstream hook publication, pack setup,
workspace grammar, records, or sibling specs. It may edit consumer prose
to remove old Backlog calls, but never changes another skill's return or
setup contract.

## Verification

**Engine**

- header/schema validation; CRUD; complete-by-link; high-water after
  dropping max id and after missing-comment reconstruction;
- stem validation rejects separators, dot components, whitespace,
  uppercase, and traversal before any path is constructed;
- unsafe root/workspace values and symlinked parents refuse without an
  escape write;
- `reorder` rejects partial/duplicate lists;
- compile sorts stems, emits `stem=` only, fails on missing TSV, rejects
  duplicate H2, and returns zero modules when cookbook is absent;
- setup matrix covers neither/tracker-only/module-only/both for builtin
  and custom stems; present components retain exact checksums;
- interruption fixtures fail after first component, rerun, and prove a
  complete pair without overwrite;
- mutation red-proof changes “either present” back to whole-stem skip
  and makes the partial-state fixtures fail.
- tracker removal covers both/tracker-only/module-only/neither, refuses
  open rows before changing the cookbook, and proves that interruption
  after module removal leaves a legal state completed by rerun;
- mutation removes the module-first order and makes the interruption
  fixture fail.

**Deployment and commit custody**

- Fresh `/backlog setup` commits staged script plus selected tracker and
  cookbook paths in one commit and leaves the worktree clean.
- Identical rerun creates no commit and does not restage the script.
- Drifted staged script refreshes from package and joins the same scoped
  commit as other setup changes.
- Missing staged script on every non-setup verb refuses
  `reason=setup-required`; package execution is a prove-by-breaking
  failure.
- A symlinked `backlog`, kind parent, or destination refuses without
  writing through it.
- First-tracker setup/add creates one valid Backlog registration block;
  rerun replaces only that block, malformed/duplicate delimiters refuse
  before tracker writes, and removing the last tracker removes only the
  block. An interruption after final tracker-data removal but before block
  cleanup leaves a stale block that rerun removes. Fixtures never touch this
  library's `AGENTS.md`.

**Behavior and absence**

- File unknown stem asks and writes nothing; known stem appends one row.
- Debrief routes two leftovers to two modules and commits once; no
  cookbook files nothing and mints no report.
- Across live `skills/`: zero `/backlog task|issue|feedback|promote`;
  zero old record-minter/template files; zero kind-first Backlog paths;
  zero Delegate paths or return-contract requirements in this spec.
- Red-proof each absence population.
- Backlog and library lint green.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| B1 | Build staged TSV engine, schema/CRUD/compile, component-local setup/removal repair, suggestions, and mutation tests | Backlog engine harness | `skills/backlog/scripts/trackers.sh`, `skills/backlog/scripts/tests/**`, `skills/backlog/suggestions/**` |
| B2 | Replace router/verbs; remove taxonomy verbs, record minter, and old template | Backlog skill-doc harness + lint | `skills/backlog/SKILL.md`, `skills/backlog/verbs/**`, `skills/backlog/templates/trackers.md`, `skills/backlog/scripts/{record-mint.sh,tests/record-mint-test.sh}` |
| B3 | Add explicit setup/materialization, Backlog-owned front-door registration, and complete scoped-commit custody; missing-script refusal | deployment/registration/commit fixtures | `skills/backlog/verbs/setup.md`, `skills/backlog/scripts/{register-route.sh,scoped-commit.sh,tests/**}` |
| B4 | Purge old Backlog calls, id-tracker collision plumbing, and tracker completion from portable consumers; update Backlog's faceless-pack runbook and README spans | absence gate + workstream harness | `skills/workstream/{SKILL.md,verbs/create.md,verbs/sync.md,verbs/ship.md,templates/workstream-handoff.md,scripts/workstream-git.sh,scripts/tests/**}`, `PACK.md` (Backlog roster/seam spans only), `README.md` (Backlog row only) |

Land order B1 → B2 → B3 → B4. Workspace-kinds has already landed, so
all paths are skill-first from B1 onward. Delegate is not an ordering
dependency and no Backlog slice touches Delegate files.

## Out of scope

- Delegate return semantics or hook deployment.
- Workstream hook publication or parser behavior.
- Workspace grammar or generic path migration.
- Pack setup, pack defaults, or an assembler.
- Record adoption/conversion or dated tracker-record cleanup.
- Item-level history beyond Git.
- Compatibility verbs, aliases, dual reads, or migration.
