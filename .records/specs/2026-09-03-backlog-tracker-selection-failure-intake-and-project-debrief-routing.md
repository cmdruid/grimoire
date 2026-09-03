---
doctype: specs
status: published
schema: architect/spec@1
tags: [backlog, trackers, setup, anchor]
---

# Backlog tracker selection, failure intake, and project debrief routing — Spec

Decision: → `adr/2026-09-03-make-backlog-anchor-a-managed-project-debrief-route.md`

## Problem

Backlog's four default queues mix action, established problems, qualitative observations, and
repeatable responses, but they have no precise home for unresolved test, build, and tooling
failures. Filing those sightings as `issues` asserts a conclusion before diagnosis; filing them as
`feedback` makes qualitative experience compete with operational evidence. Repeated flakes then
either disappear with the session or create duplicate, low-signal rows.

First-time setup also installs all queues unconditionally. Projects can change the population only
after initialization, even when they already know which follow-up classes they use. At the same
time, Backlog's optional front-door command installs only a static discovery pointer. It cannot opt
a project into the end-of-work debrief behavior that prevents follow-ups from being lost.

## Goal

Backlog initializes a user-selected set of five packaged trackers, with safe unattended defaults and
resumable setup, and routes operational failure sightings separately from qualitative feedback.
Projects can explicitly install, refresh, or remove a project-scoped debrief route whose absence or
failure never impairs tracker setup or manual Backlog use.

## Approach

Add `failures` as the fifth packaged default and treat the tracker set as five related lifecycle
lanes rather than a strict partition of subject matter:

| Tracker | Stored information | Representative example |
|---|---|---|
| `tasks` | An accepted, concrete project outcome | Replace a quadratic dependency scan. |
| `issues` | An established project problem, risk, or limitation | Benchmarks confirm a 30% regression. |
| `failures` | An unresolved operational sighting from tests, builds, or project tooling | A test failed once in CI and passed on retry. |
| `feedback` | A qualitative project-development observation | Setup works, but its recovery message is confusing. |
| `routines` | A repeatable response to a recognizable trigger | On a suite flake, retain the seed and compare retry output. |

First-time attended setup presents all five as a multi-select with every tracker selected. Explicit
`--trackers` input bypasses that selection; unattended setup chooses all five. Existing initialized
layers retain their incumbent population, including projects that have only the former four
defaults.

Replace Backlog's markerless discovery anchor with the managed project route defined by the linked
ADR. First-time attended setup offers that route after tracker selection and defaults to no
front-door change. Bare `/backlog anchor` manages the route independently. `--debrief` is the
non-interactive opt-in for either entry point.

This design rejects three broader alternatives:

- Broadening `feedback` to include every flake keeps four defaults but erases the difference between
  qualitative friction and operational evidence.
- Adding `failures` unconditionally to existing installations violates the established rule that
  initialized setup preserves tracker population.
- Making setup install the route automatically treats tracker persistence as authorization for an
  always-loaded instruction. The explicit prompt and flag preserve user choice.

Setup deliberately retains its existing incremental, resumable write model instead of staging and
renaming an entire tracker layer. Existing projects can already contain valid prehistory prefixes,
and the current custody and recovery checks reason about individual canonical paths. A small durable
selection intent extends that model without introducing a second layer swap protocol or changing
the `history.tsv` initialization boundary.

## Mechanism

### Tracker contracts

The packaged tracker order is `tasks`, `issues`, `failures`, `feedback`, `routines`. Add
`failures.md` to `skills/backlog/suggestions/` and sharpen the other suggestion files so the installed
`.trackers/DEBRIEF.md` presents these rules:

- `tasks` stores one cold-actionable outcome per row.
- `issues` stores an accepted negative condition, risk, or limitation, with the evidence needed to
  revisit it.
- `failures` stores unexpected or intermittent test, build, and project-tool behavior that remains
  unresolved after the current work. Expected red-green failures and failures resolved during the
  current objective are not leftovers. One row represents one failure family, not one execution.
