# `curate` — substrate hygiene

Keep the records home trustworthy: contract conformance, quiet closures, link rot, duplicate
records, prune proposals. This is the **format's** half of curation — grooming tracker
line-items (dedupe, re-rank, flip, reword) is the follow-up workflow's half and lives with the
client that owns the trackers, not here.

1. Resolve the records root (SKILL.md discipline). Deployed tool missing
   or not executable → name `/journal setup`, stop. Run **`records.sh
   check`** first — fix contract violations before anything cosmetic (a
   record `check` can't parse is invisible to every scan).
2. **Records**: `records.sh list` **once** (optional filters if the human scoped the pass).
   Walk the one list; do not filter by doctype unless the human scoped the
   pass that way. Inspect each `check` **WARN**: repair files that were
   meant as records; leave dated non-records alone. A remaining WARN on
   a legitimate non-record does not fail Done when. Then close records
   that quietly finished (`/journal done`, right disposition), repair
   broken `→` links, and merge duplicate notes: append the loser's unique
   body under a heading on the survivor, retarget `→` links that named
   the loser to the survivor, then `/journal done --as superseded` with
   the survivor named in the note.
3. **Propose prunes, don't execute them unasked.** Journal has no default
   threshold and does not read doctrine for one. If the human named a
   date, `records.sh prune-candidates --until <date>` is the shortlist.
   Otherwise run `prune-candidates` unfiltered, present the closed set,
   and ask for a threshold before proposing any deletion. The ledger line
   and git history remain the trace. Deletions only after the human
   confirms.
4. **One scoped commit** over everything touched
   (`scripts/scoped-commit.sh <root> "Journal: curate" <paths…>`) when standalone; write-only
   inside a larger sweep. End green: `records.sh check`.

## Done when

- `records.sh check` was green at the end (remaining WARNs on legitimate
  non-records are fine).
- Quiet closures, link repairs, and merges this pass judged are done (`/journal done` where
  a record closed).
- Prune shortlist shown, or a threshold asked for; deletions only after
  the human confirmed a threshold.
- Standalone commit landed (or write-only inside a sweep).
