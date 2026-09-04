# `review` · critique a document or completed implementation

Independent second-set-of-eyes on a document or completed change. Findings and the verdict stay in
conversation. A document may later use its existing acceptance/publication gate. The implementation
review phase remains source-mutation-free through verdict reporting; only a separately confirmed
post-verdict implementation action may remediate the change.

Kind-detect is the only target gate (SKILL.md *Kind-detect*). The seven bundled kinds are in scope.
Unknown kind → ask or refuse; do not invent a rubric. The review phase does not amend. Automatic
continuation may enter `revise`, but its questions and proposal still stop before any edit. Do not
mint a record.

## Review boundary

Establish the review boundary once, before judging the target, using SKILL.md *Scope firewall*. The
boundary comes from the requested outcome and the artifact's declared goals, affected surface,
explicit non-goals, and acceptance evidence. It is context, not another artifact or required form.
Use the narrowest supported reading; ask only when an ambiguity would materially change the verdict.

A verdict-bearing finding must concern that boundary. A defect that directly prevents the outcome,
violates an in-scope requirement, or makes the result unsafe or incorrect may be `must-fix`. A
material improvement may be `recommended` only when it improves the bounded outcome without adding
independent work. Adjacent cleanup and architectural opportunities are follow-ups outside the verdict
and revision baton; speculative or unsupported concerns are omitted.

If a finding would introduce a subsystem or surface not named by the request or artifact, require
direct causal evidence that the bounded outcome cannot be achieved safely or correctly without it.
Without that chain, it is a follow-up or omitted, never verdict-bearing. Automatic revision and all
later review rounds inherit the same boundary; discovery in one round cannot widen the next.

## Procedure

1. **Read the complete target; detect its kind and establish its boundary** per SKILL.md *Kind-detect*
   and *Scope firewall*. Load the effective kind
   file: a readable regular workspace copy when present, otherwise the bundled
   `kinds/<kind>.md` when absent. An incompatible or unreadable workspace entry is an error. For
   `implementation`, read the complete diff and resolve the governing design or plan when named or
   discoverable. Unknown kind → ask or refuse here; stop.
2. **Axis 1 — soundness** (internally consistent, feasible): use the kind file's soundness axes.
   Shared floor, unless the kind file replaces it: no section contradicts another; the approach is
   justified with alternatives honestly weighed; the mechanism is implementable as written; scope
   is one artifact's worth; every requirement is unambiguous; a **numeric acceptance target** must
   attribute its population to the mechanism's target class. A **guard/absence-style test**
   ("asserts X never happens") needs a **red-proof** only when that negative guarantee is
   acceptance-critical and the fixture could otherwise pass without exercising the guarded
   mechanism. Disable the mechanism once and show the test fails, or argue concretely why the
   fixture exercises the failing arm. Routine negative assertions with direct evidence do not
   require a mutation ritual.
3. **Axis 2 — groundedness** (conforms to the codebase and host invariants):
   - Document target: run this package's `scripts/ground-check.sh` `<root> <doc>`, then re-read the
     load-bearing signatures/code the claims rest on. A clean ground-check finds moved files; it
     does not prove that a cited symbol exists or still means what the prose claims. Check the
     artifact against the host's invariants and gotchas, plus published governing specs and live
     ADRs when present.
   - Implementation target: inspect the full diff and load-bearing surrounding code, then run the
     relevant targeted and host gates or explain a concrete inability.

   Apply every groundedness extra in the effective kind file.
