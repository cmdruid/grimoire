# The spike lane — a timeboxed answer to an open question

Answer a feasibility question by building the smallest thing that answers it, inside a declared
timebox. The **learnings** are the deliverable — the spike's code never lands as-is; what
survives is captured, then built properly through the feature lane.

**Enter from:** the routing walk's unknown-feasibility row — "can this work at all?", "which of
these two libraries survives contact?", "how expensive is this really?".

**Policy:** declare the timebox and the question up front; spike work stays in isolation (a
branch or scratch dir), never on `<trunk>` (INV-3 still governs anything that does land, e.g.
captured notes); the spike itself writes no planning artifacts.

## The walk

1. Write the question down in one sentence, and the timebox next to it. If you cannot state the
   question, it is not a spike — re-route.
2. Build the cheapest artifact that answers the question. Cut every corner that doesn't bear on
   the answer; nothing here is production code.
3. Stop at the timebox, answered or not. An unanswered spike is a result: capture what was
   ruled out and what the next question is.
4. Capture the learnings (notes / trackers) and discard or park the spike code — explicitly,
   never by silently leaving it half-merged.
5. If the answer warrants building: enter the feature lane with the captures as input.

**Done when:** the question has a recorded answer (or a recorded ruled-out result), the timebox
was honored, the learnings live in the records, and no spike code has leaked onto `<trunk>`.
