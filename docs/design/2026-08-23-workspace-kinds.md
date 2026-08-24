---
doctype: specs
status: published
created: 2026-08-23
updated: 2026-08-24
tags: [spec]
---

# Workspace kinds — closed map, script staging, hook folders — Spec

This library's design home is `docs/design/` (patient-zero). This spec
lives here. It doubles as the implementation plan.

Consumers (land after this file):
`docs/design/2026-08-23-backlog-living-trackers.md`,
`docs/design/2026-08-23-delegate-byproducts-hook.md`.

Lineage this amends, not replaces:
`docs/design/2026-08-19-two-roots-simple-spec.md` (holds-column,
coincidence severity, ownership example),
`docs/design/2026-08-20-project-hooks.md` (hooks as
`hooks/<skill>.md` files; first consumer workstream),
`skills/skill-builder/docs/DOCTRINE.md` *Which home* / *Project
hooks* / record-writing rule 6.

Settled 2026-08-23; coincidence WARN, hard-cut staging, and
folder compile stamp settled 2026-08-24. Every branch below is
resolved.

## Problem

`<agent-workspace>` (default `.dev`) is the project’s development
home. Two-roots lists `doctrine/`, `spec/`, `flows/`, `templates/`,
`scripts/`, `hooks/` with no skill that **owns the map**. Skills
invent siblings (`backlog/`, a fake kind `trackers/` used by one
writer, a dumped `.dev/scripts/foo.sh`) or copy tools into
`<agent-records>/scripts` and `doctrine/scripts` because
`dirname/..` is the data root. Leaves cannot tell a kind from a
snowflake. Executors often refuse to run scripts from the agent
install (`~/.agents/skills/…`) because that path is outside the
project sandbox.

Journal is the format authority for `<agent-records>`. The other
root has no peer.

## Goal

After this feature:

- A **`workspace` skill** is the format authority and guard for
  `<agent-workspace>`. Clankshop remains the assembler (seeds
  workshop doctrine, runs setup/migrate). skill-builder’s
  `DOCTRINE.md` keeps a short which-home table and **points** here
  for the contract. One copy of the kind map.
- Top-level children of `<agent-workspace>` are a **closed set**
  of kinds (below). Unknown children **FAIL** `workspace check`
  when the resolved homes are different paths; **WARN** when they
  coincide. Known-bad shapes FAIL in both cases.
- **No scripts in the data homes.** Not a records-home dump
  `$rr/scripts/records.sh`, not `<agent-workspace>/doctrine/scripts`,
  not a flat `<agent-workspace>/scripts/*.sh`. Invoked entrypoints
  are **staged** at `<agent-workspace>/scripts/<skill>/<entry>.sh`
  (executor-visible, in-project). When homes coincide, `scripts/`
  is the workspace kind and stays. The package remains the source
  of truth; the copy is refreshed, never host-authored. Old
  invoked paths are hard-cut this feature.
- Hooks are `<agent-workspace>/hooks/<skill>/<seam>.md` — a
  **folder** per skill, one **known file** per seam. Missing file
  = skip. Filename is the seam id. Body is the overlay.
- Templates stay `<agent-workspace>/templates/<skill>/`.
- Workshop doctrine stays `doctrine/{README,core,design,build,test,review}/`.
  Skill-lock-in doctrine is `doctrine/skills/<skill>/` so it cannot
  collide with station names.
- Trackers (living lists) are the kind
  `<agent-workspace>/trackers/<stem>.tsv`. Backlog is the only
  writer until a second consumer.
- Inspector kinds stay `inspector/<kind>.md`. Flows stay `flows/`.
- Lint `fails=0`. New workspace harness green. Clankshop / journal
  harnesses green after their consumer slices.

## Approach

**Chosen: a workspace skill (journal’s peer for this root), closed
kinds, staged scripts, hook folders, nested skill-doctrine.**

