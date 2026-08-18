---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# Front-door path homes — one standard for `agent-records`, `agent-templates`, `agent-doctrine` — Spec

`stream/feat` feature 2. Grounded against `1707ede`. Brainstormed, grilled, three-lens
reviewed, and **rescoped 2026-08-18 (human)** — see *Scope history*. Awaiting human review;
`status: open` until then.

## Scope history (read this before the review log)

The first draft of this spec was narrower and subtly mis-scoped: it treated `agent-doctrine`
as a single new variable and entangled the `handbook` skill's transition into the framework
rule. That produced a "transition-window regression" finding in review which **no longer
applies** — it was an artifact of the mis-scoping, not a defect in the design. The corrected
scope (human, 2026-08-18):

- Three sibling front-door homes — `<agent-records>`, `<agent-templates>`, `<agent-doctrine>`
  — under **one** standardized resolution regime that `skill-builder` defines and audits.
- **Any skill that touches a home resolves it on its own**, reading or writing, with no
  dependency on any other skill being installed.
- **`handbook` has nothing to do with this.** It is an ordinary future consumer: it creates
  `.handbook`, migrates existing doctrine into it, and declares `agent-doctrine: .handbook`.
  Centralizing and formatting project doctrine is its job; owning the path concept is not.
  Nothing in this spec waits on it, writes for it, or special-cases `.handbook`.

## Problem

**One of the three homes does not exist, so doctrine gets hardcoded.** Records and templates
have front-door homes (`DOCTRINE.md:203-262`); doctrine has none, so every skill that touches
project doctrine invents a path:

- `auditor` writes its rubric (`GUIDE.md` + `rules/` + `metrics.sh`) to a hardcoded
  `docs/audit/`, confirmed once at setup (`auditor/SKILL.md:31`) — while its own walk says
  "doctrine has one home" (`:93`).
- `debugger` reads `.handbook/test/workflows/diagnostics.md`; bare, it emits `unstamped` and
  investigates through Phase 3 only (`:29-31`).
- `workstream` reads `.handbook/build/workflows/feature.md`, else "the plan template's own
  structure" (`flow.md:56`).
- `blueprint` / `contractor` summon station context, else "the project's own design docs
  stand in" — not an addressable home.

**And the two homes that do exist have no conformance standard.** Their rules are split
between the front-door-variables section and the record-writing-skills section, with no way
to ask "does this skill resolve its homes correctly?" other than reading it. `1707ede`
flipped the record writers by hand; nothing prevents the next skill from hardcoding.

**A boolean is standing in for a path.** Six sites across five skills grep
`.handbook/README.md` for `Seeded from clankshop` to decide whether doctrine exists — asking
"is a workshop deployed?" when the question is "where does doctrine live, and is the piece I
need in it?"

## Goal

One citable standard for all three front-door homes, owned by `skill-builder`: every skill
that reads or writes a home resolves it the same way, on any repo, with no other skill
installed — and `skill-builder` can **audit** conformance and report violations with the
file:line and the canonical form to use.

## Approach

Extend the existing front-door-variable mechanism with a third home and unify the conformance
rules into one auditable standard. This is deliberately **not** a new mechanism:
`DOCTRINE.md:203` already defines the pattern, the declaration form, the three readers
(agents / mint scripts / state-analysis helpers), and a canonical bash resolver. Feature 2
adds the missing home, generalizes the rules from records-only to all three, and makes them
checkable.

**`<agent-doctrine>` defaults to `<agent-records>/doctrine`.** This mirrors the accepted
precedent exactly: `agent-templates` already defaults to `<resolved-agent-records>/templates`
(`DOCTRINE.md:217-219`), so one `agent-records:` line moves all three homes and a brownfield
host declares once, not three times.

**The doctrine's own bar must be cleared.** `DOCTRINE.md:258-262` sets a high bar for adding
a front-door variable — the value must truly vary per host, the default must be right for
every fresh project, and the readers must consume it. `agent-doctrine` clears all three: it
varies (a `handbook` host puts doctrine at `.handbook`, a brownfield host under its own docs
tree), the default is right for every fresh project (nobody *must* set it), and five skills
consume it on day one. The spec states this argument explicitly rather than assuming it.

