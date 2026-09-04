# `roadmap` · the durable multi-phase decision map

Use a roadmap only for an explicit durable workflow whose work genuinely spans
multiple phases. It sequences accepted scope; it does not redesign it or add
task-level detail.

## Procedure

1. **Resolve scope.** Accept a clear request, accepted draft or spec, or other
   settled source. Ask only about an open decision that changes phase
   boundaries, dependencies, safety, or acceptance.
2. **Read relevant host context.** Inspect only what is needed to establish the
   phases and their dependencies.
3. **Write the map** using `templates/roadmap.md`:
   - each phase has a goal, scope in/out, checkable exit gate, and material
     risks;
   - declare only blocking edges that affect ordering and mark genuinely
     parallel phases;
   - omit file lists, commands, and implementation steps.
4. **Land it** under the `SKILL.md` durable record contract. Resolve the active
   roadmap template, then mint `contractor/roadmap@1` with the `roadmap` tag as
   `status: draft`.

## Closing

Report the roadmap path, its next unblocked phase, and any material decision
still needed. Stop. Do not automatically produce a plan or runbook.
