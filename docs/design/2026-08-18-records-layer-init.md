---
doctype: design
status: current
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# records-layer init — Spec

Accepted 2026-08-18 on stream `grok` after four
independent `/blueprint review` passes. Human
approved; this spec doubles as the plan. Next:
execute Slice 1.

Settled 2026-08-18 on stream `grok`. Human brief: pack skills that
create records must write them to the project's **agent-records
home** (declared `agent-records:`, else legacy `records-root:`,
else `.records/`), produce their own contract-shaped front-matter
from a template they carry, and create *their own store* without
a journal floor. Project-lock-in templates live in the
**agent-templates home** (declared `agent-templates:`, else
`<agent-records>/templates`), under `<skill>/`, and only the skill names which
of its bundled templates are copied there. Journal deploys no
store directories and no templates. `/skill-builder review`
enforces that as skill doctrine; `/journal` audits and repairs
the files. Triggered by a live backlog refuse (no `records.sh`
→ stop and point at `/journal setup`).

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

Journal-as-auditor is already the intended split
(`records.sh check` / `/journal curate` repair
front-matter and ledger coherence). Journal-as-
**prerequisite** inverts it.

## Goal

Every pack skill that creates a typed record:

- writes it under the **agent-records home** (declared
  `agent-records:`, else legacy `records-root:`, else `.records/`);
- carries bundled `templates/` in the package, **declares** which
  of those are project-lock-in, and produces a contract-shaped
  record (dated slug + the five front-matter keys) from the
  resolved template with no `records.sh` and no `/journal setup`;
- on first use of a declared project template, copies it to
  `<agent-templates>/<skill>/` if absent (never overwrites);
- creates only its own store directory on first write;
- never refuses for a missing records layer;
- never deploys `records.sh`, `history.tsv`, other skills' stores,
  or the records README.

`skill-builder` **observes** the rule (doctrine + `new`
scaffold) and **enforces** it (`check` mechanical gate +
`review` judgment). `records.sh check` / `/journal curate`
remain the *file* auditors. `/journal setup` deploys the
**tool layer only** (`scripts/records.sh`, empty
`history.tsv`, README) and is never a floor. It creates
**no store directory and no pre-seeded `templates/`**.

Lint `fails=0`. No new sibling sourced at runtime.

## Approach

**Chosen:** generalize the notepad pattern into doctrine, then fold
every current writer onto it in three slices. `records.sh` stays
opportunistic. Own-store standup only. Each writer carries its
templates and **declares** which ones lock into the
**agent-templates home** (default
`<agent-records>/templates/<skill>/`).
Journal setup shrinks to the tool layer. Workshop probe stays,
but only for handbook / station / playbook context. Instances
live in the **agent-records home**. `skill-builder` is the
ongoing observer and enforcer so the next skill does not
re-learn the hole.

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
shape is caught by `records.sh check` and by the review brief, not
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

**Rejected: `.agents/templates/<skill>/`.** This library already
lives at `~/.agents/`. A project path that starts `.agents/`
sends agents to the home directory.

**Rejected: a top-level `.templates/` default.** A second
dotted directory beside `.records/` (and `.handbook/` on a
workshop host) pollutes the project root. Schema vs
instances is a named-home split, not a sibling-folder
split. Flat `.records/templates/<doctype>.md` as the
*lock-in* path is also rejected — that collapses every
skill onto one `reports.md`.

**Rejected: copy every document-creating template by default.**
Not every bundled file is a project schema. The hand-off, a
founding working file, and a compaction-anchor are skill
internal. The skill names the lock-in set; the rest stay in
the package.

**Rejected: a `templates/lock-in` manifest file.** Agents
already read `SKILL.md`. A second roster drifts. The
declaration is a `## Project templates` list in `SKILL.md`;
verbs pass only those names.

## Mechanism

### The name — agent-records home

| Surface | Value |
|---|---|
| Prose (skills, doctrine, briefs) | **agent-records home** — never "records root" |
| Default path | `.records/` (unchanged) |
| Front-door declaration | `agent-records: <rel>` preferred |
| Legacy declaration | `records-root: <rel>` still accepted |
| Resolver | first `^agent-records:` or `^records-root:` in `AGENTS.md`, then `CLAUDE.md`; else `.records` |
| Verb / mint-script argument | the resolved path (mint scripts do not scan the front door) |
| State-analysis helper | may inline the resolver (both declaration names); print `agent-records=` |
| Script fact key | `agent-records=` on new or touched scripts; existing `records-root=` is fine until that script is edited |

Why this name: "agent" says who writes here; "home" is this
library's word for a durable place (durable-home, rubric home);
dropping "root" removes the repo-root collision. The front-door
gains `agent-records:` because that is the line an agent sees
in `AGENTS.md`. `records-root:` remains a synonym so already-
declared hosts do not break. First match of either wins.

Doctrine's *Front-door variables* section is updated in place:
the canonical example becomes `agent-records:` (with
`agent-templates:` beside it), the records resolver accepts
both records names, and skill prose keeps naming each default
path literally (`.records/plans/…`,
`.records/templates/backlog/…`).

### The name — agent-templates home

Schema, not instances. Nested under the records home by
default so the project root gains no second directory.

