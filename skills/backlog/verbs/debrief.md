# `debrief` — route before substantive context is lost

1. Resolve roots and require the installed API. Read
   `<agent-workspace>/backlog/hooks/debrief.md`. Gather only the completed work since the previous
   successful debrief in this context: visible conversation, bounded repository changes, tests, and
   unresolved decisions. Do not treat the current objective, resume instructions, or ordinary
   in-flight work as leftovers. Pure Q&A, routine status, and child/delegate contexts do not file;
   the custodial caller routes returned byproducts.
2. Use each configured `## <stem>` body as editable routing judgment. Zero sections or zero filed
   rows is valid. Route by intended disposition: one-time outcome → task; wrong/risky → issue;
   useful development-experience friction → feedback; repeatable response to a recognizable trigger
   → routine. One concrete leftover routes once unless it has genuinely distinct future outcomes.
3. Before filing a routine, page all open `routines` rows needed for comparison. A candidate must
   state trigger, repeated response/decision, cost/risk/confusion, and observable completion or
   verification boundary. Use `update` for a matching open candidate; otherwise `create`. Evidence
   names the strongest basis and explicitly labels inferred recurrence.
4. Invoke only API `create` or `update`. Commit all changed queue paths once with
   `Backlog: debrief`; nested operations never commit separately. Remember this successful boundary
   within the current context; do not create a durable cursor or alternate save-state buffer.

Done when every concrete leftover was routed once or explicitly left unrouted and the sweep made at
most one scoped commit.
