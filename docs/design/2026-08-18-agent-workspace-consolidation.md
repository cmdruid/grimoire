---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# Two homes — `agent-records` + `agent-workspace` — Spec

`stream/feat` **feature 3**. Argued from the 2026-08-18 brainstorm, grounded against `main` @
`ce7e758` + branch `e8f25a2`. The `handbook` extraction is **closed as superseded**
(`2026-08-18-handbook-skill-extraction.md`) — this feature absorbed its Problem 3, and a future
`/clankshop curate` inherits its Problem 1.

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
      adr/ bugs/ design/ notes/      doctrine/            the station chapters + normative prose
      plans/ reports/ tickets/         scripts/context.sh   the doctrine loader, beside its own root
      trackers/                      templates/           schemas instances mint from
      scripts/records.sh
      history.tsv

**`records.sh` stays in the records home; `context.sh` lives inside `doctrine/`.** Both placements
are load-bearing, not incidental — each tool derives its root from its own location (M3, M5).

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
because `DOCTRINE.md:230-232` already requires skills to write default paths **literally** rather
than as variables, so the mapping is stated wherever used and learned once.

### Why not the alternatives

- **One root** (`.dev/records/`, `.dev/doctrine/`, …) — the fewest variables, and the tempting answer
  to "too many dynamic paths." Rejected because it breaks the *only* variance ever demonstrated: a
  brownfield host declaring `records-root: dev` cannot relocate records independently if records
  live inside the other home.
- **De-nest the three existing homes** (keep `agent-templates`/`agent-doctrine`, move their defaults
  to top level) — kills the carve-outs without inventing a name. Rejected because it keeps three
  variables to express two concepts and leaves two of them still without a variance case.
- **The one-line Problem-3 fix: change `agent-doctrine`'s default to `.handbook`** (or have
  `setup.md:52` write the declaration alongside `agent-records:`). This is the **cheapest thing that
  fixes the only live regression** — zero new variables, zero retirements, zero file moves — and a
  reviewer verified it works: the seed layout under `skills/clankshop/seed/` matches the five
  consumers' expected subpaths exactly, so nothing else has to move. **It is the strongest
  alternative and this spec must not omit it.** Rejected because it fixes Problem 3 *only*: the
  three-variable set, the two variables with no variance case, and the carve-out list all survive
  untouched, and the next feature to touch a path home re-opens this same design. Taken as a
  **fallback**: if this feature must be abandoned mid-flight, that one line is the thing to ship.
- **Leave it alone.** Rejected because Problem 3 is a live regression — station context is silently
  lost on every seeded project today.

### Naming — five candidates burned (hard-won; do not re-propose)

| candidate | killed by |
|---|---|
| `.agents/` | **Adjudicated twice and reverted.** `2026-08-18-records-layer-init.md:173-174` + `:1120`: *"This library already lives at `~/.agents/`. A project path that starts `.agents/` sends agents to the home directory."* And `2026-07-17-library-refactor-plan.md` Task 6 was literally *"Relocate on-disk homes under `.agents/`"* — the library migrated off it. |
| `.artifacts/` | **Inverts this library's vocabulary.** 147 uses of "artifact" in `skills/`, dominant sense = a managed record (`contractor:123` *"job artifacts in `<agent-records>/plans/`"*; `migrate.md:30`'s header `\| legacy artifact \| store \|`). Would mean artifacts live in `.records/` and non-artifacts in `.artifacts/`. Externally a build-output convention connoting *disposable* — invites gitignoring hand-curated doctrine. |
| `test/` | Conventional **source** directory for test suites across most ecosystems. Also already claimed: `test` is one of four station names (`context.sh:16`). |
| `dev/` **undotted** | Undotted breaks the dotted = tooling-not-source signal every current home follows. Dotted `.dev/` is a different string and is **not** rejected. |
| *(fifth mention, non-binding)* | `2026-07-17-library-refactor.md:310-312` chose `.agents/` over `.artifacts/` and bare `.design`/`.dev`. Non-binding: (a) it rejected **two** domain-split roots — "root clutter" — where this is **one** directory *replacing* `.handbook/`, so root count is unchanged; (b) "unclear ownership" was true because no front-door variable existed (its §12 ruled one out); (c) the winner is **dead**. Its `.artifacts/` reasoning independently matches the row above. |

