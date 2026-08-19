---
doctype: design
status: done
created: 2026-08-18
updated: 2026-08-19
tags: [spec]
---

# `agent-workspace`, part 1 — the doctrine home — Spec

`stream/feat` **feature 3a**. Grounded against `main` @ `ce7e758` + branch `de9a250`.

> **SHIPPED 2026-08-19.** Built in six slices, in the specified order, each gated. Commit
> subjects (not shas — the land rebases): *doctrine: retire agent-doctrine into
> agent-workspace/doctrine (S1)* · *lint: add check 16 (retired-literal absence + workspace
> declaration guards) (S2)* · *clankshop: seed doctrine into <workspace>/doctrine, refuse a
> pre-relocation host (S3)* · *clankshop: verbs and preflight resolve the workspace home;
> migrate gains the adopt row (S4)* · *flip the twelve agent-doctrine carriers to
> agent-workspace/doctrine (S5)* · *promote check 16 to FAIL, narrow check 14, close BL-26,
> fold remaining prose (S6)*.
>
> **Two spec defects surfaced at build**, both the same class the reviews kept finding — an edit
> surface enumerated by *intent* rather than by *consequence* — and both fixed by applying this
> spec's own staging remedy rather than a new one:
> 1. **Check 15's new `.records/doctrine/` literal was specified to land in S2 as a FAIL**, but
>    the literal was live in five consumer skills until S5, so the trunk gate would have been red
>    for the entire S2–S5 window. Round 3's MUST-FIX #3 identified exactly this hazard for check
>    16 and gave it a WARN carve-out; the same reasoning was never applied to check 15. Built
>    staged: WARN in S2, promoted to FAIL in S6 alongside check 16.
> 2. **S3's relocation breaks `setup-journal-test.sh`**, a file the Slices table assigns to S4 —
>    so S3 could not have landed green as written. Its path was repointed in S3; S4's substantive
>    work stayed in S4.
>
> Recorded as **BL-29**. Byproducts **BL-30** (the `.`-guard gained a second enforcer in
> `seed.sh` with no single owner — a Decision 13 question) and **BL-31** (the seed's prose still
> calls itself "the handbook"; the census covered path literals only) are open.
>
> **Verification, all red-proofed by disabling the check:** check 16's three arms, check 15's new
> literal, check 14's narrowing, `seed.sh`'s dual refuse arm (removing the legacy arm
> demonstrably builds a second doctrine tree beside the live one), `migrate-scan`'s dual probe.
> The promotion row ran one fixture against S2's lint (`exit=0`) and S6's (`exit=1`).
> Problem 3 closes on a default host as specified: `seed.sh` wrote `.dev/doctrine/`, the door
> declares nothing, and all five consumers name `.dev/doctrine/`.
>
> **The census was independently reproduced by check 16 itself** — 12 non-exempt files, 32
> occurrences, every line matching M5. Four review rounds could not get that right by hand.

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

**`records.sh`'s behavior and reserved-name list are untouched by this feature.** (S5 edits two
`agent-doctrine` **comments** in `records.sh` and `records-test.sh` — the census requires it and
check 16 would flag them. No code, no reserved list, no `:180`. "Untouched" below means
behaviorally untouched; see Decision 4 and Decision 11.) An earlier draft
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
stand still.** That is a required migration step with its own verification row (M6).

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
  the five consumers' expected subpaths exactly, so nothing else would have to move.
  **Stated plainly (round 3): the one-line fix does close Problem 3.** It satisfies this spec's Goal
  as written — a default-layout workshop found by its own consumers with nothing declared, and no
  second-doctrine-tree pathology (`.handbook` becomes the derived default, so rule 3 stops
  misfiring). What it does **not** do is remove a variable with no demonstrated variance case from
  the front door, or stop doctrine defaulting inside the records home. **So the rest of this feature
  is a consistency investment, not a correctness fix** — that is the honest framing, and it is the
  basis on which Decisions 1–2 were settled. Do not read the rejection as a claim that the cheap fix
  leaves the regression open. **Taken as the abandonment fallback:** if this feature must be dropped
  mid-flight, that one line is the thing to ship.
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

**Two declaration guards, both owned by lint check 16** (S2). Nothing in this library mechanically
resolves a front-door variable outside three state-analysis helpers, so a "reject it and report"
with no named owner is unenforceable prose; check 16 already walks `skills/` and the door, and is
the only mechanism this feature installs that can carry them:

- **`agent-workspace: .` is forbidden** — it would place doctrine at `./doctrine`, colliding with
  real project directories.
