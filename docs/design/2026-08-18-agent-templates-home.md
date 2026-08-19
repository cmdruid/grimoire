---
doctype: design
status: dropped
created: 2026-08-18
updated: 2026-08-19
tags: [spec]
---

# `agent-workspace`, part 2 — the templates home — Spec

> **DROPPED 2026-08-19 — superseded by BL-34 (the simple spec + hard cut).**
>
> This spec solved the wrong problem. It *preserved* every legacy path while renaming a variable —
> adopt ladders, a brownfield probe, a carve-out kept for compat — which is how a path change came
> to cost 27 files and seven slices. The pack is in **alpha**: there is no migration to protect, so
> the legacy branches get deleted, not carried. That makes the templates move cheap and turns most
> of this document into scaffolding for a problem we don't have.
>
> **Kept only as evidence** for BL-34, and for one transferable lesson: the value question
> ("is this worth its cost?") belongs *before* the argued spec, not after the review.
>
> **What shipped instead:** `f2c5c8f` BL-28 (analyst's drifted carve-out), `1901d71` the seeded
> README's doctrine home (wrong since Phase 1), and the `checkpoint` suite's mode bit — three real
> defects that were hiding inside the refactor.

`stream/feat` **feature 3b**; roadmap **Phase 3**
(`docs/design/2026-08-18-agent-workspace-roadmap.md`). Split out of
`2026-08-18-agent-workspace-consolidation.md` on 2026-08-18 (human) after that feature's
`agent-templates` half failed **three consecutive review censuses**. Argued 2026-08-19; the four
load-bearing decisions were settled by the human that day (recorded in *Approach*).

> **Depends on Phase 1** (`agent-workspace`, default `.dev`, shipped 2026-08-19 @ `db92800`) and
> **Phase 2** (BL-25, shipped 2026-08-19 @ `18741dd`) — the latter is what makes deleting
> `records.sh`'s flat fallback safe. Both have landed; this feature is unblocked.

## Problem

`agent-templates` is the last front-door variable that **defaults inside another home**
(`<agent-records>/templates`, `DOCTRINE.md:220`). Three costs follow, and they compound:

1. **`records.sh` must carve a hole in its own store enumeration.** `records.sh:64` and `:84` skip
   `templates/` because a *sibling home* is parked inside the records home. That carve-out is the
   only thing still architectural about the arrangement — everything else about it is convention.
2. **It is a variable with no demonstrated variance case.** The bar in `DOCTRINE.md:332-336` is
   explicit: a front-door variable is justified only when the value truly varies per host. No host
   has ever declared `agent-templates:`. After Phase 1 it is the only one that cannot point to a
   brownfield reality forcing it to exist.
3. **The carrier set has never been enumerated correctly.** Four prose censuses, four wrong
   answers — the most recent being this document's own predecessor. The reason is now understood
   and is structural, not carelessness: **there are two disjoint carrier populations**, and every
   census counted one of them.

   - **Literal carriers** — files naming `agent-templates` / `<agent-templates>`:
     **61 refs across 29 files** under `skills/` (the draft claimed 50 across 24).
   - **Arrangement carriers** — files that build `<agent-records>/templates` paths and never name
     the variable: `records.sh:64,84,182`, `analyst-deploy.sh:33`, `analyst-facts.sh:81,303`,
     both mint scripts' flat probes, and six test files. **The draft listed `analyst` as a
     *literal* carrier; it is not one.** It is a pure arrangement carrier, which is exactly why
     grepping the variable name kept missing it.

## Goal

`agent-templates` ceases to exist as a front-door variable. Project templates resolve at the fixed
subpath **`<agent-workspace>/templates`**, exactly as doctrine resolves at
`<agent-workspace>/doctrine` — one `agent-workspace:` line moves both. `records.sh`'s reserved-name
carve-out demotes from architectural to legacy-compat, its flat-template fallback is deleted, and
**no existing host loses a customized template.**

## Approach

**Full retirement, symmetric with Phase 1.** Templates become a fixed subpath of the workspace, the
literal `agent-templates` becomes lint-banned, and the sanctioned-resolution-literal set
(`DOCTRINE.md:471-478`) drops from three homes to two.

    BEFORE  agent-records:   dev   -> dev/
            agent-templates:       -> dev/templates/      (nested in another home)
            agent-workspace: .dev  -> .dev/doctrine/

    AFTER   agent-records:   dev   -> dev/                (instances)
            agent-workspace: .dev  -> .dev/doctrine/      (doctrine)
                                   -> .dev/templates/     (schemas)

**Decisions settled 2026-08-19 (human), each with the argument that carried it:**

1. **Full retirement, not a re-homed default.** Rejected: keeping `agent-templates` declarable with
   its default moved to `<agent-workspace>/templates`. That is much less churn (the literal stays
   valid in all 61 places) but it preserves the variable whose lack of a variance case *is* Problem
   2, and leaves three homes to reason about where two suffice. Phase 1 already established the
   pattern — a fixed subpath under one root — and a second home under the same root costs nothing
   to explain.
2. **Delete `records.sh`'s flat-template fallback** (`records.sh:182`,
   `[ -n "$tpl" ] || tpl="$RR/templates/$doctype.md"`). Rejected: keeping it re-anchored, and
   keeping it as legacy-compat. The decisive argument is one no prior round made: **ladder step 2
   — the legacy-flat *adopt* probe — already serves the exact same brownfield population, and
   serves it correctly**, by copying the file into the lock-in home before use. The fallback
   silently *skips* that lock-in copy. It is therefore not benign compatibility but a worse
   duplicate of a path that already exists, and it reintroduces the drift check 17 was built to
   prevent. Phase 2 proved no live caller reaches it; check 17 keeps a new one from re-arming it.
   Accepted cost: a human hand-typing `records.sh new plans --title "x"` at a brownfield host now
   gets `no template for doctype 'plans'` instead of a mint.
