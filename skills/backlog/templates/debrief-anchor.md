<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->
### /backlog — project follow-up trackers
Route: Inspect project trackers with `/backlog query` or `/backlog tracker list`; capture
completed-work leftovers with `/backlog debrief`.
Edges: produces `tracker`.

**Debrief boundary.**

This applies to the custodial main agent performing substantive repository work. It does not apply
to pure Q&A, routine status replies, or child/delegate sessions; those return their byproducts to
the custodial caller.

Run `/backlog debrief` automatically, without asking, once at the earliest of:

1. before telling the human that a coherent work unit is complete;
2. before beginning the next coherent work unit after one completes; or
3. before a healthy reset or hand-off would discard substantive context.

A coherent work unit is an outcome worth reporting: a completed request, feature slice,
investigation, design decision, or review. An individual edit, command, test run, or progress update
is not a work unit. The debrief sweep and any recovery it invokes close the preceding unit; neither
is itself a new work unit.

Sweep only completed-work leftovers since the previous successful debrief in this context. Do not
file the current objective, resume instructions, or ordinary in-flight work. Zero filed rows is
success. Remember the boundary in the current context and do not repeat the same unit.

During involuntary compaction or context-pressure emergencies, preserve and recover the primary work
first; run any deferred debrief at the next safe boundary. If debrief refuses, follow its recovery
diagnostic when safe and retry once. If it still refuses, keep the boundary pending, report the
refusal, and do not begin another unit or deliberately reset or hand off. A completion response may
report the primary work complete only when it also states that debrief remains pending. Never
hand-edit tracker data.
<!-- skill:backlog END -->
