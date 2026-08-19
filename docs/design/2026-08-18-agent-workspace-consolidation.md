---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `agent-workspace`, part 1 — the doctrine home — Spec

`stream/feat` **feature 3a**. Grounded against `main` @ `ce7e758` + branch `de9a250`.

> **Scope was split on 2026-08-18** after two review rounds (five lenses, both rounds
> `needs-rework`). The design survived every pass; what repeatedly failed was **edit-surface
> enumeration** — three consecutive incomplete censuses, all of them in the `agent-templates` half.
> The reviews drew the line themselves: *"S7's `<agent-doctrine>` census **is** complete — I
> enumerated every carrier and all 15 files are covered."* So this feature retires
> **`agent-doctrine` only**, on the verified census. `agent-templates` becomes **feature 3b**
> (`2026-08-18-agent-templates-home.md`), which inherits the hard interactions.
>
> **Read the Decision log before re-deriving anything.** Do not re-open the naming table.

## Problem

**Five consumer skills read `agent-doctrine:` and zero skills write it.** Verified exhaustively:
`auditor:20`, `blueprint:32`, `contractor:23`, `debugger:28`, `workstream:96` resolve the variable;
no skill, script, or verb ever writes the declaration into a host's door.

The consequence is live on **every seeded project today**. A workshop's doctrine sits at
`.handbook/`, the door never declares it, so consumers resolve the default `<agent-records>/doctrine`
(`.records/doctrine/`), find nothing, and degrade. Concretely lost: the design-station summon
(`blueprint:38`), the build-station summon (`contractor:29`), `workstream`'s feature lane
(`flow.md:56`), and `debugger`'s diagnostics playbook (`SKILL.md:31`).

**It is worse than silent degradation.** Per Doctrine-touching rule 3, a skill may create the home
when it is the derived default — so `/auditor setup` on a deployed workshop will build a **second
doctrine tree** at `.records/doctrine/test/workflows/audit/`, beside the real one, and wire routing
into files the workshop's own `check` never reads.

Underneath sits the structural cause: `agent-doctrine` defaults *inside* the records home
(`DOCTRINE.md:217-223`), and `DOCTRINE.md:236` concedes its variance case is "partly
**prospective**" — a variable with no demonstrated host, positioned where it forces the records
layer to disown a subdirectory.

## Goal

Introduce **`agent-workspace`** (default `.dev/`) and retire **`agent-doctrine`** into it as a fixed
subpath. Done means a default-layout workshop is found by its own consumers **without declaring
anything**, and the second-doctrine-tree pathology cannot occur.

## Approach

One new front-door variable; one retired:

    agent-records:   .records   (unchanged; `records-root:` still accepted)
    agent-workspace: .dev       (new)
    agent-doctrine:              RETIRED -> <agent-workspace>/doctrine

    .records/                      .dev/
      adr/ bugs/ design/ notes/      doctrine/            the station chapters + normative prose
      plans/ reports/ tickets/         scripts/context.sh   the loader, beside its own root
      trackers/                        core/ design/ build/ test/ review/
      scripts/records.sh
      templates/                   (templates stay put until feature 3b)
      history.tsv

**`records.sh` is untouched by this feature**, and so is its reserved-name list. An earlier draft
moved the tool; `records.sh:26` derives its root from its own install location
(`RR="$(cd "$(dirname "$0")/.." && pwd)"`, and its `:5` header says so), so moving it repoints the
entire records layer. It stays beside the layer it serves. The reserved list keeps **all four**
names (`templates`, `scripts`, `doctrine`, `history.tsv`): `templates/` because feature 3b has not
moved it yet, and `doctrine/` because a **coincident** host still has `dev/doctrine/` inside its
records home. Demoting that list belongs to 3b, not here.

**Workflows are station-scoped, not a peer** — `.dev/doctrine/<station>/workflows/…`, shape
unchanged. Verified: the seed has `build/`, `test/`, `review/` workflow dirs and every consumer path
is `<station>/workflows/…`. No top-level workflows directory exists anywhere.

**The two homes MAY coincide.** A legacy host may declare both at `dev/`; the reserved list keeps
that working. **But coincidence is not automatic and this is not a no-op:** `agent-workspace`
defaults to `.dev`, so a legacy `dev/` host that changes nothing gets `WS=.dev` while its doctrine
sits at `dev/doctrine` — and degrades silently. **Such a host must add `agent-workspace: dev` to
stand still.** That is a required migration step with its own verification row (M7).