- `feedback` stores concrete qualitative observations about usability, clarity, perceived
  performance, and development friction when a remedy may plausibly belong in the project.
  The remedy does not need to be known at capture time. A clearly reusable-skill-owned observation
  still goes to that skill's home feedback channel; a one-session preference or vague reaction is
  not durable project state.
- `routines` keeps its trigger, repeated response or rediscovered decision, cost or risk, evidence,
  and observable completion-boundary requirements.

Suggestion changes apply when setup or tracker administration creates a prompt section. Reconcile
does not rewrite an initialized project's incumbent `.trackers/DEBRIEF.md` prose.

Debrief continues to exclude the current objective, resume state, and ordinary in-flight work, then
applies the remedy-owner cut before project routing. Within the project boundary it routes by the
state of the knowledge: chosen action to `tasks`; established negative condition to `issues`;
unexplained operational sighting to `failures`; qualitative experience to `feedback`; repeatable
trigger-response candidate to `routines`. One leftover enters one queue unless it has genuinely
distinct future dispositions.

Before creating a failure row, debrief pages the open `failures` population needed for comparison.
It treats the affected component or command, stable failure signature, and observed behavior as the
family identity. A matching row is sharpened with `update` and its evidence is replaced by the
strongest current reference; otherwise debrief calls `create`. Matching is routing judgment, not a
new provider schema or machine-generated fingerprint. The tracker@2 table and history schemas do
not change.

Performance follows the same knowledge-state rule: a subjective slow experience is `feedback`; a
timeout, hang, or unexplained benchmark result is `failures`; a confirmed regression is `issues`;
and an accepted optimization is `tasks`.

### First-time tracker selection

`/backlog setup` distinguishes initialized reconciliation from first initialization before asking a
question:

- An initialized layer preserves its queue files and prompt population. Setup neither presents the
  tracker selector nor adds `failures`. `/backlog tracker add failures` installs the packaged
  suggestion for an existing project.
- An attended first setup presents the five packaged stems as a multi-select, all selected, and
  requires at least one selection.
- An unattended first setup with no selection installs all five.
- `/backlog setup --trackers <comma-separated-stems>` supplies the exact selection and bypasses the
  multi-select. Values must be nonempty, unique members of the five packaged stems in any input
  order; the helper normalizes them to packaged order. The option is valid only while initializing.
- `--debrief` composes with either selection path but does not change tracker selection.

The verb resolves interaction. `skills/backlog/scripts/backlog-setup.sh` remains deterministic and
receives the exact normalized list. After creating a previously absent `.trackers` directory, the
helper atomically writes temporary `.trackers/.setup-selection` as its first durable file, before
`.gitkeep`, the provider, README, prompt, or any queue. A crash that leaves only an empty directory
is restartable as absent setup and may ask for selection again. Once any other setup artifact exists,
the intent file is the minimum durable evidence that distinguishes a deliberately omitted queue from
one not yet created after interruption.

Resumed setup uses the recorded selection; a conflicting supplied list refuses. Setup writes
`history.tsv` only after the selected queues, prompt sections, provider, and README validate, then
validates the complete initialized layer and removes the intent file. If a crash occurs after
`history.tsv` is durable but before intent removal, status reports a cleanup-recovery state rather
than ordinary initialized state. The next setup validates that the queues and prompt population
exactly match the recorded selection and that the remaining canonical files are current, then
removes the intent without prompting or rewriting incumbent bytes. A mismatch refuses as ambiguous.
No successful installation retains a new configuration or receipt file.

The intent file has exactly two lines and no timestamp:

```text
schema=backlog/setup-selection@1
trackers=tasks,issues,failures,feedback,routines
```

The second line contains the selected stems in packaged order. Setup accepts only a regular,
non-symlink file with one valid schema line and one nonempty tracker line; any other incumbent
refuses as ambiguous state.