The first four candidates were all **negative** definitions ("everything that isn't a record"), and
negative definitions name badly. *Workspace* names what the home **is** — which is why it survives
as the **variable** even though the directory is `.dev/`.

**Two concerns raised against `.dev/` in review, recorded as accepted (human, settled twice — not
re-opened).** They are written down so a future reader sees they were weighed, not missed:
(a) the `.dev*` root namespace skews toward *local, ephemeral, gitignored* state (`.dev.vars*`,
`.devenv/`, `.devbox/`), which is a version of the disposability argument that killed `.artifacts/`
— though `.devcontainer/` is committed, so the family is not uniform; and (b) on a coincident legacy
host, `dev/` (records) and `.dev/` (workspace) sit **one character apart** holding opposite
concepts. Both are legibility risks, not correctness risks, and neither blocks the mechanism.

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

### M3 — `records.sh` STAYS at `<agent-records>/scripts/` (reversed 2026-08-18)

**An earlier draft moved it to the workspace. That is not implementable, and the reason is a
property of the tool itself.** `records.sh:26`:

    RR="$(cd "$(dirname "$0")/.." && pwd)"

The tool derives the records root **from its own install location** — its header at `:5` says so
outright (*"resolved from its own location — never from cwd"*). Install it at
`<agent-workspace>/scripts/` and `RR` becomes `.dev`: `stores()` enumerates `.dev/*`, `new` writes
into `.dev/<store>/`, and `done` appends to `.dev/history.tsv`. The whole records layer repoints.

So the tool lives beside the layer it serves — **the same argument that keeps `history.tsv` in
`.records/`, applied consistently.** Nothing about `records.sh`'s install location changes, and the
following stay correct untouched: `record-mint.sh:74` and `note-mint.sh:75`'s
`has_records() { [ -x "$1/scripts/records.sh" ]; }` (where `$1` is the records home),
`standup.sh:39`'s idempotency probe, `standup.sh:45-46`'s install target, and all 46
`scripts/records.sh` mentions across 16 files.

**Cost, stated:** `scripts/` remains a reserved name under the records home, so the carve-out keeps
**two** entries (`scripts/`, `history.tsv`) rather than one. `templates/` and `doctrine/` leave it.

**What DOES move is `templates/`** — and three sites derive template paths from the records root.
They are the real M3 edit surface, and an earlier draft missed them by classifying 37 grep hits as
"bare command invocations" without opening them:

| site | today | after |
|---|---|---|
| `records.sh:180` | `[ -n "$tpl" ] \|\| tpl="$RR/templates/$doctype.md"` | **delete the fallback** — both real callers (`record-mint.sh:115`, `note-mint.sh:109`) always pass `--template`; error when absent |
| `analyst-deploy.sh:33` | `DEST="$RR/templates/analyst"` | resolve `<agent-workspace>/templates/analyst` |
| `analyst-facts.sh:76-81,303` | a **second, drifted** carve-out (`^$RR/templates/`, `^$RR/scripts/` — omits `doctrine/`) + `$RR/templates/analyst` | rewrite against the two homes |

`analyst` scans the front door itself (`analyst-deploy.sh:15-24`, `analyst-facts.sh:32`), so it must
learn the workspace resolver — it is not a prose edit.

### M4 — `journal setup` gains the workspace only for templates

`journal/verbs/setup.md:12,17-18` resolves only `<agent-records>` today. Under M3 its **tool-layer
outputs are unchanged** — `records.sh` to `<agent-records>/scripts/`, `history.tsv` and the records
README to `<agent-records>/`. What changes is prose and one branch:

- **`standup.sh:56-64` writes a records README whose text this feature falsifies** — it states that
  "`templates/`, `scripts/`, `doctrine/`, and `history.tsv` are reserved" and that "sibling homes
  (project templates, project doctrine) default underneath it." After this feature only `scripts/`
  and `history.tsv` are reserved, and the siblings do not default underneath. Rewrite it.