3. **Rename the mint scripts' positional parameter** `<agent-templates>` → `<templates-home>`.
   Under decision 1 this is forced rather than optional: the extended lint bans the literal, so a
   usage string reading `<agent-templates>` would fail its own gate. The argument is a resolved
   path, so the new name states what it actually is.
4. **`standup.sh` gains `--workspace <rel>`**, mirroring its existing `--records-root <rel>`. The
   verb holds the judgment and resolves both homes; the script stays resolver-free and uses the
   value only to fill the records README's prose. Rejected: naming the default literally, which
   seeds a README that is wrong on day one at any host declaring a non-default `agent-workspace:`.

**Three of the draft's six open questions were settled by evidence, not preference:**

- **The legacy-flat adopt probe stays anchored at `<agent-records>/templates/`.** It probes
  *history*. Re-anchoring it to the workspace would point it where legacy files have never been.
- **The reserved-name list stays unconditional**, demoted in rationale only. `DOCTRINE.md:412`
  instructs hosts not to delete the old flat file, so `<agent-records>/templates/` survives **by
  design**; the moment `stores()` stops skipping it, `records.sh check` FAILs on those hosts
  forever.
- **The census is generated, not asserted** (slice 0). Twice proven: 3a's census was right only
  once a lint produced it, and Phase 2's check 17 found a carrier BL-25 had missed.

### Consequences the draft did not reach

Chasing decision 1 surfaced four branches no prior round had opened. Two are correctness defects
that full retirement *introduces* if unhandled.

**C1 — orphaned host customizations (a defect, not a nicety).** The ladder's step 1 resolves
`<agent-templates>/<skill>/<file>`; today that is `.records/templates/backlog/bugs.md`, after
retirement `.dev/templates/backlog/bugs.md`. Step 2 probes only the **flat**
`<agent-records>/templates/<doctype>.md`. So a host that has *customized*
`.records/templates/backlog/bugs.md` — the entire point of the lock-in copy — would be silently
orphaned and re-seeded from the bundled template. `analyst-deploy.sh`'s own header forbids exactly
this ("silently replacing it would discard the customization this deploy exists to enable"), and
`DOCTRINE.md:463-465` calls a re-run that clobbers host customizations "the rule that actually
matters." **Fix: the adopt ladder gains a previous-home probe** (Mechanism step 3.2).

**C2 — the rule's own name carries the banned literal.** The resolution ladder is called *"the
agent-templates rule"* throughout the library, including in non-exempt skills and in check 17's
own FAIL message. Under decision 1 those occurrences would fail the extended lint. **The rule is
renamed "the project-templates rule"**, matching the `## Project templates` SKILL.md heading the
doctrine already uses for the same set.