**The pair deliberately breaks the echo pattern — do not "fix" it.** `agent-records`→`.records`
echoes; this one does not, on purpose (settled 2026-08-18, human): the **variable** names the
concept precisely for prose explaining what the home is for, while the **directory** stays short and
legible for a literal appearing at depth —
`.dev/doctrine/test/workflows/audit/GUIDE.md` versus
`.workspace/doctrine/test/workflows/audit/GUIDE.md`, where the second also stutters against
`workflows/`. The consistency cost is small because `DOCTRINE.md:230-232` already requires skills to
write default paths **literally**, so the mapping is stated wherever used and learned once.

### Why not the alternatives

- **The one-line fix: change `agent-doctrine`'s default to `.handbook`** (or have `setup.md:52`
  write the declaration alongside `agent-records:`). The **cheapest thing that closes Problem 3** —
  zero new variables, zero retirements, zero moves — and a reviewer verified the seed layout matches
  the five consumers' expected subpaths exactly, so nothing else would have to move. Rejected
  because it leaves a variable with no variance case defaulting inside the records home, so the next
  feature to touch a path home re-opens this design. **Taken as the abandonment fallback:** if this
  feature must be dropped mid-flight, that one line is the thing to ship.
- **Retire `agent-templates` in the same feature** (the pre-split scope). Rejected on evidence: its
  census failed three consecutive review rounds, because the retired variable is a **positional CLI
  argument** to `record-mint.sh` / `note-mint.sh`, is load-bearing in the legacy-flat adopt ladder
  (`DOCTRINE.md:356-367`), and interacts with `records.sh:180`'s template fallback. Feature 3b.
- **One root** (`.dev/records/`, `.dev/doctrine/`) — fewest variables, but breaks the only variance
  ever demonstrated: a brownfield host declaring `records-root: dev` cannot relocate records
  independently if records live inside the other home.
- **Leave it alone.** Rejected because Problem 3 is a live regression — station context is silently
  lost on every seeded project today.

### Naming — five candidates burned (hard-won; do not re-propose)

| candidate | killed by |
|---|---|
| `.agents/` | **Adjudicated twice and reverted.** `2026-08-18-records-layer-init.md:173-174` + `:1120`: *"This library already lives at `~/.agents/`. A project path that starts `.agents/` sends agents to the home directory."* And `2026-07-17-library-refactor-plan.md` Task 6 was *"Relocate on-disk homes under `.agents/`"* — the library migrated off it. |
| `.artifacts/` | **Inverts this library's vocabulary.** 147 uses of "artifact" in `skills/`, dominant sense = a managed record (`contractor:123` *"job artifacts in `<agent-records>/plans/`"*). Externally a build-output convention connoting *disposable* — invites gitignoring hand-curated doctrine. |
| `test/` | Conventional **source** directory for test suites across most ecosystems; also already a station name (`context.sh:16`). |
| `dev/` **undotted** | Breaks the dotted = tooling-not-source signal every current home follows. Dotted `.dev/` is a different string and is **not** rejected. |
| *(fifth, non-binding)* | `2026-07-17-library-refactor.md:310-312` chose `.agents/` over `.artifacts/` and bare `.design`/`.dev`. Non-binding: it rejected **two** domain-split roots ("root clutter") where this is **one** replacing `.handbook/`; "unclear ownership" was true because no front-door variable existed (its §12 ruled one out); and the winner is **dead**. |

**Two concerns raised in review, recorded as accepted (human, settled twice — not re-opened):**
(a) the `.dev*` root namespace skews toward *local, ephemeral, gitignored* state (`.dev.vars*`,
`.devenv/`, `.devbox/`) — a version of the disposability argument that killed `.artifacts/`, though
`.devcontainer/` is committed so the family is not uniform; (b) on a coincident legacy host, `dev/`
(records) and `.dev/` (workspace) sit **one character apart** holding opposite concepts. Both are
legibility risks, not correctness risks.

## Mechanism

### M1 — the resolution rule

    <agent-workspace> = first line-start `agent-workspace:` in AGENTS.md, then CLAUDE.md;
                        else `.dev`
    <doctrine home>   = <agent-workspace>/doctrine        (no longer a variable)

