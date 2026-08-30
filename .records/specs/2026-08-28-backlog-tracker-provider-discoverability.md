---
doctype: specs
status: published
schema: architect/spec@1
tags: [backlog, trackers, discovery, setup]
---

# Backlog tracker-provider discoverability and durable setup hard cut — Spec

## Problem

Backlog's first-class `<agent-trackers>` layer is intended to be public project state, but an agent
that discovers the directory cannot currently learn the layer's basic operating contract from that
surface alone. Its generated README gives only a terse pointer, and the current fixed provider
name reads like an implementation detail rather than the layer's ordinary tool.
Understanding how to inspect or mutate tracker state therefore still depends on loading the Backlog
skill, even when the agent needs only the public `tracker@1` interface. If the adjacent provider is
missing, the layer also gives the discovering agent no recovery path.

The provider filename and README treatment are part of the public layer contract established by
the published base spec (→ `specs/2026-08-27-backlog-routines-and-universal-debrief.md`), so
changing them only in an implementation plan would leave two conflicting authorities.

Project front-door registration and automatic agent-event dispatch are outside this addendum.

Setup also treats every application as another initialization request. Reapplying defaults can
undo a project's deliberate queue removal, while making a configurable first-run selection resume
automatically would require setup to persist intent that cannot be recovered from a partial set of
queue files. The same custom or empty population is already reachable through explicit tracker
administration after initialization, so first setup does not need a second configuration surface.

## Goal

Make `<agent-trackers>` self-explaining: its sole canonical provider is adjacent
`trackers.sh`, and its README teaches enough of `tracker@1` for an agent to discover, inspect, and
use the layer safely without loading Backlog. A missing or invalid package-managed provider on an
initialized layer directs the agent to `/backlog repair`, which restores the tool-facing managed
surface without resetting the project's configured queues or tracker data. Rerunning
`/backlog setup` remains safe and includes the same repair step.

Make first setup deterministic without a private transaction artifact. It always initializes the
four built-in queues; projects then change that population through explicit tracker administration.
A valid `receipts.tsv` is the durable initialization boundary: before it exists, setup may resume
only the one fixed initialization; afterward, queues are incumbent configuration and setup never
recreates a removed queue. Git and Backlog's bounded ownership seams supply interrupted-write and
commit custody without a private workspace transaction record.

This is a hard cut. Current package-managed setup, runtime consumers, and Backlog-owned
instructions neither support nor migrate the prior provider filename. Project-owned prose outside
the managed README block is preserved under its own authority and is not part of that compatibility
claim. The tracker schema, commands, successful machine-readable output, data, and lifecycle do not
change; canonical paths, examples, comments, and path-bearing diagnostics receive only the declared
provider-filename substitution.

## Approach

This spec is an addendum to the published base spec above. It overrides that spec's fixed provider
filename, its absent-only treatment of the tracker-root README, first-setup queue selection, and the
rule that every bare setup invocation reapplies the default queue selection. The base spec remains
authoritative for `tracker@1`, root resolution and validation, queue and receipt schemas, existing
Backlog verbs, consumers, debriefing, and tracker lifecycle; this addendum introduces the repair
verb. It does not define or constrain project front-door registration or automatic agent-event
dispatch.

Rename the bundled and staged provider to `trackers.sh`, repoint every live consumer atomically,
and give Backlog one delimited package-managed block inside `<agent-trackers>/README.md`. Setup may
create or refresh that block while preserving all surrounding project prose. The block is the only
instruction inside the tracker root that Backlog manages refreshably.

Make setup convergent rather than repeat initialization on every invocation. First setup has one
deterministic population—`tasks`, `issues`, `feedback`, and `routines`—and publishes the receipt
ledger only after the provider, queues, and prompt sections validate. Once that boundary
exists, the incumbent queues are configuration: setup preserves them and reconciles only the
provider, managed README block, and matching prompt sections. `/backlog repair` exposes the
provider-and-README portion of that same
reconciliation mechanism for an initialized layer; it is not a second installer. Queue creation and
removal, including reaching a custom or empty population, are explicit tracker-administration
operations after initialization.

