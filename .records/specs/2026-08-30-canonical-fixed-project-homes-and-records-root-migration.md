---
doctype: specs
status: draft
schema: architect/spec@1
tags: [storage, paths, migration, journal, backlog, workspace]
---

# Canonical fixed project homes and records-root migration — Spec

## Problem

Grimoire currently gives three project-owned storage layers independently configurable roots:
`<agent-records>` defaults to `.records`, `<agent-workspace>` defaults to `.spaces`, and
`<agent-trackers>` defaults to `.trackers`. A consuming project may override them with line-start
declarations in `AGENTS.md` or `CLAUDE.md`; records additionally accepts the legacy
`records-root:` spelling.

The semantic split is useful. Records are dated typed work products, the workspace contains
owner-first skill support, and trackers are public mutable queues. Making each location dynamic is
not. Every reader, writer, setup helper, validator, fixture, and explanatory document must repeat
the same declaration precedence, path validation, and overlap rules. The current live carriers
include record writers, workspace publishers, Backlog, Analyst, Foreman, Workstream, the Workspace
guard, the lint gate, and the package configuration sweep. A fourth public layer, `.callbacks`,
already demonstrates the simpler rule: a first-class layer can be distinct and discoverable
without a front-door variable.

The records override has a stronger historical argument than the other two—brownfield projects may
already keep agent documents under another path—but permanent indirection places the cost on every
future operation. It also permits Journal's recursive record crawl to share or appropriate an
arbitrary document tree. A one-time, explicit relocation into `.records` is safer: the destination
has a clear custody boundary, while the migration can inventory legacy content and refuse
ambiguity before it moves anything.

Backlog exposes the same mismatch inside the current split. Queues, receipts, provider, and README
live in `.trackers`, while the project-editable routing policy lives at
`.spaces/backlog/hooks/debrief.md`. That file is not an optional cross-skill seam overlay. Its
`## <stem>` population changes with tracker add/remove, setup reconciles it, and Backlog debrief
interprets it alongside the queues. Keeping it in another root makes one tracker layer depend on
two storage contracts.

The current arrangement is therefore paying permanent configuration and split-ownership costs for
variance that should either be rejected or handled once. The root distinctions should remain; the
root selectors should not.

## Goal

Make `.records/`, `.spaces/`, and `.trackers/` the only canonical locations for their respective
project layers. Remove persistent root declarations and root-selection arguments from ordinary
runtime and setup contracts, make adjacent providers self-locate, and place Backlog's editable
debrief policy at `.trackers/DEBRIEF.md`.

Provide `/journal migrate [<source-root>]` as the single guarded transition for a brownfield records
root. A successful migration preserves every record's records-root-relative identity and ledger
data, strands no recognized record at the source, installs the current `.records` tool layer, and
removes the retired declaration only after validation. No ordinary verb reads legacy state through
a retired path.

## Approach

Adopt the fixed-root decision recorded in
→ `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`:

```text
.records/    dated typed records, history.tsv, README.md, records.sh
.spaces/     owner-first skill support: <skill>/<kind>/...
.trackers/   queue TSVs, receipts.tsv, README.md, DEBRIEF.md, trackers.sh
```

The angle-bracket home tokens and the `agent-records:`, `records-root:`, `agent-workspace:`, and
`agent-trackers:` declarations retire from the live contract. Explanatory prose names the literal
canonical path. Explicit paths that select an operation's subject—a document to review, a migration
source, a worktree, or a caller-chosen record subdirectory—remain legal. The change eliminates
persistent project-home configuration, not path arguments in general.

This specification overrides only the conflicting path requirements in:

- → `specs/2026-08-25-agent-workspace-naming.md`;
- → `specs/2026-08-28-journal-records-provider-discoverability-and-durable-setup.md`;
- → `specs/2026-08-28-backlog-tracker-provider-discoverability.md`; and
- → `specs/2026-08-27-backlog-routines-and-universal-debrief.md`.

Their unrelated format, lifecycle, safety, and ownership decisions remain in force. Historical
published records and completed design documents remain unchanged; live skill surfaces, doctrine,
package documentation, scripts, lint, and fixtures adopt this specification.

The cut is deliberately asymmetric:

- `.records` receives an explicit migration because real brownfield content may exist and records
  have durable identities and a closure ledger.
