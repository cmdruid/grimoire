---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# Front-door path homes — one standard for `agent-records`, `agent-templates`, `agent-doctrine` — Spec

`stream/feat` feature 2. Grounded against `1707ede`. Brainstormed, grilled, **two review
rounds** (three lenses each), rescoped once. Awaiting human review; `status: open` until then.

## Scope (human, 2026-08-18)

- Three sibling front-door homes — `<agent-records>`, `<agent-templates>`, `<agent-doctrine>`
  — under **one** standardized resolution regime that `skill-builder` defines and audits.
- **Any skill that touches a home resolves it on its own**, reading or writing, with no
  dependency on another skill being installed.
- **`handbook` is out of scope.** It is a future consumer: it creates `.handbook`, migrates
  existing doctrine into it, and declares `agent-doctrine: .handbook`. Nothing here waits on
  it, writes for it, or special-cases `.handbook`.

## Problem

**One of the three homes does not exist, so doctrine gets hardcoded.** Records and templates
have front-door homes (`DOCTRINE.md:203-262`); doctrine has none:

- `auditor` writes its rubric to a hardcoded `docs/audit/` bare (`:31`) and to
  `<root>/.handbook/test/workflows/audit/` on a workshop host (`:26-28`) — while its own walk
  says "doctrine has one home" (`:93`).
- `debugger` reads `.handbook/test/workflows/diagnostics.md` (`:27`); bare, it emits
  `unstamped` and investigates through Phase 3 only (`:29-31`).
- `workstream` reads `.handbook/build/workflows/feature.md`, else "the plan template's own
  structure" (`flow.md:56`).
- `blueprint` / `contractor` summon station context, else "the project's own design docs
  stand in" — not an addressable home.

**The two homes that do exist have no conformance standard — and have already drifted.**
Their rules are split across two DOCTRINE sections, and the same resolution clause is already
phrased inconsistently in the field: `auditor/SKILL.md:22` says "declared `agent-records:` or
`records-root:` (front-door `AGENTS.md`), else `.records/`" — omitting `CLAUDE.md` — while
`debugger/SKILL.md:33-34` says "in `AGENTS.md` then `CLAUDE.md`, else". Nothing catches this.
Drift is not a hypothetical risk; it is the current state.

**A boolean stands in for a path.** Six sites across five skills grep `.handbook/README.md`
for `Seeded from clankshop` to decide whether doctrine exists.

## Goal

One citable standard for all three homes, owned by `skill-builder`: every skill that reads or
writes a home resolves it the same way, on any repo, with no other skill installed.

**Enforcement is explicitly two-tier, and the spec claims no more than each tier delivers:**

- a **mechanical floor** — lint checks that catch omission and known-bad literals, and
- a **judgment tier** — the skill-review brief's existing Output-shape axis, extended to ask
  whether a skill's *procedure* actually resolves its homes.

The mechanical tier cannot verify that a skill's procedure resolves correctly; only the
judgment tier can. Earlier drafts of this spec claimed the lint would "report violations with
file:line" — see *Review history* round 2 for why that was withdrawn.

## Approach

Extend the existing front-door-variable mechanism with a third home and unify the conformance
rules into one auditable standard. Not a new mechanism: `DOCTRINE.md:203` already defines the
pattern, the declaration form, the three readers, and a canonical resolver.

**`<agent-doctrine>` defaults to `<agent-records>/doctrine`**, mirroring `agent-templates`,
which already defaults to `<resolved-agent-records>/templates` (`DOCTRINE.md:217-219`) — one
`agent-records:` line moves all three homes; a brownfield host declares once.

**On the doctrine's own high bar** (`DOCTRINE.md:258-262`: the value must truly vary per host,
the default must be right for every fresh project, the readers must consume it): readers
plainly consume it (five skills on day one) and the default is right for every fresh project.
**The "truly varies" leg is partly prospective and is flagged as such rather than asserted:**
the concrete variance case is a `handbook` host declaring `.handbook`, which is real only once
feature 3 ships. `auditor`'s `docs/audit/` is retained as a *legacy fallback* (§8), not as a
host declaring a non-default home, so it is not today's-live-variance in the way
`agent-records`' brownfield precedent was. If feature 3 does not ship, this leg weakens and
the variable is justified by the other two legs plus consistency with its siblings.

