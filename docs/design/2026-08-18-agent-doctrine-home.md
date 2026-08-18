---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `agent-doctrine` — a front-door home for project doctrine — Spec

`stream/feat` feature 2. Grounded against `1707ede`. Brainstormed and grilled 2026-08-18;
decision tree resolved (log at the foot). Awaiting human review — `status: open` until then.

Companion: `2026-08-18-handbook-skill-extraction.md` (feature 3), which this unblocks.

## Problem

Skills that read or write **project doctrine** have no shared home resolution. Records got
one in `1707ede` — the agent-records home (declared `agent-records:`, else legacy
`records-root:`, else `.records/`), with the rule that a record-writing skill resolves that
home, carries its own template, and never refuses for lack of a `journal` floor. Doctrine
never got the equivalent.

The gap splits into two populations, and the second is where the cost falls.

**One doctrine writer, improvising a home.** `auditor`'s rubric — `GUIDE.md` +
per-dimension `rules/` + `metrics.sh` — is doctrine by any reading, and its standalone
default is a hardcoded `docs/audit/`, confirmed once at setup (`auditor/SKILL.md:31`). Its
own walk says "doctrine has one home" for the workshop path (`:93`), then falls back to an
ad-hoc directory when bare.

**Three doctrine readers for whom doctrine is workshop-gated capability.**

- `debugger` consults `.handbook/test/workflows/diagnostics.md` on a workshop host. Bare, it
  emits `unstamped`, points at the clankshop onramps, and investigates through Phase 3 only
  (`debugger/SKILL.md:29-31`). **A bare project cannot have a diagnostics playbook at all.**
- `workstream`'s build lane reads `.handbook/build/workflows/feature.md`, else falls back to
  "the plan template's own structure" (`flow.md:56`).
- `blueprint` / `contractor` summon station context, else "the project's own design docs
  stand in" — a home that is not addressable.

**And the probe answers the wrong question.** Six sites across five consumer skills grep
`.handbook/README.md` for `Seeded from clankshop` to decide whether doctrine exists.
`1707ede`'s DOCTRINE rule 8 already stripped that probe of its records job, so it now gates
*only* station and playbook context — asking "is a workshop deployed?" when the real question
is "where does doctrine live, and is the piece I need in it?" Rule 8 also forbids the
tempting shortcut (*"Do not create `.handbook/` as a records side effect"*) while offering no
alternative destination.

## Goal

One resolution rule for project doctrine, owned by the framework (`skill-builder`'s portable
doctrine), resolving on any repo whether or not a workshop, `handbook`, or `clankshop` is
installed. **Done looks like:** a bare project can hold a diagnostics playbook, an audit
rubric, and a build lane at an addressable path, and a lint proves every doctrine-touching
skill resolves that path rather than hardcoding one.

## Approach

A **front-door variable `agent-doctrine:`**, defaulting to **`<agent-records>/doctrine`**,
defined and linted by `skill-builder`. Consumers resolve the home and then test for the
specific artifact they need. `handbook` (feature 3) *declares* the home rather than owning
the rule.

This is a second instance of an existing, documented mechanism, not a new one:
`DOCTRINE.md:203` *Front-door variables — one declaration, two readers* already names the
agent-records home as "the canonical example" and fixes the form.

**Why derive from the records home** rather than a flat `.doctrine/`: a brownfield host
declaring `agent-records: dev` gets `dev/doctrine` with no second declaration, and it
structurally guarantees what rule 8 asks for in prose — a bare doctrine writer can never
create `.handbook/`, because its default home is elsewhere by construction.

**Alternatives rejected.**

- *Flat `.doctrine/` default* — every brownfield host declares twice, and the
  never-create-`.handbook/`-bare guarantee reverts to prose.
- *Status quo (workshop probe)* — keeps a boolean where a path is needed, leaves auditor's
  home improvised and three readers workshop-gated, and forces feature 3 to convert consumers
  that would need converting again.
