# `runbook` · compile the conductor

A runbook is a **conductor** for `build`: a linearized walk. It is not a third
prose essay and not a substitute plan. From a **plan** it compiles steps +
gates + paths and strips argument. From a **roadmap** it is an ordered list of
existing phase-plan paths — never task-level work invented here.

`runbook` does not write plans. `build` does not write plans.

## Procedure

1. **Resolve input:** a **plan** path or a **roadmap** path. Missing → ask. A
   spec is refused ("that is not a job conductor input").
2. **From a plan:** compile ordered steps from the plan's slices —
   command/gate/path only, no approach essay. Each step names the slice id it
   came from.
3. **From a roadmap:** refuse unless **every** unblocked phase already has a
   **plan path** (a written plan record). If any phase lacks a plan, stop and
   tell the caller to `plan` that phase first — `runbook` does not write plans;
   `build` does not write plans. Compile: ordered unblocked phases, each line a
   **path** to that phase's plan, then "build it." Do not inline task-level
   work.
4. **Completeness check** (conductor only). Fail → fix the runbook or
   send the human back to `plan`/`roadmap`. This check is **not** `review`.
   - **Plan-sourced:** every step names a slice id and has a command +
     gate; order respects slice `requires:`; no approach essay.
   - **Roadmap-sourced:** every unblocked phase has a plan path; order
     respects phase `requires:`; no raw implementation steps invented.
5. **Land it** per SKILL.md *Shared discipline*. Compile the conductor body and mint
   `.records/records.sh new plans --schema contractor/runbook@1
   --title "Runbook: <plan title>" --tag runbook` when the tool exists; else file-mode with that
   schema into `.records/plans/`, naming the file `YYYY-MM-DD-<slug>.md`.

Output: the conductor file (`status: draft`). `build` still requires each
referenced plan to be `published` with `stage: approved` (or a caller waive
of that gate).