**Alternatives rejected.** A flat `.doctrine/` default — breaks one-line-moves-all-homes and
makes brownfield hosts declare twice. Per-skill confirmation (auditor's current model) — does
not compose. No variable — leaves doctrine hardcoded, which is the problem.

## Mechanism

### 1. The third home

    <agent-doctrine> :=
      1. the first line-start `agent-doctrine:` value in <root>/AGENTS.md,
         else in <root>/CLAUDE.md                       → that repo-relative path
      2. else <agent-records>/doctrine

with a canonical resolver mirroring `resolve_agent_records` (`DOCTRINE.md:244-253`) —
bash-3.2 safe, same precedence, printing a repo-relative path. **Invariant:** resolution never
fails and never refuses.

### 2. Two-level access

1. Resolve the home. 2. Test for the specific artifact. 3. Present → use it; absent →
**degrade exactly as the skill degrades today**.

Never treat home-exists as artifact-exists. `debugger`'s existing *"consult `diagnostics.md`
when that file exists"* is the model.

### 3. Standup — scoped, and incumbent-wins

Generalizes record-writing rules 3 and 4 (`DOCTRINE.md:280-286`), with two qualifications the
generalization requires:

- **Create only the derived default.** On first write a skill may `mkdir` its own
  subdirectory, and the home itself **only when the home is the derived default**
  (`<agent-records>/doctrine`). A skill must **never** create an *explicitly declared* home
  that is absent — that declaration names someone else's territory (a `handbook` host declares
  `.handbook`), and materializing it is how a skill fabricates another tool's layout. The
  standing prohibition is doctrine prose (`DOCTRINE.md` rule 8), **not** a lint check: §7
  records why "prose that directs creating `.handbook/`" is undecidable by text matching. An
  absent declared home degrades per §2.
- **Incumbent wins.** Doctrine is not mint-and-accumulate like records; it is
  **copy-bundled-then-customized**. `auditor setup` (`:84-109`) copies generic bundled `rules/`
  into the host and then runs a human decision-walk to author `GUIDE.md`/`metrics.sh`. So
  doctrine standup follows the **agent-templates** semantics — *"if present → use it, never
  overwrite"* (`DOCTRINE.md:313`) — not the records semantics. A re-run must never clobber host
  customizations. This is the behavior that actually matters for doctrine and it is stated, not
  left implicit.
- **No floor**, unchanged: a missing tool is never an error; no skill's standup is a
  precondition; no verb may refuse and send the operator elsewhere.

Consequence: a first `/auditor setup` on a bare repo materializes `.records/doctrine/audit/` —
a dot-directory the user did not explicitly opt into. Accepted, symmetric with record writers.

### 4. Which home — the classification test

> **Records** are dated, typed, closeable instances → `<agent-records>`.
> **Templates** are the schemas instances mint from → `<agent-templates>`.
> **Doctrine** is living, normative, undated, and never closes → `<agent-doctrine>`.

**This classifies *deployed* artifacts, not a skill's bundled source.** A skill's own
`seed/`- or `templates/`-style package content is package-only until deployed:
`clankshop/seed/core/INVARIANTS.md` and `auditor`'s bundled `rules/` are source that *becomes*
host doctrine when copied. Classify by where a thing lands, not where it ships from — and see
§3's incumbent-wins rule for what happens when it lands on an existing copy.

### 5. Resolution literals — a small fixed set, not one sentence

An earlier draft required "one canonical sentence per home, used verbatim." **That does not
survive contact with the target files.** Three findings:

- The existing, simpler records clause has *already* drifted across these same skills
  (`auditor:22` vs `debugger:33-34`, above) with no check catching it — evidence that a single
  byte-identical sentence will not hold across authors and contexts.
- `debugger`'s "One environment probe" section header becomes literally false once the
  doctrine read is separated from the stamp gate (§8): it becomes *two* probes. That section
  needs restructuring, not sentence insertion.
- The sentence must fit auditor's setup walk, debugger's probe section, and workstream's
  host-layout section — three different voices and altitudes.

So the standard defines a **small fixed set of acceptable resolution literals** per home, and
the lint matches any member. Precedent is exact: check 12 already matches two distinct fixed
phrases in one `grep -nF -e … -e …` (`skills-lint.sh:556-557`).

