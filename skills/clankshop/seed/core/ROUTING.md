# ROUTING — classify the change, dispatch it

The classification walk — judgment only; the lanes live in `build/workflows/`. Walk top to
bottom, first match wins. The door's table (`AGENTS.md`) is compiled from the dispatch rows
below.

1. **Reproducible defect?** Check `GOTCHAS.md` first — a match means working-as-coded: capture a
   note, no bug lane. Otherwise → the bug lane.
2. **One self-contained fix or tweak**, no design decision at stake → the patch lane: land on
   `<trunk>`, no ceremony (INV-12).
3. **Unknown feasibility / an open question** → a timeboxed spike; capture the learnings, then
   build properly as a feature.
4. **Everything else** — new behavior, several coupled changes, a design decision → the feature
   lane. More than one phase, or a decision worth an ADR → a roadmap first, then a plan and
   build per phase.
5. **A design decision at stake anywhere above** → the design station shapes that piece first;
   build plans against the settled spec, never against an open question.
6. **At dispatch, check for escalation:** a decision, sign-off, ambiguity, or access call only
   the human can make → a ticket (the records root's `tickets/` store) with a recommended
   answer, before the work starts.

| change | lane | entry point |
|---|---|---|
| reproducible defect | build/workflows/bug.md | root-cause first (`/debugger` where installed) |
| self-contained fix | build/workflows/patch.md | by hand, on `<trunk>` |
| new capability / design at stake | build/workflows/feature.md | design station, then the lane (`/blueprint` where installed) |
| unknown feasibility | build/workflows/spike.md | by hand, timeboxed |