| Surface | Value |
|---|---|
| Prose | **agent-templates home** |
| Default path | `<resolved-agent-records>/templates` (i.e. `.records/templates` when the records home is the default) |
| Per-skill lock-in | `<agent-templates>/<skill>/` — `.records/templates/notepad/notes.md` |
| Front-door declaration | `agent-templates: <rel>` — **override only** |
| Legacy declaration | none. Flat `<agent-records>/templates/<doctype>.md` is a brownfield *source*, not the lock-in path |
| Resolver | first `^agent-templates:` in `AGENTS.md`, then `CLAUDE.md`; else `<resolved-agent-records>/templates` |
| Verb / mint-script argument | the resolved path (mint scripts do not scan the front door) |
| State-analysis helper | n/a this unit (no helper keys off the templates home) |
| Script fact key | `agent-templates=` |

One `agent-records:` line moves both homes. Declare
`agent-templates:` only when schemas must live somewhere
else. Journal does not create `templates/`. The first
skill that copies a declared project template creates
`<agent-templates>/<skill>/` (and thus `templates/` if
needed). Legacy flat files are **siblings** of the skill
dirs (`.records/templates/notes.md` vs
`.records/templates/notepad/notes.md`); adopt copies
flat → skill dir and does not delete the flat file.

**Resolution, per declared project template `<file>`:**

The **verb** resolves both homes (inlined front-door
scan) and passes them into the mint script. The mint
script never opens `AGENTS.md` / `CLAUDE.md`.

1. `<agent-templates>/<skill>/<file>` if present → use it
   (incumbent; never overwrite).
2. Else, **only for store-named lock-ins** (the
   filename stem *is* the store: `notes.md`, `bugs.md`,
   `tickets.md`, `trackers.md`, `plans.md`, `design.md`,
   `adr.md`, `reports.md`): if
   `<agent-records>/templates/<doctype>.md` is present
   (legacy flat) → copy that file to
   `<agent-templates>/<skill>/<file>`, then use the new
   path. Do not delete the old file this unit.
   **Body scaffolds skip this step** (`spec.md`,
   `plan.md`, `roadmap.md`, `investigation.md`) — they
   have no legacy flat name, with one exception:
   **Blueprint one-time adopt.** Today's lazy-deploy
   copies bundled `templates/spec.md` to
   `<agent-records>/templates/design.md`. That file
   *is the body scaffold* (`doctype: design` plus
   Problem/Goal/…). If it exists and
   `<agent-templates>/blueprint/spec.md` does not,
   copy it to **`spec.md`** (the body). Never adopt
   it as the new `design.md` shell — that shell
   comes from the bundled `templates/design.md` in
   step 3. Do not overwrite a project `spec.md`
   with stock after that adopt. A stray
   `<agent-records>/templates/spec.md` (unusual) is
   also adopted as `spec.md` only.
3. Else copy the bundled `templates/<file>` to
   `<agent-templates>/<skill>/<file>`, then use it.

Package-only templates skip this resolver. They are read
from the skill's own `templates/` and are never copied
into the project.

**Mint-script signatures** (both homes are arguments):

```
note-mint.sh   mint  <agent-records> <agent-templates> <title>
record-mint.sh mint  <agent-records> <agent-templates> <doctype> <title>
```

`stamp` keeps `<agent-records> <abs-path>` (no template).
Records-mode uses `records.sh new --template <resolved>`
and **never** writes the *flat*
`<agent-records>/templates/<doctype>.md`. The
skill-namespaced path
(`<agent-records>/templates/<skill>/<file>` under the
default) is the lock-in dest.

**`records.sh new` gains `--template <path>`.** Writers
always pass the resolved project path. Under the default
that path is *inside* the records home
(`.records/templates/<skill>/<file>`). If
`agent-templates:` is declared it may live outside.
Do not require a `$RR` prefix and do not reject a
path for being under `$RR`. Omitting `--template`
keeps today's `$RR/templates/$doctype.md` lookup so a
brownfield home still mints.

### The record-writer rule (doctrine)

Add a section **Record-writing skills** to
`skills/skill-builder/docs/DOCTRINE.md`, after *Front-door
variables*. It is portable (any skills library, not just this
pack). Rules:

1. **Destination.** A typed record is written under the
   agent-records home (resolver above). Skill prose keeps
   naming the default path literally. **Mint/write
   scripts** take resolved paths as arguments and do not
   scan the front door. **State-analysis helpers** that
   must emit `agent-records=` without a verb (today
   `workstream-git.sh`) inline the resolver and accept
   both declaration names. Doctrine's two-readers
   paragraph is rewritten to this split.
2. **Carry your templates; declare the lock-in set.** A skill
   that mints store `D` bundles `templates/D.md` (five keys +
   `<title>` / `<date>`). Body scaffolds may also live in
   `templates/`. A `## Project templates` list in `SKILL.md`
   names every bundled file that is project-lock-in (copied
   to the agent-templates home). Files not on the list are
   package-only. The review brief flags: a writer whose
   store has no in-package doctype template; a list entry
   with no bundled file; a copy of a file the list does
   not name.
