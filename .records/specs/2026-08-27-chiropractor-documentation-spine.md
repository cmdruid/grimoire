---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, chiropractor, documentation, discoverability]
---

# Chiropractor documentation spine — Spec

## Problem

An agent enters a repository through its root `AGENTS.md`, but the project knowledge needed to do
real work is usually distributed across READMEs, design documents, contributor guides, runbooks,
package manifests, CI configuration, and helper scripts. A repository can contain accurate
instructions and working automation while still being operationally opaque: the agent cannot find
the authoritative path from “I need to do X” to the document, procedure, workflow, command, or
script that performs X.

Ordinary link checkers catch missing targets but not this failure. A document may be technically
reachable yet hidden behind an ambiguous menu, a workflow may be described without linking its
runnable entry point, and two front doors may carry divergent copies of the same instructions.
Conversely, requiring every Markdown file to be linked produces noise from historical records,
generated material, and internal helper documentation that is intentionally reached by convention
or through its caller.

The former `chiropractor` package addressed parts of this problem with a documentation graph,
entry-door audit, read-depth facts, stale-reference checks, and the “door diet” technique. Its
broader twelve-dimension rubric also judged general editorial qualities such as terminology,
heading consistency, and front-matter coverage. That scope blurred documentation topology with
prose review and made the core discoverability verdict less precise. The package was later folded
into a Clankshop role and disappeared when that role layer was removed; the underlying in-place
steward job remains unowned.

The intended host is often dirty. A useful steward must inspect and adjust the working tree as it
exists without overwriting unrelated edits, mass-reflowing prose, staging files, or treating `HEAD`
as more authoritative than the user's current bytes. Even an explicit adjustment request must not
silently choose between competing sources of truth or apply an unseen patch.

## Goal

Restore `chiropractor` as a portable, optional Clankshop skill that audits and repairs the
agent-facing documentation spine rooted at `AGENTS.md`. Every important task, document, procedure,
and workflow must have a clear, semantically labeled route from that front door to its authoritative
instructions or executable entry point; internal and historical material need not be individually
linked.

The default audit is read-only. Adjustment is confirmation-gated: the skill presents the exact
scope and proposed changes, waits for explicit approval, applies only the approved documentation
edits while preserving pre-existing dirty work, and then re-scans the same routes. A repository
without root `AGENTS.md` has no established spine; Chiropractor first proposes the front door,
including migration from `CLAUDE.md` when present, and does not perform the full spine adjustment
until that proposal is approved and applied.

## Approach

Use a hybrid route-graph audit:

1. A package-local, read-only scanner computes deterministic topology and inventory facts.
2. The agent dispositions the complete discovered candidate population, citing repository evidence
   for each individual candidate or explicitly homogeneous class.
3. The agent traces every candidate dispositioned `important` from `AGENTS.md` through explicit
   navigational edges to an authoritative leaf or runnable entry point.
4. A focused seven-check rubric judges the door and routes. `audit` returns the inventory, route
   matrix, scorecard, and evidence-ranked findings, then stops without constructing a patch.
5. `adjust` continues from the audit, constructs an exact bounded patch in temporary files, and
   waits for approval. No repository write occurs until the user approves that displayed patch.

The graph is deliberately heterogeneous. Documentation nodes include tracked Markdown and other
conventional authored documentation. Target nodes may also be scripts, commands, manifests,
workflow definitions, or scoped front doors. An edge is useful only when its surrounding label or
instruction tells an agent when to follow it; raw file reachability is evidence, not the semantic
verdict.

`chiropractor` is an **in-place steward** under the skill-authoring doctrine. It owns no project
home, setup verb, templates, route registration, record store, or persistent report. Its typed edges
are all stated `—`: a conversational audit and in-place documentation fixes are not a durable baton.
The skill remains independently routable and names no sibling in its package. Clankshop's
`PACK.md` owns the composition seam: Chiropractor maintains discoverability topology; other skills
may own prose quality, artifact review, code quality, or the procedures being linked.

Alternatives rejected:

- **Restore the former graph-only audit unchanged.** Link reachability cannot prove that an agent
  can recognize the correct route for a task, and the former rubric mixed topology with general
  documentation style.
- **Use scenario probes without a mechanical graph.** Scenario judgment finds semantic failures
  but repeatedly spends context rediscovering paths and misses routine broken references that a
  deterministic scanner can report cheaply.
- **Generate a permanent documentation catalog.** A generated map is another snapshot that can
  drift and become a competing source of truth. The live documents remain authoritative; audit
  reports stay conversational unless the user explicitly requests a file.
- **Link every tracked document and executable.** Historical stores, generated docs, and internal
  helpers are not independent agent entry points. Importance is evidence-based, and store-level or
  caller-level reachability is sufficient where that is the project's real access convention.
- **Apply immediately when invoked as `adjust`.** The dangerous part is not writing bytes but
  choosing authority and structure. An explicit adjustment request authorizes preparing a patch,
  not applying it without review.

## Mechanism

### Definitions and invariants

- **Audit root:** the supplied repository root, otherwise the enclosing Git top level. The scanner
  examines the working tree. When Git is available, it inventories tracked files plus untracked,
  nonignored files and labels their origin; ignored files remain out of scope. It does not read file
  content from `HEAD` in place of working-tree content.
- **Front door:** root `AGENTS.md`. It is the portable source of shared agent instructions and the
  root of the established spine.
- **Scoped door:** a nested `AGENTS.md` in the same repository. It governs a subtree and is a valid
  route target for tasks in that scope; it does not replace the root door.
- **Compatibility door:** root `CLAUDE.md`. Shared content belongs in `AGENTS.md`; `CLAUDE.md`
  imports it with `@AGENTS.md` and may retain only genuinely Claude-specific instructions.
- **Navigational edge:** an explicit Markdown link or import, a repository-relative document/path
  reference, or a runnable command that names its target. An edge in fenced example or quoted
  historical material is not automatically live navigation.
- **Important task:** a project action whose importance is evidenced by the front door, a primary
  README or contributor guide, build/package entry points, CI/release configuration, repeated live
  references, or an explicit maintainer statement.
- **Important artifact:** an authoritative document, procedure, workflow, or executable entry point
  needed to understand or complete an important task. A helper reached only through its documented
  caller is not independently important unless agents are expected to invoke or modify it directly.
- **Task route:** a semantically labeled sequence from the root door to an important artifact. A
  menu-only intermediate with no routing judgment or operational payload is a defect, even if it
  makes the graph technically connected.
- **Established spine:** a readable, regular, non-symlink root `AGENTS.md` exists. Its content may
  be empty, incoherent, or incomplete; those are audit findings, not reasons to skip the audit.
  Without that file, Chiropractor may census the repository to propose a door but does not issue a
  full reachability score or proceed to ordinary adjustments. A symlink, directory, or unreadable
  root door is incompatible: report it and stop for a maintainer decision rather than following or
  replacing it.

Every finding cites its evidence and distinguishes a measured fact from agent judgment. Raw counts
are never findings until archives, generated material, subrepositories, and internal helpers have
been partitioned out.

### Package surface

Create this self-contained package:

```text
skills/chiropractor/
  SKILL.md
  docs/RUBRIC.md
  verbs/audit.md
  verbs/adjust.md
  scripts/spine-scan.sh
  scripts/tests/run.sh
  scripts/tests/fixtures/...
```

`SKILL.md` is a thin router. Bare invocation and `audit [scope]` select the read-only audit, which
ends with findings and an offer to prepare an adjustment. `adjust [scope]` selects the same audit
followed by an exact patch preview and confirmation gate. A request in natural language to fix or
restructure the documentation spine routes to `adjust`, but the confirmation gate still applies.

The frontmatter description must route without relying on the opaque joke name. Its content is:

> Audit and repair a repository's agent-facing documentation spine: start at `AGENTS.md`, trace
> task routes through READMEs, docs, runbooks, workflows, and helper scripts, find unreachable or
> misleading operational knowledge, broken or stale references, duplicate authorities, and
> overloaded front doors, and propose minimal edits that preserve dirty work. Use for documentation
> discoverability, agent onboarding, knowledge-graph navigation, or “where would an agent learn how
> to do X?”