**Authored and empirically validated in S2** — the set has **three** members per home `H`:
`<H>` (the angle-bracket path form), `the H home`, and ``declared `H:` ``. Two findings from
testing it against the nine records-touching skills:

- **The angle-bracket form is the strongest member and matches 9 of 9.** Prefer it. It is a
  single token, so it cannot straddle a line wrap.
- **The phrase members require whitespace normalization across newlines.** These documents
  wrap near 95 columns, and a live skill (`analyst:104`) has "the" ending one line and
  "agent-records home." beginning the next. A naive line-based `grep -F` would FAIL a
  conforming skill purely on where its text wrapped. **Check 14 must normalize before
  matching** — this is a hard requirement, not a nicety.

All nine records-touching skills conform under the validated set, using *different* members —
which is the drift the set exists to absorb, confirmed live rather than assumed.

### 6. Declaration — typed edges

`produces: doctrine` / `consumes: doctrine` in the `## Edges` block. One coarse `doctrine`
type, matching every existing type. **Known cost, accepted:** an edge-matching composer would
derive a loose `auditor → debugger` seam that is not real.

### 7. Lint — the mechanical floor (next free numbers after 13)

**As built in S3** (two checks, not three — see the deviations below):

| # | Label | Shape | FAILs when |
|---|---|---|---|
| 14 | `doctrine home not resolved` | FAIL-on-absence, **edge-gated** | a skill declaring a `doctrine` edge carries no member of the literal set in operative prose |
| 15 | `off-home doctrine literal` | FAIL-on-presence, **unconditional** | any non-exempt skill's prose contains a known off-home literal (`docs/audit/`, `.handbook/{test,build,design,review}/…`) |

**Three deviations from this spec, decided during S3 on evidence:**

1. **Check 16 (`bare handbook creation`) was DROPPED**, for the same reason the
   hardcoded-default-path check was. The corpus contains exactly two handbook-creation lines
   (`DOCTRINE.md:339`, `workstream/SKILL.md:100`) and **both are prohibitions** — "Do not
   create `.handbook/`". There are zero directives to match, and a matcher would flag the two
   places doing the right thing. Compliant and violating text differ only by a preceding
   negation. The rule stays in doctrine prose and in the judgment tier.
2. **Check 14 is scoped to the doctrine home only.** `doctrine` is the one coarse home-typed
   edge, so it is the only home whose touchers are mechanically identifiable; records and
   templates edges are artifact-specific (`spec`, `report`, `note`…). Records/templates
   conformance stays with the existing records-writer checks plus the judgment tier. The
   *standard* still covers all three homes (S2); only this instrument is narrower.
3. **Check 15's exemption table is a seeded burn-down, not a permanent amnesty.** S3 lands
   before S5, so an unconditional check would turn the gate red on skills not yet flipped.
   The table is pre-populated with today's five and each entry is deleted as S5 flips that
   skill; an empty table is the goal state, and the table itself tracks the remaining work.

**Check 15 exists because check 14 alone is opt-in.** Check 14 only inspects skills that
*voluntarily* declared an edge; a skill that hardcodes a path and never adds the edge line is
invisible to it. Check 12 proves the lint can scan every skill unconditionally
(`skills-lint.sh:547-551`, name-based exemptions only). Check 15 restores that unconditional
net using check 12's exact shape plus a `(skill, literal)` exemption table — and §8 already
enumerates every sanctioned retained literal, so the table writes itself from this document.

**Check 14 must be anchored *and* whitespace-normalized.** It combines the three riskiest
properties — exact literal, unanchored prose, FAIL-on-absence — so a copy-edit breaks the gate
for a conforming skill (false positive), and a skill could satisfy it by merely *quoting* the
literal in a Folds note, a citation, or a fenced example (false pass). Therefore check 14
**matches only outside fenced and indented blocks** and treats quotation/citation context as
non-satisfying.

**Normalization is mandatory, not optional** (established empirically in S2 — see §5): the
phrase members wrap across lines in real skills today, so a line-based match would FAIL
conforming skills. Normalize whitespace across newlines before matching. Precedent: check 10
(`skills-lint.sh:504,508`). Preferring the angle-bracket member sidesteps the issue entirely
for skills that adopt it, but the check must still handle the phrase members correctly.

Note this reinstates fence handling for a *different* reason than the one that died with the
dropped hardcoded-path check — that rebuttal applied to that check, not to this one.

