---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec]
---

# Inspector textual implementation review action close — Spec

## Problem

Inspector's implementation action loop currently describes a native multi-select when the harness
supports one and renders Markdown checkboxes otherwise. In the actual implementation-review context,
the available interaction surface exposes neither multi-select nor multiple-choice controls. The
fallback therefore looks selectable but is only prose. A user cannot toggle its rows or submit the
defaults with Enter, so the most visible part of the feature promises an interaction it cannot deliver.

The underlying action model is still useful: choose which findings to fix, choose inline or isolated
execution, and choose whether to re-review. The defect is presentation and parsing. Those orthogonal
decisions need a text-native grammar that is concise, composable, unambiguous, and honest about how the
user responds.

## Goal

Every material implementation verdict ends with a plain-text action close. A clean `approve` has no
decision to make, so Inspector reports readiness and returns to its caller automatically. When one
writable destination is already provable for a material verdict, its numbered scope choice and
lettered modifiers can be submitted in one short response. When ownership is unresolved, a
non-mutating exit remains one response while fixing first requires the exceptional
destination-resolution turn. Safe defaults remain obvious, `yes` accepts the applicable displayed or
pending choice, explicit combinations select every supported route, and invalid or incomplete
combinations never authorize a write.

The existing mutation boundary, destination-identity checks, isolation rules, complete-package gate,
and full same-base re-review remain intact. No native prompt capability is assumed.

## Approach

**Chosen: a verdict-sensitive numbered-and-lettered response grammar.** The number selects exactly one
fix scope. `A` or `I` selects isolated-agent or inline execution. `R` or `N` selects full re-review or
no re-review. On a complete surface, a response such as `2-A-R` is both the selection and its
confirmation; omitted modifier groups use the displayed defaults. An unresolved destination first
gets a reduced, scope-only surface whose fixing choices cannot authorize a write. This preserves all
combinations without presenting inert Markdown as an interactive control.

When destination ownership is already provable, the common `needs-rework` path stays short: `yes` or
`1` means fix must-fix findings through eligible isolation and then re-review. Including
recommendations is `2`; choosing inline is `I`; combinations such as `2-I-R` remain readable without
a legend once normalized.

**Rejected: retain Markdown checkboxes as a portable fallback.** They visually imply toggles and Enter
submission that do not exist in chat. Styling static prose as controls is the observed failure.

**Rejected: require a native multi-select or multiple-choice tool.** Neither control is available in
the implementation-review mode this skill must support. A portable skill cannot make an unavailable
harness capability part of its normal path.

**Rejected: enumerate every action bundle as one flat numbered menu.** Scope, execution, and re-review
produce too many combinations; a preset menu either grows unwieldy or silently removes valid choices.

**Rejected: ask one decision per turn.** Progressive questions avoid combination parsing but make the
default fix-and-review path require several round trips. Grouped codes express the same state in one.

## Mechanism

### Review boundary and retained action state

The implementation review remains source-mutation-free through verdict reporting. It collects the
original review base, reviewed after endpoint or working-tree state, complete findings, destination
evidence, the writable destination when ownership is provable, destination identity, and observed
isolation eligibility. The verdict itself never authorizes remediation.

The action close is conversation state only. It creates no record, status, stage, setup surface, or
runtime store. Implementation remains `revision-after-review: unavailable` because it never enters
document `revise` or `refine`.

### Text grammar

Render three labeled groups in this order: **Fix scope**, **Execution**, and **Afterward**. A number is
the one scope choice. `A`/`I` and `R`/`N` are mutually exclusive modifier groups. Use these exact
letter meanings everywhere:

| Code | Meaning |
|---|---|
| `A` | use an isolated implementation agent |
| `I` | implement inline in the resolved destination |
| `R` | re-review the complete implementation after a successful complete fix package |
| `N` | stop after fixes and report that the result has not passed Inspector review |

Scope numbers are local to the displayed verdict surface; never parse a number against a different
verdict's menu. Omit a scope choice whose finding class is absent. Do not renumber the remaining
choices within one displayed surface.

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

When no recommendations exist, omit scopes `2` and `3`; the default remains `1`. When isolation is
ineligible, omit `A`, label `I` as the only route, and change the displayed and normalized default to
`1-I-R`. Do not mention pressing Enter or render checkbox syntax.

For `approve-with-changes`, render scope `1. Return as-is (default)` and `2. Fix recommended changes`.
Render the execution and afterward groups for the possible fix path as **Execution — if fixing,
choose one** and **Afterward — if fixing, choose one**. Label their defaults **default if fixing** and
use the same eligibility rules. `yes` or `1` returns unchanged. `2`, `2-A-R`, or another valid `2`
combination confirms the selected remediation.

For `approve`, report that the implementation is ready and return control to the calling workflow
immediately. Render no option, action menu, confirmation request, or internal “return to caller” seam.

### Parse and confirmation