A valid pre-feature resumable prefix with no selection intent retains the old setup contract: it
resumes toward the former ordered set `tasks`, `issues`, `feedback`, `routines`. This is the only
intent that can be reconstructed for such a prefix because the new setup path never writes another
artifact before selection intent. A supplied `--trackers` list that differs from that reconstructed
selection refuses. Ambiguous or malformed partial state continues to refuse. `history.tsv` remains
the initialization boundary; a valid intent beside it is only the bounded cleanup-recovery state
described above.

Queue-aware code must stop hard-coding four stems. The `--list` output, prompt ordering, prehistory
validation, setup tests, README examples, and package documentation use the five-stem catalog while
runtime catalog and custom tracker behavior remain extensible. Update `skills/backlog/SKILL.md`,
`skills/backlog/verbs/setup.md`, `verbs/anchor.md`, `verbs/debrief.md`, `verbs/tracker.md`, and the
repository `README.md` so their setup, anchor, and taxonomy contracts agree with this mechanism.

### Project debrief route

Add `agents-route.md` to `skills/backlog/templates/` as the package-owned route template under
`## Skill routes (self-registered)`. Retain `skills/backlog/templates/agents-pointer.md` only as the
byte-exact legacy input recognized during migration; no current path emits it:

```markdown
<!-- skill:backlog BEGIN built-against:VERSION -->
### /backlog — capture project follow-ups
Route: after substantive project work, if unresolved project-owned follow-ups remain, invoke
`/backlog debrief` once before the final response or a healthy reset. Skip pure Q&A, routine status,
ordinary success with no leftovers, and child/delegate contexts; the custodial caller routes their
byproducts. Reusable-skill feedback never enters project trackers. Project tracker state lives in
`.trackers/`; read `.trackers/README.md` for its local contract.
Edges: produces `tracker`.
<!-- skill:backlog END -->
```

The implementation may line-wrap the final template, but those trigger, exclusion, custody,
owner-boundary, discovery, and edge statements are normative. The route is advisory: a skipped or
failed debrief does not change the completed work's outcome.

`skills/backlog/scripts/trackers-anchor.sh` adopts the managed-block mechanics of `skill-feedback`
without sharing a runtime dependency. It accepts `preview` and `apply`, install/update and removal modes, and a
preview SHA-256. It validates the exact Git root, attached branch, initialized tracker@2 layer,
current installed provider and managed README block, safe regular `AGENTS.md`, one reserved heading,
and at most one well-formed owned block outside Markdown fences. Install appends the reserved
heading when absent, inserts within it when present, or replaces only the existing owned span.
Removal deletes only that span and leaves the heading and all other bytes intact.

Install and refresh require the initialized, current tracker layer because their route would point
at that layer. Removal validates only root and front-door custody and the managed block; it remains
available when `.trackers` is missing, malformed, or stale. Bare anchor with such a layer may offer
removal for an incumbent block but must report the recovery requirement instead of offering refresh.

The verb scans outside the owned block for a competing instruction that routes project follow-ups
to another command or store. Interactive install quotes the conflict and asks for cutover approval;
`--debrief` refuses and asks rather than silently overriding it. A malformed or ambiguously owned
block always refuses.

When `AGENTS.md` contains the byte-exact prior `## Project trackers` heading and canonical paragraph,
the install candidate removes that section and adds the managed route in one atomic write. A
confirmed preview or explicit `--debrief` authorizes only that exact migration. Any customized
project-tracker prose remains byte-identical, even when it mentions `.trackers/README.md`.

Bare `/backlog anchor` first computes current state and the candidate diff. Without a block it shows
that diff and offers install or cancel; with a valid block it shows the applicable diff and offers
refresh, remove, or cancel. The selected action is confirmation of the displayed digest, so there is
no second confirmation prompt. `/backlog anchor --debrief` directly runs
install or refresh, and `/backlog anchor --remove` directly runs removal. Interactive mutations show
the complete diff before the choice. The explicit flags are full consent
to their canonical mutations and skip the choice and confirmation prompts, but never the validation,
digest, concurrency, or competing-route gates.

