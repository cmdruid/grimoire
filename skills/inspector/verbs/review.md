# `review` · critique a document or completed implementation

Independent second-set-of-eyes on a document or completed change. Findings and the verdict stay in
conversation. A document may later use its existing acceptance/publication gate; implementation
review never mutates or remediates the change.

Kind-detect is the only target gate (SKILL.md *Kind-detect*). The seven bundled kinds are in scope.
Unknown kind → ask or refuse; do not invent a rubric. The review phase does not amend. Automatic
continuation may enter `revise`, but its questions and proposal still stop before any edit. Do not
mint a record.

## Procedure

1. **Read the complete target; detect its kind** per SKILL.md *Kind-detect*. Load the effective kind
   file: a readable regular workspace copy when present, otherwise the bundled
   `kinds/<kind>.md` when absent. An incompatible or unreadable workspace entry is an error. For
   `implementation`, read the complete diff and resolve the governing design or plan when named or
   discoverable. Unknown kind → ask or refuse here; stop.
2. **Axis 1 — soundness** (internally consistent, feasible): use the kind file's soundness axes.
   Shared floor, unless the kind file replaces it: no section contradicts another; the approach is
   justified with alternatives honestly weighed; the mechanism is implementable as written; scope
   is one artifact's worth; every requirement is unambiguous; a **numeric acceptance target** must
   attribute its population to the mechanism's target class; every **guard/absence-style test**
   ("asserts X never happens") needs a **red-proof** — disable the guarded mechanism once and show
   the test fails, or argue concretely why the fixture can exercise the failing arm.
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
      kind file. Mark each `clear`, `finding`, or `not-applicable`, with evidence. Do not expose a
      bureaucratic checklist when the target is clear.
   2. Trace every central claim or changed behavior through its governing mechanism and
      verification.
   3. Re-scan interactions among findings: fixing one must not leave a contradictory requirement
      or behavior elsewhere.
   4. Ask the inverse required by the kind. For a spec: which mechanism would not exist from
      scratch? For an implementation: which passing test could still encode the wrong behavior?
   5. Repeat the material pass until another pass produces no new supported must-fix finding.

   Adequacy is exhaustive over material axes, not every sentence or stylistic preference. There is
   no numeric finding cap.
5. **Materiality — admit only actionable evidence.** A reportable finding must be all of:
   - **specific** — names a location or behavior;
   - **grounded** — supported by the target and relevant source, test, doctrine, or reproducible
     scenario;
   - **consequential** — affects correctness, implementability, followability, safety, ownership,
     scope, or verification;
   - **actionable** — gives a concrete remedy in the target's ownership or names the exact owner to
     which it must be pushed back;
   - **non-duplicate** — adds a distinct defect rather than restating a symptom.

   Classify a target that cannot safely proceed as `must-fix`; classify a material improvement that
   does not block as `recommended change`; omit nits, unsupported concerns, taste, and covered
   symptoms. Qualify uncertain evidence in confidence notes; never present uncertainty as fact. An
   unresolved question that blocks classification is an `ask`, not a speculative must-fix.
6. **Map and report the verdict exactly.** Mapping is deterministic:
   - any must-fix finding → `needs-rework`;
   - no must-fix and at least one recommended change → `approve-with-changes`;
   - no material findings → `approve`.

   Report in this order: one actionable situation sentence; verdict code; must-fix findings ranked
   by severity; recommended changes; confidence notes. Omit an empty findings subsection. Each
   finding is location → defect → consequence → concrete fix.

   Verdict words stay **conversation-only**. Do not create or append `## Review history`. Do not
   write `status:` or `stage:` in this verdict turn.
7. **Resolve review continuation.** For a document, resolve the effective kind's
   `revision-after-review` mode exactly as SKILL.md *Review-continuation policy* specifies. A bad
   declaration is an error, not a fallback. `implementation` is always `unavailable`.
8. **Close or continue exactly once.** Use the resolved mode and verdict:

   | Target / verdict | `automatic-proposal` | `offered` | `unavailable` |
   |---|---|---|---|
   | document `approve` | existing accept/publish offer; stop | existing accept/publish offer; stop | existing accept/publish offer; stop |
   | document `approve-with-changes` | enter revise with all recommended changes | offer accept/publish as-is or explicit revise; stop | offer accept/publish as-is; stop |
   | document `needs-rework` | enter revise with all findings | offer explicit revise; stop | verdict only; stop |
   | implementation, any verdict | verdict only; stop | verdict only; stop | verdict only; stop |

   A passing publication offer says, “If you accept, this session will publish `<path>`.” A
   founding-shaped document instead says acceptance leaves `<path>` draft; it performs no gate
   write. For an `approve-with-changes` branch, say **accept/publish as-is** as applicable so
   acceptance cannot be confused with approval of an amendment package. An offered
   `needs-rework` branch says, “If you want, I can fold these findings with `/inspector revise`; if
   you approve the revision proposal, I’ll re-review the amended document automatically.”
   Implementation and unavailable
   `needs-rework` stop after the verdict and findings. Do not offer publish, revise, or remediation
   there; do not write code, status, or stage.

   **Automatic entry.** After reporting the verdict and findings, immediately enter
   `verbs/revise.md` with the reviewed artifact, detected kind, resolved effective policy, complete
   findings, origin verdict, and re-review queued. Skip only revise's standalone invocation
   resolver; run its verification, classification, questions, empty-package, and proposal steps.
   This is the same turn, not an edit authorization. Questions are a stop. A non-empty proposal is
   a stop. No body, `status`, or `stage` changes before proposal confirmation.

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

On accept, use executable `<agent-records>/records.sh` when present, passing
`--root <root> --records-root <records-root-relative> touch --status published`; otherwise update
`status: published` in file mode. Job artifacts (`plan`, `roadmap`, `runbook`) also
receive `stage: approved`; specs and ADRs receive `published` only. Then stop unless the same
utterance requested further work.

### Offered material-finding branch

1. **Revise** — a clear request to fold, amend, or revise these findings → enter
   `verbs/revise.md` on the next turn with the complete in-context findings, reviewed artifact,
   origin verdict, and re-review queued by default. An explicit request to revise without
   re-review clears that intent.
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

The review phase does not amend a body or code. Document fold is `revise`; implementation
remediation is outside Inspector.
