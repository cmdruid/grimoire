---
doctype: design
status: current
created: 2026-08-21
updated: 2026-08-22
tags: [spec]
---

# Clankshop glue, hats off, `shopbook` — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here, on `stream/skills` until ship. It doubles as the implementation
plan.

Subject: drop hats from the pack face; `clankshop` seeds doctrine and
pack-owned flows; skills seed their own workspace files; an
**experimental** `shopbook` finds **or creates** a host procedure
under `<agent-workspace>/flows/` with **facts scripts** (no consult
child). The door is a **pointer** (where). Shopbook's
`description:` is who to ask. `upkeep` backfills crawl keys
(`title` / `use-when`) on flow files. `create` mints a host stub.
Brief: independent skills with public interfaces; the pack is
pre-packaged glue, not a role.

Settled 2026-08-21 on stream `skills`, amended 2026-08-22 from
`needs-rework`:

1. Drop the `/clankshop <persona>` verb **and** strip hats from the
   seed (identity preambles, `context.sh` persona aliases). Stations
   remain **places** (design/build/test/review chapters, load rule)
   with no actors.
2. `/clankshop setup` stays the pack onramp. It seeds doctrine **and**
   applies pack glue. The human types that command.
3. **Independent seeding.** A skill that needs a workspace file under
   `flows/`, `hooks/`, or `templates/` copies it itself (incumbent
   wins). `shopbook` never copies another skill's bundled files.
   Host-authored procedures go through `shopbook create`. The six pack procedures
   are **clankshop-owned** payload — the face copying them *is*
   clankshop seeding its own files. Those six **ship with** `title`
   and `use-when` already. Other skills that copy a flow include
   those keys. `workstream` still seeds `hooks/workstream.md`.
   Templates stay per-skill. Using those files *is* applying the
   glue; there is no composer skill.
4. `shopbook` is **experimental** (optional pack member). Job: query /
   list / search / **create** host procedures via **facts scripts**;
   the **calling** agent reads the one file and follows it, or
   authors the body of a new stub. `sync` repairs the door
   pointer. `upkeep` is ongoing crawl-key maintenance on `flows/`
   (missing `title` / `use-when` only). `create` mints a
   host-authored stub at `<ws>/flows/<stem>.md` (crawl keys + H1);
   it does not copy pack payload, does not overwrite incumbents,
   does not invent procedure steps. It does not seed another
   skill's files, does not edit `core/ROUTING.md`, does not spawn
   a consult child, does not run on `/clankshop setup`.
   Description matches query **and create** (procedure / workflow
   / playbook / routine / shopbook) and must not fire on
   build-station, v1-role, `/clankshop migrate`, **runbook**, or
   "file a bug" / "capture the repro." Dispatch applies to
   **every** invocation. Slash mint is `/shopbook create`. NL
   create/add/author + type noun → `create`. Slash look-up is
   `/shopbook query` (alias `list` / `search` / `find`). Slash
   tokens match **Invocation only**; Trigger is NL-only. A
   first token after `/shopbook` that is not a recognized
   Invocation
   (`/shopbook bug`, `/shopbook new bug`, `/shopbook add`,
   `/shopbook author`, `/shopbook foobar`, bare `/shopbook`) is
   **ask**, not a topic — `new` / `add` / `author` are not
   shopbook slash verbs. NL description-fire (how-do-we-X,
   start the env, publish) still runs `query`. NL "use the
   shopbook" with no further intent **asks**. A missing
   procedure is **not found** — do not invent it, do not
   mention another skill, do not require a workshop. `create`
   does not mint records. Shopbook `SKILL.md` and `verbs/` do
   not name `clankshop` and do not inventory pack stems. Do
   not write `verbs/new.md`, `verbs/add.md`, or
   `verbs/author.md`. The query walk lives in
   `verbs/query.md`. **Discovery:**
   the always-loaded door **pointer** says *where* procedures live
   (`<ws>/flows/`). Shopbook's `description:` says *who to ask* to
   find **or create** one. The door does not name `/shopbook`. An
   agent looking to create a workflow, routine, or procedure
   reaches for `shopbook`.
5. This is not v1 `foreman` (register-route, door `skill:` blocks,
   derive-seams, stamp health). That oven stays retired. **This
   skill is not named `foreman`.**
6. BL-36 is unparked **only** for the six seed workflow files →
   `flows/`. `spec/` station un-nest, lint 12–17 rewrite, and
   `auditor`'s `test/workflows/audit/` rubric home stay parked.
   After un-nest, that auditor path remains a second
   workflow-shaped tree (named, not implied gone).
7. Birth is face-owned: setup step 2 is **project payload**
   (`seed.sh` + incumbent-safe copy of **clankshop-owned** flows).
   Face `scripts/flows-door.sh` writes and checks the delimited door
   **pointer**. Setup does **not** invoke `/shopbook`. Guard 24–34 is
   quote-edited on all three arms (copy unfinished + pointer
   missing/malformed/wrong path).
8. The door **replaces** the ROUTING-compiled dispatch table with a
   **pointer** to `<ws>/flows/` (not a stem table). Classification
   walk stays in `core/ROUTING.md` (four rows), retargeted at
   `<agent-workspace>/flows/<stem>.md`. Four of the six files are
   classification lanes; `diagnostics.md` and `doc-audit.md` are
   chores. Host procedures (boot the env, publish a release) are
   more files in the same tree, not extra lanes.

## Problem

v2 bundled five retired **role skills** into the face as hats
(`docs/design/2026-08-10-clankshop-role-merge.md`), then as a
`/clankshop <persona>` summon plus second-person seed preambles.
Independent skills with a job beat hats. The summon is color: nothing
in the pack routes through it, and the description still triggers on
architect/foreman/guardian/admin.

The face is also two jobs in one skill: **workshop content** (doctrine
seed, glue recipes, `/clankshop setup`) and **workspace tending**.
Glue already has a surface (project hooks, shipped). Lanes still nest
under station chapters (`seed/build/workflows/` etc.), which is the
layout BL-36 deferred. The door's thin table is compiled from
`core/ROUTING.md`'s four dispatch rows — a hand-maintained copy of
those paths. Dumping every host procedure into `AGENTS.md` would
pollute the calling context the same way.

Host procedures are not harness-loaded (unlike skills). A large
project can hold many of them plus doctrine. The caller should not
ingest that corpus to pick one file. A finder skill plus a crawl of
small front-matter on each flow is how an agent reaches a procedure
without loading the catalog.

A returning `foreman` that authored doctrine or glue, or that
registered skills into `AGENTS.md`, would be the oven this library
already killed. This feature does not reuse that name.

## Goal

After this feature:

- No persona verb, no seed hats, no persona aliases. Stations are
  places. Clankshop's description no longer triggers on hat names.
- `/clankshop setup` (and `migrate`) still stand up the pack: doctrine
  seed, `flows/` copy, journal, door, pack glue. Pack-format §6
  stays: setup lives on the face. Atomic setup does **not** require
  `/shopbook`.
- Six **clankshop-owned** host-procedure files live at
  `<agent-workspace>/flows/<stem>.md` (default `.dev/flows/`): four
  classification lanes (`bug`, `patch`, `feature`, `spike`) and two
  chores (`diagnostics`, `doc-audit`). Each ships with `title` and
  `use-when`. Clankshop copies **its** files. Other skills copy
  **theirs**. Incumbent files are never overwritten.
  `auditor`'s `doctrine/test/workflows/audit/` stays nested (parked;
  still a workflow-shaped tree).
- The door carries a delimited **pointer** to `<ws>/flows/` (resolved
  path; "not loaded until one is selected"). It does **not** list
  stems, compile ROUTING.md, or name `/shopbook`. Classification
  walk stays in `core/ROUTING.md`.
- Face `scripts/flows-door.sh` is the one birth-time writer/checker
  of that pointer. `check` reports an unfinished copy and, when the
  payload exists, pointer drift via that **face** script. Adding a
  flow file does **not** drift the pointer.
- A new helper `shopbook` is **experimental** (optional pack member).
  Script-only find / list / search over `title` / `use-when` / stem /
  first heading. On one match, the **caller** follows that file.
  Several matches → print candidates and **ask**. `create` mints
  a host stub (crawl keys + H1); the **caller** authors the body.
  `sync` repairs the pointer. `upkeep` fills missing crawl keys
  only. Does not copy pack or sibling payload. Does not mkdir
  doctrine. Does not write `skill:` blocks. Does not edit
  `core/ROUTING.md`. Does not run on `/clankshop setup`.
  Description fires on run **and** create (workflow / routine /
  procedure / playbook / shopbook). Does not fire on runbook or
  "file a bug." Dispatch applies to every invocation. Slash
  mint is `/shopbook create`. NL create/add/author + type noun
  → `create`. Slash look-up is `/shopbook query` (no topic =
  list). Slash tokens match Invocation only. A first slash
  token that is not a recognized Invocation
  (including `add` / `author` / `new`) is **ask**, not a topic.
  NL description-fire still runs `query`. NL "use the shopbook"
  with no further intent **asks**. Shopbook does not require a
  workshop.
- Lint `fails=0`. Clankshop harness green. New `shopbook` harness
  green. Patient-zero: no live `/clankshop setup` in this library;
  fixtures only.

## Approach

**Chosen: content stays on the face; each owner seeds its own
workspace files; `shopbook` is an experimental finder **and
host-stub creator** (script search, caller follows; door is a
pointer; `create` mints a stub; `upkeep` for crawl keys).**

Clankshop keeps `seed/`, `seed.sh`, hooks fill, setup/migrate/check.
A sibling payload `skills/clankshop/flows/` holds the six
**clankshop-owned** files (with `title` / `use-when`) the face copies
to `<ws>/flows/`. `seed.sh` stays a doctrine-only projector
(`cp -R seed/ → <ws>/doctrine`); it must not grow a second
destination that would place `flows/` *inside* doctrine. Other
skills keep seeding their own `hooks/` and `templates/`. `shopbook`
copies none of those.

Setup **step 2** is **project payload**: `seed.sh` (skip if doctrine
present / it refuses) **then** incumbent-safe flows copy. Unfinished
= `$SKILL/flows` present AND a source stem missing at `$DST`. Resume
does not re-run `seed.sh`; it **does** run the copy arm. Guard range
stays (1–6).

Face `scripts/flows-door.sh` (`check|apply --root --workspace`) is
the one implementation of the delimited **pointer**. Setup/migrate
call `apply` after the copy, as part of the door step. `check` calls
`check` when `$SKILL/flows` is present. Shopbook (slice 3) bundles
an identical copy; tests pin byte-identity of the functional body
(comments stripped) — BL-6 accepted duplication. Setup never
invokes `/shopbook`.

Shopbook is journal-shaped **only** in independence: it runs bare. It
does not create the workspace home and does not copy another skill's
bundled files. `create` may mkdir `<ws>/flows/` under the same
narrow rule as hooks. Clankshop remains the workspace assembler.

**Discovery (where vs who).** Two always-loaded surfaces, two jobs.
The door **pointer** tells every agent *where* procedures live
(`<ws>/flows/`, not loaded until one is selected). It does not name
`/shopbook` and does not list stems. The shopbook **`description:`**
is *who to ask* — find **and create**. An agent looking to create a
workflow, routine, or procedure reaches for `shopbook`; that skill
**dispatches** every invocation (NL author a procedure or
`/shopbook create` → `create`; look one up → `query`).
Enter `verbs/create.md` only after dispatch chose `create`.
Enter `verbs/query.md` only after dispatch chose `query`.
The query walk lives in `verbs/query.md`. Slash look-up is
`/shopbook query` (alias `list` / `search` / `find`; no
topic = list). Slash tokens match **Invocation only**;
Trigger is NL-only. A first token after `/shopbook` that is
not a recognized Invocation is **ask**, not a topic (`new` /
`add` / `author` are not shopbook slash verbs). NL description-fire still
runs `query`. NL "use the shopbook" with no further intent
**asks**.
Shopbook does not require a workshop and does not name
`clankshop`. If `shopbook` is not installed, the
pointer still locates the tree; the agent may write a file
there by hand. A look-up that misses is "not found" — do not
mint, do not mkdir `$DST`. Harness `description:` fires on
"run **or create** a procedure / workflow / playbook / routine /
use the shopbook / start the env / publish." Does not fire on
runbook or "file a bug." `flows-index.sh` lists and searches;
**no consult child.**

The six files are not one kind. `core/ROUTING.md` still has **four**
dispatch rows, retargeted at `<agent-workspace>/flows/<stem>.md`.
Diagnostics and doc-audit are chores. Extra host procedures are
just more `flows/*.md`.

Flows are host procedures, not doctrine chapters. Debugger's
**location** probe becomes `<ws>/flows/diagnostics.md` when present;
the stamp stays the **policy** probe. Which-home and the stamp
paragraph are amended in slice 4 so they stop teaching “a build
lane / diagnostics playbook is doctrine.”

**Rejected: seed payload moves into `shopbook`.** Pack identity
would leave the face. Human: clankshop seeds doctrine.

**Rejected: `shopbook` projects `../clankshop/seed`.** Floor.

**Rejected: two-step onramp (`/shopbook setup` then `/clankshop
setup`).** Pack-format §6. Human types `/clankshop setup`.

**Rejected: restore v1 oven (register-route, `skill:` blocks,
derive-seams).** Skip `skill:` registration.

**Rejected: `clankshop setup` calls `/shopbook` as a required
step.** Birth is the face script.