### Setup and commit custody

After first-time tracker initialization commits or returns its exact `.trackers` paths, attended
setup computes and shows the candidate anchor diff, then offers `Enable the project debrief route?`,
defaulting to no. That choice confirms the displayed digest. `--debrief` selects yes without the
prompt. If selected, setup invokes the same anchor procedure as the standalone verb; it does not
duplicate front-door logic.

Tracker-layer and front-door mutations remain separate operations and separate path-scoped commits.
An anchor refusal or commit failure leaves successful tracker setup intact and reports both outcomes.
Inside an announced configuration sweep, both operations return their complete path sets to the
sweep's custody instead of nesting commits. Initialized setup never offers the route; an explicit
`--debrief` may install or refresh it after ordinary reconciliation.

Repair, migration, provider calls, tracker add/remove, debrief, curate, and setup without a selected
route never inspect `AGENTS.md` as a prerequisite or mutate it. The real Grimoire `AGENTS.md` is
outside every implementation and test write.

## Verification

Extend the Backlog fixture harness with the following red-first cases:

- Fresh attended selections for one, several, and all five trackers; rejection of zero, duplicate,
  unknown, empty, or initialized-layer `--trackers` values; unattended default installation of all
  five; and canonical prompt ordering.
- Interrupted setup before intent creation, immediately after intent creation, between every later
  artifact write, and after `history.tsv` but before intent cleanup; exact selection recovery through
  `.setup-selection`; conflicting resume refusal; cleanup-state validation and intent removal; and
  compatibility recovery of a valid four-default prefix without an intent file.
- Initialized four-tracker layers remain byte-identical on setup and can opt into the packaged
  `failures` suggestion through tracker administration.
- Routing fixtures distinguish performance feedback, unexplained timeouts, confirmed regressions,
  accepted optimizations, expected red tests, resolved failures, and reusable-skill-owned feedback.
  Repeated instances update one matching failure family while unrelated signatures create separate
  rows.
- Bare anchor choices, `--debrief`, `--remove`, setup opt-in/default-off behavior, and separate commit
  custody. Anchor failure after successful setup leaves the tracker commit and initialized layer
  intact.
- Managed-block creation, insertion under an existing reserved heading, refresh, removal,
  idempotence, fenced examples, malformed and duplicate markers, unsafe and symlink paths, stale
  digests, concurrent edits/deletions, file-mode preservation, and bytes outside the block.
- Exact migration of the old canonical project-tracker pointer; preservation of customized pointer
  prose; and refusal of an unapproved competing behavioral route, including under `--debrief`.
- Package and repository guards prove setup without route selection, repair, migration, runtime,
  queue administration, pack configuration, and every real Grimoire path remain front-door neutral.
  Each absence guard must also have a red proof in a throwaway fixture: temporarily inject the
  forbidden anchor invocation or managed block into the guarded surface, demonstrate that the guard
  fails, then restore the fixture bytes. These proofs never mutate Grimoire's real `AGENTS.md`.

Run the package and repository gates:

```sh
bash skills/backlog/scripts/tests/run.sh
bash scripts/tests/backlog-provider-contract-test.sh
bash scripts/tests/project-layer-anchor-contract-test.sh
bash scripts/tests/canonical-provider-parity-test.sh
bash skills/skill-builder/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh
shellcheck -S warning skills/backlog/scripts/backlog-setup.sh \
  skills/backlog/scripts/trackers-anchor.sh
git diff --check
```

The feature is complete when these gates pass; fresh setup produces exactly the selected tables and
no durable intent residue; existing layers preserve their population; debrief routes failure and
feedback examples as specified; and only an explicit, validated anchor choice changes a throwaway
project's `AGENTS.md`.