`/workspace check` is the guard. Publishers materialize their own
kind files (narrow mkdir). Clankshop setup may run the check when
the member is present; it does not own the kinds.

**Chosen (2026-08-24): coincidence stays; unknown-child FAIL is
split-home only (WARN when homes coincide).** Known-bad shapes
still FAIL. Do not enumerate record stores.

**Chosen (2026-08-24): hard-cut old tool paths this feature.**
Assembler materializes; leaves only probe the staged path.
Missing → same degrade as today (no summon / file-mode).
**The old records-home tool dump is gone.** Journal does not
create, copy into, or document `$rr/scripts/records.sh`. An
empty leftover `$rr/scripts` is `rmdir`’d. When homes coincide,
`scripts/` is the workspace kind and stays.

**Chosen (2026-08-24): workstream compile stamps the folder;
hash is a canonical concatenation of known seam files.** Missing
known seam *file* is unfinished (setup creates it).

**Rejected: only skill-named top-level folders.** Doctrine and
flows are project kinds, not a skill’s attic.

**Rejected: `<agent-workspace>/skills/<name>/`.** Collides with the
package tree and the install home.

**Rejected: `<agent-workspace>/homes/<name>/`.** Extra namespace;
kinds already skill-key `templates/`, `hooks/`, `scripts/`.

**Rejected: leaving helper scripts only in the package.** Sandbox
executors often cannot run `~/.agents/skills/…`. Staging inside
the project is the portable workaround.

**Rejected: host-edited staged scripts (templates incumbent
policy).** Scripts are implementation. Refresh from the package.
Behavior customization is hooks / templates.

**Rejected: `dirname/..` as the data root.** Staged copies do not
live next to records or doctrine. Every staged script takes
`--root` / `--workspace` (verb resolves; script does not scan the
door).

**Rejected: `hooks/<skill>.md` as a single file of H2s.** Multiple
seams become multiple files. Parsers do not glob: they read
**known** seam filenames.

**Rejected: skill-lock-in doctrine as a sibling of `design/` /
`test/`.** Station names collide with skill names. Nest under
`doctrine/skills/<skill>/`.

**Rejected: workspace skill as the assembler.** That is clankshop.
Workspace does not seed station chapters and does not write the
door.

**Rejected (2026-08-24): withdraw coincidence.** Reopens the
legacy-`dev/` question two-roots dissolved.

**Rejected (2026-08-24): skip the unknown-child guard entirely
(positive checks only).** Split homes keep FAIL.

**Rejected (2026-08-24): shim at `doctrine/scripts/context.sh`;
dual-read or dual-write of old tool paths.** Contradicts the
Goal.

**Rejected (2026-08-24): keep a leftover `scripts/` under the
records home “for compatibility.”** The old **flat**
`$rr/scripts/records.sh` is deleted; an empty `$rr/scripts` is
`rmdir`’d. Never `rm -rf` that directory (when homes coincide it
is the workspace scripts kind).

**Rejected (2026-08-24): two `hooks-compiled:` lines.** One
directory stamp; hash covers both known seams.

## Mechanism

### Skill

Package `skills/workspace/`. Thin router. Verbs:

| Invocation | Does |
|---|---|
| `/workspace check` | Facts: top-level children vs the closed set; known kind layout; optional script-copy drift. Writes nothing. |
| `/workspace refresh` | For each staged entrypoint this host has already materialized, copy from the **installed skill package** if bytes differ. Pathspec-scoped commit when standalone. |

No `setup` that seeds doctrine. Bare `/workspace` asks which verb.

Description names no sibling. Edges: `produces: —` (check is facts;
the kinds are the project’s). No `consumes: doctrine`. Inline the
doctrine `resolve_agent_workspace` snippet (`DOCTRINE.md`, default
`.dev`). Do not shell `workstream-git.sh` (that script resolves
`agent-records` only). Prefer the sanctioned literal
`<agent-workspace>`.

