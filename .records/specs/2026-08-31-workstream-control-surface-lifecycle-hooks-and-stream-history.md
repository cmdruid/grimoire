---
doctype: specs
status: published
schema: architect/spec@1
tags: [workstream, lifecycle, hooks]
---

# Workstream control surface, lifecycle hooks, and stream history — Spec

When published, this specification supersedes
→ `specs/2026-08-29-callback-registry-and-explicit-backlog-debrief-subscription.md`. The general Callback
skill, public callback registry, and universal work-unit dispatcher described there are not built.
It also supersedes Backlog's automatic debrief-boundary anchor requirements while preserving
Backlog's tracker, provider, routing, and explicit `/backlog debrief` behavior. Historical records
retain the paths and contracts that were true when they were written.

## Problem

Workstream is the only project workflow that needs a persistent execution loop, but its project
surface is currently split across three unrelated locations. Runtime checkouts and handoffs live
under `.workstreams/`, project hook and template customizations live under `.spaces/workstream/`,
and per-unit manifests and debriefs accumulate under `.records/streams/`. Stream creation also owns
installation of an always-loaded recovery block. The result is more setup, record lifecycle, path
resolution, and agent-facing prose than the loop needs.

The proposed general Callback skill would make this cost universal. Every project session would
load an event detector and dispatcher so that a few structured workflows could subscribe to a
boundary. That reverses the desired performance boundary: ordinary work in the main checkout
should remain free-form, while an agent that deliberately enters a Workstream may accept a richer
lifecycle contract from its `WORKSTREAM.md`.

Workstream's existing hooks also lack a durable invocation identity. A context loss during a hook
can repeat side effects or skip unfinished work, and inline execution retains verbose hook reasoning
that the stream does not need. `/backlog debrief` demonstrates both issues: it benefits from the
agent's complete completed-unit context, but its detailed routing process is downstream bookkeeping
from the stream's perspective.

Finally, `.workstreams/` cannot become the new control surface incrementally. Existing projects may
have live linked or in-place streams at that path, while tracked control files must coexist with
ignored runtime directories and appear in every linked checkout. A hard-cut rename therefore needs
an explicit, topology-aware migration and nesting guards that do not rely on a `.gitignore` being
present.

## Goal

Make Workstream a self-contained, zero-floor workflow under one fixed `.streams/` root. A tracked
control surface defines project defaults, two fixed lifecycle hooks, a guarded helper, a concise
shipment ledger, and human guidance; ignored direct children hold runtime streams. Each stream
receives one resolved, immutable-until-reconfigured workflow snapshot in `WORKSTREAM.md`, with
durable hook receipts and optional context-isolated execution.

Ordinary sessions load no callback dispatcher. A small, independently managed recovery anchor acts
only after compaction and only admits the stream whose custody matches the current checkout.
Existing `.workstreams/` instances move through one explicit hard-cut migration. Workstream stops
creating or reading `.records/streams/` and `.spaces/workstream/` artifacts.

## Approach

**Chosen: a Workstream-owned control root plus per-stream compiled lifecycle snapshots.** The
project may commit `.streams/CONFIG.md`, `.streams/README.md`, `.streams/workstream.sh`,
`.streams/.gitignore`, and `.streams/history.tsv`. Direct child directories are runtime stream
instances and remain ignored. Missing control files do not prevent `create`: package defaults,
package helpers, and shared Git exclusions retain Workstream's zero-setup behavior.

`CONFIG.md` combines a strict scalar-default block with two independently versioned Markdown hook
blocks. At `create`, explicit invocation choices override project defaults, which override bundled
defaults. The helper validates and compiles the resolved values and opaque instruction bodies into
the new `WORKSTREAM.md`. The active agent reads that one local snapshot; it does not repeatedly
load or interpret project configuration. Only explicit `/workstream reconfig` may replace the
snapshot.

Hooks remain bounded overlays on the Workstream loop, not a callback registry. Version 1 recognizes
only `feature-completion` and `after-eventful-ship`. A hook may run inline or in a full-context,
serialized custodial fork. Isolation availability has an explicit fallback policy.
`parallel-preferred` records a future execution preference but resolves deterministically to serial
isolation in version 1. An effectful post-ship hook finishes through a non-recursive delivery tail,
so its tracked effects cannot be stranded behind an already-completed land.

