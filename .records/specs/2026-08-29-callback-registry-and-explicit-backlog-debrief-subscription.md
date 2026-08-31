---
doctype: specs
status: published
schema: architect/spec@1
tags: [callback, agent-events]
---

# Callback registry — Spec

## Problem

Agent-event instructions currently lack a common owner. A skill that needs an agent to perform
closure work at an observable boundary must invent its own front-door trigger or a harness-specific
hook. Those alternatives create multiple dispatchers, inconsistent boundary definitions, and no
common answer for action order or failure handling.

The successful prototype spike proved that current Grok and Codex harnesses can follow one generic
anchor through a registry dispatcher and then execute ordered Markdown instructions and skill
commands. It also proved that an advisory failure can continue, a blocking failure can halt before
later actions, and pure Q&A can remain silent
(→ `spikes/2026-08-29-callback-anchor-dispatcher-harness-acceptance.md`). The prior hosted spike
separately proved Backlog's direct boundary trigger
(→ `spikes/2026-08-29-backlog-debrief-anchor-harness-acceptance.md`). What remains missing is a
production contract that gives the shared mechanism one owner without turning arbitrary shell
hooks, dynamic events, or implicit subscriber setup into project policy.

Two published Backlog addenda described the former incumbent design. The debrief-anchor reliability spec
(→ `specs/2026-08-28-backlog-debrief-anchor-reliability.md`) makes Backlog the event owner, and the
tracker-provider discoverability spec
(→ `specs/2026-08-28-backlog-tracker-provider-discoverability.md`) requires Backlog setup to
reconcile that anchor. This specification supersedes the former and overrides the latter's
`debrief-anchor@1` route-reconciliation requirements. The later tracker-layout ADR
(→ `adr/2026-08-30-separate-tracker-tables-from-lifecycle-history.md`) hard-cuts Backlog's entire
front-door surface; Callback does not replace it with a Backlog route or subscription.

## Goal

Add a dedicated `callback` skill whose explicit setup owns one public `.callbacks/` layer and one
versioned front-door `callback-anchor@1`. Its fixed v1 catalog recognizes only
`work-unit-boundary@1`; at that boundary the custodial main agent dispatches explicitly registered
agent instructions or skill commands in stable relative order and applies each registration's
`advise` or `block` failure policy.

Callback remains independent of tracker or workflow policy. No lifecycle owner, harness hook,
arbitrary executable handler, or durable work-unit cursor becomes a second dispatcher.

## Approach

**Chosen: a staged public registry provider plus one exact agent anchor.** Callback is a durable-home
skill because it owns persisted callback registrations. `/callback setup` creates an empty,
self-explaining `.callbacks/` layer, installs its guarded provider, and registers Callback's exact
front-door block. The provider is the sole registry writer and a read-only dispatcher: it validates
the fixed event catalog and registry, emits ordered framed agent actions, and never executes a
target. The always-loaded anchor owns event detection, action execution, recursion suppression, and
failure policy.

The public layer has a fixed v1 root rather than a new front-door variable:

```text
.callbacks/
  README.md
  callbacks.sh
  registry.tsv
```

The registry is shared project configuration, not owner-local workspace content, so it does not fit
the closed `<agent-workspace>/<skill>/<kind>/...` grammar. A separate `.callbacks/` layer also lets
the staged provider self-locate without reading `AGENTS.md`. No brownfield variance justifies an
`agent-callbacks:` declaration; adding one would make every reader and writer more complex before a
real alternate-root case exists.

Registration is always explicit. Callback setup does not scan installed skills or seed entries.
Subscriber setup may publish its own instruction target, but it never invokes Callback or edits
`.callbacks/`. A user or an explicitly requested composition sweep invokes `/callback register`.
Registration appends by default; `first`, `before`, `after`, and `last` placement plus a separate
move operation express relative intent without exposing stored numeric priorities.

Callback includes `/callback repair` because an initialized layer has a small package-managed
surface—provider, managed README block, and anchor—that can become stale independently of the
registry. Repair shares setup's reconciler with a narrower write set and never creates, infers, or
rewrites registration data. Loss of `registry.tsv` is data loss and requires Git recovery.