Parse only against the most recently displayed implementation action surface. Normalize a code by:

1. trimming leading and trailing ASCII whitespace and folding letters to uppercase;
2. requiring the entire remaining response to contain one currently displayed scope number, followed
   by at most one currently available route letter and at most one currently available afterward
   letter, in group order; and
3. allowing adjacent tokens to be compact or separated independently by either one `-`, one `,`, or
   one or more ASCII whitespace characters, with optional ASCII whitespace around `-` or `,`.

Thus `1AR`, `1-A-R`, `1 A R`, `1,A,R`, and mixed valid separators such as `1-A R` normalize to
`1-A-R`. A scope number is required for a code response. Route and afterward codes are optional; an
omitted group uses the displayed default. Any other character, repeated punctuation separator,
trailing punctuation, or unmatched input is invalid. On a complete action surface, a valid normalized
code is explicit confirmation and may enter remediation immediately.

The action state holds at most one of two distinct pending values:

- A **pending scope** is a fixing scope selected from a reduced destination-less surface. It carries
  no route or afterward value and can never authorize a write.
- A **pending normalized selection** is a complete normalized code whose scope, route, and afterward
  values are all resolved. It is eligible for confirmation.

On a complete surface with neither pending value, clear acceptance such as `yes`, `proceed`, `go`,
`do it`, or `ok` confirms the complete displayed default. With a pending normalized selection, clear
acceptance confirms that exact code instead, never an earlier surface default. A direct valid code on
a complete surface replaces either pending value and confirms immediately.

On a reduced destination-less surface, only a displayed scope number is a valid code response. Clear
acceptance selects that reduced surface's displayed scope default. A non-mutating scope immediately
returns the unchanged implementation. A fixing scope, whether selected by number or clear acceptance,
becomes the pending scope and enters destination resolution without write authorization. `stop`, `not
yet`, rejection, cancellation, or dismissal writes nothing, clears either pending value, and drops
queued re-review intent.

A response with two scope numbers, both route letters, both afterward letters, an unavailable code,
unknown tokens, or out-of-order groups is invalid. State the conflict and ask once; write nothing and
do not alter an existing pending value. Route and afterward modifiers are inert when the selected
scope makes no changes; normalize that selection to its scope number alone.

An unambiguous natural-language adjustment may still be accepted. On a complete surface, translate it
to the exact normalized code, install that code as the pending normalized selection, reflect its code
and meaning once, and require confirmation before work. On a reduced surface, translate only an
unambiguous scope adjustment and process it under the reduced-surface rule above. This is the only
adjustment round trip. A direct valid code on a complete surface requires no second confirmation.

### Destination and route safety

Always expose the verdict's applicable scope choices, including its non-mutating exit. Before showing
execution and afterward modifiers or accepting a fixing scope as write authorization, resolve one
unambiguous writable destination that owns the reviewed after endpoint or working-tree state. A named
worktree can establish ownership. A commit or range requires a current checkout whose branch and HEAD
relationship proves it owns the endpoint. Never infer it from cwd, invent a snapshot or copy protocol,
or rewrite detached history.

If no single destination is provable, render a reduced close containing only the applicable Fix scope
group and its scope default, and explain that a fixing choice requires a destination before route and
re-review choices can be confirmed. `4` for `needs-rework`, or `1` for `approve-with-changes`,
immediately returns the unchanged implementation. On `approve-with-changes`, `yes` also returns
unchanged. On `needs-rework`, `yes` records default scope `1` as the pending scope and requests the
destination. Any fixing scope response likewise records only that pending scope, asks for the
destination, and stops without write authorization.

After ownership is resolved, atomically consume the pending scope, derive the eligible route default
and afterward default, and install the resulting complete code as both the new displayed default and
the pending normalized selection. Thus pending scope `2` becomes pending `2-A-R` when isolation is
eligible or `2-I-R` when it is not. Render the complete surface and require a new confirmation. This
exceptional safety round trip does not turn the earlier scope response into permission to write.

Offer `A` only when an isolated executor exists, the reviewed after endpoint is committed, the
destination is clean at that exact endpoint, and an isolated checkout can be created. Otherwise expose
only `I` and state why isolation is unavailable.

If the isolated executor becomes unavailable or isolated-checkout creation fails after confirmation
but before the isolated writer begins, first prove the destination identity is still unchanged and
leave any checkout or result unapplied. Then render a fresh inline-only surface whose pending and
displayed default preserves the confirmed scope and afterward choice while replacing only `A` with
`I`—for example, `2-A-N` becomes `2-I-N`. Require a new explicit confirmation; never silently fall
back or reset the package to the original defaults.

Do not use that fallback for other failures. Destination drift requires a fresh implementation review.
Once the isolated writer begins, blocked or partial work, failed primary inspection or verification,
or an incomplete or unverified returned package stops and remains unreviewed under the complete-package
rule; it does not present the inline route fallback.

