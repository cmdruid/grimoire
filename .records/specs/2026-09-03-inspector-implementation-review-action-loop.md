---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec]
---

# Inspector implementation review action loop — Spec

## Problem

Inspector's implementation review is intentionally read-only, but its current close is also a dead
end. Every implementation verdict stops after reporting findings. A `needs-rework` result therefore
leaves the user to reconstruct the next workflow: decide which findings to fix, choose whether the
primary session or an isolated agent should implement them, request the work, and remember to invoke a
full review again afterward. The review found the work and knows the safe next sequence, but does not
offer it.

This is most costly on the ordinary failing path. The user usually wants every must-fix finding
corrected and the resulting implementation reviewed again. Requiring them to type that sequence adds
friction without protecting the reviewed checkout. Conversely, silently editing after a verdict
would erase Inspector's read-only review boundary and the user's choice of execution route.

The interaction also needs to work across harnesses. Some can render a focused multi-select whose
selected defaults submit on Enter; others can only ask for a textual confirmation. Inspector needs
one semantic action contract with a graceful presentation fallback, not behavior coupled to one
harness API.

## Goal

Every implementation review ends with an actionable close. A `needs-rework` verdict defaults to
fixing all must-fix findings through an isolated implementation agent and then running a complete
re-review; one focused optional row lets the user include recommended changes with Space before
pressing Enter. The user may instead choose inline implementation or stop without mutation.

The review pass itself remains read-only, document revision/refinement behavior remains unchanged,
and the interaction remains portable when a native multi-select or isolated-agent capability is not
available.

## Approach

**Chosen: add a verdict-sensitive implementation action loop to `review`.** The implementation
review first completes exactly as today: resolve and inspect the full target, run its gates, apply the
materiality bar, and report the deterministic verdict. Only after that mutation-free result does it
present the next-action surface. Confirmation authorizes a distinct remediation phase, followed by a
fresh invocation of the complete implementation-review procedure when re-review is selected.

The default `needs-rework` path is the common safe sequence:

```text
needs-rework — Next actions

[ ] Also fix recommended changes
[x] Fix all must-fix findings
[x] After selected fixes, re-review the complete implementation
[x] For selected fixes, use an isolated implementation agent
    Uncheck to perform the fixes inline.

Press Enter to proceed.
```

When recommendations exist, their unchecked row is first and receives initial focus. Space selects
it; Enter submits the remaining safe defaults. This ordering is part of the behavior, not cosmetic
copy.

**Rejected: keep implementation verdict-only and leave continuation to each caller.** That preserves
the present ownership sentence but reproduces the missing next step in every host workflow and makes
re-review easy to forget.

**Rejected: route implementation findings through document `revise`.** `Revise` verifies and amends
typed document artifacts under kind-specific legal locations. Source remediation has different target,
isolation, gate, and diff-baseline requirements; overloading it would weaken both contracts.

**Rejected: automatically fix immediately after `needs-rework`.** The user must retain control over
whether recommendations are included and whether implementation runs inline or in isolation. The
review verdict alone does not authorize a write.

**Rejected: make isolated and inline two independent checkboxes.** They are mutually exclusive
execution routes, while the other rows are composable actions. One selected “use isolated” modifier,
whose unchecked meaning is inline, cannot produce an invalid both/neither route.

## Mechanism

### Review boundary and action state

The existing implementation review remains source-mutation-free through verdict reporting. Its
verification commands may produce the host's ordinary ignored build artifacts, but it does not edit
reviewed source, stage files, create records, publish, or enter document `revise` or `refine`.
`revision-after-review: unavailable` continues to mean that document revision is unavailable for the
implementation kind; it no longer suppresses the separate implementation action close.

After reporting an implementation verdict, `review` constructs an ephemeral action selection from
the findings and observed execution capabilities. The selection is conversation state, not a file or
new project store. Each row has an exact default and dependency:

| row | appears when | default | effect |
|---|---|---|---|
| Also fix recommended changes | at least one recommended change exists | off; first and focused | adds every reported recommendation to the fix package |
| Fix all must-fix findings | verdict is `needs-rework` | on | adds every must-fix finding to the fix package |
| After selected fixes, re-review the complete implementation | at least one fix row exists | on | queues the full implementation-review procedure after a successful fix phase |
| For selected fixes, use an isolated implementation agent | at least one fix row exists and isolation is eligible | on | delegates the selected fix package to a writer that cannot mutate the reviewed checkout; unchecked means inline |

