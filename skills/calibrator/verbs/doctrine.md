# `/calibrator doctrine` — the doctrine seam, both directions

The seeded chapters carry provenance back to the pack doctrine; the three-way differ classifies
every seeded entry (*unchanged / locally edited / upstream updated / conflict / locally deleted /
upstream retired*). This verb consumes those **facts** and runs the seam in both directions —
downstream (the doctrine changed; offer it here) and upstream (this project proved a rule; offer
it to the doctrine). The calibrator judges and routes; it **never edits a chapter and never
writes the upstream library.**

## Downstream — offer/apply for upstream updates

1. **Diff:** run the pack face's differ (`skills/clankshop/scripts/doctrine-diff.sh <root>` — a
   shared pack asset) and read the facts. *Unchanged* needs nothing; *locally edited* is
   legitimate divergence (note it, never revert it); *locally deleted* is **never silently
   re-imposed**.
2. **Offer, per `upstream updated` / `upstream retired` / `conflict` fact:** present the human
   the base, the local body, and the upstream body — accept, decline, or merge is their call
   (the offer gate). Declined → record the decision in the run log; the fact will recur and the
   record says why it's standing divergence.
3. **Apply via the owning role:** an **accepted** update is dispatched as an improvement item to
   the role owning the chapter; that role applies it and **re-stamps the entry's provenance**
   (`@vN` — the new doctrine version). The calibrator verifies uptake (entry updated, stamp
   current, check green) and closes per the intake pass's books (a `drained` line).

## Upstream — prepare a contribution (a human lands it)

1. **Candidate:** a locally-proven rule — an INV/GOTCHAS entry, a lane refinement, a testing
   skeleton improvement — that the differ shows as *locally edited* (or a local addition) and
   that has earned generality: it bit more than once, it is parameterizable, it is not
   project-specific residue.
2. **Assemble the evidence:** the local body, the incidents that proved it (done-log lines,
   report findings, run-log entries), and the parameterization (`<gate>`/`<trunk>` slots where
   project specifics leak in).
3. **Prepare the patch** against the doctrine source (`skills/clankshop/doctrine/`) — the entry
   body, its origin ID, and the BASES/bump-record additions the doctrine's bump procedure
   requires. **A human lands it**; this verb hands over the prepared patch + evidence and stops.
   Only after it ships as doctrine vNext do other projects see the *upstream updated* offer —
   the receiving half of this same verb, run there.

## Done when

Every differ fact is dispositioned (offered, applied-via-role and closed, or recorded as standing
divergence); provenance stamps match what was applied; any prepared contribution sits with the
human with its evidence — and no chapter or upstream file was edited by this verb.