At review time capture HEAD, staged diff, unstaged diff, and reviewed untracked paths and contents.
Immediately before either route writes, compare the complete current identity to that verdict evidence.
Any drift stops without mutation and requires a fresh review. For isolation, repeat the clean exact-HEAD
guard before checkout creation and immediately before integration. New HEAD, staged, unstaged, or
untracked state leaves the returned result unapplied.

### Remediation, independence, and re-review

The selected finding classes are the complete remediation package. Inline execution is performed by
the primary session in the resolved destination. Isolated execution starts from the exact reviewed
endpoint, confines its writer to the isolated checkout, and returns a reviewable commit or diff plus
verification evidence. The primary session inspects and verifies that result before integration.
Same-pattern observations outside the selected package return as observations rather than silently
widening scope.

A blocked or partially applied package stops and reports its state. It never triggers re-review. When
`N` is selected, a complete applied package stops with an explicit unreviewed-result statement.

When `R` is selected, run the complete implementation-review procedure from the original base through
the entire remediated result, including every changed path, not just the fix delta or files named by
the findings. Reload effective doctrine and governing design, inspect surrounding code, run applicable
gates, cover every soundness and groundedness axis, and choose a fresh verdict. Prior findings are
evidence, not reduced scope.

“Independent review” means rerunning the complete review judgment from the full evidence rather than
accepting the implementation writer's self-report. A separate provider, model, or reviewing agent is
not required. Every fresh material verdict renders a fresh text action close and authorizes no
unattended write; a fresh `approve` returns automatically.

### Package and lineage

Update Inspector's router description and flow, `verbs/review.md`, implementation kind doctrine,
behavioral fixtures, responsibility spine, README, and pack wording together. The router frontmatter
must advertise the confirmed implementation-remediation loop while naming `revise` and `refine` as
document mutation verbs. Do not add a public verb, setup behavior, project store, hook, or
harness-specific API.

This spec supersedes the presentation contract in
`.records/specs/2026-09-03-inspector-implementation-review-action-loop.md` when accepted and published.
Its non-presentation safety and review requirements are carried forward above; implementation must not
continue to depend on the superseded spec.

## Verification

Extend Inspector's behavioral fixtures to prove:

- **Rendered surfaces:** each material verdict emits only its applicable numbered scopes, preserves exact
  meanings and defaults, uses `A/I/R/N` consistently, identifies the inline-only default when
  isolation is unavailable, labels approve-with-changes modifiers as conditional on fixing, and
  contains no checkbox syntax, native-control promise, or Enter claim. `approve` emits no action
  surface and returns automatically.
- **Parser:** compact, uniformly separated, and mixed-separator forms normalize identically; outer
  whitespace is ignored while repeated punctuation, trailing punctuation, unmatched input, and
  unavailable or out-of-order codes are rejected by a whole-response match. Number-only responses
  acquire the displayed modifier defaults; direct valid codes confirm once; `yes` selects the complete
  default when nothing is pending and the exact pending code after a reflected natural-language
  adjustment. Prove separately that reduced-surface `yes` returns unchanged for
  `approve-with-changes`, records only pending scope `1` for `needs-rework`, and cannot authorize a
  write; conflicts, unknown codes, rejection, and cancellation write nothing.
- **Stateful routes:** derive destination and isolation eligibility from real temporary Git state.
  With ambiguous ownership, prove both verdicts' no-change scopes return without a destination while
  a fixing scope creates only a pending scope and cannot write. After resolution, prove that scope is
  consumed into the exact complete pending code and the full surface requires fresh confirmation.
  Inject a post-confirm executor or isolated-checkout-creation failure before writer start and prove
  no inline write occurs without a new selection, then prove the replacement preserves scope and
  afterward while changing only `A` to `I`. Separately inject destination drift, writer-started partial
  work, and failed primary verification; prove they stop without presenting inline fallback. Inject
  failure on the second finding of a multi-finding package and prove the partial result does not
  re-review.
- **Drift:** at both isolated-checkout creation and integration, independently plant changed HEAD,
  staged, unstaged, and untracked destination state; each must block application and leave the
  returned result unapplied. Preserve the dirty same-path/different-content inline case.
- **Full population:** use at least two changed paths. Put a material mutation outside the selected
  fix path and prove the full same-base review finds it while a fix-delta or path-limited mutant fails.
- **Regression:** document review, `revise`, `refine`, status custody, kind resolution, setup,
  complexity evidence, exact verdict mapping, and public inventory remain unchanged.

Red-prove the response grammar defaults and each failure guard one at a time: plant one defect, count
it, require the relevant assertion to fail, restore, and confirm byte identity. Run:

```sh
skills/inspector/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
skills/architect/scripts/ground-check.sh \
  "$(git rev-parse --show-toplevel)" \
  .records/specs/2026-09-03-inspector-textual-implementation-review-action-close.md
git diff --check
```