- `.spaces` and `.trackers` retain their existing default locations and receive no general
  relocation engine. No demonstrated consuming host uses an override. A non-default declaration is
  invalid project configuration and requires a deliberate manual move before ordinary work.
- Backlog does receive one bounded prior-path move for `.spaces/backlog/hooks/debrief.md`, because
  that exact path is the incumbent default deployed by the current package, not a speculative
  custom override.

Alternatives rejected:

- **Keep only records dynamic.** This protects brownfield paths but retains resolver and CLI
  complexity in every record writer forever. Explicit migration pays the cost once and produces a
  uniform steady state.
- **Collapse all layers beneath `.spaces`.** Fewer top-level directories would blur public data and
  owner-local support, force consumers to know another skill's namespace, and weaken provider
  discoverability. Fixed locations do not require collapsed ownership.
- **Automatically discover or adopt legacy document trees.** A directory containing dated Markdown
  is not consent to let Journal manage it. Migration requires a declared or explicit source and a
  reviewed inventory.
- **Centralize dynamic-root resolution in one shared helper.** This would reduce duplicated parsers
  but preserve hidden project configuration, overlap behavior, and split-corpus failure modes. It
  would also give otherwise self-contained skills a shared runtime dependency. The hard cut removes
  the selectors instead of making their compatibility machinery easier to call.
- **Add generic migration for every fixed layer.** Workspace and tracker overrides have no observed
  population, while a universal mover would need to understand every owner's files. The exact
  Backlog prompt move and Journal's records-layer migration cover the known state without creating
  another permanent abstraction.

## Mechanism

### Fixed-home contract

All paths are beneath the canonical Git checkout or worktree root:

| Layer | Canonical path | Authority |
|---|---|---|
| Records | `.records/` | Journal defines the record contract and tool layer; writers own their record schemas and directories |
| Workspace | `.spaces/` | Each skill owns only `.spaces/<skill>/<kind>/...`; Workspace validates the shared grammar |
| Trackers | `.trackers/` | Backlog owns the provider, queue/receipt formats, README block, and debrief routing policy |

The existing owner-first workspace kinds remain `doctrine`, `drafts`, `hooks`, `operations`,
`scripts`, and `templates`. Records and workspace can no longer coincide, so Workspace drops its
coincident-root mode and validates `.spaces` only. Trackers remain outside the workspace grammar.
The already-fixed `.callbacks/` layer and fixed scratch locations are unaffected.

Every package script that needs project state accepts or derives the absolute project root, then
constructs literal `.records`, `.spaces`, or `.trackers` paths. Setup helpers no longer accept
`--workspace`, `--records-root`, `--workspace-root`, or `--trackers-root` as home selectors. The same
hard cut applies to read/write helpers, status helpers, validators, and owner-specific mint and
deployment helpers; they may still accept the absolute project `--root`. State-analysis helpers no
longer parse front-door declarations or emit configurable-home facts; they may continue to emit
literal facts such as `records_root=.records` when useful to a caller.

Installed public providers self-locate from their canonical regular, non-symlink path:

- `.records/records.sh <command> ...` derives the project root as the safe parent of its `.records`
  directory. Its public invocation drops `--root` and `--records-root`.
- `.trackers/trackers.sh <command> ...` retains its existing adjacent self-location, tightened to
  require the literal `.trackers` parent rather than an arbitrary resolved tracker root.

Bundled provider bytes are never executed against project data. Setup installs them at the fixed
location first; ordinary verbs use only the installed copy. Writer-specific file-mode fallbacks
construct `.records/<writer-store>/...` directly and remain valid when Journal has not been set up.

The current front-door declaration names are reserved retired syntax. Current doctrine and skill
prose never advertise them as configuration. A project carrying one is invalid under the fixed-home
contract. Ordinary providers, setup helpers, state readers, writers, validators, and file-mode
fallbacks never inspect or honor the declarations; they operate only on literal canonical paths.
The library lint/configuration gate rejects their presence. `/journal migrate` is the sole runtime
that reads retired records-declaration values, and only to relocate their source. There is no
distributed transition guard, fallback resolver, warning ladder, alias, or dual-read mode.

Configuration validation reports a retired records declaration with:

```text
reason=migration-required action=/journal migrate
```