Rows use whole finding classes, not per-finding toggles. A user may adjust the package in natural
language before confirmation; any adjustment that changes the proposed package is reflected back once
before work begins. “Stop,” “not yet,” cancellation, or dismissal writes nothing and drops queued
re-review intent.

Dependencies are enforced semantically even if the presentation surface cannot disable controls:

- With no selected fix row, execution-route and re-review modifiers are inert; Enter closes the
  review and returns the unchanged target to its caller.
- A selected fix row resolves exactly one execution route: isolated when its modifier is selected,
  inline when it is not.
- Re-review runs only after the complete selected package was applied successfully. A blocked or
  partially applied fix stops and reports its state instead of reviewing a knowingly incomplete
  package.
- The user may explicitly deselect re-review. Inspector then stops after the implementation phase and
  reports that the resulting change has not passed Inspector review.

### Verdict-specific close

Apply the action table above by verdict:

- `needs-rework`: Enter accepts the selected must-fix, re-review, and eligible isolation defaults.
  The focused recommendation row lets Space include recommendations first.
- `approve-with-changes`: Enter accepts the implementation as-is. Selecting recommendations activates
  the conditional execution-route and re-review modifiers.
- `approve`: offer a direct return to the calling workflow without a remediation checklist.

Every close leads with the situation, retains the conversation-only verdict code, and presents the
applicable action rather than ending on the code alone.

### Presentation adapter

The action contract is harness-agnostic. When the harness exposes a native multi-select, use it and
preserve row order, selection defaults, and initial focus. Do not name a harness-specific tool inside
Inspector's portable instructions.

When native multi-select is unavailable, render the same ordered checklist in conversation and ask
one confirmation against the visible defaults. The fallback must state that recommended changes are
excluded and name the selected execution route: isolated when its row is available and selected,
otherwise inline. It must not claim that a literal empty chat message can be submitted. A clear
acceptance (`yes`, `proceed`, `do it`, `ok`, or equivalent) accepts the displayed defaults; an
adjustment rewrites the selection and asks once more; rejection writes nothing.

Resolve one unambiguous writable destination before rendering any fix action. If none is provable,
ask for it and stop. Then determine route availability through the isolation invariant below. When
isolation is ineligible for the resolved destination, omit its row, state that fixes will run inline,
and keep the remaining action contract available.

### Isolation invariant

Offer isolation only when an isolated executor exists, every reviewed source change is represented
by a clean commit or ref, one unambiguous writable destination is clean and checked out at that exact
after endpoint, and an isolated checkout can be created from it.

A resolved but dirty destination is ineligible for isolation. Omit the isolation row, state that
fixes will run inline against that destination, and keep the remaining action contract available. An
unresolved or ambiguous destination is instead an ask-and-stop before the action surface. Do not
invent a snapshot or copy protocol, guess a destination from cwd, or rewrite detached history. A
commit or range is eligible only when a current checkout's branch and HEAD relationship proves that
it owns the reviewed endpoint.

For isolated execution, the shared pre-write destination check below must also prove that the HEAD
still equals the reviewed after endpoint and `git status --porcelain` is still empty. Capture that
validated state, then create the isolated checkout from its endpoint. The implementation agent writes
only there and returns a reviewable commit or diff with verification evidence. The primary session
inspects and verifies the result in isolation.

Immediately before integration, the destination must still have the captured HEAD and empty status.
Any new commit, staged, unstaged, or untracked change is drift: stop without applying the result and
re-resolve the implementation. If isolation otherwise becomes unavailable, stop and offer inline
execution rather than silently weakening the selected route.

### Remediation phase

The selected findings are the complete scope of remediation. The implementation phase receives the
review target, governing design or plan, each selected finding with its location/evidence/remedy, the
resolved destination checkout, and the re-review baseline. It may make only changes needed to address
that package; same-pattern observations outside it return as observations rather than silently
expanding scope.

Before either route writes, re-resolve the destination and compare its HEAD, staged diff, unstaged
diff, and reviewed untracked paths and contents with the evidence used for the verdict. Any difference
is destination drift: stop without mutation and require a fresh review of the current implementation.
This identity check detects drift only; it never reconstructs dirty state in another checkout.

For inline execution, the primary session applies the fixes in the resolved destination checkout.
For isolated execution, follow the isolation invariant above. Self-reported success is not evidence.

