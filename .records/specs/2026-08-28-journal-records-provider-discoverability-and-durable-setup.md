---
doctype: specs
status: archived
schema: architect/spec@1
tags: [journal, records, discovery, setup]
---

# Journal records-provider discoverability and durable setup — Spec

## Problem

The records layer is public project state, but the published provider contract in
→ `specs/2026-08-25-skill-owned-artifact-migration.md` still places `records.sh` under Journal's
private workspace. An agent that discovers `<agent-records>` therefore cannot find the tool beside
the records it operates on or learn the records contract from that surface alone. The records-root
README also needs an explicit ownership seam before Journal can keep its instructions current
without overwriting project prose.

Moving the provider and expanding the README are incomplete without a recovery contract. Journal
verbs can name `/journal setup` when `records.sh` is absent, but setup does not distinguish a
first visit from narrow tool repair, and an interrupted standalone setup can leave earlier writes
outside the successful rerun's commit path list. The project needs one convergent setup mechanism
and a smaller recovery entrypoint that cannot mutate records or ledger contents.

## Goal

Make `<agent-records>` self-explaining: its sole runtime provider is adjacent `records.sh`, and its
README teaches the records discriminator, safe discovery, and basic lifecycle commands without
requiring an agent to load Journal first.

Make `/journal setup` durable and non-destructive. First setup and interrupted setup execute only
incomplete tool-layer steps, later setup preserves every record and incumbent ledger byte, and a
clean rerun performs no writes. Add `/journal repair` as the provider-and-README subset for an
already initialized records layer. Missing or stale provider diagnostics and the adjacent README
direct an agent to that narrower recovery path.

The record discriminator, metadata contract, schemas, commands, output, crawling behavior,
relocation semantics, and lifecycle do not change.

## Approach

This spec is an addendum to the published migration spec above and the Journal setup surface in
→ `specs/2026-08-25-clankshop-project-configuration.md`. It overrides the staged provider path,
the records README's absent-only treatment, and setup's interruption behavior. The governing specs
remain authoritative for records, templates, migration adapters, project-root resolution, and pack
configuration.

Stage `records.sh` beside the records it operates on and manage one delimited README block. Setup
and repair use one reconciliation mechanism: setup owns the fixed tool layer and its bounded
prior-path cleanup, while repair may restore only the provider and managed README block. A transient
workspace intent carries completed setup paths across interruptions; no configurable store
population is introduced.

Setup may remove the exact prior package-managed provider only after validating its replacement,
and may replace only the exact prior generated README pointer. Runtime callers and repair never
consult the prior path, and record content never migrates implicitly.

Alternatives rejected:

- **Keep the provider in the workspace.** Agents discovering the public records layer would still
  need a second root and Journal-specific knowledge before they could inspect it safely.
- **Leave an alias or fallback at the prior path.** Two installed entrypoints would make provider
  identity ambiguous and retain a permanent runtime compatibility branch.
- **Hard-cut setup without removing the prior package copy.** The old provider is an exact
  Journal-managed executable, not project data; leaving it behind would preserve a stale tool that
  appears authoritative. The bounded cleanup runs only in setup and only after replacement.
- **Make repair an independent installer.** Duplicate validation, rendering, and provider-copy
  logic would let setup and repair drift. Repair instead constrains the shared mechanism's write set.

## Mechanism

The steady public shape is:

```text
<agent-records>/
  README.md
  records.sh
  history.tsv
  ... writer-owned directories and records at any depth ...
```

`records.sh` remains package-owned and self-contained. Its location never selects the data root;
every invocation retains
`records.sh --root <absolute-project-root> --records-root <records-root-relative>`. Writer skills
use this installed path when executable and retain their existing file-mode behavior when it is
unavailable. They do not load Journal or run its bundled copy.

### Setup and repair

Setup and repair share one reconciliation implementation with different entry conditions and write
sets:

| Invocation | Tool-layer state | Allowed effect |
|---|---|---|
| `/journal setup` | No regular ledger and no active intent | Record intent, install the fixed tool layer, and perform bounded prior-path cleanup |
| `/journal setup` | Active setup intent | Resume the recorded transaction and execute only incomplete steps |
| `/journal setup` | Regular ledger present, reconciliation required | Record intent, preserve project state, and reconcile incomplete tool-layer steps |
| `/journal setup` | Fixed tool layer already current | Validate and report no writes without creating an intent |
| `/journal repair` | Regular ledger present, no intent | Reconcile only `records.sh` and the managed README block |

