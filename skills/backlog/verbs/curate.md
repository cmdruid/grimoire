# `curate` — tracker grooming

Keep the trackers actionable: a tracker whose lines are stale, vague, or duplicated stops
being trusted, and an untrusted tracker stops being used. Curation is **hygiene, never
draining**: it may merge, sharpen, re-rank, and flip; it never decides what a signal *means*
for the system — that judgment is `promote`. This is the workflow's half of curation —
record-level hygiene (contract conformance, link rot, prune proposals) is the format
authority's half, not this verb's.

1. Resolve both homes (SKILL.md).
2. **Walk each tracker** (`records.sh list --type trackers` when the tool exists; else
   scan live `<agent-records>/trackers/*.md`): dedupe overlapping lines (merge into the
   sharper one), reword vague items until they act cold, re-order by priority (top =
   next — a deliberate exception to the contract's append-newest-last rule; later captures
   still append last), complete lines that finished without ceremony to the contract's
   completed tracker-line form, and drop lines that no longer apply (strike or delete — the
   tracker body is not a ledger). `scripts/record-mint.sh stamp` every tracker edited.
3. **An item that needs the human** becomes an Issue line `needs human: …` (same remainder
   as `debrief`). Detail that outgrew one sentence is sharpened or split into two lines —
   never minted as a dated record from this verb.
4. **One scoped commit** over everything touched
   (`scripts/scoped-commit.sh <root> "Backlog: curate" <paths…>`) when standalone; write-only
   inside a larger sweep.

## Done when

- Each tracker walked; edits touched; standalone scoped commit landed (or write-only inside
  a larger sweep); no dated record minted.