Backlog makes a deliberate hard cut: its route helper, anchor template, and front-door writes are
deleted wholesale and are never parsed into Callback registration. This pays down the misplaced
event ownership instead of designing a permanent compatibility path around it.

Alternatives rejected:

- **Let Backlog remain the dispatcher and add subscribers to it.** This would make an unrelated
  follow-up skill the permanent owner of a general agent-event mechanism.
- **Let subscriber setup register itself.** Installation would silently change global execution
  order and failure policy, and uninstall or partial setup would leave unclear registry custody.
- **Run executable shell handlers.** A registry entry must remain agent-readable policy. Arbitrary
  executables would turn the anchor into a hook runner with a materially larger trust and failure
  surface.
- **Allow project-defined event names.** An agent cannot reliably detect a name merely because it
  appears in a registry. Events enter a closed catalog only after their trigger and exclusions have
  dedicated behavioral evidence.
- **Store numeric priorities.** Numbers leak arrangement into subscriber configuration and make a
  simple insertion renumber unrelated entries. Stable subscriber IDs and relative moves express
  the actual intent.
- **Store the registry under `.spaces/callback/`.** The workspace grammar has no configuration-data
  kind, and misusing `hooks`, `scripts`, or `doctrine` would weaken those ownership contracts.
- **Install only when the first registration appears or remove the anchor with the last entry.**
  Coupling lifecycle to row count makes registration an implicit installer. An initialized empty
  registry is valid; dispatch returns zero actions and the layer remains ready and discoverable.
- **Use Checkpoint, Workstream, or harness lifecycle hooks.** Those owners cover only some contexts,
  would duplicate the general boundary, and would make portability depend on a particular runtime.

## Mechanism

### Skill and public surface

The new package is self-contained under `skills/callback/`. Its thin `SKILL.md` routes these public
verbs:

| Invocation | Effect |
|---|---|
| `/callback setup` | Initialize or reconcile the public layer and exact anchor |
| `/callback repair` | Restore only package-managed provider, README block, and anchor |
| `/callback register ...` | Add one explicit callback registration |
| `/callback unregister ...` | Remove one registration |
| `/callback list [event]` | Show configured callbacks and derived positions |
| `/callback move ...` | Reorder one registration relative to its event peers |

There is no bare callback execution verb, teardown verb, event-definition verb, import, migration,
or alias for a registry mutation. Bare `/callback` asks which verb. The package owns its provider,
front-door template, README managed-block template, setup/repair reconciler, bounded route
reconciler, scoped commit helper, and deterministic tests. Package scripts take an absolute project
root where needed and never discover configuration by scanning the front door; the installed
provider self-locates from `.callbacks/`.

Callback declares a `consumes: callback-action` typed edge: registrations supply agent actions for
its dispatcher. A subscriber may declare `produces: callback-action` when it exposes a stable agent
instruction or skill command intended for registration. Those leaf edges never name another skill.
A future composer may match the types and propose a concrete composition under its own contract.

### Registry contract

`.callbacks/registry.tsv` has schema `callback-registry@1` and exact header:

```text
event\tsubscriber\tkind\ttarget\ton_failure
```

Rows are the ordered data. In v1 every `event` is exactly `work-unit-boundary@1`. `subscriber` is a
stable lowercase identifier matching `[a-z0-9]([a-z0-9.-]*[a-z0-9])?` and is unique within an event;
examples include `project.release-note` and `project.security-check`. `kind` is exactly `instruction` or
`skill-command`. `on_failure` is exactly `advise` or `block`. Fields are nonempty single-line text
without tabs, carriage returns, NUL bytes, or other control characters.

An `instruction` target is a repo-relative Markdown path outside `.callbacks/`. It may not be
absolute or contain empty, `.` or `..` components; every existing component and the final regular
file must be non-symlink, and the resolved file must remain beneath the project root. The
registering subscriber or project owns the Markdown bytes; Callback never creates, refreshes, or
edits them. Registration validates both the path grammar and the current file. Dispatch validates
the stored grammar but does not suppress a syntactically valid row merely because its target later
disappeared.