3. **Own-store standup.** On first write, `mkdir` that skill's
   store (and the agent-records home directory if needed). Do
   not create `scripts/records.sh`, `history.tsv`, other
   stores, the records README, or the *flat*
   `<agent-records>/templates/<doctype>.md`. Creating
   `<agent-records>/templates/<skill>/` on first
   lock-in copy is required.
4. **No floor.** Missing `records.sh` is not an error.
   Journal standup is never a precondition. A
   description must not say the skill requires a
   stood-up records layer. A verb must not refuse
   and send the operator to journal standup.
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
   `new --template <resolved>` / `touch` / `done` / `list`.
   Otherwise write the same contract shape from the
   resolved template, with the same `fill` / slug /
   collision rules notepad already copied from
   `skills/journal/scripts/records.sh`. Resolution is the
   agent-templates rule above. Never write a second
   copy at the *flat*
   `<agent-records>/templates/<doctype>.md`.
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

### Template inventory (who carries what; who declares lock-in)

Each skill's `SKILL.md` gets a `## Project templates` list.
The table is this unit's initial declaration — a skill may
shrink or grow the list later without a doctrine change.
Package-only files stay in the skill and are never copied.

| Skill | Bundled | Project templates (lock-in) | Package-only |
|---|---|---|---|
| `notepad` | `notes.md` | `notes.md` | — |
| `backlog` | `bugs.md`, `tickets.md`, `trackers.md` | those three | — |
| `blueprint` | `design.md` (add, doctype shell), `adr.md`, `spec.md`, `founding.md` | `design.md`, `adr.md`, `spec.md` | `founding.md` (cwd working file, not a project record schema) |
| `contractor` | `plans.md`, `plan.md`, `roadmap.md` | those three | — |
| `debugger` | `reports.md` (add), `investigation.md` | `reports.md`, `investigation.md` | — |
| `auditor` | `reports.md` (add) | `reports.md` | rubric seed (`BOOTSTRAP.md`, `rules/`) is a different home |
| `workstream` | `plans.md` (add), `reports.md` (add), hand-off, compaction-anchor, intake templates | `plans.md`, `reports.md` | hand-off, compaction-anchor, coordinator, `kind: workstream-template` intake files |
| `journal` | `reports.md` | **none** | `reports.md` is the contract example. Setup copies nothing. |
| `analyst` | `briefing.md`, `status.md`, `subsystem.md`, `diagnostics.md`, `guide.md` | those five (already deploys to `<agent-records>/templates/analyst/`) | — |

A skill does not carry templates for stores it does not mint.
Auditor and debugger do not carry `bugs.md` this unit
(impersonation rule, below).

### skill-builder — observe and enforce

`skill-builder` is how this rule stays true after the
fold. Three verbs, one job each. No new verb.

**Observe — doctrine + `new`.**

- `docs/DOCTRINE.md` gains **Record-writing skills** (the
  rule set above) and the two front-door homes. That is
  a `calibrate`-shaped fold: the doctrine is the living
  home; this spec is the argued change.
- `verbs/new.md` asks, after the tier question and
  orthogonal to it: *will this skill write typed records
  into the agent-records home?* Yes → scaffold, in
  `SKILL.md`:
  - the inlined agent-records / agent-templates
    resolvers (default paths named literally);
  - the five-key in-package contract;
  - a no-floor sentence (missing `records.sh` is not
    an error; journal standup is never a
    precondition);
  - `## Project templates` (named files, or an explicit
    "none" if it writes records but locks nothing in
    yet).
  - Not automatically durable-home. Notepad is the
    worked example of a records-path client.
  No → do not add those sections.

**Enforce — `check` (mechanical) + `review` (judgment).**

`scripts/skills-lint.sh` grows two checks (header
inventory updated). Each is proven red on
deliberately-broken input before the green is trusted
(doctrine: prove a new check by breaking it). Journal
is exempt from the floor-phrase check (it may document
its own setup). `skill-builder` is exempt from the
floor-phrase check (it is the enforcer; its doctrine
and `new` describe the hole without being a floor).
Pack faces are exempt from both, same as today's
independence checks.