Pack: **optional helper** (not required). Joining the member set
bumps `PACK.md` `version:` (minor). Clankshop `check` runs
workspace check when the sibling package is present; missing
member → skip, no finding. skill-builder is not a pack member; it
points at this skill’s kind table.

### Closed top-level

Default `<agent-workspace>` = `.dev`. Allowed children, and nothing
else:

| Kind | Path | Who writes | Incumbent |
|---|---|---|---|
| Workshop doctrine | `doctrine/README.md`, `doctrine/core/`, `doctrine/design\|build\|test\|review/` | clankshop seed; then the **project** | seed never overwrites present files |
| Skill doctrine | `doctrine/skills/<skill>/` | the named skill (lock-in copy) | **wins** |
| Templates | `templates/<skill>/` | the named skill (lock-in) | **wins** |
| Hooks | `hooks/<skill>/<seam>.md` | the named skill (skeleton); pack fill of **empty** known seams; host overwrite of bodies | non-empty body **wins**; missing file = skip |
| Scripts | `scripts/<skill>/<entry>.sh` | the named skill (stage/refresh from package) | **refresh** (package wins) |
| Trackers | `trackers/<stem>.tsv` | backlog (only writer today) | script is the only writer |
| Inspector kinds | `inspector/<kind>.md` | inspector (bundled vs workspace copy) | workspace copy **wins** |
| Flows | `flows/*.md` | clankshop copy of pack flows; shopbook host stubs | dest file **wins**; extras kept |

**Known-bad (always FAIL, split-home or coincident):**

- `spec/` (not a kind this skill stands up; workspace spec/
  station was dropped 2026-08-23; specs are records)
- `<agent-workspace>/doctrine/scripts/`
- `<agent-workspace>/scripts/*.sh` (flat)
- `<agent-workspace>/backlog/`, `homes/`, `skills/`

`check` does not require `spec/`. An existing `spec/` directory
FAILS until the host deletes it. Alpha.

**Coincidence.** Let `W` = `resolve_agent_workspace(root)` and
`R` = `resolve_agent_records(root)` (doctrine snippets; default
`.dev` and `.records`). When `W` and `R` are the **same path**,
extra top-level names that are not kinds and not known-bad are
WARN (`reason=coincident-unknown`), not FAIL. Do not enumerate
record stores (`plans/`, `notes/`, `history.tsv`, … are open-ended
per two-roots). When `W` ≠ `R` (the default), extra names FAIL.

Narrow mkdir: a publisher may `mkdir` **its** kind path only when
`<agent-workspace>` already exists, or the home is the derived
default `.dev` and the mkdir is that kind only (creates `.dev` as
a container, never `doctrine/`). Declared `agent-workspace:` that
is absent → write nothing (`reason=no-home`). Clankshop remains
the owner-exception assembler for the workspace home itself.

### Hooks

Path: `<agent-workspace>/hooks/<skill>/<seam>.md`.

- `<skill>` matches frontmatter `name:`.
- `<seam>` is a **known** kebab filename the publisher documents
  (workstream: `feature-completion.md`, `after-eventful-ship.md`;
  delegate: `byproducts.md`; backlog: `debrief.md`).
- **Do not glob.** Extra files in the folder are ignored by the
  publisher; they are not a workspace-check FAIL (v1). They do
  not enter the compile hash.
- Missing file = skip the overlay. Empty body (whitespace strip) =
  skip. Non-empty body is the overlay (a glue command, a
  definition, or a catalog the **skill’s** script parses).
- Filename is the seam id. No required H2 inside the file. No
  required front-matter.
- **Package skeleton (workstream, this feature):**
  `skills/workstream/templates/hooks/<seam>.md` — split today’s
  `skills/workstream/templates/hooks.md`. Other publishers pick
  one package path in *their* spec and stick; this spec pins
  workstream because it migrates it. Copy if the project file is
  absent; never overwrite a present file. Pack fill writes
  **empty** known files only.