Same precedence and mechanism as `agent-records`. **No legacy alias** — `records-root:` exists only
because hosts declared it before a rename; `agent-workspace` is new with zero declarations to honor.
`agent-workspace: .` is **forbidden** (it would place doctrine at `./doctrine`, colliding with real
project directories) — reject it and report.

Skill prose keeps naming the default literally (`.dev/doctrine/…`). **Two-level access is unchanged
doctrine:** resolve the home, *then* test for the artifact; a missing artifact degrades exactly as
the skill degrades with no workspace at all.

### M2 — retire `agent-doctrine`, atomically

The variable stops being recognized. **No fallback window.**

*Risk surfaced in review and consciously accepted (human, 2026-08-18):* `DOCTRINE.md:226-228`
currently **publishes** `agent-doctrine: .handbook` as the sanctioned override, so a host that hit
Problem 3 and followed the shipped doctrine is exactly the host the flip breaks — silently. Accepted
because the author controls the entire install population (one workshop). **The mitigation is
required, not optional:** S1 removes that declaration example in the same change, so the docs stop
minting hosts the flip would break. `agent-templates:` stays published until 3b retires it.

### M3 — `.handbook/` becomes `<agent-workspace>/doctrine/`

    .dev/doctrine/
      README.md                        <- the install stamp lives here
      scripts/context.sh
      core/{POLICY,INVARIANTS,GOTCHAS,ROUTING}.md
      design|build|test|review/POLICY.md
      build/workflows/{feature,bug,patch,spike}.md
      test/workflows/diagnostics.md
      review/workflows/doc-audit.md

*(`test/workflows/audit/` is **not** seeded — `/auditor setup` creates it at the resolved home. It
belongs in the tree, not in what `seed.sh` writes.)*

**`context.sh`'s LOGIC needs no change; two header comments do.** `context.sh:15` resolves its root
as `$(cd "$(dirname "$0")/.." && pwd)`, so at `.dev/doctrine/scripts/context.sh` that yields
`.dev/doctrine/` and every load-set path resolves. **This is why the loader must stay nested inside
`doctrine/`** rather than in a workspace-level `scripts/` — at `.dev/scripts/context.sh` its root
would resolve to `.dev/` and every load set would miss. Stale `.handbook/` literals at `context.sh:2`
and `:5` must be updated; "no change" means its logic, not its bytes.

**The stamp relocates** to `<workspace>/doctrine/README.md`. Its *string* is unchanged
(`Seeded from clankshop vX.Y on DATE`), so rule 8's policy semantics are untouched — but four sites
carry the old literal path: `DOCTRINE.md:337` plus the three surviving policy probes
(`debugger:39`, `workstream/SKILL.md:101`, `workstream/verbs/create.md:119`). Those probes must now
resolve `<agent-workspace>` before locating the stamp. That does **not** convert them into location
questions — they still decide *is a workshop assembled* — but it is more machinery in a probe rule 8
calls simple, and rule 8's wording should acknowledge it.