**Alternatives rejected.** A flat `.doctrine/` default — breaks the one-line-moves-all-homes
property and makes brownfield hosts declare twice. Per-skill confirmation (auditor's current
model) — does not compose, and gives each skill a different answer. No variable — leaves
doctrine hardcoded, which is the problem.

## Mechanism

### 1. The third home

    <agent-doctrine> :=
      1. the first line-start `agent-doctrine:` value in <root>/AGENTS.md,
         else in <root>/CLAUDE.md                       → that repo-relative path
      2. else <agent-records>/doctrine

with a canonical resolver mirroring `resolve_agent_records` (`DOCTRINE.md:244-253`) —
bash-3.2 safe, same precedence, printing a repo-relative path. **Invariant:** resolution
never fails and never refuses; every repo has all three homes, declared or derived.

### 2. Two-level access

Resolving a home is not finding an artifact.

1. Resolve the home.
2. Test for the specific artifact.
3. Present → use it. Absent → **degrade exactly as the skill degrades today**.

Never treat home-exists as artifact-exists. `debugger`'s existing *"consult `diagnostics.md`
when that file exists"* is the model; `contractor` summoning a station against a doctrine home
with no chapters must degrade, not break.

### 3. Own-directory standup, no floor

Generalizes record-writing rules 3 and 4 (`DOCTRINE.md:280-286`) to all three homes: on first
write, `mkdir` your own subdirectory (and the home itself if needed). Do not create another
skill's assets. A missing tool is never an error; no skill's standup is ever a precondition;
no description may claim a layer is required; no verb may refuse and send the operator
elsewhere.

Consequence to state plainly: a first `/auditor setup` on a bare repo materializes
`.records/doctrine/audit/` — a dot-directory the user did not explicitly opt into, where today
they would get a visible `docs/audit/`. Accepted, symmetric with record writers.

### 4. Which home — the classification test

A lint cannot judge this; the prose must.

> **Records** are dated, typed, closeable instances → `<agent-records>`.
> **Templates** are the schemas instances mint from → `<agent-templates>`.
> **Doctrine** is living, normative, undated, and never closes → `<agent-doctrine>`.

Doctrine: an audit rubric, a diagnostics playbook, a build lane, a station chapter. Not
doctrine: a spec (a dated `design/` record), a notepad fact, an audit *report*.

### 5. The canonical resolution phrase (pinned literal)

Checks 12 and 13 match exact fixed literals; a check matching "a resolution phrase" as a
semantic category is not implementable. So the standard **defines one canonical sentence per
home**, and conforming skills use it verbatim. S4 authors it; S3's check greps that literal.

Note this does **not** conflict with `DOCTRINE.md:223-224` ("skill prose keeps naming each
default path literally"). A conforming skill does both: it names the default path literally
*and* carries the resolution sentence.

### 6. Declaration — typed edges

`produces: doctrine` / `consumes: doctrine` in the `## Edges` block, reusing the existing
mechanism. One coarse `doctrine` type, matching every existing type (`spec`, `report`, `plan`,
`note`). **Known cost, accepted:** an edge-matching composer would derive a loose `auditor →
debugger` seam that is not real; revisable by splitting the type later.

### 7. Lint (`skills-lint.sh`, next free numbers after 13)

| # | Label | FAILs when |
|---|---|---|
| 14 | `home not resolved` | a skill declaring a home-touching edge lacks the canonical resolution literal for that home |
| 15 | `bare handbook creation` | a skill's prose directs creating `.handbook/` (rule 8's prohibition, now checkable) |

**A "hardcoded path" check was specified and then dropped** — recorded so it is not
reproposed. It is not implementable by text matching *and* it would contradict the doctrine:
`DOCTRINE.md:223-224` instructs skills to name default paths literally, so a check failing on
literal paths would fail conforming skills. A hardcoded path and a correctly-documented
default are the same bytes. Check 14's FAIL-on-absence formulation asserts the right behavior
positively and has no such ambiguity.

Because both checks are FAIL-on-absence or fixed-literal-presence, **no fenced-block handling
is required** — the earlier fence-skip requirement died with the dropped check. (`skills-lint.sh`
has no fence handling today; adding it is now a separate concern, captured, not smuggled in.)