- **Declared-but-absent workspace.** Doctrine-touching rule 3 permits creating a home *only when it
  is the derived default* and forbids creating an **explicitly declared** home that is absent. So a
  host declaring `agent-workspace: somewhere` with no such directory must **degrade per rule 2 and
  report** — never `mkdir` it, never silently fall back to the records home. State the branch.

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

**`context.sh`'s LOGIC needs no change — its header comment does.** `context.sh:15` resolves its
root as `$(cd "$(dirname "$0")/.." && pwd)`; at `.dev/doctrine/scripts/context.sh` that resolves to
`.dev/doctrine/`, so every load-set path still resolves and the loader relocates transparently.
**This is why `context.sh` must stay nested inside `doctrine/` rather than sitting in the
workspace-level `scripts/`** — at `.dev/scripts/context.sh` its root would resolve to `.dev/` and
every load set would miss. The two `scripts/` directories are deliberately distinct. `context.sh:5`
carries a stale `.handbook/` literal in its header (*"paths relative to .handbook/"*) and must be
updated — "verified unchanged" means its logic, not its bytes.

**Existing deployments migrate physically; no declaration expresses it.** The old tree is
`.handbook/{README.md, scripts/context.sh, core/, <station>/}`; the new is
`<workspace>/doctrine/{…}`. There is **no value of `agent-workspace`** that maps one onto the other
— declaring `agent-workspace: .handbook` yields `.handbook/doctrine/`. So the Approach's "any other
layout is a declaration, not a redesign" **does not hold for a pre-flip workshop**: that host needs
`git mv .handbook <workspace>/doctrine`. Exactly one such deployment is known (the author's).
Decision 3's "no `git mv` is forced" is scoped to **records**, not doctrine — say so.

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
- `migrate-scan.sh` — emits **both** a new `workspace=` probe (default `.dev/doctrine`, plus any
  declared value) **and retains the legacy `handbook=` probe**. It runs *before* any door
  declaration exists, so it can only test defaults — and detecting a pre-flip `.handbook/` is
  precisely the signal a brownfield preflight needs. Replacing the probe would blind it.
- `seed.sh` — its copy target and refuse-on-existing check.

**Legacy `dev/` hosts must ADD a declaration to stand still.** `agent-workspace` defaults to `.dev`,
so a coincident host that changes nothing gets `WS=.dev` while its doctrine and templates sit at
`dev/doctrine`, `dev/templates` — which then degrade silently. Such a host writes
`agent-workspace: dev`. This is a **required migration step**, not a no-op; it needs a `migrate.md`
adopt row and a verification row of its own.

### M8 — doctrine, lint, and roster folds

**`DOCTRINE.md` — the edit is larger than the front-door section.** Enumerated, because S1 defines
the literals every later slice writes:

- The **front-door section**: two variables replace three; the "one `agent-records:` line moves all
  three" rationale is deleted (it *was* the defect); `:236`'s prospective note goes with the retired
  variable; the deliberate echo break is documented here, once.
- **`:226-228` must stop publishing `agent-doctrine: .handbook` as the sanctioned override.**
  Required, not cosmetic: the retirement is atomic (Decision 6), so leaving the doctrine that tells
  hosts to write that declaration would keep minting exactly the hosts the flip breaks.
- **Doctrine-touching rule 1**'s three-destination classification table (Templates→`<agent-templates>`,
  Doctrine→`<agent-doctrine>`) — the conceptual core of the section.
- **Rule 3**'s derived-default language (the clause M4 depends on).
- **Rule 5**'s sanctioned literal set, keyed *"For home `H` (one of `agent-records`,
  `agent-templates`, `agent-doctrine`)"* — **this enumeration is what lint check 14 greps**, so S2
  cannot be specified without it.
- **Rule 6**'s `produces: doctrine` / `consumes: doctrine` edge vocabulary. **Decision: the edge type
  stays `doctrine`** — it names the *kind of thing* carried, not the home it resolves through, and
  changing it would churn every edge block for no gain. State it so check 14's gate expression is
  unambiguous.