**Existing deployments migrate physically; no declaration expresses it.** There is no value of
`agent-workspace` that maps an existing `.handbook/` tree onto `<workspace>/doctrine/` — declaring
`agent-workspace: .handbook` yields `.handbook/doctrine/`. A pre-flip workshop needs
`git mv .handbook <workspace>/doctrine`. Exactly one such deployment is known (the author's).
**Decision 3's "no `git mv` is forced" is scoped to records only** — stated here and in the Decision
log, not left as an instruction.

### M4 — who may create a home

Doctrine-touching rule 3 permits creating a home *only when it is the derived default* and forbids
creating an **explicitly declared** home that is absent. Read universally that would forbid
`clankshop setup` from seeding into a declared-but-absent workspace, making the Approach's "a host
preferring `.workspace/` writes one line" unimplementable — and it would also forbid what
`standup.sh:44` already does today for a declared records home.

**The rule needs an owner exception, folded into S1:** *the skill that **assembles** a home may
create it even when declared (clankshop for the workspace, journal for records); every other skill
resolves, tests, and degrades per rule 2 — never `mkdir`.* State it in `DOCTRINE.md` rather than
leaving M4 to imply a universal prohibition.

### M5 — flip the five consumers (+ every other carrier)

`auditor:20`, `blueprint:32`, `contractor:23`, `debugger:28`, `workstream:96` move from resolving
`agent-doctrine:` to resolving `agent-workspace:` and reading `<agent-workspace>/doctrine/…`. Their
station-shaped subpaths are unchanged.

**The complete `<agent-doctrine>` carrier census (15 files, verified by an independent reviewer —
this is the census the split was drawn around):** the five `SKILL.md`s, plus
`auditor/BOOTSTRAP.md:12,102,268,275,276`, `workstream/{flow.md:56, verbs/sync.md:100,
verbs/create.md:119}`, `journal/SKILL.md:29`, `agent-council/briefs/skill-review.md:33`,
`skill-builder/docs/DOCTRINE.md`, `skills-lint.sh:632`,
`skill-builder/scripts/tests/lint-doctrine-consumer-test.sh`, and `journal/scripts/records.sh:70`
(comment only).

**Problem 3 closes by construction on a default host:** the seed lands at the *default* workspace
path, so the host declares nothing and its consumers still resolve it. There is no declaration to
forget. (Non-default hosts still declare, and a forgotten declaration degrades as today — "by
construction" is scoped to the default layout.)

### M6 — clankshop

- `setup.md` — step 2 seeds to `<agent-workspace>/doctrine`; step 4's door writes
  `agent-workspace: <rel>` **only when not the default**, and points at
  `<agent-workspace>/doctrine/README.md`; Guard (c)'s classification reads the new paths and
  **retains its "Existing `.handbook`?" branch** as a legacy arm.
- `migrate.md` — step 3's seed row, step 4's door write, and a new **adopt row**: a legacy
  coincident host declares `agent-workspace: dev`.
- `check.md` — step 1's loader path, step 2's stamp path, step 4's door pointer.
- `persona.md:12` — the deployed loader path `<root>/.handbook/scripts/context.sh`.
- `SKILL.md` — including its `description:` frontmatter, which names `.handbook/` and is routing
  surface.
- **`seed.sh`** — gains `--workspace <rel>` (front-door doctrine forbids write scripts scanning the
  door, so the resolved path arrives as an argument); `:31`'s hardcoded `hb="$root/.handbook"`
  becomes the passed path. Its **refuse-on-existing check must test both** `<ws>/doctrine` **and**
  legacy `.handbook/` — otherwise `seed.sh` on a pre-flip host seeds a second tree beside the live
  one, recreating Problem 3's exact pathology.
- **`migrate-scan.sh`** — gains a `workspace=` probe **and retains `handbook=`**. It runs before any
  door exists, so it can only test the **default** (`.dev/doctrine`); the legacy probe is what
  detects a pre-flip workshop. The key answers *is a workshop assembled*, not *does the home exist*.

### M7 — doctrine and lint

**`DOCTRINE.md` (S1) — enumerated, because it defines the literals every later slice writes:**

- The **front-door section**: `agent-workspace` replaces `agent-doctrine`; the "one `agent-records:`
  line moves all three" rationale narrows to two; `:236`'s prospective note goes with the retired
  variable; the deliberate echo break is documented here, once.
- **`:226-228` must stop publishing `agent-doctrine: .handbook`** (required — see M2). The
  `agent-templates: schemas` example stays until 3b.
- **`:230-232`'s example literals** include `.records/doctrine/audit/…`, which this feature
  falsifies. The Approach cites these lines as support for the echo break — update the example, keep
  the rule.
- **Rule 1**'s three-destination classification table (Doctrine→`<agent-doctrine>`).
- **Rule 3** — the derived-default clause **plus M4's owner exception**.
- **Rule 5**'s sanctioned literal set, keyed *"For home `H` (one of `agent-records`,
  `agent-templates`, `agent-doctrine`)"* — **this enumeration is what lint check 14 greps.**
- **Rule 6**'s `produces: doctrine` / `consumes: doctrine` edge vocabulary. **Decision: the edge type
  stays `doctrine`** — it names the kind of thing carried, not the home it resolves through.
- **Rule 8**'s `<agent-doctrine>` sentence, its *"Do not create `.handbook/`"* clause, and `:337`.

**Lint:**

- **Check 14**'s sanctioned set tracks rule 5. It is **edge-gated and `.md`-only**, so it cannot see
  `backlog`, `notepad`, `auditor`, `debugger`, `workstream`, or any `.sh` file — it is a *presence*
  requirement on the two skills that declare a doctrine edge, not a repo-wide guarantee.
- **New unconditional check 16** — the absence guard check 14 cannot provide: FAIL on `agent-doctrine`
  appearing as a resolution literal anywhere under `skills/`, exemptions `skill-builder` + pack
  faces, **glob including `scripts/**/*.sh`**. This is what makes "the variable is retired"
  verifiable rather than asserted.
- **Check 15 keeps its `.handbook/<station>/` literals — do NOT rewrite them.** Check 15's own
  rationale (`skills-lint.sh:660-666`) rules out matching *default* paths: prose is required to name
  defaults literally, so a hardcoded default is textually identical to a documented one; only
  **off-home** literals are decidable. `.handbook/` remains off-home and is now also stale.
  **Newly decidable and worth adding:** `.records/doctrine/` stops being any home's default after
  this feature, so it becomes a legitimate check-15 literal — the strongest new guard this feature
  enables.

## Verification

**Governing discipline: no check is trusted until it FAILs on deliberately-broken input.**

**Nothing in this library mechanically resolves a front-door variable outside three state-analysis
helpers**, and this feature adds no resolver. So every row below is a **lint** or **agent** proof,
and says which. An earlier draft asserted `script` rows against a resolver that does not exist, and
one of them was **vacuous** — it could not go red whether the feature was implemented or not. Named
rather than quietly replaced.

| what | how it is proven | kind |
|---|---|---|
| **`agent-doctrine` is retired** | check 16: no `agent-doctrine` resolution literal under `skills/` outside the exemptions, `.sh` included; **red-proof:** reintroduce the literal into a fixture skill → lint **FAILs** | lint |
| check 14 keeps teeth | fixture skill declaring a `doctrine` edge with no sanctioned literal → check 14 FAILs; **red-proof:** add the `<agent-workspace>` literal → passes | lint |
| check 15 gains a guard | fixture carrying `.records/doctrine/test/` → check 15 FAILs; **red-proof:** remove it → passes | lint |
| `context.sh` relocates transparently | seed a fixture to `.dev/doctrine/`, run `context.sh --check` → `load sets: OK`; **red-proof:** delete `core/ROUTING.md` → exit 2 | script |
| seed refuses a pre-flip host | fixture with a live `.handbook/` → `seed.sh` **refuses**; **red-proof:** remove the legacy arm → it seeds a second tree | script |
| `migrate-scan` sees both | fixture with `.handbook/` → `handbook=present`; fixture with `.dev/doctrine/` → `workspace=present`; **red-proof:** drop the legacy probe → a pre-flip host reports absent | script |
| stamp relocation | `check` on a fixture finds the stamp at `.dev/doctrine/README.md`; **red-proof:** delete the stamp line → reported | script |
| **legacy host must declare** | coincident fixture declaring only `agent-records: dev` → doctrine resolves to `.dev/…` and degrades; adding `agent-workspace: dev` restores it. Proves the migration step is required | script |
| coincidence still reserved | fixture with both at `dev/` and a `dev/doctrine/<station>/workflows/x.md` carrying prose and **no front-matter**: assert `check` green, `list` omits it, `show` exits 2 with `reserved path, not a record`, `touch` likewise — **each arm red-proofed independently** (the incumbent `records-test.sh:183-215` standard; `records.sh` is unmodified here, so this is a **no-regression** row) | script |
| **Problem 3 closes on a default host** | seed a default-layout fixture, declare nothing → the path `seed.sh` wrote equals the literal each of the five consumers' `SKILL.md` names; **red-proof:** move the seed without declaring → the two diverge | agent |
| policy probes still fire | fixture workshop → `debugger` Phase 4 gate opens; **red-proof:** remove the stamp → gate closes | agent |
| declared-but-absent workspace | fixture declaring `agent-workspace: nowhere` → `clankshop setup` **creates** it (owner exception); a consumer **degrades and reports**, never `mkdir`s; **red-proof:** make the consumer create it → assertion fails | agent |
| lint baseline | `skills-lint.sh` `fails=0`, warns ≤ **22** (no new skill added) | lint |
| whole-suite | **all eight** `skills/*/scripts/tests/run.sh` | script |

## Slices

| id | does | verify | paths |
|---|---|---|---|
| **S1** | `DOCTRINE.md` (M7): retire the variable, rules 1/3/5/6/8, the **owner exception**, remove `:226-228`'s doctrine example, fix `:230-232`'s literal, document the echo break | lint baseline; S2 depends on rule 5 | `skills/skill-builder/docs/DOCTRINE.md` |
| **S2** | Lint: **new check 16** (absence, `.sh` included), check 14's set tracks rule 5 **accepting both literal families transitionally**, check 15 gains `.records/doctrine/` | the three lint rows, each red-proofed | `skills/skill-builder/scripts/skills-lint.sh`, `scripts/tests/lint-doctrine-consumer-test.sh` |
| **S3** | Seed relocation: `seed.sh --workspace` + **dual refuse arm**, `context.sh:2,:5` literals, stamp path | `context.sh`, seed-refuses, stamp rows | `skills/clankshop/{scripts/seed.sh,seed/}`, `scripts/tests/seed-test.sh` |
| **S4** | clankshop verbs + `migrate-scan.sh` dual probe + `migrate.md`'s adopt row | clankshop suite; migrate-scan + legacy-host rows | `skills/clankshop/{verbs/*,SKILL.md}`, `scripts/migrate-scan.sh`, `scripts/tests/{setup-journal,migrate-scan,face}-test.sh` |
| **S5** | Flip all 15 `<agent-doctrine>` carriers (M5's census) + rule 8's stamp literal | Problem-3, policy-probe, declared-but-absent rows | the 5 `SKILL.md`s, `auditor/BOOTSTRAP.md`, `workstream/{flow.md,verbs/sync.md,verbs/create.md}`, `journal/SKILL.md`, `agent-council/briefs/skill-review.md` |
| **S6** | Narrow check 14 to `<agent-workspace>` only; roster/prose folds; remaining `.handbook` literals | check-14 red-proof; lint `fails=0`; **all eight** suites | `skills-lint.sh`, `README.md`, `AGENTS.md`, `PACK.md`, `clankshop/seed/README.md`, `seed/review/workflows/doc-audit.md`, `workstream/templates/*` |

**Ordering.** S1 first — it defines the literals every later slice writes. S2 lands **accepting both
literal families**, so the gate does not go red on `blueprint`/`contractor` during S3–S5; **S6
narrows it after S5**, with a red-proof that the narrowed set FAILs a fixture carrying the retired
literal. That is the real constraint — *S6 narrows only after S5* — not a must-land-together pair.
S3 before S4; S5 after S3.

## Greenfield check

- **`.handbook`'s specialness.** M3 exists because the seed lands somewhere the default resolver
  does not point. Deleting that mismatch is precisely what this feature does — the seed now lands at
  the derived default. Nothing paid.
- **The stamp.** Its *location* moves here; its existence is out of scope (rule 8 adjudicated its
  policy consumers). Greenfield, a workshop assembled into a resolvable home would need no stamp —
  the home's existence plus a loader is the same evidence. Named, not taken: the three policy probes
  are shipped surface.
- **The reserved-name list.** Untouched here and load-bearing for coincidence. Its *demotion* is
  feature 3b's, and only after `templates/` moves. Naming it now so 3b does not treat it as new.
- **`agent-records`' legacy `records-root:` alias.** Still carried; brownfield hosts declared it.
- **Whether `agent-workspace` needs to be a variable at all.** A fixed `.dev/` would close Problem 3
  identically with zero variables. Settled as a variable (Decision 1, human) — and unlike
  `agent-doctrine`, it has a **live** variance case this spec produces: M6's legacy coincident host
  must declare `agent-workspace: dev`. It clears the bar that `agent-doctrine` never did.

## Decision log

Settled by the human 2026-08-18 unless noted. **Do not re-litigate.**

1. **`agent-workspace` is a variable**, default `.dev/`.
2. **Default `.dev/`, variable `agent-workspace`** — the mismatch is deliberate; reasoning above.
3. **The two homes may coincide**, and the reserved list keeps that working. **"No `git mv` is
   forced" is scoped to RECORDS only** — a pre-flip `.handbook/` workshop *does* need a physical
   rename (M3), and a legacy coincident host *does* need to add a declaration (M6). Neither is a
   no-op.
4. **`records.sh` is untouched by this feature** *(reversed 2026-08-18 after review)* — it derives
   its root from its own install location. Its reserved list keeps all four names.
5. **`.handbook/` becomes `<agent-workspace>/doctrine/`**; `context.sh` stays nested inside it.
6. **Atomic retirement of `agent-doctrine`, no fallback window.** *Risk consciously accepted* — see
   M2. The `:226-228` removal is **required**, not optional.
7. **Workflows stay station-scoped**; no top-level `workflows/` *(agent, from evidence)*.
8. **No legacy alias for `agent-workspace`**; `agent-workspace: .` is forbidden.
9. **The edge type stays `doctrine`** *(agent)*.
10. **Naming is closed** — five candidates burned; see the table.
11. **`agent-templates` is OUT OF SCOPE — feature 3b** *(split 2026-08-18, human, on review
    evidence)*. This feature must not touch `records.sh:180`, the mint scripts, `analyst`,
    `backlog`, or `notepad`.

## Grounding

Verified at spec time, not assumed:

- `records.sh:26` derives `RR` from the script's own location; `:5` header states it. `:64`/`:82`/`:70`
  carve-outs unmodified by this feature.
- `DOCTRINE.md:217-223`, `:226-228`, `:230-232`, `:236`, `:337`, rule 3 at `:395-400`, rule 5's home
  enumeration, rule 6's edge vocabulary.
- 5 consumer readers of `agent-doctrine:`; **0 writers** repo-wide (exhaustive grep, twice).
- The 15-file `<agent-doctrine>` carrier census — independently enumerated and confirmed complete.
- `context.sh:15` (`HB` resolution, traced through `load_set()`/`check_all()`), `:16` STATIONS,
  stale `.handbook/` literals at `:2` and `:5`.
- `seed.sh:31` hardcodes `hb="$root/.handbook"` and takes no home flag.
- `skills-lint.sh` baseline `fails=0 warns=22`; `is_pack_face()` `:118-123`; check 14 edge-gated and
  `.md`-only at `:618-639`; check 15's undecidability rationale at `:660-666`.
- Seed workflow dirs are station-scoped (`build/`, `test/`, `review/`); `test/workflows/audit/` is
  **not** seeded.
- `migrate.md:24-26` — `dev/` as the worked legacy **records** root.
- Naming archaeology: `2026-08-18-records-layer-init.md:173-174,1120`;
  `2026-07-17-library-refactor-plan.md` Task 6; `2026-07-17-library-refactor.md:310-312`.
- `.dev` and `agent-workspace` are unclaimed in the repo and in `.gitignore`.

## Review history

### 2026-08-18 — needs-rework (round 1: soundness, groundedness, skeptic)

Three lenses, unanimous. Design sound; census and verification table were not. Nineteen findings;
the load-bearing one was that `records.sh:26` derives its root from its install location, making the
then-proposed move unimplementable. Full dispositions in `de9a250`'s revision of this file.

### 2026-08-18 — needs-rework (round 2: disposition audit + new-defect hunt)

Delta pass over the fold. **Disposition audit: 13 upheld, 4 overstated, 0 false** — the fold was
substantially honest, but four entries *recorded a TODO instead of executing it* (the "no-op" and
"no `git mv`" claims survived in the Decision log and Greenfield check while the Mechanism said the
opposite). The new-defect hunt found the `agent-templates` census still incomplete for the third
consecutive round, plus a blocking contradiction (the carve-out cannot demote and still guarantee
coincidence) and a false claim that deleting `records.sh:180`'s fallback was safe — three contractor
verbs call `records.sh new plans --title` bare and would hard-error.

**Both rounds are resolved by the 2026-08-18 scope split**, not by another fold:

- Every `agent-templates` finding → **feature 3b**, where it is in scope.
- The carve-out contradiction → **dissolved**: `records.sh` is untouched here, so the reserved list
  does not change and there is nothing to demote.
- `records.sh:180` → **out of scope**; the fallback is not deleted by this feature.
- The stale "no-op" / "no `git mv`" claims → **executed**, not re-noted: Decision 3 and the Approach
  now scope the claim to records and state both migration steps.
- The vacuous / unbacked verification rows → **replaced**: every row is now lint or agent, check 16
  supplies the absence guarantee check 14 structurally cannot, and the coincidence row is relabelled
  a **no-regression** check.
- The S2/S7 pairing self-contradiction → **restated** as *S6 narrows only after S5*.
- M4's declared-but-absent contradiction → **resolved** by the owner exception in M7/S1.

_A delta re-review is recommended before sequencing: this is a scope change plus a fold, authored by
the spec's own author._
