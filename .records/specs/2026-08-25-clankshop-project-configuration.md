---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, clankshop, setup, configuration]
---

# Clankshop project configuration — Spec

Related: `→ specs/2026-08-25-agent-workspace-naming.md`,
`→ specs/2026-08-25-skill-owned-artifact-migration.md`

## Problem

Clankshop is installable in an existing project, but it is not yet straightforward to configure as
a coherent toolkit. `PACK.md` accurately lists the members and their composition seams, yet its body
does not give an agent an ordered configuration procedure. An agent can discover that Journal owns
the records layer, Backlog owns trackers, Workstream owns stream hooks, and Delegate owns a
byproducts policy, but must still invent which setup operations to run and which project overlays
join those independent capabilities.

The member skills also expose project-customizable surfaces inconsistently. Journal, Backlog,
Delegate, Analyst, Inspector, and Auditor have a `setup` operation, while Architect, Contractor,
Workstream, Notepad, and Debugger expose active project templates, hooks, or flows without one.
Several record writers instead copy a template on first ordinary use. That makes project setup
partly explicit and partly an incidental side effect of doing work. It also weakens the rule that
the agent workspace contains deliberate, actively consumed project configuration rather than a
cache of anything a skill happens to bundle.

A central Clankshop installer would make invocation simple, but would restore a pack face and a
cross-owner writer. That conflicts with the accepted design: Clankshop is a faceless distribution
and human-readable seam map; installation has no project lifecycle; and each skill owns its files
beneath `<agent-workspace>/<skill-name>/`. The missing piece is therefore not a new pack-level
mechanism. It is a consistent member-owned setup contract plus a runbook that tells an agent when
to invoke those independent operations and what project-authored glue to apply afterward.

## Goal

Make an explicitly supplied `PACK.md` sufficient to guide an agent through configuring Clankshop in
an existing project. Every Clankshop skill with a durable, project-customizable surface owns an
idempotent `setup` operation; adopting that capability is optional at the project level, while a
selected durable capability may require its own setup before its normal verbs can run. The pack
runbook selects the relevant member setups, then guides the agent in authoring only the approved
cross-skill overlays. Installation remains side-effect-free, no `/clankshop` skill or lifecycle is
introduced, and no member requires pack-wide setup, a pack marker, or a sibling skill's setup.
Template-only setup remains optional because ordinary work can read the bundled fallback.

## Approach

Adopt **uniform capability, selective execution**:

- A skill gets `setup` when it has durable project files that it actively reads or executes and
  that are meaningful to deploy before ordinary work: active templates, hooks, doctrine, flows,
  staged tools, trackers, or another declared configuration surface.
- Setup is not added to pure mechanisms, scratch-only skills, or skills whose only project output
  is a record or an artifact authored on demand. Package-only examples, schemas, validators, and
  migration chains never make a skill setup-capable.
- Running `/<skill> setup` means “materialize this skill's declared project surface.” It does not
  recursively set up dependencies, write a sibling namespace, or apply cross-skill policy.
- The `PACK.md` body remains a human-readable runbook. When the user explicitly asks an agent to
  configure Clankshop from that file, the agent proposes a configuration profile, runs only those
  member setups, authors the approved glue, validates the result, and reports the exact project
  changes.

This is an alpha hard cut. Active project templates move to one explicit deployment rule:
deployed copy wins; otherwise the skill reads its bundled default without creating project files.
Only `setup` deploys a fresh template. The existing first-use template copy is removed rather than
retained as a second setup path. Recognized legacy locations still refuse and point to the owning
skill's `migrate` verb; setup never migrates or adopts them.

This specification supersedes only the ordinary template-resolution clause in
`→ specs/2026-08-25-skill-owned-artifact-migration.md` that copies a bundled template on first use.
That specification's canonical destinations, legacy detection, ownership classifiers, and explicit
`migrate` operations remain controlling. The new ordinary resolution order is canonical incumbent,
recognized-legacy refusal, then bundled read-only fallback.

The setup-capable Clankshop roster is:

| Skill | Setup-owned surface |
|---|---|
| Architect | active `adr.md` and `specs.md` templates |
| Contractor | active `plan.md` and `roadmap.md` templates |
| Workstream | active `manifest.md` and `debrief.md` templates; known stream hook points |
| Journal | staged records tool, ledger, and records README |
| Backlog | staged tracker tool, selected trackers, debrief cookbook, and its own route block |
| Notepad | active `notes.md` template |
| Analyst | active report-template catalog |
| Auditor | active `reports.md` template and project audit rubric |
| Debugger | active `bugs.md` and `investigation.md` templates; diagnostics flow |
| Inspector | project review-kind doctrine |
| Delegate | byproducts-policy hook point |

Shopbook does not gain setup: it authors a selected host procedure on demand rather than deploying
a bundled configuration set. Workspace remains a read-only structural checker. Checkpoint,
Mailbox, and Scheduler own scratch or operational state created by their named operations, not a
project customization surface to predeploy.

Alternatives rejected:

- **A `/clankshop setup` face or pack script.** It would give a faceless pack a lifecycle, require a
  cross-owner orchestrator, and make independent skills less truthful about their own setup.
- **Let the configuring agent write every file directly from `PACK.md`.** This bypasses owner
  preflight, incumbent handling, legacy detection, and each skill's knowledge of which bundled
  assets are active.
- **Keep the current mixed explicit/lazy model.** It works at runtime but cannot distinguish an
  intentionally configured project from a fresh project that merely used one record writer.
- **Add setup to every installed skill.** Empty ceremony does not improve configuration. The
  eligibility test is a deployed project surface, not pack membership.
- **Expose schemas beside templates.** Templates are editable authoring guidance; schemas,
  validators, and migrations are executable format authority and remain package-owned.

## Mechanism

### Member setup contract

Every setup-capable skill exposes `/<skill> setup [<root>]` in its routing surface and owns the
implementation. Existing domain arguments remain legal where the setup itself requires a choice,
such as Backlog's tracker selection; this specification adds no generic asset-selector language.

A setup operation follows these invariants:

1. Resolve `<root>`, `<agent-workspace>` (default `.spaces`), and, only when the skill owns records
   infrastructure, `<agent-records>` (default `.records`). Reject an unsafe root, absolute or
   root-escaping declaration, and symlinked or non-directory destination components.
2. Inventory only the skill's declared active assets. Every deployed template, hook, doctrine
   file, or flow must have a live read or execution site in that same skill. Package-only assets
   are excluded even when they live in a package directory named `templates/`.
3. Preflight the whole owned write set before creating directories, then recheck every existing
   parent immediately before each creation or replacement. A symlink, non-directory parent, or
   incompatible destination discovered by either check refuses that write. If a later recheck fails
   after earlier safe creations, report every completed path and stop; a rerun preserves those
   incumbents and deterministically finishes the remainder. Project-editable content is absent-only:
   copy or create it when absent, preserve a valid incumbent byte-for-byte, and refuse incompatible
   or invalid incumbents. A recognized previous-home artifact causes a clean refusal naming
   `/<skill> migrate <source-path>`.
4. Package-managed executable tooling may be refreshed when that skill already defines refresh as
   part of setup; user-authored templates, hooks, doctrine, flows, tracker data, and README content
   are never refreshed. A second setup therefore preserves accumulated project judgment.
5. Write only beneath `<agent-workspace>/<skill>/` except for a surface the skill explicitly owns
   elsewhere: Journal's records-layer standup and an established, delimited self-registration
   block such as Backlog's route. Setup never reads a sibling namespace as configuration and never
   writes another skill's files.
6. Report the repo-relative paths created, preserved, or refused using that owner's established
   output; this specification introduces no shared setup-output grammar. A successful rerun reports
   no writes. Standalone setup makes one scoped commit over its reported writes; when the caller
   declares a larger configuration sweep, the member remains write-only. The sweep records Git state
   before writing, refuses an approved destination that already contains unrelated changes, and
   derives its final path set from the Git diff limited to the approved destinations rather than by
   parsing heterogeneous setup output.
7. Validate the deployed surface using the owning skill's bundled rules. Setup never changes a
   document schema, reformats records, or resolves a collision by guessing; those are migration
   responsibilities.

For active project templates, ordinary skill use changes to this resolution ladder:

1. A valid `<agent-workspace>/<skill>/templates/<file>` exists: use it as the project incumbent.
2. A recognized legacy template exists while the canonical file is absent: refuse and name the
   owning skill's `migrate` command.
3. Neither exists: read the bundled active template without writing to the project.

This keeps setup optional while making deployment intentional. A project that never customizes a
template gets current bundled guidance after a skill upgrade; a project that runs setup owns its
deployed copy until it explicitly edits or migrates it.

Workstream setup deploys only its two active file templates and its two known hook points:

```text
<agent-workspace>/workstream/templates/manifest.md
<agent-workspace>/workstream/templates/debrief.md
<agent-workspace>/workstream/hooks/feature-completion.md
<agent-workspace>/workstream/hooks/after-eventful-ship.md
```

The hook files begin empty, so setup alone changes no Workstream behavior. Workstream continues to
treat a missing or empty known hook as no overlay. Delegate's existing byproducts hook follows the
same empty-means-disabled rule. Debugger setup deploys the active templates and a bundled
`diagnostics.md` flow carrying Shopbook's required `title` and `use-when` crawl keys.

Auditor setup is an optional, time-intensive, deferred enhancement. It deploys `reports.md` and
interactively calibrates the project rubric, but does not persist an audit report or write a pointer
into the host's document index or routing surface. A first `/auditor` pass is a separate,
explicitly approved operation after setup. Core Clankshop configuration never invokes Auditor and
does not wait for rubric calibration.

### Pack configuration runbook

The `PACK.md` body gains a **Project configuration** section. It is not automatically loaded by
installation and defines no new manifest or lifecycle key. The entry condition is an explicit
instruction naming a readable source manifest, such as:

```text
Read /path/to/grimoire/PACK.md and configure clankshop for <project-root>.
```

Pack format 1 does not guarantee that an installed pack exposes its source `PACK.md`; this feature
does not add a cache, discovery command, or installed runbook copy. The caller supplies the readable
manifest path.

The configuring agent performs one bounded sweep:

1. Read the target project's instructions and inspect its existing `.spaces`, `.records`, route
   blocks, legacy locations, and installed Clankshop members without writing.
2. Present a proposed profile naming every member setup, every project file it may create, and the
   cross-skill glue it proposes. Keep default roots undeclared; add `agent-workspace:` or
   `agent-records:` only when the project needs a non-default location. Obtain approval before the
   sweep writes project policy.
3. Invoke the approved member setups in write-only sweep mode. A useful baseline is Journal setup;
   a delivery-loop profile adds Backlog, Workstream, and optionally Delegate. Analyst, Architect,
   Contractor, Debugger, Inspector, and Notepad setup are selected only when the project wants to
   customize those skills' surfaces. Never include Auditor in the initial glue sweep: identify it as
   a time-intensive deferred enhancement and ask separately when the project is ready to calibrate a
   rubric.
4. Apply the approved seam bodies to the owner-created files. `PACK.md` describes the content, but
   neither the pack nor a member setup owns the cross-skill decision. The configuring agent writes
   it as project-authored policy under the consuming skill's namespace.
5. Rerun each selected setup and require no writes; run any advertised owner-specific check, then
   `/workspace check`. Compare the complete diff with the recorded pre-sweep state and approved
   destinations, then make one project-scoped commit if the user requested commits. Installation
   state and `grimoire.lock` are neither setup markers nor permission to configure the project.

The initial delivery-loop glue is deliberately narrow:

- Workstream's `feature-completion.md` tells the stream to run `/backlog debrief` over the completed
  feature before ship or save and to include actionable Delegate byproducts returned during that
  feature.
- Workstream's `after-eventful-ship.md` tells the stream to run `/backlog debrief` over ship-specific
  friction only and not refile leftovers already handled at feature completion.
- Delegate's `byproducts.md`, when selected, asks a returned actionable byproduct to include a
  proposed class (`task`, `issue`, or `feedback`), evidence or path, and why it matters. It tells
  Delegate not to file directly because the calling workflow owns routing.