- **Rule 8**'s `<agent-doctrine>` sentence and its *"Do not create `.handbook/` as a side effect"*
  clause, plus `:337`'s stamp literal.
- **Record-writing rule 6**'s opportunistic `<agent-records>/scripts/records.sh` clause — unchanged
  under M3's reversal, but verify rather than assume.

**Lint check 15 keeps its `.handbook/<station>/` literals — do NOT rewrite them to `.dev/`.** An
earlier draft said the opposite and it contradicts check 15's own documented rationale
(`skills-lint.sh:660-666`): a check on the *canonical default* path is undecidable, because skill
prose is *required* to name defaults literally, so a hardcoded default is textually identical to a
documented one. Only **off-home** literals are decidable. `.handbook/` remains off-home after this
feature (and is now also stale), so the existing literals stay correct and gain a second reason to
exist. Check 14's sanctioned set **does** change, tracking rule 5.

- `README.md` / `AGENTS.md` / `PACK.md`: any prose naming `.handbook/` or the three-variable set.

## Verification

**Governing discipline: no check is trusted until it FAILs on deliberately-broken input.** A
verification grep is not evidence. Every guard-style assertion below names how it goes red.

**Nothing in this library mechanically resolves a front-door variable outside the state-analysis
helpers** (`analyst-facts.sh`, `analyst-deploy.sh`, `workstream-git.sh`); every other consumer is
agent-read prose. So a row is either a **script** proof or a **lint/prose-conformance** proof, and
this table says which. An earlier draft asserted "resolver returns X" rows against a resolver that
does not exist — one of them (*retired variables are inert*) was **vacuous**: nothing reads
`agent-doctrine` in code, so the fixture passed identically with the feature implemented or not.
That is the same defect class this section exists to catch, so it is called out rather than quietly
replaced.

