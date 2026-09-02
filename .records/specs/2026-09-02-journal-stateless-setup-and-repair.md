---
doctype: specs
status: published
schema: architect/spec@1
tags: [journal, setup, repair, stateless]
---

# Journal stateless setup and repair — Spec

Supersedes the setup-transaction and repair mechanism in
→ `specs/2026-08-28-journal-records-provider-discoverability-and-durable-setup.md`.
The adjacent-provider and managed-README decisions from that specification remain in force.

## Problem

Journal setup persists a private `.spaces/journal/setup.intent` write-ahead file so a later
invocation can reconstruct the exact set of tool-layer paths written before an interruption. That
mechanism makes one setup attempt's commit custody recoverable, but it also creates a second source
of setup state outside the public records layer, adds an applying/ready/finalize lifecycle, and makes
ordinary runtime behavior depend on the presence and safety of a transient file.

The extra state has proved more expensive than the guarantee it preserves. Agents have repeatedly
treated an absent intent as evidence that Journal is uninstalled even though absence is the normal
steady state. A stale, malformed, or unsafe intent also blocks search, closure, curation, and repair
despite the actual `.records` layer being independently inspectable. The result is unnecessary setup
runs, misrouted recovery, and time spent reasoning about transaction state rather than the files the
user cares about.

Journal's fixed `.records` home no longer needs a private transaction to identify the intended end
state. Its provider, ledger, and managed README block have deterministic postconditions, and Git can
show any surviving project changes after an interrupted invocation. Exact automatic reconstruction
of a cross-attempt write union is therefore not worth retaining.

## Goal

Remove `setup.intent` and its lifecycle from Journal. `/journal setup` and `/journal repair` become
stateless, convergent reconciliation operations whose decisions come from the fixed `.records`
layer plus read-only Git recovery evidence, never from private setup state; interruption leaves safe
partial results that the same command can inspect and finish on its next invocation.

Runtime operations must never consult `.spaces/journal`, and setup must no longer require a separate
finalization step. The accepted trade-off is that Journal will not automatically reconstruct the
exact set of paths written across multiple crashed attempts; the caller will inspect the bounded Git
diff before committing recovered work.

This is a hard cut. Setup and repair target the current canonical contract in a generic brownfield
project; they do not detect, classify, migrate, clean up, or otherwise support artifacts from prior
Journal versions.

## Approach

Use the same state-derived model as a conventional fixed-layer installer:

- a safe regular `.records/history.tsv` is the initialization boundary;
- the provider and managed README block are independently reconcilable projections;
- every individual destination replacement remains atomic;
- setup derives missing or stale work from the current filesystem on every invocation; and
- unflagged repair is the initialized-layer subset of that same reconciler.

An interruption may expose a partial prefix of safe destination changes. This is acceptable: no
partial file is published, the ledger boundary tells repair whether initialization completed, and a
rerun converges the remaining paths without consulting prior invocation state. In Git repositories,
the helper classifies the bounded diff of Journal-owned destinations before the caller commits. A
recovered path changed by an earlier attempt may appear there even when the rerun did not rewrite
it.

Alternatives rejected:

- **Retain a persistent transaction under the same or a different name.** Any recovery journal
  preserves the second source of authority, extra runtime dependency, and setup lifecycle merely to
  keep exact automatic cross-attempt commit custody.
- **Use one Git commit or staging area as the transaction record.** Setup works before all projects
  have a usable commit context, the shared index is contended across worktrees, and partially staged
  state would move the same recovery problem into Git.
- **Atomically replace the entire `.records` directory.** The directory contains project records,
  ledger history, and project-owned README prose. Whole-directory replacement would violate
  Journal's ownership boundary.
- **Recognize and clean up earlier Journal layouts.** Version-shaped probes would turn setup into a
  migration engine and retain the compatibility branches this cut is meant to remove. Brownfield
  reconciliation considers only current canonical paths and ownership markers.

## Mechanism

### State model

Setup, bare repair, and runtime have no private setup state and do not resolve or inspect `.spaces`
on their own. Files outside the current canonical paths are inert project residue to those
operations: the hard cut does not read them, use them to select work, block on them, clean them up,
or add a continuing compatibility branch for them. The sole explicit-source exception is
`/journal migrate <source-root>`, which may inspect the exact project path the human names but never
infers that path from retired declarations or version-shaped artifacts.

The fixed public paths are:

```text
.records/records.sh
.records/history.tsv
.records/README.md
```

Classify state in this order:

- **unsafe**: `.records` or any destination that the selected operation must inspect or mutate is a
  symlink, directory of the wrong kind, unreadable, or otherwise outside the existing path-safety
  contract;
- **initialized**: `history.tsv` is a safe regular file;
- **recoverable ledger loss**: `history.tsv` is absent but the Git `HEAD` for this project tracks
  that exact path;