The diagnostic does not make the declared store an ordinary runtime location. A workspace or
tracker declaration is likewise invalid and must be removed after its data is deliberately placed
at the fixed path; no runtime skill treats its value as a location. Use these diagnostics:

```text
reason=unsupported-home-declaration declaration=agent-workspace action=move-to-.spaces-and-remove
reason=unsupported-home-declaration declaration=agent-trackers action=move-to-.trackers-and-remove
```

These are configuration errors, not compatibility branches in ordinary operations.

### Backlog's complete tracker surface

Backlog's project surface becomes:

```text
.trackers/
  README.md
  DEBRIEF.md
  trackers.sh
  receipts.tsv
  <stem>.tsv
```

`DEBRIEF.md` is project-editable tracker routing policy. It contains the current title and one
structural `## <stem>` section for every configured queue. Backlog setup creates missing default
sections, tracker add creates the absent section for its queue, tracker remove removes only that
section, and debrief reads it before routing. Incumbent section bodies remain project-owned and are
never refreshed. The generic tracker provider and unrelated tracker consumers do not read
`DEBRIEF.md`.

Setup and tracker administration recognize exactly one prior prompt path:
`.spaces/backlog/hooks/debrief.md`. After complete preflight:

- prior present and destination absent: move the regular non-symlink file byte-for-byte;
- both present and byte-identical: retain the destination and remove the prior file;
- both present and different, or either path unsafe: refuse before either file changes;
- prior absent: reconcile the destination normally.

The bounded move joins the same setup or tracker-administration write set and scoped commit. It
does not remove empty `.spaces/backlog/hooks/` parents and never probes a path derived from a retired
workspace declaration. Once the canonical file exists, every Backlog verb reads only it.

### `/journal migrate`

Journal adds one substrate relocation verb:

```text
/journal migrate [<source-root>]
```

The destination is always `.records`. Before resolving an argument or declaration, Journal checks
for `.records/.journal-migrate-manifest`. A safe valid manifest owns the transaction: bare
invocation resumes its recorded source, while an explicit source must match it. Declaration absence
after the recorded declaration-removal phase is valid; a conflicting argument, changed declaration
before that phase, malformed manifest, or custody drift refuses human review. Journal never starts
a second migration while that manifest exists.

Without a manifest, the optional source is a safe repo-relative directory. With no argument,
Journal reads all line-start `agent-records:` and `records-root:` declarations from root
`AGENTS.md`, then `CLAUDE.md`. Exactly one distinct safe value becomes the proposed source; no
declaration refuses and requests an explicit source, and conflicting values refuse. An explicit
argument overrides absence, not conflict: any incumbent records declaration must name the same
source. `.records` itself, an absolute path, a dot path, traversal, a symlinked component, or a path
outside the checkout refuses.

Migration runs through Journal's package-local migration helper because neither the source nor the
destination is required to have a usable provider. The helper owns only relocation mechanics and
never becomes an alternate ordinary records runtime. It installs the current provider at the
destination before invoking that installed provider for the final records check.

Migration is a preview-then-apply operation. Preview is read-only and reports:

- every recognized record, preserving its source-root-relative path and checksum;
- dated Markdown candidates that fail the record discriminator;
- `history.tsv` presence, safety, checksum, and every records-root-relative identity it names;
- a safe regular source `records.sh` as package-owned tool surface scheduled for removal; an unsafe
  or incompatible entry blocks;
- the source README's Journal-managed block state and checksum; a well-formed block is scheduled
  for removal while all surrounding prose remains byte-identical, and malformed ownership markers
  block;
- every non-record source entry that will remain in place;
- `.records` destination state and every path collision; and
- repository references outside the source whose path text begins with the physical source-root
  prefix and would become stale after relocation, excluding the recognized declaration lines that
  the transaction removes itself.

Preview also refuses any active Journal transaction that could own either root: a
`journal/setup-intent@1` whose recorded records root is the source or destination, or any
`.journal-relocate-manifest` or `*.relocate-staged` entry beneath either root. The migration reports
the exact marker and directs the human to finish or resolve that transaction first; it never
adopts, translates, deletes, or guesses through another transaction's state.

