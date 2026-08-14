# Clankshop v2 — Phase 6 plan: journal/backlog split

Companion to `2026-08-14-journal-backlog-split-design.md` (the argued design — its *Decisions*
section is settled, do not re-ask) and the roadmap's Phase 6. Needs Phase 5 shipped (landed
2026-08-14, main @ 89dd367).

## Tasks

1. **`journal` slims to the format authority.** SKILL.md rewritten: the `.records` definition,
   the front-matter contract in one citable section (or bundled contract doc), the `records.sh`
   surface (`setup`, `new`/`touch`/`done`/`history`/`list`/`show`/`check`), templates,
   `standup`, curate's substrate half (ledger prune, record rot). Workflow verbs move out
   (task/bug/issue/note/feedback/ticket/debrief and tracker-side curate). Lineage note in the
   body. `records.sh` and the format itself are **unchanged** (non-goal).
2. **`backlog` stands up as the follow-up lifecycle.** New skill dir: capture by kind →
   tracker lines + linked records, `ticket`, `debrief`, tracker-side `curate`. Guard: no
   records layer → point at `/journal setup`, one breath. Doctrinal citation of journal's
   contract; runtime calls go to the *deployed* `records.sh`. Lineage note (name re-minted
   from v1).
3. **Retire the `bug`/`task` proxies**: delete `skills/bug` + `skills/task`; PACK.md
   `optional:` and roster rows; README table rows.
4. **Cross-skill re-points**: workstream flow/verbs `/journal debrief` → `/backlog debrief`;
   delegate's byproducts-block taxonomy citation; clankshop seed/setup references (stay
   journal — records standup); PACK.md adds `backlog` optional; README/AGENTS rosters.
5. **Suites + fixtures**: journal's records-test (should be untouched — the tool doesn't
   change); setup-journal delegation suite still green; add/adjust any verb-file tests the
   split relocates.
6. **Exit sweep + routing probe**: zero relocated-verb refs pointing at journal outside
   history docs; zero proxy remnants; routing-probe on the two new descriptions (capture →
   backlog, format/setup → journal; a mis-route fails the gate — fix by sharpening scope,
   never by cross-reference). Sweeps proven by breaking; plain patterns, no `\b` (macOS ERE).

## Exit (roadmap)

Routing-probe passes; suites green; proxy dirs gone; sweep clean; lint fails=0.

## Post-ship (human/machine, outside the stream)

`install.sh backlog` + `install.sh --remove bug task` (harness re-wire; the deleted proxies'
symlinks go dangling at ship).

## Decisions to settle before build

- None blocking — the design doc settled the architecture. Two soft spots to confirm while
  building: the exact home of the contract text (SKILL.md section vs bundled doc — pick
  whichever the lint's citation checks handle better), and whether `standup` keeps its verb
  file in journal unchanged or is trimmed to match the slimmer scope.

**Settled at build (2026-08-14):**

- **Contract home: a journal SKILL.md section** (*The record contract*). Clients cite it in
  prose (no backticked bundle path — a cross-skill `references/...` token would trip the
  lint's bundle-local resolution), and the section loads with the skill, so the authority is
  always in context when journal is.
- **`standup` is not a verb** — on disk it is the stand-up *mechanics* (`scripts/standup.sh`,
  run by `setup`), and there is no report verb anywhere; the design doc's "canned report"
  parenthetical matched nothing real. It stays in journal untouched (setup's delegated
  mechanics), and no report verb was invented (non-goal: no tool changes).
