# `/clankshop check` — whole-system assembly validation

Validate a stamped installation as an **assembly**: is every part present, every stamped
projection current against its named input, every cross-store reference intact, the installed set
what the pack lock says? Run `scripts/check-facts.sh <root> [<skills-root>]` and judge its facts —
the script computes, this verb concludes. On an unstamped root the facts start and end at
`stamped=0`: report it and point at the onramps (`setup` / `migrate`); nothing else to validate.

## The fact partition (pack §4.6 — state it, honor it)

`check` owns **assembly** facts — the system's wiring. **Document-shape** facts — entry
conformance to wire formats, citation resolution inside prose, budget overflow — are the
docs-quality role's audit, and **code quality** is the auditor's. When a fact could be read
either way, the cut is: does it break the *machine* (assembly — ours) or the *reading* (shape —
theirs)? Never re-implement their side here; never wait for them to catch ours.

## Reading the facts

**Installation:** `stamped`, `layout`, `pack`, `pack-version`; `malformed=` means the door block
needs human repair before anything else is judged.

**Projections vs inputs** — each stamped projection must match what it names:
- `steward_stale` / `registration_stale` — a `clankshop@N` stamp differing from the installed
  `pack-version` means the projection predates the current pack: regenerate it from its source
  (door profile / doctrine), never hand-bump the stamp.
- `records_projection_version` vs `doctrine_version` — a deployed RECORDS behind the doctrine is
  an *upstream updated* situation for the improvement loop, not a hand-edit.
- `submodule_index_stale` / `submodule_unindexed` — index rows vs live gitlinks; unindexed may be
  a legal opt-out (confirm against the interview record), stale rows never are.
- `routing_targets` / `routing_unresolved` / `lane_missing` / `routing_entry_unresolved` — every
  slash-skill token in the door's table rows must resolve to an installed skill (by-hand rows carry
  no token and resolve by definition); every ROUTING dispatch row's lane file must exist. An
  unresolved target is a red fact: the door is dispatching readers into a void.
- `unregistered` / `orphaned_registrations` — tier-aware: **core members** must carry a
  pack-stamped door block (a fresh setup leaves `unregistered` empty of core members by
  construction); **helpers** register under their own independence protocol; an **optional
  proxy** registers only when installed, so an uninstalled proxy is never a gap.

**Chapters and stores:** `chapters_missing` (the four-chapter registry), `handbook_unknown` (a
top-level entry no stewardship line claims — an unowned artifact), `stores_missing` (tracker
skeleton, tickets, done log).

**Cross-store integrity** — `ticket_problems`, lifecycle-aware by construction: an
`open`/`answered` promoted ticket needs a **live, paused** origin (`origin-dangling` /
`origin-unpaused`); a `resolved` one needs its done-log line (origin ID, gist citing the `TK-`)
**or** a live unpaused origin (the demoted case); a resolved **direct** ticket needs its `TK-`
done-log line. `ticket_blocking_cycles` — a `blocking:` cycle can never resolve; break it with
the human. `done_log_inconsistent`, prefix-aware: a flat-tracker ID still live, a store-dir ID
not `resolved`, a `TK-` line whose ticket isn't resolved. `dup_ids` (archives included) — an ID
collision is corruption; resolve before anything cites either claimant.

**Coverage and health:** `ticket_open_age` (unanswered escalations aging out — surface to the
human); `seats` (each role's seat present for installed roles that need one);
`lock_missing_installed` — pack members the lock names that are not installed (a partial install
is a fact; the human decides whether it is intentional); `design_draft` — surviving draft
content that should have been distilled or retired.

## Verdict shape

Report **green** (no red facts), or the red facts grouped by the fix's owner: regenerate a
projection (this skill), repair a store (the records instrument), a human decision (partial
install, opt-outs, cycles). `check` itself **changes nothing** — it is the validator every other
verb points at, and its output is the worklist.

## Done when

Every fact family above has been read and judged; red facts are reported with their owning fix;
green is stated plainly. Nothing was written.