### 8. Consumers

**Population attribution.** 11 live `Seeded from clankshop` sites in `skills/`, three classes:

| Class | Count | Disposition |
|---|---|---|
| Probes | 6 (`auditor:21`, `blueprint:30`, `contractor:23`, `workstream/SKILL.md:93`, `workstream/verbs/create.md:119`, `debugger:25`) | **5 flip**; debugger's is retained |
| clankshop-internal | 4 (`setup.md:37`, `check.md:14`, `seed/README.md:68`, `seed-test.sh:38`) | unchanged |
| Doctrine statement | 1 (`DOCTRINE.md:304`) | reworded |

The target is **5 of 6 probe sites flipped** — the other six are a different class this
feature does not touch.

- **`auditor`** (writer) — resolves `<agent-doctrine>/audit/`; **legacy `docs/audit/`
  detection retained**, as `records-root:` remains accepted. Nothing in the field moves.
  Declares `produces: doctrine`. *(Verify at build: its home becomes resolved rather than
  "confirmed once at setup" — check the setup walk still reads coherently.)*
- **`blueprint`, `contractor`, `workstream` (×2)** (readers) — probe replaced by two-level
  resolution; their "point at the clankshop onramps" branches restructure. **What they
  restructure *to* is an open build-time item**, not left silent: the intended shape is
  "resolve the home; use the artifact if present; else the existing bare fallback", with no
  onramp pointer, since a missing workshop no longer implies missing doctrine.
- **`debugger`** — playbook read resolves `<agent-doctrine>`; declares `consumes: doctrine`.
  **Retains the stamp probe for one job only:** gating Phase 4. Phase 4 is already
  human-gated (`:62-63` — "Phase 4 starts only after the human confirms the root cause and
  that a fix should land"; `:109` — "Entered only after the human confirmed the root cause and
  that a fix should land"); the workshop gate is a second, independent gate expressing policy.
  Two probes, two questions — *is a workshop assembled* is policy, *where is doctrine* is
  location.

**Transitional note (not a blocker).** Until a host runs `handbook` (feature 3) and gains an
`agent-doctrine: .handbook` declaration, a seeded workshop's readers resolve
`<agent-records>/doctrine` and degrade per §2, while its doctrine sits at `.handbook`. This is
correct behavior under the standard, not a regression to fix here: `handbook`'s migrate is the
mechanism that moves such a host, and inventing a `.handbook` fallback arm in the framework
would put back exactly the coupling this scope removed.

### 9. `records.sh` must reserve `doctrine` — code, not prose

`records.sh:73` excludes only `templates|scripts` from `stores()`, and `:64`'s `resolve()`
reserved case is only `templates/*|scripts/*|history.tsv`. So `<agent-records>/doctrine` is
enumerated as a typed record store, `check` demands record front-matter on every doctrine
file, and a doctrine path is silently accepted *as a record*. **Reproduced in review.**

This is a **code** change to `skills/journal/scripts/records.sh` (both case arms), not a
documentation fold — and it must land **before** anything creates the directory.

### 10. Folds

- **`DOCTRINE.md:304` (rule 8)** — currently says the stamp "still picks handbook, station
  context, and playbooks." After this feature it picks only workshop policy (debugger's Phase
  4) and clankshop-internal provenance. Reword with the mechanism (`DOCTRINE.md:61`).
- **`journal/SKILL.md:28`** — `doctrine` joins the reserved never-scanned entries, matching
  the script change in §9.
- **The home-vs-layer sentence** — the records **home** is a directory that may host sibling
  homes; the records **layer** is the eight typed stores. Without it, `<agent-records>/doctrine`
  argues against the rule that `.records` is work output.

## Verification

**Gate:** `bash skills/skill-builder/scripts/skills-lint.sh` → `fails=0` (baseline `fails=0
warns=22`; warns must not increase), plus the `skill-builder`, `journal`, `clankshop`, and
`analyst` suites.

