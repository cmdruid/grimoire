---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# records-layer init — Spec

Settled 2026-08-18 on stream `grok`. Human brief: pack skills that
create records must write them to the project's **agent-records
home** (declared `agent-records:`, else legacy `records-root:`,
else `.records/`), produce their own contract-shaped front-matter
from a template they carry, and create *their own store* without
a journal floor. Journal deploys no store directories.
`/skill-builder review` enforces that as skill doctrine;
`/journal` audits and repairs the files. Triggered by a live
backlog refuse (no `records.sh` → stop and point at
`/journal setup`).

This library's existing design home is `docs/design/` (patient-zero:
grimoire authors the records layer, it does not run a workshop on
itself). This spec lives here. After the flip, *runtime* record
writes from the skills go to the agent-records home, including on
a host that has never run `/journal setup`.

## Problem

Record-writing skills do not share one initiation story. Three
regimes currently coexist:

1. **Refuse.** `backlog` stops if
   `<agent-records>/scripts/records.sh` is missing and points at
   `/journal setup`. Journal's own `setup` documents that floor:
   "clients that find no records layer stop and point here." That
   is the failure the human hit.
2. **Skip or relocate.** On a host without a clankshop stamp,
   `workstream` skips the records seams and will not create
   `.records/`; `blueprint` and `contractor` confirm an output home
   (default `docs/`); `auditor` writes a dated file under the rubric
   home; `debugger` mints no report.
3. **Write independently.** `notepad` already does the right thing:
   resolve the agent-records home, create `notes/` on first write,
   emit the five-key contract from a bundled template, use
   `records.sh` only when that file is executable, never deploy
   the rest of the layer, never refuse.

Two more holes sit behind the refuse:

4. **Journal pre-creates the stores.** `standup.sh` `mkdir`s all
   eight store directories (plus `.gitkeep`) and copies
   `templates/reports.md`. Empty folders then look like a layer
   someone else owns. The skill that mints a store should be the
   one that creates it.
5. **The name "records root" is too generic.** Agents confuse it
   with the repo root, a filesystem root, or ordinary project
   docs. The directory is specifically where *agent-authored
   typed records* live.

