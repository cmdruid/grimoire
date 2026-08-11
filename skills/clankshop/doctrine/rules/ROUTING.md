# ROUTING — classify the change, dispatch to the lane

<!-- spine-doc v1
kind: routing
doctrine: clankshop
doctrine-version: 2
refs: .handbook/**
budget: 25 lines
-->

The classification walk — judgment only; lanes live in `workflows/`. Walk top to bottom, first
match wins. The front door's tier-0 table is compiled from the dispatch rows below.

1. **Reproducible defect?** Check `GOTCHAS.md` first — a match means working-as-coded: capture a
   note, no bug lane. Otherwise → the bug lane.
2. **One self-contained fix or tweak**, no design decision at stake → the patch lane: land on
   `<trunk>`, no ceremony (INV-11).
3. **Unknown feasibility / an open question** → a timeboxed spike; capture the learnings, then
   build properly as a feature.
4. **Everything else** — new behavior, several coupled changes, a design decision → the feature
   lane. More than one phase, or a decision worth an ADR → run it as a track.
5. **At dispatch, apply the promotion bar** (`.handbook/rules/RECORDS.md`, the escalation layer):
   a decision / sign-off / ambiguity / access call only the human can make → `/backlog promote`
   before the work starts.

| change | lane | entry point |
|---|---|---|
| reproducible defect | workflows/bug.md | `/debugger` |
| self-contained fix | workflows/patch.md | by hand, on `<trunk>` |
| new capability / design at stake | workflows/feature.md | `/feature` |
| unknown feasibility | workflows/spike.md | by hand, timeboxed |
