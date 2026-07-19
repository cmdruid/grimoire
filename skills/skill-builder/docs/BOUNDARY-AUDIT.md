# Boundary audit — keeping the skills independent

The workflow behind `skill-builder check`. It verifies that each skill's `description:` routes on its
own and that cross-skill glue lives in the runbook, not scattered across leaves. It is deliberately a
**toolmaker workflow** — auditing a library's own authored skills, not something a deployed project's
workflow hub runs on itself.

Doctrine: `docs/DOCTRINE.md`'s *self-scoping descriptions*, *seams live in the runbook*, and *glue
content vs. mechanism* bullets. The authoritative seam map is whatever runbook/pack manifest the
library ships (grimoire's own is `packs/clankshop.md`).

## North star

Agents must wield these skills with **high competence**. Independence (self-scoped descriptions, no
cross-references) is the *means*; it is **gated on routing accuracy, never traded for it**. A
description is the routing surface and must route **on its own** — a bare install (skills present, no
pack deployed) has only the descriptions in context.

## The violation rubric

Flag a skill when:
1. its `description:` names a sibling skill to **defer, disambiguate, or contrast** (*"for X use
   /other"*, *"distinct from /other"*, *"peer to /other"*);
2. its `description:` carries **decision- or domain-language that duplicates another skill's job**;
3. a **body** *re-documents* another skill's protocol/seam instead of pointing at it;
4. a seam it **asserts** is **absent from the runbook's seam table** (leaf ↔ runbook drift).

**Legitimate exceptions (not violations):**
- (a) a **router** naming the mechanisms it dispatches among — it's describing its own function;
- (b) a **fragment** carrying one orientation pointer to its parent;
- a **body** operational pointer a reader needs mid-task ("land the work next") — point, don't paste.

## The workflow

1. **Inventory** the skills (`ls skills/`).
2. **Scan** each `description:` + body against the rubric.
3. **Cross-check** every asserted seam against the runbook's seam table (if the library ships one).
4. **Findings** — list each candidate with its rubric item; note allowed exceptions explicitly.
5. **Fix** — self-scope the leaf; move any real seam into the runbook (never duplicate it down).
6. **Routing-probe** (below) the thinned descriptions.
7. **Re-run** `scripts/skills-lint.sh` (check 7 flags sibling refs in descriptions) and confirm the
   residual WARNs are all documented exceptions.
8. **Report.**

## The routing-probe acceptance gate

Independence is verified, not assumed. For each pair a fix thins, write 1–2 realistic **ambiguous**
prompts + the expected target, and check routing against **only the thinned descriptions** — ideally
via a **fresh sub-agent** that cannot see the audit's reasoning. A mis-route **fails the gate**; the
fix is **sharper self-scope, never a restored cross-reference**.

Record the run (date, prompt count, pass rate, which pairs were probed) wherever the host library
keeps its own maintainer notes — this doc states the method, not one library's results.

## The mechanical backstop

`scripts/skills-lint.sh` **check 7** WARNs when a `description:` names a sibling skill via `/<sibling>`.
Facts, not verdicts: it surfaces a **candidate**; you judge it against this rubric (the router/fragment
exceptions are real, so it never FAILs). A new WARN that isn't a documented exception is a regression —
self-scope it.

**Known limitation.** Check 7 covers only *description*-level backticked `/<sibling>` refs. **Body-level
re-documentation** (rubric item 3 — a section restating a sibling's verbs/protocol/seam) has **no
mechanical backstop**; it is caught only by the manual scan (step 2). Don't over-trust a green lint for
bodies — the roster/scope-boundary rot lives there.