**A hardcoded-*default*-path check remains dropped**, and the reason is now stated precisely,
because an earlier draft over-extended it: `DOCTRINE.md:223-224` instructs skills to name
default paths literally, so a check FAILing on `.records/doctrine/` in prose would fail
conforming skills, and "hardcoded" vs "correctly documented default" is genuinely
indistinguishable in text. That argument covers the **canonical default** only. It does **not**
cover **off-home** literals, which are distinct strings, trivially greppable, and are exactly
what check 15 now catches.

**What the floor does not do.** Check 14 is FAIL-on-absence, so it **cannot emit a file:line**
— there is no line where a missing sentence lives. It proves "this file contains an acceptable
literal," not "this skill's procedure resolves the home." That stronger claim belongs to §11.

### 8. Consumers

**Population attribution.** 11 live `Seeded from clankshop` sites, three classes: 6 consumer
probes (`auditor:21`, `blueprint:30`, `contractor:23`, `workstream/SKILL.md:93`,
`workstream/verbs/create.md:119`, `debugger:25`); 4 clankshop-internal (`setup.md:37`,
`check.md:14`, `seed/README.md:68`, `seed-test.sh:38`) — unchanged; 1 doctrine statement
(`DOCTRINE.md:304`) — reworded. **Target: the doctrine-location use flips at 5 of 6 probe
sites**; no probe is deleted wholesale (see the carve-outs).

