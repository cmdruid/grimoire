---
doctype: specs
status: draft
schema: architect/spec@1
tags: [workstream, simplification, hard-cut]
---

# Workstream essential lifecycle simplification — Spec

This specification refines and composes with
→ `specs/2026-08-31-workstream-control-surface-lifecycle-hooks-and-stream-history.md`,
→ `specs/2026-09-02-workstream-lean-runtime-and-resumable-shipping.md`, and
→ `specs/2026-09-03-workstream-worktree-only-runtime-and-primary-checkout-safety.md`.
Those specifications remain authoritative for worktree custody, resumable shipments, landing
authority, primary-checkout safety, delivery recovery, and exact teardown. This document replaces
their execution-mode, cadence, stream-history, hook-placeholder, gate-classification,
compatibility-helper, and migration-retention requirements.

## Problem

Workstream's safety kernel now works, but several speculative or duplicative mechanisms surround
it. They increase the number of concepts an agent must understand without changing a useful
outcome:

- `ship-cadence` is parsed, validated, fingerprinted, projected, and reconfigured, but no runtime
  transition implements any of its three values.
- `mode: delegate|manual` does not select an executor. Delegate mode is the ordinary loop; manual
  mode adds `phase-set` transitions and human stops around the same work.
- `.streams/history.tsv` duplicates facts already available from Git and the per-stream tracker.
  Its append, sequence, setup, repair, validation, metadata commit, generated-path gate exception,
  and special rebase-conflict merge all exist for a file explicitly declared non-authoritative.
- Empty default hooks still produce compiled fingerprints and `not-applicable` receipt rows.
  `parallel-preferred` is stored as policy but always executes serially.
- Gate classes, selector manifests, environment variables, selector receipts, and `gate-none`
  form a second CI protocol even though the host's selected command is already the actual gate.
- Three older helper scripts and several CLI operations have no live agent-facing caller. Their
  tests preserve the secondary interfaces rather than Workstream behavior.
- The legacy `.workstreams` converter has no exit condition, so a bounded bridge can become a
  permanent subsystem.

The cost is observable at this specification's baseline, `HEAD` `4727ffc`: the agent-facing
Workstream surface is 416 lines across `SKILL.md` and 13 verb files; the primary runtime helper is
2,604 lines; and the Workstream harness contains 2,385 lines across 30 files. These populations are
not targets by themselves. They identify where the above mechanisms live; custody, transaction,
and delivery branches are excluded from the critique merely because they are large.

The root problem is policy/state multiplication: every inert choice is copied through prose,
configuration, runbook generation, tracker grammar, fingerprints, recovery, setup, repair, and
tests. Local simplification is therefore insufficient. Each rejected concept must disappear
end-to-end.

## Goal

Make Workstream one guarded path: create or resume a registered worktree, complete coherent units,
run an explicitly configured hook when one exists, prepare one immutable shipment, run one exact
host-selected gate command, deliver without force, and either recycle or close.

The final package has no execution mode, cadence policy, Workstream history ledger, empty-hook
receipts, concurrency preference, gate taxonomy, test-only public helper operation, or expired
compatibility script. It retains every safety property whose removal could corrupt work, duplicate
an external effect, or mutate the wrong checkout.

## Approach

**Chosen: an end-to-end hard cut around the essential lifecycle.** Remove each rejected concept
from its public prose, generated artifacts, parser, state machine, runtime output, setup/repair
surface, and tests in the same change. Removed commands and options receive the ordinary unknown
command or option error; there are no deprecation aliases, dormant fields, readers for old current
formats, or conversion-on-read paths.

Configuration becomes sparse and outcome-bearing. `landing` is the only scalar default. A hook
exists only when its project block has a non-whitespace body, and its only policy is whether it runs
inline or requests isolated context. The host chooses one concrete gate command; Workstream binds
its result to the shipment but does not classify the command or emulate a host CI selector.

Migration compatibility is not part of the simplified package. The public verb, converter,
tests, and source allowlist are deleted in the same hard cut as the other retired surfaces. A
portable skill has no installation registry from which to derive a universal "last legacy user,"
and it must not encode one maintainer's repository state as product policy. Any live legacy
worktrees in a consuming repository are an upgrade or landing constraint for that repository, not
a state machine retained inside Workstream.