At action time the anchor obtains instruction bytes only through the installed provider's
read-only `snapshot-instruction --target <repo-relative-path>` operation; it never reads the source
path directly. That operation revalidates the path grammar, every parent, and the final regular
non-symlink Markdown file, copies the bytes into a private mode-0600 temporary snapshot outside the
project tree, then rechecks the parent chain, source identity, metadata, and bytes before writing
the verified snapshot to stdout. It emits no instruction bytes unless every check succeeds and
always removes the temporary snapshot. Disappearance, replacement, byte change, or a symlink race
before the verified bytes are emitted refuses the operation and is that callback's failure under
its `on_failure` policy. The safety claim is that unstable or unverified bytes are never exposed to
the agent for execution; Callback does not claim to prevent another process from changing a
subscriber-owned file after a successful snapshot has been returned.

A `skill-command` target is one agent command line beginning with a slash skill name matching
`/[a-z0-9][a-z0-9-]*`, optionally followed by arguments. It is data for the harness's skill router,
not a shell command: the provider never evaluates, tokenizes, or executes it. Tabs, newlines,
carriage returns, NUL bytes, and other control characters refuse. Availability and the selected
verb's done condition are checked when the agent invokes the target, not inferred from an
installation path during registration.

The installed `callbacks.sh` is the sole registry writer and publishes `schema=callback-registry@1`
through `describe`. Its mutation interface is:

```text
callbacks.sh register --event <event> --subscriber <id> --kind <kind> --target <target>
  --on-failure <advise|block> [--first|--last|--before <id>|--after <id>]
callbacks.sh unregister --event <event> --subscriber <id>
callbacks.sh move --event <event> --subscriber <id>
  (--first|--last|--before <id>|--after <id>)
callbacks.sh list [--event <event>]
callbacks.sh dispatch --event <event>
callbacks.sh snapshot-instruction --target <repo-relative-path>
```

Omitted registration placement means `--last`. A relative ID must exist in the same event and may
not be the moving subscriber. An identical incumbent registration is `status=current` without
moving it; any different incumbent row for the same event/subscriber refuses
`reason=incumbent-conflict`. Changing target, kind, or failure policy therefore requires explicit
unregister/register operations. Unregistering an absent row is a no-op. Moving to the current
position is a no-op. There is no `update` alias.

Every mutation first acquires an exclusive `.callbacks/.registry.lock` directory with a decimal PID
owner file. An incumbent lock refuses `reason=registry-busy action=retry`; mutators never guess that
it is stale. While holding the lock, the provider validates the complete registry, snapshots the
destination, creates a fully validated replacement beside it, rechecks that the destination is
unchanged and canonical, then atomically renames and releases the lock. Normal exits and handled
signals remove only the lock token owned by that process.

Before acquiring its own lock, `/callback repair` may remove an incumbent lock only when the owner
file is an exact decimal PID and the platform process probe conclusively reports that no such
process exists. A successful `kill -0`, a permission error such as `EPERM`, PID reuse by a live
process, a malformed or unreadable owner, and any result that cannot be distinguished from those
states remain `reason=registry-busy action=human-inspect`; a generic nonzero probe status is not
proof of absence. After proven-stale removal, repair acquires and owns a fresh lock under the same
token rules as every other mutator.

A mutation reports only `wrote=registry.tsv` plus the affected subscriber; a no-op reports no
write. Physical row order is canonical event order followed by callback order within the event.
Positions are derived one-based values in `list` and `dispatch`, never persisted priority. A direct
destination change while the provider holds its lock causes `reason=registry-raced`; it is never
silently overwritten. Hand editing registry bytes is unsupported and documented as such.

The Callback skill invokes the staged provider for register, unregister, list, and move. Standalone
mutations commit only `.callbacks/registry.tsv` once through package-local scoped commit custody;
inside an announced configuration sweep they return the write without committing. Detached HEAD or
an unheld stream/feature branch refuses commit custody under the library's ordinary rule.

### Read-only dispatch and anchor behavior

Dispatch copies one stable regular-file snapshot, validates it completely, filters the requested
catalog event, and writes only stdout. Atomic provider rename means a concurrent read sees either
the complete old registry or the complete new one; dispatch does not acquire the mutation lock.
Empty configuration succeeds with `count=0`. Unknown events, malformed registry bytes, or
provider-state errors refuse before any callback frame.
Successful output is exactly one header followed by zero or more frames:

```text
schema=callback-dispatch@1
event=work-unit-boundary@1
count=<N>
--CALLBACK-BEGIN--
position=<one-based position>
subscriber=<id>
kind=<instruction|skill-command>
target=<target>
on_failure=<advise|block>
--CALLBACK-END--
```

The output is a snapshot. Registry mutations performed by a callback apply at the next event
boundary and never change the in-flight sequence.

Callback setup owns this exact behavioral block beneath the ordinary self-registered-routes
heading:

````markdown
<!-- skill:callback BEGIN built-against:callback-anchor@1 -->
### /callback — registered agent-event actions
Route: Configure explicit agent-event actions with `/callback setup`, `/callback register`,
`/callback unregister`, `/callback list`, `/callback move`, or `/callback repair`.
Edges: consumes `callback-action`.

**Work-unit boundary.**

This applies to the custodial main agent performing substantive repository work. It does not apply
to pure Q&A, routine status replies, or child/delegate sessions; those return byproducts to their
custodial caller.

`work-unit-boundary@1` occurs once, at the earliest of: before reporting a coherent work unit
complete; before beginning another coherent work unit after one completes; or before a healthy
reset or hand-off would discard substantive context. A coherent work unit is an outcome worth
reporting, not an individual edit, command, test, progress update, callback action, or callback
recovery action. Remember a completed boundary in current context and do not repeat the same unit.

At that boundary, automatically and without asking, run:

```sh
.callbacks/callbacks.sh dispatch --event work-unit-boundary@1
```

Require exactly `schema=callback-dispatch@1`, the requested event, the declared count, and complete
ordered frames. For `kind=instruction`, pass the frame's exact target as one argument to
`.callbacks/callbacks.sh snapshot-instruction --target <target>`, require success, and carry out only
the verified Markdown bytes returned on stdout; never read the registered source path directly.
For `kind=skill-command`, invoke the exact slash command through its installed skill. An action
succeeds only when its instruction or skill command reaches its own done condition.

If an action refuses, is unavailable, is ambiguous, or cannot reach done, report its event,
subscriber, and reason. `on_failure=advise` continues with the next frame and does not keep the
boundary pending; `on_failure=block` keeps the boundary pending and halts immediately before every
later callback, new work unit, or deliberate context discard. A missing provider, malformed
registry, invalid dispatch, or count/frame mismatch blocks globally before any action. Do not repair
or retry inside the blocked boundary. A response may report the primary unit complete only when it
also says that its callback boundary remains pending.

During involuntary compaction or context-pressure emergencies, preserve and recover primary work
first, then run the deferred boundary at the next safe opportunity. Dispatcher work, callback
actions, their reports, and later recovery are closure work for the preceding unit and never
recursively trigger another callback boundary.
<!-- skill:callback END -->
````

The complete-line reserved marker family begins `<!-- skill:callback BEGIN`; the exact end marker
is `<!-- skill:callback END -->`; the exact reserved H3 is `/callback — registered agent-event
actions`. Callback's route classifier admits `current`, `drifted-current`,
`replaceable-managed`, and `absent` states with the same bounded ownership rules already proven by
Backlog. Duplicate, nested, reversed, unmatched, overlapping, or unmarked-reserved-heading states
refuse before mutation. Setup and repair append, refresh, or preserve only Callback's extent and
never alter a sibling route. Grimoire's authored `AGENTS.md` remains patient-zero and never receives
the block; fixtures exercise it in consuming projects.

An advisory report is user-visible but does not solicit permission before the remaining callbacks.
A blocking report is terminal for the current turn. The agent does not run `/callback repair`,
override the failure, skip to a later frame, begin another unit, or deliberately discard context.
The user may invoke recovery in a later turn; after recovery the same pending boundary dispatches a
fresh registry snapshot from the beginning. Callback instructions must therefore be idempotent or
recognize their own completed done condition, just like directly invoked skill commands.

### Setup, repair, and interruption safety

Recognized Callback state is any canonical provider, registry, managed README block, or bounded
front-door route. An exact regular `registry.tsv` is the initialization boundary. With no recognized
state, setup may create the fixed empty registry and the package-managed surfaces. If recognized
state exists but the registry is absent, symlinked, or malformed, setup and repair refuse
`reason=registry-recovery-required action=git-restore`; they never infer registrations or replace
data with an empty file.