- *Give `handbook` the variable* — makes a pack member load-bearing for a framework rule, and
  every consumer would need to know handbook exists.
- *Narrower scope (home + writers only, or doctrine only)* — the readers are where the value
  is, and a variable shipped with zero live consumers is its own risk.

## Mechanism

### 1. Resolution

    <agent-doctrine> :=
      1. the first line-start `agent-doctrine:` value in <root>/AGENTS.md,
         else in <root>/CLAUDE.md                          → that repo-relative path
      2. else <agent-records>/doctrine

where `<agent-records>` resolves by the existing rule (line-start `agent-records:` in
`AGENTS.md` then `CLAUDE.md`, else legacy `records-root:`, else `.records/`).

**Invariant:** resolution never fails and never refuses. Every repo has a doctrine home,
declared or derived.

### 2. Two-level access (the rule that is easy to get wrong)

Resolving the home is not finding the artifact.

1. Resolve `<agent-doctrine>`.
2. Test for the specific artifact (`<agent-doctrine>/<path>`).
3. Present → use it. Absent → degrade **exactly as the skill degrades today with no
   workshop**.

**Never treat home-exists as artifact-exists.** `contractor` summoning "the build station"
against a doctrine home containing no station chapters must degrade, not break. `debugger`'s
existing *"consult `diagnostics.md` when that file exists"* is the model.

### 3. Bare creation

A skill declaring `produces: doctrine` **creates its own subdirectory under the resolved
home with no floor and no confirmation**, symmetric with grok's settled rule for record
writers. It must never create `.handbook/`.

Consequence to state in the docs: a first `/auditor setup` on a plain repo materializes
`.records/doctrine/audit/` — a dot-directory the user did not explicitly opt into, where
today they would get a visible `docs/audit/`. Weighed against a confirmation round-trip the
records side does not have, and a refuse-and-stop `1707ede` was built to eliminate.

### 4. Classification test (prose — a lint cannot judge it)

> **Doctrine is living, normative, undated, and never closes. Records are dated, typed, and
> closeable.**

Doctrine: an audit rubric, a diagnostics playbook, a build lane, a station chapter. Not
doctrine: a spec (a dated `design/` record), a notepad fact, an audit *report* (the
agent-records home).

### 5. Declaration — typed edges

A skill declares its relationship through the existing mechanism: `produces: doctrine` /
`consumes: doctrine` in its `## Edges` block. One coarse `doctrine` type, matching every
existing type (`spec`, `report`, `plan`, `note` are all coarse); which artifact is meant goes
in the edge's prose description.

**Known cost, accepted:** an edge-matching composer would derive a loose `auditor → debugger`
seam that is not real. Acceptable while composer matching is aspirational; revisable by
splitting the type later.

### 6. Lint (`skills-lint.sh`, next free check numbers after 13)

Following the established block idiom (`# ---- N. <label> (FAIL) ----`, iterate
`$skills_dir/*/`, exempt `skill-builder` and pack faces, emit `fail "$name: $rel:$line:
<label>"`). Checks apply **only to skills declaring a `doctrine` edge**:

| # | Label | FAILs when |
|---|---|---|
| 14 | `hardcoded doctrine home` | a doctrine-edged skill contains a literal `docs/audit`-style or `.handbook/`-rooted path in prose |
| 15 | `doctrine home not resolved` | a doctrine-edged skill has no `agent-doctrine` resolution phrase |
| 16 | `bare handbook creation` | a doctrine-edged skill's prose directs creating `.handbook/` (rule 8's prohibition, now lintable) |

**Checks 14–16 MUST skip fenced and four-space-indented blocks.** `skills-lint.sh` has **no
fence handling today** — every existing check greps raw text — so this is new machinery, and
it is not optional: `auditor`'s own SKILL.md will *document* the legacy `docs/audit/`
fallback, so a raw-text check 14 would FAIL the very skill it exists to certify. Port the
idiom already proven in `journal/scripts/records.sh:356-362` (an awk fence toggle that skips
fenced and indented alike) into a shared helper.

