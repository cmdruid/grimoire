# `/calibrator doctrine` — the doctrine seam, both directions

The seeded chapters carry file-level provenance back to the pack doctrine (`origin:` +
`origin-version:` keys on whole-file assets; RECORDS' `built-against:` stamp), and the doctrine
carries one version integer. The seam is judgment, not machinery: read the deployed chapter and
the current doctrine side by side and classify each difference yourself. This verb runs the seam
in both directions — downstream (the doctrine changed; offer it here) and upstream (this project
proved a rule; offer it to the doctrine). The calibrator judges and routes; it **never edits a
chapter and never writes the upstream library.**

## Downstream — offer/apply for upstream updates

1. **Compare:** a deployed file whose `origin-version:` (or RECORDS' `built-against:`) is behind
   the doctrine's current version was seeded from older content. Read the two bodies and judge
   each difference: a local edit is legitimate divergence (note it, never revert it); a local
   deletion is **never silently re-imposed**; content the doctrine changed or added since seeding
   is an offer.
2. **Offer, per difference:** present the human the local body and the upstream body — accept,
   decline, or merge is their call (the offer gate). Declined → record the decision in the run
   log; the difference will recur at the next compare and the record says why it is standing
   divergence.
3. **Apply via the owning role:** an **accepted** update is dispatched as an improvement item to
   the role owning the chapter; that role applies it and re-stamps the file's `origin-version:`
   to the current doctrine version. The calibrator verifies uptake (chapter updated, stamp
   current, check green) and closes per the intake pass's books (a `drained` line).

## Upstream — prepare a contribution (a human lands it)

1. **Candidate:** a locally-proven rule — an INV/GOTCHAS entry, a lane refinement, a testing
   skeleton improvement — that has earned generality: it bit more than once, it is
   parameterizable, it is not project-specific residue.
2. **Assemble the evidence:** the local body, the incidents that proved it (done-log lines,
   report findings, run-log entries), and the parameterization (`<gate>`/`<trunk>` slots where
   project specifics leak in).
3. **Prepare the patch** against the doctrine source (`skills/clankshop/doctrine/`) — the entry
   body plus the `doctrine-version` bump. **A human lands it**; this verb hands over the
   prepared patch + evidence and stops. Only after it ships as doctrine vNext do other projects
   see the offer — the receiving half of this same verb, run there.

## Done when

Every judged difference is dispositioned (offered, applied-via-role and closed, or recorded as
standing divergence); stamps match what was applied; any prepared contribution sits with the
human with its evidence — and no chapter or upstream file was edited by this verb.