Journal resolves `<root>`, `<agent-records>`, and `<agent-workspace>`, then checks
`<agent-workspace>/journal/setup.intent` before accessing tool-layer destinations. The intent
records `schema=journal/setup-intent@1`, `phase=applying|ready`, the resolved records and workspace
roots, the exact prior provider path, exactly one `pending=` field, and every completed durable path
written or removed by the transaction. The pending value is empty between steps or names the one
path whose destination commit is in progress. Current declarations must agree with those values. A
symlinked, malformed, unsupported, or conflicting intent refuses before another write.

Every setup invocation that would write first preflights its complete write set, then atomically
writes the intent before the records-root provider, ledger, README, or prior provider changes. A
clean invocation validates the current layer without creating an intent. Before each destination
commit, setup atomically names that path as pending; after the postcondition holds, it atomically
promotes the path to completed and clears pending. Each transaction step validates an
already-complete result instead of rewriting it and records missing bookkeeping in the intent. Only
completed paths use the `wrote:` vocabulary. A resumed run reports the union of durable paths changed
across every attempt.

After the canonical provider, ledger, managed README block, bounded legacy cleanup, and final
self-check pass, setup advances the intent to `phase=ready` but retains it through commit custody.
Standalone setup derives one exact pathspec-scoped commit from the recorded union. It omits a path
only when that path is now absent and `git ls-files --error-unmatch -- <path>` proves it was never
tracked; the recorded union remains unchanged for reporting and recovery. After the remaining paths
commit, setup removes the intent. If no commit-eligible path remains, or interruption occurs after
the commit but before finalization, rerun may finalize without a new commit only after the ready
transaction's results revalidate and Git proves that none of its paths remains modified or
untracked. In an announced configuration sweep, the sweep's recorded pre-write Git state and
approved-destination diff own recovery; setup hands off the complete union before removing the
intent. The intent itself is neither reported nor committed. Journal's own search, done, and curate
verbs refuse with `reason=setup-required action=/journal setup` while either phase exists;
independent writer skills retain their ordinary staged-tool-or-file-mode contract.

Without an intent, a regular `history.tsv` marks an initialized tool layer even when the provider
or README is absent. Setup may install or refresh the canonical provider, restore its executable
bit, create a missing README, refresh only Journal's managed block, and complete the bounded prior
provider cleanup. If the ledger is absent, setup creates an empty regular file; if present, setup
never truncates, rewrites, or replaces it. Setup creates no writer directory, record, template, or
store roster.

Repair requires a safe existing records root, a regular `history.tsv`, no setup intent, and a valid
README ownership seam. It may install or refresh only `<agent-records>/records.sh`, restore its
executable bit, and append or refresh the managed README block. It never creates or changes the
ledger, removes the prior workspace provider, rewrites a prior generated pointer outside the
managed block, or creates any writer-owned surface. A missing ledger directs the caller to
`/journal setup`; unsafe or incompatible entries and malformed ownership markers refuse before any
write.

Both entrypoints install the provider before advertising it in the README. Before the managed block
may be written, the installed script must match the bundled provider bytes, be executable, and pass
one exact usage probe: invocation with the resolved `--root` and `--records-root` but no command
exits 1, begins with the usage line, and names every current command including `grep`. The final
content-aware `check` is separate and may still find malformed or legacy project records. That
outcome does not roll back a safely restored tool: setup or repair reports that the tool layer is
usable and directs the agent to `/journal curate` or the record owner's explicit migration path.

Completed paths retain Journal's `wrote: <repo-relative-path>` vocabulary, including a removed
prior package provider. A later refusal reports earlier safe writes, a resumed transaction reports
all paths changed across its attempts, and a clean invocation reports none. Standalone setup and
repair use one exact pathspec-scoped commit; an announced configuration sweep receives the paths
without a nested commit.

Setup alone performs the bounded provider upgrade. It recognizes only the exact resolved prior
`<agent-workspace>/journal/scripts/records.sh`, validates that entry and its parents during
preflight, installs and validates `<agent-records>/records.sh`, updates the managed README block,
then removes the prior regular file last when the paths differ. Coincident paths retain the newly
installed provider. An interruption resumes through the setup intent; setup deletes no empty parent
directory and recognizes no other filename. It replaces the prior generated three-line README
pointer only when all three lines match exactly. All other unowned prose remains project content,
even when it names the retired path. Repair performs none of this cleanup.

### Records-root README

Journal owns exactly one block:

```text
<!-- journal:records-tool BEGIN -->
...
<!-- journal:records-tool END -->
```