That omission is not hypothetical: it is **BL-20**, the trunk-red defect this stream shipped
a fix for — `records.sh check` following example links inside code blocks. Reintroducing it
one file over would be the same bug with a new name.

*Follow-up, explicitly out of scope:* the shared helper makes fence-skipping available to
checks 1–13, which all still grep raw text. Retrofitting them is its own change — capture it,
do not smuggle it in here.

### 7. Consumer changes

**Population attribution for the acceptance target below.** There are **11** live
`Seeded from clankshop` sites in `skills/`. They are not one class:

| Class | Count | Sites | Disposition |
|---|---|---|---|
| Consumer probes | 6 | `auditor:21`, `blueprint:30`, `contractor:23`, `workstream/SKILL.md:93`, `workstream/verbs/create.md:119`, `debugger:25` | **5 flip**; debugger's is **retained** (below) |
| clankshop-internal | 4 | `setup.md:37` (writes), `check.md:14` (asserts), `seed/README.md:68` (template), `seed-test.sh:38` (test) | unchanged |
| Doctrine statement | 1 | `DOCTRINE.md:304` (rule 8) | **reworded** |

So the target is **5 of 6 probe sites flipped**, not "11 → 0" — the other six are a
different class and this feature deliberately does not touch them.

- **`auditor`** — home becomes `<agent-doctrine>/audit/` for new setups; **legacy
  `docs/audit/` detection retained**, exactly as `records-root:` remains accepted alongside
  `agent-records:`. Nothing in the field moves. Declares `produces: doctrine`. *(Verify at
  build: its home becomes resolved rather than "confirmed once at setup" — check the setup
  walk still reads coherently.)*
- **`blueprint`, `contractor`, `workstream` (×2)** — probe replaced by two-level resolution;
  their "point at the clankshop onramps" branches restructure, since a missing workshop no
  longer implies missing doctrine. Each declares `consumes: doctrine`.