1. **Journal-floor phrase (FAIL).** A non-exempt
   skill's `.md` matches `Requires a stood-up records
   layer` or `stop and point at \`/journal setup\``.
   Evidence: skill, file, line. Match is
   **case-sensitive** (the live Guard uses that
   exact capitalization). Do **not** match a
   prohibition ("journal standup is never a
   precondition") — that is how `new` / doctrine
   state the rule. Do not use `grep -i` (the
   skill-review brief cites the floor in lowercase
   as a finding description). The Verification grep
   uses these same two phrases and the same
   exemptions (`journal`, `skill-builder`, pack
   faces). The live backlog Guard is the first
   plant.
2. **Project-templates heading (FAIL).** The skill
   has `templates/*.md` and `SKILL.md` has no heading
   `## Project templates`. Journal has `reports.md`
   and must carry the heading with an explicit none
   (or an empty list). A skill with no `templates/`
   dir is out of scope.

**Activation (so slice 1 does not maroon the live
tree at FAIL):** slice 1 implements both checks,
proves them red on fixtures, and **enables check 2
on the live tree** only after heading-only edits
land on **every** current `templates/*.md` skill:
notepad, backlog, blueprint, contractor, debugger,
workstream, journal (explicit none),
`agent-council` (explicit none — `ballot.md` /
`review.md` are package-only), and `analyst`
(the five catalog files). Check 1 stays
fixture-only until the end of slice 2, when the
backlog floor phrases are gone; then it joins the
live run. A live-tree `fails=0` after slice 1
includes check 2 and excludes check 1. After slice 2
it includes both.

List-vs-disk (a listed file missing from `templates/`)
and "copied a file the list does not name" stay on
**review** — parsing an arbitrary list in lint is
fragile; those are substance.

`skills/agent-council/briefs/skill-review.md` — extend
**Independence** and **Output shape**, no new axis:

- **Independence.** If the skill writes typed records, it
  must not require a sibling standup or an executable
  `records.sh` as a floor. A stop that treats journal
  standup as a precondition is a finding. A description
  that requires a stood-up records layer is a finding.
- **Output shape.** If it produces a record, the destination
  is `<agent-records>/<store>/` (default `.records/<store>/`),
  not a confirmed `docs/` fallback and not "skip, write
  nowhere." The in-package contract (five keys, dated slug)
  is specified in the package. Every store it mints has
  `templates/<doctype>.md` in the package. A `## Project
  templates` list names the lock-in set; every listed file
  exists in the package; the skill does not copy a file
  the list does not name. Project copies land under
  `<agent-templates>/<skill>/`.

`/skill-builder review` does not change its verb file;
it already judges only the axes the brief names.
`calibrate` is not run as a slice — the doctrine fold
in slice 1 *is* the calibration for this decision.

### Journal

Setup shrinks to the **tool layer**.

`scripts/standup.sh` creates only:

- the agent-records home directory itself (default `.records/`);
- `scripts/records.sh` (`scripts/` is journal's tool folder,
  not a store — reserved, same as today);
- empty `history.tsv`;
- `README.md` if absent (worded for the slim layer: stores
  appear when a skill first writes; project templates live
  in the agent-templates home and arrive with the writer).

It does **not**:

- `mkdir` `adr` / `bugs` / `design` / `notes` / `plans` /
  `reports` / `tickets` / `trackers`;
- write `.gitkeep` anywhere;
- pre-seed `templates/` or copy `reports.md` (the first
  writer creates `<agent-templates>/<skill>/`);

Exit 2 (already stood up) keys **only** on
`scripts/records.sh` present — not on `templates/`. A home
that merely exists (legacy path, or a notepad-created
`.records/notes/` with no tool) is still fine: standup is
additive and writes the tool beside what is there.

`verbs/setup.md` drops the sentence that clients stop and
point here, and drops "stand up the eight stores." It
resolves the home with the both-names rule
(`agent-records:` preferred, `records-root:` accepted,
else `.records`) and passes the rel path to
`standup.sh` (the flag may stay `--records-root`; the
*scan* is what changes). Done-when becomes: tool +
ledger + README; no store directories.

`SKILL.md` still *defines* the eight store names and the
five-key contract. It is rewritten so it no longer
teaches the old mint:

- **Template convention:** `records.sh new <doctype>
  --template <resolved>` mints from the caller-supplied
  path (usually
  `<agent-templates>/<skill>/<doctype>.md`). Omitted
  `--template` still reads
  `$RR/templates/<doctype>.md` (brownfield). The
  minting skill owns the bundled template and copies
  it to the **agent-templates home**, never to
  `.records/templates/`. Journal's in-package
  `reports.md` is the contract example only; setup
  copies nothing.
- **Shared discipline resolver:** both names
  (`agent-records:` preferred, `records-root:`
  accepted, else `.records`). `done` / `curate` use
  this scan so a host that only declared
  `agent-records:` is not silently aimed at
  `.records/`.
- **Dispatch / intro:** setup stands the tool layer,
  not "stores + templates." Drop "clients lazy-deploy
  into `.records/templates/`" as citable contract.
  Client skills state the in-package contract; they
  do not send the agent here for those bytes.
- **`## Project templates`:** explicit none.

`curate` already owns ledger-coherence repair; no new
verb. File-mode closes are a curate input, not a
setup trigger.

`scripts/tests/standup-test.sh` is rewritten against the
slim layer: no store dirs, no deployed `reports.md`, no
`.records/templates/`, `scripts/records.sh` + `history.tsv`
+ README present, exit 2 still fires when `records.sh`
already exists.

`scripts/records.sh`: `new` accepts `--template <path>`
(required by writers in this unit; omitted → today's
`$RR/templates/$doctype.md`). Tests cover both arms.

`skills/clankshop/scripts/tests/setup-journal-test.sh`
currently `cp`s `trackers.md` into
`.records/templates/` (the directory standup plants
today). Slice 1 updates that fixture: `mkdir -p` is
not enough after standup stops creating `templates/`
— pass `--template` to `records.sh new` (or
`mkdir -p` the dest dir before the `cp`). Do not
assume standup still plants `templates/`.

`description:` stays setup / done / curate / the contract.
Journal does not become optional in the pack
(`PACK.md` `required: journal` stays — the workshop's
records step still delegates here).

`records.sh new` already `mkdir -p`s the doctype directory.
That stays — the *mint*, not standup, creates the store.

### Notepad

Carries `notes.md` and already file-mode mints. It does
**not** already conform: today's `note-mint.sh` still
lazy-deploys into the **flat**
`<agent-records>/templates/notes.md` when `records.sh`
exists. Slice 3 writes only
`<agent-records>/templates/notepad/notes.md`. The
general adopt rule (flat `<doctype>.md` → skill dir)
covers a leftover flat file if one appears; if it
does not exist, there is nothing to copy. Invert
`note-mint-test.sh`'s "lazy-deploy copied template"
assertion to the nested dest.

Also take both homes, resolve through the
agent-templates rule, update resolver prose, and
have verbs pass both homes on `mint`. `## Project
templates` lists `notes.md`.

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
  record-mint.sh mint  <agent-records> <agent-templates> <doctype> <title>
  record-mint.sh stamp <agent-records> <abs-path> [--status <status>] [--note "<text>"]
  ```

  Bundled template is `templates/<doctype>.md` (`bugs`,
  `tickets`, `trackers` — already present and declared
  project templates). File-mode creates only
  `<agent-records>/<doctype>/`. Same stdout keys as
  `note-mint.sh`. Same `fill` / slug / collision /
  `file_stamp`. Resolves each declared template through
  the agent-templates rule; never writes `history.tsv`.
- `## Project templates` lists `bugs.md`, `tickets.md`,
  `trackers.md`.
- Tests: `scripts/tests/record-mint-test.sh` + `run.sh`,
  same fixture style as notepad (no `.records/` in this
  repo). Cases: no `records.sh` → store + five keys +
  `mode=file`; with `records.sh` → `mode=records` and
  `--template` from the agent-templates path; stamp closing
  status without `records.sh`
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
  resolved project template; stamp-only close). Do not
  create `.handbook/`.