- Parsers must not glob `hooks/`. Each skill reads only
  `hooks/<its-name>/<its-known-seams>`.

**Workstream paths and stamp.**

`$HOOKS_DIR=<root>/<agent-workspace>/hooks/workstream/`
(absolute). `create` / `recycle` / `hooks.sh` / `hooks-glue.sh`
take `--dir "$HOOKS_DIR"`. No `--file` on `hooks/workstream.md`.

`hooks-compiled: <rel-dir> @ <hash12>` where `<rel-dir>` is
`$HOOKS_DIR` relative to the root (e.g. `.dev/hooks/workstream`)
and `<hash12>` is the first 12 hex chars of sha256 over the
**known** seam files in documented order
(`feature-completion` then `after-eventful-ship`):

```
feature-completion.md\0<body>\n---\nafter-eventful-ship.md\0<body>
```

`<body>` is the file bytes after the same surrounding-whitespace
strip `hooks.sh parse` uses today. Extra files in the folder do
not enter the hash. The compiled hand-off block still inlines
both bodies. `save` compiled-get/put span is unchanged.

**Missing cases (hash vs unfinished).**

- `$HOOKS_DIR` **absent** → today’s missing-file parse:
  `status=missing`, `hash=none`, every known slug empty, exit 0.
- Directory present, a known seam file missing → hash uses
  empty `<body>` for that slot only. **Unfinished** fires
  (below). Overlay skip if empty.

**Unfinished** (setup / migrate / check finding). Presence =
sibling dir `skills/workstream/templates/hooks/` (a known seam
file in it), resolved from the clankshop skill dir. Not
`templates/hooks.md`. No reader of the old single file except
the one-shot migrate (split, then delete). Presence AND (a
**known seam file missing** OR present with empty body after
strip). Missing *file* is unfinished — setup copies that file
from the skeleton, never overwrites a present file. This is
**not** today’s missing-H2 rule (project-hooks G2: a deleted
heading was not unfinished). Overlay skip stays: missing or
empty file → no extra glue. Setup’s job is to make the files
exist and fill empty pack glue.

**Migration (workstream, same feature):** live
`<agent-workspace>/hooks/workstream.md` (one file, H2 ids) becomes
the two files under `hooks/workstream/`. If the old file exists:
split H2 bodies into the new files (empty H2 → empty new file),
then delete the old file. Test fixtures that plant a glue
**body** retarget to the new paths. `PACK.md` workstream/backlog
seam path becomes
`<agent-workspace>/hooks/workstream/<seam>.md` (content-only; no
`version:` bump in S3).

### Scripts (staging)

Package path remains `skills/<skill>/scripts/<entry>.sh` (authoring,
tests).

Invoked path is
`<root>/<agent-workspace>/scripts/<skill>/<entry>.sh`.

**Who materializes (assembler-only).** Leaves never copy from a
sibling package.

- clankshop `setup` / `migrate` stages
  `scripts/clankshop/context.sh`, and stages
  `scripts/journal/records.sh` when that member is installed.
- journal `setup` stages `scripts/journal/records.sh`.
- `/workspace refresh` refreshes copies already present.
- `cmp` then `cp` if different. Never create the dest by hand.
  Tests and `tests/` trees are **not** staged.

Leaves **probe** the staged path. Missing → same degrade as
today (station summon: no summon; opportunistic `records.sh`:
file-mode).

**Hard-cut.** No shim, no dual-read, no dual-write. The only
invoked paths after this feature:

- `scripts/clankshop/context.sh` with `--workspace` (or
  `--doctrine`)
- `scripts/journal/records.sh` with `--root <agent-records>`

**Brownfield.**

- `context.sh`: if
  `<agent-workspace>/doctrine/scripts/context.sh` exists,
  `cmp`/`cp` onto the staged path, then **delete** the old file
  (and `doctrine/scripts/` if empty). Leftover
  `doctrine/scripts` is a known-bad FAIL.