The cut deliberately has no compatibility ladder. Setup and runtime code do not probe, copy,
rename, delete, validate, invoke, or otherwise branch on the prior filename. A pre-cut file remains
untouched project residue and is never consulted by package-managed code. Backlog likewise does not
recognize or rewrite prior generated README prose outside its new ownership block; surrounding
incumbent prose remains project-owned even when stale. The managed block therefore identifies itself
as Backlog's current package-owned tool contract: surrounding prose may document project practice,
but it cannot redefine the canonical provider named by that block.

Alternatives rejected:

- **Alias or wrapper at the prior filename.** This would preserve two public entrypoints and make
  the supposedly retired name indefinitely discoverable.
- **Keep `tracker-api.sh` and add only the managed README and repair behavior.** The provider's
  adjacent filename is itself part of the public project-layer affordance. Retaining the old name
  would avoid the cut but preserve the implementation-oriented entrypoint this addendum deliberately
  replaces; the one canonical public tool is therefore `<agent-trackers>/trackers.sh`.
- **Setup-time migration or cleanup.** Detecting, moving, or deleting the pre-cut file would add a
  compatibility branch to every future setup and make the new contract depend on legacy state.
- **Only expand Backlog's skill documentation.** Agents discovering `<agent-trackers>` would still
  need to locate and load the skill before understanding a public project layer.
- **Overwrite the whole README.** The tracker root is public project state; project-authored prose
  outside Backlog's explicit ownership seam must survive setup.
- **Reapply the default queues on every bare setup.** A recovery command could recreate a queue the
  project intentionally removed, so an operational repair would also become a configuration
  mutation.
- **Persist a workspace setup intent.** A private transaction record would make a configurable
  first-setup selection recoverable, but it would add a second source of setup authority and a
  lifecycle whose only steady-state result is deletion. Fixed initialization plus the receipt-ledger
  boundary makes the intended result derivable instead.
- **Infer a configurable first-setup selection from partial files.** An absent queue is
  indistinguishable from an intentionally excluded queue. Setup therefore has no configurable
  first-run population to infer: customization begins only after the fixed initialization succeeds.
- **Make repair an independent installer.** Duplicating setup's validation and provider-copy logic
  would let the two recovery paths drift. Repair is instead a constrained entrypoint to setup's
  shared reconciliation mechanism.

## Mechanism

The fixed public shape becomes:

```text
<agent-trackers>/
  README.md
  trackers.sh
  receipts.tsv
  <stem>.tsv
```

Backlog packages `skills/backlog/scripts/trackers.sh`. Setup installs or refreshes it only at
`<agent-trackers>/trackers.sh`, restores its executable bit when necessary, and reports that
canonical path through its existing `wrote=` vocabulary. The provider continues to self-locate
from its parent directory and publishes the exact existing `tracker@1` contract through
`describe`. Its subcommands, arguments, TSV schemas, receipts, paging, validation, and
successful machine-readable output remain byte-for-byte behavioral contracts. Canonical executable
paths, invocation examples, package comments, and path-bearing diagnostic details change only by
substituting `trackers.sh` for the prior filename.

### Setup and repair

Setup and repair share one reconciliation mechanism with different entry conditions and write
sets:

| Invocation | Admitted state | Reconciliation write set |
|---|---|---|
| `/backlog setup` | No recognized Backlog state | An optional custom-root declaration, provider, four built-in queues and prompt sections, ledger, and managed README block |
| `/backlog setup` | Exact resumable fixed prefix without a ledger | Only the missing extents of that same fixed initialization |
| `/backlog setup` | Valid ledger and valid incumbent queue schemas | Provider, managed README block, and missing prompt sections only for incumbent queues |
| `/backlog repair` | Existing root, valid ledger, and valid incumbent queue schemas | Provider, executable bit, and managed README block only |

Setup resolves `<root>`, `<agent-records>`, `<agent-workspace>`, and `<agent-trackers>` through the
ordinary front-door rules. A first-setup `--trackers-root` remains legal only when no declaration or
Backlog state exists. After complete preflight, setup writes that declaration as its first durable
change, before creating anything at the custom root. A bare rerun can therefore resolve an
interrupted custom-root initialization; an interruption before the declaration leaves no durable
setup write.