**`lint-doctrine-consumer-test.sh`**, mirroring `lint-records-writer-test.sh` (throwaway
library in `mktemp -d`; nothing touches the library's own tree). Per check:

- **Red-proof** — plant the breakage (a home-touching edge with no canonical literal; prose
  directing `.handbook/` creation) and assert the exact `FAIL: <name>: <rel>:<line>: <label>`.
- **Green-proof** — plant the correct text; assert the label does **not** appear. Catches an
  over-matching pattern.
- **Negative-scope proof** — a fixture with **no** home-touching edge must not fire the checks.

**`records.sh` reserved-directory proof** — plant a doctrine file with no front-matter under
`<agent-records>/doctrine` in a fixture records root and assert `records.sh check` passes.
Red-proof: with the §9 fix reverted, the same fixture must FAIL. *This is the proof the
earlier draft was missing, and its absence is exactly why the defect survived to review.*

**Resolution proof** — three arms: declared `agent-doctrine:` wins; absent, derives from a
declared `agent-records:`; both absent, derives `.records/doctrine`. Plus two-level: home
present, artifact absent → consumer degrades rather than erroring.

**Doctrine: no check is trusted until it FAILs on deliberately-broken input.**

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | `records.sh` reserves `doctrine` (both case arms) + the reserved-directory proof with its red-proof. **First, so nothing creates a directory that breaks the gate.** | `journal` suite; fixture FAILs with the fix reverted | `skills/journal/scripts/records.sh`, `skills/journal/scripts/tests/` |
| S2 | The unified front-door-homes standard in DOCTRINE.md: third variable + resolver, two-level access, own-directory standup/no-floor generalized to all three homes, the classification test, the canonical resolution literals, the high-bar argument. | `skills-lint.sh` → `fails=0` | `skills/skill-builder/docs/DOCTRINE.md` |
| S3 | Lint checks 14–15 + `lint-doctrine-consumer-test.sh` (red, green, negative-scope proofs); wire into `run.sh`. | fixture FAILs on planted breakage; `tests/run.sh` green | `skills/skill-builder/scripts/skills-lint.sh`, `scripts/tests/` |
| S4 | Flip the five: `auditor` (writer, legacy fallback), `debugger` (playbook; stamp retained for Phase 4), `workstream` ×2, `blueprint`, `contractor` — each declaring its edge and carrying the canonical literal. | `skills-lint.sh`; resolution proof | the five skills' `SKILL.md` + `workstream/verbs/create.md` |
| S5 | Folds: rule 8 rewording, `journal/SKILL.md` reserved entry, the home-vs-layer sentence. Full gate. | all four suites + `skills-lint.sh` | `skills/skill-builder/docs/DOCTRINE.md`, `skills/journal/SKILL.md` |

Sequencing: S1 first (the substrate must tolerate the default before anything writes it); S2
before S3 (the check greps literals the standard defines); S3 before S4 (checks exist before
the skills they check); S5 last (rule 8 becomes wrong only once the readers have flipped).

## Decision log (settled 2026-08-18, human)

| Decision | Resolution |
|---|---|
| Scope | All three homes, one standard — not `agent-doctrine` alone |
| Applies to | Any skill that **touches** a home — readers and writers alike |
| Variable + default | `agent-doctrine:`, default `<agent-records>/doctrine` |
| Owner | `skill-builder` (framework) |
| `handbook`'s role | **None here.** A future consumer that creates `.handbook`, migrates doctrine into it, and declares the variable |
| `skill-builder` capability | **Audit and report** — flags non-conformance with file:line and the canonical form. It does not rewrite other skills |
| Resolution | Two-level: home, then artifact; degrade, never break |
| Declaration | Typed edges, one coarse `doctrine` type |
| Hardcoded-path check | **Dropped** — not implementable by text matching, and contradicts `DOCTRINE.md:223-224` |
| `auditor` migration | Legacy `docs/audit/` retained; no field migration |
| `debugger` Phase 4 | Keeps the stamp probe for that gate alone |
| Bare creation | Permitted, no floor, no confirmation |
| `records.sh` | **Code fix** reserving `doctrine`, landing first |
| Declaration site | `AGENTS.md`, then `CLAUDE.md` |

## Risks

- **Renaming `agent-records` orphans the sibling homes.** Resolution recomputes; files stay
  put. A host renaming `agent-records: dev` → `work` strands `dev/doctrine/…` and
  `dev/templates/…` while skills resolve the new path, find nothing, degrade — or mint a
  second, empty tree. Nothing detects it. *The existing agent-templates convention
  (`DOCTRINE.md:217-219`, "one `agent-records:` line moves both homes") carries the same
  imprecision; this spec inherits it rather than introducing it. Worth a separate capture.*
- **The nesting convention is young.** `agent-templates`-under-`agent-records` shipped hours
  ago in `1707ede`; this is its second application, with no field mileage.
- **Five consumer skills change** — the second consecutive feature to rewrite these files.
- **This feature edits `skills/workstream/SKILL.md`, the skill driving the stream.** No hazard
  in the worktree (the harness loads from the root checkout); the running skill changes at
  ship.
- **Doctrine nested under the records home reads against the distinction it encodes** —
  mitigated by §9's code fix and §10's home-vs-layer sentence, which must actually ship.

## Review history

### 2026-08-18 — independent three-lens review — **needs-rework** → dispositions below

Soundness `needs-rework`, skeptic `needs-rework`, groundedness `approve-with-changes`. Every
finding was re-verified against the tree before being recorded or actioned.

| Finding | Disposition |
|---|---|
| **MF1** — feature regresses seeded workshop hosts; nothing writes an `agent-doctrine:` declaration | **WITHDRAWN.** An artifact of the pre-rescope draft, which entangled handbook's transition into the framework rule. Under the corrected scope the transition is `handbook`'s migrate; see §8 *Transitional note* |
| **MF2** — check 14's fence-skip fix does not cover inline backtick spans, the shape that actually needs protecting | **RESOLVED by dropping the check** (§7). Sharpened on re-verification: skills write every path in inline backticks, so the check is unimplementable *and* contradicts `DOCTRINE.md:223-224` |
| **MF3** — the journal fold is prose against enforcement code; `.records/doctrine` breaks `records.sh check` | **ACCEPTED, reproduced.** Now §9, a code change, promoted to **S1** so it lands before anything creates the directory, with the missing fixture added |
| **F4** — a quotation attributed to `debugger:62` used words absent from the file; `:103` mis-cited; `records.sh` range one line short | **ACCEPTED.** §8 now quotes `:62-63` and `:109` verbatim; the stale `records.sh` range citation is gone with the dropped fence requirement |
| **F5** — "moves" should be "orphans" | **ACCEPTED**, in Risks, with the inherited-not-introduced note |
| **F6** — check 15's phrase must be a pinned literal | **ACCEPTED**, now §5 |
| **NTH** — "Consumer probes" label included a producer; reader degrade-target left unstated | **ACCEPTED.** Table relabelled "Probes"; the degrade target is named in §8 |

**Attacks that FAILED (recorded so they are not re-litigated).** The Problem section's reader
claims verified verbatim, not dramatized. The derived default is precedented, not accidental
coupling (`DOCTRINE.md:217-219`) — though that precedent is hours old. The 11-site inventory
and 6/4/1 classification reproduced exactly. The required-tier / resolves-bare distinction is
consistent. Alternatives are real, not strawmen. Bundling beats the counterfactual. One
calibration accepted: debugger's net gain is narrower than first framed — Phases 1–3 run
identically today and Phase 4 stays stamp-gated; the gain is that the playbook becomes
consultable bare.

## Grounding

Built against `1707ede`. Verified: `DOCTRINE.md:203-262` (front-door variable mechanism, the
three readers, the canonical resolver, the high bar, patient-zero rule); `:217-219`
(agent-templates nests under agent-records); `:223-224` (name default paths literally);
`:264-292` (record-writing rules, incl. own-store standup and no-floor); `:304` (rule 8);
`:61` ("fix the doctrine, not just the tool"); `auditor/SKILL.md:31,93`;
`debugger/SKILL.md:29-31,62-63,109`; `flow.md:56`; `journal/SKILL.md:28`;
`journal/scripts/records.sh:64,73` (the reserved-directory gap); `skills-lint.sh` (13 is the
highest check; no fence handling anywhere); `lint-records-writer-test.sh` (fixture idiom);
11 live stamp sites classified in §8; `agent-doctrine` occurs nowhere in `skills/` today.