The refuse is a **self-init floor** — corollary 1 of
`skills/skill-builder/docs/DOCTRINE.md` ("a durable-home skill can
create its own home; it depends on no other skill's `init` having
scaffolded it first"). Backlog is not durable-home, but the same
constraint applies: a skill that *writes* records must be able to
write them with no sibling standup. The workshop stamp is being
used as a proxy for "records exist." Those are different facts.
The stamp picks handbook and station context. It does not decide
whether a record gets written, or where.

Journal-as-auditor is already the intended split (`check` /
`curate` repair front-matter and ledger coherence). Journal-as-
**prerequisite** inverts it.

## Goal

Every pack skill that creates a typed record:

- writes it under the **agent-records home** (declared
  `agent-records:`, else legacy `records-root:`, else `.records/`);
- carries `templates/<doctype>.md` for every store it mints, and
  produces a contract-shaped record (dated slug + the five
  front-matter keys) from that template with no `records.sh` and
  no `/journal setup`;
- creates only its own store directory on first write;
- never refuses for a missing records layer;
- never deploys `records.sh`, `history.tsv`, other skills' stores,
  or the records README.

`/skill-builder review` flags a writer that still has a journal
floor, cannot produce front-matter itself, lacks its own
`<doctype>` template, or lands records in a confirmed `docs/`
fallback. `/journal check` / `curate` remain the file auditors.
`/journal setup` deploys the **tool layer only** (`scripts/records.sh`,
empty `history.tsv`, README) and is never a floor. It creates
**no store directory and no `templates/`**.

Lint `fails=0`. No new sibling sourced at runtime.

## Approach

**Chosen:** generalize the notepad pattern into doctrine, then fold
every current writer onto it in three slices. `records.sh` stays
opportunistic. Own-store standup only. Each writer carries the
templates for the stores it mints. Journal setup shrinks to the
tool layer. Workshop probe stays, but only for handbook / station
/ playbook context. The place is named the **agent-records home**.

**Rejected: full journal layer on first write.** Every capture
would silently become `/journal setup`. That couples skills that
share nothing but a path, deploys a ledger the skill must not
hand-write, and makes "stand up" mean something different from
what notepad already shipped.

**Rejected: journal still mkdir's the eight stores, empty.** That
is how the current standup teaches agents "this layer already
exists and belongs to journal." Empty `.gitkeep` directories are
not a kindness; they are a floor in filesystem form.

**Rejected: doctrine + backlog only this unit.** Leaving
blueprint / contractor / workstream / debugger / auditor on the
`docs/` or skip path would leave the same hole under a different
name: a spec or plan still would not appear in the agent-records
home on a bare repo.

**Rejected: a shared runtime mint library sourced from journal.**
Self-contained packages do not `source` a sibling. Each writer
either already has a minter (`notepad`), gets a doctype-
parameterized copy of that minter (`backlog`), or composes
front-matter + its existing body scaffold in prose when minting
is rare (`debugger`, `auditor`). Copy-drift of the five-key
shape is caught by `journal check` and by the review brief, not
by a new shared binary.

**Rejected: flipping this library's own `docs/design/` and
`docs/BACKLOG.md` into `.records/` as a side effect.** Patient-zero
stands: do not seed a workshop here, do not register against this
`AGENTS.md`. The skills' *runtime* destination is the
agent-records home; this repo's maintainer artifacts stay where
they are until a human migrates them.

**Rejected: rename the default directory to `.agent-records/`.**
The adjective belongs in the prose name, not the path.
`.records/` is already shipped; brownfield hosts and every
existing test fixture use it.

**Rejected: "working records."** Collides with git's working
tree, which this library already uses heavily (workstream,
worktree, working-tree draft).

## Mechanism

### The name — agent-records home

| Surface | Value |
|---|---|
| Prose (skills, doctrine, briefs) | **agent-records home** — never "records root" |
| Default path | `.records/` (unchanged) |
| Front-door declaration | `agent-records: <rel>` preferred |
| Legacy declaration | `records-root: <rel>` still accepted |
| Resolver | first `^agent-records:` or `^records-root:` in `AGENTS.md`, then `CLAUDE.md`; else `.records` |
| Script argument | the resolved path (scripts do not scan the front door) |
| Script fact key | `agent-records=` on new or touched scripts; existing `records-root=` is fine until that script is edited |

Why this name: "agent" says who writes here; "home" is this
library's word for a durable place (durable-home, rubric home);
dropping "root" removes the repo-root collision. The front-door
gains `agent-records:` because that is the line an agent sees
in `AGENTS.md`. `records-root:` remains a synonym so already-
declared hosts do not break. First match of either wins.

Doctrine's *Front-door variables* section is updated in place:
the canonical example becomes `agent-records:`, the resolver
accepts both names, and skill prose keeps naming the default
path literally (`.records/plans/…`).

### The record-writer rule (doctrine)

Add a section **Record-writing skills** to
`skills/skill-builder/docs/DOCTRINE.md`, after *Front-door
variables*. It is portable (any skills library, not just this
pack). Rules:

1. **Destination.** A typed record is written under the
   agent-records home (resolver above). Skill prose keeps
   naming the default path literally. Scripts take the
   resolved path as an argument and do not scan the front
   door (same split as notepad).
2. **Carry your templates.** A skill that mints store `D`
   bundles `templates/D.md` — a contract-conformant record
   with `<title>` / `<date>` slots. Body scaffolds (blueprint
   `spec.md`, contractor `plan.md`) are *not* a substitute
   unless they *are* the doctype template. The review brief
   flags a writer whose store has no in-package template.
3. **Own-store standup.** On first write, `mkdir` that skill's
   store (and the agent-records home directory if needed). Do
   not create `scripts/records.sh`, `history.tsv`, other
   stores, the records README, or `templates/` except when
   lazy-deploying *this* store's template because `records.sh`
   is about to `new` from it.
4. **No floor.** Missing `records.sh` is not an error. Missing
   `/journal setup` is not an error. A description must not say
   the skill requires a stood-up records layer. A verb must not
   stop and point at `/journal setup`.
5. **In-package contract.** The writer states the five keys
   (`doctype`, `status`, `created`, `updated`, `tags`), the
   status vocabulary (`open` | `current` live; `done` |
   `dropped` | `superseded` | `consumed` closed), the dated
   slug (`YYYY-MM-DD-<slug>.md`), and the record-link form
   (`→ <store>/<file>.md`) in *its own* package. It does not
   send the agent to another skill's `SKILL.md` for those
   bytes. Pack composition (the face / runbook) still names
   journal as the format authority; leaves do not.
6. **Opportunistic `records.sh`.** If
   `<agent-records>/scripts/records.sh` is executable, use
   `new` / `touch` / `done` / `list` and lazy-deploy the
   bundled template into `<agent-records>/templates/` when
   the deployed copy is absent (incumbent wins; this is the
   one moment a writer creates `templates/`). Otherwise write
   the same contract shape from the bundled template, with
   the same `fill` / slug / collision rules notepad already
   copied from `skills/journal/scripts/records.sh`.
7. **Never hand-write `history.tsv`.** File-mode close rewrites
   `status:` (and `updated:`) only. After a later
   `/journal setup`, `records.sh check` will flag a closed
   record with no ledger line. Repair is journal `curate`:
   rewrite `status:` back to `open`, then `records.sh done`.
   `records.sh done` refuses an already-closing status — that
   is why the writer must not pretend file-mode close is a
   ledger close.
8. **Workshop stamp is orthogonal.** The one probe
   (`Seeded from clankshop` in `.handbook/README.md`) still
   picks handbook, station context, and playbooks. It does
   **not** pick the agent-records destination and does **not**
   decide whether a record is minted. Do not create
   `.handbook/` as a records side effect. Do not run
   `/clankshop setup` or `/clankshop migrate` as a records
   side effect.

Corollary 1's "name your floor" sentence gains an explicit
records clause: a writer that needs journal's *tool* names
`consumes: records-tool` only when it *cannot* file-mode;
the default is that it can.

### Template inventory (who carries what)

| Skill | `templates/<doctype>.md` it must carry | Already has |
|---|---|---|
| `notepad` | `notes.md` | yes |
| `backlog` | `bugs.md`, `tickets.md`, `trackers.md` | yes |
| `blueprint` | `design.md`, `adr.md` | `adr.md` yes; `spec.md` is the body scaffold — add `design.md` as the doctype shell (five keys + `<title>`/`<date>`), same split contractor already uses (`plans.md` vs `plan.md`) |
| `contractor` | `plans.md` | yes |
| `debugger` | `reports.md` | no — add (match journal's in-package example; copy, do not source) |
| `auditor` | `reports.md` | no — add, same shape |
| `workstream` | `plans.md`, `reports.md` | no — add both (it seeds / drafts plans and may mint a debrief report) |
| `journal` | none deployed | keep `templates/reports.md` in-package as the **contract example only**. Setup does not copy it. |

A skill does not carry templates for stores it does not mint.
Auditor and debugger do not carry `bugs.md` this unit
(impersonation rule, below).

### Enforcement

`skills/agent-council/briefs/skill-review.md` — extend
**Independence** and **Output shape**, no new axis:

- **Independence.** If the skill writes typed records, it
  must not require a sibling standup or an executable
  `records.sh` as a floor. A stop that names `/journal setup`
  is a finding. A description that requires a stood-up
  records layer is a finding.
- **Output shape.** If it produces a record, the destination
  is `<agent-records>/<store>/` (default `.records/<store>/`),
  not a confirmed `docs/` fallback and not "skip, write
  nowhere." The in-package contract (five keys, dated slug)
  is specified in the package. Every store it mints has
  `templates/<doctype>.md` in the package.

`/skill-builder review` already judges only the axes the
brief names. No verb change. `/skill-builder check` does
not grow a mechanical records-writer lint this unit — the
grep in Verification is the build gate; the brief is the
ongoing gate.

### Journal

Setup shrinks to the **tool layer**.

`scripts/standup.sh` creates only:

- the agent-records home directory itself (default `.records/`);
- `scripts/records.sh` (`scripts/` is journal's tool folder,
  not a store — reserved, same as today);
- empty `history.tsv`;
- `README.md` if absent (worded for the slim layer: stores
  appear when a skill first writes; templates arrive with
  the writer).

It does **not**:

- `mkdir` `adr` / `bugs` / `design` / `notes` / `plans` /
  `reports` / `tickets` / `trackers`;
- write `.gitkeep` anywhere;
- `mkdir` `templates/` or copy `reports.md`.

Exit 2 (already stood up) keys **only** on
`scripts/records.sh` present — not on `templates/`, which
may never exist until a writer lazy-deploys. A home that
merely exists (legacy path, or a notepad-created
`.records/notes/` with no tool) is still fine: standup is
additive and writes the tool beside what is there.

`verbs/setup.md` drops the sentence that clients stop and
point here, and drops "stand up the eight stores." Done-when
becomes: tool + ledger + README; no store directories.

`SKILL.md` still *defines* the eight store names and the
contract. It no longer claims to create those directories.
"Clients cite the contract" stays as pack-composition
language in the body intro; client skills stop sending the
agent there. `curate` already owns ledger-coherence repair;
no new verb. File-mode closes are a curate input, not a
setup trigger.

`scripts/tests/standup-test.sh` is rewritten against the
slim layer: no store dirs, no deployed `reports.md`,
`scripts/records.sh` + `history.tsv` + README present,
exit 2 still fires when `records.sh` already exists.

`description:` stays setup / done / curate / the contract.
Journal does not become optional in the pack
(`PACK.md` `required: journal` stays — the workshop's
records step still delegates here).

`records.sh new` already `mkdir -p`s the doctype directory.
That stays — the *mint*, not standup, creates the store.

### Notepad

Already conforms (carries `notes.md`, own-store, no floor).
Resolver prose updates to the new name and accepts
`agent-records:`. No other behavior change.

### Backlog (the pain)

Drop the floor:

- `description:` loses "Requires a stood-up records layer —
  it guards rather than standing one up."
- Delete the **Guard** section. Shared discipline starts
  with the agent-records resolver (inlined, same as notepad,
  both declaration names) and the in-package contract (five
  keys, tracker-line form, the three canonical trackers).
- Every verb drops the first-step "no records layer → stop
  and point at `/journal setup`."
- Add `scripts/record-mint.sh`, a doctype-parameterized
  copy of `note-mint.sh`:

  ```
  record-mint.sh mint  <agent-records> <doctype> <title>
  record-mint.sh stamp <agent-records> <abs-path> [--status <status>] [--note "<text>"]
  ```

  Bundled template is `templates/<doctype>.md` (`bugs`,
  `tickets`, `trackers` — already present). File-mode
  creates only `<agent-records>/<doctype>/`. Same stdout
  keys as `note-mint.sh` (`agent-records` or
  `records-root`, `path`, `rel`, `mode`). Same `fill` /
  slug / collision / `file_stamp`. Never writes
  `history.tsv`.
- Tests: `scripts/tests/record-mint-test.sh` + `run.sh`,
  same fixture style as notepad (no `.records/` in this
  repo). Cases: no `records.sh` → store + five keys +
  `mode=file`; with `records.sh` → `mode=records` and
  lazy-deploy; stamp closing status without `records.sh`
  does not create `history.tsv`; missing doctype template
  is an error.
- Verbs call the script. `list` when `records.sh` is
  missing: scan `<agent-records>/<doctype>/*.md` and honor
  live vs closing `status:`, same as notepad `write`.
- Commit-tree probe and `scoped-commit.sh` stay.
- Tracker files are still created lazily on first capture
  (`new trackers --title "Backlog"` or file-mode equivalent
  that sets the H1 and `## Items`). Incumbent-schema guard
  unchanged.
- Do not name journal in the description. Body may say
  "the format authority" without a sibling slash-command.

### Workstream

Host layout changes from "workshop → records seams; else
skip and do not create `.records/`" to:

- **Stamp present** → summon build-station context; filled
  `<debrief>` is `/backlog debrief`.
- **Stamp absent** → no handbook summon; filled `<debrief>`
  stays "the project's own close-the-books sweep (do not
  invoke `/backlog`)." Independence: workstream is not a
  backlog client on a bare host.
- **Agent-records destination is not stamped.**
  Workstream-owned records — seeded / drafted `plans/`
  files, ship-time plan closes, optional debrief
  `reports/` — land under the agent-records home.
  File-mode if `records.sh` is missing (fill from the
  bundled doctype template; stamp-only close). Do not
  create `.handbook/`.
- **Carry `templates/plans.md` and `templates/reports.md`.**
- **Do not impersonate backlog.** Do not mint a Backlog
  tracker. Tracker-line completion runs only when that
  tracker file already exists (flip `[ ]` → `[x]`,
  opportunistic `touch`). Else record the ship in the
  plan close / hand-off / the project's own tracker
  layout, as today on a non-workshop host.
- `create` step 5: a new untracked plan moves to
  `<agent-records>/plans/` on every host, with contract
  front-matter (`records.sh new` or file-mode fill from
  `templates/plans.md`).
- `ship` step 1: opportunistic `records.sh done`; else
  file-mode stamp of the plan. Ledger commit path only
  when `history.tsv` was actually written.
- Next-plan draft (delegate mode): same destination,
  same opportunistic mint.

Workstream does not grow a mint script this unit unless
file-mode plan fill turns out to be more than a template
copy + five-key front-matter — prefer prose + the bundled
templates. If a script is needed, it is a workstream-local
`plan-mint.sh`, not a sibling source.

### Blueprint

The environment probe still summons the design station on
a stamped host. It no longer forks the *destination*:

- Feature `spec` / `brainstorm` / ADR artifacts land in
  `<agent-records>/design/` and `<agent-records>/adr/`.
- Drop "confirm an output home (default `docs/`)."
- Founding-shaped `grill` / `spec` stay on the named file
  (no records mint). `new` / `deploy` unchanged
  (`deploy`'s dest `docs/ARCHITECTURE.md` is a genesis
  project file, not a typed record).
- Carry `templates/design.md` (doctype shell) and
  `templates/adr.md` (already present). `templates/spec.md`
  remains the body scaffold, filled after the shell is
  minted — same split as contractor `plans.md` / `plan.md`.
- Opportunistic `records.sh new`; else file-mode from the
  doctype template.
- Status promotion: `records.sh touch --status current`
  when the tool exists; else file-mode stamp. Closure
  through `records.sh done` when the tool exists; else
  file-mode stamp (curate repairs the ledger later).

### Contractor

Same destination flip for `plans/`:

- Drop standalone output-home confirmation.
- `roadmap` / `plan` / `runbook` land in
  `<agent-records>/plans/` with `tags:` exactly one of
  `[plan]`, `[roadmap]`, `[runbook]`.
- Already carries `templates/plans.md`. Keep it.
- Workshop: mint shell then fill body, as today.
  File-mode: write the plans template (five keys) then
  overwrite `tags:` and the body from `templates/plan.md`
  / `roadmap.md` / a runbook conductor, same as the
  workshop fill.
- Build / review verbs do not mint.

### Debugger

The stamp still picks the diagnostics playbook and still
gates Phase 4 (fix landing is not a record question).
The report is a record on every host:

- After Phase 3, mint a `reports/` record under the
  agent-records home (opportunistic `records.sh new
  reports`, else file-mode from `templates/reports.md` +
  `templates/investigation.md` body).
- Unstamped Done-when loses "No mint."
- Do not mint `bugs/` (backlog's store). A deferred
  defect still graduates through the host's bug lane.
- Bundle `templates/reports.md` (copy of journal's
  in-package example, not sourced).

### Auditor

The stamp still picks the rubric home (guardian doctrine
vs confirmed `docs/audit/`). That home is **not** a
record. The pass report is:

- Always a `reports/` record under the agent-records
  home, tagged `audit`. Drop the standalone
  `<home>/YYYY-MM-DD-audit-<scope>.md` path.
- Carry `templates/reports.md`.
- Defects: mint `bugs/` only when `records.sh` is
  present (workshop-typical) *or* when this skill is
  willing to file-mode a bugs record from a bundled
  template. **This unit does not give auditor a `bugs`
  template.** File-mode defects stay in the reports
  record; the operator files `/backlog bug` to promote
  one. That is the same drain-without-impersonation
  rule as workstream vs the Backlog tracker.
- Tracker-line drain: only when the tracker file
  already exists. Else the report is the queue.

### Clankshop / PACK.md

`setup` / `migrate` still delegate the tool-layer standup
to journal. That is the workshop onramp, not a client
refuse. They must not grow their own store `mkdir`s to
"help." Unchanged otherwise.

`PACK.md` roster blurbs that call backlog "a client of
the deployed records layer" and auditor "drains findings
into the records when a workshop is present" get one-
line updates so the face does not restate the old floor.
No `version:` bump (member set unchanged).

### Out of scope

- Standing `.records/` up inside this library as a
  migration of `docs/design/` / `docs/BACKLOG.md`.
- Renaming the default directory off `.records/`.
- Dropping the `records-root:` alias this unit.
- A mechanical lint rule in `skills-lint.sh` (the brief
  + the Verification grep are enough this unit).
- Giving every writer a mint script.
- Changing debugger Phase 4's workshop gate.
- Changing auditor's rubric-home probe.
- Making journal optional in the pack.
- Moving `records.sh` out of `scripts/` (that folder is
  journal's tool home, not a store).

## Verification

**Mechanical**

- `cd <worktree> && skills/skill-builder/scripts/skills-lint.sh`
  → `fails=0`. Expected WARNs: orphan edge types;
  worktree-vs-clone symlink notes.
- Grep gate (must be empty outside journal `setup`
  history / this spec / dated design docs):

  ```
  cd <worktree> && rg -n 'point at `/journal setup`|Requires a stood-up records layer' \
    skills --glob '!**/docs/**'
  ```

  After slice 2, `skills/backlog/` is empty of those
  strings. After slice 3, no writer skill carries them.
- Journal standup test rewritten: after `standup.sh` on
  a bare fixture, the home has `scripts/records.sh`,
  `history.tsv`, `README.md`, and **none** of
  `adr/ bugs/ design/ notes/ plans/ reports/ tickets/
  trackers/ templates/`.
- `cd <worktree> && skills/notepad/scripts/tests/run.sh`
  stays green (reference implementation).
- `cd <worktree> && skills/backlog/scripts/tests/run.sh`
  (new): file-mode mint, records-mode mint, no
  `history.tsv` on file-mode close, missing template
  errors.
- Each writer in the inventory table has
  `templates/<doctype>.md` on disk for every store it
  mints.

**Judgment**

- `/skill-builder review backlog` against
  `skills/agent-council/briefs/skill-review.md` after
  slice 2: Independence no longer flags a journal
  floor.
- Read-back of each slice's named files against this
  Mechanism section (destination, no floor, own-store
  only, own templates, opportunistic `records.sh`,
  journal creates no store dirs).
- Skill prose says "agent-records home," not "records
  root."

**Red-proof for the grep gate.** Before deleting
backlog's Guard, the grep must match
`skills/backlog/SKILL.md`. After, it must not. That
is the plant; do not delete the Guard until the
pattern has been seen to fire.

**Red-proof for standup.** Today's `standup-test.sh`
asserts the eight store directories exist. After the
flip those assertions invert (must be absent). Run
the old assertion once on the *new* script and
confirm it fails before committing the inverted test.

## Slices

This spec doubles as the plan. Sequencing is required
(doctrine first, then the pain, then the other
writers). A separate contractor plan is not required
unless a later flip changes a slice boundary.

- [ ] **Slice 1: doctrine + brief + journal tool-layer**
  <requires: —>
  - Paths: `skills/skill-builder/docs/DOCTRINE.md`;
    `skills/agent-council/briefs/skill-review.md`;
    `skills/journal/SKILL.md`;
    `skills/journal/verbs/setup.md`;
    `skills/journal/scripts/standup.sh`;
    `skills/journal/scripts/tests/standup-test.sh`;
    optionally `skills/clankshop/PACK.md` roster blurbs.
  - Verify: lint `fails=0`. Doctrine section present;
    front-door example is `agent-records:`; resolver
    accepts both names. Brief Independence / Output
    shape name the records-writer and template checks.
    `setup.md` no longer says clients stop and point
    here. Standup test: no store dirs, no deployed
    `templates/`.
- [ ] **Slice 2: backlog writes without a floor**
  <requires: 1>
  - Paths: `skills/backlog/SKILL.md`;
    `skills/backlog/verbs/*.md`;
    `skills/backlog/scripts/record-mint.sh` (new);
    `skills/backlog/scripts/tests/` (new).
  - Verify: grep gate empty under `skills/backlog/`.
    `scripts/tests/run.sh` green. Description ≤ 1024
    chars and names no sibling. Lint `fails=0`.
- [ ] **Slice 3: destination flip for the other writers**
  <requires: 2>
  - Paths: `skills/workstream/SKILL.md`,
    `verbs/create.md`, `verbs/ship.md`,
    `templates/plans.md`, `templates/reports.md`;
    `skills/blueprint/SKILL.md`,
    `templates/design.md`;
    `skills/contractor/SKILL.md`,
    `verbs/plan.md`, `verbs/roadmap.md`,
    `verbs/runbook.md`;
    `skills/debugger/SKILL.md`,
    `templates/reports.md`;
    `skills/auditor/SKILL.md`,
    `templates/reports.md`;
    `skills/notepad/SKILL.md` (resolver wording only).
  - Verify: grep gate empty under `skills/`. No
    writer confirms a `docs/` output home for a typed
    record. Workstream Host layout no longer says
    "do not create `.records/`." Debugger unstamped
    Done-when no longer says "No mint." Inventory
    table complete on disk. Prose says
    "agent-records home." Lint `fails=0`.

## Alternatives rejected (recap)

| Alternative | Why not |
|---|---|
| Full layer on first write | Silent `/journal setup`; deploys a ledger the writer must not touch |
| Journal still mkdir's empty stores | A floor in filesystem form; the minting skill owns the directory |
| Doctrine + backlog only | Same hole remains as `docs/` / skip on the other writers |
| Shared mint sourced from journal | Breaks self-contained packages |
| Migrate this library into `.records/` | Patient-zero; not the brief |
| Rename the directory to `.agent-records/` | Path churn; the adjective belongs in the prose name |
| "Working records" | Collides with git working tree |
| Mechanical lint in `skills-lint.sh` | Brief + grep are enough this unit; a new check needs its own red-proof later |