- `records.sh` (one algorithm; no coincidence branch in the
  writer). Stage
  `<ws>/scripts/journal/records.sh` first. If
  `$rr/scripts/records.sh` exists and is **not** that staged
  path, `cmp`/`cp` onto the staged path if needed, then
  `rm -f` the flat file. Then `rmdir "$rr/scripts"` only if
  empty — if `journal/` / `clankshop/` / any other child
  remains, leave the directory. **Never `rm -rf "$rr/scripts"`.**
  After journal `setup` / later visit:
  - split homes (`W` ≠ `R`): `[ ! -e "$rr/scripts" ]`
  - coincident (`W` == `R`): `[ ! -f "$rr/scripts/records.sh" ]`
    and `[ -x "<ws>/scripts/journal/records.sh" ]`
  Workspace check does **not** inspect the records home.

The copy is **committed** (same as doctrine). A skill upgrade is a
git diff under `.dev/scripts/<skill>/`. CI has the bits without the
agent install.

Verbs always run the **staged** path after materialize, with
`--root` / `--workspace` as needed. Approval allowlist: one
project-relative glob (`<agent-workspace>/scripts/**`).

`records.sh` stages at `scripts/journal/records.sh` and takes
`--root <agent-records>`. Journal `setup` still writes `history.tsv`
+ records README; it **does not create** a records-home
`scripts/` dump (no `mkdir "$rr/scripts"`).
Rewrite standup, `records.sh` header comments, SKILL.md,
`search.md`, tests, and the minted records README so they never
name `<agent-records>/scripts` as the tool location.
`clankshop check` records step runs the **staged** journal path,
not `$rr/scripts/records.sh`. Later-visit refresh is
`/workspace refresh` (or journal setup calling the same copy
into `scripts/journal/`).

`context.sh` stages at `scripts/clankshop/context.sh` and takes
`--workspace` (or `--doctrine`). Seed copies chapters only, not the
loader. `check` invokes the staged loader (walk step 1).

**Portable contract (S4, `DOCTRINE.md` record-writing rule 6):**
if `<agent-workspace>/scripts/journal/records.sh` is executable,
use it; else file-mode. Strike
`<agent-records>/scripts/records.sh`.

**Summon retarget (same feature — otherwise the hole moves).**
Every live `doctrine/scripts/context.sh` summon becomes
`scripts/clankshop/context.sh` with `--workspace` / `--doctrine`.
Every opportunistic `<agent-records>/scripts/records.sh` probe
becomes the staged journal path.

### Trackers

`<agent-workspace>/trackers/<stem>.tsv`. Kind definition only;
schema and CRUD are the living-trackers spec. This skill’s check:
if `trackers/` exists, every child must be `*.tsv`; any other
name FAIL. Unknown **top-level** names still FAIL.

### Two-roots + doctrine

`docs/design/2026-08-19-two-roots-simple-spec.md` holds-column
becomes: `doctrine/` (incl. `doctrine/skills/`), `flows/`,
`templates/`, `hooks/` (directories), `scripts/<skill>/`,
`trackers/`, `inspector/`. Drop workspace-level `scripts/` as a
dump and drop `spec/` as a required hold.

Coincidence remains legal. Replace “needs no carve-out”: the
one carve-out is workspace check’s unknown-child **severity**
(WARN vs FAIL) when `W` == `R`. Ownership example: delete
“journal creates `scripts/` (its tool)” — journal stages at
`<agent-workspace>/scripts/journal/`; the records home no longer
holds a `scripts/` tool.

`DOCTRINE.md` *Which home*: replace the five-destination box with a
short table plus “full contract: the workspace skill.” Project
hooks section: folder + known seam files; strike “not delegate”;
named seam (loop or return overlay). Narrow mkdir bullets stay,
keyed on the kinds above. Record-writing rule 6 is S4 (staged
journal path), a different section of the same file.

`skill-builder new` hooks question: yes → SKILL.md sentence plus
known **seam filenames** (folder), not “known ids on the parse
line.” Still no generic scaffold.

