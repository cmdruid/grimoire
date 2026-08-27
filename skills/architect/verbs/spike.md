# `spike [draft-or-question]` — bounded feasibility evidence

Use a spike only when a design choice is blocked by material implementation uncertainty. A direct
invocation asks Architect to consider a spike; it does not authorize execution.

## Procedure

1. **Qualify read-only.** Read the named Architect draft when supplied, then inspect existing code,
   documentation, and records. Proceed only when cheaper evidence cannot settle the uncertainty,
   the result could change the design choice, and one bounded falsifiable experiment can answer one
   question. Otherwise explain the cheaper evidence and stop without writing.
2. **Charter and stop.** Present the question, decision relevance, hypothesis, success criterion,
   expected cost, and stopping condition. Ask for explicit confirmation even after a direct
   `/architect spike`. Before confirmation, write no draft and run no experimental command.
3. **Experiment after confirmation.** Create or resume the idea draft through package-local
   `scripts/architect-artifacts.sh draft-save` and record the charter. Inspect the project read-only.
   Keep experiment code, fixtures, generated data, and build output in a disposable temporary area;
   never offer them as a patch or copy them into the project. The only durable project writes are
   the Architect draft and completed spike record. External effects retain their normal approval
   boundaries. Stop at the charter's condition or budget and save method, observations, failures,
   and limitations to the draft.
4. **Conclude.** A complete positive, negative, or inconclusive account uses the package-only
   `templates/spikes.md` outline and `scripts/architect-artifacts.sh spike-publish`. Resolve both
   project homes through SKILL.md *Project homes* and pass the executable
   `<agent-workspace>/journal/scripts/records.sh` only when present; otherwise use file mode. Add the
   returned `→ spikes/YYYY-MM-DD-<slug>.md` link to the draft through `draft-save`.

Incomplete or interrupted work remains only in draft notes and never calls `spike-publish`. Resume
by re-reading the charter; ask for confirmation again only when an assumption or expected cost
changed. Never overwrite a published spike. Later evidence creates a new record whose conclusion
cites the predecessor, and the draft links the new record too. `published` means stable and citable,
not independently endorsed.

## Done when

The spike stopped at qualification, awaits confirmation, remains resumable draft notes, or produced
one self-contained published evidence record linked from its draft. No production implementation or
durable probe job exists.