Workstream history becomes one append-only TSV row per landed unit. Git retains implementation
detail; the ignored handoff retains current execution state; the ledger provides only a compact
project overview. Workstream no longer owns typed plan or report records, deployable manifest or
debrief templates, or a `.spaces` namespace.

Alternatives rejected:

- **Build the general Callback registry.** It makes an always-loaded event engine a project-wide
  cost and gives arbitrary sessions workflow obligations they did not enter.
- **Keep hooks under `.spaces/workstream/`.** It leaves Workstream split across project homes and
  makes setup, repair, migration, and configuration understanding depend on another namespace.
- **Use JSON for the whole configuration.** JSON is convenient for scalar validation but awkward
  for multiline agent instructions and requires a guaranteed parser. Exact Markdown delimiters and
  a closed scalar grammar are simpler to validate portably.
- **Split hooks into `HOOKS.md`.** The existing block versions already let defaults and each hook
  evolve independently; another file adds no behavioral isolation.
- **Run every hook inline.** It needlessly retains verbose downstream reasoning in the stream's
  scarce context.
- **Let an isolated hook silently degrade.** Some projects require isolation. The configured
  `preferred` versus `required` policy states whether inline fallback is acceptable.
- **Run side-effecting hooks concurrently in the active checkout.** Parent and child writes would
  race on files, the index, refs, and rebases. Parallel execution requires a prepare/apply boundary.
- **Keep per-unit manifests and debrief records.** They turn transient orchestration state into
  schemas, templates, closure rules, and prose archives. Durable plans remain owned by their source;
  substantial findings use the project's ordinary durable lanes.
- **Derive history directly from every commit or squash each unit.** One row per commit is too
  detailed, while mandatory squashing rewrites useful development history. The handoff owns semantic
  unit boundaries and Git supplies their supporting commit facts.
- **Dual-read `.workstreams/` and `.streams/`.** A permanent compatibility branch weakens custody
  checks and permits two roots to claim the same stream. Migration is explicit and runtime is a hard
  cut.

## Mechanism

### Canonical layout and ownership

The fixed project layout is:

```text
.streams/
  .gitignore
  CONFIG.md
  README.md
  history.tsv
  workstream.sh
  <stream>/                 # ignored runtime directory or linked worktree
    WORKSTREAM.md           # top-level inside a linked worktree
```

`.streams/.gitignore` is package-managed and has the canonical runtime rule:

```gitignore
# Workstream runtime directories
/*/

# Interrupted migration state
/.migration.tsv
```

The rule ignores immediate runtime directories while leaving top-level control files visible.
Ignore state is hygiene, never a safety boundary. Before creating any stream, Workstream ensures
the shared repository exclusion contains `/.streams/*/` and `/WORKSTREAM.md`; inability to ensure
both exclusions refuses before a branch, directory, or worktree is created. The tracked
`.gitignore` and the shared local exclusion intentionally overlap.

Tracked control files appear inside every ordinary linked checkout. That is valid. No directory is
part of the tracked control surface, so an immediate directory beneath a stream worktree's own
`.streams/` is a nested-runtime signature and blocks lifecycle mutation. The topology guards also
enforce all of these invariants independently of ignore state:

- A stream name is one safe lowercase path segment and maps exactly to
  `<root>/.streams/<stream>` and `stream/<stream>`.
- A linked stream's canonical path and branch match one entry in Git's worktree registry.
- An in-place stream has one ignored `<root>/.streams/<stream>/WORKSTREAM.md` and holds its recorded
  branch in the root checkout unless explicitly parked.
- The handoff's immutable `instance-id`, `root checkout`, `worktree`, `branch`,
  `integration-target`, and `this hand-off` fields pass their exact grammar and agree with
  filesystem and Git facts where applicable.
- Only the five declared top-level control files may be tracked beneath `.streams/`. A tracked
  runtime child, handoff, or nested Git marker is corruption.
- `save` writes only the handoff's canonical absolute path. `close` removes only a registered,
  canonical runtime path. `status` uses the helper to emit bounded status fields and violations
  without disclosing another session's handoff body to the agent.

`.streams` is a narrow Workstream control-home exception to the three general project homes, as
recorded in → `adr/2026-08-31-give-workstream-a-dedicated-streams-control-home.md`. It is fixed,
not selectable, and no other skill may use it as a generic configuration or scratch root.