- **`agent-workspace:` declared with a value equal to the current default (`.dev`) is flagged as a
  probable no-op.** This is not pedantry: M6 *requires* a legacy coincident host to declare
  `agent-workspace: dev` (undotted). `agent-workspace: .dev` is one keystroke away, syntactically
  valid, and silently restates the default — so the host degrades exactly as Problem 3 describes,
  now by way of the prescribed migration step rather than the bug it fixes. The guard sits on the
  one path this spec mandates walking. (A deliberate `.dev` declaration is legal; the guard warns,
  it does not fail.)

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
would resolve to `.dev/` and every load set would miss. Two stale header comments must be updated —
`context.sh:5` carries the actual `.handbook/` path literal (it is the file's only occurrence);
`:2` carries the bare word "handbook" in the tool's one-line description. Both need the rename;
only `:5` is a path literal. "No change" means its logic, not its bytes.

**The stamp relocates** to `<workspace>/doctrine/README.md`. Its *string* is unchanged
(`Seeded from clankshop vX.Y on DATE`), so rule 8's policy semantics are untouched — but four sites
carry the old literal path: `DOCTRINE.md:337` plus the three surviving policy probes
(`debugger:40`, `workstream/SKILL.md:102`, `workstream/verbs/create.md:118`). Those probes must now
resolve `<agent-workspace>` before locating the stamp. *(Line numbers corrected in round 3 — the
first three each sit on the second line of a two-line sentence, and the earlier citations pointed at
the half without the literal. `workstream/verbs/create.md` belongs to **this** list and **only**
this list; it carries a `.handbook` stamp literal and zero occurrences of `agent-doctrine`, so its
prior appearance in M5's carrier census was a false positive.)* That does **not** convert them into location
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

**The complete `agent-doctrine` carrier census — GENERATED, not asserted.** Reproduce with:

    grep -rlE 'agent[-_]doctrine|AGENT_DOCTRINE' skills/ | sort

Output at `dd40010`, checked in here as the artifact — **15 files, 54 occurrences.** The line lists
are **exhaustive, not first-hit locators**; regenerate with the same expression per file:

    skills/agent-council/briefs/skill-review.md          33
    skills/auditor/BOOTSTRAP.md                          12,102,268,275,276
    skills/auditor/SKILL.md                              20,28,31,99,108,109
    skills/blueprint/SKILL.md                            31,32,38,39,369
    skills/contractor/SKILL.md                           22,23,29,30,125
    skills/debugger/SKILL.md                             28,31
    skills/journal/SKILL.md                              29
    skills/journal/scripts/records.sh                    70,77          (comments)
    skills/journal/scripts/tests/records-test.sh         183            (comment)
    skills/skill-builder/docs/DOCTRINE.md                222,228,236,273,275,276,280,340,381,415
    skills/skill-builder/scripts/skills-lint.sh          86,630,631,632,638,675
    skills/skill-builder/scripts/tests/lint-doctrine-consumer-test.sh
                                                         52,70,86,102,120,192
    skills/workstream/SKILL.md                           96,99
    skills/workstream/flow.md                            56
    skills/workstream/verbs/sync.md                      100

**S5 sweeps whole files, not the lines above.** The list exists so a slice can be checked for
coverage and so check 16's green can be predicted — not as an edit worklist. An earlier version of
this block cited one line per file, which read as a locator set and would have invited
line-targeted edits that leave siblings behind (`auditor/SKILL.md` alone has six).

**Corrected in round 3 (the prior census had the right count and the wrong membership).**
`workstream/verbs/create.md` was in and is **out** — it carries zero occurrences of the term; what
sits at its `:118` is a `.handbook` stamp literal, which belongs to M3's list.
`journal/scripts/tests/records-test.sh` was out and is **in**. The two swaps cancel, which is why
the erroneous list still totalled 15 — a count is not a census, and this is the fourth round the
distinction has cost.

**Inclusion rule, stated once and applied uniformly: a comment counts.** Check 16 is a *textual*
absence guard; it cannot tell a comment from code, so every occurrence of the literal is a carrier
regardless of syntactic role. That is why both `records.sh:70` and `records-test.sh:183` are in —
the earlier list counted the first and omitted the second, which is the inconsistency that hid the
error. **Both must therefore appear in a slice's `paths` (S5), or check 16 can never go green.**

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
  coincident host declares `agent-workspace: dev`. **The adopt row must state the undotted value
  explicitly and warn that `.dev` is the wrong answer here** — it is the default, so declaring it is
  a silent no-op that leaves the host degraded (M1's second guard is the mechanical backstop; this
  is the prose one, at the point of use).
- `check.md` — step 1's loader path, step 2's stamp path, step 4's door pointer.
- `persona.md:11` — the deployed loader path `<root>/.handbook/scripts/context.sh`. *(Was cited as
  `:12` in round 2; that line is unrelated prose about the station's `POLICY.md` preamble.)*
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
- **New check 16** — the absence guard check 14 cannot provide: it fires on `agent-doctrine`
  appearing anywhere under `skills/` (comments included — see M5's inclusion rule), exemptions
  `skill-builder` + pack faces, **glob including `scripts/**/*.sh`**. This is what makes "the
  variable is retired" verifiable rather than asserted. It also carries M1's two declaration
  guards (forbidden `.`; default-valued no-op).
  **"Unconditional" describes its *scope*, not its severity** — unlike check 14 it is not
  edge-gated, so it sees every skill and every file type. Its severity is staged across two slices:

  **Severity is staged PER ARM, not for the check as a whole.** Only one of the three arms has a
  transitional population; staging the other two would be cargo-culting the carve-out.

  | arm | S2 | S6 | why |
  |---|---|---|---|
  | retired-literal absence | **WARN** | **FAIL** | the 15 carriers are still unflipped until S5; failing here would redden the trunk gate for the whole S2–S5 window |
  | `agent-workspace: .` forbidden | **FAIL** | FAIL | the variable is **new** — nothing can have declared it before this feature, so there is no population to protect and no reason to soften it |
  | default-valued no-op warning | **WARN** | WARN | advisory by design: a deliberate `.dev` declaration is legal, so this arm never fails |

  The absence arm mirrors check 14's "accept both literal families transitionally, narrow in S6"
  treatment, for the same reason: the trunk gate stays green across the rollout. S6's promotion
  carries its own red-proof — a fixture carrying the retired literal must **FAIL** under the
  promoted check and only **WARN** under the S2 one, so the promotion is shown to do work.
- **BL-26 — `skill-builder/verbs/new.md:35` (S6 tail).** It tells the scaffolder to inline "the
  agent-records / agent-templates resolvers (default paths named literally)". It does **not** name
  `agent-doctrine`, so this feature's exposure is narrower than BL-26's full scope: the fix here is
  to add `agent-workspace` to that resolver list so newly scaffolded skills resolve the doctrine
  home the new way. The `agent-templates` half stays for **3b** to retire. Small, and it belongs
  with S6's tightening — otherwise the check installed in S2/S6 starts failing skills that
  `new.md` itself told the author to write.
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
helpers**, and this feature adds no resolver. Every row below is therefore a **lint**, **script**,
or **agent** proof, and says which — where a `script` row exercises a real shipped tool
(`context.sh`, `seed.sh`, `migrate-scan.sh`, `records.sh`) against a fixture. What an earlier draft
did wrong was assert `script` rows against a **resolver that does not exist**, one of them
**vacuous** — it could not go red whether the feature was implemented or not. Those rows are gone;
the surviving `script` rows all drive tools that exist today.

*(Round 3 correction: this paragraph previously claimed "every row below is a lint or agent proof"
while the table carried `script` on seven of fourteen rows. The rows were sound; the claim was not.)*

| what | how it is proven | kind |
|---|---|---|
| **`agent-doctrine` is retired** | check 16 (promoted to FAIL in S6): no occurrence of `agent-doctrine` under `skills/` outside the exemptions, `.sh` and comments included; **red-proof:** reintroduce the literal into a fixture skill → lint **FAILs** | lint |
| **check 16's promotion does work** | a fixture carrying the retired literal **WARNs** under S2's check and **FAILs** under S6's; **red-proof:** run the same fixture both ways — identical input, different verdict, so the promotion is not cosmetic | lint |
| **the flip is positive, not just absent** | check 16 proves the old literal is *gone*; it cannot distinguish "repointed to `<agent-workspace>`" from "silently deleted". **S5 build-time check, not a standing gate:** for each of the 12 carriers it flips, confirm the site that held the old literal now names `<agent-workspace>` (or `.dev/doctrine`). **Red-proof:** in a fixture, delete a replacement instead of repointing it → this check reports the carrier while check 16 still passes, which is exactly the gap it covers. *Deliberately **not** lint:* a standing check would have to carry the frozen census as data and would rot the moment a skill is added or renamed | agent |
| check 14 keeps teeth | fixture skill declaring a `doctrine` edge with no sanctioned literal → check 14 **FAILs — this is the red-proof**; green control: add the `<agent-workspace>` literal → passes | lint |
| check 15 gains a guard | fixture carrying `.records/doctrine/test/` → check 15 **FAILs — this is the red-proof**; green control: remove it → passes | lint |
| **declaration guards fire** (M1) | `agent-workspace: .` → rejected and reported; `agent-workspace: .dev` on a host whose records are at `dev/` → flagged as a probable no-op; **red-proof:** remove each guard in turn → the fixture declaring the bad value passes silently | lint |
| `context.sh` relocates transparently | seed a fixture to `.dev/doctrine/`, run `context.sh --check` → `load sets: OK`; **red-proof:** delete `core/ROUTING.md` → exit 2 | script |
| seed refuses a pre-flip host | fixture with a live `.handbook/` → `seed.sh` **refuses**; **red-proof:** remove the legacy arm → it seeds a second tree | script |
| `migrate-scan` sees both | fixture with `.handbook/` → `handbook=present`; fixture with `.dev/doctrine/` → `workspace=present`; **red-proof:** drop the legacy probe → a pre-flip host reports absent | script |
| stamp relocation | `check` on a fixture finds the stamp at `.dev/doctrine/README.md`; **red-proof:** delete the stamp line → reported | script |
| **legacy host must declare** | coincident fixture declaring only `agent-records: dev` → doctrine resolves to `.dev/…` and **degrades — this is the red-proof**; green control: add `agent-workspace: dev` → restored. Proves the migration step is required, not cosmetic | script |
| **check 14's narrowing has teeth** (S6) | after S6 narrows check 14's sanctioned set to `<agent-workspace>` only, a fixture carrying the retired `<agent-doctrine>` literal **FAILs**; **red-proof:** run the same fixture against the pre-S6 transitional set → passes, so the narrowing is what does the work | lint |
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
| **S2** | Lint: **new check 16** (absence, `.sh` + comments included, **WARN-only here**) carrying M1's two declaration guards; check 14's set tracks rule 5 **accepting both literal families transitionally**; check 15 gains `.records/doctrine/` | the lint rows, each red-proofed; **lint stays green** (check 16 warns, does not fail, until S6) | `skills/skill-builder/scripts/skills-lint.sh`, `scripts/tests/lint-doctrine-consumer-test.sh` |
| **S3** | Seed relocation: `seed.sh --workspace` + **dual refuse arm**, `context.sh:2,:5` literals, stamp path | `context.sh`, seed-refuses, stamp rows | `skills/clankshop/{scripts/seed.sh,seed/}`, `scripts/tests/seed-test.sh` |
| **S4** | clankshop verbs + `migrate-scan.sh` dual probe + `migrate.md`'s adopt row | clankshop suite; migrate-scan + legacy-host rows | `skills/clankshop/{verbs/*,SKILL.md}`, `scripts/migrate-scan.sh`, `scripts/tests/{setup-journal,migrate-scan,face}-test.sh` |
| **S5** | Flip the **12 remaining** `agent-doctrine` carriers (M5's census minus the 3 handled in S1/S2) + rule 8's stamp literal + `create.md`'s stamp probe | Problem-3, policy-probe, declared-but-absent, positive-flip rows | the five consumer `SKILL.md`s (`auditor`, `blueprint`, `contractor`, `debugger`, `workstream` — note the census holds **six** `SKILL.md`s; journal's is listed separately below and is not double-counted), `auditor/BOOTSTRAP.md`, `workstream/{flow.md,verbs/sync.md}`, **`journal/{SKILL.md, scripts/records.sh, scripts/tests/records-test.sh}`**, `agent-council/briefs/skill-review.md`; plus `workstream/verbs/create.md` (**stamp literal only** — not an `agent-doctrine` carrier) |
| **S6** | **Promote check 16 WARN→FAIL** and narrow check 14 to `<agent-workspace>` only; **BL-26** — `skill-builder/verbs/new.md` stops prescribing the retired resolver; roster/prose folds; remaining `.handbook` literals | check-16 promotion + check-14 narrowing red-proofs; lint `fails=0`; **all eight** suites | `skills-lint.sh`, **`skill-builder/verbs/new.md`**, `README.md`, `AGENTS.md`, `PACK.md` (*roster prose — carries no `.handbook` literal*), `clankshop/seed/README.md`, `seed/review/workflows/doc-audit.md`, `workstream/templates/*` |

**Ordering.** S1 first — it defines the literals every later slice writes. S2 lands **permissively**:
check 14 accepts both literal families and check 16 ships WARN-only, so the gate does not go red on
`blueprint`/`contractor` or on the not-yet-flipped carriers during S3–S5. **S6 tightens both after
S5** — narrowing check 14 and promoting check 16 to FAIL — each with its own red-proof. That is the
real constraint: *S6 tightens only after S5*, not a must-land-together pair.

**Shipping order: S1 → S2 → S3 → S4 → S5 → S6.** Only four of those edges are *required*; the rest
is a chosen sequence, and the distinction matters if a slice has to be resequenced later.

- **Required:** S1 first (it defines the literals every later slice writes) · **S3 before S4** (the
  verbs point at what the seed writes) · **S5 after S3** · **S5 after S4** *(added round 3 —
  S5's "declared-but-absent workspace" row exercises `clankshop setup`'s owner exception, which S4
  builds; without this edge S1,S2,S3,**S5,S4**,S6 satisfies every stated constraint and runs S5's
  verification against machinery that does not exist yet)* · **S6 after S5** (it tightens what S5
  emptied).
- **Chosen, not required:** S2's position relative to S3/S4. Check 16 has no interaction with
  `seed.sh` or `migrate-scan.sh`; S2 sits early only so the gate is watching during the moves.

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
  identically with zero variables. Settled as a variable (Decision 1, human).
  **This spec does NOT claim the new variable clears a bar the old one failed** — that claim was
  withdrawn in round 3 as circular, and rightly: `agent-doctrine` is retired for having only a
  prospective variance case, while `agent-workspace`'s one live case (M6's legacy coincident host
  declaring `agent-workspace: dev`) exists *because this spec chose `.dev` as the default*. A
  variance case a design manufactures is migration friction, not demonstrated host variance, and
  grading the new variable on it while executing the old one for its absence would be a double
  standard inside one document.
  The variable is justified on **architecture** instead: the front door should express *where the
  development environment lives* as one declaration, and a host that wants it elsewhere should not
  have to fork the library. That is a design position, held openly, not an evidence claim.

## Decision log

Settled by the human 2026-08-18 unless noted. **Do not re-litigate.**

1. **`agent-workspace` is a variable**, default `.dev/`.
2. **Default `.dev/`, variable `agent-workspace`** — the mismatch is deliberate; reasoning above.
3. **The two homes may coincide**, and the reserved list keeps that working. **"No `git mv` is
   forced" is scoped to RECORDS only** — a pre-flip `.handbook/` workshop *does* need a physical
   rename (M3), and a legacy coincident host *does* need to add a declaration (M6). Neither is a
   no-op.
4. **`records.sh` is behaviorally untouched by this feature** *(reversed 2026-08-18 after review;
   scoped in round 3 — S5 edits its `agent-doctrine` comments at `:70,77`, nothing else)* — it derives
   its root from its own install location. Its reserved list keeps all four names.
5. **`.handbook/` becomes `<agent-workspace>/doctrine/`**; `context.sh` stays nested inside it.
6. **Atomic retirement of `agent-doctrine`, no fallback window.** *Risk consciously accepted* — see
   M2. The `:226-228` removal is **required**, not optional.
   **Re-affirmed in round 3 against a proposed one-cycle deprecation shim** (resolve a declared
   `agent-doctrine:` for one release, printing a notice — modelled on the `records-root:` alias).
   Rejected, and the reason is mechanical rather than a preference: **a shim and check 16 are
   mutually exclusive.** Check 16 is an unconditional textual absence guard over `skills/` — it is
   what converts "the variable is retired" from an assertion into a verifiable fact, and it is this
   feature's principal verification win. A shim requires the resolution literal to keep existing
   somewhere the guard would have to be taught to ignore, which reintroduces exactly the
   edge-gated, exemption-riddled shape that made check 14 unable to prove anything repo-wide. The
   population claim (one deployed workshop, the author's) was independently re-verified in round 3;
   no `.handbook` tree exists anywhere else on this machine.
7. **Workflows stay station-scoped**; no top-level `workflows/` *(agent, from evidence)*.
8. **No legacy alias for `agent-workspace`**; `agent-workspace: .` is forbidden.
9. **The edge type stays `doctrine`** *(agent)*.
10. **Naming is closed** — five candidates burned; see the table.
11. **`agent-templates` is OUT OF SCOPE — feature 3b** *(split 2026-08-18, human, on review
    evidence)*. This feature must not touch `records.sh:180`, the mint scripts, `analyst`,
    `backlog`, or `notepad`. **Note:** S5 *does* edit `journal/scripts/records.sh` and
    `records-test.sh` — but only their `agent-doctrine` **comments**, which the census requires and
    check 16 will flag. No behavior, no reserved list, no `:180`. That is not a Decision 11
    violation.
12. **BL-26 is IN scope as an S6 tail step** *(round 3)*. The roadmap names it a Phase 1 tail step:
    `skill-builder/verbs/new.md` prescribes the resolvers new skills are scaffolded with, so until
    it is updated this feature keeps *minting* violations of the check it just installed. Cheap, and
    it belongs with the S6 tightening rather than trailing it.
13. **The two declaration guards are owned by lint check 16** *(round 3)* — forbidden
    `agent-workspace: .`, and a warning on a declared value equal to the current default. The second
    exists because M6's required migration step (`agent-workspace: dev`) is one keystroke from a
    silent no-op (`.dev`). "Reject and report" with no named owner was unenforceable; nothing else
    this feature installs can carry them.

## Grounding

Verified at spec time, not assumed:

- `records.sh:26` derives `RR` from the script's own location; `:5` header states it. `:64`/`:82`/`:70`
  carve-outs unmodified by this feature.
- `DOCTRINE.md:217-223`, `:226-228`, `:230-232`, `:236`, `:337`, rule 3 at `:395-400`, rule 5's home
  enumeration, rule 6's edge vocabulary.
- 5 consumer readers of `agent-doctrine:`; **0 writers** repo-wide (exhaustive grep, twice).
- The 15-file `agent-doctrine` carrier census — **generated, not asserted** (M5 carries the command
  and its checked-in output). Round 3 corrected its membership: `workstream/verbs/create.md` out
  (zero occurrences), `journal/scripts/tests/records-test.sh` in. Verified at `dd40010`.
- The `.handbook` literal census is **complete and fully covered by the slices** — all 25 live
  carriers under `skills/` + `README.md` + `AGENTS.md` map to a slice's `paths` (regenerated
  round 3). `clankshop/PACK.md` carries none; it is in S6 for roster prose only.
- `context.sh` holds exactly **one** `.handbook` path literal, at `:5`; `:2` is the bare word.
- Stamp-probe line numbers re-opened and corrected round 3: `debugger:40`,
  `workstream/SKILL.md:102`, `workstream/verbs/create.md:118`, `persona.md:11`.
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

### 2026-08-18 — needs-rework (round 3: the delta re-review — soundness, groundedness, skeptic, disposition audit)

Four lenses. Three returned `needs-rework`, one `approve-with-changes`. **The design is not the
problem and was not challenged** — the architecture, the split, and the decision log survived a
fourth pass. What failed, for the fourth consecutive round, is **edit-surface enumeration** — this
time inside the very census the split was drawn around.

**MUST-FIX**

1. **The 15-file census is wrong in composition** (groundedness; re-verified by the orchestrator).
   `grep -rlE 'agent[-_]doctrine' skills/` returns 15 files — but not these 15.
   `workstream/verbs/create.md` has **zero** occurrences of the term; what sits at its `:118` is a
   `.handbook/README.md` stamp literal, which belongs to M3's list, not M5's. And
   `journal/scripts/tests/records-test.sh:183` **is** a carrier (`# The agent-doctrine home defaults
   to <agent-records>/doctrine`), omitted — while `records.sh:70`, a structurally identical
   comment-only occurrence, is counted. The count is coincidentally right; the membership is not.
   *Fix:* correct the membership, state the comment-only inclusion rule explicitly and apply it
   consistently, and **paste the generated census into this spec as a checked-in artifact** — the
   roadmap's standing discipline #1 ("generate the census; do not assert it") is what four rounds of
   asserting it have now cost.
2. **Two carriers are in no slice's `paths`, so check 16 fails forever** (soundness + disposition
   audit, converged; widened from one file to two by the corrected census).
   `journal/scripts/records.sh` and `journal/scripts/tests/records-test.sh` are both under
   `skills/journal/` — neither is exempt (exemptions are `skill-builder` + pack faces) and check 16's
   glob explicitly includes `scripts/**/*.sh`. Nothing in S1–S6 ever edits them, so the unconditional
   absence check can never go green — directly contradicting the Verification table's `fails=0`
   baseline row and S6's gate. *Fix:* add both to a slice's `paths`.
3. **Check 16 lands in S2 but polices carriers not flipped until S5, with no transitional carve-out**
   (soundness). Check 14 is given exactly such a carve-out, for exactly this reason ("so the gate
   does not go red on `blueprint`/`contractor` during S3–S5"), narrowed later in S6. Check 16 gets
   none, and every ordering the spec permits puts S2 before S5 — so the trunk lint gate is red for
   the whole window. *Fix:* give check 16 the same transitional carve-out narrowed in S6, or state
   explicitly that lint may be red on trunk between S2 and S5.
4. **The Verification section's governing sentence is false** (disposition audit). Line 289 states
   *"every row below is a **lint** or **agent** proof, and says which"* — the table's `kind` column
   carries `script` on **seven of fourteen** rows. The Review history above repeats the claim. The
   rows themselves are fine (they test real shipped tools, unlike the vacuous rows round 2 killed);
   it is the claim that is wrong. *Fix:* name three kinds, in both places.
5. **Missing ordering constraint: S4 before S5** (soundness). S5's "declared-but-absent workspace"
   verification row exercises `clankshop setup`'s owner exception — machinery M6 assigns to **S4**.
   The stated constraints ("S3 before S4; S5 after S3") permit S1,S2,S3,**S5,S4**,S6, which runs that
   row against something not yet built. *Fix:* add "S5 after S4".
6. **The `.dev` no-op typo trap** (skeptic). M6 *mandates* that a legacy coincident host add
   `agent-workspace: dev` (undotted). `agent-workspace: .dev` is one keystroke away, syntactically
   valid, and a **silent no-op** — it restates the default, and the host degrades exactly as Problem 3
   describes, now via the prescribed fix rather than the bug. M1 guards `agent-workspace: .` but not
   this, which sits directly on the migration path this spec requires walking. *Fix:* flag a declared
   value equal to the current default in the `migrate.md` adopt row and/or check 16.
7. **Verification of the flagship claim is negative-only for two-thirds of the census** (soundness).
   Check 16 proves the old literal is *gone*; it cannot distinguish "correctly repointed to
   `<agent-workspace>`" from "reference silently deleted." `auditor/BOOTSTRAP.md` (five call sites),
   `workstream/flow.md`, `workstream/verbs/sync.md`, `journal/SKILL.md`, and
   `agent-council/briefs/skill-review.md` carry no positive check at all. *Fix:* add a row asserting
   the correct new literal is *present* in the remaining carriers.
8. **BL-26 is never acknowledged** (disposition audit). The roadmap names it a Phase 1 tail step —
   *"until it is updated each phase keeps producing violations of the check it just installed"* — and
   this spec names every other roadmap foundation (check 16, the rule-3 owner exception) but not this
   one. *Fix:* cover it in a slice or explicitly defer it in the Decision log.
9. **Four off-by-one stamp-literal citations** (groundedness; all four re-opened and confirmed):
   `debugger:39`→`:40`, `workstream/SKILL.md:101`→`:102`, `workstream/verbs/create.md:119`→`:118`,
   `persona.md:12`→`:11`. The last points at unrelated prose about station personas. `DOCTRINE.md:337`
   in the same family is exact, so this is a local batch error, not a uniform offset.

**NICE-TO-HAVE**

10. Line 84 cites `(M7)` for the legacy-host declaration step, which is specified in **M6** — the
    Greenfield check at line 343 attributes it correctly, so this is a slip, not a reading.
11. The `red-proof:` label is applied inconsistently: in the check-14 and check-15 rows it marks the
    *pass* clause rather than the *fail* one; the "legacy host must declare" row omits the label
    entirely. Both rows do contain a genuine red demonstration — the labelling weakens a discipline
    this doc otherwise prides itself on.
12. `agent-workspace: .` is forbidden and "reject it and report" (M1, Decision 8) with no assigned
    owner and no verification row — and the spec itself notes nothing mechanically resolves a
    front-door variable outside three state-analysis helpers.
13. S5's `does` overclaims "flip all 15" when three of the fifteen are handled in S1/S2.
14. The Ordering paragraph asserts a red-proof for S6's narrowing of check 14 with no corresponding
    Verification-table row.
15. `context.sh:2` carries the bare word "handbook", not a `.handbook/` literal (confirmed: that file
    holds exactly one `.handbook` occurrence, at `:5`). Both lines still need the rename; the
    description overstates what is at `:2`.
16. S6's `paths` lists `clankshop/PACK.md` under "remaining `.handbook` literals", but that file
    carries none — only the bare word in a roster line. Clarify which clause covers it, or drop it.
17. **Adjacent, not a defect in this spec:** `clankshop/verbs/migrate.md:58` states the records
    reserved-path set as three names, omitting `doctrine/` — a second drifted copy of the list BL-28
    already tracks for `analyst-facts.sh`. Worth a BL-28 addendum.

**Referred to the human — these touch settled decisions and are not folded unilaterally**

- **A one-cycle deprecation shim for `agent-doctrine:`** (skeptic). Decision 6 settles the *atomic*
  retirement with the risk consciously accepted on a population-of-one basis. The skeptic does not
  dispute the population — it corroborated it (no `.handbook` tree exists anywhere else on this
  machine) — but observes that Decision 8 forbids a legacy alias for the **new** variable and never
  considered a deprecation shim for the **retired** one, which is a different, cheaper, precedented
  mitigation (`records-root:` carries exactly this shape at negligible cost). A new option, not a
  re-litigation — but the human's call.
- **The variance circularity** (skeptic, its sharpest finding). `agent-doctrine` is retired for having
  a "partly prospective" variance case; `agent-workspace` is defended as clearing that bar because a
  legacy coincident host must declare it — **a case this spec's own default choice creates**. Applying
  the same test evenly is uncomfortable for the new variable. The strongest counter, which the spec
  does not currently make, is that records/doctrine coincidence-vs-separation is a genuine
  host-independent axis and the legacy host is merely its one available instance. *Fix either way:*
  make that argument, or drop the "clears the bar" sentence and defend the variable on architecture
  grounds. Decisions 1–2 stand regardless.
- **What the cheap fix concretely fails to close** (skeptic, Front 1). Decisions 1–2 are settled and
  are **not** reopened here. The separable, foldable ask: the doc rejects the one-line fix on a
  forward-looking claim ("the next feature to touch a path home re-opens this design") that names no
  such feature, while itself designating that one line as the abandonment fallback. State plainly what
  survives the cheap fix, or frame the remainder as a consistency investment rather than a
  correctness fix.

**Confirmed sound — recorded so a fifth round does not re-derive it**

- ~50 citations opened and verified exact: `DOCTRINE.md`'s full rule set (1/3/5/6/8 plus `:217-223`,
  `:226-228`, `:230-232`, `:236`, `:337`), `records.sh:5,26,64,70,82,180`, `context.sh:15,16`,
  `seed.sh:31`, `skills-lint.sh:118-123,618-639,632,660-666`, the five consumer resolution literals,
  `auditor/BOOTSTRAP.md:12,102,268,275,276`, `flow.md:56`, `sync.md:100`, `journal/SKILL.md:29`,
  `skill-review.md:33`, `migrate.md:24-26`, and the naming archaeology.
- **"5 readers, 0 writers" independently re-verified** — the only `.sh` hit repo-wide is
  `skills-lint.sh:632`, the check-14 *detector*, not a writer.
- Seed layout claims all confirmed: workflows are station-scoped, no top-level `workflows/` exists,
  `test/workflows/audit/` is not seeded, and `.dev` / `agent-workspace` are unclaimed in the repo and
  in `.gitignore`.
- **The `.handbook` literal census is complete** (regenerated by the orchestrator): all 25 live
  carriers under `skills/` + `README.md` + `AGENTS.md` map to a slice's `paths`. The other edit
  surface is sound.
- Six of the seven round-2 dispositions genuinely **executed** in the text (only #4 above is false).
  The "no-op" / "no `git mv`" claim that was overstated last round is now consistent across the
  Approach, M3, M6, Decision 3, and the Greenfield check.
- Two skeptic attacks **failed**, and the spec's position holds: the install stamp and the
  reserved-name list are pre-existing debt the doc identifies, prices, and defers rather than hides.
- `skills-lint.sh` baseline re-run at `fails=0 warns=22`, matching the Grounding claim.

**Dispositions — round 3 fold (2026-08-18, `/blueprint revise`)**

| Id | Finding | Disposition |
|---|---|---|
| F1 | Census wrong in composition | **resolved** — M5 now carries the generating command + its checked-in output; membership corrected (`create.md` out, `records-test.sh` in); comment-counts-as-carrier rule stated once and applied uniformly |
| F2 | Two journal carriers in no slice | **resolved** — both added to S5's `paths`; Decision 11 amended to record that editing their comments is not an `agent-templates` violation |
| F3 | Check 16 red for the S2–S5 window | **resolved** — check 16's absence arm ships **WARN-only** in S2 and is promoted to FAIL in S6, mirroring check 14's transitional treatment. *(Round 4 corrected this entry twice: the original fold staged the whole check rather than the one arm with a transitional population, and claimed a promotion red-proof it had not written.)* |
| F4 | "every row is lint or agent" false | **resolved** — Verification intro now names three kinds and records why the surviving `script` rows are sound; the historical round-2 bullet is left as written (reviewer prose is not rewritten) |
| F5 | S4→S5 ordering unstated | **resolved** — full constraint chain spelled out, with the S5-after-S4 edge and the counter-example ordering it excludes |
| F6, F12 | `.dev` no-op typo; `.` guard unowned | **resolved** — both folded into one mechanism: M1's two declaration guards, owned by check 16 (Decision 13), with a prose warning at M6's adopt row and a red-proofed Verification row |
| F7 | Negative-only flip verification | **resolved** — new positive-flip row asserting each carrier names the *new* literal, red-proofed so it fails where check 16 still passes |
| F8 | BL-26 unacknowledged | **resolved** — `skill-builder/verbs/new.md` added to S6's `paths`; Decision 12 records it as an in-scope tail step per the roadmap |
| F9 | Four off-by-one citations | **resolved** — corrected in M3 and M6, with a note that `create.md` belongs to the stamp list and not the carrier census |
| F10 | `(M7)` should be `(M6)` | **resolved** — corrected |
| F11 | `red-proof:` label misapplied | **resolved** — the FAIL clause is now labelled the red-proof in the check-14/15 rows; the legacy-host row gains the label it lacked |
| F13 | S5 overclaims "all 15" | **resolved** — S5 now says "the 12 remaining", naming the 3 handled in S1/S2 |
| F14 | S6 narrowing red-proof had no row | **resolved** — added as its own Verification row |
| F15 | `context.sh:2` is a bare word | **resolved** — M3 distinguishes the path literal at `:5` from the bare word at `:2`; both still need the rename |
| F16 | `PACK.md` carries no `.handbook` literal | **resolved** — S6's `paths` annotates it as roster prose |
| F17 | `migrate.md:58` reserved-set drift | **rejected** — not a defect in this spec; it is a second drifted copy of the list BL-28 already tracks. Routed to the backlog as a BL-28 addendum, which is the correct owner |
| D1 | Deprecation shim vs atomic retirement | **resolved (human, 2026-08-18)** — atomic stands; Decision 6 now records the mechanical reason (a shim and check 16 are mutually exclusive), which is stronger than the population argument alone |
| D2 | Variance circularity | **resolved (human, 2026-08-18)** — the "clears the bar" claim is **withdrawn**; the Greenfield check now states the circularity plainly and defends the variable on architecture grounds |
| D3 | Cheap-fix framing | **resolved (human, 2026-08-18)** — the Approach now states outright that the one-line fix *does* close Problem 3, and that the remainder is a consistency investment rather than a correctness fix |

**Not folded, by design:** the design itself, the naming table, and Decisions 1–5 and 7–10 were not
challenged in round 3 and are untouched.

### 2026-08-18 — needs-rework → folded (round 4: narrow delta pass over round 3's fold)

A **single** lens, scoped to the changed surface only — the generated census, slice coverage, the
check-16 staging, the four new Verification rows, the ordering edges, and an audit of round 3's own
dispositions. Commissioned because a fold is unverified content authored by the session that
reviewed it. It found four must-fix, **three of them defects the round-3 fold itself introduced.**

**Confirmed clean, independently:** the census matches a freshly-run `grep` exactly — same 15 files,
both correction claims verified by opening the files; **all 15 map to exactly one slice** (3 in
S1/S2, 12 in S5 — the arithmetic checks); no ordering cycle; and of round 3's 20 dispositions,
**18 upheld, 2 overstated, 0 false**.

**MUST-FIX, all folded in the same pass:**

1. **`records.sh` "untouched" survived in two places** — the Approach and Decision 4 — after only
   Decision 11 was scoped. Flatly contradicted by S5 editing its comments. *Fixed:* all three now
   say **behaviorally** untouched and name the comment edits at `:70,77`.
2. **Check 16's staging was applied to the whole check**, sweeping in the `agent-workspace: .`
   guard, which M1 and Decision 8 call *forbidden* and the Verification row calls *rejected*. The
   variable is new — nothing can have declared it — so that arm has no transitional population and
   no reason to soften. *Fixed:* severity is now staged **per arm**, in a table: absence
   WARN→FAIL, `.` FAIL throughout, no-op warning advisory always.
3. **"check 16's census is exhaustive" was circular** — its red-proof restated how the census was
   generated, and it duplicated the row above it. *Fixed:* replaced with a row that proves the
   **promotion** does work (same fixture WARNs under S2's check, FAILs under S6's).
4. **"the flip is positive, not just absent" claimed `kind: lint` for a check specified nowhere** —
   the exact failure class round 2 killed (a row asserted against a mechanism that does not exist),
   reintroduced by the fix for round 3's F7. *Fixed:* reclassified `agent`, scoped as an **S5
   build-time check**, with the reason a standing lint would be wrong (it would carry the frozen
   census as data and rot on the next skill added).

**Nice-to-have, also folded:** the census line lists were first-hit locators reading as exhaustive
(`auditor/SKILL.md` alone has six) — now **exhaustive, 54 occurrences**, with an explicit note that
S5 sweeps whole files; "the 5 `SKILL.md`s" named explicitly against a census holding six; the
ordering split into **required** edges versus chosen sequence; and BL-26 given its mechanism detail
(`new.md:35` does not name `agent-doctrine`, so this feature's exposure is narrower than BL-26's
full scope — the `agent-templates` half stays for 3b).

`status:` stays `open`. Round 4's own fold is one round newer than its review — the same condition
that justified commissioning it, now one level down and with a much smaller surface.
