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
   build plans against the settled spec, never against an open question. A call only the
   human can make is asked in the conversation when a human is present; if it must survive
   a reset, debrief/curate files `needs human:`.

| change | lane | entry point |
|---|---|---|
| reproducible defect | build/workflows/bug.md | file via `/debugger file`, then root-cause (`/debugger`) |
| self-contained fix | build/workflows/patch.md | by hand, on `<trunk>` |
| new capability / design at stake | build/workflows/feature.md | design station, then `/architect spec`, `/inspector review`, then `/contractor plan` only when sequencing is required; stream still ships |
| unknown feasibility | build/workflows/spike.md | by hand, timeboxed |

After a passing `/inspector review` the caller accepts, they write `published`
(job artifacts: also `stage: approved`) before `/contractor plan` or
`/contractor build`. Not unattended.
