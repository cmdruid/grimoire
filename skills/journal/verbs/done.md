# `done` — close a record in place

Completion is a **judgment**, then a mechanic. The judgment: is this really finished, and
under which disposition? The mechanic: `records.sh done` — closure in place (the file never
moves; moves would dangle every path-based link) plus the one ledger line in `history.tsv`.

1. Resolve the records root (SKILL.md discipline). Deployed tool missing
   or not executable → name `/journal setup`, stop. Then confirm the
   record (`records.sh list`/`show`).
2. **Pick the disposition** — the vocabulary is the contract:
   - `done` — completed as intended;
   - `dropped` — deliberately won't do / no longer true (say why in the note);
   - `superseded` — replaced (the note **names the successor record**);
   - `consumed` — absorbed into the spec/doctrine (the note **names where**).
   Not sure it's finished? Then it isn't — leave it open, or `touch --status` it instead.
3. **Close it**: `records.sh done <path> [--as <disposition>] --note "<one line>"` — the
   script stamps the date, rewrites `status:`, and appends the ledger line (its sole writer;
   it refuses a double-close). Never hand-edit a status to a closing value — `check` flags a
   closing status with no ledger line.
4. **Tracker line-items are not records.** Completing a line-item *on
   request* is the follow-up client's job, not this verb. Closing a
   *whole tracker* (rare — a retired concern) goes through
   `records.sh done` like any record.
5. **Writebacks**: `records.sh list` (no `--type`), then search each
   body for `→ <rel>` where `<rel>` is the closed record's
   records-root-relative path. Rewrite only **unchecked** tracker-item
   lines under `## Items` that match the contract's live form (SKILL.md
   *The record contract* → Tracker line form). Leave prose and already
   completed items. `records.sh touch` each tracker you rewrote. Zero
   hits: nothing to write back.
6. **Commit** per the commit policy (SKILL.md): standalone → its own scoped commit
   (`Journal: done — <slug> (<disposition>)`); inside a client's sweep → write-only (the
   sweep commits once).

Pruning closed records (deleting the file; ledger + git history remain the trace) is
`curate`'s proposal to make, against the project's own prune threshold — never part of `done`.

## Done when

- Record closed: `records.sh done` wrote the disposition + ledger line;
  writebacks rewrote only matching live tracker-item lines; standalone
  commit landed (or write-only inside a sweep).
- Not finished: left open (or `touch --status`); no close.