### Configuration contract

`CONFIG.md` is project-owned, absent-only configuration. Prose outside recognized delimiters is
explanatory and has no runtime meaning. The defaults block is exactly:

```markdown
<!-- workstream:defaults@1 -->
mode: delegate
isolation: worktree
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->
```

The keys are closed and unique. Their values use the existing Workstream enums. `landing` must be
`local` for worktree isolation. Unknown keys, duplicate keys, unsupported versions, malformed
marker pairs, invalid enum combinations, or non-scalar lines refuse the complete configuration.

Each optional hook block has this shape:

```markdown
<!-- workstream:hook:feature-completion@1 -->
execution: isolated-preferred
concurrency: parallel-preferred

/backlog debrief
<!-- /workstream:hook:feature-completion@1 -->
```

The only second hook name is `after-eventful-ship`. Both metadata lines are required when a block
is present and precede one blank line plus the opaque Markdown instruction body.
`execution` is `inline`, `isolated-preferred`, or `isolated-required`; `concurrency` is `serial` or
`parallel-preferred`. `inline` plus `parallel-preferred` is invalid. A missing block or a
whitespace-only body disables that hook. Duplicate or unknown hook blocks refuse; unrelated
headings do not create behavior.

The block suffix versions the block grammar, not project content. At compilation the helper records
the schema version and a content fingerprint for defaults and each hook. The three blocks evolve
independently. Unsupported versions refuse with the supported versions; a future block version must
define its own explicit migration and is never interpreted approximately by an agent.

Missing `CONFIG.md` means the bundled scalar defaults above and two disabled hooks. At create,
explicit command choices take precedence over project values, which take precedence over bundled
values. The resulting handoff records each effective value, hook policy, instruction body, source
version, and fingerprint. It does not retain a live pointer that changes behavior when project
configuration changes.

The default file installed by setup contains the defaults block plus both recognized hook blocks
with `execution: inline`, `concurrency: serial`, and empty instruction bodies. Explanatory prose
identifies those empty bodies as disabled. A project may delete either complete hook block with the
same effect.

### Installed helper, setup, and repair

The package and project copies of `workstream.sh` expose the same guarded operations for control
surface classification, instance-identity minting, configuration validation and compilation,
history validation and update, hook receipt transitions, topology facts, and exact old/new
previews. Mechanical operations print compact facts and evidence; they do not choose a lifecycle
action or execute hook instructions.

An absent installed helper uses the package helper, including when a zero-setup project already has
runtime directories, `CONFIG.md`, or a lazily created history file. A Workstream-managed README
block or an installed helper is the initialized-control-surface boundary. At that boundary, a
missing, stale, symlinked, or malformed installed helper refuses ordinary mutation and points to
repair; runtime never silently executes stale project tooling against project data. An installed
helper without the managed README is recognized partial setup and points to setup.

`/workstream setup [<root>]` initializes or reconciles the complete control surface. It installs the
executable helper, canonical `.gitignore`, managed README block, default `CONFIG.md` when absent,
and exact `history.tsv` header when the ledger has never existed. Project-authored configuration
and README prose are preserved. Setup preflights its full write set, rechecks every parent and target
before mutation, and makes one exact pathspec-scoped commit when run standalone. Missing Workstream
setup is never a precondition for `create`.

Naked `/workstream repair` requires recognized initialized control state. It refreshes the
package-managed helper, `.gitignore`, and README block; restores a missing default `CONFIG.md` but
never overwrites a present one; and validates configuration and history. A missing or malformed
ledger after initialization is possible data loss and directs Git recovery rather than creating an
empty replacement. Repair never touches `AGENTS.md`, runtime stream directories, handoffs, branches,
or hook receipts.

`/workstream repair <stream>` is a separate, explicitly targeted mechanical repair. A root
coordinator may target a named stream; an agent already driving a stream may target only itself. It
classifies, previews, rechecks, and then may restore exclusions, repair unambiguous Git worktree
administrative metadata, restore package-managed file modes or markers, relocate one unambiguous
misplaced handoff to its immutable coordinate, or remove a proven stale nested duplicate after
approval. It never enters the stream, synthesizes a missing handoff from Git facts, changes intent
or configuration, or resolves divergent handoffs, coordinate disagreements, concurrent activity,
or ambiguous topology.