| what | how it is proven | kind |
|---|---|---|
| resolution: declared wins | `analyst-facts.sh` on a fixture door with `agent-workspace: custom` → emits `agent-workspace=custom`; **red-proof:** stub out the declaration-scan arm → falls to `.dev`, assertion fails | script |
| resolution: default | fixture with no declaration → emits `.dev`; **red-proof:** delete the default constant → emits empty | script |
| **retired variables are inert** | lint: no file under `skills/` outside `skill-builder`'s doctrine contains `agent-doctrine:` / `agent-templates:` as a resolution literal; **red-proof:** reintroduce the literal into a fixture skill → lint **FAILs** | lint |
| `context.sh` relocates transparently | seed a fixture to `.dev/doctrine/`, run `context.sh --check` → `load sets: OK`; **red-proof:** delete `core/ROUTING.md` → exit 2 | script |
| `records.sh` stays correct | `journal setup` on a **non-coincident** fixture → `records.sh` at `.records/scripts/`; then `record-mint.sh` mints through it and `done` writes a **ledger line** in `.records/history.tsv`; **red-proof:** move the tool to `.dev/scripts/` → `has_records()` false, mint falls to file-mode, **no ledger line** | script |
| templates relocate | `records.sh new` with no `--template` → errors (fallback deleted); `analyst deploy` writes `.dev/templates/analyst/`; **red-proof:** restore the `$RR/templates` default → a template resolves from the records home | script |
| coincident homes still work | fixture declaring both at `dev/`, containing `dev/doctrine/<station>/workflows/x.md` **with prose and no front-matter**; assert all four arms: `check` green, `list` omits it, `show` exits 2 with `reserved path, not a record`, `touch` likewise. **Red-proof each arm independently** — patching `stores()` while leaving `resolve()` broken passes a `check`-only proof (this is the incumbent `records-test.sh:183-215` standard; do not ship weaker) | script |
| **legacy host must declare** | coincident fixture that declares **only** `agent-records: dev` → doctrine/templates resolve to `.dev/…` and degrade; adding `agent-workspace: dev` restores them. Proves the migration step is required, not optional | script |
| **Problem 3 closes on a default host** | seed a default-layout fixture, declare **nothing** → the path `seed.sh` wrote equals the literal each of the five consumers' `SKILL.md` names; **red-proof:** move the seed without declaring → the two diverge | lint/prose |
| stamp relocation | `check` on a fixture finds the stamp at `.dev/doctrine/README.md`; **red-proof:** delete the stamp line → reported | script |
| policy probes still fire | *human/agent-run:* fixture workshop → `debugger` Phase 4 gate opens; **red-proof:** remove the stamp → gate closes. Labelled as judgment, not mechanized | agent |
| lint gate keeps teeth | `skills-lint.sh` `fails=0`, warns ≤ **22** (no new skill, so check-4's wiring/inventory warns do not apply) — **plus** check 14 red-proofed against a fixture carrying the retired literal | lint |
| whole-suite | **all eight** `skills/*/scripts/tests/run.sh` — `clankshop`, `journal`, `analyst`, `skill-builder`, **`backlog`**, **`notepad`**, `checkpoint`, `agent-council`. The first draft named four and omitted `backlog` and `notepad` — precisely the suites whose fixtures encode the tool's install location | script |

**Population attribution for the headline claim.** "5 readers, 0 writers" — the readers are
`auditor:20`, `blueprint:32`, `contractor:23`, `debugger:28`, `workstream:96`; `skills-lint.sh:632`
is **not** a reader (it greps skill prose for sanctioned literals). "0 writers" was verified by
exhaustive grep over `skills/`: every occurrence is a reader, a lint literal, a reserved-name
comment, or prose.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| **S1** | `DOCTRINE.md`: two variables, retire two, rules 1/3/5/6/8, remove `:226-228`, document the echo break | resolution rows 1–2 | `skills/skill-builder/docs/DOCTRINE.md` |
| **S2** | Lint **check 14**'s sanctioned set tracks rule 5 (**check 15's literals are retained** — M8); accept both literal families **transitionally** | *retired variables are inert* row; check 14 red-proof | `skills-lint.sh`, `skill-builder/scripts/tests/lint-doctrine-consumer-test.sh` |
| **S3** | `journal`: workspace-for-templates, `standup.sh`'s README text, the declared-but-absent branch | `records.sh stays correct` row | `skills/journal/verbs/setup.md`, `SKILL.md`, `scripts/standup.sh`, `scripts/tests/standup-test.sh` |
| **S4** | `records.sh`: demote the carve-out to two entries, **delete `:180`'s template fallback**, update the header comment | coincident-homes row (all four arms) | `skills/journal/scripts/records.sh`, `scripts/tests/records-test.sh` |
| **S5** | Seed relocation: `seed.sh` target, `context.sh:5` header literal, stamp path, **`.handbook` → `<workspace>/doctrine` migration note** | `context.sh` + stamp rows | `skills/clankshop/{scripts/seed.sh,seed/}`, `scripts/tests/{seed,face,lint-exemption}-test.sh` |
| **S6** | clankshop verbs + `migrate-scan.sh` **dual probe** + the legacy-host adopt row in `migrate.md` | clankshop suite; *legacy host must declare* row | `skills/clankshop/verbs/*`, `SKILL.md` (incl. `description:`), `scripts/migrate-scan.sh`, `scripts/tests/{setup-journal,migrate-scan}-test.sh` |
| **S7** | Flip the five consumers + **every other `<agent-doctrine>` carrier** + rule 8's stamp literal | Problem-3 row; policy-probe row | the 5 `SKILL.md`s, `workstream/{verbs/create.md,verbs/sync.md,flow.md,templates/*}`, `auditor/BOOTSTRAP.md`, `journal/SKILL.md:29`, `agent-council/briefs/skill-review.md`, `DOCTRINE.md:337` |
| **S8** | `analyst`: front-door resolver, `DEST`, the drifted second carve-out | templates-relocate row | `skills/analyst/scripts/{analyst-deploy.sh,analyst-facts.sh}`, `SKILL.md:27`, `scripts/tests/*` |
| **S9** | Roster/prose folds; the remaining `.handbook` literals (61 refs / 23 files) | lint `fails=0`; **all eight** suites | `README.md`, `AGENTS.md`, `PACK.md`, `clankshop/seed/README.md`, `seed/review/workflows/doc-audit.md` |