- **Records-mode mint:** resolve via the agent-templates
  rule, pass `records.sh new --template <resolved>`,
  never write the flat
  `<agent-records>/templates/<doctype>.md`. Same for the
  next-plan draft and an optional debrief report.
- **Carry and declare** `templates/plans.md` and
  `templates/reports.md` as project templates. Hand-off,
  compaction-anchor, coordinator, and intake templates
  stay package-only.
- **Do not impersonate backlog.** Do not mint a Backlog
  tracker. Tracker-line completion runs only when that
  tracker file already exists (flip `[ ]` → `[x]`,
  opportunistic `touch`). Else record the ship in the
  plan close / hand-off / the project's own tracker
  layout, as today on a non-workshop host.
- `create` step 5: a new untracked plan moves to
  `<agent-records>/plans/` on every host, with contract
  front-matter (`records.sh new --template <resolved>`
  or file-mode fill from the resolved `plans.md`).
- `ship` step 1: opportunistic `records.sh done`; else
  file-mode stamp of the plan. Ledger commit path only
  when `history.tsv` was actually written.
- Next-plan draft (delegate mode): same destination,
  same `--template` / file-mode path.
- `scripts/workstream-git.sh` `resolve_records_root`
  today scans `^records-root:` only. Update it to the
  both-names resolver and print `agent-records=`. A
  host that declares only `agent-records:` must not
  send `drafted_next_plan` at the default `.records`.

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
- `## Project templates` lists `design.md`, `adr.md`,
  `spec.md`. `founding.md` is package-only.
- Records-mode: resolve `design.md` / `adr.md` via the
  agent-templates rule, `records.sh new --template
  <resolved>`. File-mode: write from that same
  resolved path. Never write the flat
  `<agent-records>/templates/<doctype>.md`.
  Then fill the body from the resolved `spec.md` (or
  the ADR body).
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
- `## Project templates` lists `plans.md`, `plan.md`,
  `roadmap.md`.
- Records-mode: resolve `plans.md` via the
  agent-templates rule, `records.sh new --template
  <resolved>`, then fill the body from the resolved
  `plan.md` / `roadmap.md` / runbook conductor.
  File-mode: write the resolved plans shell then the
  same body fill. Never write the flat
  `<agent-records>/templates/<doctype>.md`.
  "As today" is **not** the path — today lazy-deploys
  into the flat `templates/<doctype>.md`.
- Build / review verbs do not mint.

### Debugger

The stamp still picks the diagnostics playbook and still
gates Phase 4 (fix landing is not a record question).
The report is a record on every host:

- After Phase 3, mint a `reports/` record under the
  agent-records home. Resolve `reports.md` via the
  agent-templates rule; `records.sh new --template
  <resolved>` when the tool exists; else file-mode
  from that path + the resolved `investigation.md`
  body. Never write the flat
  `<agent-records>/templates/<doctype>.md`.
