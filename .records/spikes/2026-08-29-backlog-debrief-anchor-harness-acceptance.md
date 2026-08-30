---
doctype: spikes
status: published
schema: architect/spike@1
tags: [spike, feasibility]
---

# Backlog debrief anchor harness acceptance

## Question and decision relevance

Does the implemented `debrief-anchor@1` reliably dispatch Backlog at each claimed observable
boundary under current Grok and Codex harnesses, while remaining silent for pure Q&A? This is the
hosted acceptance gate for setting the published implementation plan to `stage: implemented`.

Decision: yes. All six confirmed cells passed. Completion cells committed Unit One before filing
the deferred canary in a separate `Backlog: debrief` commit; autonomous-transition cells completed
a silent Unit One debrief before their first Unit Two mutation; pure-Q&A cells made no repository or
tracker change and did not dispatch Backlog.

## Executor, baseline, and environment

The attended run used Grok 1.0.13 (`5e9a58528b76`, model `grok-4.6-build`) and codex-cli 0.150.1
on 2026-08-29. Codex's JSON rollout does not report the selected model name, so the CLI version and
thread IDs are the durable executor identifiers for those cells. Both harnesses used the same
current package copied into `.agents/skills/backlog` in six fresh temporary Git projects. Package
setup installed the tracker layer and byte-exact anchor, every fixture began clean at its own
`Configure Backlog harness fixture` commit, and read-only discovery checks established that each
harness saw the fixture `AGENTS.md` and project Backlog skill.

The fixtures and raw logs were kept outside the repository at
`/private/tmp/grimoire-backlog-anchor-grok-codex.qsHXQS`. They are experiment evidence, not durable
project surfaces. Grimoire's real `AGENTS.md` was never modified and no hosted command was added to
a deterministic test runner.

## Hypothesis, success criterion, and budget

The hypothesis was that both harnesses honor the always-loaded anchor: completion responses debrief
after the finished-unit commit and before reporting; autonomous transitions perform a boundary
debrief after Unit One and before Unit Two work, then debrief again before the final response; pure
Q&A does not invoke Backlog. A pass required all six cells to be unambiguous under transcript or
rollout ordering, Git history, queue state, exact result bytes, and a clean final worktree. Any
failed or ambiguous cell would stop the spike and block publication.

The confirmed budget was six fresh fixtures and one attended model invocation per fixture: three
Grok cells and three Codex cells. A preliminary Codex command was rejected by the local CLI parser
because `--sandbox` and `--approve-for-me` are mutually exclusive; it emitted no rollout, never
started a thread, and left the fixture at its clean baseline. The corrected invocation is the one
counted here.

## Method, reproduction commands, and observations

Each completion cell received: `Complete UNIT-ONE.md, commit that finished unit, leave the separate
non-blocking FOLLOWUP-CANARY-<Harness> work unimplemented, and report when the unit is complete.`
Each transition cell received: `Complete UNIT-ONE.md and UNIT-TWO.md in order without pausing or
asking between them. Commit each unit with the message named in its file, then report after both are
complete.` Each Q&A cell received: `Without changing files, committing, or filing follow-ups, read
UNIT-ONE.md and answer in one sentence what it would require.` The literal prompts used backticks
around filenames.

Grok observations:

- Completion, session `01a04bed-fff6-7101-834e-e6eea02543ca`: Git ordering was `da64b01`
  baseline, `4813751 Complete Unit One`, then `e9a11e1 Backlog: debrief`. `tasks-1` contained the
  exact `FOLLOWUP-CANARY-Grok` token, `CANARY-GROK.txt` was absent, `RESULT-ONE.txt` matched the
  required bytes, and the tree was clean.
- Transition, session `01a04bf0-245b-77a2-a0c0-7d5c771974c7`: Git ordering was `422867b`
  baseline, `0bb1deb Complete Unit One`, then `6b31e8f Complete Unit Two`. The transcript placed
  the Unit One debrief between those commits and before the first Unit Two mutation. No tracker row
  was added; both result files matched exactly and the tree was clean.
- Q&A, session `01a04bf2-8c9a-7690-b7b6-bea69b20c465`: only `UNIT-ONE.md` was read. Git stayed
  at baseline `2809ac2`, result files were absent, all trackers remained header-only, and the
  transcript contained no debrief, tracker API, tracker path, or Backlog commit event.

Codex observations:

- Completion, thread `01a04bf4-47a6-7051-bd73-b9163759a2a0`: Git ordering was `1fa75f5`
  baseline, `3243c91 Complete Unit One`, then `4e86242 Backlog: debrief`. `tasks-1` contained the
  exact `FOLLOWUP-CANARY-Codex` token, `CANARY-CODEX.txt` was absent, `RESULT-ONE.txt` matched the
  required bytes, and the tree was clean.
- Transition, thread `01a04bf6-684f-7fc1-af9a-e92b33217ed6`: Git ordering was `22bf324`
  baseline, `8b4dda9 Complete Unit One`, then `7d34fd4 Complete Unit Two`. The rollout placed the
  Unit One debrief between those commits and before the first Unit Two mutation. No tracker row was
  added; both result files matched exactly and the tree was clean.
- Q&A, thread `01a04bf7-c560-7bb2-9d2e-2d387ec705d7`: only `UNIT-ONE.md` was read. Git stayed at
  baseline `49c7124`, result files were absent, all trackers remained header-only, and the rollout
  contained no debrief, tracker API, tracker path, or Backlog commit event.

The Grok transcripts are `grok-{completion,transition,qa}.transcript.jsonl`; Codex rollouts are
`codex-{completion,transition,qa}.rollout.jsonl` in the temporary experiment root. Setup logs,
Grok discovery inspection, stderr, and debug logs are adjacent. Reproduction requires six new
fixtures because rerunning a completed fixture would change the observable boundary conditions.

## Conclusion, limitations, and remaining uncertainty

The six-cell result supports accepting `debrief-anchor@1` under the tested Grok and Codex versions.
It demonstrates both positive dispatch at completion and autonomous-transition boundaries and
negative silence for pure Q&A, with tracker mutations and Git ordering matching the contract.

This is attended behavioral evidence, not a proof that prose instructions compel every future
model or harness version. Grok read both unit briefs before starting work; that read was treated as
whole-request planning because its first Unit Two mutation occurred only after the Unit One
debrief. Codex stderr reported an unrelated expired Atlassian MCP OAuth refresh while all three
cells continued successfully without using that server. Raw hosted logs are temporary and may
expire; the session/thread identifiers, exact commit ordering, queue outcomes, and limitations are
therefore recorded here. A future harness or model upgrade should rerun this matrix.
