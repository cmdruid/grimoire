# `/clankshop design distill` — the collapse ritual

Hat: `roles/architect.md` — read the hat first; you operate this verb wearing that hat.

Folds accreted change-records (ADRs, plans, roadmap deltas) back into the standing spec they
describe, so the seed stays a clean present-tense source of truth as the project churns. See
`docs/DESIGN-DOCTRINE.md` § Two temporal kinds of doc for the failure mode this verb cures, and § The
durability gradient for what `distill` is allowed to touch (it writes `.handbook/design/src/<system>.md`
and, on promotion, `PHILOSOPHY.md`; never code). *(Seam: `distill` compacts the seed's own accretion;
external signal arrives as calibrator-routed improvement items, applied here as ordinary seed work.)*

## Cadence B — manual, milestone-triggered

Change-records are allowed to accrete freely during fast incremental work — that's the point of
keeping them separate from the seed (`docs/DESIGN-DOCTRINE.md` § Two temporal kinds of doc): zero
coherence tax on the forward, incremental path. `distill` is the deliberate, **user-enacted**
counter-motion, run at a milestone the human chooses — not a per-change tax, not triggered
automatically by `check`'s distill-debt signal (that signal only tells you debt exists; a human
still decides when paying it down is worth the session). Never run `distill` as a background or
scheduled step.

## Judgment-heavy, agent-assisted, human-curated

`distill` is not a mechanical merge. Reconciling a chain of decisions into one coherent present-
tense statement requires reading each change-record's actual content and judging what survived,
not just taking the most recent file. An agent does the reading and drafts the fold (Steps 1–3
below); a human makes the two calls that are irreducibly judgment, not mechanism: whether a
recurring pattern is actually a durable tenet (Step 4) and whether a seam redraw is warranted
(Step 5). Never present a distill as a done deal the human didn't review — the output is a diff to
read, not an auto-commit.

## Procedure

1. **Gather.** Collect every change-record touching the target system since its last
   `distilled_through_*` stamp (`.handbook/design/src/<system>.md` frontmatter — `none` means everything
   ever recorded for it): ADRs, plans, roadmap deltas, and any notes they link. Read the stamp
   first — this is what makes `distill` incremental instead of re-reading a system's entire
   history every time. Order what you gather chronologically; you'll need the sequence, not just
   the set, to reconcile correctly in Step 2.

2. **Reconcile the net effect.** This is the step with real judgment in it, and the one most
   tempting to shortcut. **It is not a mechanical "last record wins."** A chain collapses to its
   current endpoint only when every record in it is a *full* supersession of the one before —
   confirm that's actually true rather than assuming it, and handle the cases where it isn't:
   - **Partial supersession** — a later record overturns *one* decision of an earlier one and
     leaves the rest standing. Keep the surviving part; only the overturned piece drops.
     Mechanically diffing "latest file" against "current spec" loses this — you have to read what
     each record actually changed, not just which one is newest.
   - **Rollback** — a later record reverts to an earlier decision. The chain's *sequence* is
     N ← N+1 ← N+2, but the *net effect* is N, not N+2. Don't let recency alone decide.
   - **Parallel/independent records** — two change-records affecting the same system that don't
     supersede each other at all (different concerns, e.g. one on damage, one on cooldown). Both
     survive, folded together; don't force a false ordering between them.
   - **Decisions that live only in code or tests, never written down.** A change-record chain is
     never the complete history — some decisions were made directly in code and never got an ADR.
     `distill` must **read the current code** at the reference-architecture tier's pointers (and
     the tests exercising it) to surface these, not rely on change-records alone. A spec folded
     only from written records, when the code disagrees, is folding a *documented* history, not
     the *actual* one — treat a records-vs-code mismatch found here as a live discrepancy to
     reconcile, the same way `check`'s `drift:<sys>` flags one mechanically after the fact.

   The scars — every dead end, reversal, and superseded chain member — drop out of the reconciled
   result. They are not lost: git retains them as archaeology, and the change-records themselves
   stay in `.records/` untouched. `distill` only changes what the *standing spec* says; it never edits
   or deletes an ADR.

3. **Fold into the standing spec, present-tense.** Rewrite the affected sections of
   `.handbook/design/src/<system>.md` as though the reconciled result were designed whole, today — using
   `templates/design/system-spec.md`'s two-tier shape. The reconciled behavior, invariants, and seams go
   in **Contract**; the current implementation shape (pointer-heavy, per `docs/DESIGN-DOCTRINE.md`) goes
   in **Reference Architecture**. No "used to," "previously," "supersedes," or version-numbered
   language survives into the fold — that phrasing is a change-record's voice, not a standing
   spec's. If a passage can't be written without narrating the history, the reconciliation in
   Step 2 isn't finished yet; go back and settle what the *current* truth actually is.

4. **Promote recurring insight up the gradient — candidate signal, human decides.** If the same
   constraint or pattern shows up in the fold for **two or more systems** (this distill pass or
   across past ones), that recurrence is a *candidate signal* for a `PHILOSOPHY.md` tenet — per
   `PHILOSOPHY.md`'s own promotion rule and `docs/DESIGN-DOCTRINE.md`. It is not automatic: name the
   candidate and the systems it recurs in, and let the human decide whether it's a durable,
   project-wide constraint or a coincidence that happens to rhyme. Don't add to `PHILOSOPHY.md`
   without that human call.

5. **Re-partition if warranted.** Distillation is also the moment a system's true seams surface —
   you often can't see a subsystem's actual boundary until enough of it has accreted to show the
   pattern. If the reconciled fold reveals a coupling `MAP.md` doesn't yet record (or records
   wrong — a seam that no longer exists, or lives at a different boundary now), update `MAP.md`'s
   system index and seam graph to match. This is optional per distill pass — most passes don't
   warrant it — but check for it explicitly rather than only ever touching the one `src/<system>.md`
   file in front of you.

6. **Re-stamp.** Update `.handbook/design/src/<system>.md`'s frontmatter to the new baseline:
   `distilled_through_adr` (the newest change-record's id folded in), `distilled_through_commit`
   (the repo's current HEAD short SHA), `distilled_through_date` (today, `YYYY-MM-DD`). This is
   what makes the next `distill` pass on this system incremental (Step 1) and lets `/clankshop design health`
   compute distill-debt from a clean fact instead of re-deriving it.

## Report

Close `distill` with: the target system and the change-records gathered (Step 1, with the prior
baseline they were gathered *since*), the reconciliation call for anything non-trivial — partial
supersession, rollback, parallel records, or a code/test-only decision surfaced (Step 2, named
explicitly so the human can sanity-check the judgment), the sections of the standing spec actually
rewritten (Step 3, diff-shaped), any promotion candidate raised and left for the human (Step 4,
flagged *unactioned* until they decide), any `MAP.md` re-partition made (Step 5) or explicitly
considered and skipped, and the new baseline stamp (Step 6).