- Unstamped Done-when loses "No mint."
- Do not mint `bugs/` (backlog's store). A deferred
  defect still graduates through the host's bug lane.
- Bundle `templates/reports.md` (copy of journal's
  in-package example, not sourced).
- `## Project templates` lists `reports.md`,
  `investigation.md`.

### Auditor

The stamp still picks the rubric home (guardian doctrine
vs confirmed `docs/audit/`). That home is **not** a
record. The pass report is:

- Always a `reports/` record under the agent-records
  home, tagged `audit`. Resolve `reports.md` via the
  agent-templates rule; `records.sh new --template
  <resolved>` when the tool exists; else file-mode
  from that path. Drop the standalone
  `<home>/YYYY-MM-DD-audit-<scope>.md` path. Never
  write the flat `<agent-records>/templates/<doctype>.md`.
- Carry `templates/reports.md`. `## Project templates`
  lists that file.
- **Do not mint `bugs/` this unit.** Auditor has no
  `bugs` template and must not read backlog's package
  or a leftover `.records/templates/bugs.md`. Defects
  stay in the reports record; the operator files
  `/backlog bug` to promote one. Same
  drain-without-impersonation rule as workstream vs
  the Backlog tracker.
- **`BOOTSTRAP.md` and the §12 GUIDE skeleton** still
  say a workshop drain is "bugs records + tracker
  lines" (live §2 `<drains>`, §7, §12). A pass
  follows `GUIDE.md`. Rewrite those slots to: report
  record + `/backlog bug` for defects; tracker lines
  only when the tracker file already exists. Do not
  leave a deployed GUIDE teaching `records.sh new
  bugs`.
- Tracker-line drain: only when the tracker file
  already exists. Else the report is the queue.

### Analyst (landed on `main` 2026-08-18)

Already deploys to
`<agent-records>/templates/analyst/` via
`scripts/analyst-deploy.sh` (never-overwrite, no
floor). That dest **is** this unit's default. Still
fold:

- `## Project templates` lists the five catalog
  files (Slice 1 heading; Slice 3 can fill the
  names).
- Both-names records resolver (`agent-records:` +
  `records-root:`).
- Persist path: `records.sh new reports --template
  <resolved>` (it currently mints bare). File-mode
  on a host with no tool.
- Deploy when the records home exists, not only on
  a workshop stamp (the script already keys on the
  directory).

Files: `SKILL.md`, `scripts/analyst-deploy.sh`,
`scripts/analyst-facts.sh`, deploy/facts tests.

### Clankshop / PACK.md

`setup` / `migrate` still delegate the tool-layer standup
to journal. That is the workshop onramp, not a client
refuse. They must not grow their own store `mkdir`s to
"help."

`check` / `setup` / `migrate` resolve the agent-records
home with the both-names rule (`agent-records:`
preferred, `records-root:` accepted, else `.records`).
A host that only declares `agent-records:` must not be
told the layer is absent at default `.records/`.
Prose that says journal standup creates "stores,
templates" is updated to the tool layer (scripts +
ledger + README). Files: `SKILL.md` (face blurb:
records layer is `records.sh` + ledger, not
"templates + scaffolding"), `verbs/check.md`,
`verbs/setup.md`, `verbs/migrate.md`.

`PACK.md` roster blurbs that call backlog "a client of
the deployed records layer" and auditor "drains findings
into the records when a workshop is present" get one-
line updates so the face does not restate the old floor.
No `version:` bump (member set unchanged).

### Scope of work (this unit)

| In | Out |
|---|---|
| Doctrine: both homes + Record-writing skills | Migrating this library's `docs/design/` / `docs/BACKLOG.md` into `.records/` |
| `skill-builder new` scaffold for record-writers | A new skill-builder verb |
| `skills-lint.sh` journal-floor + Project-templates heading, with red-proofs | Lint that parses the project-templates *list* vs disk |
| Skill-review brief Independence / Output shape | Renaming `.records/` or dropping `records-root:` |
| Journal tool-layer standup; `SKILL.md` contract rewrite; `records.sh --template` (path may be outside `$RR`) | Journal creating any store dir or `templates/` |
| Backlog: drop the floor, `record-mint.sh`, project templates | Giving every writer a mint script |
| Destination flip: workstream, blueprint, contractor, debugger, auditor, notepad (incl. verbs) | Debugger Phase 4 workshop gate; auditor rubric-home probe; auditor minting `bugs/` |
| Each writer: bundled doctype template + `## Project templates` | Copying undeclared / skill-internal templates |
| Clankshop / PACK.md roster wording (no version bump); `setup-journal-test.sh` `--template`; check/setup/migrate both-names resolver | Making journal optional in the pack; moving `records.sh` out of `scripts/` |
| `workstream-git.sh` both-names resolver | — |
| `note-mint.sh` both-homes signature; never write the flat `<doctype>.md` | — |
| Brownfield adopt of `.records/templates/<doctype>.md` into the agent-templates home | Deleting legacy `.records/templates/` this unit |

### Out of scope (recap)

- Standing `.records/` up inside this library as a
  migration of `docs/design/` / `docs/BACKLOG.md`.
- Renaming the default directory off `.records/`.
- Dropping the `records-root:` alias this unit.
- A top-level `.templates/` default.
- Flat `.records/templates/<doctype>.md` as the lock-in
  path (legacy adopt-only).
- Putting project templates under `.agents/`.
- A `templates/lock-in` manifest besides `SKILL.md`.
- Copying every bundled template by default.
- A lint that parses the project-templates list.
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
  cd <worktree> && rg -n 'Requires a stood-up records layer|stop and point at `/journal setup`' \
    skills --glob '!**/docs/**' --glob '!**/skill-builder/**'
  ```

  Journal and skill-builder are exempt. After slice 2,
  `skills/backlog/` is empty of those strings. After
  slice 3, no writer skill carries them.
- Journal standup test rewritten: after `standup.sh` on
  a bare fixture, the home has `scripts/records.sh`,
  `history.tsv`, `README.md`, and **none** of
  `adr/ bugs/ design/ notes/ plans/ reports/ tickets/
  trackers/ templates/`.
- `records.sh new --template` writes from the given path;
  omitted `--template` still reads
  `$RR/templates/<doctype>.md`.
- Each writer's `## Project templates` list exists; every
  listed file is on disk in the package; no unlisted file
  is copied in tests.
