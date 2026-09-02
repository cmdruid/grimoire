# `done` — close a record in place

Completion is a judgment followed by the staged provider's lifecycle mechanic. Records never move
on closure; the provider stamps `archived` and appends the sole ledger row.

1. Resolve `<root>` and run `scripts/records-runtime-check.sh --root <root>`. Stop on its exact
   diagnostic. Use its sole success line as the staged-provider path; never resolve `.spaces` or
   execute the bundled copy. Confirm the target through staged `list`/`show`.
2. Pick the disposition: `done` (completed), `dropped` (won't do; explain why), `superseded`
   (replacement named), or `consumed` (destination named). If completion is uncertain, leave the
   record live.
3. Run `<provider> done <path> [--as <disposition>] --note "<one line>"`. Never hand-edit archived
   status or `history.tsv`.
4. Search the staged provider's full live list for inbound `→ <rel>` references. Rewrite only
   matching unchecked tracker-item lines under `## Items`, leaving prose and completed items alone;
   touch each rewritten tracker through the staged provider.
5. Commit the exact record, ledger, and writeback paths with Journal's scoped commit policy, or
   return them to an announced sweep.

Pruning closed records belongs to curate and always requires separate human confirmation.

## Done when

The record was left live when uncertain, or it was closed in place with one ledger row, bounded
writebacks, and exact commit custody.