The final wording may be tightened for the frontmatter length target without dropping the named
trigger cases. The package declares the in-place-steward disposition, no home or setup, and this
edge block:

```markdown
<!-- edges:chiropractor -->
- produces: — (conversational audit plus in-place documentation fixes, not a typed artifact)
- handoff: — (the verified adjustment ends the pass)
- consumes: — (the repository working tree is direct input, not a typed artifact)
<!-- /edges:chiropractor -->
```

### Scanner contract

`scripts/spine-scan.sh <root> [--candidates]` is Bash 3.2 compatible, read-only, and is the one
stable entrypoint. With no option it emits compact `key=value` facts plus capped samples with
uncapped `<fact>_count` totals. `--candidates` emits the complete, uncapped candidate population as
sorted TSV rows plus `candidate_count`; the audit uses this mode to construct its ledger. Both modes
share one inventory implementation, so their counts cannot drift. The scanner reuses the proven
ideas from the former implementation but is rewritten around a heterogeneous spine rather than an
all-Markdown orphan graph. It depends on no other skill or deployed project tool. It never executes
a discovered command or repository script. It does not descend through symlinked directories, and
it lexically normalizes reference targets so paths that escape the audit root are reported rather
than opened as ordinary project nodes.

The scanner must emit at least these fact classes:

- Root-door state: presence of `AGENTS.md` and `CLAUDE.md`, whether `CLAUDE.md` imports
  `AGENTS.md`, root door outline, imported bytes, and exact content digests. The agent, not the
  scanner, judges substantive duplication.
- Scope state: nested `AGENTS.md` paths and nested Git roots. Nested Git roots are excluded from
  the outer graph and reported separately.
- Documentation inventory: tracked and untracked-nonignored Markdown/MDX, reStructuredText,
  AsciiDoc, and conventional extensionless documentation names; historical/store and generated
  pattern evidence remains visible for later agent triage.
- Operational candidates: conventional `scripts/` and `bin/` files; tracked or
  untracked-nonignored files with an executable bit; Make/Just/Task entry files; package manifests;
  CI/release workflow files; and project-owned runbook or operation directories named by repository
  evidence. These paths are inventory facts; the scanner does not infer that every target or
  manifest command is public.
- Candidate population: one `candidate` identity per normalized repository-relative path, with all
  applicable kind labels, tracked/untracked origin, and pattern evidence attached, plus one uncapped
  `candidate_count`. Nested-root contents are not members of the outer population. This deduplicated
  population is the physical-source ledger's denominator. In `--candidates` mode each row is
  `candidate<TAB><path><TAB><comma-separated-kinds><TAB><origin><TAB><evidence>`.
- Edges: source, normalized target, and kind for the finite v1 grammar below. Fenced examples do not
  become live edges. Absolute runtime paths and URLs are not mistaken for repository paths.
- Integrity: broken file links and unresolved live path references within the finite grammar, plus
  broken Markdown section anchors where the declared anchor algorithm applies.
- Topology: nodes reachable from `AGENTS.md`, route depth, dead ends, documentation or operational
  candidate nodes with no incoming live edge, and unreachable top-level documentation/operations
  areas. These are
  candidate facts, not automatic findings.
- Worktree state: documentation paths already modified or untracked at scan time. The scanner does
  not call a dirty path defective and never mutates it.

Repeated facts use a documented, machine-readable line shape such as
`edge=<kind><TAB><source><TAB><target>` and are sorted for deterministic tests. Samples must carry a
truncation marker and a true total so large repositories do not flood context. Archive/store and
generated pattern labels must carry their convention or path evidence; they must not silently
discard those nodes from output. The audit must consume `--candidates`; it may not reconstruct a
complete ledger from the default capped sample. In `--candidates` mode the number of TSV candidate
rows must equal its reported `candidate_count`; the default mode must report that same count.

The finite v1 edge grammar is:

1. Markdown/MDX inline local destinations `](target)` where `target` contains no unescaped
   whitespace or parentheses; the same destination followed by one quoted title; and angle-bracket
   destinations `](<target with spaces or parentheses>)`, also with an optional quoted title. Strip
   the title and fragment before path normalization. Reference-style links and embedded HTML are
   inventory for direct inspection, not mechanically parsed edges.
2. `@` imports whose target matches `[A-Za-z0-9._/-]+` and is repository-relative.
3. Fenced-code-aware inline code spans containing one repository-relative path token matching
   `[A-Za-z0-9._/-]+`, with an optional `:line` or `#fragment`. A literal target with a leading `/`,
   URL scheme, glob, template marker, or whitespace is not a path edge.
4. Markdown fragments validated against explicit HTML ids and a bundled, tested GitHub-style ATX
   heading slugger, including duplicate-heading suffixes. Any other anchor convention emits
   `anchor_unverified`, not `broken_anchor`.

reStructuredText, AsciiDoc, extensionless docs, manifests, Make/Just/Task files, CI configuration,
and workflow files remain first-class candidates, but the v1 scanner does not parse their internal
link or command grammars. The agent reads each candidate or dispositioned class directly and adds
semantic route edges to the report when repository evidence supports them. This keeps the scanner's
mechanical claims finite while retaining heterogeneous task discovery.

The scanner computes facts only. It must not label a repository healthy, decide that a candidate
is important, recommend an index, or emit an adjustment verdict.

### Front-door gate and migration

The audit classifies the root before the full route pass. The first two rows assume `AGENTS.md` is
a readable regular non-symlink file; its quality is judged by the audit rather than this gate:

| State | Behavior |
|---|---|
| `AGENTS.md` only | Treat it as the canonical front door. Do not create `CLAUDE.md`. |
| Both; `CLAUDE.md` imports `AGENTS.md` | Treat `AGENTS.md` as canonical; check that remaining `CLAUDE.md` prose is genuinely harness-specific and nonduplicative. |
| `CLAUDE.md` only | Report “no established spine.” Propose moving portable content into a new `AGENTS.md` and replacing `CLAUDE.md` with `@AGENTS.md` plus any necessary Claude-specific remainder. |
| Both, duplicated or divergent | Propose a reconciled `AGENTS.md`; reduce `CLAUDE.md` to the import plus necessary Claude-specific remainder. Never choose between conflicting instructions without surfacing the decision. |
| Neither | Report “no established spine.” Use repository evidence to propose a minimal `AGENTS.md`; do not invent project policy that no source supports. |
| `AGENTS.md` is a symlink, directory, or unreadable | Report an incompatible door and stop. Do not follow, replace, or reinterpret it without a maintainer decision. |

Creating or reconciling the door is itself a confirmation-gated patch. After it is approved and
applied, re-scan from the new root door before producing any further spine adjustment. This may
produce two deliberate confirmation points: establishment of the canonical door, then repair of
the routes it exposes.

The minimal front door contains only grounded, load-bearing material: what the repository is, how
to reach essential build/test or contribution entry points, a task-oriented route map, and critical
constraints or tripwires. Unsupported commands, ownership claims, lifecycle rules, or directory
conventions are omitted and called out as missing project knowledge.

### Importance classification and route tracing

After the front-door gate passes, the agent reads the primary door, its immediate destinations, and
the scanner's complete `--candidates` stream. It creates two reconciled views: a physical-source
ledger covering every scanner candidate and a semantic-surface ledger covering the tasks,
procedures, workflows, and load-bearing knowledge discovered while inspecting those sources.

Every physical candidate appears individually or in an explicitly homogeneous class whose row
states its count, representative sample, shared inspection treatment, and disposition rule:

```text
candidate or class | count | sample | evidence | inspection | surfaces | disposition | rationale
```

The allowed dispositions are `important`, `internal`, `historical/generated`, and `unresolved`.
Every `important` candidate receives an individual row so its route can be tested independently;
only non-important candidates may be grouped. The sum of individual and grouped scanner-candidate
row counts must equal `candidate_count`. An `unresolved` row is an explicit maintainer question and
prevents Routing and Reach from scoring `solid`; it is never silently excluded to keep the report
bounded. A task or artifact the scanner did not nominate is marked `added`, counted separately from
the reconciled scanner population, and otherwise receives the same disposition and route treatment.