4. **Adequacy — cover the material surface before choosing a verdict.**
   1. Enumerate internally every required soundness axis and groundedness extra from the effective
      kind file as it applies inside the review boundary. Mark each `clear`, `finding`, or
      `not-applicable`, with evidence. Do not expose a bureaucratic checklist when the target is
      clear.
   2. Trace every in-boundary central claim or changed behavior through its governing mechanism and
      verification.
   3. Re-scan interactions among findings: fixing one must not leave a contradictory requirement
      or behavior elsewhere.
   4. Ask the inverse required by the kind. For a spec, ask the substrate inverse only when its
      effective kind enables it for an explicit deep review. For an implementation, ask which
      passing test could still encode the wrong behavior.
   5. Repeat the material pass until another pass produces no new supported must-fix finding inside
      the review boundary.

   Adequacy is exhaustive over material axes inside the boundary, not every sentence or stylistic
   preference. There is no numeric finding cap.
5. **Materiality — admit only actionable evidence.** A reportable finding must be all of:
   - **specific** — names a location or behavior;
   - **grounded** — supported by the target and relevant source, test, doctrine, or reproducible
     scenario;
   - **consequential** — affects the bounded outcome's correctness, implementability, followability,
     safety, ownership, scope, or verification;
   - **actionable** — gives a concrete remedy in the target's ownership or names the exact owner to
     which it must be pushed back;
   - **non-duplicate** — adds a distinct defect rather than restating a symptom.

   Classify a target that cannot safely achieve its bounded outcome as `must-fix`; classify an
   in-boundary material improvement that does not block as `recommended change`. Report an adjacent
   independent improvement once as a non-blocking follow-up outside the verdict; do not pass it to
   `revise`. Omit nits, unsupported concerns, taste, speculative opportunities, and covered symptoms.
   Qualify uncertain evidence in confidence notes; never present uncertainty as fact. An unresolved
   question that blocks classification is an `ask`, not a speculative must-fix.
6. **Map and report the verdict exactly.** Mapping is deterministic:
   - any must-fix finding → `needs-rework`;
   - no must-fix and at least one recommended change → `approve-with-changes`;
   - no material findings → `approve`.

   Report in this order: one actionable situation sentence; verdict code; must-fix findings ranked
   by severity; recommended changes; confidence notes; non-blocking follow-ups, if any. Omit an empty
   findings subsection. Each verdict-bearing finding is location → defect → consequence → concrete
   fix. Label follow-ups as outside the verdict and exclude them from continuation.

   Verdict words stay **conversation-only**. Do not create or append `## Review history`. Do not
   write `status:` or `stage:` in this verdict turn.
7. **Resolve review continuation.** For a document, resolve the effective kind's
   `revision-after-review` mode exactly as SKILL.md *Review-continuation policy* specifies. A bad
   declaration is an error, not a fallback. `implementation` is always `unavailable`: that forbids
   document `revise` and `refine`, while the action close below remains separate.
8. **Close or continue exactly once.** Use the resolved mode and verdict:

   | Target / verdict | `automatic-proposal` | `offered` | `unavailable` |
   |---|---|---|---|
   | document `approve` | existing accept/publish offer; stop | existing accept/publish offer; stop | existing accept/publish offer; stop |
   | document `approve-with-changes` | enter revise with all recommended changes | offer accept/publish as-is or explicit revise; stop | offer accept/publish as-is; stop |
   | document `needs-rework` | enter revise with all findings | offer explicit revise; stop | verdict only; stop |
   | implementation `approve` | report ready; resume caller | report ready; resume caller | report ready; resume caller |
   | implementation `approve-with-changes` | optional-fix action stop | optional-fix action stop | optional-fix action stop |
   | implementation `needs-rework` | required-fix action stop | required-fix action stop | required-fix action stop |

   A passing publication offer says, “If you accept, this session will publish `<path>`.” A
   founding-shaped document instead says acceptance leaves `<path>` draft; it performs no gate
   write. For an `approve-with-changes` branch, say **accept/publish as-is** as applicable so
   acceptance cannot be confused with approval of an amendment package. An offered
   `needs-rework` branch says, “If you want, I can fold these findings with `/inspector revise`; if
   you approve the revision proposal, I’ll re-review the amended document automatically.”
   An unavailable document `needs-rework` stops after the verdict and findings. Implementation never
   offers publish, `revise`, or `refine`, and never writes status or stage. Every implementation
   material verdict enters only the separate action close below. Implementation `approve` reports
   readiness and immediately resumes its caller without a stop or confirmation.

   **Automatic entry.** After reporting the verdict and findings, immediately enter
   `verbs/revise.md` with the reviewed artifact, detected kind, resolved effective policy, complete
   verdict-bearing findings, origin verdict, inherited review boundary, and re-review queued. Never
   include follow-ups. Skip only revise's standalone invocation resolver; run its verification,
   classification, questions, empty-package, and proposal steps.
   This is the same turn, not an edit authorization. Questions are a stop. A non-empty proposal is
   a stop. No body, `status`, or `stage` changes before proposal confirmation.