The preview never infers a source from arbitrary dated files. External physical-prefix references
and destination collisions are blockers; Journal does not rewrite arbitrary project prose. The
human updates those references or resolves the collision, then reruns. Records' canonical `→
<dir>/<file>.md` links do not contain the physical root and remain unchanged. A canonical ordering
of all preview facts ends with `preview_digest=sha256:<digest>`.

Apply requires the human to accept that preview. The agent passes its digest to the package-local
helper; the helper recomputes the canonical preview immediately before the first write and requires
byte-identical facts and digest. A changed inventory never becomes an implicitly accepted preview.
The destination may be absent, empty, or may match the exact fresh tool layer produced by the
current Journal setup: current provider, setup-generated README, and empty ledger. Any destination
record, nonempty ledger, changed README prose, unknown entry, or colliding target refuses rather
than merging two corpora.

The first durable write creates `.records/.journal-migrate-manifest`. The manifest records a
versioned schema, source, destination, declaration files and checksums, the complete record and
ledger inventory, destination preconditions, one current phase, and every completed path. It is
never committed. Every later write rechecks source, destination, and manifest custody. An
interruption leaves the manifest and both source and staged destination bytes sufficient for the
same invocation to resume; a different source or changed inventory refuses human review rather
than restarting or rolling back.

Apply then:

1. Materializes each recognized record at the same relative path beneath `.records`, using staged
   bytes and checksum verification before the source identity is removed.
2. Preserves `history.tsv` byte-for-byte. When the destination has an allowed empty ledger, it is
   replaced only after the source ledger has been safely staged. When the source has no ledger,
   migration creates the current empty ledger as a tool-layer surface and reports the absence as a
   content finding; it never invents historical closure lines.
3. Installs the current provider and managed README block from Journal's package at `.records`; they
   are never copied from the source. After validating that canonical tool layer, removes a safe
   regular source-root `records.sh` and the source README's well-formed Journal-managed block. It
   preserves every surrounding README byte and leaves malformed candidates, workspace kinds, and
   all other non-record entries in place. It leaves no source alias, tombstone, or fallback.
4. Validates that every inventoried record now exists at the same relative identity with the same
   bytes, every migrated source identity is absent, the ledger bytes match, and no new physical
   source-prefix reference was introduced.
5. Runs the current `.records/records.sh check`. Findings already attributable to migrated legacy
   content are reported and routed to the owning writer's migration or Journal curation; they do
   not undo a structurally complete root relocation. A new relocation-induced path, link, or ledger
   failure blocks completion.
6. Removes every retired records declaration only when all declarations still match the accepted
   source and their files retain the previewed bytes. It preserves every surrounding front-door
   byte.
7. Makes one exact pathspec-scoped commit over migrated records, ledger, current tool surfaces,
   declaration edits, source-provider removal, source-README block removal, and tracked source
   removals. After Git and the final postconditions are clean, it removes the manifest. Inside an
   announced configuration sweep it returns the same exact path set without a nested commit.

If the source was a mixed or formerly coincident records/workspace root, only recognized records
and the ledger move. Unrelated content remains usable at the source. Migration never recursively
moves or deletes the source directory, never removes empty parents, and never upgrades record
schemas or templates. Writer-owned `/... migrate` verbs keep that responsibility.

### Coordinated contract cut

This feature changes one shared storage contract and must not leave a live tree in which some
writers still honor declarations while others use fixed roots. The implementation updates all
current package prose, setup/read/write helpers, state-analysis scripts, provider interfaces,
Workspace validation, pack/README guidance, lint rules, and fixtures as one coordinated cut.
Historical published records remain historical evidence and are excluded from the live-literal
sweep.

The 2026-08-30 `skills/` baseline census finds 98 live candidates (27 executable scripts and 71
prose or template files) plus 37 test or fixture files across `agent-council`, `analyst`,
`architect`, `auditor`, `backlog`, `code-humanizer`, `contractor`, `debugger`, `delegate`, `foreman`,
`inspector`, `journal`, `notepad`, `skill-builder`, `workspace`, and `workstream`. A candidate file
carries at least one retired declaration or symbolic home, a home-selection argument or positional
placeholder, a declaration resolver, or a records/workspace/trackers root variable. These are
baseline files whose matched carriers must be classified, not 135 strings that must all disappear:
migration and rejection surfaces intentionally retain some retired spellings.

The executable implementation census is:

| Package | Scripts carrying the current dynamic-home contract |
|---|---|
| Analyst | `analyst-deploy.sh`, `analyst-facts.sh` |
| Architect | `architect-artifacts.sh`, `architect-setup.sh` |
| Auditor | `auditor-seed.sh` |
| Backlog | `backlog-setup.sh`, `tracker-layer-status.sh`, `tracker-runtime-check.sh` |
| Contractor | `contractor-setup.sh` |
| Debugger | `bug-mint.sh`, `debugger-setup.sh` |
| Delegate | `delegate-setup.sh` |
| Foreman | `foreman-door.sh`, `goal-compile.sh`, `migration-census.sh`, `operation-check.sh`, `operation-write.sh`, `operations-index.sh` |
| Inspector | `kinds-deploy.sh` |
| Journal | `records.sh`, `standup.sh` |
| Notepad | `note-mint.sh`, `notepad-setup.sh` |
| Skill Builder | `skills-lint.sh` |
| Workspace | `workspace-check.sh` |
| Workstream | `workstream-git.sh`, `workstream-setup.sh` |

Every matched carrier receives exactly one implementation disposition; one file may contain
carriers with different dispositions:

1. **Replace** — a live resolver, selector, symbolic path, provider invocation, overlap rule, or
   descriptive contract becomes a literal canonical-home contract.
2. **Migration-only** — `/journal migrate` reads retired records declarations or describes the
   source it migrates; no ordinary operation shares that reader.
3. **Rejection-only** — configuration validation or lint names retired syntax solely to refuse it.
4. **Test-only** — a deliberate fixture proves replacement, migration, or rejection behavior and
   is not executable project doctrine.

No matched carrier may be unclassified or carry more than one disposition. The implementation
records the file-level census and per-carrier dispositions in its verification output so additions
and deletions after this baseline are reviewable rather than hidden by the aggregate count.

The portable authoring doctrine replaces its front-door-variable section with a fixed-home rule:
new project-owned shared layers require a canonical path, and brownfield variance is handled by an
explicit owner migration rather than a persistent selector. Skill-owned subpaths stay fixed beneath
their canonical owner home. A future dynamic project home would require a new reviewed decision
with demonstrated host variance and cannot be introduced by analogy.

## Verification

Verification uses throwaway consuming-project fixtures; grimoire's authored `AGENTS.md`, records,
workspace, and tracker data are never setup or migration targets.

**Live contract census.** Enumerate the population from current `README.md`, `PACK.md`, `scripts/`,
and `skills/`, excluding `.records/`, historical `docs/design/`, and fixture strings whose sole
purpose is proving rejection from the live population. The search population includes retired
declaration names and symbolic homes; `--workspace`, `--records-root`, `--workspace-root`, and
`--trackers-root`; positional records-root/workspace placeholders; declaration resolvers; and
records/workspace/trackers root variables. Dump every matched file, attribute it to the carrier
class that selected it, and assign every matched carrier exactly one **Replace**,
**Migration-only**, **Rejection-only**, or **Test-only** disposition; a file may carry more than one
disposition. Reconcile the `skills/` subset against the 98-live/37-test baseline and the 27-script
table above; any count drift requires a file-level explanation.

This command defines the baseline population exactly; its expected output is
`live=98 scripts=27 prose_or_templates=71 tests=37 all=135`:

```sh
census_file="$(mktemp)"
rg -l \
  -e '<agent-(records|workspace|trackers)>' \
  -e 'agent-(records|workspace|trackers):' \
  -e 'records-root:' \
  -e 'records-root-relative' \
  -e 'workspace-relative' \
  -e '--records-root' \
  -e '--workspace-root' \
  -e '--trackers-root' \
  -e '--workspace([[:space:]]|=|\))' \
  -e 'resolve_(records|workspace|trackers)' \
  -e '(records|workspace|trackers)_(root|rel|home)' \
  skills | sort >"$census_file"