`inspection` is `direct`, `grouped`, or `unresolved`. Every live, nonhistorical source is read
directly unless a grouped row supplies evidence that the class has one homogeneous role and names
the representative bodies inspected. A direct inspection records the semantic-surface ids it found
or the explicit value `none`; it may not leave the cell blank. A grouped inspection records the
shared surface rule and its sample. `unresolved` inspection blocks a complete verdict.

Each discovered task, procedure, workflow, or load-bearing knowledge surface receives a stable
report-local id `<source>#<short-label>` and a row in the semantic-surface ledger:

```text
surface id | kind | source evidence | disposition | authoritative destination | rationale
```

The semantic ledger uses the same four dispositions. Every important semantic surface is
individual and receives a route; non-important surfaces may group only when their source coverage
and disposition rule are homogeneous. Agent- or maintainer-added surfaces use the same shape and
are counted separately. Physical reconciliation proves that every candidate source was considered;
semantic reconciliation proves that multiple supported actions inside one source did not collapse
into one path-level verdict.

Classification follows this descending evidence order:

1. The maintainer explicitly names the task or artifact.
2. `AGENTS.md` declares it or a scoped door governs it.
3. A primary README/contributor guide presents it as a supported project action.
4. Build, package, CI, release, or deployment configuration exposes it as a project entry point.
5. Multiple live documents or workflows invoke it directly.

One strong source may justify `important`, but the row must explain why an agent is expected to
invoke, modify, or understand the candidate directly. A conventional filename or CI invocation
alone creates a candidate, not an important classification. Historical records, generated output,
vendored documentation, and internal helpers receive explicit non-important dispositions unless
current repository evidence promotes them. A record/archive store is discoverable when its
convention and index/query entry point are reachable; its individual members may be grouped under
one evidenced `historical/generated` row rather than linked separately.

For every important task, trace the actual sequence starting at `AGENTS.md` and record:

```text
task | route | navigation actions | result | evidence
```

Project-wide tasks should dispatch directly from `AGENTS.md` to their authoritative entry point.
Subsystem tasks may pass through one scoped door or substantive router before their leaf. More than
two navigation actions, an ambiguous branch, a menu-only hop, or a leaf that omits the runnable
entry point is presumed drift unless repository structure provides a concrete justification. The
goal is not a universal numeric graph score; it is an explainable successful route for every
classified important task and artifact.

### Focused rubric

The bundled rubric defines seven checks, each scored `solid`, `drift`, or `gap` with cited evidence:

1. **Door:** `AGENTS.md` is canonical, concise, and coherent with compatibility/scoped doors.
2. **Routing:** the door dispatches by recognizable task intent to substantive entry points.
3. **Reach:** every classified important task and artifact has an unambiguous route.
4. **Currency:** live links, anchors, paths, and command targets resolve in the working tree.
5. **Authority:** one canonical source owns each instruction; other documents point rather than
   maintain divergent copies.
6. **Altitude:** the door keeps routing cues and non-negotiable tripwires while mechanisms and
   rationale live in task-specific leaves.
7. **Scope:** nested doors and nested repositories preserve local authority and standalone
   boundaries without stranding the root reader.

The rubric does not require a glossary, index, frontmatter, uniform heading style, or a particular
docs taxonomy. Those mechanisms may be proposed only when a concrete route or authority failure
would be solved by them. Form is subordinate to discoverability.

The Altitude check retains the former **door diet** adjustment: when an always-loaded section
restates a leaf, preserve the fact that tells an agent when to open the leaf and every surprising
constraint or “never” rule the agent must not violate; replace copied mechanism, paths, and
rationale with the authoritative link. A surviving door line routes or constrains—it does not
summarize the leaf wholesale.

### Audit report

The read-only audit returns, in order:

1. Scope, Git/worktree state, front-door state, and excluded nested roots or stores.
2. The reconciled physical-source and semantic-surface ledgers, including population totals and any
   unresolved source, inspection, or disposition rows.
3. The task-route matrix.
4. The seven-check scorecard.
5. Severity-ranked findings with location, measured fact, judgment, and proposed adjustment.

`gap` means an important route is absent, broken, contradictory, or cannot establish authority.
`drift` means the route still works but is ambiguous, unnecessarily deep, duplicated, or poorly
signposted. Counts without triage never determine severity. `audit` stops after the findings and
offers `adjust`; it does not construct a patch or ask the user to approve repository writes.

### Adjustment proposal

After producing the audit, `adjust` adds a bounded patch proposal naming every target path,
explaining each hunk's intent, and showing the exact unified diff (or complete contents for a new
small file).

The proposed result is constructed against temporary copies, never by modifying the repository and
then asking whether the modification was acceptable. For mechanical changes, the proposal calls
out the literal before/after target or link. For structural door edits, it explains the changed
section and still shows the resulting diff. It separates authority decisions from mechanically safe
corrections and caps ordinary proposals at the smallest set that restores all affected important
routes. It ends by asking for explicit approval of the whole displayed patch or named subsets. The
report is conversational by default and writes no record or map.

### Confirmation-gated adjustment

`adjust` runs the audit first even when the user directly asks for a fix. Before any repository
write it must:

1. Record `git status --short` and the current diff for every proposed tracked target; note untracked
   targets separately.
2. Read and retain an exact temporary preimage and content digest of each target that already
   exists. Refuse a symlink or a path whose existing parent chain escapes or traverses a symlink.
3. Construct the proposed result in a freshly created temporary directory and present the
   path-complete unified patch described above.
4. Stop and wait for explicit confirmation. Silence, a prior general desire to improve docs, or the
   word `adjust` itself is not approval of an unseen patch.

Approval applies only to the displayed patch. Naming a subset of already displayed hunks is explicit
approval of that subset when the freshly rendered subset is byte-identical to those hunks; it does
not require a second confirmation. Immediately before writing, compare each target with its saved
digest. If a target changed, a hunk must be rebased, or the rendered subset differs, the proposal is
stale: re-read it, recompute the affected hunks, and obtain confirmation again. A new path, move,
deletion, source-of-truth choice, or broader rewrite also requires a revised proposal.

After approval:

- Edit documentation and front-door files only. Chiropractor may repair a reference to a script,
  but it does not modify the script, workflow, manifest, or code it discovers. A defective target is
  reported as outside the documentation adjustment.
- Apply minimal hunks against the current bytes. Do not mass-reflow, normalize unrelated headings,
  or replace a dirty file wholesale when a surgical edit suffices.
- Never delete content without a separately displayed deletion proposal. Front-door migration
  preserves Claude-specific content and replaces only portable duplication with `@AGENTS.md`.
- Do not stage, commit, stash, reset, or restore unrelated work.
- Compare each touched file with its saved preimage so the report distinguishes Chiropractor's
  incremental edit from the user's pre-existing Git diff.

Re-run the scanner over the same root, repeat every affected task trace, and report the incremental
diff plus before/after facts. Verification succeeds only when the approved routes work and every
touched reference resolves. An unresolved result is reported with a follow-up proposal; it does not
authorize an additional write.

### Repository integration

Add `chiropractor` to the library README inventory and to Clankshop's optional/default-installed
members. Place its human-readable seam in `PACK.md`, not in leaf descriptions: it stewards the
discoverability route from the front door to project-owned knowledge and operations without taking
ownership of their content or implementation.

Update the repository integration runner to execute the package test suite. Historical design and
boundary-audit records remain historical; new routing-probe evidence may be appended only where the
current repository convention calls for a new probe result.

The package is tested against throwaway fixtures. It must never exercise front-door migration or
adjustment against grimoire's real `AGENTS.md`; that file is authored library doctrine and is covered
by the patient-zero caveat.

## Verification

### Scanner fixtures

The package test runner must cover at least:

- Root `AGENTS.md` only; root `CLAUDE.md` only; neither; healthy import pair; duplicated and
  divergent pairs; an import pair retaining harness-specific remainder; and incompatible root-door
  symlink/directory cases.
- The exact finite grammar: ordinary and angle-bracket Markdown destinations, `@` imports, safe
  inline repo-path tokens, GitHub-style and explicit-id anchors, duplicate headings, fenced examples,
  absolute runtime paths, URLs, globs/templates, and document-relative paths.
- Important operational candidates from `scripts/`, executables, Make/Just/Task files, package
  manifests, CI/release workflows, and project runbook directories.
- reStructuredText, AsciiDoc, reference-style Markdown links, embedded HTML, manifests, and workflow
  bodies are inventoried for agent inspection without manufacturing parsed edges.
- Nested scoped doors, nested Git roots, inward superproject references, and outward references that
  break standalone use.
- Historical/archive stores, generated docs, vendored material, untracked docs, and internal helpers
  invoked only through a documented caller.
- Deterministic ordering, a fixture whose population exceeds the default sample cap, capped default
  samples with accurate totals, complete `--candidates` TSV output, agreement between both modes'
  `candidate_count`, paths containing spaces, and a dirty working tree without mutation.

Each new mechanical assertion is red-proved by mutating a fixture, confirming the assertion fails,
restoring the fixture byte-for-byte, and confirming green. The tests verify the scanner is read-only
by comparing fixture state before and after execution.

### Procedure walkthroughs

Fixture-backed walkthroughs must demonstrate:

1. No `AGENTS.md` plus no `CLAUDE.md` stops at a grounded minimal-door proposal.
2. `CLAUDE.md`-only migration moves portable content, preserves Claude-specific content, and leaves
   the import skeleton only after confirmation.
3. Divergent dual doors surface the conflict rather than silently selecting a winner.
4. A graph-reachable but ambiguously labeled workflow fails Routing or Reach.
5. A documented public script is classified and traced, while its private helper is not required as
   an independent route.
6. An archive store is reachable by convention without linking every record.
7. `audit` stops after findings without constructing a patch or asking for write approval.
8. Direct `adjust` invocation previews an exact patch but performs no tree write before approval.
9. A dirty target receives a surgical edit and the final report separates pre-existing and new
   changes.
10. A target changed after proposal invalidates approval and requires a refreshed proposal.
11. A named byte-identical patch subset applies under its original approval; a rebased subset
    requires a new confirmation.
12. A broken script discovered through a valid documentation route is reported but not edited.
13. Every scanner candidate is dispositioned individually or by an attributed homogeneous class;
    one planted undispositioned candidate prevents a complete verdict.
14. A live source with two supported tasks produces two semantic-surface rows; omitting either task
    or leaving a source's `surfaces` cell blank prevents a complete verdict.
15. A grouped source class names its population, representative bodies, and shared surface rule;
    removing that evidence prevents grouping.

### Package and repository gates

Run:

```text
bash skills/chiropractor/scripts/tests/run.sh
skills/skill-builder/scripts/skills-lint.sh .
scripts/tests/run.sh
```

The skill lint must report `fails=0`; the repository integration suite must pass; the README and
pack inventories must include `chiropractor`; and a fresh routing probe using descriptions alone
must select Chiropractor for documentation-discoverability and broken-spine prompts without stealing
named-document prose review, code-quality audit, or operation-authoring prompts.

Finally, dogfood both verbs against a dirty throwaway repository with at least five important tasks
and both front-door files. Attribute the complete acceptance population through the
physical-source ledger: its individual and grouped counts must reconcile to the uncapped candidate
stream and `candidate_count`. Every live source must carry direct or evidenced grouped inspection
coverage and name its semantic surfaces or `none`. The semantic-surface ledger must include every
surfaced task, procedure, workflow, and load-bearing knowledge item, and every `important` row must
carry evidence and an explained route. `audit` must leave the repository byte-identical and stop
without a patch. `adjust` must produce a path-complete patch while leaving the repository
byte-identical until confirmation. Intentionally excluded candidates must remain visible through
their grouped count, sample, evidence, inspection treatment, and disposition rule.