- **`auditor`** (writer) — resolves `<agent-doctrine>/audit/`; **legacy `docs/audit/`
  detection retained** as a sanctioned exemption in check 15's table. Declares `produces:
  doctrine`. *(Verify at build: its home becomes resolved rather than "confirmed once at
  setup" — check the setup walk still reads coherently.)*
- **`debugger`** — the playbook read resolves `<agent-doctrine>`; declares `consumes:
  doctrine`. **Retains the stamp probe solely to gate Phase 4** — already human-gated
  (`:62-63`, "Phase 4 starts only after the human confirms the root cause and that a fix should
  land"; `:109`, "Entered only after the human confirmed the root cause and that a fix should
  land"), with the workshop gate a second, policy gate. **Its "One environment probe" section
  header becomes false and must be restructured** — the section now describes two probes with
  two different jobs.
- **`workstream` — CARVE-OUT, do not replace the probe wholesale.** Its stamp probe gates
  **three** things (`SKILL.md:96-101`, verified): summoning the build station (a *doctrine
  location* question), `<debrief>` routing (`/backlog debrief` vs the project's own sweep), and
  whether queue items may be **Backlog** tracker lines. **Only the station summon flips.** The
  other two are "is a workshop assembled" policy questions — the same distinction drawn for
  debugger, and it applies here identically. Naively replacing the whole probe silently breaks
  debrief routing and tracker-mint gating.
- **`blueprint`, `contractor`** — probe's doctrine use replaced by two-level resolution. Their
  "point at the clankshop onramps" branches restructure to: resolve the home; use the artifact
  if present; else the existing bare fallback; no onramp pointer.

**Transitional note (not a defect).** Until a host runs `handbook` (feature 3), a seeded
workshop's readers resolve `<agent-records>/doctrine` and degrade per §2 while its doctrine
sits at `.handbook`. That is correct under the standard; `handbook`'s migrate is the mechanism
that moves such a host. Inventing a `.handbook` fallback arm in the framework would restore
exactly the coupling this scope removed.

### 9. `records.sh` must reserve `doctrine` — code, not prose

`records.sh:73` excludes only `templates|scripts` from `stores()`; `:64`'s `resolve()` reserved
case is only `templates/*|scripts/*|history.tsv`. Both arms are required, and they fix
**two different subcommand families**:

- via `stores()`: **`check`** (FAILs "no front-matter block" on every doctrine file) **and
  `list`** (silently emits a garbage row with every field empty).
- via `resolve()`: **`show`** (cats arbitrary doctrine prose as a record), **`touch`** and
  **`done`**. Note `touch`/`done` are *accidentally* protected today by `require_record`'s
  front-matter check — a doctrine file that legitimately carries its own YAML front-matter
  would slip through and be silently rewritten. The `resolve()` arm makes the protection
  structural rather than incidental.

`history` and `prune-candidates` are unaffected (ledger-based) and become transitively safe
once `resolve()` is fixed.

**Out of scope, captured separately:** `cmd_new` performs no reserved-name check at all —
`records.sh new templates --title X` already succeeds today. Pre-existing, not
doctrine-specific, not introduced here.

### 10. Folds

- **`DOCTRINE.md:304`** (rule 8) — reword: the stamp now picks only workshop policy and
  clankshop-internal provenance.
- **`journal/SKILL.md:28`** — `doctrine` joins the reserved never-scanned entries.
- **`journal/scripts/standup.sh:58-59`** — it *generates* a `.records/README.md` whose prose
  states that `templates/`, `scripts/`, and `history.tsv` are reserved. That generated text
  goes stale the moment `doctrine` joins the set. A third prose site, distinct from the two
  above.
- **The home-vs-layer sentence** — the records **home** is a directory that may host sibling
  homes; the records **layer** is the eight typed stores.

### 11. The judgment tier

The mechanical floor cannot verify that a procedure resolves its homes. That claim is carried
by the existing skill-review brief, which already has the right axis:
`agent-council/briefs/skill-review.md:23-24` asks, under **Output shape**, whether "the
destination is `<agent-records>/<store>/`" rather than a hardcoded fallback.

This feature **extends that axis to all three homes** and adds the question the lint cannot
ask: *does the skill's operative procedure resolve the home, or does it carry a resolution
literal while its actual steps name a fixed path?* Wired through `skill-builder review`, whose
Pass 1 currently just reruns the lint.

## Verification

**Gate:** `skills-lint.sh` → `fails=0` (baseline `fails=0 warns=22`; warns must not increase),
plus the `skill-builder`, `journal`, `clankshop`, and `analyst` suites.

**`records.sh` reserved-directory proof — both arms proven independently.** A prior review
demonstrated that a `check`-only proof **passes against a partial fix** (`stores()` patched,
`resolve()` left broken), so:

- via `stores()`: plant a doctrine file with no front-matter under `<agent-records>/doctrine`;
  `check` passes and `list` omits it. Red-proof: revert that arm → `check` FAILs.
- via `resolve()`: `records.sh show <doctrine-path>` must exit non-zero with `reserved path,
  not a record`. Red-proof: revert that arm → it exits 0 and cats the file.

**`lint-doctrine-consumer-test.sh`** (throwaway library in `mktemp -d`; nothing touches the
library's own tree). Per check: **red-proof** (planted breakage FAILs with the exact string),
**green-proof** (correct text does not fire), **negative-scope proof** (no edge → check 14
silent), plus two the earlier draft lacked:

- **Anchoring proof (check 14)** — a fixture whose only occurrence of the literal is inside a
  fenced block or a quotation/citation context must **still FAIL**. Without this, the false-pass
  path is unverified.
- **Unconditional proof (check 15)** — a fixture with an off-home literal and **no declared
  edge** must FAIL, proving the opt-in hole is actually closed; an exempted skill must not
  fire; and the canonical *default* path must never fire (it is required, conforming usage).
- **Normalization proof (check 14)** — a conforming skill whose phrase literal wraps across a
  line must **pass**. This is the live false-positive shape, not a hypothetical.

**Not verifiable mechanically, and stated as such:** "carries the literal but the procedure
still hardcodes" is the judgment tier's case (§11), not a lint case. The spec does not pretend
a fixture covers it.

**Resolution proof** — declared wins; absent derives from `agent-records:`; both absent derives
`.records/doctrine`. Plus two-level: home present, artifact absent → degrade.

**Doctrine: no check is trusted until it FAILs on deliberately-broken input.**

## Slices

| id | does | verify | paths |
|---|---|---|---|
| S1 | `records.sh` reserves `doctrine` (both arms) + the two-arm proof with independent red-proofs. **First — the substrate must tolerate the default before anything writes it.** | `journal` suite; each arm FAILs when individually reverted | `skills/journal/scripts/records.sh`, `skills/journal/scripts/tests/` |
| S2 | The unified standard in DOCTRINE.md: third home + resolver, two-level access, scoped standup + incumbent-wins, the classification test incl. bundled-source, the resolution-literal **sets**, the prospective-variance caveat. | `skills-lint.sh` → `fails=0` | `skills/skill-builder/docs/DOCTRINE.md` |
| S3 | Lint checks 14–15 + `lint-doctrine-consumer-test.sh` (red, green, negative-scope, anchoring, normalization, unconditional proofs); check 15's seeded burn-down table; wire into `run.sh`. **DONE** — 10 proofs, each check verified by disabling it. | fixture FAILs on each planted breakage | `skills/skill-builder/scripts/skills-lint.sh`, `scripts/tests/` |
| S4 | Extend the review brief's Output-shape axis to all three homes + the procedure-resolves question; wire through `skill-builder review`. | `skill-builder` suite | `skills/agent-council/briefs/skill-review.md`, `skills/skill-builder/verbs/review.md` |
| S5 | Flip the five: `auditor`; `debugger` (playbook flips, stamp retained, **probe section restructured**); `workstream` **(station summon only — debrief routing and tracker gating stay)**; `blueprint`; `contractor`. | `skills-lint.sh`; resolution proof | the five skills' `SKILL.md` + `workstream/verbs/create.md` |
| S6 | Folds: rule 8, `journal/SKILL.md`, **`standup.sh`'s generated README**, the home-vs-layer sentence. Full gate. | all four suites + `skills-lint.sh` | `skills/skill-builder/docs/DOCTRINE.md`, `skills/journal/SKILL.md`, `skills/journal/scripts/standup.sh` |

Sequencing: S1 first; S2 before S3 (checks grep literals the standard defines); S3/S4 before S5
(both tiers exist before the skills they judge); S6 last.

## Decision log (settled 2026-08-18, human)

| Decision | Resolution |
|---|---|
| Scope | All three homes, one standard |
| Applies to | Any skill that **touches** a home — readers and writers |
| Variable + default | `agent-doctrine:`, default `<agent-records>/doctrine` |
| Owner | `skill-builder` (framework) |
| `handbook`'s role | **None here.** Future consumer; creates `.handbook`, migrates doctrine into it, declares the variable |
| Enforcement | **Two tiers** — a mechanical lint floor, plus the review brief's judgment axis. The lint does **not** claim to verify procedures |
| Resolution | Two-level: home, then artifact; degrade, never break |
| Standup | Derived default only; **incumbent-wins**, never clobber |
| Declaration | Typed edges, one coarse `doctrine` type |
| Resolution literals | A small fixed **set** per home, not one sentence |
| Hardcoded-**default**-path check | **Dropped** (contradicts `DOCTRINE.md:223-224`) |
| Off-home literal check | **Kept** (check 15) — unconditional, exemption-tabled |
| `auditor` migration | Legacy `docs/audit/` retained, as a sanctioned exemption |
| `debugger` Phase 4 | Keeps the stamp probe for that gate alone |
| `workstream` probe | **Only the station summon flips**; debrief routing + tracker gating stay |
| `records.sh` | **Code fix**, both arms, landing first |

## Risks

- **Literal drift.** The records clause has already drifted (`auditor:22` vs `debugger:33-34`).
  The fixed-set approach bounds it; check 14 catches total omission, not paraphrase. Adding a
  set member must stay a deliberate edit to the standard.
- **Renaming `agent-records` orphans the sibling homes.** Resolution recomputes; files stay
  put; consumers degrade or mint a second empty tree. Nothing detects it. *The existing
  agent-templates convention carries the same imprecision; inherited, not introduced.*
- **The nesting convention is young** — `agent-templates`-under-`agent-records` shipped hours
  ago; this is its second application.
- **Five consumer skills change** — the second consecutive feature to rewrite these files.
- **This feature edits `skills/workstream/SKILL.md`, the skill driving the stream.** No hazard
  in the worktree; the running skill changes at ship.

## Review history

### Round 1 — 2026-08-18 — three lenses — needs-rework → dispositioned

Soundness and skeptic `needs-rework`; groundedness `approve-with-changes`.

| Finding | Disposition |
|---|---|
| MF1 — regresses seeded workshop hosts | **WITHDRAWN** — artifact of the pre-rescope framing; see §8 *Transitional note* |
| MF2 — fence fix misses inline backtick spans | **RESOLVED** by dropping that check (§7) |
| MF3 — journal fold is prose against enforcement code | **ACCEPTED** — now §9, code, promoted to S1 |
| F4 — fabricated `debugger:62` quotation; `:103` mis-cited | **ACCEPTED** — §8 quotes `:62-63` and `:109` verbatim |
| F5 — "moves" → "orphans" | **ACCEPTED** (Risks) |
| F6 — pin the resolution phrase | **ACCEPTED, then SUPERSEDED** by round 2 — a fixed *set*, not one sentence |
| NTH — probe label; degrade target unstated | **ACCEPTED** (§8) |

**Round 1 attacks that failed:** Problem-section claims verified verbatim; derived default is
precedented (`DOCTRINE.md:217-219`); the 11-site inventory reproduced exactly; alternatives are
real; bundling beats the counterfactual. Calibration accepted: debugger's net gain is that the
playbook becomes consultable bare — Phases 1–3 are unchanged and Phase 4 stays stamp-gated.

### Round 2 — 2026-08-18 — three targeted lenses on the new material — needs-rework → folded

| Finding | Disposition |
|---|---|
| Check 14 is **opt-in**; a skill that never declares an edge is invisible | **ACCEPTED** — check 15 restores an unconditional net (§7) |
| Phrase-present-while-procedure-hardcoded is the **median** outcome, given all five skills' identical probe-plus-Destination shape | **ACCEPTED** — §11 judgment tier + S4; verification says plainly that the lint cannot cover it |
| "audit … with file:line" is **mechanically impossible** for a FAIL-on-absence check | **ACCEPTED** — Goal rewritten to a two-tier claim; §7 states the limit |
| Dropping the hardcoded-path check **over-extended** `DOCTRINE.md:223-224` from canonical-default to off-home literals | **ACCEPTED** — §7 now separates the two classes; check 15 catches the tractable one. *(Note: the buildability lens judged the drop "sound as specified"; the two lenses disagreed, and the more specific analysis was followed.)* |
| §3 vs check 16: "create the home if needed" collides with the prohibition on creating `.handbook` | **ACCEPTED** — §3 scopes creation to the derived default only |
| §3 silent on **incumbent-wins**; doctrine is copy-then-customize, not mint-and-accumulate | **ACCEPTED** — §3 adopts agent-templates semantics (`DOCTRINE.md:313`) |
| One verbatim sentence does not fit the three target sections; the records clause has already drifted | **ACCEPTED** — §5 now a fixed set, per check 12's two-phrase precedent |
| Check 14 unanchored: copy-edit false-positive, quotation false-pass | **ACCEPTED** — §7 anchors it; fence handling returns for this distinct reason |
| **`workstream`'s probe gates three things**; only the station summon should flip | **ACCEPTED** — §8 carve-out; would have silently broken debrief routing and tracker gating |
| `debugger`'s "One environment probe" header becomes false | **ACCEPTED** — §8; restructure, not sentence insertion |
| `check`-only proof passes a **partial** `records.sh` fix | **ACCEPTED** — Verification proves each arm independently |
| §9 named only `check`; `list` is broken by the same root cause | **ACCEPTED** — §9 enumerates both families |
| `standup.sh:58-59` generates stale reserved-list prose | **ACCEPTED** — added to §10 and S6 |
| `cmd_new` has no reserved-name check | **OUT OF SCOPE** — pre-existing, not doctrine-specific; captured to the backlog |
| High-bar "truly varies" leg is prospective | **ACCEPTED** — Approach flags it rather than asserting it |
| Classification test silent on bundled source | **ACCEPTED** — §4 |

**Round 2 attacks that failed:** §1's resolver, §2's two-level access, §6's typed edges, and
check 16 were each judged sound and well-precedented. `DOCTRINE.md:223-224` genuinely does
foreclose a canonical-default-literal check — that citation was read correctly.

## Grounding

Built against `1707ede`. Verified: `DOCTRINE.md:203-262`, `:217-219`, `:223-224`, `:244-253`,
`:258-262`, `:264-292`, `:304`, `:313`, `:61`; `auditor/SKILL.md:22,26-28,31,84-109,93`;
`debugger/SKILL.md:22-31,27,33-34,62-63,109`; `workstream/SKILL.md:92-101`, `flow.md:56`;
`journal/SKILL.md:28`, `journal/scripts/records.sh:64,73`, `standup.sh:58-59`;
`skills-lint.sh:504,508,547-551,556-557,574` (13 is the highest check; no fence handling
today); `agent-council/briefs/skill-review.md:23-24`; `lint-records-writer-test.sh`; 11 live
stamp sites classified in §8; `agent-doctrine` occurs nowhere in `skills/` today.