Alternatives rejected:

- **Keep the fields but document their current no-op behavior.** This preserves the cross-product
  and advertises future features with no present value.
- **Leave history as an optional overview.** Optional writers, readers, validation, and conflict
  recovery still impose almost all of the implementation cost, while Git remains authoritative.
- **Retain gate classes but simplify selectors.** Class validation and generated-path exceptions
  still make Workstream responsible for host test semantics.
- **Replace mode or cadence with new booleans.** The loop already has explicit user requests,
  source boundaries, and helper-emitted actions; another persisted policy is unnecessary.
- **Keep migration until every known installation is empty.** The library has no installation
  registry, so "known" would be an informal, host-specific policy with no portable completion
  test. Git history preserves the retired converter without keeping it in the active package.

## Mechanism

### Retained safety kernel

The following behavior remains authoritative and may not be weakened as a simplification:

- exact admission of `<root>/.streams/STREAM` as one registered worktree on `stream/STREAM`;
- a top-level `WORKSTREAM.md`, helper-owned `workstream.tsv`, immutable instance and shipment
  identities, atomic tracker writes, and stale-evidence invalidation;
- bounded `read` and `read-current` projections that never expose raw tracker rows or sibling
  runbooks;
- semantic unit boundaries with clean tracked work and at least one implementation commit;
- explicit, replay-safe hook `ready → running → complete` receipts for hooks that actually run;
- worktree-local preparation and gate execution, Gitlink proof, uncertain external-effect
  reconciliation, and exact partial-delivery recovery;
- explicit landing authority, non-force ref changes, clean-primary admission, and the non-blocking
  repository landing lease; and
- guarded synchronization, recycle, close-check, and exact teardown.

The primary checkout remains an integration endpoint, never a development worktree. `save` remains
an optional one-line semantic note. Setup remains optional, recovery remains current-worktree-only,
and no operation gains polling, automatic rollback, force, or cross-stream discovery.

### One loop, no cadence policy

Remove `mode`, `ship-cadence`, their enums, CLI options, configuration keys, provenance rows,
fingerprint inputs, read projections, reconfiguration options, and source tests. Delete
`phase-set`, its caller-controlled transition table, the tracker `phase/name` row, and the manual
`plan`/`build`/`ship` names. Retain the helper-owned `phase/-/next-action` row and every
`shipment/ID/phase` transition required by resumable preparation, delivery, and postflight. There
is one execution mode: the custodial agent performs the current unit, using a native isolated fork
only for an enabled hook whose execution policy requests one.

After a unit and its optional feature hook complete, the loop reaches `accumulate`. At that point
the agent starts the next coherent source item when one is known and no shipment was requested;
otherwise it invokes shipment preparation. A source reaching its actual end and an explicit
`/workstream ship` are concrete landing boundaries. They require no persisted cadence value.
`ship-prepare` continues to require a nonempty batch of completed units and allocates one immutable
shipment identity.

### Sparse configuration and hooks

The defaults block is exactly:

```markdown
<!-- workstream:defaults@1 -->
landing: local
<!-- /workstream:defaults@1 -->
```

`landing` accepts `local`, `push`, or `pr`. Creation accepts only `--landing` as a policy override;
reconfiguration accepts only `--landing` and `--inherit landing`. The compiled runbook stores the
effective landing value once, with its `explicit`, `project`, or `bundled` provenance. Landing is
policy, not immutable identity. The runbook/tracker contract hash continues to bind the effective
contract; a separate defaults fingerprint is unnecessary.

An optional hook block is:

```markdown
<!-- workstream:hook:feature-completion@1 -->
execution: inline

<non-whitespace instructions>
<!-- /workstream:hook:feature-completion@1 -->
```

The other recognized event remains `ship-friction`; execution remains `inline`,
`isolated-preferred`, or `isolated-required`. Remove `concurrency` and
`parallel-preferred`. A missing block or whitespace-only body disables the event. The bundled
configuration contains no empty hook blocks.

Compilation omits a disabled hook from `WORKSTREAM.md`; it does not compute or store that hook's
fingerprint. Runtime creates no identity, `not-applicable` row, or evidence digest for a disabled
hook. For an enabled feature hook, `unit-complete` creates the existing ready receipt. For an
enabled ship-friction hook, preparation creates a receipt only when concrete friction facts exist.
With no enabled hook, both seams advance directly. Fingerprints and replay guards remain for
enabled hooks, including receipts completed under an older reconfigured body.

