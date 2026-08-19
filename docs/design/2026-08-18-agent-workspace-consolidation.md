---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# Two homes — `agent-records` + `agent-workspace` — Spec

`stream/feat` **feature 3**. Argued from the 2026-08-18 brainstorm, grounded against `main` @
`ce7e758` + branch `e8f25a2`. The `handbook` extraction is **parked behind this**
(`2026-08-18-handbook-skill-extraction.md`, *Status: PARKED*) — this feature answers the question
that blocked it.

> **Read the Decision log before re-deriving anything**, and do **not** re-open the naming table:
> five candidates were burned with recorded evidence.

## Problem

The front door carries **three** path variables where only one has ever demonstrated variance, and
the two dependent ones nest *inside* the first — which forces the records layer to disown part of
its own directory.

1. **Two of three variables have no variance case.** `agent-records` has real brownfield history
   (hosts declaring `records-root: dev`, kept in place rather than `git mv`'d — `migrate.md:24-26`).
   `agent-templates` and `agent-doctrine` both default *under* the resolved records home
   (`DOCTRINE.md:217-223`) so that "one `agent-records:` line moves all three." Neither has a live
   host declaring it, and `DOCTRINE.md:236` concedes `agent-doctrine`'s case is "partly
   **prospective**."

2. **The nesting forces the records tool to exclude its own subdirectories.** `records.sh:64`:

       templates/*|scripts/*|doctrine/*|history.tsv) err "reserved path, not a record: $rel" ;;

   and `:82` skips `templates|scripts|doctrine` when enumerating stores. `:70`'s comment says why:
   *"doctrine is reserved because the agent-doctrine home defaults to…"*. **The carve-out list is
   the defect's signature** — `.records/` hosts three kinds of thing that are not records, so the
   records layer must be taught to ignore them.

3. **A workshop adds a fourth home nobody declares.** `.handbook/` is the deployed doctrine tree,
   but **5 consumer skills read `agent-doctrine:` and 0 skills write it** (verified exhaustively).
   So consumers resolve the default `.records/doctrine/`, miss `.handbook/` entirely, and — per
   Doctrine-touching rule 3 — `/auditor setup` will *create a second doctrine tree there beside the
   real one*. Concretely lost today on every seeded project: the design-station summon
   (`blueprint:38`), build-station summon (`contractor:29`), `workstream`'s feature lane
   (`flow.md:56`), and `debugger`'s diagnostics playbook (`SKILL.md:31`).

## Goal

**Two homes, positively defined.** `agent-records` is the file cabinet — dated, typed, closeable
documents. `agent-workspace` is the development environment — doctrine, templates, scripts,
station chapters: everything the agents need on this project that is not a record. Done means no
home defaults inside another, the carve-out list is no longer architectural, and a default-layout
workshop is found by its own consumers **without declaring anything**.

## Approach

Two front-door variables:

    agent-records:   .records   (unchanged; `records-root:` still accepted)
    agent-workspace: .dev       (new)

`agent-templates` and `agent-doctrine` are **retired as variables** and become fixed subpaths of the
workspace, so there is nothing new to declare and one `agent-workspace:` line moves them together:

    .records/                      .dev/
      adr/ bugs/ design/ notes/      doctrine/     living normative prose + the station chapters
      plans/ reports/ tickets/       templates/    schemas instances mint from
      trackers/                      scripts/      deployed tools (records.sh, context.sh)
      history.tsv

**Workflows are station-scoped, not a peer** — `.dev/doctrine/<station>/workflows/…`, shape
unchanged. Verified: the seed has `build/workflows/`, `test/workflows/`, `review/workflows/`, and
every consumer path is `<station>/workflows/…`. No top-level workflows directory exists anywhere.

**The two homes MAY coincide.** A legacy host declaring both at `dev/` keeps working: those hosts
were *already* mixed, so nothing is lost and no `git mv` is forced. The consequence, stated rather
than glossed: **`records.sh`'s reserved-name skip does not die — it demotes** from architectural
(every host nests doctrine and templates inside records) to legacy-compat (needed only where a host
deliberately points both homes at one directory). Greenfield hosts stop depending on it.

**Any other layout is a declaration, not a redesign.** A host preferring `.workspace/`,
`.handbook/`, or a legacy `dev/` writes one `agent-workspace:` line; the default only has to be
right for a fresh project.

**The pair deliberately breaks the echo pattern — do not "fix" it.** The other three variables name
their own default (`agent-records`→`.records`, and both retired siblings echoed too). This one does
not, on purpose (settled 2026-08-18, human): the **variable** must name the concept precisely for
prose explaining *what the home is for*, while the **directory** must stay short and legible for a
literal appearing at depth in ~30 files — `.dev/doctrine/test/workflows/audit/GUIDE.md` versus
`.workspace/doctrine/test/workflows/audit/GUIDE.md`, where the second also stutters against
`workflows/`. Forcing one word to do both jobs compromises one. The consistency cost is small
because `DOCTRINE.md:223-224` already requires skills to write default paths **literally** rather
than as variables, so the mapping is stated wherever used and learned once.

### Why not the alternatives

- **One root** (`.dev/records/`, `.dev/doctrine/`, …) — the fewest variables, and the tempting answer
  to "too many dynamic paths." Rejected because it breaks the *only* variance ever demonstrated: a
  brownfield host declaring `records-root: dev` cannot relocate records independently if records
  live inside the other home.
- **De-nest the three existing homes** (keep `agent-templates`/`agent-doctrine`, move their defaults
  to top level) — kills the carve-outs without inventing a name. Rejected because it keeps three
  variables to express two concepts and leaves two of them still without a variance case.
- **Leave it alone.** Rejected because Problem 3 is a live regression and the parked feature cannot
  be specced without answering "where does the seed land."

### Naming — five candidates burned (hard-won; do not re-propose)

| candidate | killed by |
|---|---|
| `.agents/` | **Adjudicated twice and reverted.** `2026-08-18-records-layer-init.md:173-174` + `:1120`: *"This library already lives at `~/.agents/`. A project path that starts `.agents/` sends agents to the home directory."* And `2026-07-17-library-refactor-plan.md` Task 6 was literally *"Relocate on-disk homes under `.agents/`"* — the library migrated off it. |
| `.artifacts/` | **Inverts this library's vocabulary.** 140+ uses of "artifact" in `skills/`, dominant sense = a managed record (`contractor:123` *"job artifacts in `<agent-records>/plans/`"*; `migrate.md:30`'s header `\| legacy artifact \| store \|`). Would mean artifacts live in `.records/` and non-artifacts in `.artifacts/`. Externally a build-output convention connoting *disposable* — invites gitignoring hand-curated doctrine. |
| `test/` | Conventional **source** directory for test suites across most ecosystems. Also already claimed: `test` is one of four station names (`context.sh:16`). |
| `dev/` **undotted** | Undotted breaks the dotted = tooling-not-source signal every current home follows. Dotted `.dev/` is a different string and is **not** rejected. |
| *(fifth mention, non-binding)* | `2026-07-17-library-refactor.md:310-312` chose `.agents/` over `.artifacts/` and bare `.design`/`.dev`. Non-binding: (a) it rejected **two** domain-split roots — "root clutter" — where this is **one** directory *replacing* `.handbook/`, so root count is unchanged; (b) "unclear ownership" was true because no front-door variable existed (its §12 ruled one out); (c) the winner is **dead**. Its `.artifacts/` reasoning independently matches the row above. |

The first four candidates were all **negative** definitions ("everything that isn't a record"), and
negative definitions name badly. *Workspace* names what the home **is** — which is why it survives
as the **variable** even though the directory is `.dev/`.

## Mechanism

### M1 — the resolution rule

    <agent-workspace> = first line-start `agent-workspace:` in AGENTS.md, then CLAUDE.md;
                        else `.dev`

Same precedence and mechanism as `agent-records` (`DOCTRINE.md`'s front-door section). **No legacy
alias** — `records-root:` exists only because hosts declared it before a rename; `agent-workspace`
is new with zero declarations to honor. Skill prose keeps naming default paths literally
(`.dev/doctrine/…`, `.dev/templates/backlog/task.md`), never `$WORKSPACE/…`.

**Two-level access is unchanged doctrine:** resolve the home, *then* test for the artifact; a
missing artifact degrades exactly as the skill degrades with no workspace at all.

### M2 — retire the two variables, atomically

`agent-templates` and `agent-doctrine` stop being recognized. **No fallback window** — verified 0
skills write either declaration, and the human confirmed no hand-added declaration exists on the one
deployed workshop, so a compatibility ladder would be dead code guarding an empty set. Their
concepts survive as fixed subpaths:

    <agent-templates>  ->  <agent-workspace>/templates
    <agent-doctrine>   ->  <agent-workspace>/doctrine

The agent-templates **resolution ladder** (incumbent skill-namespaced file → legacy flat adopt for
store-named lock-ins → bundled copy) is unchanged in shape; only its base path moves.

### M3 — `records.sh` relocates to `<agent-workspace>/scripts/`

Population attribution for the edit size: `grep -rn 'scripts/records\.sh' skills/` = **46 mentions
across 16 files**, of which **9** write the resolved-home form (`<agent-records>/scripts/records.sh`
or `<records-root>/scripts`); the other 37 are bare command invocations (`records.sh new`,
`records.sh check`) that never name the home. **Only those 9 change.**

`records.sh` already takes resolved paths as arguments and does not scan the front door
(`DOCTRINE.md` rule 1), so it needs no internal change — only its install location and the 9 prose
sites move. `history.tsv` **stays in `.records/`**: it is the closure ledger, records-layer *state*
rather than tooling, and a cross-home write is normal for a tool taking resolved arguments.

**On a coincident host the file does not move at all** — both homes resolve to `dev/`, so it stays
`dev/scripts/records.sh` exactly as today.

### M4 — `journal setup` resolves BOTH homes (a contract change, not a path edit)

`journal/verbs/setup.md:12,17-18` today resolves only `<agent-records>` and installs `records.sh`
into `<agent-records>/scripts/`. It must now resolve both and split its outputs:

| output | home |
|---|---|
| `records.sh` | `<agent-workspace>/scripts/` |
| `history.tsv` | `<agent-records>/` |
| the records README | `<agent-records>/` |

This is the one place the two-home split adds machinery rather than removing it. It also means
`/journal setup` creates `<agent-workspace>/scripts/` on first run — permitted under
Doctrine-touching rule 3 **because it is the derived default**, which is precisely the clause that
the parked feature's `/handbook setup` was found to violate.

### M5 — `.handbook/` becomes `<agent-workspace>/doctrine/`

The station chapters *are* the doctrine home's content, so this is a consequence, not a separate
decision. Layout:

    .dev/doctrine/
      README.md                        <- the install stamp lives here
      scripts/context.sh
      core/{POLICY,INVARIANTS,GOTCHAS,ROUTING}.md
      design|build|test|review/POLICY.md
      build/workflows/{feature,bug,patch,spike}.md
      test/workflows/diagnostics.md
      review/workflows/doc-audit.md
      test/workflows/audit/            <- auditor's rubric, in-structure

**`context.sh` needs no change.** `context.sh:15` resolves its root as `$(cd "$(dirname "$0")/.." &&
pwd)`; at `.dev/doctrine/scripts/context.sh` that resolves to `.dev/doctrine/`, so every load-set
path still resolves. The loader relocates transparently.

**The stamp relocates** from `.handbook/README.md` to `<agent-workspace>/doctrine/README.md`. Its
*string* is unchanged (`Seeded from clankshop vX.Y on DATE`), so rule 8's policy semantics are
untouched — but four sites carry the old literal path and must update: `DOCTRINE.md:337` (rule 8's
definition) plus the three surviving policy probes `debugger:39`, `workstream/SKILL.md:101`,
`workstream/verbs/create.md:119`.

**One honest complication this introduces.** Those three probes today grep a *fixed* path. After
this they must resolve `<agent-workspace>` before locating the stamp. That does **not** convert them
into location questions — they still answer *is a workshop assembled here* (policy), and rule 8's
test keys on what the probe *decides*, not on how it finds its evidence. But it is more machinery in
a probe the doctrine calls simple, and rule 8's wording should acknowledge it.

### M6 — flip the five consumers (+ the lint gate)

`auditor:20`, `blueprint:32`, `contractor:23`, `debugger:28`, `workstream:96` move from resolving
`agent-doctrine:` to resolving `agent-workspace:` and reading `<agent-workspace>/doctrine/…`. Their
station-shaped subpaths are unchanged (`/scripts/context.sh`, `/test/workflows/diagnostics.md`,
`/build/workflows/feature.md`, `/test/workflows/audit/`, `/core/ROUTING.md`, `/test/POLICY.md`).
`skills-lint.sh:632`'s sanctioned-literal grep updates to match.

**Problem 3 closes by construction:** the default workshop layout puts doctrine at the *default*
workspace path, so a default-layout host declares nothing and its consumers still find it. There is
no declaration to forget.

### M7 — clankshop

- `setup.md` — step 2 seeds to `<agent-workspace>/doctrine`; step 4's door writes
  `agent-workspace: <rel>` **only when not the default** (mirroring the existing `agent-records:`
  rule) and points at `<agent-workspace>/doctrine/README.md`; Guard (c)'s classification reads the
  new paths.
- `migrate.md` — step 3's seed row and step 4's door write, same changes.
- `check.md` — step 1's loader path, step 2's stamp path, step 4's door pointer.
- `persona.md` — the deployed path; the bundled-seed fallback is untouched by *this* feature.
- `migrate-scan.sh` — its `handbook=` inventory probe reads the new location.
- `seed.sh` — its copy target and refuse-on-existing check.

### M8 — doctrine, lint, and roster folds

- `DOCTRINE.md` front-door section: two variables replace three; the "one `agent-records:` line
  moves all three" rationale is deleted (it was the defect); `:236`'s "prospective" note goes with
  the retired variable; the deliberate echo break is documented **here**, once.
- Lint **check 14** (sanctioned `<agent-doctrine>` resolution literals) and **check 15**
  (`.handbook/<station>/` FAIL literals) encode retired paths and must be rewritten against
  `<agent-workspace>`. Check 15's exemption is name-based (`is_pack_face()`,
  `skills-lint.sh:118-123`) and already known-fragile — do not widen it here; only update literals.
- `README.md` / `AGENTS.md` / `PACK.md`: any prose naming `.handbook/` or the three-variable set.

## Verification

**Governing discipline: no check is trusted until it FAILs on deliberately-broken input.** A
verification grep is not evidence. Every guard-style assertion below names how it goes red.

| what | how it is proven |
|---|---|
| resolution: declared wins | fixture door with `agent-workspace: custom` → resolver returns `custom`; **red-proof:** delete the line → returns `.dev` |
| resolution: default | fixture with no declaration → `.dev`; **red-proof:** break the default branch → returns empty, caller degrades |
| retired variables are inert | fixture door declaring `agent-doctrine: .handbook` → resolver **ignores** it and returns `.dev`; this is the atomic-flip proof |
| `context.sh` relocates transparently | seed a fixture to `.dev/doctrine/`, run `context.sh --check` → `load sets: OK`; **red-proof:** delete `core/ROUTING.md` → exit 2 |
| `records.sh` relocates | `journal setup` on a fixture → `records.sh` at `.dev/scripts/`, `history.tsv` at `.records/`; **red-proof:** point `agent-workspace:` elsewhere and confirm the tool follows while the ledger does not |
| coincident homes still work | fixture declaring both at `dev/` → `records.sh` at `dev/scripts/`, stores at `dev/*`, `records.sh check` green; **red-proof:** add a `dev/doctrine/` tree and confirm `list` does **not** treat it as a store (the demoted carve-out still holds) |
| **Problem 3 actually closes** | seed a default-layout fixture, declare **nothing**, then have a consumer resolve its doctrine path → returns `.dev/doctrine`; **red-proof:** move the seed elsewhere without declaring → consumer degrades rather than finding a stale tree |
| stamp relocation | `check` on a fixture finds the stamp at `.dev/doctrine/README.md`; **red-proof:** delete the stamp line → reported |
| policy probes still fire | fixture workshop → `debugger` Phase 4 gate opens; **red-proof:** remove the stamp → gate closes (proves the probe still answers a *policy* question after the path move) |
| lint gate | `skills-lint.sh` `fails=0`; warns ≤ **22** (baseline; no new skill is added by this feature, so the check-4 wiring/inventory warns that would inflate it do not apply) |
| whole-suite | `skills/{clankshop,journal,analyst,skill-builder}/scripts/tests/run.sh` all green |

**Population attribution for the headline claim.** "5 readers, 0 writers" — the readers are
`auditor:20`, `blueprint:32`, `contractor:23`, `debugger:28`, `workstream:96`; `skills-lint.sh:632`
is **not** a reader (it greps skill prose for sanctioned literals). "0 writers" was verified by
exhaustive grep over `skills/`: every occurrence is a reader, a lint literal, a reserved-name
comment, or prose.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| **S1** | `DOCTRINE.md`: two variables, retire two, document the echo break | resolution rows 1–3 | `skills/skill-builder/docs/DOCTRINE.md` |
| **S2** | Lint checks 14/15 rewritten against `<agent-workspace>` + fixtures | lint row; each check red-proofed on broken input | `skills-lint.sh`, `scripts/tests/` |
| **S3** | `journal`: setup resolves both homes, splits its outputs | `records.sh` relocation + coincident-homes rows | `skills/journal/verbs/setup.md`, `SKILL.md`, `scripts/` |
| **S4** | `records.sh`: demote the carve-out to legacy-compat, update its comment | coincident-homes red-proof | `skills/journal/scripts/records.sh` |
| **S5** | Seed relocation: `seed.sh` target, `context.sh` verified unchanged, stamp path | `context.sh` + stamp rows | `skills/clankshop/{scripts/seed.sh,seed/}` |
| **S6** | clankshop verbs + `migrate-scan.sh` (M7) | clankshop suite green | `skills/clankshop/verbs/*`, `scripts/migrate-scan.sh` |
| **S7** | Flip the five consumers + rule 8's stamp literal (M6, M5-tail) | Problem-3 row + policy-probe row | the 5 `SKILL.md`s, `workstream/verbs/create.md`, `DOCTRINE.md:337` |
| **S8** | Roster/prose folds (M8 tail) | lint `fails=0`; whole-suite | `README.md`, `AGENTS.md`, `PACK.md` |

**Ordering:** S1 before all (it defines the literals everything else writes). S2 early so the gate
catches drift in S3–S8 rather than after. S7 late — it is the flip, and it wants the seed already
relocated. **S3+S4 are the only pair that must land together** (journal's setup and its tool's
carve-out are one behavior).

## Greenfield check

_Which mechanisms exist only because of substrate we could delete instead?_

- **The carve-out list itself.** Retained (demoted) purely to support coincident homes. Delete
  coincidence — forbid the two homes from being equal — and `records.sh` needs no reserved-name skip
  at all. **Pay it:** coincidence is what makes legacy `dev/` hosts a no-op migration, which is the
  entire reason this feature costs those hosts nothing. Worth re-weighing if legacy hosts ever
  disappear.
- **The stamp.** Its *location* moves here; its existence is out of scope (rule 8 adjudicated the
  policy consumers). But greenfield, a workshop assembled into a *declared* home would not need a
  stamp at all — the home's existence plus a loader is the same evidence. Named, not taken: the
  three policy probes are shipped surface and rule 8 forbids deleting them.
- **`agent-records`' legacy `records-root:` alias.** Still carried. Greenfield there is one name.
  Pay it — brownfield hosts declared it.

## Decision log

Settled by the human 2026-08-18 unless noted. **Do not re-litigate.**

1. **Two variables only** — `agent-records` + `agent-workspace`; the other two retire.
2. **Default `.dev/`, variable `agent-workspace`** — the mismatch is deliberate; reasoning above.
3. **The two homes may coincide**; legacy `dev/` hosts are a no-op.
4. **`records.sh` moves** to `<agent-workspace>/scripts/`; `history.tsv` stays in `<agent-records>/`.
5. **`.handbook/` becomes `<agent-workspace>/doctrine/`**, stamp at its `README.md`.
6. **Atomic flip, no fallback window** — nothing declares the retired variables.
7. **Workflows stay station-scoped** *(agent, resolved from evidence)*.
8. **No legacy alias for `agent-workspace`** *(agent, resolved from evidence)*.
9. **Naming is closed** — five candidates burned; see the table.

## Grounding

Verified at spec time, not assumed:

- `records.sh:64,82` carve-outs; `:70`'s comment naming the nesting as the cause.
- `DOCTRINE.md:217-223`, `:236`, `:228`, `:223-224`, `:337` (rule 8's stamp literal), rule 3's
  derived-default clause.
- `migrate.md:24-26` — `dev/` as the worked legacy **records** root.
- 5 consumer readers of `agent-doctrine:`; **0 writers** repo-wide (exhaustive grep).
- `agent-templates`: 24 files / 50 refs. `scripts/records.sh`: 46 mentions / 16 files, **9** in
  resolved-home form.
- `context.sh:15` — `HB="$(cd "$(dirname "$0")/.." && pwd)"`; relocation is transparent.
- `context.sh:16` — `STATIONS="design build test review"`; `test` is a station name.
- `journal/verbs/setup.md:12,17-18` — resolves only agent-records today; installs into
  `<agent-records>/scripts/`.
- Seed workflow dirs are station-scoped: `build/`, `test/`, `review/` only.
- `skills-lint.sh` baseline `fails=0 warns=22`; `:118-123` `is_pack_face()`; checks 14/15 literals.
- `.agents/` rejections: `2026-08-18-records-layer-init.md:173-174,1120`;
  `2026-07-17-library-refactor-plan.md` Task 6; `2026-07-17-library-refactor.md:310-312`.
- "artifact" appears 140+ times in `skills/`, dominantly meaning a managed record.
- No `agent-workspace` or live `.dev/` reference exists in the repo — both unclaimed.

## Review history

_(none yet — an independent `/blueprint review` is recommended before sequencing.)_
