---
doctype: spikes
status: published
schema: architect/spike@1
tags: [spike, feasibility]
---

# Callback anchor dispatcher harness acceptance

## Question and decision relevance

Do Grok 1.0.13 and Codex CLI 0.150.1 reliably honor a package-owned
`callback-anchor@1` at `work-unit-boundary@1`, run an explicit registry dispatcher, execute
ordered agent instructions and skill commands, continue after advisory callback failure, halt
immediately after blocking callback failure, and remain silent for pure Q&A?

Decision: yes, for the tested harness versions and prototype contract. All eight confirmed hosted
cells passed, so the result supports specifying a dedicated callback skill and revising Backlog to
register `/backlog debrief` as a subscriber. It does not authorize production implementation by
itself.

## Executor, baseline, and environment

The attended run used Grok 1.0.13 (`5e9a58528b76`, model `grok-4.6-build`) and codex-cli 0.150.1
on 2026-08-29. Codex JSON rollouts do not report a model name, so CLI version and thread IDs are
the durable executor identifiers. Each cell began in a fresh temporary Git fixture with the same
prototype anchor, callback provider, explicit registry, callback instructions, and current Backlog
package copied into `.agents/skills/backlog`. Backlog setup installed a one-queue tracker layer;
the callback anchor then replaced Backlog's direct debrief route in the fixture front door.

The prototype, fixtures, generated state, and raw logs live outside the repository under
`/private/tmp/grimoire-callback-anchor-spike.zy2Pj6`. They are disposable experiment evidence.
Grimoire's real `AGENTS.md` was not changed by the spike, no production callback skill was added,
and no hosted invocation was added to a deterministic test runner.

The first Grok command requested a nonexistent `workspace-write` profile. It started no session,
produced no behavioral evidence, and left the fixture unchanged; the charter's one infrastructure
retry was used with Grok's configured default. Codex stderr reported an unrelated failed Atlassian
MCP OAuth refresh in all four cells, but none used that server and all completed normally.

## Hypothesis, success criterion, and budget

The hypothesis was that both harnesses would treat the front-door anchor as an automatic event
contract: dispatch exactly at a coherent work-unit boundary, process the returned frames in order,
apply each callback's own done condition, and enforce its declared failure policy. Completion had
to commit the unit before the instruction callback and `/backlog debrief`; autonomous transition
had to close Unit One's boundary before the first Unit Two mutation; pure Q&A had to avoid dispatch
and all mutation; failure-policy had to report an advisory refusal and continue, then report a
blocking refusal and halt before the next callback.

A pass required all eight cells to be unambiguous from hosted transcripts or rollouts, exact files,
tracker state, Git order, and final worktree state. Any behavioral failure or genuine ambiguity
would stop the spike. The confirmed budget was four scenarios in each harness, one hosted
invocation per fixture, plus one no-behavior infrastructure retry if needed. The spike stopped after
all eight cells passed.

## Method, reproduction commands, and observations

The disposable Bash provider exposed a fixed event catalog containing only
`work-unit-boundary`, accepted explicit `instruction` or `skill-command` registrations, rejected
conflicting subscriber registrations and unknown events, supported `first`, `last`, `before`, and
`after` placement, and emitted framed `callback-dispatch@1` output without executing actions. Its
deterministic harness exercised register, list, relative move, ordered dispatch, conflict refusal,
and unknown-event refusal. That harness printed `provider prototype: ALL GREEN`; ShellCheck passed
for the provider, provider test, and fixture builder.

Grok observations:

- Completion, session `01a04f20-c5dc-73b3-b9bd-cf981f68f3d7`: Git order was `50d87f9`
  baseline, `e50a06a Complete Unit One`, `b112918 Callback: completion audit`, then `9d23097
  Backlog: debrief`. The exact deferred canary became `tasks-1`, its implementation remained
  absent, result and callback marker bytes matched, and the tree was clean.
