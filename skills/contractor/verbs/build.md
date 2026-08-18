# `build` · execute a plan or a runbook

Walk the job. Delegation is optional: do the slice yourself, or write a
self-contained brief and use the host's delegation mechanism. Do not restate
spawn flags. Do not `ship`.

A raw **roadmap** is not an input. Compile a runbook first.

## Procedure

1. **Resolve input:** a **plan** or a **runbook**. A raw **roadmap** → refuse;
   tell the caller to `runbook` it first (describe the artifact type, do not
   name a sibling skill). A spec → refuse (that is not a job to walk).
2. **Every plan that will be walked** must have passed `review` or the human
   must waive it. If unknown, run `review` on that plan first. For a runbook:
   also run the conductor completeness check (`verbs/runbook.md` step 4); that
   check **does not** replace plan review.
3. **Plan:** walk slices in declared order. Per slice: do it yourself **or**
   write a self-contained brief and use the host's delegation mechanism. After
   each slice: the slice's verify command (for you). Do not narrate every
   slice to the human unless it failed or they asked. Do not `ship`.
4. **Runbook:** walk the conductor list.
   - **Plan-sourced:** walk the steps; each step's command/gate is the
     verify. Do not invent work.
   - **Roadmap-sourced:** each entry is an existing plan path — nested
     plan-walk (step 3). Do not run `plan` to fill gaps. Phase gate must
     pass before the next phase.
5. **Status** — contractor's own assessment of the **job**, not a git-land:
   - `DONE` — every in-scope slice/step has a verify result
   - `DONE_WITH_CONCERNS` — walked, with residual risk the human should see
   - `NEEDS_CONTEXT` — cannot continue without an answer
   - `BLOCKED` — an external dependency or failed gate
6. Done when every step/slice in scope has a verify result or an explicit skip
   the human accepted. After a `DONE` / `DONE_WITH_CONCERNS` walk, run the
   host's close-the-books sweep (SKILL.md *Hard seams*).

The host lane still lands the result. This verb stops at the job assessment.
Tell the human what the software can do now, what is still open, and
whether anything is on a side branch — not a bare `DONE` code.