With a valid registry, setup preserves every row and reconciles only `callbacks.sh`, its executable
bit, the managed README block, and the exact Callback anchor. Repair requires that same valid
registry and has the identical package-managed write set; unlike setup, it never creates the layer
or registry. It may additionally clear only a provably stale mutation lock under the rule above.
After preflight, setup and repair acquire the same exclusive registry lock before refreshing any
package surface; a live or ambiguous owner refuses the operation, and the lock is held through final
validation. Setup and repair share one implementation rather than parallel copies. Both preflight
their complete write set and initial root state before creating anything. Setup may create
`.callbacks/` only when it was absent at preflight; repair never creates it, and neither operation
recreates a root that disappears or changes identity after preflight. Immediately before every
read, write, replacement, or execution, both operations revalidate the complete existing parent
chain and target as non-symlink directories or the required regular-file type. An unsafe, missing,
or replaced parent or target refuses that operation and every later mutation.

The reconciler snapshots the project-authored bytes outside Callback's managed README and
front-door extents, then rechecks those snapshots and the destination identity immediately before
atomic replacement. A concurrent surrounding-prose or sibling-route change refuses rather than
being overwritten. Interruption leaves either the old complete file or the new complete file; the
invocation reports every earlier durable write alongside the refusal, and a rerun converges without
silently reclaiming lost path custody.

The README contains one refreshable block delimited by `<!-- callback:tool BEGIN -->` and
`<!-- callback:tool END -->`, preserving all project-authored prose outside it. The block identifies
`callback-registry@1` and `callback-dispatch@1`, names `callbacks.sh` as the sole registry writer,
documents every public provider command, explains instruction versus skill-command targets and both
failure policies, warns against hand editing, and directs missing/stale package surfaces to
`/callback repair` while directing registry loss to Git recovery. Duplicate or malformed README
markers refuse before any write.