- **ambiguous ledger loss**: `history.tsv` is absent, Git cannot restore it, and either the current
  Journal-managed README block exists or the records crawl contains an archived record whose closure
  history requires a ledger; and
- **uninitialized or resumable initialization**: `history.tsv` is absent, Git does not track it,
  and neither the current managed README block nor an archived record witnesses prior closure
  history.

For any admitted state, **current** means every destination in the selected operation's write set
satisfies its deterministic postcondition. The provider or README may be absent or stale on an
initialized layer. That is repairable projection drift, not evidence that initialization is
incomplete.

Setup refuses recoverable ledger loss with exactly
`reason=ledger-recovery-required action=git-restore`. It refuses ambiguous ledger loss with exactly
`reason=ledger-recovery-required action=human-review`. Only the final state above permits creation
of a new empty ledger. A deleted untracked ledger remains indistinguishable from interrupted
initialization when neither Git nor a surviving managed-block or archived-record witness exists;
accepting that bound is part of choosing a stateless design, and projects that need durable recovery
commit the initialized layer.

### Stateless setup

`scripts/standup.sh setup <root>` performs one invocation-local reconciliation:

1. Resolve the fixed project root and `.records` paths. Do not resolve or inspect `.spaces`.
2. Preflight the complete setup write set before mutation: `.records`, `records.sh`, `history.tsv`,
   `README.md`, the current managed-block marker shape, Git's exact ledger-path witness, and the
   read-only archived-record witness. Preserve the current all-before-write refusal behavior for
   unsafe destinations and malformed current markers. Refuse either ledger-loss state before any
   write. Do not probe for version signatures, retired paths, or earlier generated prose.
3. Reconcile `records.sh` with an atomic sibling-file replacement when absent, byte-stale, or
   non-executable. Validate the installed bytes, mode, exit status, usage heading, and complete
   command roster before advertising the provider.
4. If `history.tsv` was absent and setup classified the layer as uninitialized or resumable, create
   an empty regular ledger atomically after the provider postcondition holds. Never truncate,
   replace, or reinterpret an incumbent ledger.
5. Reconcile only Journal's current delimited README block after a safe regular ledger exists,
   preserving every unowned byte. Prose outside the current block is project-owned regardless of
   whether it resembles output from an earlier Journal version.
6. Run the content-aware provider `check`. A failure leaves the reconciled tool layer in place and
   emits the neutral curation route. Setup does not classify failures as migration work or prescribe
   a writer migration.
7. Emit current and recovered commit-custody paths as defined below and exit. There is no `phase`,
   pending/completed set, ready transition, or `finalize` mode.

The provider → ledger → README order makes an interrupted first setup derive cleanly. Before ledger
creation, only a current canonical provider can be a resumable deterministic prefix. After ledger
creation, the layer is initialized and setup or repair can reconcile a missing README. Publishing
the current managed block only after the ledger exists makes that block a reliable witness of later
ledger loss. A content-check failure after these writes does not undo initialization.

### Stateless unflagged repair

Bare `/journal repair` invokes `scripts/standup.sh repair <root>` and uses the same reconciliation
primitives with a smaller write set:

1. Require a safe existing `.records` directory and safe regular `history.tsv`; an absent ledger
   reports `reason=setup-required action=/journal setup`.
2. Preflight the provider, README, and managed markers before mutation.
3. Reconcile and validate `records.sh`, then reconcile the managed README block.
4. Run the same content-aware check and neutral curation diagnostic.
5. Emit current and recovered commit-custody paths under the shared contract below; candidates are
   limited to the provider and README.

Unflagged repair never creates or changes the ledger, touches records, performs prior-provider
cleanup, or consults `.spaces`. A clean repair is a no-op. This section governs bare repair only;
`/journal repair --closure` has a separate contract.

### Runtime preflight

Journal search, done, and curate inspect actual public-layer state in this order:

1. absent, non-regular, or unsafe `.records/history.tsv` → exactly
   `reason=setup-required action=/journal setup`;
2. absent, non-regular, non-executable, stale, unsafe, or usage-incomplete
   `.records/records.sh` → exactly `reason=repair-required action=/journal repair`; and
3. otherwise invoke only the staged provider.

No runtime verb inspects `.spaces` or an intent-shaped file. The adjacent provider guide describes
the same public-state recovery routes.

### Commit custody after interruption

After reconciliation, the helper compares the selected operation's bounded candidate paths with
Git `HEAD`: setup considers `records.sh`, `history.tsv`, and `README.md`; repair considers only
`records.sh` and `README.md`. It records `wrote: <repo-relative-path>` for every destination changed
by the current invocation, but that provenance does not itself admit the path to a commit. Every
candidate that differs from `HEAD`, including a `wrote:` path, must independently pass the complete
ownership test: the provider equals the bundled executable and its whole diff is the package
result, the ledger is a new safe regular empty file absent from `HEAD`, or every README change is
confined to the current managed block. A valid candidate not already reported as `wrote:` emits
`reconciled: <repo-relative-path>`.

