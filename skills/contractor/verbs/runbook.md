# `runbook` · the durable execution conductor

Use a runbook only for an explicit durable workflow that benefits from one
linear execution sequence. It compiles accepted plans and gates; it is neither
a prose essay nor a prerequisite for ordinary builds.

## Procedure

1. **Resolve input.** Accept a plan or roadmap path. A spec alone is not an
   executable conductor input.
2. **Compile from a plan.** Reduce the plan to ordered units with the relevant
   path, action, and verification gate. Preserve only real dependencies.
3. **Compile from a roadmap.** Include only phases that already have executable
   plans. If a phase lacks one, leave it out and report the gap; do not invent
   task-level work or force every future phase to be planned now.
4. **Check completeness.** Every included unit has enough instruction and a
   gate to execute; ordering respects declared dependencies; no approach essay
   remains. This check validates the conductor, not the underlying design.
5. **Land it** under the `SKILL.md` durable record contract as
   `contractor/runbook@1` with the `runbook` tag and `status: draft`.

## Closing

Report the runbook path, included scope, and any omitted phase lacking an
executable plan. Stop. Do not automatically build it.
