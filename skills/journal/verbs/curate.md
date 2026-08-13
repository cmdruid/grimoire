# `curate` — store hygiene

Tidy the records so they stay trustworthy and scannable. Curation is **hygiene, never
draining**: it may merge, sharpen, re-rank, flip, and propose prunes; it never decides what a
signal *means* for the system — that judgment lives downstream.

1. Resolve the records root (SKILL.md discipline). Run **`records.sh check`** first — fix
   contract violations before anything cosmetic (a record `check` can't parse is invisible to
   every scan).
2. **Trackers** (the usual bulk): dedupe overlapping lines (merge into the sharper one),
   reword vague items until they act cold, re-order by priority (top = next), flip lines that
   completed without ceremony (`[x]` + date), and drop lines that no longer apply (strike or
   delete — the tracker body is not a ledger). `records.sh touch` every tracker edited.
3. **Records**: `records.sh list` per store — close records that quietly finished
   (`/journal done`, right disposition), repair broken `→` links, and merge duplicate notes
   (survivor absorbs; loser closed `superseded`, note naming it).
4. **Propose prunes, don't execute them unasked**: closed records past the project's prune
   threshold (project doctrine — journal has no default) can be deleted; the ledger line and
   git history remain the trace. `records.sh prune-candidates --until <threshold-date>` is the
   shortlist (still-existing, still-closed records the ledger dates at or before the
   threshold); list it and let the human confirm.
5. **One scoped commit** over everything touched
   (`scripts/scoped-commit.sh <root> "Journal: curate" <paths…>`) when standalone; write-only
   inside a larger sweep. End green: `records.sh check`.