- **`debugger`** — the diagnostics playbook read flips to home resolution; declares
  `consumes: doctrine`. **The stamp probe is retained for one job only:** gating Phase 4.
  Phase 4 is already human-gated (`:62`, `:103` — "starts only after the human confirms the
  root cause and that a fix is wanted"); the workshop gate is a second, independent gate
  expressing a policy (do not apply fixes on a project that has not opted into a workshop).
  Two probes, two distinct questions — *is a workshop assembled* is policy, *where is
  doctrine* is location, and they were only ever conflated by accident.

### 8. Folds

- **`DOCTRINE.md:304` (rule 8)** currently reads that the stamp "still picks handbook,
  station context, and playbooks." After this feature it picks none of those — only workshop
  policy (debugger's Phase 4) and clankshop-internal provenance. Reword with the mechanism
  ("fix the doctrine, not just the tool", `DOCTRINE.md:61`).
- **`journal/SKILL.md:28`** — `doctrine` joins the reserved never-scanned entries.
  `records.sh check` ignores it and asserts nothing about it (asserting would be journal
  reaching across a seam).
- **The distinction must be stated where the default path contradicts it:** the records
  **home** is a directory that may host sibling layers; the records **layer** is the eight
  typed stores. Without that sentence, `<agent-records>/doctrine` argues against the rule
  that `.records` is work output and `.handbook` is doctrine.
- **`agent-templates`** — unchanged. Doctrine-owned templates resolve under the existing
  templates home, skill-namespaced. One templates home, no proliferation.

## Verification

**Gate:** `bash skills/skill-builder/scripts/skills-lint.sh` → `fails=0` (baseline
`fails=0 warns=22`; warns must not increase), plus `bash
skills/skill-builder/scripts/tests/run.sh`, `.../journal/scripts/tests/run.sh`,
`.../clankshop/scripts/tests/run.sh`, `.../analyst/scripts/tests/run.sh`.

**The lint fixture — `skills/skill-builder/scripts/tests/lint-doctrine-consumer-test.sh`**,
mirroring `lint-records-writer-test.sh`: a throwaway library in `mktemp -d`, one fixture
skill, nothing touching the library's own tree. **Every check gets both proofs** — this is
the part that makes the suite trustworthy:

- **Red-proof** — plant the breakage (a hardcoded `docs/audit/` path; a doctrine edge with no
  resolution phrase; prose directing `.handbook/` creation) and assert the specific
  `FAIL: <name>: <rel>:<line>: <label>` string appears.
- **Green-proof** — plant the *correct* text and assert the label does **not** appear. This
  is what catches an over-matching pattern, and `lint-records-writer-test.sh` runs it for
  every check it owns.
- **Negative-scope proof** — a fixture skill with **no** doctrine edge and a hardcoded path
  must **not** fire checks 14–16 (they are edge-scoped).
- **Fence-proof** — a doctrine-edged fixture whose hardcoded path appears **only inside a
  fenced block** (and a second inside a four-space-indented block) must **not** fire check
  14. Without this proof the fence-skipping is unverified, and BL-20 is the record of what
  that costs.

**Resolution proof** — a fixture repo exercising all three arms: declared `agent-doctrine:`
wins; absent declaration derives from a declared `agent-records:`; both absent derives
`.records/doctrine`. Plus the two-level case: home present, artifact absent → the consumer
degrades rather than erroring.

**Doctrine: no check is trusted until it FAILs on deliberately-broken input.** A verification
grep is not evidence.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | The `agent-doctrine` section in DOCTRINE.md — variable, resolution, two-level access, bare creation, classification test, typed-edge declaration. No behavior change. | `skills-lint.sh` → `fails=0` | `skills/skill-builder/docs/DOCTRINE.md` |
| S2 | Fence-skip helper (ported from `records.sh:356-362`) + lint checks 14–16 + `lint-doctrine-consumer-test.sh` (red, green, negative-scope, fence proofs); wire into `run.sh`. | fixture FAILs on planted breakage **and** stays green on fenced examples; `tests/run.sh` green | `skills/skill-builder/scripts/skills-lint.sh`, `scripts/tests/lint-doctrine-consumer-test.sh`, `scripts/tests/run.sh` |
| S3 | Writer flip: `auditor` home resolution + legacy fallback + `produces: doctrine`. | `skills-lint.sh`; auditor's own suite if present | `skills/auditor/SKILL.md`, `skills/auditor/BOOTSTRAP.md` |
| S4 | Reader flips: `debugger` (playbook resolves; stamp retained for Phase 4), `workstream` ×2, `blueprint`, `contractor` — each declaring `consumes: doctrine`. | `skills-lint.sh`; resolution proof | the five skills' `SKILL.md` + `workstream/verbs/create.md` |
| S5 | Folds: rule 8 rewording, `journal` reserved entry, the home-vs-layer sentence. Full gate. | all four suites + `skills-lint.sh` | `skills/skill-builder/docs/DOCTRINE.md`, `skills/journal/SKILL.md` |

Sequencing note: S1 before S2 (the lint keys on doctrine the section defines); S2 before
S3/S4 (checks exist before the skills they check); S5 last (rule 8 only becomes wrong once
the readers have flipped).

## Decision log (settled 2026-08-18, human)

| Decision | Resolution |
|---|---|
| Variable + default | `agent-doctrine:`, default `<agent-records>/doctrine` (derived) |
| Owner | `skill-builder` (framework), not `handbook` or `clankshop` |
| `handbook`'s relationship | *declares* the home; does not own the rule |
| `handbook`'s pack tier | **`required:`** — `/clankshop setup` hard-stops without it, exactly as it does without `journal`. Distinct from the framework claim: the rule still resolves with no handbook installed |
| Resolution | Two-level: home, then the artifact; degrade, never break |
| Scope | Home + writers + **readers** |
| Declaration | Typed edges, one coarse `doctrine` type |
| `auditor` migration | Legacy `docs/audit/` fallback retained; no field migration |
| `debugger` Phase 4 | Keeps the stamp probe for that gate alone |
| Bare creation | Permitted, no floor, no confirmation, symmetric with record writers |
| `journal` | `doctrine` joins the reserved list; `records.sh check` asserts nothing |
| `agent-templates` | Unchanged |
| Declaration site | `AGENTS.md`, then `CLAUDE.md` |

## Risks

- **Doctrine nested under the records home reads against the distinction it encodes** —
  mitigated by the reserved-list entry and the home-vs-layer sentence (§8), which must
  actually ship or the default path argues against the rule.
- **`agent-doctrine` and `agent-records` are coupled by the derived default** — moving the
  records home silently moves doctrine on any host that never declared `agent-doctrine:`.
  Acceptable; must be stated where hosts read it.
- **Six consumer skills change** — the second consecutive feature to rewrite these files.
  `grok` has landed, so the contention is gone.
- **This feature edits `skills/workstream/SKILL.md`, the skill driving the stream.** No
  hazard in the worktree (the harness loads from the root checkout), but the running skill
  changes when this ships.

## Review history

### 2026-08-18 — independent three-lens review — **needs-rework**

Soundness `needs-rework`, skeptic `needs-rework`, groundedness `approve-with-changes`. All
findings below were independently re-verified against the tree before being recorded (a
reviewer's claim is a claim, not a decision). Prune each entry on resolution.

**MUST-FIX 1 — the feature regresses every existing workshop host (soundness).** Resolution
(§1) has two arms: a declared line, or the derived default. **Nothing writes an
`agent-doctrine:` declaration** — verified: the string appears nowhere in `skills/`, and
`clankshop/verbs/setup.md:52` + `migrate.md:25,54` write only `agent-records:` /
`records-root:`. The skill that would declare it is `handbook`, which is feature 3 and out of
scope here. So after S4, a seeded host with real doctrine at `.handbook/test/workflows/
diagnostics.md` (verified present in `seed/`) resolves `<agent-records>/doctrine`, finds
nothing, and silently degrades — losing discovery of content that exists on disk two
directories over. This falsifies §7's "Nothing in the field moves": the bytes don't move, but
what finds them stops finding them. It also puts debugger's two gates in live disagreement —
the retained stamp says "workshop present," while home resolution says "artifact absent,"
about the same real directory. **Fix:** add a slice having `clankshop`'s `setup` and
`migrate` write `agent-doctrine: .handbook` into the door (small, in scope, closes the gap
without waiting on feature 3), and add a resolution-proof arm modelling "seeded `.handbook`,
no declaration."

**MUST-FIX 2 — check 14 is not implementable as text matching (soundness, sharpened).** §6
prescribes porting the `records.sh` fence toggle so check 14 stops failing `auditor`, which
documents the legacy `docs/audit/` path. But that path sits in **prose with inline
single-backtick spans** (`auditor/SKILL.md:31-32`, verified), and the fence toggle skips only
fenced and four-space-indented blocks — so the prescribed fix does not protect the case that
motivated it, and the fence-proof would pass while the real case fails. Sharpening on
re-verification: skills write **every** path in inline backticks, so skipping inline spans
makes check 14 match nothing, while not skipping them makes it fire on legitimate
documentation. A hardcoded path and a documented legacy path are textually identical.
**Recommended fix: drop check 14.** Check 15 (resolution phrase present) asserts the right
behavior positively and has no such problem; check 16 targets a specific prose directive.
Proving-a-negative-in-text was the wrong instrument.

**MUST-FIX 3 — the journal fold is prose against enforcement code (skeptic, reproduced).**
§8 claims "`doctrine` joins the reserved never-scanned entries. `records.sh check` ignores
it." Verified false as specced: `records.sh:73` excludes only `templates|scripts` from
`stores()`, and `:64`'s `resolve()` reserved case is only `templates/*|scripts/*|history.tsv`
— so `doctrine/` is enumerated as a typed record store and `check` demands record
front-matter on every doctrine file (the skeptic reproduced a `check: FAIL` against a
fixture). S5's path list never touches `records.sh`. Compounding it: **S3 creates
`.records/doctrine/audit/` before S5's fold**, so the spec ships a window where its own
default breaks the records gate — and no fixture plants a doctrine file under the records
root and runs `check`, so the spec's own verification would miss it. **Fix:** add the
`records.sh` case-arm edits to S5 (or a dedicated slice), move the fold **before** S3, and
add the missing fixture.

**FIX 4 — fabricated quotation (groundedness).** `debugger/SKILL.md:62-63` reads "…and that a
**fix should land**"; this spec quoted "…and that a fix **is wanted**" inside quotation marks.
That phrase occurs nowhere in the file. Also `:103` is "Human confirms → Phase 4", not the
cited sentence — the match is at `:109`. And `records.sh:356-362` stops one line short: the
four-space/tab skip is `:363`.

**FIX 5 — "moves" should be "orphans" (skeptic).** Renaming the records home does not move
doctrine: resolution recomputes, files stay put, and consumers then resolve an empty path or
mint a second doctrine tree. Stranding, not relocation, and nothing detects it. *(Note: the
existing agent-templates convention at `DOCTRINE.md:217-221` — "one `agent-records:` line
moves both homes" — appears to carry the same imprecision. Inherited, not introduced here;
worth a separate capture.)*

**FIX 6 — check 15's phrase must be pinned (skeptic).** Checks 12 and 13 match exact fixed
literals; check 15 matches "an `agent-doctrine` resolution phrase", a semantic category. S4
must author one canonical sentence and reuse it verbatim so S2 can grep a literal. This
matters more if check 14 is dropped, since 15 then carries the weight alone.

**NICE-TO-HAVE.** §7's "Consumer probes" class label includes `auditor:21`, which §5 declares
a *producer* — relabel. §7 says the onramp branches "restructure" without saying to what —
name it as a build-time open item rather than silence.

**Attacks that FAILED (recorded so they are not re-litigated).** The Problem section's
reader-gap claims were verified verbatim, not dramatized. The derived default is precedented,
not accidental coupling: `DOCTRINE.md:217-221` shows agent-templates already nests under
agent-records — though that convention is hours old and unseasoned. The 11-site inventory and
its 6/4/1 classification were independently reproduced exactly. The required-tier /
resolves-bare distinction is consistent across both documents. Alternatives were judged real,
not strawmen. Blast-radius: bundling is cheaper than the counterfactual by the codebase's own
resequencing logic. One calibration: debugger's net gain is narrower than the Problem section
implies — Phases 1–3 run identically today and Phase 4 stays stamp-gated; the gain is that
the playbook becomes consultable bare.

## Grounding

Built against `1707ede`. Verified: `DOCTRINE.md:203` (front-door variable pattern,
agent-records as canonical example); `DOCTRINE.md:304` (rule 8); `auditor/SKILL.md:31,93`
(improvised `docs/audit/` home); `debugger/SKILL.md:29-31` (bare playbook gap), `:62,:103`
(human gate on Phase 4); `flow.md:56` (workstream build-lane fallback); `journal/SKILL.md:28`
(reserved-name list); `lint-records-writer-test.sh` (fixture idiom: red-proof + green-proof
per check); `skills-lint.sh:545` (check block idiom); 11 live `Seeded from clankshop` sites,
classified in §7.