Exactly zero or one well-formed block is valid. Duplicate, nested, reversed, or unmatched markers
refuse before any setup or repair write. When absent, reconciliation appends the block with only the
separator required before it; when present, it replaces only the bytes from the begin marker
through the end marker. A byte-identical block is a no-op.

The block identifies the adjacent provider and explains:

- the dated-filename-plus-`doctype` record discriminator and the four required front-matter keys;
- the records-root-relative path identity, live crawl at any depth, and `history.tsv` closure role;
- the safely quoted invocation prefix for the resolved records root;
- read-only `list`, `grep`, `show`, `history`, and `check` discovery;
- lifecycle `new`, `touch`, `done`, and `relocate`, including writer-owned schemas and the rule that
  agents never hand-edit `history.tsv`; and
- if `./records.sh` is missing, non-executable, or lacks the current usage surface, agents do not
  hand-repair it or run Journal's bundled copy against project records; they run `/journal repair`.

The block points to bare `records.sh` usage for the complete command reference instead of
reproducing specialized curation operations. It does not teach schema ownership for every writer,
migration judgment, curation decisions, or commit custody.

Before Journal search, done, or curate invokes the provider, an active intent reports
`reason=setup-required action=/journal setup`. On an initialized layer, an absent, non-executable,
or stale provider reports `reason=repair-required action=/journal repair`. With no regular ledger,
Journal reports the setup-required diagnostic. The adjacent README carries the steady-state repair
instruction for agents that discover the layer without loading Journal.

## Verification

All proofs run against throwaway project fixtures, never grimoire's authored records layer.

- Fresh default, custom records-root, and coincident records/workspace setups produce executable
  adjacent `records.sh`, an empty ledger, and exactly one managed README block without creating a
  writer directory. Rendered README invocations remain runnable for roots containing spaces and
  shell metacharacters.
- Fresh and initialized failure injection after the intent, every durable setup change, the ready
  transition, the scoped commit, and immediately before finalization proves the intent retains the
  resolved roots and completed path set. Rerun executes only incomplete steps, reports the complete
  transaction, and either commits the outstanding path set or proves an already committed ready
  transaction clean before removing the intent. Journal verbs refuse with the setup-required
  diagnostic until finalization; a clean later setup creates no intent and reports no writes.
- Initialized setup fixtures preserve record bytes, every incumbent ledger byte, surrounding README
  prose, and coincident-root content while refreshing drifted provider bytes and the managed block,
  restoring executable mode, and creating only absent setup surfaces. A missing provider is
  restored; a malformed record makes final `check` name curation without undoing the tool repair.
- Repair fixtures restore only the provider and managed block with the same rendered bytes and
  validation setup uses. Clean repair is a no-op. Missing-ledger, active-intent, malformed-marker,
  and unsafe-destination cases refuse before mutation. Missing, non-executable, and stale providers
  produce the repair-required diagnostic; an active intent and absent ledger produce the
  setup-required diagnostic. Mutation red proofs disable each new refusal guard and require the
  corresponding fixture to fail.
- A provider-move fixture plants recognizable bytes at the exact prior workspace path and its
  generated README pointer. Setup must install and validate the canonical provider before removing
  that file, replace only the exact pointer, preserve surrounding prose, and report both paths.
  Failure injection around every phase resumes forward; coincident paths retain the provider. A
  tracked prior provider commits its deletion, while an untracked prior provider is still removed
  and reported but is omitted from the commit pathspec after the exact Git proof. Runtime and repair
  fixtures never consult the prior path, and record contents never migrate.
- README marker mutation red proofs cover duplicate, nested, reversed, and unmatched forms. Failure
  injection around provider validation proves the managed block is never newly written while the
  adjacent tool is unusable. Validation fixtures independently corrupt the installed bytes, clear
  executable mode, change the bare invocation's exit status, and omit `grep` from usage; each keeps
  the managed block absent or unchanged. README contract fixtures execute representative rendered
  forms of `list`, `grep`, `show`, `history`, `check`, `new`, `touch`, `done`, and `relocate` and
  verify their read or lifecycle effects.
- Journal's complete harness, consuming-project configuration, record-writer contract fixtures,
  portable doctrine checks, skill lint, and repository integration tests pass. A live-source search
  finds the prior workspace provider path only in setup's bounded cleanup, its negative fixtures,
  and unchanged historical records—never in runtime invocation or current project guidance.

The addendum is complete when these proofs establish one adjacent provider, one safely refreshable
README ownership seam, interruption-safe non-destructive setup, narrow steady-state repair, bounded
prior-provider cleanup, unchanged record behavior, and no runtime compatibility path.