awk 'BEGIN { live=tests=scripts=docs=0 }
  /\/scripts\/tests\/|\/tests\// { tests++; next }
  { live++; if ($0 ~ /\.sh$/) scripts++; else docs++ }
  END { printf "live=%d scripts=%d prose_or_templates=%d tests=%d all=%d\n",
               live, scripts, docs, tests, live + tests }' "$census_file"
rm -f "$census_file"
```

Running the same matcher over `README.md PACK.md scripts skills` defines the complete live-contract
population and starts at `live=100 scripts=27 prose_or_templates=73 tests=39 all=139`. The saved
sorted paths, carrier matches, and dispositions—not either aggregate—are the review evidence. After
the cut:

- no ordinary live procedure resolves `agent-records:`, `records-root:`, `agent-workspace:`, or
  `agent-trackers:` as a location; `/journal migrate` is the sole records-source exception;
- no ordinary provider, setup helper, reader, writer, status helper, validator, mint helper, or
  deployment helper accepts `--workspace`, `--records-root`, `--workspace-root`, or
  `--trackers-root` as a home selector;
- no live skill path uses `<agent-records>`, `<agent-workspace>`, or `<agent-trackers>` where the
  literal canonical path is meant; and
- retained declaration strings occur only in `/journal migrate`, configuration/lint rejection, and
  their deliberate tests.

Prove each absence check red by planting one carrier from its own classified population, count the
mutation target before and after, require failure, restore byte identity, and rerun green.

**Fixed-home behavior.** Fresh fixtures with no front-door declarations prove every setup, writer,
reader, status helper, and validator uses `.records`, `.spaces`, or `.trackers` as applicable.
Installed providers refuse symlinked, renamed, or noncanonical parents and operate from canonical
paths containing spaces and shell metacharacters. Workspace fixtures prove only split fixed mode;
the former coincidence and arbitrary-root cases disappear. Callback and other already-fixed layers
remain unchanged.

**Retired declarations.** Fixtures cover each retired spelling in `AGENTS.md` and `CLAUDE.md`,
duplicates, matching and conflicting records declarations, unsafe values, and declarations mixed
with ordinary prose. Configuration validation emits the specified diagnostic without touching
either source or destination. Ordinary providers and helpers neither inspect nor honor any retired
declaration and use only canonical paths; canaries at each declared noncanonical path prove no
access. `/journal migrate` alone reads records-declaration values. Workspace/tracker declarations
are rejected as invalid configuration and never select a path. The lint mutation proof demonstrates
that a new dynamic home cannot silently return.

**Journal migration.** The migration harness covers bare declaration-derived and explicit sources;
no declaration, conflicts, explicit/declaration disagreement, already-canonical and unsafe sources;
dedicated and mixed/coincident roots; current and legacy records; absent and byte-bearing ledgers;
malformed dated candidates; external physical-prefix references; allowed empty-tool destination;
every destination collision class; active setup intents and record-relocation manifests;
source/destination races; and symlinks at every parent and target. It proves:

- preview writes nothing, reports the complete classified inventory, and emits a deterministic
  digest whose accepted facts must match apply;
- relative record paths, bytes, ledger bytes, and root-relative `→` links are unchanged;
- unrelated source bytes remain unchanged;
- provider and README bytes come from the current package, not the source;
- the safe source provider and only the source README's managed block are removed after canonical
  provider validation, leaving no alias, tombstone, fallback, or surrounding-prose change;
- another active Journal transaction blocks without being translated, adopted, or modified;
- declarations disappear only after a complete validated move;
- an injected failure after the manifest and after every durable phase resumes without duplicate,
  loss, overwrite, or rollback guesswork;
- interruption after declaration removal and after commit resumes or finalizes from the manifest
  before declaration-derived source resolution;
- preexisting legacy-content findings remain attributable while migration-induced findings block;
  and
- standalone migration commits exactly its reported paths and leaves no manifest.

Break one source checksum, destination recheck, declaration checksum, relative identity, ledger
comparison, and phase transition in turn; each mutation must make the corresponding fixture fail.

**Backlog policy move.** Fixtures cover prior-only, destination-only, identical-both,
different-both, unsafe parents, interrupted move, custom queue sections, and tracker add/remove.
They prove byte-preserving migration to `.trackers/DEBRIEF.md`, incumbent section preservation,
one section per configured queue, no read of the old path after success, no empty-parent cleanup,
and one exact commit with queue changes. Backlog's generic provider and external consumers never
read `DEBRIEF.md`.

Finally run every affected skill harness, package integration test, shell syntax check, and the
repository skills lint gate. A fresh consuming-project setup followed by a second full setup must
produce the exact canonical tree on the first run and zero writes on the second.