## Implementation textual action close

After every material implementation verdict, retain the original review base, reviewed after endpoint,
complete findings, destination evidence, and the identity of the reviewed source state. The action
close is a separate post-verdict stop; presenting it mutates nothing.
The verdict itself is never confirmation. The action state is conversation-only and holds at most
one **pending scope** or one **pending normalized selection**; it creates no record, project store,
status, or stage.

Use plain text only; do not style prose as an interactive control or claim an empty response can
submit it. A number selects exactly one verdict-local fix scope. `A`/`I` select isolated or inline
execution; `R`/`N` select full re-review or stop without re-review. Omit a scope whose finding class is
absent and do not renumber the remaining choices.

For `needs-rework`, render:

```text
needs-rework — Next actions

Fix scope — choose one:
1. Fix must-fix findings only (default)
2. Fix all findings
3. Fix recommended changes only
4. Make no changes

Execution — choose one:
A. Use an isolated implementation agent (default)
I. Work inline

Afterward — choose one:
R. Re-review the complete implementation (default)
N. Stop without re-review

Reply with a combination such as `1-A-R`, `2-I-R`, or `4`.
Reply `yes` to accept the defaults: `1-A-R`.
```

When no recommendations exist, omit scopes `2` and `3`; `1` remains the default. When isolation is
ineligible, omit `A`, label `I` as the only route, state the derived ineligibility reason immediately
above the execution group, and display `1-I-R` as the default. Treat the
fenced surface above as the fully eligible, all-findings example: every rendered reply footer must
be regenerated from the scopes and routes actually displayed. Its examples must contain no omitted
scope or unavailable route, and its `yes` line must name that surface's exact default. For
`approve-with-changes`, render `1. Return as-is (default)` and `2. Fix recommended changes`, followed
by **Execution — if fixing, choose one** and **Afterward — if fixing, choose one**. Label their
defaults **default if fixing**. `yes` or `1` returns unchanged; `2` enters the selected remediation.
For `approve`, report that the implementation is ready and return control to the calling workflow
immediately. Render no option, action surface, confirmation request, or internal caller seam.

### Parse and confirmation

Parse only against the most recently displayed implementation surface. Trim leading and trailing
ASCII whitespace, fold letters to uppercase, and consume the whole response. A code must start with
one displayed scope number, followed in group order by at most one available route letter and at most
one available afterward letter. Tokens may be adjacent or separated independently by one `-`, one
`,`, or one or more ASCII whitespace characters, with optional ASCII whitespace around punctuation.
Thus `1AR`, `1-A-R`, `1 A R`, `1,A,R`, and `1-A R` all normalize to `1-A-R`. Omitted modifier groups
use the displayed defaults. A direct valid code on a complete surface is explicit confirmation and
may proceed without a second turn.

Reject the entire response if it contains no scope number, two scope numbers, both route letters,
both afterward letters, an unavailable code, an unknown token, out-of-order groups,
repeated punctuation, or trailing punctuation. State the conflict and ask once; write nothing and
preserve any existing pending value. Validate every explicit modifier against the groups and choices
on the current surface before applying non-mutating-scope semantics. Only an available route or
afterward modifier is inert for a non-mutating scope and normalizes away; a modifier from an omitted
group or an unavailable choice is invalid rather than inert. Thus `1-A-N` is invalid on `approve`,
and `1-A-N` is invalid on an inline-only `approve-with-changes` surface even though scope `1` returns
unchanged.