- `cd <worktree> && skills/notepad/scripts/tests/run.sh`
  stays green (reference implementation).
- `cd <worktree> && skills/backlog/scripts/tests/run.sh`
  (new): file-mode mint, records-mode mint, no
  `history.tsv` on file-mode close, missing template
  errors. Red-proof the absence: plant a
  `history.tsv` write on the file-mode close path,
  demand the test FAIL, then remove the plant.
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
  root," and "agent-templates home" for the schema path.

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

**Red-proof for the new lint checks.** Plant
`Requires a stood-up records layer` in a throwaway
non-exempt `SKILL.md` and confirm check 1 FAILs;
remove it and confirm green. Plant `journal standup
is never a precondition` in the same file and
confirm check 1 stays green (prohibition must not
match). Plant a skill with `templates/foo.md` and
no `## Project templates` and confirm check 2
FAILs; add the heading and confirm green. Do not
land either check on a first clean run.

## Slices

This spec doubles as the plan. Sequencing is required
(doctrine and the enforcer first, then the pain, then
the other writers). A separate contractor plan is not
required unless a later flip changes a slice boundary.

- [x] **Slice 1: doctrine + skill-builder + journal tool-layer**
  <requires: —>
  - Paths: `skills/skill-builder/docs/DOCTRINE.md`;
    `skills/skill-builder/verbs/new.md`;
    `skills/skill-builder/scripts/skills-lint.sh`;
    `skills/skill-builder` lint-check tests (or the
    existing prove-by-breaking fixture pattern);
    `skills/agent-council/briefs/skill-review.md`;
    `skills/journal/SKILL.md` (template convention,
    both-names resolver, `## Project templates` none,
    setup = tool layer);
    `skills/journal/verbs/setup.md`;
    `skills/journal/scripts/standup.sh`;
    `skills/journal/scripts/records.sh` (`--template`);
    `skills/journal/scripts/tests/standup-test.sh`;
    `skills/journal/scripts/tests/records-test.sh`;
    `skills/clankshop/scripts/tests/setup-journal-test.sh`;
    `skills/clankshop/SKILL.md` (face blurb: records
    layer is `records.sh` + ledger, not templates +
    scaffolding);
    `skills/clankshop/verbs/check.md`,
    `verbs/setup.md`, `verbs/migrate.md` (both-names
    resolver; journal standup = tool layer);
    heading-only `## Project templates` on
    `skills/{notepad,backlog,blueprint,contractor,debugger,workstream,journal,agent-council,analyst}/SKILL.md`;
    optionally `skills/clankshop/PACK.md` roster blurbs.
  - Verify: lint `fails=0` on the live tree. Doctrine
    names both homes; `new` asks the record-writer
    question; both new lint checks have a red-proof
    then green. Brief Independence / Output shape name
    the records-writer, declaration, and
    agent-templates checks. `setup.md` no longer says
    clients stop and point here. Standup test: no store
    dirs, no deployed `.records/templates/`.
    `records.sh new --template` covered (path outside
    `$RR` accepted). Journal `SKILL.md` no longer
    teaches `.records/templates/` lazy-deploy or a
    `records-root:`-only scan. Every
    template-bearing skill (incl. journal none) has
    `## Project templates`. Check 2 live-green;
    check 1 fixture-red then fixture-green, not yet
    on the live run.
- [x] **Slice 2: backlog writes without a floor**
  <requires: 1>
  - Paths: `skills/backlog/SKILL.md`;
    `skills/backlog/verbs/*.md`;
    `skills/backlog/scripts/record-mint.sh` (new);
    `skills/backlog/scripts/tests/` (new).
  - Verify: grep gate empty under `skills/backlog/`.
    `scripts/tests/run.sh` green. Description ≤ 1024
    chars and names no sibling. `## Project templates`
    lists the three doctypes. Check 1 enabled on the
    live run; lint `fails=0`.
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
    `BOOTSTRAP.md` (drain slots + §12 GUIDE
    skeleton: no `bugs` mint),
    `templates/reports.md`;
    `skills/notepad/SKILL.md`,
    `verbs/*.md`,
    `scripts/note-mint.sh`,
    `scripts/tests/note-mint-test.sh`;
    `skills/workstream/scripts/workstream-git.sh`;
    `skills/analyst/SKILL.md`,
    `scripts/analyst-deploy.sh`,
    `scripts/analyst-facts.sh`,
    `scripts/tests/deploy-test.sh`.
  - Verify: grep gate empty under `skills/`. No
    writer confirms a `docs/` output home for a typed
    record. Workstream Host layout no longer says
    "do not create `.records/`." Debugger unstamped
    Done-when no longer says "No mint." Inventory
    table complete on disk. Each writer has `## Project
    templates`. Every records-mode mint passes
    `--template`. Notepad verbs pass both homes.
    Auditor `BOOTSTRAP.md` drain slots no longer
    say workshop `bugs` records.
    Prose says "agent-records home" and
    "agent-templates home." Lint `fails=0`.

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
| `.agents/templates/<skill>/` | Collides with `~/.agents/` |
| Top-level `.templates/` default | Root pollution; nest under the records home |
| Flat `.records/templates/<doctype>.md` as lock-in | One `reports.md` for every writer; skill-namespace instead |
| Copy every document-creating template | Not every bundled file is a project schema; the skill declares the set |
| A `templates/lock-in` manifest | Second roster; `SKILL.md` is the declaration |
| Lint that parses the project-templates list | Fragile; review owns list-vs-disk and undeclared copies |