### Independence

- `workspace` description names no sibling.
- Leaves still say “host’s follow-up lane” etc. They do not name
  `/workspace` except clankshop `check` (face may name members) and
  skill-builder’s pointer.
- Face may name `/workspace check` and `/workspace refresh`.

### Out of scope

- Living-trackers schema / verbs (sibling spec). TSV columns
  are that spec; this check only requires `*.tsv` children.
- Delegate byproducts fill copy (sibling spec).
- `/backlog next`.
- A shared hooks parser in skill-builder.
- Gitignoring staged scripts.
- Reopening `agent-workspace: .`.

## Verification

**Mechanical**

- `skills/workspace/scripts/tests/run.sh`: closed-set FAIL on an
  extra top-level dir (split-home); green on a fixture with only
  allowed kinds; `spec/` present → FAIL (split or coincident);
  `doctrine/scripts` present → FAIL; `scripts/foo.sh` (flat) →
  FAIL; `scripts/journal/records.sh` → OK; plant
  `trackers/notes.md` → FAIL; plant `trackers/tasks.tsv` → OK.
  Coincident fixture
  (`agent-workspace:` and `agent-records:` both `dev`, `plans/`
  present) → WARN `reason=coincident-unknown`, not FAIL. Prove-by-
  breaking both arms.
- Workstream folder migration: old file with two H2s → two seam
  files + old file gone; empty H2 → empty dest file.
- Compile stamp: `hooks-compiled:` names the directory; hash
  changes if either known body changes; an extra file in the
  folder does not change the hash; `$HOOKS_DIR` absent →
  `hash=none`; directory present, missing known file →
  unfinished finding (setup-named).
- Journal: staged `scripts/journal/records.sh` exists; `new` /
  `list` still work with `--root`. Split-home after setup (fresh
  and brownfield): `[ ! -e "$rr/scripts" ]`. Coincident after
  setup: `[ ! -f "$rr/scripts/records.sh" ]` and
  `[ -x "<ws>/scripts/journal/records.sh" ]`; `scripts/journal/`
  still present. Brownfield split: old `$rr/scripts/records.sh`
  → staged copy then `rmdir` of empty `$rr/scripts`. Brownfield
  coincident: old flat `$rr/scripts/records.sh` gone, kind dir
  kept. Prove-by-breaking: a setup that `rm -rf "$rr/scripts"`
  on a coincident fixture must FAIL.
- Clankshop: seed does not write `doctrine/scripts`; staged
  `scripts/clankshop/context.sh --check` is green against the seed.
  Brownfield: leftover `doctrine/scripts/context.sh` migrate-then-
  delete; check FAILs if it remains.
- Lint `fails=0` for `workspace`. PACK `version:` bumped.

**Absence** (population = this library’s `skills/` trees)

- Zero `<agent-records>/scripts` as an invoked or created path
  under `skills/journal/` except historical `docs/design/` and
  tests that plant the **old** flat file / empty dir to prove
  `rm -f` + `rmdir`. Zero `rm -rf` of `$rr/scripts` under
  `skills/journal/`.
- Zero `doctrine/scripts` writes under `skills/clankshop/seed/`
  (loader is not in the seed tree).
- Zero invoked `doctrine/scripts/context.sh` under `skills/`
  except historical `docs/design/`, this spec, and tests that
  plant the old path to prove migration.
- Zero invoked `<agent-records>/scripts/records.sh` under
  `skills/` except historical `docs/design/`, this spec, and
  tests that plant the old path to prove migration.
- Zero `hooks/<skill>.md` (file) publishers under `skills/` except
  allowed remnants: this spec, historical design docs, tests that
  plant the **old** file to prove migration.