Recognized Backlog state is a canonical provider, receipt ledger, queue TSV, managed README block,
or Backlog debrief prompt. Unowned README prose and the pre-cut provider filename do not count. A
valid regular `receipts.tsv` is the sole initialization boundary. With that
boundary present, setup treats the incumbent queue population as configuration and never interprets
an absent queue as permission to add defaults. Setup accepts no queue selection in either state and
directs population changes to `/backlog tracker add|remove`.

Without a receipt ledger, setup admits only an absent layer or an exact deterministic prefix made of
the canonical provider, any subset of the four empty built-in queues and their package-created prompt
sections, and an earlier custom-root declaration. Present package-owned extents must match their
setup postconditions; incumbent editable prompt bodies survive, and queue TSVs have only the exact
header. A custom or nonempty queue, managed README block, malformed extent, or other ambiguous state
refuses before mutation. When the current `HEAD` contains the canonical ledger path but the worktree
does not, setup reports `reason=ledger-recovery-required action=git-restore`. A managed README block
without a ledger and without that Git evidence proves post-ledger damage but not a recoverable Git
copy, so it reports `reason=ledger-recovery-required action=human-review` and does not mutate. With
neither witness, a deleted uncommitted ledger whose remaining bytes match the fixed prefix is
indistinguishable from interrupted initialization, so setup resumes and may recreate an empty
ledger. This is the accepted bound of using resulting state instead of a private transaction
artifact: recoverable historical contents are never recreated, but unwitnessed loss cannot be
diagnosed. Projects needing Git recovery must commit the completed setup result.

First setup validates the roots and complete write set, then installs or validates, in order, any
custom-root declaration, the canonical provider, all four built-in queues, and their prompt
sections. It atomically creates `receipts.tsv` only after those pre-ledger surfaces pass their final
validation. The ledger is therefore a durable declaration that fixed initialization completed, not
a transaction journal. Setup then validates `describe` and `catalog` before appending or refreshing
the managed README block. An interruption before the ledger leaves only a resumable fixed prefix;
an interruption after it leaves an initialized layer whose missing provider, managed README, or
prompt surfaces are ordinary reconciliation work.

After the ledger boundary, neither entrypoint creates or replaces the ledger or creates or removes
queues. Setup may add a missing prompt section only for a queue that exists; repair never touches the
prompt. Both call the same provider-and-README primitive.

Both entrypoints preflight their complete write set and refuse unsafe paths, incompatible entries,
malformed schemas, or malformed README ownership markers before writing. They preserve valid queue
bytes, receipt rows, project-authored README prose, incumbent prompt bodies, and unrelated
front-door bytes. Missing absent-only scaffolding may be created only
within setup's write set; package-owned provider bytes and the managed README block may be
refreshed. Paths changed by the current invocation use the existing `wrote=` vocabulary.

Setup does not claim knowledge of the exact write history of an interrupted process. On a successful
rerun it instead compares the finite setup write set with Git and emits `reconciled=` for an earlier
durable result only when the current bytes satisfy the exact setup-owned postcondition and the
Backlog-owned extent differs from `HEAD`. The current invocation's `wrote=` paths and those proven
`reconciled=` paths form standalone setup's commit path set. A dirty candidate whose setup-owned
extent cannot be distinguished from unrelated project edits refuses automatic commit custody and
returns the path for human review. An announced configuration sweep retains its existing ownership
of the approved destination diff. A clean committed rerun reports neither vocabulary. Standalone
repair commits only its unique `wrote=` paths under the existing custody rules.

Neither entrypoint recovers deleted tracker rows or historical receipt contents; Git owns that
recovery. After initialization, setup never recreates a removed default queue merely because it was
part of the original default selection.

Backlog, Analyst, Foreman, and integration fixtures resolve `<agent-trackers>` through the existing
front-door rule and invoke `trackers.sh` directly. They do not fall back to the bundled provider or
any other installed filename. Current library documentation and portable doctrine name
`<agent-trackers>/trackers.sh`; historical records retain the names that were true when written.

Backlog owns exactly one README block:

```text
<!-- backlog:trackers-tool BEGIN -->
...
<!-- backlog:trackers-tool END -->
```