A modified incumbent ledger, an unowned README hunk, provider bytes that do not match the bundle, or
any other ambiguous candidate returns `reason=commit-custody-required detail=<path>` and suppresses
the entire automatic commit; completed writes remain as an inspectable project diff. Only after all
dirty candidates pass does standalone setup or repair commit the unique union of admitted `wrote:`
and `reconciled:` paths. An announced sweep retains that proven union in its approved diff custody.
A clean committed rerun emits neither vocabulary. Outside Git, reconciliation still reports current
writes but cannot recover cross-attempt commit custody. The caller never reconstructs these
classifications from prose.

### Documentation and historical state

The new specification supersedes the intent-based transaction, finalization, runtime gate,
cross-attempt commit-union, and automatic prior-path recognition and cleanup requirements of the
prior provider/setup specification. Provider adjacency, the current managed README ownership seam,
path safety, atomic destination replacement, and the setup-versus-unflagged-repair write-set
boundary remain unchanged.

`/journal migrate` remains only as `/journal migrate <source-root>`, an explicit preview, confirm,
and Git move of the exact dedicated records root the human names. Remove its no-argument source
inference, retired-declaration recognition and cleanup, setup-intent handling, and finalization
path. After the move it invokes stateless setup against `.records`. It contains no prior-version
recognition or compatibility behavior; retired declarations and paths outside the named source
remain untouched project residue.

After this specification is accepted, close the prior specification as `superseded`, naming this
record. Historical records remain unchanged. Current skill prose, helper comments, usage, tests, and
project-facing templates must contain no operative `setup.intent` contract.

## Verification

All behavioral tests use disposable projects.

- Red-first contract tests remove the intent preflight from Journal runtime prose and fail if any
  current runtime verb treats a workspace path as state. Present regular files, symlinks, and an
  unsafe `.spaces` parent are ignored when the public records layer is healthy.
- Setup tests inject failure after each provider, ledger, and README destination
  commit. Every partial result contains only complete files; the next stateless setup converges;
  the README block is published only after ledger creation; no invocation inspects or creates a
  workspace path or requires finalization.
- Missing-ledger fixtures prove that a ledger tracked by `HEAD` routes to `git-restore`, a current
  managed README block or archived record without a recoverable ledger routes to `human-review`, and
  only a layer with none of those witnesses may initialize an empty ledger. Mutating any guard makes
  its fixture fail.
- Generic brownfield fixtures contain unrelated records-root prose and files plus recognizable
  prior-version-shaped residue outside the current owned paths. Setup and repair reconcile only the
  current canonical provider, ledger, and managed block and neither inspect nor modify that residue.
- Migration fixtures require an explicit source root, prove that retired declarations cannot select
  a source and remain byte-identical, and preserve the existing preview, confirmation, path-safety,
  whole-root Git move, and post-move stateless-setup contracts.
- Initialized setup fixtures preserve record and ledger bytes while repairing provider/README
  drift. Clean setup writes nothing. Unsafe destination and malformed-marker fixtures still refuse
  before mutation.
- Unflagged-repair fixtures prove that it reads no workspace state, never changes ledger or record
  bytes, refuses an absent or unsafe ledger, and changes only provider/README projections.
- A Git-backed interruption fixture proves that a path changed by a killed attempt remains visible
  as `reconciled:` after a convergent rerun. Provider, new-ledger, and managed-README fixtures
  exercise every accepted classification; mismatched provider bytes, a modified incumbent ledger,
  and an unowned README hunk produce the commit-custody diagnostic instead of entering the commit.
  A distinct fixture refreshes a managed block atop a pre-existing unowned README hunk during the
  current invocation and proves that `wrote:` provenance cannot bypass the same refusal or admit any
  other candidate to an automatic commit.
- Every setup-time `check` failure emits `records check failed — tool layer is current;
  action=/journal curate`; setup neither classifies the failure as legacy work nor claims that writer
  migration is required.
- Mutation red proofs disable the README-after-ledger boundary, each ledger-loss guard, workspace
  independence, complete preflight, per-file atomic replacement, hard-cut path population, and each
  bounded commit-diff classification; every corresponding fixture must fail.
- The Journal full suite, repository integration tests, ShellCheck, `git diff --check`, and the
  Skill-builder lint gate pass. A live-source search finds `setup.intent` only in immutable
  historical records and deliberate negative fixtures, never as a current skill, script, or
  project-facing contract.

The feature is complete when Journal has one public, state-derived setup model; setup and repair
converge after every injected interruption without private state; every current operation depends
only on `.records` plus the setup caller's read-only Git recovery evidence; and the repository
retains no live setup-state lifecycle, `finalize` command, automatic prior-version detection, or
compatibility path. The only noncanonical input is a source root explicitly supplied to
`/journal migrate <source-root>`.