- Autonomous transition, session `01a04f22-327b-78e2-a1dd-aa88ae0f32eb`: Git order was
  `44e61e6` baseline, `bc5de5a Complete Unit One`, `fd4baed Callback: Unit One boundary`,
  `e196094 Backlog: debrief`, `09004e1 Complete Unit Two`, then `e0e0fe6 Callback: Unit Two
  boundary`. This proves the first boundary closed before Unit Two. The tree was clean.
- Pure Q&A, session `01a04f24-fdcd-7eb2-8d08-be8c2a14059d`: only `UNIT-ONE.md` was read.
  Git stayed at baseline `bb7856a`; no result, callback marker, tracker row, dispatch, or mutation
  appeared.
- Failure policy, session `01a04f25-6a25-79d1-9d0a-7f6ace02fb00`: Git order was `a40ab5a`
  baseline, `db77326 Complete Unit One`, then `71b99b3 Callback: advisory continued`. Grok
  reported `reason=probe-advisory-failure`, continued to the proof commit, reported
  `reason=probe-blocking-failure`, kept the boundary pending, and did not read or execute the
  fourth callback. `AFTER-BLOCK.txt` was absent and the tree was clean.

Codex observations:

- Completion, thread `01a04f26-af51-72e3-a2bd-14f58f71bd4d`: Git order was `846599c`
  baseline, `b423a82 Complete Unit One`, `7278d0f Callback: completion audit`, then `7327c88
  Backlog: debrief`. The exact deferred canary became `tasks-1`, its implementation remained
  absent, result and callback marker bytes matched, and the tree was clean.
- Autonomous transition, thread `01a04f28-6c63-7aa0-aced-ff2d5479375d`: Git order was
  `e978727` baseline, `0a0b3ee Complete Unit One`, `726db10 Callback: Unit One boundary`,
  `090668c Complete Unit Two`, then `acf31e0 Callback: Unit Two boundary`. This proves the first
  boundary closed before Unit Two. Backlog found no leftover, tracker state remained empty, and the
  tree was clean.
- Pure Q&A, thread `01a04f2a-6bdb-7831-98b6-9f9438040398`: one read-only command inspected
  `UNIT-ONE.md`. Git stayed at baseline `9dacd8d`; no result, callback marker, tracker row,
  dispatch, or mutation appeared.
- Failure policy, thread `01a04f2a-d44f-7542-98f8-e067fca217aa`: Git order was `fa139ea`
  baseline, `ce7376d Complete Unit One`, then `d52fbc5 Callback: advisory continued`. Codex
  reported both probe refusals with the correct policies, kept the boundary pending, and did not
  read or execute the fourth callback. `AFTER-BLOCK.txt` was absent and the tree was clean.

Raw evidence is named `grok-{completion,transition,qa,failure}.transcript.jsonl` and
`codex-{completion,transition,qa,failure}.rollout.jsonl` in the temporary root, with adjacent stderr
logs. Reproduction requires fresh fixtures because completed boundaries and tracker rows alter the
conditions being tested.

## Conclusion, limitations, and remaining uncertainty

The eight-cell result supports the callback design: current Grok and Codex harnesses can reliably
detect the tested boundary, follow one level of dispatcher indirection, preserve explicit callback
order, invoke an installed skill command, distinguish advisory from blocking failures, halt
fail-fast, and exclude pure Q&A. The next design step is to write the callback skill specification
and revise Backlog's published documents so Backlog becomes an explicit subscriber rather than the
owner of the front-door anchor.

This is attended behavioral evidence, not a guarantee across future model or harness versions.
Event detection remains prose-mediated and was tested only for `work-unit-boundary@1`; the fixed
catalog should not expand without another event-specific reliability test. The shared fixture
builder copied `FOLLOWUP-CANARY-CALLBACK.md` into transition fixtures as well as completion
fixtures. Grok treated that visible deferred item as a legitimate Unit One leftover and filed it;
Codex left it unrouted. That difference does not obscure the decisive transition evidence because
both histories place the Unit One callback boundary before Unit Two, but a future rerun should omit
the canary from transition fixtures for a cleaner tracker comparison. Raw hosted logs are temporary
and may expire, so the durable evidence is the executor identifiers, commit sequences, tracker
outcomes, exact file assertions, and limitations recorded here.