**Ordering.** S1 before all — it defines the literals every later slice writes.

**S2 and S7 must land together.** Check 14 is edge-gated and currently passes for `blueprint` and
`contractor` on their `<agent-doctrine>` edge-line literals. If S2 narrows the sanctioned set early,
the gate FAILs on both skills for the whole S3–S6 window — contradicting the `fails=0` bar. So S2
lands **accepting both literal families**, and S9 narrows it to `<agent-workspace>` only, with a
red-proof that the narrowed set FAILs a fixture still carrying the retired literal. (An earlier
draft claimed S3+S4 was the only must-land-together pair; that was wrong.)

**S3+S4 still pair** — journal's template resolution and its tool's carve-out are one behavior.
S8 (`analyst`) may land any time after S1. S5 before S6; S7 after S5.

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
4. **`records.sh` STAYS at `<agent-records>/scripts/`** *(reversed 2026-08-18 after review)*; so does
   `history.tsv`. An earlier draft moved the tool; `records.sh:26` derives its root from its own
   install location, so moving it repoints the entire records layer. Only `templates/` leaves the
   records home.
5. **`.handbook/` becomes `<agent-workspace>/doctrine/`**, stamp at its `README.md`. `context.sh`
   stays nested inside `doctrine/` — its root resolution depends on it.
6. **Atomic flip, no fallback window.** *Risk surfaced in review and consciously accepted:*
   `DOCTRINE.md:226-228` currently publishes `agent-doctrine: .handbook` as the sanctioned override,
   so any host that hit Problem 3 and followed the shipped doctrine would be silently broken by the
   flip. Accepted because the author controls the entire install population (one workshop). **The
   mitigation is required, not optional:** S1 removes `:226-228` in the same change, so the docs stop
   minting hosts the flip would break. Do not re-open the window question without new population
   evidence; do not skip the `:226-228` removal.
7. **Workflows stay station-scoped** *(agent, resolved from evidence)*.
8. **No legacy alias for `agent-workspace`** *(agent, resolved from evidence)*.
9. **Naming is closed** — five candidates burned; see the table.

## Grounding

Verified at spec time, not assumed:

- `records.sh:64,82` carve-outs; `:70`'s comment naming the nesting as the cause.
- `DOCTRINE.md:217-223`, `:236`, `:228`, `:230-232` (write defaults literally), `:337` (rule 8's
  stamp literal), rule 3's derived-default clause at `:395-400`.
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
- "artifact" appears 147 times in `skills/`; the dominant sense is a managed record (`blueprint` /
  `contractor`, ~63 refs) — but `mailbox` (13) and `delegate` (11) use the **opposite** sense
  explicitly ("*not a typed artifact*"), ~16% of uses. The `.artifacts/` inversion conclusion holds;
  "dominantly" is qualified rather than absolute.
- No `agent-workspace` or live `.dev/` reference exists in the repo — both unclaimed.

## Review history

### 2026-08-18 — needs-rework (×3: soundness, groundedness, skeptic)