**C3 — `analyst` needs a second resolver.** `analyst-deploy.sh:15-23` and `analyst-facts.sh`
inline `resolve_records_root`. Their template destination moves to the workspace, so they need
`resolve_agent_workspace` beside it. This also lands **BL-28**: `analyst-facts.sh:75-81`
(`each_record`'s comment plus its `grep -v`) carries a second copy of the reserved-name carve-out
that has **drifted** from `records.sh:84` — it skips `templates/` and `scripts/` but **omits
`doctrine/`**, so a doctrine file under the records home would be miscounted as a record.

**C4 — one target-class carrier is invisible to the gate.** `skill-builder/verbs/new.md:35-36`
instructs `new` to inline the retired resolver, so left unfixed it keeps minting *new* skills
carrying the retired variable. It sits under `skill-builder`, which check 16 arm (a) exempts by
name. It must be fixed by hand and verified by hand; the lint cannot catch it. This is stated here
so the gate's blind spot is a known fact rather than a discovered one.

## Mechanism

**Invariant threaded through every step: one batch, one home.** Finding 7's sequencing hazard is
that `backlog`/`notepad` mint into `.records/templates/` while `journal`/`analyst` deploy to
`.dev/templates/` — a silent divergence of precisely the shape Phase 1 exists to fix. Every writer
flips in a single slice (S3), and S6 proves convergence with a fixture that exercises two
independent writers and asserts one home.

1. **Doctrine (`skill-builder/docs/DOCTRINE.md`).** Delete `resolve_agent_templates()` (`:301-311`)
   and the sibling-home paragraph (`:217-225`) including the `agent-templates: schemas` example.
   Rule 5's sanctioned set (`:471-478`) becomes two homes, `agent-records` and `agent-workspace`.
   The angle-bracket form for templates is **`<agent-workspace>/templates`**, mirroring
   `<agent-workspace>/doctrine`. DOCTRINE.md retains the retired literal only where it *documents*
   the retirement (it is lint-exempt by name, as it was for `agent-doctrine`).

2. **Rename the rule** (C2): "the agent-templates rule" → "the project-templates rule", everywhere
   including check 17's FAIL message and that message's assertions in
   `lint-records-writer-test.sh`.

3. **The resolution ladder** (`DOCTRINE.md:404-414`) becomes four steps, per declared project
   template `<file>`:

   1. `<agent-workspace>/templates/<skill>/<file>` present → use it (incumbent; never overwrite).
   2. **(new — C1)** Else `<agent-records>/templates/<skill>/<file>` present (the *previous* home,
      skill-namespaced) → copy to the new path, then use it. Applies to **all** lock-ins, not only
      store-named ones. Do not delete the old file.
   3. Else, **only for store-named lock-ins**, `<agent-records>/templates/<doctype>.md` present
      (legacy flat) → copy to the new path, then use it. Do not delete the old file. Body scaffolds
      skip this step.
   4. Else copy the bundled `templates/<file>` to the new path, then use it.

   Step 2 is ordered **above** step 3 deliberately: a host with both a customized skill-namespaced
   file and a legacy flat one must adopt the customized one.

4. **Mint scripts.** `backlog/scripts/record-mint.sh` and `notepad/scripts/note-mint.sh`: rename
   positional arg 2 to `<templates-home>` in usage strings, comments, and the local (`$at` → `$th`);
   implement ladder step 2 in `resolve_template` / `resolve_notes_template`. Behavior for a
   greenfield host is unchanged. Their callers — `backlog`'s five verbs, `notepad`'s two, plus both
   `SKILL.md`s — pass the workspace-resolved path and name it by the new contract.

5. **`records.sh`** (`journal/scripts/records.sh`): delete the `:182` fallback line (decision 2).
   **Keep** `:64` and `:84`, re-commented from architectural carve-out to **legacy-compat**: they
   exist for flat survivors at brownfield hosts, not because a home lives there.

6. **`analyst`** (C3): `analyst-deploy.sh` and `analyst-facts.sh` inline `resolve_agent_workspace`;
   `DEST` / `deployed` become `<agent-workspace>/templates/analyst`. `analyst-deploy.sh` adopts a
   pre-existing `<agent-records>/templates/analyst/<file>` rather than re-seeding bundled (C1's
   analogue for a non-mint deployer). `analyst-facts.sh:76-81`'s drifted carve-out is reconciled
   with `:81` and gains `doctrine/` (**BL-28**).

7. **`standup.sh`** (decision 4): add `--workspace <rel>` (default `.dev`), used only to fill the
   records README prose — templates live in `<agent-workspace>/templates/<skill>/`, not under the
   records home. Its own header comment (`:12-13`) updates to match.

8. **`skill-builder/verbs/new.md`** (C4): the scaffold instruction stops teaching the retired
   resolver. Hand-fixed, hand-verified.

9. **Lint** (`skill-builder/scripts/skills-lint.sh`): check 16 arm (a)'s pattern extends to
   `agent[-_]templates|AGENT_TEMPLATES`. It ships at **FAIL** immediately, not staged through WARN
   as the `agent-doctrine` arm was — that staging existed because carriers were flipped across a
   multi-day window; here the flip and the check land in one batch, so there is no transitional
   population to protect.

**Greenfield check — which of these mechanisms would not exist in a from-scratch build?** Three:
ladder step 3 (the flat legacy probe), the `records.sh:64,84` carve-out, and ladder step 2 itself.
All three are shaped by brownfield substrate rather than by the design. The honest question is
whether that substrate is real or imagined — and here it **is** real: this library has live
consuming projects, including legacy hosts onboarded with their records root declared in place at
`dev/`. So all three are **pay-the-debt**, not design-around; deleting them would break hosts that
exist today. Ladder step 2 is additionally self-limiting — it is a *migration* path, and once every
host has moved it becomes dead code that a later phase can drop. Record that as a future prune, not
as a reason to skip it now.

**Unchanged, and deliberately so:** the mint scripts still `mkdir -p` their own
`<templates-home>/<skill>/` on first lock-in copy. That is required by the record-writing rules
and is not affected by which root the home hangs from.

## Verification

**Numeric acceptance, with population attribution.** Total literal refs under `skills/`: **61
across 29 files**. Of these, `skill-builder/docs/DOCTRINE.md` (15) and
`skill-builder/scripts/skills-lint.sh` (4) legitimately *retain* the literal — they document and
ban it respectively — and are excluded by the check's own name-based exemption. The target class is
therefore **42 refs across 27 files**, split by who can measure it:

- **41 refs / 26 files / 10 skills** (`agent-council`, `analyst`, `auditor`, `backlog`, `blueprint`,
  `contractor`, `debugger`, `journal`, `notepad`, `workstream`) → **0**, measured by check 16 arm (a).
  No carrier is a pack face, so none is exempt for that reason.
- **1 ref** (`skill-builder/verbs/new.md`, C4) → **0**, hand-verified; structurally invisible to the
  check.

Gates, all required:

1. **Eight suites green** — enumerated from disk, not from memory:
   `skills/{agent-council,analyst,backlog,checkpoint,clankshop,journal,notepad,skill-builder}/scripts/tests/run.sh`.
   Note `contractor` and `debugger` carry literals but ship **no** suite, so their edits are covered
   by the lint gate alone.
2. **`skills-lint.sh fails=0`.** Warn counts are checkout-specific (22 from a worktree, 7 from the
   root) and are not a gate.
3. **The extended arm is red-proofed, with the break asserted as applied** (BL-33): count the target
   occurrences before and after the deliberate break and fail loudly on zero replacements, then
   restore from backup and confirm byte-identity. A break that silently fails to apply is
   indistinguishable from a passing proof, and this trap has now fired twice in two features.
4. **Brownfield fixture — legacy-flat survivor.** A host with `.records/templates/plans.md` and no
   workspace templates still passes `records.sh check` after the flip. Proves the reserved-name
   demotion did not become a deletion. **Red-proof:** drop `templates` from the `records.sh:84`
   skip list and show the fixture FAILs — otherwise this gate passes just as happily against a
   `records.sh` that never had a carve-out at all.
5. **Migration fixture — customized template survives (C1).** Stand up a host with a *customized*
   `.records/templates/backlog/bugs.md`, run the flip, and assert the customization is present at
   `.dev/templates/backlog/bugs.md` and that the old file still exists. Red-proof it by removing
   ladder step 2 and showing the customization is lost.
6. **Convergence fixture (finding 7).** One fixture project, two independent writers — a `backlog`
   mint and an `analyst` deploy — land in the **same** templates home. Red-proof by reverting either
   writer to the records home and showing the assertion fails.
7. **Deletion proof for `records.sh:182`** — the bare form exits non-zero with
   `no template for doctype`, and every shipped caller still mints. Phase 2's
   `records-test.sh` section already stands this up against a cut fixture; it converts from
   simulating the cut to asserting the real absence.

## Slices

Ordered; S3 is deliberately one slice because splitting it is finding 7's hazard.

| id | what | verify | paths |
|---|---|---|---|
| **S0** | The census tool: a checked-in script enumerating both carrier populations. **It is not redundant with S1** — check 16 arm (a) can only ever see the *literal* population, and the arrangement carriers (which have no literal to grep) are precisely the ones four prose censuses missed. S0 is the only mechanical view of that second axis. | script runs; output matches the 61/29 literal set + the arrangement set recorded above | `skills/skill-builder/scripts/` |
| **S1** | Extend check 16 arm (a) to the `agent-templates` literal; rename the rule (C2) in check 17's message. Run red against the pre-flip tree — **this enumerates S3's carriers mechanically.** | arm FAILs listing 26 files; red-proof per gate 3 | `skills/skill-builder/scripts/skills-lint.sh`, `scripts/tests/lint-*-test.sh` |
| **S2** | Doctrine: resolver deletion, sibling paragraph, sanctioned set, the four-step ladder, the rule rename. | `fails=0` for skill-builder's own suite | `skills/skill-builder/docs/DOCTRINE.md`, `skills/skill-builder/verbs/new.md` |
| **S3** | **The writers, one batch:** both mint scripts (rename + ladder step 2), their callers (backlog ×5 verbs + SKILL.md, notepad ×2 + SKILL.md), `analyst` deploy/facts + BL-28, `standup.sh` + `--workspace`, and the remaining prose carriers in `contractor`, `journal`, `workstream`, `debugger`, `blueprint`, `auditor`, `agent-council`. | check 16 arm (a) → 0; suites green | the 26 files S1 enumerates, **plus** the arrangement carriers only S0 can see — `analyst-deploy.sh`, `analyst-facts.sh` — and the test files that break with them (per BL-29: a slice's paths must include every file its own change *breaks*, not only those it means to edit) |
| **S4** | Delete `records.sh:182`; re-comment `:64`/`:84` as legacy-compat; convert `records-test.sh`'s cut-fixture section to assert the real absence. | gates 4 and 7 | `skills/journal/scripts/records.sh`, `scripts/tests/records-test.sh` |
| **S5** | Migration fixture (gate 5) — customized template survives, red-proofed. | gate 5 | `skills/backlog/scripts/tests/`, `skills/notepad/scripts/tests/` |
| **S6** | Convergence fixture (gate 6) — two writers, one home, red-proofed. | gate 6 | `skills/clankshop/scripts/tests/` |

## Review history

### 2026-08-19 — self-review (author-administered; NOT an independent `review`)

Recorded honestly: the `review` verb calls for a second set of eyes, and this pass was run by the
spec's author. It is `spec` step 4's self-review carried to full depth, not a verdict. Four defects
found and folded before any cut existed:

- **`analyst-facts.sh:76-81` mis-cited.** The prose claimed a "second, drifted copy" reconciled
  "with `:81`" — incoherent, since `:81` *is* inside that span. Corrected to `:75-81` with the
  actual drift stated: it omits `doctrine/` from a carve-out `records.sh:84` includes.
- **A fabricated gate list.** "Eight suites" named `contractor` and `debugger`, neither of which
  ships one; the real eight include `agent-council` and `checkpoint`. Enumerated from disk and
  corrected — this would have died at gate time, exactly the failure mode the census lesson names.
- **S3's paths were under-specified** (BL-29's lesson): they named only S1's literal carriers,
  omitting the arrangement carriers the same slice must edit.
- **Gate 4 had no red-proof**, so it would have passed against a `records.sh` with no carve-out
  at all.

An **independent** pass is still recommended before sequencing — this spec's subject has failed
four consecutive censuses, and a self-administered review structurally cannot catch what the author
did not think to check.

### 2026-08-19 — needs-rework (independent: grok, headless, read-only)

Single-seat independent review (the human chose one seat over a three-family council). 17 claims,
8 high. **Every load-bearing claim was re-verified against the tree by the orchestrator before
being accepted** — all held.

**Must-fix**

1. **Self-contradiction on `analyst`.** Problem says "the draft listed `analyst` as a *literal*
   carrier; it is not one," but `analyst/SKILL.md:98` reads "resolve `reports.md` via the
   agent-templates rule" — a literal — and this spec's own Verification lists `analyst` among the
   ten measured skills. The bullet refuted a claim the draft never made, and got the fact wrong.
   Fix: `analyst` is a **mixed** carrier (literal at `SKILL.md:98`; arrangement at `SKILL.md:27`
   and in both scripts).
2. **Check 16 arm (a) → 0 cannot prove the goal.** It measures *literal absence*, so it cannot
   distinguish "repointed to `<agent-workspace>/templates`" from "literal deleted, live path still
   on the records home." `analyst/SKILL.md:27` — "The live catalog is
   `<agent-records>/templates/analyst/`" — is exactly that shape and is invisible to the check.
   Fix: add a **positive** assertion that every live destination names `<agent-workspace>/templates`.
3. **Extending arm (a)'s regex without a new FAIL string** makes a templates hit report as a
   "retired `agent-doctrine` literal … resolve `<agent-workspace>/doctrine` instead"
   (`skills-lint.sh:756-760`). Fix: freeze a templates-specific message (or a second arm) plus its
   assertion.
4. **The `mkdir -p` sentence is wrong, not "deliberately unchanged."** `record-mint.sh:108`
   (`[ -d "$at" ] || mkdir -p "$at"`) currently materializes a directory under the **records** home,
   which the record-writing rules sanction. After the flip it materializes one under the
   **workspace**, which `DOCTRINE.md:451-455` permits only to `clankshop`. Fix: resolve who may
   create the workspace home on first lock-in, and what a mint does when it is absent.
5. **`DOCTRINE.md:357` is unowned** — "Creating `<agent-records>/templates/<skill>/` on first
   lock-in copy is required" must re-anchor to the workspace. Not named in Mechanism or S2.
6. **The `:217-225` deletion span is too wide.** `:216-218` carries the `records-root:` legacy
   synonym, which must survive. Narrow to the sibling-home sentence onward.
7. **`analyst-deploy.sh`'s degrade path breaks.** Its early exit keys on `records_layer=absent`
   (`:34-40`), but after the flip the destination is the workspace. Fix: specify the post-flip
   degrade and dest-absent test.
8. **The arrangement census is still not a checkable set.** "Never name the variable" is false of
   both mint scripts (`record-mint.sh:3`), and "six test files" is wrong — four are pure
   arrangement. Fix: S0 emits a `file:line` list splitting mixed from pure; that list *is* the
   expected output.

**Also fix**

- `journal/SKILL.md:71-72` still documents omitting `--template` as a live brownfield read —
  directly contradicted by decision 2, and named by no slice.
- `standup.sh:59-64`'s seeded README states the retired architecture ("sibling homes … default
  underneath it"). It **also** still claims *project doctrine* defaults under the records home —
  stale since Phase 1 shipped, i.e. a pre-existing residue this feature should sweep.
- "Finding 7" dangles: the numbered findings lived in the draft this spec replaced. Define the
  hazard inline. Related: `journal` is **not** a templates writer (`standup.sh` creates no
  `templates/`), so the hazard's phrasing is wrong.
- Check 17's test never asserts the rule-name phrase (`lint-records-writer-test.sh:122` is
  `c17='bare mint'`), so S1 cannot verify the rename there as claimed.
- C1's probe misses a host that *declared* `agent-templates:` elsewhere; "no host has ever
  declared" is uncited. Either cite the survey or state the accepted loss.
- S2 can land green with `verbs/new.md` unfixed — its verify cannot see the file (C4). Put the
  hand-check in S2's verify column.
- `DOCTRINE.md:412` is a constraint on the resolver, not an instruction to hosts. Re-word the cite.
