# `curate` — substrate hygiene

Keep the records home conformant: contract checks, quiet closures, link rot, duplicates, and prune
proposals. Tracker line-item grooming belongs to its owning workflow.

1. Resolve `<root>` and run `scripts/records-runtime-check.sh --root <root>`. Stop on its exact
   diagnostic. Use only the returned staged provider, never `.agents/skilldata` or the bundled copy. Run
   `check` first and fix contract violations before cosmetic work.
2. Run staged `list` once, scoped only when the human requested filters. Inspect each warning;
   repair files meant to be records and leave legitimate dated non-records alone. Close records that
   quietly finished through the done procedure, repair broken `→` links, and merge duplicates by
   preserving unique body content, retargeting links, and superseding the loser.
3. Propose prunes; never execute them unasked. With a human date, use
   `prune-candidates --until <date>`. Otherwise show the closed set and ask for a threshold. The
   ledger and Git remain the trace after an approved deletion.
4. Commit exactly the touched paths with
   `scripts/scoped-commit.sh <root> "Journal: curate" <paths...>`, or return them to an announced
   sweep. End with staged `check` green.

## Done when

The provider check is green, judged closures/link repairs/merges are complete, prune work was only
performed after confirmation, and the exact mutation set has commit custody.