The shared reconciliation mechanism inventories the README and all other destinations before
writing. Exactly zero or one well-formed block is valid. Duplicate, nested, reversed, or unmatched
delimiters refuse before any write. When absent, reconciliation appends the block without changing
existing bytes other than the separator needed before the block. When present, it replaces only
the bytes from its begin marker through its end marker. A byte-identical rerun reports no README
write.

The managed block identifies `tracker@1` and explains:

- the delimited block is Backlog's current package-owned tool contract, so surrounding
  project-authored guidance does not redefine its canonical provider;
- `README.md` is the local guide, `<stem>.tsv` files are current queue state, and `receipts.tsv` is
  the observation/consumption ledger;
- `trackers.sh` is the sole writer for queue rows and receipts, while Git owns history, merge,
  recovery, and rollback;
- if `./trackers.sh` is missing, non-executable, or does not describe exactly `schema=tracker@1`,
  agents stop, do not hand-repair it or run the bundled provider against project data, and run
  `/backlog repair` to restore the package-managed surface;
- direct TSV inspection is allowed, but agents do not hand-edit queue or receipt bytes;
- commands are run from the tracker-root directory so every example safely uses the adjacent
  `./trackers.sh`, independent of custom tracker-root characters;
- `describe`, `catalog`, and bounded `page` are read-only discovery operations; and
- `create`, `update`, `observe`, and `consume` are the guarded mutation forms, with stable consumer
  keys, required consumption resolutions, optional evidence/results, and provider-reported paths.

The README shows one representative invocation of every provider command using the existing exact
flags and placeholders. It does not reproduce the entire Backlog workflow, debrief routing
judgment, setup procedure, or commit-custody rules; those remain skill concerns rather than layer
basics.

Reconciliation writes or refreshes the managed README block only after the canonical provider and
the substrate required by its documented discovery commands are installed and validated. At
minimum, `trackers.sh` is executable, `receipts.tsv` is valid, `describe` emits exactly one line
beginning `schema=` and that line is exactly `schema=tracker@1`, and `catalog` succeeds before the
README may advertise the tool. All other existing `describe` output remains unchanged. Each
destination is rechecked immediately before its write. An interruption may therefore leave a
usable provider without the new guide, but never a newly written guide pointing to an unusable
provider.

Before Backlog-owned file, query, debrief, or curate work invokes the provider, a missing,
non-executable, or invalid canonical provider refuses with the exact recovery diagnostic
`reason=repair-required action=/backlog repair` when a valid receipt ledger establishes
initialization. Without that boundary, Backlog operations report
`reason=ledger-recovery-required action=git-restore` when `HEAD` contains the missing ledger,
`reason=ledger-recovery-required action=human-review` when only the managed README proves post-ledger
damage, and otherwise `reason=setup-required action=/backlog setup`; they never infer or resume setup
themselves. The adjacent README carries the steady-state repair instruction for agents that discover
the layer without loading Backlog. Generic consumers remain independent: Analyst and Foreman may
report or degrade around an unavailable provider, but they invoke neither Backlog recovery verb nor
the bundled copy.

## Verification

All setup and provider proofs run against throwaway project fixtures, never grimoire's authored
root.

- Fresh default and custom-root setups produce exactly the four built-in queues, executable adjacent
  `trackers.sh`, a valid receipt ledger, matching prompt surfaces, and exactly one managed
  README block without deploying the pre-cut filename or creating a private setup artifact. Failure
  injection after every durable write proves that a pre-ledger rerun admits only the valid fixed
  prefix, completes only missing steps, and creates the ledger only after the provider, queues, and
  prompt validate. An interruption after ledger creation resumes as initialized
  reconciliation. A custom-root fixture interrupts immediately before and after the
  `agent-trackers:` declaration; the former leaves no durable setup write, while the latter lets bare
  setup resolve the declared custom root and never initialize `.trackers`.
- Resumable-prefix fixtures admit every valid subset of the canonical provider, empty built-in
  queues, and package-created prompt sections. Custom or nonempty queues, a managed README block
  without its ledger, a ledger present in `HEAD` but missing on disk, malformed postconditions, and
  unsafe destinations all refuse before mutation. The Git-backed deletion reports `action=git-restore`;
  the README-only case reports `action=human-review` because no recoverable Git copy is proven. A
  distinct fixture removes an uncommitted ledger before the README exists, proves that its remaining
  exact prefix is indistinguishable from interrupted initialization, and expects deterministic
  resumption with a new empty ledger; the test names this limitation rather than presenting it as
  loss detection.