With no pending value on a complete surface, clear acceptance such as `yes`, `proceed`, `go`, `do it`,
or `ok` confirms the displayed default. An unambiguous natural-language adjustment becomes an exact
candidate code, which must pass the same current-surface scope and route availability validation as a
direct code before it becomes a pending normalized selection. Reflect a valid code and meaning once,
then require confirmation. Clear
acceptance confirms that pending code, never an earlier default; a direct valid code replaces and
confirms it. `stop`, `not yet`, rejection, cancellation, or dismissal writes nothing, clears pending
state, and discards queued re-review intent. An unclear answer asks once.

### Destination resolution and reduced surface

Before execution or afterward modifiers can authorize fixing, resolve one unambiguous writable destination
that owns the reviewed after endpoint or working-tree state. A named worktree can
establish ownership. A commit or range requires a current checkout whose branch and HEAD relationship
proves it owns the endpoint. Never infer it from cwd, invent a snapshot or copy protocol, or rewrite
detached history.

If no single destination is provable, still render the applicable Fix scope group and its
non-mutating exit, but omit execution and afterward groups. Explain that a fixing choice requires a
destination. Only a displayed scope number is a valid code response on this reduced surface. Clear
acceptance selects its displayed scope default. `4` for `needs-rework`, or `1`/`yes` for
`approve-with-changes`, returns unchanged without destination resolution. A fixing scope—including
`needs-rework` `yes`, which selects scope `1`—stores only a pending scope, asks for the destination,
and cannot authorize a write.

After ownership resolves, atomically consume the pending scope, derive eligible route and afterward
defaults, and install the resulting complete code as both the displayed default and pending normalized
selection. Pending scope `2` becomes `2-A-R` when isolation is eligible or `2-I-R` otherwise. Render
the complete surface and require a fresh confirmation; the earlier scope response is not permission
to write. On the reduced surface, an unambiguous natural-language adjustment may select only scope and
follows these same rules; route or afterward prose is invalid.

### Destination identity and routes

At review time capture the evidence population for the resolved destination: HEAD, staged diff, unstaged diff,
and reviewed untracked paths and contents. Immediately before either route writes, re-resolve the
destination and compare that complete identity with the verdict evidence. Any difference is drift:
stop without mutation and require a fresh implementation review. This check detects change; it never
reconstructs dirty state elsewhere.

For inline execution, the primary session applies the selected package in the resolved destination.
Offer `A` only when an isolated executor exists, the reviewed after endpoint is a committed object,
the destination is clean with HEAD at that exact endpoint, and an isolated checkout can actually be
created from it. Derive all four facts from the current repository and executor state with a read-only
preflight: verify the executor, commit object, exact clean HEAD, worktree support, absent checkout
target, and writable target parent without creating a checkout or running checkout hooks. Actual
checkout creation occurs only after confirmation; a race or creation-time failure uses the pre-writer
fallback below. Otherwise omit `A`, expose only `I`, and state the specific failed eligibility reason.
For isolated execution, repeat
the identity check and require the clean destination HEAD to equal the reviewed after endpoint before
creating the isolated checkout from that exact commit. Give the writer
the target, governing design, baseline, and selected findings with their evidence and remedies. Confine
writes to the isolated checkout and require a reviewable commit or diff plus verification evidence;
same-pattern observations outside the package return as observations instead of widening scope.

The primary session inspects the isolated result and runs relevant verification; a writer's
self-report is not evidence. Immediately before integration, repeat the clean destination HEAD and
status guard. New commits, staged, unstaged, or untracked changes leave the result unapplied. Integrate
only a complete inspected and verified package.