Setup does not claim knowledge of an interrupted process's write history. On a successful rerun it
compares the finite setup-owned postconditions—the exact registry initialization boundary when
created, exact provider bytes and mode, exact managed README extent, and exact anchor extent—with
Git. It emits `reconciled=` for an earlier durable result only when the current Callback-owned
extent exactly satisfies its setup postcondition and differs from `HEAD`. Current `wrote=` paths
plus proven `reconciled=` paths form standalone setup's unique commit path set for `Callback:
setup`. If a candidate extent cannot be distinguished from project-authored README or front-door
edits, setup refuses automatic commit custody and reports the path for human review. A clean,
committed rerun emits neither vocabulary and creates no commit.

Standalone repair commits only its exact unique current `wrote=` paths with `Callback: repair`; it
never reconciles an earlier invocation. An announced configuration sweep receives `wrote=` and
`reconciled=` paths without member-owned commits and retains custody of its approved destinations.
Neither verb touches subscriber-owned instruction files, Backlog, trackers, records, or any sibling
workspace namespace.

### Backlog boundary

Backlog owns no project front door and is outside Callback's implementation scope. This
specification does not define, install, advertise, or test a Backlog route, Callback registration,
or automatic debrief composition. Backlog's explicit `/backlog debrief` verb remains usable when a
caller invokes it, but any future workflow composition belongs to a separately reviewed change.
Neither Callback nor Backlog setup mutates the other's state.

## Verification

All setup, registry, route, and integration proofs operate on throwaway consuming projects. No test
or setup invocation installs Callback's route in grimoire's real `AGENTS.md`.

- **Provider schema and operations.** Exhaustive fixtures cover empty describe/list/dispatch;
  register default-last, first, last, before, and after; multi-row relative move; no-op moves;
  unregister present and absent; identical registration idempotence; incumbent conflicts; subscriber
  and field grammar; unknown events; both target kinds; event-local uniqueness; derived positions;
  stable dispatch snapshots; and byte-exact output framing. Red proofs weaken each validator and
  require the corresponding malformed fixture to pass only in the broken copy.
- **Path and race safety.** Instruction fixtures cover absolute, empty, dot, dot-dot, `.callbacks/`,
  outside-root, missing, directory, non-Markdown, file-symlink, and symlink-component targets at
  registration and action time. Instruction-snapshot injection before copy, during copy, and before
  verified-byte emission proves that a source, byte, or parent-chain race returns no instruction
  bytes and follows the row's failure policy; a controlled broken-anchor copy that reads the source
  directly must fail this assertion. Registry mutation injection before snapshot, before
  replacement, and before rename proves `registry-raced` refusal and no partial registry.
  Concurrent mutations prove one lock owner, one `registry-busy` refusal, and a successful retry
  that preserves both changes. Live, conclusively absent, reused-PID, permission-denied, malformed,
  and unreadable lock owners prove that repair clears only the conclusively absent case. ShellCheck
  passes for every Bash script.
- **Setup and repair.** Fresh setup creates the exact empty registry, executable provider, one
  managed README block, and one byte-identical anchor; a rerun writes nothing. Initialized setup and
  repair preserve registry bytes while refreshing each package-managed surface independently.
  Missing or malformed registry state, incompatible entries, symlinks, malformed README markers,
  and malformed route markers refuse before mutation. Parent-symlink replacement before every
  durable write, root disappearance during repair, and concurrent project edits around the README
  and route extents refuse without overwriting the raced bytes or performing later mutations.
  Failure injection after every durable write proves rerun convergence, registry preservation, and
  exact `wrote=` plus `reconciled=` standalone commit custody. Tracked project-authored README and
  front-door prose, mixed Callback/project edits, a clean committed rerun, and an announced
  configuration sweep exercise every custody branch. Repair never initializes an absent layer or
  recreates one that vanishes.
- **Anchor contract.** Deterministic scenario fixtures cover all three earliest-of trigger moments,
  coherent-unit examples and exclusions, current-context once-only behavior, zero callbacks,
  instruction then skill-command order, advisory report-and-continue, blocking immediate halt,
  global provider/registry failure, count/frame mismatch, target disappearance, deferred emergency
  recovery, fresh-snapshot retry, and no callback recursion. Controlled broken-template copies
  remove each instruction class and must make its assertion fail.
- **Backlog independence and hard cut.** Source guards reject any Backlog production access to
  `.callbacks/`, `/callback`, `AGENTS.md`, `CLAUDE.md`, or route-management helpers. Callback has no
  built-in `/backlog debrief` dispatch. Red proofs plant each forbidden coupling in temporary
  live-source copies.
- **Hosted acceptance.** Repeat the attended four-scenario matrix under the current Grok and Codex
  harnesses using the implemented provider and installed anchor: completion with ordered actions;
  autonomous two-unit transition; pure Q&A; and advisory-then-blocking failure.
  Omit the deferred canary from transition fixtures. All eight cells must be unambiguous from logs,
  exact files, tracker state, Git ordering, and final worktree state; any failed or ambiguous cell
  blocks implementation acceptance and publication of its acceptance spike.
- **Repository gates.** Callback's complete harness, Backlog's complete harness, repository
  integration tests (`scripts/tests/run.sh`), `skills/skill-builder/scripts/skills-lint.sh`,
  ShellCheck, the consuming-project fixture, and `git diff --check` pass. README and PACK inventory
  agree that Callback is an optional Clankshop utility and Backlog owns only tracker-layer state. A
  live-source search confirms no production `debrief-anchor@1`, no arbitrary
  executable callback kind, no commit-derived route marker, and no `skill:callback` or
  `skill:backlog` block in grimoire's authored front door. Each absence assertion is mutation-red-
  proved in an isolated live-source copy: plant a Backlog front-door access, arbitrary executable kind,
  commit-derived marker, patient-zero Callback or Backlog block, hidden registration path, and
  second dispatcher one at a time; require its guard to fail, then restore the exact copied source
  population before the next mutation.

The feature is complete when Callback is the sole owner and dispatcher of
`work-unit-boundary@1`, registry mutations are explicit and race-safe, agent instructions and skill
commands obey stable relative order and declared failure policy, Backlog remains outside Callback's
route and registration contract, all deterministic and hosted acceptance gates pass, and no second
dispatcher or hidden registration path exists.
