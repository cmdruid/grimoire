---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `analyst` — reports and briefings for the developer — Spec

_Draft weight (brainstorm output, 2026-08-18): Problem/Goal argued, Approach sketched, open
questions at the foot. `grill`/`spec` resolves them._

## Problem

The workshop's records layer is write-heavy and read-poor. A project accumulates a complete
account of its own history — the `history.tsv` closure ledger, closed plans, debrief reports,
ADRs, live trackers — but **nothing synthesizes that account for the developer**. Catching up
("what happened here since I last looked?", "what's the state of subsystem X?", "what shipped
this month and what's still open?") is manual archaeology across stores, git log, and trackers.
Every existing pack member either writes the record (journal, backlog, workstream debriefs) or
judges the code (auditor); no member reads the record back and *informs*.

## Goal

`/analyst` produces **developer-facing briefings and reports**: a catch-up briefing over a time
span, a shipped-work digest, a state-of-a-subsystem report — synthesized from the records layer
plus git history, curated and translated into readable prose. The developer asks a question about
their own project and gets an argued answer, not a pile of pointers.

## Decisions already settled (brainstorm, 2026-08-18)

- **Name: `analyst`.** Trade-role register (contractor, auditor, debugger, analyst). Settled by
  the human over `chronicler` (vetoed), herald/gazette/publisher/envoy (passed over).
- **Audience: the developer.** Inward-facing intelligence. **Release engineering is out of
  scope** — changelogs, release notes, version bumps, tagging are *user*-facing artifacts and a
  possible later skill; analyst does not carry them.
- **A new skill, not journal verbs.** Journal is the format authority; all its verbs are
  substrate-side (setup/done/curate). Every consumer of the layer is deliberately a client (the
  Phase 6 backlog split established exactly this boundary). Analyst is the first member that
  reads the records layer to *synthesize*, and its judgment (audience, salience, translation) is
  a different job from format authority. Folding it into journal would also bloat the pack's one
  `required:` member with optional functionality.
- **Routing line vs `auditor`:** **auditor judges** (scores code against a rubric, drains
  findings); **analyst synthesizes and informs** (reports state and history, renders no quality
  verdict). The `description:` must make "report on / brief me on the codebase" route to analyst
  and "how good is this code" route to auditor.

## Approach (sketch)

A **read-only consumer** of the records layer + git, structured like the pack's other
fact-then-judgment skills:

1. **Span/scope facts, token-free.** A bundled script (the `workstream-git.sh` pattern) computes
   the raw feed: ledger lines since an anchor (a date, a tag, the last briefing), closed records
   in span, tracker deltas, commit counts by area. Facts, not verdicts.
2. **Follow the links.** A ledger line is a closure fact; the substance lives in the closed
   record (plan goal, debrief report, ADR). The analyst reads what the span's facts point at.
3. **Curate + synthesize — the judgment step.** Select what the developer needs, group it, and
   translate record-speak into a readable briefing. This step is why it is a skill and not a
   `records.sh` subcommand.
4. **Deliver.** In context by default; optionally persisted as a `reports/` record (the store
   already exists and carries the contract) when the briefing is worth keeping.

**Standalone degrade** (no workshop): fall back to git history + the project's own docs — weaker
input, same synthesis job. No refusal, per the pack's standalone rule.

**Alternatives rejected:** journal verbs (boundary — above); a `records.sh report` subcommand
(steps 3–4 need judgment, not templating); folding into auditor (different job: informing vs
judging — and auditor is rubric-calibrated, analyst is question-shaped).

## Mechanism

_To be argued at spec weight — see open questions._

## Verification

_To be argued at spec weight. Candidates: fixture records tree with a planted span → briefing
must surface the planted closures and open items; routing probe for the auditor boundary;
standalone-host degrade exercised on a bare repo fixture._

## Open questions (for `grill`)

1. **Verb set.** Candidates: `brief` (catch-up over a span), `report` (deep-dive on a named
   subsystem/topic), `status` (trackers-now snapshot). One verb with modes, or several?
2. **Inputs beyond closures.** Does a briefing include *open/blocked* items (trackers, open
   records) alongside shipped work? (Leaning yes — a catch-up without "what's still open" is
   half a briefing.)
3. **Span anchors.** What does "since X" resolve from — date, git ref, last persisted briefing,
   `history.tsv` position? Does analyst remember its last run, and where?
4. **Artifact policy.** When does a briefing persist as a `reports/` record vs stay in context?
   Who decides (flag, size, human ask)?
5. **Pack tier.** Helper or utility in `PACK.md`? (Consumes the records layer like backlog —
   probably helper — but degrades standalone.)
6. **Depth dial / delegation.** Fan-out readers over stores for a large span (the route exists);
   when is that warranted?
7. **Code-reading scope.** Is a "state of subsystem X" report records-only, or does analyst also
   read the code itself? (Code-reading widens the auditor collision and the job — needs a line.)
8. **Scheduler seam.** A recurring briefing ("Monday morning catch-up") via `scheduler` is an
   obvious composition — in scope to document, or leave emergent?
