# `/skill-builder calibrate` — fold accreted authoring decisions back into `docs/DOCTRINE.md`

The same collapse-ritual shape a design-seed steward runs for a project's spec — and the same *name*
`foreman calibrate` already uses for "drain accumulated signal into doctrine" — applied to
skill-authoring itself: as design docs, ADRs, and one-off authoring decisions accrete around *how this
library builds skills*, `calibrate` folds the ones that proved durable back into `docs/DOCTRINE.md` so
it stays a clean, current reference — and marks the source records as historical rather than leaving
them to silently disagree with the doctrine they fed.

## Cadence — manual, milestone-triggered

Design docs and one-off decisions are allowed to accrete freely during fast incremental work — that's
the point of keeping them separate from the doctrine. `calibrate` is a deliberate, **human-enacted**
counter-motion run at a milestone the human chooses (a roadmap track closing, a doctrine bullet proven
across several skills), never a per-change tax and never triggered automatically.

## Judgment-heavy, agent-assisted, human-curated

Reconciling a chain of authoring decisions into one coherent doctrine bullet requires reading each
record's actual content and judging what survived — not taking the most recent file wholesale, and not
mechanically diffing. An agent does the reading and drafts the fold; a human makes the call on whether
a recurring pattern is actually a durable tenet worth stating generically (vs. a one-off that shouldn't
generalize). Never present a calibration as a done deal the human didn't review.

## Procedure

1. **Gather.** Collect design docs / ADRs / roadmap phases touching *how skills are built* since
   `docs/DOCTRINE.md`'s own last-updated point (its git history is the stamp — there is no separate
   frontmatter marker to maintain). Order chronologically.

2. **Reconcile the net effect.** Not "last record wins" — a later record may only overturn *part* of
   an earlier one (keep the rest), may *revert* to an earlier decision (net effect is the earlier
   state, not the latest file), or may be *independent* of another (both survive, no forced ordering).
   Read what each record actually changed.

3. **Draft the fold.** Update the relevant `docs/DOCTRINE.md` section(s) to state the reconciled,
   present-tense doctrine — generically, no host-library-specific paths or skill names baked in (this
   doc must stay portable). Where a source record's reasoning is worth preserving for *why*, leave the
   record in place and mark it superseded/implemented rather than deleting it — `docs/DOCTRINE.md` is
   the *what's true now*; the record stays the *why it changed*. `calibrate` may add a file under `specs/`; it does
   not fold enum tables back into `docs/DOCTRINE.md`.

4. **Human review.** Present the diff — what moved into the doctrine, what stayed a historical record,
   what (if anything) didn't survive reconciliation and why. The human confirms before it's treated as
   settled.

5. **Gate.** Run `scripts/skills-lint.sh` → `fails=0` (a doctrine-only edit is typically doc-linter
   scope, not a full script-touching gate — but re-run the full lint if any skill's `## Edges` or
   frontmatter changed as part of the fold).

## Done when

`docs/DOCTRINE.md` reflects the reconciled, current doctrine; superseded source records are marked as
historical (not deleted, not left claiming to be live); the human has reviewed and confirmed the fold.