**Rejected: two door tables or a stem catalog in `AGENTS.md`.**
Procedure routing in every prompt. The door is a pointer; the
tree is on disk; `shopbook` searches it.

**Rejected: a second `doctrine/ROUTING.md` or `shopbook` managing
`core/ROUTING.md`.** Change classification is pack doctrine.
Lookup is the search script over `flows/`.

**Rejected: a consult child / throwaway lookup agent this pass.**
Script + crawl keys. Vague queries become a candidate list and
an ask, not a synthesized runbook.

**Rejected: name this skill `foreman`.** Routing collision with
the retired hat and oven. Human: `shopbook`.

**Rejected: `/shopbook migrate`.** `/clankshop migrate` is the
brownfield workshop onramp. Upkeep of crawl keys is `upkeep`.

**Rejected: move `auditor`'s `test/workflows/audit/` into `flows/`.**
Parked. Named remaining nested tree.

**Rejected: `shopbook` copies pack or sibling payload into
`flows/`, `hooks/`, or `templates/`.** Independent seeding.
`hooks-glue.sh` stays on the face for birth fill. `create` mints a
*host-authored* stub; that is not seeding another skill's files.

**Rejected: name `/shopbook` in the door pointer.** The door is
where; the description is who. Naming the skill on `AGENTS.md` is
`skill:` registration lite.

**Rejected: `create` authors the procedure walk or dumps the
catalog.** Stub is crawl keys + H1; the caller writes the body.
Extra stems stay off the prompt.

**Rejected: `create` mints a record, or aliases a file-a-repro
verb.** `create` is host-procedure stubs only. Filing a dated
repro is not this skill. The guide path for "how do we handle
bugs here?" is **query** (NL, or `/shopbook query bug`) →
`flows/bug.md` (that file names the entry). Description does
not fire on "file a bug" / "capture the repro."

**Rejected: a `new` mint verb on `shopbook`.** Human: `create`
is the mint verb. Do not write `verbs/new.md`.

**Rejected: `/shopbook <query>` as a slash format, and `new`
as a look-up token.** A first token after `/shopbook` that is
not a known verb conflicts with other verbs. Look-up slash
form is `/shopbook query`. `/shopbook new <stem>`,
`/shopbook add`, `/shopbook author`, and `/shopbook bug` are
unknown → **ask**. NL description-fire still runs `query`.

**Rejected: slash `add` / `author` as mint tokens.** NL
create/add/author + type noun mints. Slash mint is only
`/shopbook create`. Do not write `verbs/add.md` or
`verbs/author.md`.

**Rejected: shopbook inventories pack stems, requires a
workshop, or names `clankshop`.** Looking up a procedure that
is not on disk is "not found." Authoring a new host procedure
is create-shaped `create`. Clankshop's copy remains incumbent-safe
on the **face** (that is not a shopbook list).

**Rejected: a glue-apply composer, a workflow engine, scheduling
verbs, or a persona brief in doctrine.** Using the files is the
glue. `upkeep` is crawl-key maintenance, not a maintenance-workflow
platform.

**Rejected: mint this spec into `.records/`.** Patient-zero.

**Rejected: keep persona aliases "for compatibility."** Delete the
hat layer.

**Rejected: the records five-key contract on flow files.**
Procedures are living and undated. Crawl keys are `title` and
`use-when` only.

## Mechanism

### Ownership

| Skill | Owns | Does not |
|---|---|---|
| `clankshop` | Pack face, doctrine seed, **its** six flow files (with crawl keys), glue *recipes*, `scripts/flows-door.sh`, `/clankshop setup` (payload + journal + door pointer + birth glue fill) | Hats, seeding another skill's `hooks/`/`templates/`/`flows/` |
| `shopbook` | Experimental finder + host-stub creator: query/list/search over `flows/` (script); caller follows; `create` mints a host stub (crawl keys + H1) when authoring; `sync` repairs the pointer; `upkeep` fills missing `title`/`use-when` | Copy pack or sibling payload, mint records, inventory pack stems, require a workshop, name `clankshop`, author procedure *bodies*, overwrite incumbents or existing crawl keys, edit `core/ROUTING.md`, `skill:` blocks, mkdir doctrine, birth-time setup, consult child |
| each other skill | Its own `hooks/`, `templates/`, and any skill-owned `flows/` file (with crawl keys) | Rely on `shopbook` or the pack face to copy those files |
| `journal` | Records home (already) | Doctrine, flows |

### Hats off

Delete `skills/clankshop/verbs/persona.md`. Drop the router row and
the description's persona clause and Use-when "talk to a station
persona." Drop PACK.md "persona summons."

Seed `POLICY.md` files (design/build/test/review): delete the identity
paragraph ("You are the architect/foreman/guardian/admin…") and the
H1 subtitle that is only the hat (`— the architect`). Keep standing
judgments as ordinary station-policy bullets. Drop seed README's
persona column, "own persona," and "Persona names are accepted as
station aliases." `context.sh`: drop persona aliases from usage,
comments, and `station_for` (stations only:
`design|build|test|review`). `seed-test.sh`: drop the alias
equality case and the "You are the guardian." render assert; assert
station names still render policy. `face-test.sh`: loop `setup
migrate check` only.

Library `AGENTS.md` / `README.md`: drop persona summons from the pack
blurb; stations without parenthetical hats. While editing those
rosters: add `shopbook` when slice 3 lands; `AGENTS.md` helper list
gains `notepad` and `analyst` (README already has them); `/skill-builder
distill` → `calibrate`; "seed handbook" → "seed doctrine."

Clankshop `SKILL.md` body: stations are a line of **places**, not
place-and-actor. "Each station's chapter opens in its persona's
voice" goes. Description keeps `setup`, `migrate`, `check`, and
Use-when for those; it may say the face seeds doctrine and applies
pack glue. Stay ≤1024, prefer ≤750. Do not list the four station
names as description triggers (finding 5, 2026-08-17 review, still
binds). Assets: add `flows/` as pack payload (slice 2).

### `flows/` (six host-procedure files)

Census of **seed** files that move (body unchanged except path
pointers; **add** crawl front-matter as they move):

| today (under `skills/clankshop/seed/`) | tomorrow (`skills/clankshop/flows/`) | kind |
|---|---|---|
| `build/workflows/bug.md` | `bug.md` | classification lane |
| `build/workflows/feature.md` | `feature.md` | classification lane |
| `build/workflows/patch.md` | `patch.md` | classification lane |
| `build/workflows/spike.md` | `spike.md` | classification lane |
| `test/workflows/diagnostics.md` | `diagnostics.md` | chore / playbook |
| `review/workflows/doc-audit.md` | `doc-audit.md` | chore |

Each payload file starts with:

```yaml
---
title: <short name>
use-when: <comma-separated trigger phrases>
---
```

Not the records contract. No `doctype` / `status` / dates. `title`
is one line. `use-when` is keywords the search script matches
(publish, cut a release, start the environment, …).

Delete the emptied `workflows/` directories from the seed. `seed/`
remains a byte-mirror of deployed `<ws>/doctrine/`. `seed.sh`
continues to `cp -R "$SEED" "$root/$ws/doctrine"` only.

**Setup step 2 — project payload** (two arms; still one numbered
step; Guard range (1–6)):

1. **Doctrine.** `scripts/seed.sh <root> --workspace …` as today.
   Present doctrine home → do not re-run (`seed.sh` refuses).
2. **Flows copy.** `SRC=$SKILL/flows`, `DST=$root/$ws/flows`. If
   `$SRC` is absent, skip. `mkdir` `$DST` only when `<ws>` already
   exists (arm 1 just created it, or it already existed) or the home
   is the derived default `.dev`. For each `$SRC/*.md`, copy **if
   the dest file is absent**; never overwrite an incumbent; do not
   delete extras already in `$DST`. A host file already at a pack
   filename is an incumbent; the face skips that file. Do not
   publish pack stem names to shopbook.

**Unfinished (copy):** `$SRC` present AND a source stem missing at
`$DST`. **Unfinished (door, step 4):** `$SRC` present AND the
flows pointer is missing, malformed, or its body does not contain
the resolved `<ws>/flows/` path as a literal. Missing crawl keys
are **not** setup-unfinished (that is `/shopbook upkeep`).

**Guard — quote-edit HEAD `setup.md` 24–34, all three arms**
(project-hooks G1). Range stays `(1–6)`.

1. **STOP / already-seeded.** Green-list extends: unfinished copy
   is false **and**, when `$SRC` is present, face
   `flows-door.sh check` is green. Unfinished hooks stay.
2. **Resume.** Parenthetical adds: unfinished copy **and**
   missing/malformed/wrong-path flows pointer. Empty `$HOOKS` /
   unfinished hooks stay. A present doctrine pointer + complete
   copy + missing flows pointer (or complete doctrine + missing
   dest stems) must hit **this** arm, not STOP, not a dead branch.
   Resume: skip `seed.sh` if doctrine is present; **still run** the
   copy arm and/or door `apply` when those predicates fire.
3. **Range.** `(1–6)` unchanged.

Migrate: same copy after its `seed.sh`, before the door; same
unfinished predicates. `check`: required finding when copy
unfinished, names `/clankshop setup`. Setup Notes commit pathspec
adds `<agent-workspace>/flows/`.