### Recovery anchor

`/workstream anchor [status|install|refresh|remove] [<front-door>]` is the exclusive owner of one
versioned Workstream recovery block. Bare `anchor` means `status`, which is read-only. The mutating
operations classify the selected always-loaded Markdown file as `current`, `absent`, `drifted`,
`conflict`, or `error`, show the exact old and new bounded bytes, reclassify immediately before an
atomic write, and preserve all surrounding content. Malformed, duplicate, nested, overlapping, or
unmarked reserved content refuses. Tests use consuming-project fixtures and never install the block
in grimoire's authored `AGENTS.md`.

The anchor is locally complete but deliberately small. It applies only after compaction or a
continuation summary. It checks the current Git top level, admits a top-level `WORKSTREAM.md` only
when its coordinates match that checkout and branch, and admits an in-place
`.streams/<stream>/WORKSTREAM.md` only when HEAD holds that stream's recorded branch. It then
requires a full read and durable-fact reconciliation before continuation. Other handoffs visible
from the root belong to other sessions and must not be read. The anchor contains no lifecycle event
catalog, hook bodies, configuration parser, callback dispatcher, or dependency on
`.streams/workstream.sh`.

`create` and `load` may report a missing or drifted anchor, but they do not install, refresh, or
offer to edit it. Setup and repair also leave the front door untouched. This separates persistent
recovery policy from stream admission and control-surface maintenance.

### Handoff snapshots and reconfiguration

`WORKSTREAM.md` remains the ignored, worktree-local source of stream custody and resume state. Its
immutable coordinates include an `instance-id`: exactly 32 lowercase hexadecimal characters minted
from 128 bits of secure randomness by the effective helper. Entropy failure refuses create before
any branch, runtime path, or worktree mutation; there is no name-, time-, sequence-, or
history-derived fallback. `save`, `load`, `reconfig`, and `recycle` preserve the identifier, while a
later `create` reusing a closed stream name mints a new one. The managed configuration section
contains the resolved scalar values, each scalar's `explicit`, `project`, or `bundled` provenance,
and the compiled hook blocks. Its managed lifecycle section contains the current monotonic unit
sequence, next monotonic shipment sequence, active shipment's ordered unit sequences, semantic unit
boundary, supporting commit subjects and count, and hook receipts. General plans, diffs, hook
transcripts, and tracker rows are not copied into the handoff.

`/workstream reconfig [<stream>] [--mode <mode>] [--landing <landing>]
[--ship-cadence <cadence>] [--inherit <field>]` is the only operation that adopts a later
`CONFIG.md` or changes a mutable scalar override. `--inherit` may repeat and accepts `mode`,
`landing`, or `ship-cadence`; it removes that field's explicit override. Within a stream, the
omitted name targets that stream only. From the root, the name is required and the operation does
not load or enter the target. Reconfig:

1. requires a quiescent unit boundary: no uncommitted work, interrupted Git operation, active
   lifecycle mutation, or `running` hook receipt, and the current unit is either not started or has
   completed its feature-completion hook;
2. validates and fingerprints the current project configuration;
3. produces an exact old/new preview of effective defaults, scalar provenance, hook policies,
   bodies, versions, and fingerprints;
4. rejects changes to immutable topology, including isolation, canonical paths, branch, and target;
5. rechecks the configuration fingerprint and target handoff immediately before mutation; and
6. atomically replaces only the managed configuration and compiled-hook extents.

Invocation authorizes adoption of the displayed valid configuration; there is no second implicit
refresh or hidden merge. Without an explicit scalar option or matching `--inherit`, every
`explicit` value survives unchanged. Reconfig recomputes only `project`- and `bundled`-sourced
values. An explicit scalar option replaces that value and records `explicit` provenance;
`--inherit` resolves the field from the current project block or bundled default and records that
source. Supplying both forms for one field refuses. Isolation has no mutable option: any effective
topology change still refuses. New instructions apply only to hook identities that have not
started. Completed receipts remain bound to their original hook fingerprint. Coordinates, queue
state, unit evidence, completed receipts, and authored handoff prose remain unchanged. `recycle`
preserves the incumbent snapshot until reconfig is invoked.

### Hook events and receipts

Version 1 exposes exactly two hookable events:

- `feature-completion` occurs once after a unit meets its completion and verification boundary and
  before Workstream decides whether to accumulate or ship it.
- `after-eventful-ship` occurs once after a successful ship when that ship resolved a rebase or
  landing conflict, retried after target or root contention, or required more than one synchronization
  attempt. A normal successful ship marks the event not applicable.

No create, load, save, sync, park, recycle, close, setup, repair, anchor, reconfig, migration, or
history action is hookable. Hook execution and its closure do not recursively create another event.
Adding an event requires a new recognized hook name and behavioral evidence; configuration cannot
invent event names.

Feature-completion invocation identity is
`<stream>/<instance-id>/unit/<unit-sequence>/feature-completion`. Before the first attempt to ship a
nonempty completed batch, Workstream allocates one shipment sequence, records the batch's ordered
unit sequences, and gives its ship hook identity
`<stream>/<instance-id>/shipment/<shipment-sequence>/after-eventful-ship`. A retry reuses that
identity and batch; it never allocates another. The first stream instance starts both sequence
populations at one. A recreated or migrated stream seeds both next values above the maximum
existing unit sequence in history. The fresh instance identifier prevents a discarded unlanded
unit, whose sequence never reached history, from colliding with a later stream incarnation.

Every identity is bound to the compiled hook fingerprint. The managed receipt state is `ready`,
`running`, `complete`, or `not-applicable`. Immediately before exposing instructions, the helper
atomically changes `ready` to `running` in the handoff. After the parent verifies the hook's done
condition and durable effects, it explicitly changes `running` to `complete`. Empty hooks and a
normal, non-eventful shipment become `not-applicable` without execution.

A context that recovers a `running` receipt treats the outcome as uncertain. It inspects durable
effects and the closure evidence before choosing to mark complete or explicitly retry; it never
automatically repeats the instructions. A hook failure leaves the receipt running and blocks
crossing that lifecycle seam. For `after-eventful-ship`, the already-landed code remains landed, but
the stream may not reset, recycle, or begin another unit until the receipt is reconciled. Receipt
transitions are narrow atomic state writes, not full `/workstream save` operations.

### Isolated and parallel-preferred execution

Inline execution runs in the custodial parent and may retain its output in that context. An
isolated execution is not ordinary delegation: it is a full-context, serialized custodial fork.
The parent marks the receipt running and pauses. The fork inherits the conversation,
`WORKSTREAM.md`, unit identity, supporting commit facts, and exact hook body. It may perform the
hook's scoped effects while retaining the same stream custody, but it may not invoke Workstream
lifecycle verbs, modify the handoff or receipt, create or load another stream, or outlive the parent
without a join.

The fork returns only this closure envelope; its reasoning and tool transcript are discarded:

```text
status: complete | blocked | uncertain
summary: <one single-line summary>
effects: <paths, identifiers, or none>
parent-actions: <explicit actions or none>
```

The parent independently validates claimed worktree and Git effects before completing the receipt.
Backlog's child-context rule gains a narrow owner-neutral distinction: ordinary children and
delegates still return byproducts without filing, while a serialized custodial continuation may
invoke `/backlog debrief` and complete its provider-managed writes. Workstream itself never names or
requires Backlog; `/backlog debrief` is merely a valid project-authored hook body.

An `after-eventful-ship` receipt remains `running` until every claimed tracked effect is delivered.
The parent first requires the hook's declared paths to be committed and the index and tracked
worktree to be clean; an uncommitted or unexplained change is uncertain state and blocks at the
receipt. When no tracked commit exists, validated external or no-op effects may complete directly.
When the hook leaves tracked commits, Workstream runs a **closure tail** using the stream's recorded
landing mode: `local` repeats sync, the gate-by-what-lands decision, and the guarded fast-forward;
`push` also pushes the updated target; `pr` pushes the existing stream branch so the already-open
shipment PR contains the closure commit. The tail appends no history row, advances no queue, and
cannot emit either hook event. A contention retry reuses the same running receipt. Only confirmed
delivery completes it; failure or uncertain delivery leaves it running and continues to block save,
reset, recycle, close, and the next unit.

Capability resolution follows the configured policy:

- `inline` executes in the parent.
- `isolated-preferred` uses serial isolation when available and otherwise executes inline.
- `isolated-required` uses serial isolation when available and otherwise stops before execution.