The isolated route is selected by default because it preserves separation between the implementation
agent and the reviewing session. Choosing inline explicitly trades that agent separation for lower
overhead; it never waives the distinct full-review pass or any review axis. “Independent review” means
that the review judgment is rerun from the complete evidence rather than accepted from the writer's
self-report, not that a separate provider or model is mandatory.

An implementation target may be a worktree, diff, range, or commit, but remediation requires one
unambiguous writable destination before the action close. A named writable worktree can supply it.
For a commit or range, a current checkout must prove through its branch and HEAD relationship that it
owns the reviewed endpoint; otherwise ask for the destination and stop.

### Full re-review and loop

Capture the original review's base endpoint before remediation. After fixes, re-review the complete
resulting implementation from that same base through the remediated destination HEAD or working-tree
state. Reviewing only the fix delta is forbidden: it could prove each correction locally while
missing a regression or interaction in the full accumulated change.

Re-review runs the entire implementation procedure: reload the effective kind doctrine and governing
design, inspect the full diff and surrounding code, run applicable gates, cover every soundness and
groundedness axis, and select a fresh verdict. Prior findings are evidence to verify, not a reduced
checklist or automatic disposition.

The new verdict gets the same action close. Another `needs-rework` may enter another confirmed
fix-and-review cycle; there is no unattended loop and no automatic write across cycles. The user can
stop at every verdict.

### Package surface and ownership

Inspector remains self-contained. Its prose names generic inline and isolated execution capabilities,
not a sibling skill, provider, model, or harness API. No setup, hook, runtime store, project doctrine
kind, or new public verb is added. Project implementation doctrine may refine review axes but cannot
replace the shared action-selection, confirmation, isolation, or full-re-review semantics.

Update the router's scope and implementation-review flow, `verbs/review.md`, and
`kinds/implementation.md` together so the doctrine does not retain the false “verdict-only” close.
Align the live responsibility spine and catalog wording where they describe implementation review.
Historical specifications and reports remain unchanged.

## Verification

Extend Inspector's behavioral fixtures to prove:

- **Action close:** all three verdicts render the specified actions and defaults; recommendations
  remain first, focused, and optional; absent finding classes produce no empty choices; native and
  textual presentations report the same recommendation and execution-route defaults; confirmation,
  adjustment, rejection, and dismissal preserve the mutation boundary.
- **Execution routes:** eligible isolation starts from the captured endpoint and confines the writer;
  deselection runs inline; dirty or incapable targets expose inline before confirmation; ambiguous
  targets ask for a destination and stop; post-confirm failure never silently falls back; destination
  drift blocks inline mutation, isolated-checkout creation, and integration, including when dirty
  content changes without changing the status-path population.
- **Review lifecycle:** only a completely applied package triggers re-review; the full result is
  reviewed from the original base; mutations outside the fix delta remain visible; deselected,
  blocked, or partial paths report the unreviewed state; every new verdict presents a fresh action
  close.
- **Regression surface:** document review, `revise`, `refine`, status custody, kind resolution,
  setup, verdict mapping, and destination-selection boundaries remain unchanged.

Red-prove the action defaults, row order, dirty-state exclusion, pre-write and pre-integration
destination-drift guards, and full re-review baseline by disabling each mechanism once, requiring its
assertion to fail, restoring the fixture, and confirming byte identity. Run:

```sh
skills/inspector/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
skills/architect/scripts/ground-check.sh \
  "$(git rev-parse --show-toplevel)" \
  .records/specs/2026-09-03-inspector-implementation-review-action-loop.md
```

Then re-read the complete Inspector router, review verb, implementation kind, affected behavioral
fixtures, responsibility spine, and catalog entries. Verify that no live surface still claims every
implementation review is verdict-only or that the review phase itself mutates code.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| I1 | Add the verdict-sensitive action selection, confirmation parser, inline/isolated remediation boundary, full re-review baseline, and loop semantics | Inspector implementation and close fixtures, including red-proofs | `skills/inspector/SKILL.md`, `skills/inspector/verbs/review.md`, `skills/inspector/kinds/implementation.md`, `skills/inspector/scripts/tests/implementation-test.sh`, `skills/inspector/scripts/tests/review-close-test.sh` |
| I2 | Align the public responsibility and catalog surfaces, then run the complete package and library gates | Inspector full harness, skill lint, ground-check, manual full-surface reread | `docs/design/2026-08-21-architect-contractor-inspector.md`, `README.md`, `PACK.md`, `.records/specs/2026-09-03-inspector-implementation-review-action-loop.md` |