Three lenses, unanimous. The design (M1–M8's shape) survived; the **census and the verification
table** did not. Dispositions below; findings not listed were duplicates across lenses.

| id | finding | disposition |
|---|---|---|
| F1 | `records.sh:26` derives `RR` from its install location, so M3's move repoints the whole records layer; the *coincident* case is the only one that survives, which is why no fixture would have caught it | **resolved** — Decision 4 reversed; the tool stays at `<agent-records>/scripts/` |
| F2 | `has_records()` in `record-mint.sh:74` / `note-mint.sh:75` returns false after the move → **silent** file-mode minting → no ledger line → `records.sh check` FAILs on every closed record | **resolved** — dissolves with F1's reversal; a lifecycle assertion + red-proof added to Verification |
| F3 | `standup.sh:39` idempotency probe → double install | **resolved** — dissolves with F1; its README text (`:56-64`) still falsified, folded into M4 + S3 |
| F4 | `records.sh:180` hardcodes `$RR/templates/$doctype.md`, the retired agent-templates default | **resolved** — M3 deletes the fallback (both real callers always pass `--template`); S4 owns it |
| F5 | `analyst` absent from the spec: scans the front door itself, `DEST="$RR/templates/analyst"`, plus a **second drifted carve-out** omitting `doctrine/` | **resolved** — new slice **S8** |
| F6 | Approach diagram put `context.sh` at `.dev/scripts/` while M5 requires `.dev/doctrine/scripts/` — the diagram's version breaks the loader | **resolved** — diagram corrected; the nesting is now stated as load-bearing |
| F7 | Verification rows 1–3/7/9 asserted a resolver that does not exist; row 3 (*retired variables are inert*) was **vacuous — could not go red** | **resolved** — table rewritten with a `kind` column; row 3 replaced by a decidable lint assertion; agent-judgment rows labelled |
| F8 | Coincident red-proof weaker than the incumbent `records-test.sh:183-215`, which proves `stores()` and `resolve()` separately | **resolved** — all four arms + independent red-proofs; fixture specified concretely |
| F9 | No migration path for the existing `.handbook/`; **no value of `agent-workspace` expresses it** | **resolved** — M5 states the physical rename; Decision 3 scoped to records |
| F10 | "Legacy `dev/` is a no-op" false — the host must **add** `agent-workspace: dev` to stand still | **resolved** — M7 states it as a required step; new Verification row |
| F11 | M8 told S2 to rewrite check 15's literals to `.dev/`, contradicting check 15's own rationale (`skills-lint.sh:660-666`): default paths are undecidable, only off-home literals work | **resolved** — check 15's `.handbook/` literals **retained**; only check 14 tracks rule 5 |
| F12 | S2 before S7 turns the gate red for `blueprint`/`contractor` across S3–S6; S2+S7 are a pair | **resolved** — S2 lands accepting both literal families, S9 narrows with a red-proof |
| F13 | `DOCTRINE.md` edit underspecified — rules 1/3/5/6/8 and the edge-type question | **resolved** — enumerated in M8; **edge type stays `doctrine`**, stated |
| F14 | `.handbook` = 61 refs / 23 files and `<agent-doctrine>` carriers (`flow.md:56`, `auditor/BOOTSTRAP.md`, `sync.md:100`, `journal/SKILL.md:29`, the council brief, workstream templates) unnamed | **resolved** — S7/S9 path columns expanded; test dirs added to every slice |
| F15 | The one-line Problem-3 fix (default `agent-doctrine` to `.handbook`) never argued down | **resolved** — added to *Why not the alternatives* and taken as the abandonment fallback |
| F16 | `.dev/` never subjected to the disposability test that killed `.artifacts/`; `dev/` vs `.dev/` one character apart on coincident hosts | **rejected** — human-settled twice; **recorded as accepted risk** in the Naming section rather than re-opened (legibility, not correctness) |
| F17 | Atomic retirement refuted: `DOCTRINE.md:226-228` publishes `agent-doctrine: .handbook` as sanctioned, so doctrine-following hosts break silently | **rejected** — human holds atomic (controls the install population); risk recorded in Decision 6, and removing `:226-228` promoted to a **required** S1 edit |
| F18 | Citation `:223-224` → `:230-232`; "artifact… dominantly" overstated (`mailbox`/`delegate` use the opposite sense, ~16%) | **resolved** — both corrected |
| F19 | Whether `agent-workspace` needs to be a variable at all (a fixed `.dev/` would do) | **rejected** — Decision 1, human-settled; not re-litigated |

**What the reviews confirmed as sound**, and should not be re-verified on the next pass: every
prior-adjudication citation, the naming archaeology, the 5-readers/0-writers census, all three
edit-size counts (24/50, 46/16, 9), `context.sh`'s transparent relocation traced through its logic,
the lint baseline, and the three Greenfield verdicts. Groundedness found **no fabricated citation**.

_Amended 2026-08-18. This fold is unverified content authored by the spec's own author — a delta
re-review (Review history + what changed) is the next step before sequencing._
