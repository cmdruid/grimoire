# `debrief` — route before substantive context is lost

1. Resolve roots and run package-local `scripts/tracker-runtime-check.sh` with them. Invoke only its
   returned installed provider. Read
   `.trackers/DEBRIEF.md`. Gather only the completed work since the previous
   successful debrief in this context: visible conversation, bounded repository changes, tests, and
   unresolved decisions. Do not treat the current objective, resume instructions, or ordinary
   in-flight work as leftovers. Pure Q&A, routine status, and child/delegate contexts do not file;
   the custodial caller routes returned byproducts.
2. Before consulting the editable project prompt, apply this non-overridable remedy-owner cut. If
   the remedy belongs in a reusable installed skill, do not write it to `.trackers`; return it to
   the custodial caller as a skill-tagged byproduct for that skill's home feedback channel. If the
   remedy belongs in this repository, continue through the project routes below. Project defects,
   risks, work, and repeated responses keep their existing project routes.
3. Use each configured `## <stem>` body as editable routing judgment. Zero sections or zero filed
   rows is valid. Route by the state of the knowledge: a chosen project outcome → `tasks`; an
   established negative condition, risk, or limitation → `issues`; an unresolved operational sighting
   from a test, build, or project tool → `failures`; qualitative project-development
   experience → `feedback`; and a repeatable response to a recognizable trigger → `routines`.
   One concrete leftover routes once unless it has genuinely distinct future outcomes. If the
   configured layer has no `failures` queue, leave an unresolved sighting explicitly unrouted; don't
   silently file it elsewhere or add the queue.
4. Apply the same knowledge-state rule to performance observations. Route subjective slowness to
   `feedback`; a timeout, hang, or unexplained benchmark to `failures`; a confirmed regression to
   `issues`; and an accepted optimization to `tasks`. Expected red-green failures and failures
   resolved during the current objective aren't leftovers. A qualitative nitpick can be `feedback`;
   a vague preference isn't durable state.
5. Before filing a failure, page the bounded open `failures` population needed for comparison,
   following `next=` until the relevant population is exhausted. Compare the component or command, stable signature, and observed behavior.
   Use `update` for one matching family, replacing its text
   with the sharper current description and its evidence with the strongest current evidence;
   otherwise use `create`. Keep family matching as agent judgment: don't add a fingerprint,
   occurrence counter, provider command, or history action.
6. Before filing a routine, page all open `routines` rows needed for comparison. A candidate must
   state trigger, repeated response/decision, cost/risk/confusion, and observable completion or
   verification boundary. Use `update` for a matching open candidate; otherwise `create`. Evidence
   names the strongest basis and explicitly labels inferred recurrence.
7. Invoke only API `create` or `update`. Commit all changed queue paths once with
   `Backlog: debrief`; nested operations never commit separately. Remember this successful boundary
   within the current context; do not create a durable cursor or alternate save-state buffer.

Done when every concrete leftover was routed once or explicitly left unrouted and the sweep made at
most one scoped commit.