Red-proof: plant `.dev/gizmos/` in a split-home check fixture,
demand FAIL, remove. Plant `plans/` in a coincident fixture,
demand WARN not FAIL, remove. Plant coincident journal setup
with staged `scripts/journal/records.sh` then a writer that
`rm -rf "$rr/scripts"` — demand FAIL, restore. Plant
`/backlog debrief` is not this spec.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | `workspace` skill: SKILL.md, `check` / `refresh` verbs, check script, tests (incl. coincident WARN and `trackers/` non-tsv FAIL) | `skills/workspace/scripts/tests/run.sh`; lint `workspace` | `skills/workspace/**` |
| S2 | Two-roots holds + coincidence severity + ownership example; `DOCTRINE.md` which-home + hooks folder; `new.md` seam-filename pointer | lint; two-roots grep | `docs/design/2026-08-19-two-roots-simple-spec.md`, `skills/skill-builder/docs/DOCTRINE.md`, `skills/skill-builder/verbs/new.md` |
| S3 | Workstream + hooks-glue: file → `hooks/workstream/<seam>.md`; `--dir`; folder stamp + canonical hash; unfinished = missing or empty known file; PACK seam path; clankshop `$HOOKS_DIR` | workstream + clankshop harnesses | `skills/workstream/**`, `skills/clankshop/scripts/hooks-glue.sh`, `skills/clankshop/scripts/tests/hooks-fill-test.sh`, `skills/clankshop/PACK.md`, `skills/clankshop/verbs/setup.md`, `skills/clankshop/verbs/migrate.md`, `skills/clankshop/verbs/check.md` |
| S4 | Stage `records.sh` / `context.sh`; `rm -f` old flat `$rr/scripts/records.sh`; `rmdir` if empty (never `rm -rf`); rewrite journal comments/README/tests; hard-cut readers onto staged paths; `DOCTRINE.md` rule 6 | journal + clankshop harnesses; absence greps | `skills/journal/**`, `skills/clankshop/scripts/seed.sh`, `skills/clankshop/seed/**`, `skills/clankshop/verbs/check.md`, `skills/clankshop/SKILL.md`, `skills/clankshop/flows/doc-audit.md`, `skills/clankshop/scripts/tests/seed-test.sh`, `skills/clankshop/scripts/tests/setup-journal-test.sh`, `skills/clankshop/scripts/tests/face-test.sh`, `skills/architect/SKILL.md`, `skills/contractor/SKILL.md`, `skills/inspector/SKILL.md`, `skills/auditor/SKILL.md`, `skills/workstream/SKILL.md`, `skills/workstream/verbs/ship.md`, `skills/notepad/verbs/write.md`, `skills/notepad/verbs/find.md`, `skills/notepad/scripts/note-mint.sh`, `skills/notepad/scripts/tests/note-mint-test.sh`, `skills/debugger/scripts/bug-mint.sh`, `skills/debugger/scripts/tests/bug-mint-test.sh`, `skills/backlog/scripts/record-mint.sh`, `skills/backlog/scripts/tests/record-mint-test.sh`, `skills/skill-builder/docs/DOCTRINE.md` |
| S5 | PACK optional member + version bump; clankshop `check` step 1 (after staged `context.sh --check`) runs workspace check when the sibling is present | clankshop harness; PACK frontmatter | `skills/clankshop/PACK.md`, `skills/clankshop/verbs/check.md`, `README.md` |

Land order **S1 → S3 → S2 → S4 → S5**. S2 requires S3 (doctrine
folder sentence is true only after the consumer migrates). S3
before living-trackers / delegate-hooks so those specs never
publish the old file shape. S4 may parallel S3 (tool staging
does not depend on hook folders). S2 and S4 edit different
sections of `DOCTRINE.md` (which-home / hooks vs rule 6). S5
last (member set). `check.md` has three deltas: S3 = `$HOOKS_DIR`; S4 = staged
`context.sh` / `records.sh` in step 1 / records step; S5 =
workspace-check bullet after the staged loader. Do not add a
10th check step.

## Review history

None yet. Caller publishes after a passing host review they accept.
