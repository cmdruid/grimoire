# `review` · critique a document or completed implementation

Independent second-set-of-eyes on a document or completed change. Findings and the verdict stay in
conversation. A document may later use its existing acceptance/publication gate. The implementation
review phase remains source-mutation-free through verdict reporting; only a confirmed English close
may remediate the change in this checkout.

Kind-detect is the only target gate (SKILL.md *Kind-detect*). The seven bundled kinds are in scope.
Unknown kind → ask or refuse; do not invent a rubric. The review phase does not amend. Bundled
document kinds stop after the verdict and offer `revise`. A kind that declares `automatic-proposal`
may enter `revise` in the same turn; its questions and proposal still stop before any edit. Do not
mint a record.

## Review boundary

Establish the review boundary once, before judging the target, using SKILL.md *Scope firewall*. The
boundary comes from the requested outcome and the artifact's declared goals, affected surface,
explicit non-goals, and acceptance evidence. It is context, not another artifact or required form.
Use the narrowest supported reading; ask only when an ambiguity would materially change the verdict.

Light (default): one native pass, ground cited paths, apply in-force invariants, stop. Deep
(explicit): also inverse questions, safety of the mechanism, and named lenses. Kind-file
substrate-skeptic / explicit-deep extras are this dial, not a second switch. Do not auto-escalate
from path names. Inspector may note that a deep look would be proportionate without changing the
dial.

Named sets are opt-in (SKILL.md *Named sets*). Resolve
`.agents/skilldata/inspector/invariants/<name>.md` and
`.agents/skilldata/inspector/lenses/<name>.md` only when the caller names them. Default none.
Unknown name → ask. Unnamed look-again does not re-attach sets. A named lens on a light review is
a non-blocking note unless that file also states a forbidden shape (then the shape is must-fix;
the rest of the lens is not).

A verdict-bearing finding must concern that boundary. Must-fix: the written step cannot succeed as specified, or a falsifiable forbidden shape from an invariant file in force for this review is
violated. Taste, parenthetical alternatives, a preamble restated as a follow-up, and “or whatever
the real install is” are not must-fix. Two legal in-boundary remedies → ask; review does not pick
the product. A material improvement may be `recommended` only when it improves the bounded outcome
without adding independent work. Adjacent cleanup and architectural opportunities are follow-ups
outside the verdict and revision baton; speculative or unsupported concerns are omitted.

If a finding would introduce a subsystem or surface not named by the request or artifact, require
direct causal evidence that the bounded outcome cannot be achieved safely or correctly without it.
Without that chain, it is a follow-up or omitted, never verdict-bearing. Revision and all
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

   Adequacy is exhaustive over material axes inside the boundary, not every sentence or stylistic
   preference. There is no numeric finding cap. Do not mine extra must-fix findings by repeating
   the pass.
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
   document `revise` and `refine`, while the English close below remains separate.
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
   material verdict enters only the separate English close below. Implementation `approve` reports
   readiness and immediately resumes its caller without a stop or confirmation.

   Bundled document kinds and a missing declaration use the `offered` column. When the effective
   mode is a declared `automatic-proposal`, enter `verbs/revise.md` after reporting the verdict and
   findings, with the reviewed artifact, detected kind, resolved effective policy, complete
   verdict-bearing findings, origin verdict, inherited review boundary, and re-review queued. Never
   include follow-ups. Skip only revise's standalone invocation resolver; run its verification,
   classification, questions, empty-package, and proposal steps.
   This is the same turn, not an edit authorization. Questions are a stop. A non-empty proposal is
   a stop. No body, `status`, or `stage` changes before proposal confirmation.

## Implementation close

After a material implementation verdict, ask in English to fix in this checkout. Presenting the
close mutates nothing. The verdict itself is never confirmation.

- If the review named a commit or range that is not this tree, refuse to apply and say so.
- `approve`: report that the implementation is ready and return control to the calling workflow
  immediately. Render no option, action surface, confirmation request, or internal caller seam.
- `needs-rework`: ask to fix must-fix findings in this tree, then look again — or stop.
- `approve-with-changes`: stand as-is, or apply the recommended changes here.
- `yes` / `fix them` / `stop` and obvious paraphrases are enough.

Look-again is another complete implementation review in this session from the original base through
the full accumulated change, never just the fix delta. Reload effective kind doctrine and governing
design, inspect the whole diff and surrounding code, run applicable gates, and choose a fresh
verdict. The original review boundary remains authoritative. A new material verdict gets the same fresh close. It authorizes no unattended write. A new `approve` reports readiness and resumes the
caller automatically.

## Next-turn parse for document reviews

When review stopped, parse the next user utterance against the offer that made the stop; an
utterance may compose acceptance with more requested work. A declared `automatic-proposal`
continuation has not stopped at a review offer: its later proposal confirmation is parsed by
`revise.md`.

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
remediation is the English close of `review`, never document `revise` or `refine`. Isolation is not
used for a second pair of eyes or for applying fixes.