Door write (setup step 4 / migrate's door paragraph) still
integrates, never clobbers. It does **not** compile dispatch rows
from `core/ROUTING.md`. Minimum bytes: doctrine pointer;
delimited flows **pointer**; `agent-records:` / `agent-workspace:`
only when not default. Classification **walk** stays in
`seed/core/ROUTING.md` with **four** rows, paths
`<agent-workspace>/flows/<stem>.md`. Review POLICY / `doc-audit.md`
stop requiring the door table to match ROUTING.md; the door is a
pointer; the walk stays in doctrine.

`seed/build/POLICY.md` "lanes live in `workflows/` here" → lanes
live in `<agent-workspace>/flows/`. Review/test POLICY chore
pointers follow (`<ws>/flows/diagnostics.md`,
`<ws>/flows/doc-audit.md`). Seed README layout: no per-station
`workflows/`; document `<ws>/flows/` as a sibling of `doctrine/`.
PACK.md debugger blurb: guided by
`<agent-workspace>/flows/diagnostics.md` when present.

**Reclassify, do not only retarget (debugger, slice 2).** Location
probe: consult `<agent-workspace>/flows/diagnostics.md` **when that
file exists**. Absent → investigate without it. Do **not** say the
playbook is doctrine. Stamp probe unchanged. `consumes: doctrine`
remains for stamp / station context, not for the playbook file.

Live consumers of the six files (not historical `docs/design/`):

- `skills/workstream/flow.md` (feature lane path)
- `skills/debugger/SKILL.md` (diagnostics path **and** "is doctrine"
  location sentence)
- `skills/clankshop/seed/core/ROUTING.md` and station POLICY
- `skills/clankshop/seed/README.md` (per-station `workflows/` tree)
- `skills/clankshop/seed/build/workflows/bug.md` (relative
  `test/workflows/diagnostics.md` — retarget as it moves)
- `skills/clankshop/SKILL.md` Assets
- `skills/clankshop/PACK.md` debugger row
- `skills/clankshop/verbs/check.md`
- `skill-builder` lint fixtures: **every** plant of
  `doctrine/test/workflows/diagnostics.md` (green **and** indented
  RED at `lint-doctrine-consumer-test.sh:132`), switch positives to
  a path that still lives under doctrine. Keep `.handbook/…/workflows/{feature,diagnostics}.md`
  as off-home FAILs.
- any other `skills/` hit from
  `rg -n 'doctrine/.*/workflows/(bug|feature|patch|spike|diagnostics|doc-audit)\.md'`
  **or** `rg -n 'build/workflows|test/workflows|review/workflows'`
  excluding `docs/design/` and excluding synthetic fixtures
  (journal `records-test.sh` may keep a fake
  `doctrine/test/workflows/…` as "not a record")

`skills/auditor/**` `test/workflows/audit/` — **do not move.**

Do not teach the linter that `flows/` is doctrine.

Two-roots (`docs/design/2026-08-19-two-roots-simple-spec.md`,
`status: current`) holds-column: replace `workflow/` with `flows/`.
**Renames** bullet: the six files un-nest to `flows/` (plural).
Which-home box does **not** add a fifth landing class — `flows/`
are host procedures, workspace-resident, copied by the owner skill.
Slice 4 edits Which-home's "Doctrine: …" sentence (drop "a
diagnostics playbook, a build lane"; audit rubric may stay) and the
stamp paragraph that currently says playbooks and lanes resolve
through `<agent-workspace>/doctrine`.

`<agent-workspace>/flows/` is not `workstream`'s package file
`flow.md`. Analyst catalog `diagnostics.md` is a different object.

`context.sh` load sets stay `core/*` + `<station>/POLICY.md`. Slice
2: drop "workflows load lazily" as a station-dir claim. Procedures
are not loaded until one is selected (door pointer language);
`core/ROUTING.md` still selects a classification-lane path under
`<ws>/flows/`. Do not name `shopbook` in the seed.

### Door block (pointer)

Exact delimiters. One implementation: face
`skills/clankshop/scripts/flows-door.sh`. Shopbook bundles a copy
(slice 3). Golden-byte test on the functional body.

Default workspace:

```markdown
<!-- flows BEGIN -->
Project procedures live under `.dev/flows/` and are not loaded until one is selected.
<!-- flows END -->
```

Declared `agent-workspace: dev` → the body uses `dev/flows/`
instead of `.dev/flows/`.

- Body is **exactly one line**: `Project procedures live under
  `<rel>/flows/` and are not loaded until one is selected.`
  No stem table. Do not name `/shopbook` (the description is
  who; this line is where).
- Writer owns **only** the bytes between the delimiters.
- **absent section → append** (creating `AGENTS.md` only when
  **clankshop setup/migrate** is the caller and it is already writing
  the door). Shopbook never creates a door.
- **present → replace only between the delimiters.**
- **malformed → report, touch nothing.**
- Adding or deleting a `flows/*.md` file does **not** change the
  pointer. `drift=true` only when the block is missing, malformed,
  or the body lacks the resolved `<ws>/flows/` literal.

Script: `flows-door.sh check|apply --root <abs> --workspace <rel>`.
Workspace resolution is the verb's; the script still reads/writes
`$root/AGENTS.md`. It does not open `CLAUDE.md`.

Facts: `workspace=` `flows_dir=` `door=` `door_class=`
`block=missing|ok|malformed` `drift=true|false`.

| payload `$SRC` | block | `--check` | `apply` |
|---|---|---|---|
| n/a, `door_class=claude-only` or `absent` | any | 1 (`door=…`) | no-op 0; never create AGENTS.md; never write CLAUDE.md |
| present | missing | 1 | append pointer |
| present | ok, path matches | 0 | rewrite span (idempotent) |
| present | ok, wrong path | 1 drift | rewrite span |
| present | malformed | 1 | no-op STOP |
| absent | any | 0 | no-op 0 |

### `shopbook` skill

New package `skills/shopbook/` (follow `skill-builder new` in spirit;
author by this spec). **Experimental.** Not part of atomic setup.
Does not copy pack or sibling payload. `create` mints a host stub.

- **Tier:** in-place steward. No `init`. No durable home. **Skip
  `skill:` registration.** Slice 4 records this exception.
- **Record-writer:** no. `create` does not mint records.
- **Hooks:** no.
- **Description (self-scoping, live string — paste this):**
  `Find or create a project procedure under <agent-workspace>/flows/ (workflow, playbook, host routine). Query, list, or search by title and use-when; when asked to run a host routine (start the environment, publish a release), resolve one file and follow it in the calling context. When asked to create, add, or author a workflow, routine, procedure, or playbook, mint a host stub there (create). Use when asked to use the shopbook, query or create a project procedure, list host workflows, repair the procedures pointer in AGENTS.md, or fill missing title/use-when (upkeep).`
  Authoring constraints (**not** in the string, and **not**
  pasted into `SKILL.md` — the absence is the constraint): do
  not name `clankshop`; do not say "routing table"; no
  build-station or hat language; do not say "migrate"; do not
  say "runbook"; do not fire on "file a bug" / "capture the
  repro." Stay ≤1024, prefer ≤750.
- **Edges:** honest all-`—`.
- **Verbs.** Dispatch applies to **every** invocation (slash,
  unknown slash, NL, and bare). It is not "bare only." After
  dispatch:
  - `query` → `verbs/query.md` (`query` (alias `list` /
    `search` / `find`), skill-builder `check` (alias `audit`)
    shape; `/shopbook query` with no topic = list). The query
    walk lives in this file, not in `SKILL.md`.
  - `create` → `verbs/create.md` (host stub)
  - `sync` → `verbs/sync.md` (pointer repair). `--check` facts-only
  - `upkeep` → `verbs/upkeep.md` (crawl keys). `--check` facts-only
  - Recognized slash first tokens are the table's **Invocation**
    names. `list` / `search` / `find` are aliases of `query` —
    they open `verbs/query.md`; do not write those files.
    `new` / `add` / `author` are **not** slash verbs. Do not
    write `verbs/new.md`, `verbs/list.md`, `verbs/search.md`,
    `verbs/find.md`, `verbs/add.md`, or `verbs/author.md`
    (spec-only; do not paste those paths into `SKILL.md` or
    `verbs/` — tests may name them to assert absence).

**Dispatch** (this file, **before** any walk).
Paste into `SKILL.md` as journal-shaped `Invocation | Verb file |
Trigger`. Slash tokens match **Invocation only**; Trigger is
NL-only. Authoring synonyms (`add` / `author`) are not slash
aliases of `create`. Enter `verbs/create.md` only after this
table chose `create`. Enter `verbs/query.md` only after this
table chose `query` (including the `list` / `search` / `find`
aliases).

Authoring **verbs** (NL only) = {create, add, author}. A type
noun (workflow / routine / procedure / playbook) without those
verbs does not select the `create` walk. Slash mint is only
`/shopbook create`. Slash `add` / `author` are unknown → **ask**.

| Invocation | Verb file | Trigger |
|---|---|---|
| `/shopbook query` (alias `list` / `search` / `find`; with or without a topic; no topic = list) | `verbs/query.md` | list / search / run / follow a host procedure; "how do we handle X"; start the env; publish a release (NL, no slash verb) |
| `/shopbook create` (with or without a stem) | `verbs/create.md` | create / add / author a workflow, routine, procedure, or playbook (NL, no slash verb; `add`+procedure wins over list) |
| `/shopbook sync` | `verbs/sync.md` | repair the procedures pointer in AGENTS.md (NL, no slash verb) |
| `/shopbook upkeep` | `verbs/upkeep.md` | fill missing title/use-when (NL, no slash verb) |
| unknown slash token (`/shopbook foobar`, `/shopbook bug`, `/shopbook new bug`, `/shopbook add`, `/shopbook author`, bare `/shopbook`); NL "use the shopbook" with no further intent | — | **ask** which of query / create / sync / upkeep |

Query's `matches=0` is **not found**. Do not mint. Do not
mkdir `$DST`. Do not call `flows-create.sh`. Do not name
another skill. Do not mention setup. "File a bug" /
"capture the repro" is not shopbook — do not treat it as
`create`. Do not treat the first unknown slash token as a
topic.

**`flows-index.sh` `list|search --root --workspace [--query]`**
(facts, no LLM). Regular `*.md`, one directory level, skip
dotfiles. `list`: `stems=` `paths=` `titles=` (parallel, empty
slot if missing). `search`: match query tokens against **stem,
`title`, `use-when`, and first ATX H1**; `matches=` `stems=`
`paths=` `titles=` of hits. Missing dir → `flows_dir=missing`
`matches=0` exit 0.

**Query walk** (paste into `verbs/query.md`, not `SKILL.md`;
no child; only after dispatch chose `query`):

1. Resolve project root (conversation → cwd → ask). Resolve
   `<agent-workspace>` from the door (else `.dev`).
2. If the remaining argument is a single kebab-case stem, test
   `$DST/<stem>.md`. Present → that path; go to step 5. Absent →
   do not mkdir `$DST` (a miss leaves `$DST` absent); do not
   call `flows-create.sh`; continue to step 3 and search that
   token. Do not invent a procedure. Do not fall through to
   `create`. Do not name another skill.
3. Run `search` if there is a query, including a kebab-case
   stem whose `$DST/<stem>.md` was absent in step 2; else `list`
   (`/shopbook query` with no topic is list).
4. Decision:
   - `matches=0` → **not found**; stop. Do not invent a
     procedure. Do not fall through to `create`. Do not name
     another skill. Do not mkdir `$DST`.
   - `matches=1` → that path.
   - `matches>1` → print stem / title / use-when for each;
     **ask**; never pick silently.
5. The **calling** agent reads that file **in full** and follows
   it. Do not substitute a summary.

**`flows-create.sh` `--root --workspace --stem [--title] [--use-when]`**
(facts, write). Stem must be kebab-case
`[a-z0-9]+(-[a-z0-9]+)*` — no `/`, no `..`, no leading `.`.
The script does not know pack stems and does not mention
another skill. Facts: `workspace=` `flows_dir=` `stem=` `path=`
`created=true|false`
`reason=ok|incumbent|bad-stem|no-home|bad-value`.
Pairing: `created=true` ⇔ `reason=ok` ⇔ exit 0;
`created=false` ⇔ one refuse reason ⇔ exit 1. Check order:
`bad-stem`, then `bad-value`, then `no-home`, then `incumbent`,
else create. Default `title` is the stem with hyphens turned
to spaces; default `use-when` is the stem.

**YAML values** (`title` / `use-when` that **shopbook writes**):
single-line only. Empty or whitespace-only → `bad-value`.
Refuse newline or a `---` substring. Write each value as a
double-quoted YAML scalar, backslash-escaping `\` and `"`.
Same rule when `upkeep` inserts a key. **Reading:** parse
quoted or unquoted front-matter already on disk (files
shopbook did not write). Do not tell another skill how to
author its payload.

**Narrow `flows/` mkdir** (same rule as hooks): mkdir `$DST`
only when (a) `<root>/<agent-workspace>` already exists as a
directory, or (b) the home is the derived default `.dev` and
the mkdir is `flows/` only (creates `.dev` as a container for
`flows/`, never `doctrine/`). Declared `agent-workspace:` that
is absent → `reason=no-home`, write nothing. Shopbook is not
the workspace assembler.

**`create` walk** (when dispatch chose `create`):

0. This file runs **only** after dispatch chose `create`. If
   opened for `/shopbook query` / `list` / `search` / `find`,
   STOP and run the query walk; do not call `flows-create.sh`.
   If opened for `/shopbook new` / `add` / `author` or another
   unknown slash token, STOP and **ask**; do not mint.
1. Resolve project root and `<agent-workspace>` the same way
   as query.
2. Stem from the argument; if missing and a human is present,
   **ask**. If missing and no human, stop; do not call the
   script. If the argument is not already kebab and a human
   is present, **propose** one (lowercase; non `[a-z0-9]` →
   `-`; collapse repeats; trim edge hyphens; strip a trailing
   `.md`) and **confirm**; then the script validates. If the
   argument is not kebab and no human, stop; do not slugify;
   do not call the script.
3. Optional `--title` / `--use-when`; if omitted and a human
   is present, ask; else script defaults.
4. Run `flows-create.sh`.
5. Decision:
   - `reason=bad-stem` / `no-home` / `bad-value` → report; stop.
   - `reason=incumbent` → report the existing path; stop. Do
     not overwrite. Missing crawl keys on that file are
     `/shopbook upkeep`, not `create`.
   - `created=true` → print `path=`. The **calling** agent
     then authors the procedure body **in that file** (calling
     context). Shopbook does not fill the walk. Do not list
     other stems. Do not run `sync` (adding a file does not
     drift the pointer).

`create` does not copy another skill's bundled files. `create`
does not mint records.

**`sync` walk:** door pointer table (bundled script). New flow
files do not require `sync`. Missing `AGENTS.md` is a no-op write.

**`upkeep` walk** (`flows-upkeep.sh check|apply --root --workspace`):

Ongoing maintenance of crawl keys on `$DST/*.md` (same glob as
the index). Not a workshop onramp. Not `migrate`.

- Parse YAML front-matter if the file starts with `---`.
- Facts per file: `fm=missing|ok|malformed`, `title=missing|ok`,
  `use_when=missing|ok`. Summary: `need=` comma stems that are
  not fully ok; `malformed=` stems whose FM does not parse.
- `--check`: exit 0 if `need=` empty and `malformed=` empty;
  else 1. Write nothing.
- `apply`: for each file with `fm=missing`, insert a leading
  block with quoted `title:` from first H1 (else the stem)
  and quoted `use-when:` from the stem (YAML values rule
  above). For `fm=ok` with a missing key, add **only that
  key** (title default as above; `use-when` default the
  stem). Never change an existing key. Never change the
  body after the front-matter. `fm=malformed` → skip that
  file, report it, do not rewrite. H1 containing newline
  or `---` → skip that file, do not insert.
- Does not create files. Does not delete. Missing `$DST` →
  no-op 0.

No stamp probe. No pack tripwire.

### Pack and doctrine

`PACK.md` `version: 2.5.0` (member set grows). `optional:` adds
`shopbook`. Roster table: helper, "experimental — query or create
host procedures under `flows/`; this release: `query`
(list/search/find aliases) + host-stub `create` + pointer
`sync` + crawl-key `upkeep`." Seam note:

> **Seam — `clankshop` / `shopbook`:** the face copies **its**
> `<agent-workspace>/flows/` files (with crawl keys) and writes
> the initial door **pointer** via `scripts/flows-door.sh`. Other
> skills seed their own `hooks/` / `templates/` / skill-owned
> flows (with crawl keys). `shopbook` never copies pack or
> sibling payload. `create` mints a host-authored stub only.
> Shopbook does not inventory pack stems and does not require
> a workshop. Setup does not invoke `/shopbook`. `/shopbook`
> later may `query` the tree (caller follows), may `create` a
> host stub (caller authors the body), may `sync` the pointer,
> and may `upkeep` missing keys. Leaves do not name each other.

Doctrine **Glue is content vs. mechanism** bullet — quote HEAD:
"Project hooks files (`<agent-workspace>/hooks/<skill>.md`) are the
glue surface — not a composer skill to invoke. Pack/runbook still
authors *what* the glue says; there is no oven." Add: using
`flows/` / `hooks/` / `templates/` is applying that glue; there is
still no oven. Do **not** add a named applicator.

Independent-seeding sentence (slice 4): a skill copies only the
workspace files it owns (`flows/` / `hooks/` / `templates/` as
applicable), including crawl keys on any flow it copies;
incumbent wins; `shopbook` is not a seeder of pack or sibling
payload. `shopbook create` mints a host stub; that is not seeding.

Owner exception unchanged: `clankshop` assembles the workspace;
`journal` assembles records. Shopbook is "every other skill" —
resolve, test, degrade; never `mkdir` a declared-absent home.
Narrow `flows/` mkdir (default `.dev` container only) is the
hooks rule, not an owner exception.

### Clankshop check vs `shopbook`

Required (face script, not the member):

1. **Unfinished copy** — `$SKILL/flows` present and a source stem
   missing at `<ws>/flows`. Finding names `/clankshop setup`.
2. **Pointer drift** — when `$SKILL/flows` is present, run face
   `scripts/flows-door.sh check`. `drift=true` or
   `block=missing|malformed` → finding. Names `/shopbook sync` if
   that skill is present, else `/clankshop setup`. Check still
   does not write. Extra dest files are **not** a finding.
   Missing crawl keys are **not** a clankshop `check` finding
   (`/shopbook upkeep`).

Setup Guard is the three-arm quote-edit above. Unfinished hooks
stay as shipped.

### Inventory and tests

`README.md` skills table: add `shopbook`; rewrite the `clankshop`
row (no persona). Pack paragraph lists `shopbook` as a helper.
`AGENTS.md` opening roster: same, plus the notepad/analyst/`calibrate`
riders in *Hats off*.

Harnesses:

- Clankshop: face-test without persona; seed-test without aliases;
  seed-test still green on `context.sh --check`; after fixture
  `seed.sh` + flows copy, six files at `<ws>/flows/` with `title`
  and `use-when`; no `workflows/` under doctrine; incumbent flow
  not overwritten; `seed.sh` alone does not create `flows/`;
  resume after doctrine-present still copies missing stems; door
  has the pointer and **no** ROUTING table and **no** stem table;
  `check` red on a missing source stem.
- Face `flows-door.sh` tests cover the pointer table (red-proofs
  5–11). Extra dest file does **not** set `drift=true`.
- Shopbook: `scripts/tests/run.sh` + door-script tests +
  `flows-index-test.sh` + `flows-upkeep-test.sh` +
  `flows-create-test.sh`; golden-byte identity vs the face door
  script.

### Out of scope

- `spec/` station un-nest; lint 12–17 rewrite; remaining BL-36.
- Moving `auditor` rubric home `doctrine/test/workflows/audit/`.
- Moving `hooks-glue.sh` into `shopbook`.
- A glue-apply composer; a workflow engine; a consult child;
  scheduling verbs; a persona brief in doctrine.
- `create` inventing procedure steps, copying pack payload,
  minting records, aliasing a file-a-repro verb, or dumping
  the flows catalog into the calling context.
- A `new` mint verb on `shopbook` (`verbs/new.md`).
- Slash `add` / `author` mint verbs (`verbs/add.md`,
  `verbs/author.md`).
- `/shopbook <query>` as a slash format; `new` as a look-up
  token (`/shopbook new <stem>` is unknown → ask).
- Inlining the query walk in `SKILL.md` instead of
  `verbs/query.md`.
- Editing `core/ROUTING.md` from `shopbook`; minting
  `doctrine/ROUTING.md` or `doctrine/foreman.md`.
- A stem catalog in `AGENTS.md`.
- Naming this skill `foreman`.
- A `migrate` verb on `shopbook`.
- Reassigning the six pack flow files to other skills.
- A named `upgrade` verb; a `check` facts/link-walker script.
- Phase 7 live deploy. Patient-zero still binds.
- Restoring `/clankshop design|route|verify`.
- `/backlog task` / `/backlog issue` in workstream.
- Convening a panel.

## Verification

**Mechanical**

```
cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
  bash skills/clankshop/scripts/tests/run.sh && \
  bash skills/shopbook/scripts/tests/run.sh && \
  bash skills/skill-builder/scripts/skills-lint.sh .
```

Expect: both harnesses ALL GREEN; lint `fails=0`.

Grep gates (count the hits; fail on the wrong count):

1. Under `skills/clankshop/` excluding `scripts/tests/**` and this
   spec: `rg -n 'verbs/persona.md'` → empty.
2. Under `skills/clankshop/seed/`: `rg -n '^You are the (architect|foreman|guardian|admin)'`
   → empty.
3. Under `skills/clankshop/` excluding `scripts/tests/**` and this
   spec: `rg -n 'build/workflows|test/workflows|review/workflows'`
   → empty after slice 2. Red-proof: plant one leftover, gate
   red, restore.
4. Under `skills/shopbook/`: `rg -n 'skill:.*BEGIN|register-route'`
   → empty.
5. Live consumers of the six: both census commands in *Live
   consumers* → empty after the path flip, except documented
   synthetic fixtures and parked auditor `audit/`.
6. Under `skills/shopbook/` excluding tests: `rg -n 'verbs/migrate.md'`
   → empty.
7. Under `skills/shopbook/` `SKILL.md` and `verbs/`: `rg -n 'clankshop'`
   → empty.
8. Absence of alias/mint verb files is **existence**, not a
   content grep. From the worktree root (shopbook tests **may**
   name these paths):
   `for v in new list search find add author; do test ! -e skills/shopbook/verbs/$v.md || exit 1; done`
   Plant any one empty file; this gate red; restore.
   Under `skills/shopbook/` `SKILL.md` and `verbs/` (**not**
   tests): `rg -n 'verbs/(new|list|search|find|add|author)\.md'`
   → empty. Plant any one string there; gate red; restore.
9. Under `skills/clankshop/seed/scripts/context.sh`: `rg -n 'shopbook'`
   → empty. Plant; gate red; restore.

**Red-proofs (do not land a first clean run)**

1. **Hats gone.** `face-test` with `persona` still in the verb loop
   fails; after the loop drop, green. `context.sh architect` exits 1.
   Disable the `station_for` alias deletion, confirm `architect`
   still renders, restore.
2. **Flows copy, doctrine not.** Six files at `$ws/flows/`; no
   `workflows/` dir under doctrine. Disable seed-tree deletion of
   `build/workflows/`, confirm they land *inside* doctrine, restore.
3. **Incumbent flow.** Unique bytes at `$ws/flows/feature.md`; copy;
   checksum unchanged.
4. **`seed.sh` does not copy flows.** `$ws/flows` absent.
5. **Door pointer initial.** Well-formed pointer with resolved
   `<ws>/flows/` literal; no ROUTING table; no stem table; body
   does not contain `shopbook`. Extra dest file → door checksum
   unchanged, `drift=false`.
6. **Resume copy + missing pointer.** (i) missing dest stem →
   resume, copy runs, `seed.sh` not re-run. (ii) stems present,
   pointer absent → resume, door `apply`, then check green.
   Disable resume parenthetical, confirm write-nothing on (ii),
   restore.
7. **Unfinished copy is a `check` finding.** Names setup; tree
   unchanged.
8. **Pointer apply / wrong path.** Workspace `dev` → body contains
   `dev/flows/`. Disable path substitution, `--check` stays 1
   after `apply`, restore.
9. **Malformed refuse.** One delimiter → apply writes nothing;
   `--check` exits 1.
10. **No AGENTS.md / claude-only.** Apply writes nothing; does not
    create AGENTS.md; does not write CLAUDE.md.
11. **No oven.** Plant `<!-- skill:shopbook BEGIN`; apply does not
    modify it.
12. **Grep gate 3.** Plant `build/workflows/feature.md` in
    `skills/clankshop/flows/bug.md`; gate red; restore.
13. **Golden copy.** Face `flows-door.sh` vs shopbook bundle:
    functional body byte-identical. Break one copy; identity test
    red; restore.
14. **Index search.** Files with `use-when` containing `release` →
    `search --query release` `matches=1`. Disable `use-when`
    match, confirm a title-only hit still matches on title;
    restore.
15. **Find does not pick among many.** Two title hits → harness
    (or agent-script contract) reports `matches=2` and does not
    emit a single `path=`.
16. **`upkeep` fills missing keys only.** File with body and no
    FM → apply inserts `title` (from H1) and `use-when` (stem);
    body bytes after FM unchanged. File with `title` present and
    `use-when` missing → only `use-when` added; `title` unchanged.
    File with both keys → checksum unchanged. Malformed FM →
    skipped; checksum unchanged.
17. **`create` mints a host stub only.** `flows-create.sh --stem
    publish-release` on an empty `$DST` (dispatch chose
    `create`) → file at `$ws/flows/publish-release.md` with
    `title` / `use-when` and an H1; body after H1 is empty
    (no invented walk). Re-run → `created=false`
    `reason=incumbent`; checksum unchanged. `--stem Bug` or
    `--stem ../x` → `reason=bad-stem`; no file. Declared
    workspace `workspace` that is absent → `reason=no-home`;
    no `workspace/` directory created. Default `.dev` absent →
    mkdir `.dev/flows/` only; no `doctrine/`. Disable incumbent
    refuse, confirm overwrite, restore.
18. **Look-up does not invent.** Index `matches=0` → harness
    reports none and does not create a file; `$DST` stays
    absent. `/shopbook query bug` on a tree with `$DST`
    absent: no file created, `$DST` remains absent (no mkdir),
    `flows-create.sh` is not invoked. Do not run
    `flows-create.sh` in this test. `verbs/query.md` greps: the
    kebab arm contains `test `$DST/<stem>.md``, `do not call
    `flows-create.sh``, `a miss leaves `$DST` absent`, and
    `continue to step 3 and search`. Delete those bullets;
    greps go red; restore. `SKILL.md` does **not** contain a
    `Query walk` heading, does **not** contain `$DST/<stem>.md`,
    and does **not** contain `do not call `flows-create.sh``
    (the walk is not inlined there, even under another heading).
19. **YAML quote (shopbook writes).** `flows-create.sh --stem
    cut-release --title 'Cut: "v1" release'` → `fm=ok`, title
    parses as `Cut: "v1" release`. `--title` containing a
    newline, `---`, or only spaces → `reason=bad-value`; no
    file. Empty `--title` → `bad-value`. `upkeep` H1
    `Cut: "v1"` → quoted `title` `fm=ok`. Unquoted on-disk
    front-matter still parses.
20. **Dispatch table is in SKILL.md; query walk is in
    `verbs/query.md`.** Distinctive texts required: the
    `/shopbook query` row, the unknown-slash **ask** row
    (`/shopbook bug` / bare `/shopbook` → ask), and the NL
    how-do-we-X → `query` trigger. (a) `SKILL.md` contains the
    dispatch table; `verbs/query.md` contains the `Query walk`
    heading. Inline the walk in `SKILL.md` or drop the heading
    from `query.md`; this grep goes red; restore. (b)
    `SKILL.md` does not contain `/shopbook <query>` as a slash
    form, does not contain `bare `/shopbook` [query] → find`,
    does not map `/shopbook new` → `verbs/new.md` or
    `verbs/create.md` or a look-up walk, does not map
    `/shopbook add` → `verbs/create.md`, does not map
    `/shopbook author` → `verbs/create.md`, and does not map
    bare `/shopbook` → `query` / `list`. Plant any; this grep
    goes red; restore. Create-shaped language → `create` is
    Judgment (an agent following the table), not a bash prompt
    classifier. Slash tokens match Invocation only.

**Judgment**

- Clankshop description does not name hat tokens or "talk to a
  station persona."
- Shopbook description is query/follow + `create` + pointer
  `sync` + `upkeep`; names procedure/workflow/playbook/routine/
  shopbook; fires on "create a workflow / routine / procedure /
  playbook"; does not name `clankshop`, `backlog`, or `runbook`;
  does not say migrate; does not fire on "file a bug"; does not
  use hat / build-station language; does not advertise a child
  consult or glue-apply. The quoted live string is the
  `description:`; authoring constraints sit outside it. Asking
  to **create** a procedure uses `create`, not search.
  `add`+procedure wins over list (NL). `/shopbook create` (with
  or without a stem) mints. Slash `add` / `author` **asks**.
  Slash look-up is `/shopbook query` (no topic = list; alias
  `list` / `search` / `find` → `verbs/query.md`). Slash tokens
  match **Invocation only**; Trigger is NL-only. A first
  unknown slash token (`/shopbook bug`, `/shopbook new bug`,
  `/shopbook add`, bare `/shopbook`) is **ask**, not a topic.
  NL description-fire still runs `query`. NL "use the shopbook"
  with no further intent **asks**. NL pointer-repair → `sync`.
  NL missing crawl keys → `upkeep`. Asking for a named
  procedure that is not on disk is not found, not a mint.
  Shopbook `SKILL.md` and `verbs/` do not name `clankshop`.
  No `verbs/new.md` / `list.md` / `search.md` / `find.md` /
  `add.md` / `author.md`. The query walk lives in
  `verbs/query.md`.
- `PACK.md` version is `2.5.0`; `shopbook` is `optional:` and
  marked experimental. No `foreman` member.
- Glue bullet still says project hooks are the glue surface and
  there is no oven; using `flows/` / `hooks/` / `templates/` is
  applying glue.
- Owner exception still names `clankshop` and `journal` only.
- Two-roots holds-column lists `flows/` and not `workflow/`.
- `hooks-glue.sh` and `flows-door.sh` live on the face.
- Debugger location probe is `flows/diagnostics.md`, not doctrine.
- Which-home Doctrine sentence no longer calls a diagnostics
  playbook or build lane doctrine.
- Auditor `test/workflows/audit/` still named as parked.
- `core/ROUTING.md` is still the change classifier.

## Slices

- [x] **Slice 1: hats off**
  <requires: —>
  - Files: `skills/clankshop/SKILL.md`, `PACK.md` (prose only, **no**
    version bump yet), `verbs/persona.md` (delete), `verbs/setup.md`
    (drop "the guardian fills it" if it reads as a summon — reword
    to "the test station"), `scripts/tests/face-test.sh`,
    `scripts/tests/seed-test.sh`, `seed/scripts/context.sh`,
    `seed/README.md`, `seed/{design,build,test,review}/POLICY.md`,
    library `AGENTS.md` / `README.md` (persona / handbook /
    `calibrate` / notepad / analyst; not yet a `shopbook` inventory
    row if the skill does not exist).
  - Change: Mechanism *Hats off*. Nested `workflows/` still seed as
    today. No `shopbook` package. No `flows-door.sh`.
  - Verify: red-proof 1. Clankshop harness ALL GREEN. Lint
    `fails=0`. Grep gate 1–2.

- [ ] **Slice 2: un-nest + face pointer + Guard + reclassify**
  <requires: 1>
  - Files: create `skills/clankshop/flows/*.md` (move + add crawl
    keys); delete seed `**/workflows/`; create
    `skills/clankshop/scripts/flows-door.sh` and tests; `seed.sh`
    unchanged in destination; `verbs/setup.md` (step 2 two arms,
    unfinished copy, **quote-edit Guard 24–34 all three arms**,
    door pointer, Notes pathspec `flows/`);
    `scripts/tests/face-test.sh` (scripts loop adds `flows-door.sh`
    + `bash -n`); `verbs/migrate.md`; `verbs/check.md`; `SKILL.md`
    Assets; `PACK.md` debugger blurb (no version bump);
    `seed/core/ROUTING.md` + station POLICY + seed README +
    `bug.md` relative pointer; `workstream/flow.md`;
    `debugger/SKILL.md` location probe; skill-builder lint
    fixtures (positives **and** indented RED `:132`);
    `docs/design/2026-08-19-two-roots-simple-spec.md` holds-column
    and Renames; `seed/scripts/context.sh` "workflows load lazily"
    (replace with door language; do not name `shopbook`);
    `scripts/tests/*` for copy/resume/`check`.
  - Change: Mechanism *`flows/`* + *Door block* + *Clankshop check*
    (face half). No `shopbook` package yet.
  - Verify: red-proofs 2–12 on the **face** script. Grep gates 3,
    5, and 9. Clankshop harness green. Lint `fails=0`.

- [ ] **Slice 3: `shopbook` finder + host stub**
  <requires: 2>
  - Files: create `skills/shopbook/SKILL.md` (journal-shaped
    dispatch table; dispatch applies to every invocation;
    enter `verbs/create.md` only after dispatch chose `create`;
    enter `verbs/query.md` only after dispatch chose `query`;
    slash tokens match Invocation only; no `Query walk` heading
    and no kebab-arm bytes in `SKILL.md`),
    `verbs/query.md` (the query walk lives here; `query` (alias
    `list` / `search` / `find`); `/shopbook query` with
    no topic = list),
    `verbs/create.md` (step 0 STOP if opened for `/shopbook
    query` or an unknown slash token including `add` /
    `author` / `new`), `verbs/sync.md`,
    `verbs/upkeep.md` (not a workshop onramp; not `migrate`),
    `scripts/flows-door.sh` (copy), `scripts/flows-index.sh`,
    `scripts/flows-upkeep.sh`, `scripts/flows-create.sh`, tests
    (`flows-door-test.sh`, `flows-index-test.sh`,
    `flows-upkeep-test.sh`, `flows-create-test.sh`, `run.sh`);
    modify `PACK.md` (`2.5.0`, `optional:`, roster, seam); library
    `README.md` / `AGENTS.md` inventory row; `check.md` finding
    names `/shopbook sync` when the skill is present. Do not
    write `verbs/new.md`, `verbs/list.md`, `verbs/search.md`,
    `verbs/find.md`, `verbs/add.md`, or `verbs/author.md`.
  - Change: Mechanism *`shopbook` skill* (dispatch + query +
    `create` + sync + upkeep). Description includes create/author
    a workflow / routine / procedure / playbook; no `runbook`;
    no "file a bug." Dispatch: NL author or `/shopbook create`
    → `create`; slash look-up is `/shopbook query`; unknown
    first slash token (including `add` / `author` / `new`) →
    **ask**; NL description-fire → `query`; NL "use the
    shopbook" with no further intent → **ask**. YAML values
    shopbook writes are quoted. `SKILL.md` + `verbs/` name no
    `clankshop`.
  - Verify: red-proofs 8–11, 13–20. Shopbook harness ALL GREEN.
    Clankshop still green. Lint `fails=0`. Grep gates 4, 6, 7,
    8, and 9. Shopbook `SKILL.md` `description:` has no
    `runbook`. `test -f skills/shopbook/verbs/query.md`.
    `SKILL.md` has the dispatch table; `verbs/query.md` has
    the Query walk heading.

- [ ] **Slice 4: doctrine + BL-36 note**
  <requires: 3>
  - Files: `skills/skill-builder/docs/DOCTRINE.md` (glue bullet
    quoted from HEAD + using `flows/`/`hooks/`/`templates/` is
    applying glue, still no oven; independent-seeding + crawl keys
    on copied flows; Which-home "Doctrine: …" drops diagnostics
    playbook / build lane; stamp paragraph: `flows/` procedures do
    not resolve through doctrine; steward-registration exception;
    do not retarget the audit `GUIDE.md` length example unless it
    becomes false); `docs/BACKLOG.md` BL-36 body: item 3 **partly
    done** — six seed files un-nested to `flows/`; `spec/` and
    auditor rubric home still parked, auditor path named. BL-13/16
    stay "foreman is retired" (this skill is `shopbook`). Do not
    invoke `/backlog`.
  - Change: Mechanism remaining doctrine + close-the-books.
  - Verify: lint `fails=0`. Glue bullet names hooks as the surface
    and still says there is no oven. Independent-seeding sentence
    present. Which-home Doctrine sentence no longer lists
    diagnostics playbook / build lane.

## Done when

All four slices checked. Verification block green.

- `/clankshop architect` is not a verb; seed POLICY files do not
  address the reader as a hat; `context.sh` accepts only station
  names.
- Fixture setup: doctrine at `<ws>/doctrine`, six files at
  `<ws>/flows/` with `title` and `use-when`, no `workflows/` under
  doctrine, door contains one well-formed flows **pointer** and
  **no** ROUTING table and **no** stem table, hooks fill unchanged.
  `check` red if a seed stem is missing. Setup green without
  `/shopbook`.
- `seed.sh` alone does not create `flows/`. Resume after doctrine
  present still copies missing stems.
- Face `flows-door.sh` implements the pointer table. Extra flow
  files do not drift the pointer. `/shopbook sync --check`
  facts-only; `sync` rewrites only the delimited span.
- `/shopbook` dispatch applies to every invocation. NL
  authoring a procedure or `/shopbook create` → `create`.
  Slash `add` / `author` **asks**. Slash look-up is
  `/shopbook query` (alias `list` / `search` / `find`;
  no topic = list). Slash tokens match Invocation only.
  The query walk lives in `verbs/query.md`.
  NL description-fire (how-do-we-X, start the env, publish)
  still runs `query`. A first unknown slash token
  (`/shopbook bug`, `/shopbook new bug`, `/shopbook add`,
  `/shopbook foobar`, bare `/shopbook`) is **ask**, not a
  topic. NL "use the shopbook" with no further intent **asks**.
  `new` / `add` / `author` are not slash verbs; no
  `verbs/new.md` / `list.md` / `search.md` / `find.md` /
  `add.md` / `author.md`. Query: one match → path, caller follows;
  zero → **not found** (does not mint); many → ask. Index
  matches stem / title / use-when / H1. When dispatch chose
  `create`: stub at `<ws>/flows/<stem>.md` with quoted crawl
  keys + H1; caller authors the body; incumbent refuse;
  narrow `flows/` mkdir; no catalog dump; no records.
  `upkeep` fills missing keys only; never clobbers. No consult
  child. No `migrate` verb. Shopbook `SKILL.md` and `verbs/`
  do not name `clankshop`. Shopbook does not copy pack or
  sibling `flows/` / `hooks/` / `templates/`, does not
  inventory pack stems, and does not require a workshop.
- PACK 2.5.0 lists `shopbook` optional and experimental. No
  `foreman` member. No `skill:` registrar. Description is
  query/follow **and** `create`, not a hat, not glue-apply,
  not runbook, not "file a bug." Door pointer locates
  `<ws>/flows/` and does not name shopbook.
- Debugger location probe is `<ws>/flows/diagnostics.md`.
- Two-roots holds-column says `flows/`. BL-36 records the partial.
  Auditor `audit/` still named as parked nested home.
- `core/ROUTING.md` still classifies changes.

Close-the-books: `docs/BACKLOG.md` as slice 4. Do not invoke
`/backlog`. Do not unpark the rest of BL-36.

## Review history

### 2026-08-21 — needs-rework

Independent two-axis review (soundness + groundedness + skeptic).
Ground-check: `checked=24` `unresolved_count=11` — all eleven are
create-targets or unprefixed `scripts/…` paths, not drifted HEAD
files. Do not sequence until must-fix is folded.

Must-fix:

1. **Flows copy is unnumbered and has no unfinished predicate
   (project-hooks Guard hole).** Location: Mechanism *`flows/`* copy
   rule; HEAD `verbs/setup.md` Guard resume (1–6), `seed.sh` refuses
   existing doctrine. Copy sits “after seed.sh / before the door”
   with no walk number. Resume after a half-done seed skips it.
   Optional `check` drift only runs when `flows/` already exists and
   `foreman` is present — missing copy is presence-false, no finding.
   Fix: number the copy (own step or fold into step 2 as “project
   payload”); Guard unfinished = `$SKILL/flows` present AND a source
   stem missing at `$DST`; `check` reports that unfinished copy;
   same step on migrate. Range (1–6) if the walk grows.

2. **Two writers of one door-block grammar, no shared
   implementation.** Location: Approach (setup writes the initial
   block; does not invoke `/foreman`); Door block (“one grammar”);
   slice 2 vs slice 3 `flows-door.sh`. Red-proof 5 allows “a unit of
   the door-write helper” with no owner. Fix: one implementation
   from slice 2. Either ship `flows-door.sh` in slice 2 (face or
   future-foreman path) and have setup/migrate/`sync` call `apply`,
   or state duplication-accepted and pin both writers to one golden
   fixture. Do not leave slice 2 as unscripted agent splice.

3. **Door keeps the ROUTING-compiled table and adds a flows
   block.** Location: *`flows/`* “Door write still integrates…
   **Add** a delimited flows block”; HEAD `setup.md` 57–63 still
   compiles dispatch rows from `core/ROUTING.md`. Two tables on
   `AGENTS.md`. Fix: pick one. Replace the compiled dispatch table
   with the delimited projection (and retarget ROUTING.md / review
   POLICY / setup minimum / face SKILL.md), or keep the compiled
   table and drop the flows block (then `foreman` has no door job).

4. **`--check` / `drift` / `block=missing` underspecified.**
   Location: `foreman` walk steps 2–4. `block=missing` with
   `flows_dir` present is in neither exit arm; drift is stem-set
   only (wrong paths still `drift=false`); orphan table
   (`flows_dir` missing, `block=ok`) cannot be greened by `apply`;
   CLAUDE.md-only door unresolved. Fix: a decision table for every
   pair of `{flows missing|present} × {block missing|ok|malformed}
   × {AGENTS|CLAUDE|both|neither}`. Drift = stem **and** resolved
   path. “Does not scan the door” means workspace resolution only;
   pass `--door` or state AGENTS.md-only writes.

5. **The six files are not one kind.** Location: Goal / Mechanism
   “six pack lanes.” HEAD `ROUTING.md` dispatch table has **four**
   rows (`bug`/`patch`/`feature`/`spike`). `diagnostics.md` and
   `doc-audit.md` are station chores, not classification lanes.
   Setup compiles the door from those four rows, not from
   `**/workflows/*.md`. Fix: split classification lanes (4) from
   playbooks/chores (2). Say which set the door block lists, and
   whether it replaces the ROUTING table (finding 3).

6. **Living doctrine still classifies those files as doctrine.**
   Location: “Which-home box does not add a fifth landing class.”
   HEAD `DOCTRINE.md` Which-home: “Doctrine: an audit rubric, a
   diagnostics playbook, a build lane, a station chapter.”
   `debugger/SKILL.md` 40–47: “The diagnostics playbook **is
   doctrine**, so it sits at `<agent-workspace>/doctrine`.” A path
   flip without reclassifying leaves debugger resolving the doctrine
   home for a file that moved out, and Which-home still teaching
   “a build lane” is doctrine. Stamp paragraph (`DOCTRINE.md`
   368–373) “playbooks, and lanes are doctrine and resolve through
   `<agent-workspace>/doctrine`” is the same claim. Fix: slice 2
   retarget debugger’s location probe (workspace `flows/`, two-level
   access); keep the stamp as the *policy* probe. Slice 4 must edit
   Which-home’s “Doctrine: …” sentence and the stamp/lanes sentence,
   not only a layout example. Audit rubric may stay doctrine.

Nice-to-have:

7. **`/foreman` reinstalls the worst routing token.** Slice 1
   strips hat triggers from the face description; slice 3 mints a
   skill whose `name:` is `foreman` (slash-command + description
   key). Historical `/foreman` and `context.sh` alias collide with a
   different job. Human chose the name; still a routing risk. Fix:
   a non-retired slug (`flows-door` / `door-sync`), **or** a
   description that cannot fire on build-station / v1-role prompts.
   Independence forbids “not clankshop” contrast in the description.

8. **Optional member never runs on `/clankshop setup`.** Unlike
   journal (required, setup step 3) and hooks (optional, still
   filled when present), `foreman` is skipped even when installed.
   Birth path does not drift (copy + initial block). Growth path
   (the only job the skill exists for) is a manual `/foreman sync`
   nobody is forced to run; `check` nags only if the script is
   present. Fix: either call the projector from setup/`check` when
   the member is present (hooks pattern), put `flows-door.sh` on
   the face next to `hooks-glue.sh`, or state loudly that the
   steward is growth-only and not part of atomic setup.

9. **Grep gates miss leftover English and relative paths.** Gate 3
   is `workflows/` under `seed/` only; payload
   `skills/clankshop/flows/bug.md` can still say
   `test/workflows/diagnostics.md`. Gate 5 requires a
   `doctrine/.*/workflows/` prefix, so `build/workflows/feature.md`
   in ROUTING.md would pass. No red-proof that the *grep* goes red
   on a planted leftover. `context.sh` “workflows load lazily” is
   listed in slice 1 for aliases, not slice 2. Fix: also match
   `build/workflows|test/workflows|review/workflows`; plant a
   leftover string; include `flows/` payload and `context.sh` on
   slice 2.

10. **Slice file lists omit files the change reddens.** Slice 2
    misses `SKILL.md` Assets, `check.md`, setup Notes pathspec
    (`flows/`), `PACK.md` debugger blurb (“test station’s
    diagnostics”), `seed/build/workflows/bug.md` relative pointer,
    lint-doctrine-consumer-test.sh line 132 (indented RED, not only
    positives). Slice 4 misses BL-13/BL-16 “foreman is retired”
    wording if a live skill reuses the name. Doctrine “register
    durable-home + steward skills” vs this spec’s no-`init`
    in-place steward: record an exception or the implementer
    violates one document.

11. **Glue-bullet quote is not on HEAD.** Spec says keep “v1
    `foreman` oven is not the glue surface.” Live bullet:
    “Project hooks files … are the glue surface … there is no
    oven.” No “v1 `foreman`” in that sentence. Quote HEAD; add the
    new-steward clause onto “there is no oven.”

12. **Two remaining workflow-shaped trees after un-nest.** Auditor
    `doctrine/test/workflows/audit/` stays (parked, correct as a
    non-move). The layout story must say that remaining home by
    name, not imply one `flows/` tree is the only workflow shape.

13. **Hats-off does not require slices 2–3.** Independently
    shippable. Human asked for the combined spec; still three
    mechanisms. Coupling forces slice 2 to invent a door grammar
    before the owner skill exists (feeds finding 2). Split, or
    make slice 2 copy-only and delay projection to slice 3 *using
    the one script*.

Unverified / failed as kill shots (do not block on these as
stated): “door drifts immediately” (birth path is specified to
match); “one home per fact” is not a named DOCTRINE rule;
BL-36 unpark was asked, not unasked; v1 oven *responsibilities*
(register-route / `skill:` / derive-seams / stamp-health) are
correctly rejected.

Independent reviewers: three read-only explore seats (soundness,
groundedness, skeptic). Confidence high on (1)–(6) against HEAD
setup Guard / ROUTING.md / debugger SKILL.md / Which-home.

### 2026-08-22 — revise dispositions

| Id | Action | Disposition |
|---|---|---|
| F1 | keep — expand setup step 2 | resolved — step 2 is project payload (`seed.sh` skip-if-present + incumbent-safe copy); unfinished = source stem missing; `check` reports it; Guard range stays (1–6) |
| F2 | keep — face owns `flows-door.sh` | resolved — face script in slice 2; setup/migrate/`check` call it; foreman bundles a copy with golden-byte test; setup does not invoke `/foreman` |
| F3 | keep — replace compiled door table | resolved — door is doctrine pointer + flows inventory; ROUTING walk stays in doctrine; Rejected: two door tables |
| F4 | keep — decision table | resolved — Mechanism *foreman* table; drift = `(stem, path)` pairs; AGENTS.md-only writes; `claude-only` / empty dir specified |
| F5 | keep — four lanes vs two chores | resolved — door lists the tree; ROUTING.md still four rows; diagnostics/doc-audit are chores |
| F6 | keep — reclassify | resolved — debugger location probe → `flows/diagnostics.md`; stamp stays policy; slice 4 Which-home + stamp paragraph |
| F7 | keep-optional — description only | resolved — name stays `foreman`; description drops "routing table" / hat language. Rename deferred |
| F8 | keep — growth-only + face checker | resolved — Goal/Approach: steward is not atomic setup; `check` uses the **face** script whenever `flows/` exists |
| F9 | keep-optional take | resolved — grep gate 3 matches `build/workflows\|test/workflows\|review/workflows` under `skills/clankshop/` including payload; red-proof 13 |
| F10 | keep-optional take | resolved — slice 2/4 file lists; steward skips `skill:` registration |
| F11 | keep-optional take | resolved — glue bullet quotes HEAD "there is no oven" |
| F12 | keep-optional take | resolved — auditor `audit/` named as remaining nested tree |
| F13 | keep-optional take sequencing | resolved — one spec; slice 2 = copy + face projector; slice 3 = growth verb |

### 2026-08-22 — needs-rework

Named re-review after revise (same-session; depth dial off).
Ground-check: `checked=29` `unresolved_count=12` — create-targets /
unprefixed `scripts/…` paths, not drifted HEAD files.

Prior F1–F13 dispositions stand. One new must-fix from the fold;
do not sequence.

Must-fix:

1. **Guard three arms are not quote-edited for copy or the flows
   block (G1 class, again).** Location: Mechanism *setup step 2*
   “Already-seeded green-list includes this predicate”; *Clankshop
   check vs foreman* “green-list includes unfinished copy”; slice 2
   `setup.md` “Guard green-list.” HEAD `setup.md` 24–34 is an
   **exhaustive** if/else: STOP iff check would be green
   (parenthetical: stamp, slots, door pointer, records, unfinished
   hooks); resume iff check would not be green **and** the
   parenthetical matches (missing stamp / leftover slots / no door
   pointer / records absent / unfinished hooks). A present door
   pointer + complete copy + **missing/malformed flows block**
   (or complete doctrine + **missing dest stems**) makes `check`
   red, so STOP does not fire, but the resume parenthetical matches
   **neither** arm → dead branch, write nothing. Project-hooks
   required quoting **all three** arms (STOP green-list, resume
   parenthetical, range). This fold named the copy predicate and
   the `check` findings; it did not quote-edit the resume list to
   include (a) unfinished copy, (b) missing/malformed flows block
   when `$DST` exists. Door apply is walk step 4; without (b) as
   step-4 unfinished, resume can treat “AGENTS.md exists” as step 4
   done and skip `apply`. Fix: slice 2 quote-edits Guard 24–34 all
   three arms. STOP green-list: unfinished copy finding=false **and**
   face `flows-door.sh check` would not report missing/malformed
   when `<ws>/flows` exists. Resume parenthetical: add unfinished
   copy **and** missing/malformed flows block. Range stays (1–6).
   Door step unfinished = `$DST` exists AND block missing or
   malformed. Red-proof: doctrine+stamp+door pointer+records+hooks
   green, (i) one source stem missing, (ii) stems present but block
   absent → resume, not STOP, not dead branch; (i) runs copy arm,
   (ii) runs door `apply`; then check green. Disable the
   parenthetical edit, confirm write-nothing on (ii), restore.

Nice-to-have:

2. **`face-test.sh` scripts loop still only `seed.sh` /
   `migrate-scan.sh`.** Slice 2 adds `scripts/flows-door.sh` that
   setup/migrate/`check` lean on. Add it to that loop (and
   `bash -n`) in slice 2’s file list, same pattern as hooks-fill
   being its own suite if preferred — but then say so. Currently
   neither.

F1–F6 as folded are internally consistent (payload step, face
script, one door table, decision table, four-vs-two, reclassify).
Confidence high on (1) against HEAD `setup.md` 24–34 and the
project-hooks G1 pattern.

### 2026-08-22 — revise dispositions (Guard + seeding + experimental)

| Id | Action | Disposition |
|---|---|---|
| G1 | keep — quote-edit Guard 24–34 three arms | resolved — STOP/resume/range; copy unfinished + missing/malformed block; door step unfinished; red-proof 6 (i)(ii) |
| G2 | keep-optional take | resolved — slice 2 `face-test.sh` scripts loop includes `flows-door.sh` |
| N1 | keep — independent seeding | resolved — owner copies `flows/`/`hooks/`/`templates/`; six pack files remain clankshop-owned; `foreman` never seeds |
| N2 | keep — experimental charter | resolved — Goal/SKILL.md charter (manage/execute flows, apply glue); this feature implements `sync` only; execute/glue-apply out of scope |

### 2026-08-22 — needs-rework

Named re-review after the Guard + seeding + experimental fold
(same-session authorship; depth dial off). Ground-check:
`checked=29` `unresolved_count=12` — create-targets / unprefixed
`scripts/…` paths, not drifted HEAD files.

G1/G2/N1/N2 are present in the body (Guard 24–34 three-arm
quote-edit + red-proof 6 (i)(ii); slice 2 `face-test.sh` scripts
loop; owner-copies `flows/`/`hooks/`/`templates/`; execute/glue-apply
Rejected this pass). F1–F13 dispositions stand. One new must-fix
from this fold; do not sequence.

Must-fix:

1. **Description lead is the experimental charter; only `sync`
   exists (finding-5 class).** Location: Mechanism *`foreman` skill*
   Description draft; Judgment “Foreman description carries the
   experimental charter and the `sync` trigger”; Settled #4
   “charter sentence in `SKILL.md`”; Approach “the charter …
   is stated on the skill.” HEAD `DOCTRINE.md` *Self-scoping
   descriptions* + Authoring conventions: `description:` is the
   routing surface — “a **trigger, not a summary** — when to fire
   + keywords, not a feature inventory (that's the body's job).”
   The draft leads with “Help manage and execute host flows …
   and apply project glue,” then qualifies “This version: rebuild
   the AGENTS.md flows block.” The only verb is `sync`. Lead
   tokens fire on lane execution (`workstream` / “run the feature
   flow”) and on glue apply (`/clankshop setup`, hooks fill) —
   jobs this skill does not perform, and that this spec Rejects
   implementing this pass. Settled #5 already requires the
   description not fire on build-station or v1-role prompts.
   N2 asked for a charter sentence in `SKILL.md`; the fold put it
   on the routing surface. Fix: invert lead vs body. Description
   + Use-when = this-version job only (rebuild the delimited
   `AGENTS.md` flows block from `<agent-workspace>/flows/` when
   they disagree). Charter (manage/execute flows; apply glue; no
   opinions; no seeding) lives in the `SKILL.md` **body** Overview,
   marked experimental / not this release. Same invert on the
   Judgment bullet (charter in the body, trigger = `sync`). PACK
   roster may keep the experimental future — that is not a routing
   surface. Do not name `clankshop`. Do not say “routing table.”
   Do not use hat / build-station language. Goal’s charter-vs-tracer
   split can stay; it is not a routing surface.

Nice-to-have: none that survive this pass. PACK roster lead
(“manage/execute … this release: door `sync` only”) is honest
runbook, not a trigger.

Failed as kill shots: G1 dead-branch (folded; HEAD `setup.md`
24–34 still matches the quote target); G2 scripts loop (folded
into slice 2); independent-seeding vs six pack files (clankshop
owns those files; other skills copy theirs); two-roots
`workflow/` (slice 2 still names holds-column + Renames);
debugger “is doctrine” (`SKILL.md` 40–47; slice 2 retarget);
Which-home / stamp (`DOCTRINE.md` 368–373, 431–432; slice 4).

Confidence high on (1) against DOCTRINE description-as-trigger
and the 2026-08-17 clankshop finding 5. Same-session authorship
noted; the fold is what this pass inspects.

### 2026-08-22 — revise dispositions (consult finder; keep name)

| Id | Action | Disposition |
|---|---|---|
| R1 | keep — description must match verbs | resolved — description is find/follow + pointer sync; consult/caller split is in Mechanism |
| H1 | keep — name stays `foreman` | resolved — sentimental; not a hat; description forbids hat/build-station language |
| H2 | keep — glue is the directories | resolved — using `flows/`/`hooks/`/`templates/` is applying glue; no composer; doctrine quote stays HEAD |
| H3 | rejected for this spec | rejected — no scheduling/maintenance charter |
| H4 | keep — pointer, not catalog | resolved — door is one-line pointer; extra stems do not drift; Guard/check retargeted |
| H5 | keep — consult child, caller follows | resolved — find walk; child returns `path=`/`why=`; no child execute |
| H6 | keep — `core/ROUTING.md` stays classifier | resolved — Rejected: second ROUTING.md; Rejected: foreman edits core |

### 2026-08-22 — revise dispositions (shopbook; script-only; upkeep)

| Id | Action | Disposition |
|---|---|---|
| P1 | keep — rename to `shopbook` | resolved — optional member `shopbook`; `foreman` not reused |
| P2 | keep — script-only find | resolved — no consult child; matches>1 asks; index uses title/use-when |
| P3 | keep — crawl-key upkeep | resolved — `upkeep` fills missing `title`/`use-when` only; not `migrate` |
| P4 | keep — pack files ship with keys | resolved — slice 2 payload includes front-matter |
| H5 | superseded | resolved — consult child dropped (P2) |
| H1 | superseded | resolved — name is `shopbook` (P1) |

### 2026-08-22 — revise dispositions (create / discovery)

| Id | Action | Disposition |
|---|---|---|
| C1 | keep — door is where | resolved — pointer names `<ws>/flows/`; does not name `/shopbook` |
| C2 | keep — description is who (find **and** create) | resolved — description fires on create/add/author a workflow, routine, or procedure; agent reaches for `shopbook` |
| C3 | keep — `new` mints a host stub | resolved — `flows-new.sh`; crawl keys + H1; caller authors the body; incumbent refuse; narrow `flows/` mkdir |
| C4 | keep — `new` is not seeding | resolved — pack/sibling copy stays with the owner skill; `new` is host-authored only |

### 2026-08-22 — needs-rework (create / discovery fold)

Named re-review after the create/discovery fold (same-session
authorship; depth dial off). Three read-only explore seats:
soundness, groundedness, skeptic.

Ground-check: `checked=46` `unresolved_count=0` — create-targets
(`skills/shopbook/**`, `skills/clankshop/flows/`, `flows-door.sh`,
`flows-new.sh`, …) are not drifted HEAD files. Prior F/G/P/C
citations still describe HEAD (Guard 24–34, ROUTING four rows,
debugger “is doctrine”, Which-home + stamp, hooks mkdir predicate,
glue bullet, face-test loops, lint `:132`, two-roots `workflow/`).

C1–C4 as *intent* stand (door is where; description is who;
`new` mints a stub; `new` is not pack copy). Two must-fixes from
this fold; do not sequence.

Must-fix:

1. **Create intent never reaches `new` (finding-5 class, dispatch).**
   Location: Approach *Discovery* “reaches for `shopbook` … and
   runs `new`”; Mechanism verbs “bare `/shopbook` [query] →
   **find**”; Find walk “`matches=0` → report none; stop. Do not
   invent a procedure.” Slice 3 names “find walk + `new` dispatch”
   but Mechanism never defines that dispatch. A create-shaped
   query (“create a release procedure”) loads shopbook via the
   description, then runs **find**. Empty tree → refuse to mint.
   A fuzzy `use-when` hit on `release` → **follow** an incumbent
   instead of minting. Journal’s table maps find vs other verbs
   and asks on unrecognized; this spec’s default walk is find.
   Fix: dispatch **before** find. Create/add/author/mint +
   (workflow|routine|procedure|playbook) → `new` walk (ask for
   stem if needed). Find’s `matches=0` / “do not invent” applies
   only after dispatch chose find. Red-proof: create-shaped
   prompt with `matches=0` still runs `new`, does not follow a
   fuzzy hit. Support: soundness + skeptic.

2. **`new` before setup can steal pack stems.** Location: `new`
   walk “Pack stems already copied by setup are incumbents;
   `new bug` refuses” — post-copy only. Setup copy never
   overwrites an incumbent. Red-proof 17 allows any kebab on
   empty `$DST`. `new bug` on a greenfield `.dev/flows/` mints a
   host stub; later setup skips clankshop-owned `bug.md`.
   Independent seeding loses the pack file without shopbook
   having copied it. Fix: pick one. (a) `new` refuses the six
   reserved pack stems (name them in the script; that is a
   published list, not a copy of sibling payload), or (b)
   host-stub-first is accepted and setup will not install that
   pack file — say so on both the copy rule and the `new` walk.
   Support: soundness. (Skeptic’s near-miss `features` vs
   `feature` is a different claim and failed as a kill shot.)

Nice-to-have:

3. **`runbook` in the shopbook description steals contractor.**
   Location: description draft “workflow, playbook, **runbook**,
   host routine”; Judgment names runbook. HEAD
   `skills/contractor/SKILL.md` description: “write a roadmap,
   implementation plan, or **runbook** … execute a plan or
   runbook.” Boundary-audit battery already routes “compile a
   runbook” / “execute the implementation plan” to contractor.
   Workstream lane-execution was **not** re-opened (failed as
   kill shot). Fix: drop `runbook` from shopbook `description:`
   and the Judgment name-list. Keep procedure / playbook /
   routine / shopbook / `flows/`. Support: skeptic. Soundness
   did not raise contractor; still a routing-surface edit.

4. **YAML `title` / `use-when` have no quoting or refuse rule.**
   `--title` / `--use-when` and `upkeep` H1 → `title` splice into
   a YAML block. Colon, quote, newline, or `---` can mint
   `fm=malformed` that `upkeep` will not repair. Defaults from a
   kebab stem are plain-YAML-safe. Fix: single-line values;
   refuse newline / `---`; quote scalars. Same rule on `upkeep`.
   Red-proof: `--title 'Cut: "v1" release'` still `fm=ok`.
   Support: both seats (skeptic: must-fix / sequencing;
   soundness: nice-to-have because defaults are safe). Kept
   nice-to-have: script is implementable from kebab defaults;
   optional flags are the hole.

5. **Stem-from-title has no algorithm.** “Derive kebab from a
   phrase” vs script regex. No-human missing `--stem` has no
   `reason=`. Fix: ask until the argument is already kebab, **or**
   name the slug (`tr`/`sed` as notepad/records.sh) then validate.
   Script regex stays the gate. Support: both seats. Not a
   sequencing blocker.

6. **Description draft mixes the trigger with “Do not name
   `clankshop`.”** Paste-the-draft → sibling-in-description lint
   FAIL. Fix: quote only the live `description:` string; move
   authoring constraints outside it. Support: skeptic.

Failed as kill shots (do not block): workstream “run the feature
flow” (find-then-follow is not lane execution); create without
shopbook (honest optional + door fallback); `new` does not write
the door (description + default `.dev` still locate); empty-body
stub is script success (caller authors, same as find’s caller
follows); `features` vs `feature` exact-path refuse; description
length (~557 routing chars, under 1024 / ~700); seeder skills
will not `/shopbook new` (no live `description:` says “create a
workflow”); Judgment-only “reaches for shopbook” (routing probe,
not a mechanical red-proof); `flows-new.sh` does not belong on
the face scripts loop; `check` ignoring extra dest files;
`reason=ok` × `created=false` (pairs are named); Grok Rhai
`create-workflow` (harness-agnostic; object is `flows/*.md`).
Narrow `flows/` mkdir matches the HEAD hooks predicate.
`upkeep` “does not create files” is verb-scoped; Guard 24–34 is
not a `new` predicate.

Confidence high on (1)–(2) against Discovery vs the find walk
and incumbent copy vs empty-DST `new`. Groundedness high
(`checked=46`). Same-session authorship noted; the fold is what
this pass inspects. Do not sequence.

### 2026-08-22 — revise dispositions (dispatch / reserved / description)

| Id | Action | Disposition |
|---|---|---|
| D1 | keep — dispatch before find | resolved — Mechanism dispatch table; create-shaped intent → `new`; find `matches=0` does not fall through; red-proof 20 |
| D2 | keep — refuse six pack stems | resolved — `reason=reserved` even on empty `$DST`; reserved before incumbent; red-proof 18. Recast: not "file a bug" |
| D3 | keep — drop `runbook` | resolved — live `description:` and Judgment omit it |
| D4 | keep-optional take — YAML quote | resolved — double-quoted scalars; refuse newline/`---`; `reason=bad-value`; red-proof 19 |
| D5 | keep-optional take — stem propose+confirm | resolved — propose kebab then confirm; missing stem / no human → stop |
| D6 | keep-optional take — quote only the live string | resolved — authoring constraints sit outside the `description:` draft |
| D7 | keep-optional take — fact pairing | resolved — `created=true` ⇔ `reason=ok` ⇔ exit 0 |
| D8 | rejected | rejected — `new` mints records or aliases a file-a-repro verb; host-stub-first on pack stems |

### 2026-08-22 — needs-rework (dispatch / reserved / description fold)

Named re-review after D1–D8 (same-session authorship; depth dial
off). Three read-only explore seats: soundness, groundedness,
skeptic.

Ground-check: `checked=57` `unresolved_count=0`. Live
`description:` 546 characters (≤750 / 1024). No `runbook`,
`clankshop`, `file a bug`. Contractor still owns runbook;
debugger still owns `/debugger file`. Prior Guard / ROUTING /
Which-home / mkdir citations still match HEAD.

D1–D8 as *intent* stand (dispatch-before-find, reserved six, no
runbook, YAML quote, stem propose, live string, fact pairing,
no record-mint). Two must-fixes from this fold; do not sequence.

Must-fix:

1. **Red-proof 20 cannot go red.** Location: Verification item 20
   “agent-script contract”; slice 3 harness is bash (`flows-*-test.sh`).
   Dispatch is SKILL.md prose, not a facts script. A green
   `run.sh` cannot fail if create-shaped intent still walks find.
   Support: soundness + skeptic. Fix: drop 20 from mechanical
   red-proofs. Pin dispatch in bash: `SKILL.md` contains the
   dispatch table **before** the find walk, and does not say
   bare `/shopbook` [query] → find. Put “create a release
   procedure” → `new` (does not follow a fuzzy `release` hit)
   in Judgment / a routing probe, same class as journal’s table.

2. **Dispatch has no else-row for a topical query.** Location:
   Dispatch table. Create-shaped → `new` is specified. “How do
   we handle bugs here?” / a subject with no `new`/`list`/`search`
   token is neither create-shaped nor “list / search / run /
   follow,” and “unrecognized **verb** token → ask” only fires
   when there is a verb token. D2’s guide path (find →
   `flows/bug.md`) is not a table row. Support: soundness
   (must-fix); skeptic treated create-intent as closed and left
   this as first-match hygiene. Fix: first-match. Else-row: no
   recognized verb token and not create-shaped → **find**
   (topical query / “how we handle X” / the description’s run
   examples). Keep unrecognized verb (`/shopbook foobar`) as
   ask. Keep `/shopbook new` and create-intent on the `new` row.
   Name the bug-lane guide path on the find row.

Nice-to-have:

3. **No-human + non-kebab stem** is propose+confirm with no
   confirm path. Fix: same as missing stem — stop, do not
   slugify, do not call the script. Support: soundness.

4. **Greenfield reserved** (`new bug` before setup) reports
   `reserved` with no dest and no next step. Fix: report
   pack-owned stem; do not mkdir; recovery is setup or find
   after the copy. Support: soundness.

5. **Slice 2 payload YAML** stays unquoted while `new`/`upkeep`
   quote. Fix: six pack files use the same double-quoted
   scalars (or state pack titles are colon-free and the parser
   accepts both). Support: soundness.

6. **Empty / whitespace-only** `title` not refused. Fix: treat
   as `bad-value`. Support: skeptic.

7. **Reserved list publication site** unnamed. Fix: one list in
   `flows-new.sh`; SKILL.md points at it. Support: skeptic.

Failed as kill shots: `/shopbook new bug` vs “create a bug
procedure” vs “file a bug” (consistent: reserved / reserved /
not shopbook); dropping runbook (contractor still owns it;
playbook steals nothing live); hardcoded six names (filename
list, not sibling copy); YAML colon+quote (specified);
“workflow” / Grok create-workflow (not worse); reserved after
setup vs incumbent (check order + red-proof 18); Guard / two
door tables / consult child / shopbook on the door (not
reopened); description length 546.

Confidence high on (1) against slice 3’s bash harness vs an
LLM-only red-proof. Groundedness high (`checked=57`). Do not
sequence.

### 2026-08-22 — revise dispositions (human: shopbook is independent)

| Id | Action | Disposition |
|---|---|---|
| E1 | keep — else-row is find | resolved — topic / how-do-we-X / `new bug` when not authoring → find; miss → not found |
| E2 | keep — pin dispatch in the skill file | resolved — red-proof 20 is a grep that the table sits above find, not a fake prompt classifier |
| E3 | supersede D2 | resolved — **no** reserved-stem list. Shopbook does not know pack names, does not require a workshop, does not name `clankshop`. Missing procedure → not found |
| E4 | keep-optional take | resolved — no human + non-kebab → stop, do not slugify |
| E5 | keep-optional take | resolved — empty/whitespace title → `bad-value` |
| E6 | keep — do not co-mingle YAML | resolved — shopbook quotes what it **writes**; it **reads** quoted or unquoted files already on disk. Pack payload format stays a face concern |

### 2026-08-22 — needs-rework (independence split)

Named re-review after the human-confirmed split (shopbook
independent; look-up miss = not found). Three read-only seats.
Ground-check: `checked=64` `unresolved_count=0`. Live
`description:` 550 characters. Prior Guard / ROUTING / debugger
citations still match HEAD.

The split as *intent* stands. Three must-fixes so an implementer
cannot mint on look-up or paste a sibling name into shopbook.
Do not sequence.

Must-fix:

1. **`/shopbook new <stem>` can still mint.** Dispatch row 2
   (`/shopbook new` when authoring) matches the invocation form
   before the “not authoring → find” row. The `new` walk is
   titled `/shopbook new <stem>` and takes the argument as the
   stem. `verbs/new.md` will be written as “always mint.”
   Support: soundness + skeptic. Fix: drop that overlapping
   row. Enter `new` only after dispatch chose authoring
   (create/add/author + procedure/workflow/routine/playbook).
   `/shopbook new <stem>` without those words is find that
   stem; miss → not found; do not call the create script.
   Retitle the `new` walk “when dispatch chose `new`.”

2. **Look-up of a stem is not an exact file probe.** “Find that
   stem” does not say to open `$DST/<stem>.md` (or require an
   exact stem hit). Fuzzy search can miss or ask among other
   files. Support: soundness. Fix: for `/shopbook new bug` as
   look-up, test that one path. Absent → not found, no mint,
   no mkdir.

3. **Shopbook upkeep names `/clankshop migrate`.** The walk an
   implementer pastes into `verbs/upkeep.md` names a sibling.
   Support: both seats. Fix: in shopbook verb files say only
   “not a workshop onramp; not `migrate`.” Keep the clankshop
   contrast in PACK.md / this spec. Grep `skills/shopbook/`
   `SKILL.md` + `verbs/` for no `clankshop`.

Nice-to-have:

4. Red-proof 20 as **two** greps (table above find; forbidden
   “bare query → find”), not one plant that cannot go red both
   ways. Distinctive row texts required.
5. “Add a procedure to the list” — `add`+procedure wins over
   list; say so.
6. Seed `context.sh` should not name `shopbook` (door already
   says not loaded until selected).
7. Look-up miss: `$DST` stays absent (no mkdir). A host file
   that happens to share a pack filename is an incumbent on
   the **face** copy — do not put those names in shopbook.

Failed as kill shots: “create a bug procedure” minting `bug.md`
(shopbook does not know pack names — correct under the split);
find miss writing a file (it does not); resurrecting a reserved
list (face incumbent-safe copy is enough); Guard / two door
tables / consult child / runbook (not reopened).

Most likely to fail at implement time: `verbs/new.md` always
mints on `/shopbook new <stem>`, so look-up invents `bug.md`.
Do not sequence.

### 2026-08-22 — revise dispositions (look-up does not mint)

| Id | Action | Disposition |
|---|---|---|
| L1 | keep — drop overlapping `/shopbook new` row | resolved — dispatch enters `new` only after create/add/author + procedure nouns, or `/shopbook new` with no stem; `new` walk titled when dispatch chose `new` |
| L2 | keep — exact stem probe | resolved — find-that-stem tests `$DST/<stem>.md`; miss → not found; no mint, no mkdir, do not call `flows-new.sh` |
| L3 | keep — upkeep does not name clankshop | resolved — shopbook verbs say "not a workshop onramp; not `migrate`"; grep gate 7 |
| N4 | keep-optional take — red-proof 20 two greps | resolved — table-above-find and forbidden bare-query→find planted separately |
| N5 | keep-optional take — add+procedure wins over list | resolved — first dispatch row names the object as a new file |
| N6 | keep-optional take — context.sh does not name shopbook | resolved — slice 2 uses door language + ROUTING walk |
| N7 | keep-optional take — look-up miss / face incumbent | resolved — red-proof 18 leaves `$DST` absent; face copy skips a host file at a pack filename |

### 2026-08-22 — needs-rework (look-up-does-not-mint fold)

Named re-review after L1–L3 / N4–N7 (same-session authorship; depth
dial on: three read-only seats). Ground-check: `checked=30`
`unresolved_count=12` — create-targets (`skills/shopbook/**`,
`skills/clankshop/flows/`, `flows-door.sh`) and unprefixed
`scripts/…` paths, not drifted HEAD files. Live `description:` 550
characters. Prior Guard 24–34, ROUTING four rows, debugger “is
doctrine”, Which-home + stamp, face-test loops, lint `:132`,
two-roots `workflow/`, contractor `runbook`, `/debugger file`
still match HEAD.

L1–L3 as *intent* stand in the dispatch table and find walk. The
central claim still fails at the router an implementer will write.
Do not sequence.

Must-fix:

1. **`/shopbook new <stem>` still never reaches the look-up row.**
   Location: Mechanism *Verbs* `` `new` → `verbs/new.md` (host
   stub) `` then `` bare `/shopbook` [query] → **dispatch** `` vs
   Dispatch “enter `verbs/new.md` only after this table chose
   `new`” vs library thin-router (journal / notepad /
   skill-builder: recognized token → verb file; bare → table).
   `/shopbook new bug` is not bare. Token `new` opens
   `verbs/new.md`. The look-up row is never consulted. The `new`
   walk still stems-then-`flows-new.sh`. Title “when dispatch
   chose `new`” is not a STOP. Red-proof 20 greps row *text*,
   not that slash-`new` opens that row. Support: soundness +
   skeptic (same L1 failure mode). Fix: dispatch applies to
   **every** invocation, including `/shopbook new <stem>`. Drop
   “host stub” as a slash shortcut. `verbs/new.md` step 0: if
   the prompt is `/shopbook new <stem>` without create/add/author,
   STOP and run find-that-stem; do not call `flows-new.sh`. Grep
   that STOP. Retire Settled “Host-authored procedures go through
   `shopbook new`” as the mint recipe (authoring nouns, or
   `/shopbook new` with **no** stem).

2. **Red-proof 18’s last sentence re-teaches mint on the look-up
   shape.** Location: red-proof 18 “`new --stem publish-release`
   on empty `$DST` still creates (authoring — dispatch chose
   `new`).” Dispatch would **not** choose `new` for
   `/shopbook new publish-release`. Support: soundness. Fix:
   keep 17 as the only mint pin (`flows-new.sh` after dispatch
   chose `new`). 18: missing `$DST` + index `matches=0` and
   exact-stem miss; `$DST` stays absent; do not run
   `flows-new.sh` in that test. Delete the last sentence.

3. **`/shopbook new procedure` has no walk.** Location: Settled
   #4 conjunction vs dispatch row 5 “without those authoring
   words.” If “those” includes type nouns, row 5 does not match,
   row 1 lacks create/add/author, row 6 needs no stem → no walk
   (then the Verbs list mints). Support: soundness (must-fix);
   skeptic (nice-to-have). Fix: authoring **verbs** =
   {create, add, author} only. `/shopbook new <stem>` is look-up
   even when `<stem>` is `procedure`. Row 1 still wins for
   “create a bug procedure.”

Nice-to-have:

4. Red-proof 20(a) proves presence, not “above find.” Require
   look-up-row line number < `Find walk` heading.
5. Slice 3 `verbs/upkeep.md` parenthetical “no `clankshop`” —
   if pasted, gate 7 fails on intended text. Keep the sibling
   name out of shopbook file-list parentheticals.
6. No grep that seed `context.sh` omits `shopbook`.
7. Description create-clause omits `playbook` (dispatch row 1
   includes it).
8. Early Review-history tables still say “foreman bundles a
   copy” / `reason=reserved` (superseded later; not HEAD).

Failed as kill shots: reserved-stem list (body `reason=` has
none); workshop required; `clankshop` in shopbook `SKILL.md` /
`verbs/` (gate 7; no shopbook file is specified to contain it);
runbook / “file a bug” / hats / `migrate` on the live
description; Guard / two door tables / consult child; “create a
bug procedure” minting `bug.md` (correct under the split);
look-up miss mkdir via the index.

Most likely to fail at implement time: `verbs/new.md` always
mints on `/shopbook new <stem>`, so look-up invents `bug.md`.
Same L1; leftover Verbs list + “bare → dispatch” is why it
survived. Do not sequence.

### 2026-08-22 — revise dispositions (create verb; only router)

| Id | Action | Disposition |
|---|---|---|
| R1 | keep — dispatch is the only router | resolved — dispatch applies to every invocation; `create` → `verbs/create.md` only after the table chose `create`; `/shopbook new` is not a verb; no `verbs/new.md`; create walk step 0 STOP |
| R2 | keep — red-proof 18 does not re-teach mint | resolved — 17 is the script mint pin; 18 is look-up miss / no `flows-create.sh` |
| R3 | keep — authoring verbs pin | resolved — {create, add, author} only; `/shopbook new procedure` is look-up of `procedure.md`; `/shopbook create procedure` mints |
| R4 | keep — mint verb is `create` | resolved — human: `create` not `new`; `/shopbook create` mints; `/shopbook new <stem>` looks up |
| N4 | keep-optional take — 20(a) is order | resolved — look-up-row line < Find walk heading |
| N5 | keep-optional take — slice 3 parenthetical | resolved — shopbook file-list does not name `clankshop` |
| N6 | keep-optional take — context.sh grep | resolved — grep gate 9 |
| N7 | keep-optional take — playbook in create clause | resolved — live `description:` create/add/author includes playbook |
| N8 | keep-optional take — stale early tables | resolved — F2/F3/D2 superseded by P1/H4/E3/R4; do not implement reserved stems or a flows-inventory door |

### 2026-08-22 — approve

Named re-review after the `create` verb + leftover-router fold
(same-session authorship; three read-only seats). Ground-check:
`checked=31` `unresolved_count=12` — create-targets /
unprefixed `scripts/…` paths, not drifted HEAD files. Live
`description:` 563 characters. Prior Guard 24–34, ROUTING four
rows, debugger “is doctrine”, Which-home + stamp, contractor
`runbook`, `/debugger file` still match HEAD.

Must-fix: none. Central claim holds: `/shopbook new bug` with no
`$DST/bug.md` is not found (no mint). `/shopbook create bug`
mints. `new` is not a shopbook verb; no `verbs/new.md`.
Dispatch applies to every invocation.

Nice-to-have (not sequencing blockers): gate 8 vs tests; create
walk step 0 is belt not the look-up router; “skill-builder new
in spirit” is scaffolding. Residual implement-time risk is a
journal-shaped SKILL.md that *omits* the `/shopbook new <stem>`
look-up row (ask instead of not-found) — that is a look-up miss,
not a mint; red-proof 20 already requires that row.

Do not sequence until the owner promotes `status: current`.

### 2026-08-22 — revise dispositions (query verb; no slash-topic)

| Id | Action | Disposition |
|---|---|---|
| Q1 | keep — slash look-up is `/shopbook query` | resolved — `verbs/query.md`; `list` / `search` / `find` alias that file; no topic = list; red-proof 20 distinctive row is `/shopbook query` |
| Q2 | keep — unknown first slash token is **ask** | resolved — `/shopbook <query>` slash format rejected; `/shopbook bug`, `/shopbook new bug`, `/shopbook foobar`, bare `/shopbook` ask which of query / create / sync / upkeep |
| Q3 | keep — NL description-fire still queries | resolved — how-do-we-X / start the env / publish (no slash verb) still run the query walk |
| Q4 | keep — `new` is not a look-up token | resolved — `/shopbook new <stem>` is unknown → ask; no `verbs/new.md`; create walk step 0 STOP+ask if opened for `new` |
| Q5 | keep — kebab argument prefers the exact file | resolved — query walk tests `$DST/<stem>.md` first; miss continues to search; no mint, no mkdir |

### 2026-08-22 — revise dispositions (NL-scoped dispatch; query walk owner)

| Id | Action | Disposition |
|---|---|---|
| T1 | keep — dispatch row 1 is NL-only | resolved — slash mint is `/shopbook create`; slash `add` / `author` ask; `{create, add, author}` are NL authoring verbs; no `verbs/add.md` / `verbs/author.md` |
| T2 | keep — query walk lives in `verbs/query.md` | resolved — `SKILL.md` is the journal-shaped table; 18 greps `verbs/query.md`; 20 is table-in-SKILL.md + heading-in-query.md |
| T3 | keep-optional take — 20 pins this fold | resolved — distinctive ask row, NL how-do-we-X row; forbid `/shopbook new` as look-up and bare `/shopbook` → query/list |
| T4 | keep-optional take — NL else | resolved — "use the shopbook" with no further intent asks; NL pointer-repair → `sync`; NL missing keys → `upkeep` |
| T5 | keep-optional take — PACK seam subject | resolved — `/shopbook` may query / create / sync / upkeep |
| T6 | keep-optional take — gate 8 alias paths | resolved — `verbs/(new\|list\|search\|find\|add\|author).md` empty under `skills/shopbook/` |

### 2026-08-22 — approve (T1–T6 re-review)

Named re-review after T1–T6. Ground-check: `checked=31`
`unresolved_count=12`. Must-fix: none. Owner accepted and
folded the five pins below. Status: `current`.

### 2026-08-22 — revise dispositions (pins after approve)

| Id | Action | Disposition |
|---|---|---|
| N1 | keep-optional take — gate 8 is file absence | resolved — existence `test ! -e` in tests; content `rg` on `SKILL.md` + `verbs/` only |
| N2 | keep-optional take — drop query-walk Otherwise | resolved — step 3 searches when there is a query, including kebab miss |
| N3 | keep-optional take — slash matches Invocation | resolved — deleted First match wins; Trigger is NL-only; 20(b) plants add/author → `create.md` |
| N4 | keep-optional take — 18/20 grep SKILL.md walk bytes | resolved — `SKILL.md` must not contain `$DST/<stem>.md` or `do not call flows-create.sh` |
| N5 | keep-optional take — skill-builder alias cell | resolved — `query` (alias `list` / `search` / `find`) → `verbs/query.md`; no one-file-per-alias set |