If the isolated executor becomes unavailable or isolated-checkout creation fails after confirmation
but before the isolated writer begins, first prove destination identity remains unchanged and leave
any checkout or result unapplied. Render a fresh inline-only surface whose pending and displayed
default preserves the confirmed scope and afterward choice while changing only `A` to `I`; for
example, `2-A-N` becomes `2-I-N`. Require a new explicit confirmation. Never silently fall back or
reset the package to the original defaults.

Do not use that fallback for destination drift, writer-started partial or blocked work, incomplete
return, failed primary inspection, or failed primary verification. Drift requires a fresh
implementation review. Every other incomplete or unverified package stops unreviewed and remains
unapplied where applicable. A package containing multiple selected findings is complete only when all
of them succeed. When `N` is selected, a complete applied result stops with an explicit statement that
it has not passed Inspector review.

### Full re-review and loop

When re-review is selected, run the complete implementation procedure from the original base through
the full accumulated change at the remediated destination, never just the fix delta. Reload effective
kind doctrine and governing design, inspect the whole diff and surrounding code, run applicable gates,
cover every in-boundary soundness and groundedness axis, and choose a fresh verdict. The original
review boundary remains authoritative. Prior findings are evidence, and changes outside the fix delta
remain visible, but adjacent opportunities outside the boundary cannot enter the verdict or fix scope.

A new material verdict gets the same fresh action close. It authorizes no unattended write, and the
user can stop at every material cycle. A new `approve` reports readiness and resumes the caller
automatically.

## Next-turn parse for document reviews

When review stopped, parse the next user utterance against the offer that made the stop; an
utterance may compose acceptance with more requested work. Automatic entry has not stopped at a
review offer: its later proposal confirmation is parsed by `revise.md`.

### Passing offer

1. **Refine instead.** A clear request to simplify or `/inspector refine` the reviewed spec or plan
   enters `verbs/refine.md` on that exact artifact without accepting or publishing it. Unsupported
   kinds refuse refinement and remain draft.
2. **Reject** (`stop` / `don't` / `not yet` / `needs work`) → write nothing; stay draft.
3. **Accept** — any clear acceptance of the verdict, including `yes`, `looks good`, `approved`,
   `proceed`, `do it`, `lgtm`, `ok`, or `go ahead`; a request to sequence or walk the accepted
   document also accepts. Write the gate on exactly the reviewed artifact first, then honor the
   remainder. Founding-shaped documents remain draft.
4. **Unclear** → ask once whether they accept the verdict; write nothing.

On accept, use executable `.records/records.sh touch --status published` when present; otherwise update
`status: published` in file mode. Job artifacts (`plan`, `roadmap`, `runbook`) also
receive `stage: approved`; specs and ADRs receive `published` only. Then stop unless the same
utterance requested further work.

### Offered material-finding branch

1. **Revise** — a clear request to fold, amend, or revise these findings → enter
   `verbs/revise.md` on the next turn with the complete in-context verdict-bearing findings and
   reviewed artifact, with re-review queued by default, and carry the original review boundary into
   revision. An explicit request to revise without re-review clears that intent.
2. **Accept/publish as-is** — legal only for `approve-with-changes`. A clear acceptance of the
   reviewed artifact without taking the recommendations uses exactly its existing *Passing offer*
   gate. It never applies proposed changes. Founding-shaped remains draft; `needs-rework` cannot
   publish or accept.
3. **Reject** (`stop` / `don't` / `not yet`) → write nothing.
4. **Unclear** → ask once whether to enter revise (or, for `approve-with-changes`, accept/publish
   as-is); write nothing.

Depth dial (default off): for a high-stakes artifact, dispatch a few **read-only** subagents in
parallel — each a distinct lens, one a skeptic trying to refute the target's central claim — and
synthesize. Never an editing subagent.

The review phase does not amend a body or code. Document fold is `revise`; confirmed implementation
remediation is a post-verdict action of `review`, never document `revise` or `refine`.