## Review history

Independent `/blueprint review` 2026-08-18 (`needs-rework`).
Must-fixes folded the same day. Owner prunes this
section when the next review is clean.

1. **high — Slice 1 Paths omitted heading-only edits.**
   Folded: every current `templates/*.md` skill
   (incl. `agent-council` none) is on the Slice 1
   path list; check 2 enables only after those
   headings land.
2. **high — Mint scripts cannot apply the
   agent-templates rule.** Folded: both homes are
   arguments; verbs scan, mint scripts do not;
   notepad `note-mint.sh` is a Slice 3 behavior
   change, not wording-only; records-mode never
   writes `.records/templates/`.
3. **mid — `setup-journal-test.sh` assumes standup
   plants `templates/`.** Folded: file is on Slice 1;
   fixture uses `--template` (or `mkdir -p` before
   `cp`).
4. **mid — `workstream-git.sh` scans `records-root:`
   only.** Folded: both-names resolver; script on
   Slice 3; doctrine two-readers paragraph split
   (mint scripts take paths; state-analysis helpers
   inline the resolver).
5. **mid — Legacy adopt had no file→doctype map.**
   Folded pass 1 (incomplete). Pass 2: live dest is
   `.records/templates/design.md` and *is the body*.
   Refolded: adopt that file as `spec.md`; never as
   the new `design.md` shell.
6. **low — File-mode no-`history.tsv` lacked a
   red-proof.** Folded: plant a write, demand red,
   remove the plant.

Independent `/blueprint review` pass 2, 2026-08-18
(`needs-rework`). Must-fixes folded the same day.

1. **high — Check 1 / grep match the no-floor
   wording this spec plants in skill-builder.**
   Folded: check 1 + grep match `Requires a stood-up
   records layer` or `stop and point at \`/journal
   setup\``; skill-builder and journal exempt;
   `new` / doctrine say "journal standup is never a
   precondition"; red-proof that the prohibition
   stays green.
2. **high — Auditor `bugs/` mint has no template
   after this unit.** Folded: auditor does not mint
   `bugs/` this unit; defects stay in the report.
3. **mid — Slice 3 writer bullets still said
   `records.sh new` as today.** Folded: each writer
   resolves via the agent-templates rule and passes
   `--template`; never writes `.records/templates/`.
4. **mid — Slice 3 omitted notepad verbs.** Folded:
   `skills/notepad/verbs/*.md` on the path list.
5. **mid — Door resolvers outside workstream-git.sh
   stayed `records-root:`-only.** Folded: journal
   `setup.md` and clankshop check/setup/migrate use
   both names; clankshop prose describes the tool
   layer.
6. **low — `/journal check` is not a verb.** Folded:
   `records.sh check` / `/journal curate`.

Independent `/blueprint review` pass 3, 2026-08-18
(`needs-rework`). Must-fixes folded the same day.

1. **high — Journal `SKILL.md` still taught the old
   mint.** Folded: rewrite template convention to
   `--template` + agent-templates home; both-names
   resolver on Shared discipline; setup = tool
   layer; `reports.md` example only.
2. **high — Auditor `BOOTSTRAP.md` / GUIDE skeleton
   still drained defects as `bugs` records.** Folded:
   `BOOTSTRAP.md` on Slice 3; drain slots + §12
   skeleton match "no `bugs` mint."
3. **Notes folded:** `--template` path may be
   outside `$RR`; check 1 is case-sensitive;
   clankshop face `SKILL.md` drops "templates +
   scaffolding."

Human amendment 2026-08-18 (after accept): default
agent-templates home is
`<agent-records>/templates/<skill>/`, not a
top-level `.templates/`. `agent-templates:` is an
override only. Flat
`<agent-records>/templates/<doctype>.md` stays
legacy adopt-only.

Sync 2026-08-18: rebased onto `main` @ `cd8ae03`
(21 incoming, no conflict). Folded: `analyst` already
deploys to `templates/analyst/` — treat as the
landed pattern; add to inventory + Slice 1 headings
+ Slice 3 resolver/`--template`. Notepad writes
`templates/notepad/notes.md` only; flat adopt
no-ops if the file is absent. Incoming
`records.sh` code-block link-check is orthogonal;
`--template` still lands on that file in Slice 1.

Independent `/blueprint review` pass 4, 2026-08-18
(`needs-rework` — one path-list miss). Folded the
same day: `skills/clankshop/SKILL.md` is on Slice 1
Paths. All fourteen prior findings were closed.