### Git is shipment history

Delete `.streams/history.tsv` from the tracked control surface, setup, repair, README, validation,
shipment preparation, gate relevance, migration output, and tests. Setup owns exactly
`.streams/.gitignore`, `.streams/CONFIG.md`, `.streams/README.md`, and executable
`.streams/workstream.sh`.

Preparation no longer appends rows or creates a metadata commit. It derives the candidate directly
from the committed unit boundaries in `workstream.tsv` and Git. Unit and shipment counters remain
monotonic only within the current instance and restart with a new instance ID; globally unique hook
identities continue to include that instance ID. Sync uses ordinary semantic conflict handling and
has no path-specific `.streams/history.tsv` merge algorithm.

`status` remains a bounded view of admitted current streams. Detailed history comes from the
stream branch and integration-target Git log; current unit/shipment state comes from
`workstream.tsv`; plan or roadmap progress remains with its source artifact. Workstream does not
replace the ledger with another event log, record type, tag, note, or cache.

### One exact-command gate

The gate API becomes:

```text
gate-run STREAM --label LABEL -- ARGV...
```

`ship-prepare` emits the exact candidate and target tips and reports that a gate is required; it
does not classify or project changed paths. The agent first uses a gate documented in project
instructions already in context. When none is documented, it performs bounded read-only discovery
across conventional repository surfaces: applicable `AGENTS.md` and README files, build manifests,
task-runner definitions, package scripts, and CI workflows. It may select a command only when those
sources establish one clear project-standard gate. Multiple plausible commands or no supported
command is the last-resort stop: ask the user for the exact argv without executing candidates to
discover intent. A narrower command is legal only when the same evidence identifies it as
sufficient for the shipment; otherwise use the discovered full or default gate.

`gate-run` revalidates the immutable tips and shipment inputs, records a `running` receipt before
execution, runs the exact argv from the stream worktree, and stores the existing command digest,
result, output digest, and bounded output tail. Success advances to friction handling or readiness;
failure and interrupted execution retain their current safe semantics. Changed candidate, target,
batch, runbook contract, or command invalidates evidence.

Remove `docs|full|semantic|none` classes, `--selector`, own/incoming/final/generated manifest
files, `WORKSTREAM_GATE_*` environment variables, selector-authored receipt files, docs-only
enforcement, generated-history exemptions, and `gate-none`. Bounded evidence-based discovery is
agent judgment, not a new helper operation, configuration surface, command registry, probing run,
or path-query API. The selected argv is the whole gate contract.

### One supported helper surface

Delete `skills/workstream/scripts/workstream-git.sh`,
`skills/workstream/scripts/workstream-prime.sh`, and
`skills/workstream/scripts/worktree-exclude.sh` after a repository-wide live-consumer check confirms no executable,
instruction, or generated artifact invokes them. Move no behavior into replacement wrappers:
`workstream.sh` already owns admission, unit start, exclusions, gate inputs, and landing facts.
Update the root `AGENTS.md` worked-reference pointer to the guarded `workstream.sh` implementation.
Historical records keep their original names.

Remove the public helper operations `state`, `diagnose`, `phase-set`, `gate-none`,
`contract-recover`, and `validate-tracker`. Delete the first four behaviors outright.
`contract-recover` and tracker validation remain private functions called by guarded operations
that need them, without CLI dispatch or usage entries. Preserve underscore-prefixed internal
dispatch required to execute a landing transaction under the process-scoped lease. Preserve
agent-routed delivery, PR, friction, and reconciliation operations until their callers are removed
or replaced by a later specification.

Tests assert the supported Workstream outcomes through routed verbs and public operations. Delete
tests whose sole purpose is a removed wrapper or secondary API; fold any unique safety assertion
into the nearest retained lifecycle test rather than keeping a compatibility-shaped harness.

### No migration subsystem

Delete `skills/workstream/verbs/migrate.md`,
`skills/workstream/scripts/workstream-migrate.sh`, its tests, the migration-only active-source
allowlist, and `migrate` dispatch together. Active Workstream code, prose, templates, and tests
contain no `.workstreams` compatibility grammar. Removed current-format fields and legacy layouts
receive no reader, converter, alias, warning path, or automatic cleanup.