In version 1, `parallel-preferred` is a validated and fingerprinted preference with no parallel
dispatch behavior. It selects serial isolation first and then obeys the execution policy's
inline-or-stop behavior. Runtime performs no capability discovery, read-only child dispatch, result
artifact exchange, or prepare/apply join. A successor specification must define that complete
protocol before any implementation may activate the preference. A hook action that has started but
fails never falls back automatically, because replay could duplicate effects.

The current Backlog debrief is one-phase. A `parallel-preferred` Backlog hook therefore selects
serial isolation, then inline when configured as `isolated-preferred`. A future Backlog
prepare/apply design is outside this specification.

### Backlog boundary hard cut

Backlog retains a lean discoverability route but no longer installs a work-unit detector or runs
debrief automatically. Its package-owned route becomes:

```markdown
<!-- skill:backlog BEGIN built-against:backlog-route@1 -->
### /backlog — project follow-up trackers
Route: Inspect and manage project follow-up trackers with `/backlog`.
Edges: produces `tracker`.
<!-- skill:backlog END -->
```

Backlog setup, repair, and tracker administration reconcile that exact route under their existing
bounded ownership rules. A recognized `debrief-anchor@1` block is replaceable package-managed
Backlog state and is replaced without carrying event instructions forward. Backlog deletes its
package-only debrief anchor template and removes callback-action declarations. Explicit
`/backlog debrief` retains its existing bounded-context, routing, provider, commit, and zero-row
success behavior.

When a serialized fork invokes debrief, the caller supplies the current completed-unit identity,
commit evidence, and prior successful hook receipt as its bounded context. Backlog adds no durable
cursor, and discarding the fork's transcript does not make earlier units eligible again.

No Workstream setup or runtime operation edits Backlog state, registers a subscriber, or assumes
Backlog is installed. A consuming project's `CONFIG.md` may place `/backlog debrief` in a known hook
body. That project-authored instruction is the complete composition seam.

### Unit boundaries and history

Workstream no longer creates, closes, reads, or links `workstream/plan@1` or
`workstream/debrief@1` records. It deletes the bundled `manifest.md` and `debrief.md` templates and
removes the `produces: plan, report` edge. Tracked queue-source plans and roadmaps remain under their
own authorities. An untracked file is not silently claimed or moved into a Workstream store:
`create` requires the caller to place it durably through its owning lane or to supply its essential
scope as an inline brief. Ad hoc units keep only concise execution state and pointers in the
handoff.

At unit start, the handoff records the unit slug, summary, sequence, and current stream commit
boundary. At feature completion, before its hook runs, Workstream reconciles the implementation
commits authored for that unit against Git and records their ordered subjects plus count. Hook,
ledger, queue, and other closure commits are excluded from that count. Sync or rebase preserves
semantic unit order but may rewrite hashes; therefore history never stores commit SHAs. If a rebase
drops, combines, or otherwise makes a recorded boundary ambiguous, ship refuses until the agent
reconciles the unit's subject list and count against the current branch.

`.streams/history.tsv` has the exact header:

```text
stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary
```

`sequence` is a positive decimal, monotonic and unique within a stream name. A recreated stream
continues after the maximum existing sequence. `recorded_at` is UTC RFC 3339 to seconds and records
when the shipment row was prepared; the row becomes project history only when it lands. `commits`
is the positive count reconciled for that unit. Names and summary are nonempty single-line fields
without tabs, carriage returns, NUL bytes, or other control characters.

This is Workstream's internal operational ledger, not Journal's `.records/history.tsv`, a typed
record, or a cross-skill artifact. Workstream's final edge block therefore declares no produced or
handoff artifact and continues to consume only `plan` and `roadmap` queue sources.

Before landing, `ship` appends one row for every completed unit in the batch and commits the ledger
with the stream's changes. A failed land leaves those rows only on the stream branch; retry never
duplicates their `(stream, sequence)` keys. Successful PR landing makes the rows visible only when
the PR merges. Save, sync, load, create, park, recycle, close, setup, repair, anchor, reconfig, and
migration do not write activity rows.

