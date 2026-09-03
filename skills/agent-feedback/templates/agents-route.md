<!-- skill:agent-feedback BEGIN built-against:__BUILT_AGAINST__ -->
### /agent-feedback — capture reusable agent-system feedback
Route: after completing work with a named reusable skill, agent, harness, tool, or workflow, if its
concrete use exposed friction, a gap, a preservation win, or a well-supported request, invoke
`agent-feedback` at most once before the final response. Apply its full reuse, evidence, and privacy
checks and remain silent when they fail. Do not invoke it for ordinary success, generic praise,
project-owned defects, speculative redesign, or automatic feedback about `agent-feedback` itself.
Capture is advisory: failure never changes the completed work's outcome.
Explicit human `/agent-feedback capture` remains valid, including feedback about `agent-feedback`.
Edges: produces `feedback-observation`.
<!-- skill:agent-feedback END -->