There is no direct Delegate-to-Backlog writer. Delegate returns observations to its caller;
Workstream's completion seam invokes Backlog's debrief; Backlog's project cookbook decides which
enabled tracker receives an item. Contractor plans remain Workstream queue sources through their
typed artifact seam and need no hook file. Architect-to-Inspector-to-Contractor remains an
invocation flow, not deployed configuration.

### Doctrine and enforcement

Skill-builder doctrine changes from first-use template copying to explicit setup plus bundled
fallback. Its setup guidance distinguishes project-editable incumbents from refreshable
package-managed tools, retains owner-local publishing, and requires every deployed asset to have a
live consumer. `skill-builder check` enforces that each nonempty `## Project templates` inventory
has a routed setup operation and that every listed file is covered by its setup test. Hook, flow,
and doctrine deployment remains declared in the owning setup surface and tested there; no shared
configuration registry or pack executor is introduced.

The current mixed behavior is removed in the same change. There is no compatibility alias for
lazy template locking, no setup receipt, no Clankshop marker, and no migration performed merely
because setup encountered an old file.

## Verification

Add setup fixture coverage for the eleven setup-capable skills named in this specification. All
eleven prove unsafe-parent refusal at preflight and immediate recheck, exact owner boundaries,
owner-specific path reporting, safe continuation after an interrupted partial deployment, and a
zero-write rerun against the same package version. The seven active-template owners—Architect, Contractor,
Workstream, Notepad, Analyst, Auditor, and Debugger—also prove bundled fallback without project
writes, absent-only deployment, valid-incumbent preservation, package-only exclusion, and legacy
refusal where that owner registers a previous home. Workstream and Delegate prove empty-hook
degradation; Debugger proves that its deployed flow is crawlable. Journal and Backlog separately
prove that refreshing package-managed tools preserves project-authored content and tracker data.

Add a disposable consuming-project test for the `PACK.md` runbook's delivery-loop profile. Starting
from an existing repository with no `.spaces` or `.records`, the test stands up Journal, selected
Backlog trackers, Workstream, and Delegate; applies the three approved overlays; verifies that the
Workstream hook parser sees the two bodies; verifies Backlog's staged tool and cookbook; verifies
Delegate's policy is readable; and runs `/workspace check`. The resulting paths must belong only to
their declared owners, schemas must remain inside skill packages, and a second complete sweep must
produce no diff. The fixture must prove that this core sweep neither invokes Auditor nor waits for
rubric decisions.

Test Auditor separately as a deferred setup: deployment and interactive calibration preserve
incumbents and create no audit report or host-index pointer. Only a later explicit `/auditor` pass
mints the initial report. Auditor setup is not a prerequisite for the core fixture's validation or
commit.

Add negative proofs that pack install, update, check, and remove never execute the runbook or create
project configuration; that the runbook never creates a `/clankshop` face or marker; and that no
member setup writes a sibling's namespace. Add a red-proof to `skill-builder check`: temporarily
remove the setup route from one declared project-template owner and require lint to fail.

Red-prove every material absence class:

- **Immediate parent recheck:** use a test-only seam to exchange a fixture parent for a symlink after
  preflight; disabling the immediate recheck must make the safety test fail.
- **Owner and package boundaries:** inject one package-only asset and one sibling destination into a
  fixture deployment inventory; the boundary tests must fail.
- **No pack lifecycle:** give a fixture member a canary setup that writes a sentinel. First invoke
  the canary directly and prove the absence assertion fails; after cleaning the sentinel, pack
  install, update, check, and remove must leave it absent.
- **Deferred Auditor writes:** instrument Auditor setup with audit-report and host-pointer sentinels;
  prove its isolated negative tests detect each forbidden write.
- **Core-sweep isolation:** make the instrumented Auditor setup fail loudly if invoked; the
  Journal/Backlog/Workstream/Delegate configuration sweep must still pass.
- **Setup-route lint:** temporarily remove the setup route from one declared project-template owner
  and require `skill-builder check` to fail.

Run every changed skill harness, the Skill-builder lint and doctrine suites, the pack manifest
tests, and a repository-wide census for the retired first-use copy language. Ground the final
runbook commands against the actual setup surfaces. Verify that only approved implementation paths
changed, and preserve and report every unrelated worktree change.