This hard cut does not authorize inspection, migration, deletion, or closure of a consuming
repository's existing legacy worktrees. Before landing the new package, that repository's owner
must resolve any such live sessions using the incumbent version. That repository-specific fact
belongs in the implementation plan's coexisting-work constraints, not this portable mechanism.
Existing historical specs, plans, ADRs, reviews, and Git history remain untouched.

### Explicit non-goals

This change does not redesign worktree topology, unit semantics, landing policies, authorization,
the landing lease, push/PR delivery, Gitlink transport, partial-delivery reconciliation, compaction
recovery, the recovery anchor, operator notes, recycle, close, or teardown. It does not introduce a
generic callback system, CI registry, telemetry, activity log, compatibility alias, automatic
source parser, background worker, or new project home.

## Verification

- **Hard-cut source population.** An enumerated active-source guard covers `skills/workstream/`,
  current root guidance, generated control files, and current consumer prose. It proves zero live
  occurrences of removed mode, cadence, history, concurrency, gate-taxonomy, migration, legacy
  helper, and secondary-operation constructs. Historical `.records/` is outside the population.
  For every removed class, including each helper filename and public operation, a temporary
  mutation adds one live reference, proves the guard fails, restores the source byte-for-byte, and
  proves the clean guard passes.
- **Configuration and runbook.** Zero-setup and initialized fixtures accept only the single landing
  scalar and optional nonempty hook blocks. Removed keys/options fail. Generated runbooks contain
  one landing value, omit disabled hooks, and retain enabled hook bodies, execution policy,
  fingerprint, source, immutable coordinates, and contract binding. Reconfiguration interruption
  still resolves to exactly the old or new contract through a private recovery path.
- **Unit and hook loop.** Delegate/manual phase fixtures are replaced by one unit lifecycle.
  Completed units may accumulate and an explicit ship or actual source end prepares the same
  immutable batch. Empty hooks generate no tracker rows; enabled inline and isolated hooks retain
  start-before-effect, uncertain replay, closure validation, effect verification, and
  reconfiguration identity tests.
- **History deletion.** Setup and repair own exactly four tracked control files. Shipment
  preparation creates no history file or metadata commit. Rebase conflict tests use ordinary
  semantic handling. Status, recycle, close, and recreated-instance tests prove no lifecycle logic
  reads a removed ledger or reuses an identity unsafely.
- **Gate execution.** Direct-command success, failure, interruption, changed-input invalidation,
  bounded output, and reuse tests run through the classless API. Mutation fixtures prove no selector
  environment, manifest, external receipt, `gate-none`, or history exception survives. Agent-facing
  contract fixtures cover a command documented in loaded instructions, one command clearly
  established by conventional repository surfaces, multiple plausible commands, and no supported
  command. The latter two stop for user input without executing a candidate or calling `gate-run`.
- **Consumer deletion.** Repository-wide searches first print every live reference to each legacy
  helper and secondary operation. Deletion proceeds only after all executable and instruction
  callers are zero. Retained safety assertions run through the supported helper. Shell syntax and
  the complete Workstream test runner pass afterward.
- **Migration hard cut.** Current package sources contain no migration verb, helper, test,
  dispatch, allowlist, or active `.workstreams` reference. Removed migration commands fail through
  the ordinary unknown-command path. Fixtures inject each retired surface and require the
  active-source guard to fail. Verification never reads another session's `WORKSTREAM.md` or
  mutates a legacy worktree.
- **Package gates.** `skills/workstream/scripts/tests/run.sh` passes; every changed shell file
  passes `bash -n` and `shellcheck`; `skills/skill-builder/scripts/skills-lint.sh` reports no new
  failures or Workstream warnings. Remeasure the attributed populations with exactly
  `wc -l skills/workstream/SKILL.md skills/workstream/verbs/*.md`,
  `wc -l skills/workstream/scripts/workstream.sh`, and
  `find skills/workstream/scripts/tests -maxdepth 1 -type f -print0 | xargs -0 wc -l`. Each total
  must decrease from the baseline in Problem while the retained safety scenarios above stay green.