The effective helper is the sole ledger writer: the current installed helper at a recognized
initialized control surface, otherwise the package helper. In a zero-setup project whose ledger has
never existed, the package helper creates the exact header as part of the first guarded append. Once
the initialization boundary exists, a missing or stale installed helper or a missing ledger refuses
as described above rather than falling back. The effective helper validates the complete file, uses
a guarded atomic replacement, and rejects a divergent incumbent key. Concurrent streams may append
distinct keys. During a rebase conflict, the helper may form the strict union of two completely
valid append-only populations: identical keys must have identical rows, divergent same-key rows
refuse, and no base row may disappear or change. This deterministic merge is the only supported
rewrite. `status` may show recent history alongside active handoff facts, but history is never
recovery authority and the recovery anchor never loads it.

### Hard-cut migration

`/workstream migrate .workstreams` is an attended, project-wide migration of runtime streams only.
It does not inspect, move, delete, or translate `.spaces/workstream/` customizations or
`.records/streams/` records. The removed manifest and debrief templates have no project destination;
package-only intake templates remain inside the skill.

Migration inventories every direct legacy child, classifies linked and in-place streams from Git
and handoff coordinates, and requires one-to-one names with no destination collision, nested
runtime signature, missing or divergent handoff, coordinate disagreement, unknown entry, or
`running` hook receipt. The operator confirms that every inventoried stream is saved and quiescent.
Linked streams move through `git worktree move`; in-place runtime directories move through a
guarded filesystem rename. Canonical absolute `.workstreams/<stream>` values in each handoff are
rewritten to `.streams/<stream>`.

Legacy handoffs receive one bounded shape upgrade during that same guarded rewrite. Existing
effective scalar choices and compiled hook bodies are preserved without reading
`.spaces/workstream`; scalar choices receive `explicit` provenance because their prior source cannot
be recovered safely, and hook bodies without execution metadata become `inline` and `serial`.
Migration mints and records a fresh instance identifier before it creates any version-1 receipt.
The current unit and next shipment sequence are seeded above the ledger maximum, and the current
unit's new hook receipts become `not-applicable` so migration cannot repeat or invent closure work
whose prior execution is unknown. The first unit and shipment begun after migration use normal
version-1 receipts. History is not reconstructed or backfilled. Queue state, coordinates unrelated
to the root rename, and authored handoff prose remain unchanged.

The operation records its finite inventory and completed moves in an ignored
`.streams/.migration.tsv` so an interruption resumes without rediscovering intent. Every step
rechecks source, destination, Git registry, and handoff fingerprint. Completion validates the new
topology and Git registry, removes the manifest, and removes `.workstreams/` only when empty.
Unknown legacy content remains in place and blocks completion.

Before creating the manifest, migration ensures `/.streams/.migration.tsv` is covered by the
shared local Git exclusion; inability to do so refuses before the first move. The tracked
`.streams/.gitignore` supplies the same exclusion when setup is present.

While either root contains an incomplete inventory, ordinary lifecycle verbs refuse and point to
the same migration. Runtime contains no fallback reader, symlink, alias, or mixed-root mode.
Migration does not edit `AGENTS.md`; it reports that `/workstream anchor refresh` is required.

## Verification

All setup, anchor, migration, and lifecycle tests use throwaway consuming repositories. No test
deploys project blocks or layout into grimoire's authored `AGENTS.md`.

- **Control surface.** Fixtures prove zero-setup create, fresh setup, partial-write convergence,
  current reruns, exact scoped commits, incumbent `CONFIG.md` and README preservation, helper and
  `.gitignore` refresh, missing-ledger recovery refusal, symlink and parent-race refusal, and naked
  repair's prohibition on stream mutation. Mutation-red tests weaken every owned-path and
  incumbent-preservation guard.
- **Configuration.** Table tests cover missing configuration, every valid enum and precedence
  branch, scalar provenance, empty hooks, both hook names, independent block versions and
  fingerprints, malformed and duplicate delimiters, duplicate and unknown keys, unknown hooks,
  invalid combinations, opaque Markdown bodies, and refusal of unsupported versions. A fixture
  proves an agent receives the compiled handoff snapshot without reading `CONFIG.md` at event time.
- **Topology and nesting.** Linked and in-place fixtures prove canonical coordinates, registry
  agreement, exact instance-ID grammar, entropy failure before mutation, identifier preservation
  across every non-create lifecycle path, tracked-control allowlisting, local exclusions, valid
  tracked `.streams` content inside linked worktrees, nested runtime and Git-marker detection, exact
  save targets, status non-disclosure, and close's registered-path boundary. Guards still fail after
  removing every `.gitignore` fixture.
