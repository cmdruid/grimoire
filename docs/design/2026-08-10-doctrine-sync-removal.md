# Doctrine sync-machinery removal — decision + removal plan

**Status: executed 2026-08-10** (owner decision, same date). Supersedes the projection
protocol's three-way-diff layer — plan Appendix J of
`docs/design/2026-08-06-clankshop-pack-plan.md` (text unchanged there per the
historical-record rule; this doc is the supersession record).

## Decision

Remove the doctrine's three-way-diff sync machinery — the base archive, bump records,
per-entry provenance markers, the differ, and the checker facts that police them. Keep the
lightweight file-level provenance (whole-file `origin:` + `origin-version:` keys, RECORDS'
`built-against:` stamp) and the plain `doctrine-version:` integer.

## Rationale

- **The machinery contradicts the system's premise.** Three-way merge infrastructure exists so
  a *dumb tool* can sync content without judgment. Clankshop is operated by an agent with
  judgment: handed the local chapter and the current doctrine, it can classify divergence vs
  update by reading, and ask when unsure. The archive automated a capability the operator
  already has.
- **All cost, no benefit, observed.** Zero bumps, zero installations, zero syncs ever ran; the
  bump-plus-archival ceremony had already deterred doctrine edits once (the 2026-08-08
  editorial pass deferred doctrine polish specifically because of it). It taxed the common case
  (edit the doctrine) for a rare case that never materialized — a YAGNI violation, and against
  the spirit of the pack's own INV-13 (abstractions are earned at the second consumer).
- **It cut against the seed philosophy.** The handbook is projected so the project owns it and
  grows it freely; machinery whose purpose is measuring drift from upstream is in tension with
  that. Scaffolding precedent agrees: seed-and-own is the norm, template-sync tooling the niche.
- **Timing.** Done *before* the live deployment test: no real installation exists, so no
  deployed tree carries the retired markers — the removal is free now and would not be later.

## What replaces it

The update story is versioned judgment, not mechanical diffing: a deployed chapter's
`origin-version:` (or RECORDS' `built-against:`) behind the doctrine's current version means
"seeded from older content — run a reconcile pass." The calibrator's doctrine seam keeps its
philosophy intact (offers, never silent overwrites; local edits and deletions are respected
divergence) but classifies by reading the two bodies, not by consulting a base archive.

**Accepted losses:** no mechanical unchanged/edited/updated classification per entry; the
seeded-vs-locally-added distinction for one-line entries (INV) is now inferred by comparison
with the doctrine rather than read off a marker. Both are judgment calls the operating agent
makes anyway.

## What stays

- `doctrine-version:` in doctrine declaration blocks — one integer, bumped when seeded content
  changes; no archival ceremony attached.
- Whole-file `origin:` + `origin-version:` keys stamped at projection (lanes, testing docs);
  RECORDS' `built-against: clankshop-doctrine@<v>` stamp.
- `check`'s `doctrine_version` / `records_projection_version` facts (the behind-doctrine
  signal).

## Removal inventory (tasks)

- [x] **T1 — this record.** Commit this doc; append a supersession line to the 2026-08-06
  plan's close-out status block.
- [x] **T2 — the engine, one green commit.** Delete `skills/clankshop/doctrine/BASES.md`,
  `skills/clankshop/scripts/doctrine-diff.sh`, `skills/clankshop/scripts/tests/
  doctrine-diff-test.sh`; drop the differ from `tests/run.sh`; excise `check-facts.sh`'s
  provenance section (marker collection, `provenance_stamps`, `missing_base`,
  `bump_uncovered`) keeping the two version facts; stop appending INV markers in
  `tests/lib.sh`'s `project_doctrine`; update `tests/onramp-test.sh` (drop the marker-count
  and differ asserts and the two fact keys from the green/migrate loops; assert seeded INV
  count directly instead).
- [x] **T3 — the prose sweep.** `doctrine/README.md` (bump-procedure section → a short
  *Versioning* note; intro rewritten off the base archive); `SKILL.md` (assets row + seeding
  paragraph); `verbs/setup.md` (provenance-stamp block → file-level stamps only);
  `verbs/check.md` (Provenance paragraph deleted); `docs/RUNBOOK.md` (three-way diff →
  compare-and-judge); `skills/calibrator/verbs/doctrine.md` (differ-driven procedure →
  judgment-driven, same seam philosophy, BASES/bump prep step dropped).
- [x] **T4 — verify.** Lint at baseline (`fails=0 warns=10`); full suite green (expected drop:
  −16 differ asserts, −6 onramp asserts, +1 replacement ≈ 181); repo-wide grep proves zero
  remaining references (`BASES`, `doctrine-diff`, `three-way`, `missing_base`,
  `bump_uncovered`, `⟨clankshop`, `bump record`, `base archive`).

No doctrine-version bump: no seeded entry body changes (only doctrine meta-docs and
never-deployed assets are touched), and no installation exists to reconcile.