- Initialized-layer setup fixtures preserve default-with-removal, custom, and deliberately empty
  queue populations. They refresh drifted package bytes and managed README content, restore a
  deleted provider, and reconcile only matching prompt sections implied by the incumbent queues.
  Queue and receipt bytes, prompt bodies, surrounding README prose, and unrelated front-door bytes
  survive. Setup exposes no queue-selection form, repair does not mutate queues or prompts, and a
  clean committed rerun reports neither `wrote=` nor `reconciled=`.
- Repair fixtures restore only the provider and managed README block with the same rendered bytes
  and validation setup uses. Clean repair is a no-op; uninitialized, malformed-ledger,
  malformed-state, and unsafe-destination cases refuse before mutation. Provider absence,
  non-executable mode, and wrong-schema bytes on an initialized layer produce
  `reason=repair-required action=/backlog repair`; absence of the ledger produces
  `reason=ledger-recovery-required action=git-restore` when `HEAD` contains the ledger,
  `reason=ledger-recovery-required action=human-review` when only the managed README witnesses loss,
  and otherwise `reason=setup-required action=/backlog setup`. The README carries the repair command
  and warning against hand-repair or use of the bundled copy.
- A hard-cut red proof plants uniquely recognizable executable bytes at the pre-cut filename. The
  pre-change implementation must fail the fixture; the completed setup leaves those bytes
  unchanged, stages and invokes only `trackers.sh`, and no live caller or current Backlog-owned
  instruction names the planted path. The same upgrade fixture preserves an exact pre-cut generated
  README sentence outside the new markers while proving the managed block unambiguously names itself
  as the current package contract and `trackers.sh` as its sole canonical provider. Preserved project
  prose, historical specs/plans, and the explicit negative fixture are excluded from the live-source
  absence verdict.
- Malformed, duplicate, nested, reversed, and unmatched README markers refuse before any setup or
  repair write; mutation red proofs require every marker guard to fail when weakened. Failure
  injection around provider installation and validation proves that the README remains absent or
  unchanged until ledger publication, `describe`, and `catalog` succeed, earlier safe writes remain
  valid, and rerun converges.
- Git-custody fixtures interrupt after every setup write, then rerun from the resulting filesystem
  and `HEAD`. They prove that the current invocation reports its `wrote=` paths, exact earlier
  setup-owned differences report as `reconciled=`, both vocabularies form the standalone commit
  path set, and a candidate mixed with an indistinguishable project edit refuses automatic commit
  custody. After that commit, a clean rerun reports neither vocabulary.
- Mutation red proofs independently disable the resumable-prefix classifier, Git-recoverable and
  README-only ledger-loss guards, receipt-ledger publication boundary, initialized-queue
  preservation, and repair-entry guards and require each corresponding fixture to fail, proving that
  the named guard rather than incidental validation causes the refusal.
- README contract fixtures execute representative rendered forms of all seven commands against a
  staged provider: `describe`, `catalog`, bounded `page`, `create`, `update`, `observe`, and
  `consume`. They verify the resulting row and receipt effects so correct provider tests cannot hide
  a broken documented invocation. Provider contract fixtures preserve successful machine-readable
  output byte-for-byte and require every canonical path, example, package comment, and path-bearing
  diagnostic change to be only the declared provider-filename substitution.
- Backlog's complete harness, Analyst's live-provider facts, Foreman's tracker-tuning fixture, the
  consuming-project configuration fixture, skill lint, and repository integration tests all pass.

The addendum is complete when these proofs establish one canonical filename, one safely refreshable
README ownership seam, deterministic fixed first-setup resumption without a private transaction
artifact, an explicit receipt-ledger initialization boundary, non-destructive steady-state
reconciliation through setup and its repair subset, bounded Git-derived commit custody, unchanged
`tracker@1` behavior apart from the declared canonical-filename substitution, witness-bounded ledger
loss detection, and no compatibility or migration path for the pre-cut name.