- **Anchor.** Classifier fixtures cover current, absent, drifted, replaceable conflict, malformed
  marker families, surrounding-content races, install, refresh, and remove. Recovery scenarios
  cover top-level custody, matching in-place custody, foreign linked handoffs, branch mismatch,
  compaction-only activation, read-only reconciliation, and no helper, hook, or history dependency.
- **Reconfig.** Fixtures prove exact previews, source and target race refusal, current-stream and
  root-target scope, quiescent-boundary enforcement, preservation and replacement of explicit
  overrides, `--inherit` resolution, conflicting-option refusal, immutable-topology refusal,
  preservation of queue and receipts, future-event-only adoption, atomic replacement, and no
  implicit adoption from load, save, repair, sync, recycle, or config edits.
- **Hook receipts.** Deterministic scenarios cover disabled hooks; each recognized seam; normal and
  eventful ships; unit- and shipment-scoped identities; multi-unit shipment batches and retry
  identity reuse; ready, running, complete, and not-applicable transitions; duplicate suppression;
  context loss before and after effects; explicit reconciliation and replay; action failure; local,
  push, and PR closure-tail delivery; tail interruption; history, queue, and recursion suppression;
  prevention of lifecycle progress across an unresolved receipt; and completion, discard, and
  same-name recreation of an unlanded unit proving a fresh instance identity despite sequence
  reuse. Controlled broken helpers must make each transition assertion fail.
- **Isolation.** Capability fixtures cover inline, isolated-preferred success and inline fallback,
  isolated-required refusal, compact closure envelopes, full inherited context, parent suspension,
  custody and lifecycle-verb prohibitions, effect validation, failed-child recovery, and
  `parallel-preferred`'s deterministic serial resolution. A live-source guard proves version 1 has
  no parallel hook dispatcher or prepare/apply protocol. Hosted acceptance under each supported
  harness runs a full-context debrief hook and confirms that only the closure envelope returns to
  the parent.
- **History.** Fixtures cover first-write header creation, one row per unit, multi-unit shipment,
  package-helper zero-setup writes, initialized-helper authority, monotonic reuse,
  commit-subject/count reconciliation, rebase hash changes, ambiguous-boundary refusal, failed-land
  retry, PR visibility, exact-key idempotence, divergent-key refusal, strict concurrent union,
  malformed bytes, and absence of rows for every non-ship verb and closure tail.
- **Migration.** Fixtures cover multiple linked streams, in-place streams, collisions, unknown
  entries, nested state, dirty but saved state, running receipts, Git/handoff disagreement,
  interruption after each move, manifest resume, instance-ID minting, explicit provenance
  assignment, unit and shipment sequence seeding, exact absolute-path rewrites, empty legacy-root
  removal, anchor-refresh reporting, and refusal of mixed-root runtime. They prove that `.spaces`
  and `.records/streams` bytes remain untouched.
- **Backlog and hard cut.** Backlog fixtures replace the eventful debrief anchor with a lean
  discoverability route while preserving explicit debrief behavior. Ordinary children still cannot
  file; a serialized custodial continuation can. Live-source guards reject a Callback package or
  dispatcher, Workstream reads or writes of `.records/streams` and `.spaces/workstream`, ordinary
  runtime reads of `.workstreams`, project manifest/debrief templates, and legacy anchor content.
  Every absence guard is mutation-red-proved against a temporary source copy; historical evidence
  and the bounded migration/rejection surface are excluded deliberately.
- **Repository gates.** Workstream's complete harness, Backlog's affected harness, repository
  integration tests, `skills/skill-builder/scripts/skills-lint.sh`, ShellCheck, the host doc gate,
  and `git diff --check` pass. README, PACK, doctrine, live front-door recovery prose, and helper
  inventories agree on `.streams`, the bounded hook catalog, and the absence of a general Callback
  runtime.

The feature is complete when structured lifecycle behavior is confined to enrolled Workstreams;
the `.streams` control and runtime surface is guarded and recoverable; configuration changes are
explicit snapshots; hook receipts prevent silent replay; optional isolation returns only compact
closures; history contains exactly one validated row per landed unit; legacy streams migrate
without importing old customizations or records; and ordinary project sessions carry no callback
dispatcher.
