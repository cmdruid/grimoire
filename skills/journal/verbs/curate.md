# `curate` — substrate hygiene

Keep the stores trustworthy: contract conformance, quiet closures, link rot, duplicate
records, prune proposals. This is the **format's** half of curation — grooming tracker
line-items (dedupe, re-rank, flip, reword) is the follow-up workflow's half and lives with the
client that owns the trackers, not here.

1. Resolve the records root (SKILL.md discipline). Run **`records.sh check`** first — fix
   contract violations before anything cosmetic (a record `check` can't parse is invisible to
   every scan).
2. **Records**: `records.sh list --type <doctype>` per doctype (the scan is a crawl filtered
   on front-matter, not a walk of store directories) — close records that quietly finished
   (`/journal done`, right disposition), repair broken `→` links, and merge duplicate notes
   (survivor absorbs; loser closed `superseded`, note naming it).
3. **Propose prunes, don't execute them unasked**: closed records past the project's prune
   threshold (project doctrine — journal has no default) can be deleted; the ledger line and
   git history remain the trace. `records.sh prune-candidates --until <threshold-date>` is the
   shortlist (still-existing, still-closed records the ledger dates at or before the
   threshold); list it and let the human confirm.
4. **One scoped commit** over everything touched
   (`scripts/scoped-commit.sh <root> "Journal: curate" <paths…>`) when standalone; write-only
   inside a larger sweep. End green: `records.sh check`.

## Done when

- `records.sh check` was green at the end.
- Quiet closures, link repairs, and merges this pass judged are done (`/journal done` where
  a record closed).
- Prune candidates listed; deletions only after the human confirmed a threshold.
- Standalone commit landed (or write-only inside a sweep).
