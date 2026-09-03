---
doctype: specs
status: published
schema: architect/spec@1
tags: [skilldata, workspace, skill-builder, migration]
---

# Skilldata hard cut and Workspace retirement — Spec

Related: → `adr/2026-09-02-reserve-skilldata-for-project-and-global-skill-owned-data.md`;
→ `specs/2026-08-25-agent-workspace-naming.md`;
→ `specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md`;
→ `specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md`;
→ `specs/2026-09-02-foreman-first-use-and-global-operation-templates.md`

## Problem

Grimoire puts project-owned skill support under `.spaces/<skill>/<kind>/...`. The owner-first
grammar is useful, but the root name does not explain that the content belongs to agent skills and
sits beside a much more widely recognized `.agents/skills/` installation convention. The resulting
layout makes an important custody boundary look like generic scratch space.

The convention also has a separate `workspace` skill whose only job is to inspect the complete
`.spaces` tree and validate owner names, kind names, extensions, and symlinks. That package owns no
project data and performs no repair. Keeping a runtime skill solely to validate a path grammar adds
an installation, invocation, pack member, test suite, and cross-owner inspection surface. It is at
odds with the stronger library rule that each skill owns and validates only its own paths.

At the same time, new global skill-owned data is settling under
`~/.agents/skilldata/<skill>/...`. Leaving project support under `.spaces` would create two names for
the same ownership idea, while moving package bytes under `skilldata` would incorrectly mix mutable
data with installed skills. The missing design is one explicit convention that distinguishes
package code, project support, global user data, records, and public trackers without adding a
central workspace manager.

This is a coordinated naming cut, not a brownfield migration feature. Existing `.spaces` content is
outside the implementation: project owners may remove or move it themselves. Compatibility probes
would make every future reader pay for paths that the cut is meant to retire.

## Goal

Make `.agents/skilldata/<owner>/<kind>/...` the only live project home for owner-local skill support,
retain `~/.agents/skilldata/<owner>/...` as the optional user-global counterpart, and remove the
`workspace` skill completely. Teach the distinction and custody rules in `skill-builder` so newly
authored skills select the correct scope and current skills cannot reintroduce `.spaces`.

After the cut, a consuming project can understand the durable layout without an extra command:

```text
.records/                         dated typed records
.agents/skills/                   installed skill packages, when project-local
.agents/skilldata/<owner>/<kind>/ project-owned support for one skill
.trackers/                        public project queues

~/.agents/skills/                 user-global installed skill packages
~/.agents/skilldata/<owner>/...   optional user-owned cross-project skill data
```

The feature does not migrate, copy, delete, diagnose, or warn about incumbent `.spaces` trees; add a
replacement runtime validator; make every skill global-stateful; change `.records` or `.trackers`;
or deploy project skilldata into Grimoire itself.

## Approach

Adopt the shared `skilldata` decision in the related ADR and make one library-wide hard cut. Project
support keeps the proven owner-first, closed-kind grammar but moves beneath `.agents/skilldata`.
Global skilldata shares the owner boundary and nothing else: each global-state owner defines its own
internal layout because feedback ledgers, reusable authoring inputs, caches, and other cross-project
data do not naturally fit the project kind list.

Delete `workspace` rather than rename or repurpose it. Runtime custody becomes local: a skill checks
the concrete parent chain and artifact it is about to read or write, never every sibling owner.
Authoring-time custody becomes portable doctrine plus lint in `skill-builder`. This is an
intentional reduction in surface area, not a relocation of `workspace-check.sh`.

Make project data authoritative by default. A global home is visible to a project only when the
owning skill explicitly defines a global-input feature and its materialization or precedence rule.
Global bytes are never directly executable project instruction. Foreman, for example, may suggest a
global operation template, but must materialize reviewed project operation bytes before a goal can
consume them.

The related ADR owns the rejected namespace, package-co-location, central-validator, dual-read, and
transparent global-fallback alternatives. This spec implements that decision without adding another
runtime layout mode.

## Mechanism

### Canonical project grammar

The project root is the Git worktree or other project root already resolved by the acting skill.
Project support paths have exactly this shape:

```text
<project>/.agents/skilldata/<owner>/<kind>/...
```

`<owner>` is a lowercase kebab-case skill slug matching `[a-z0-9-]+`; the namespace is open-ended.
`<kind>` is exactly one of `doctrine`, `drafts`, `hooks`, `operations`, `scripts`, or `templates`.
Direct files under `skilldata/` or an owner directory, unknown kinds, invalid owners, and symlinked
managed parents remain invalid destinations. Artifact-specific schemas, extensions, nested layouts,
and read/write rules belong to the owner. These conditions are diagnosed only when an owner or an
explicit cross-owner consumer resolves the affected path; unrelated malformed sibling content is
inert and has no whole-tree validation contract.

Each skill constructs the fixed path directly from the project root. Production instructions and
scripts accept no skilldata-root, workspace-root, or owner selector. A skill may create
`.agents/skilldata`, its own owner child, and only the kinds it declares, with a real-directory and
non-symlink recheck immediately before each write. It neither creates nor inventories sibling
owners. A deliberate cross-owner reader such as Foreman's operations inventory may enumerate only
its declared kind and remains read-only outside its own owner.

Project skilldata is ordinary repository content and is commit-eligible under the consuming
project's policy. It is not necessarily present: package-only fallbacks remain valid, reads do not
create empty directories, and explicit setup or an authorized publisher creates only concrete
owned artifacts. Grimoire's patient-zero caveat remains: tests deploy to disposable fixtures, not
to this library's real `.agents/skilldata` tree or front door.

### Global grammar and scope boundary

A skill with separately justified cross-project user data constructs:

```text
<resolved-user-home>/.agents/skilldata/<owner>/...
```

The global root and owner slug are fixed. The contents below the owner are specified by that skill;
the six project kinds are not imposed globally. A skill may create the shared root and its own child
but may not enumerate or mutate siblings or install a shared registry. Tests isolate the user home
at the process boundary; production code gains no alternate-home option.

Global data is user-private by scope and never becomes project data merely because the names match.
A skill that reads both scopes must specify the exact artifact class, lookup order, invalid-entry
behavior, and materialization boundary in its own spec and prose. Project artifacts win for the same
declared input. A global authoring input may seed a fully previewed project artifact but is not
itself executed, imported by goal identity, or written back during project work.

`.agents/skills` and `~/.agents/skills` remain package installation locations. No setup or runtime
writer stores mutable data inside an installed package or follows an installation symlink as a data
destination. Package-manager caches, locks, trust, and desired-installation state remain outside
`skilldata`.

### Workspace retirement

Remove the complete `skills/workspace/` package, its scripts and tests, its README inventory row,
its `clankshop` pack membership and prose, installation expectations, skill lists, and current
cross-references. There is no tombstone package, deprecated-command shim, renamed command, or
`/workspace check` successor. After the cut, `/workspace` is simply not a Grimoire skill.

References to a generic English workspace remain when they mean a Git worktree or working area.
References to the retired skill, the `.spaces` root, an `agent-workspace` declaration, a
workspace-root selector, or the old validator contract disappear from live package and library
surfaces. Historical typed records remain unchanged except for explicit supersession links; tests
may contain the retired spelling only as a rejection input.

No implementation step scans, moves, removes, aliases, or reports an existing `.spaces` directory.
After the cut it is inert, and its cleanup belongs to the project owner. This includes no special
migration for deployed Foreman operations, Architect drafts, doctrine, hooks, or templates.

### Skill-builder doctrine and scaffolding

Update `skills/skill-builder/docs/DOCTRINE.md` as the portable authority. Its fixed-homes section
names `.records`, `.agents/skilldata`, and `.trackers`; examples and owner-specific guidance use the
new project path. Add a global-skilldata section that records these distinctions:

- project support is owner-first with the closed project kind set;
- user-global state is optional, separately justified, and owner-defined below the fixed owner;
- neither scope has a shared registry or central lifecycle;
- `.agents/skills` contains package bytes, never mutable skill data;
- project content normally outranks an explicitly supported global input;
- global content cannot become executable project authority without the owner's review and
  materialization protocol; and
- a skill validates only the paths and artifact schemas it owns or explicitly consumes.

Revise `/skill-builder new` so durable storage is classified along two independent axes:

1. Does the skill own project support, and which of the six kinds does it use?
2. Does it need user-global cross-project data, and what concrete need rules out project or package
   storage?

The default for the second question is no. A project-support scaffold uses
`.agents/skilldata/<new-skill>/<kind>/`; a global scaffold names the fixed global owner, requires its
internal data contract and privacy/permission behavior, and adds no project setup unless the first
answer also requires one. A skill that owns both scopes must state their precedence and transfer
boundary. The tier classification remains about lifecycle, not a promise that both scopes exist.

Every package that reads or writes global skilldata has a `## Global skilldata` section in
`SKILL.md`. It names the exact `~/.agents/skilldata/<owner>/...` artifacts, why project and package
storage are unsuitable, whether initialization is lazy or explicit, permissions and sensitive-data
behavior, and any project/global lookup or materialization rule. A global-only package states that
it writes no project data. This section is the machine-detectable declaration used by lint; prose
elsewhere cannot silently opt a package into global storage.

Revise `check`, `review`, and `skills/skill-builder/scripts/skills-lint.sh` to enforce the authored
contract without becoming a consuming-project validator. The mechanical gate:

- rejects `.spaces`, retired project-home declarations, and workspace-root selectors in live skill
  prose and scripts;
- recognizes `.agents/skilldata/<owner>/<kind>` as the only project-support literal and rejects
  kind-first or unknown-kind spellings;
- recognizes `~/.agents/skilldata/<owner>/...` as global only when the package carries the exact
  `## Global skilldata` declaration and that section names the matching owner;
- checks obvious writer-owner mismatches while leaving deliberate, documented cross-owner reads to
  review judgment;
- permits the retired spelling only in historical record stores, the bounded Skill-builder
  retirement-doctrine paragraph, the lint implementation that recognizes the token, and a
  negative-test line carrying the exact annotation
  `# lint: allow retired-skilldata-rejection`; none of those surfaces may resolve, read, write,
  migrate, or emit the retired path; and
- contains no check that requires a consuming project to have any skilldata directory.

Update the skill-builder scaffold fixtures and lint red/green tests so disabling each new rule makes
its sabotage case fail. The old Workspace validator tests are deleted with the package, not copied
into skill-builder.

### Coordinated library cut

Update every current Grimoire skill that reads, writes, documents, seeds, indexes, or tests project
support. The change preserves artifact schemas and owner/kind tails; only the project prefix and
related vocabulary change. Package scripts use a variable such as `skilldata=.agents/skilldata` only
when it improves local construction, never as a public selector.

README and `PACK.md` present the four distinct surfaces: records, installed packages, project/global
skilldata, and trackers. Grimoire's own `AGENTS.md` inventory removes Workspace but receives no
deployed route block. Current specs or ADRs that are still drafts may link to this decision;
published historical records stay byte-stable and are governed through the ADR's explicit
supersession boundary.

This spec replaces only the `.spaces`, Workspace, and project-support clauses of the related draft
→ `specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md` before either
draft is published. That draft's `.records` migration, `.trackers`, adjacent-provider, Backlog
debrief, and unrelated fixed-home requirements remain available to its eventual implementation.

The hard cut lands as one coherent implementation. There is no supported intermediate state in
which some live consumers write `.spaces` while others read `.agents/skilldata`, and no release
claims success until the live-source census is clean and all package suites pass.

## Verification

Prove the project grammar at its two actual enforcement boundaries. Skill-builder fixtures cover
the owner-first literal, all six kinds, invalid owners, kind-first and unknown-kind spellings, and
obvious writer-owner mismatches. Each affected owner tests only the paths it reads or writes:
missing-root behavior, absent-only creation, incumbent preservation, unsafe parents, symlink
refusal, and cross-owner write refusal. Deliberate cross-owner readers test their declared kind and
ignore or report malformed entries there without validating unrelated siblings. No fixture expects
an arbitrary malformed skilldata tree to fail as a whole.

Extend skill-builder tests to prove:

- a generated project durable-home package names only its owner beneath `.agents/skilldata`;
- a project-plus-global package documents two distinct roots and a precedence/materialization rule;
- a package is not granted global storage merely by selecting durable-home;
- live `.spaces`, kind-first skilldata, unknown project kinds, owner-mismatched writes, retired
  selectors, and mutable writes beneath `.agents/skills` fail;
- correct owner-first project literals and justified global owner literals pass; and
- only annotated negative lines and the two named Skill-builder self-hosting surfaces may quote
  `.spaces`, without making the lint implementation tolerate it in other live skill surfaces.

Delete Workspace's suite and remove it from pack-install expected members. Pack installation must
still succeed and expose every remaining member. A repository census over current README, pack,
skill prose, package scripts, and non-historical fixtures must find no operative `.spaces` path or
Workspace-skill route. The census excludes `.records/**`, `.scratch/**`, Git history, the bounded
retirement paragraph in `skills/skill-builder/docs/DOCTRINE.md`, the rejecting pattern in
`skills/skill-builder/scripts/skills-lint.sh`, and only test lines carrying
`# lint: allow retired-skilldata-rejection`. It does not broadly exclude tests, comments, or the
Skill-builder package.

Run every affected skill's suite, the complete `skill-builder` suite,
`skills/skill-builder/scripts/skills-lint.sh .`, pack installation tests, and `.records/records.sh
check`. Verify separately that Grimoire's real `AGENTS.md` has no generated door block and that no
real `.agents/skilldata` content was created. No verification step requires an incumbent `.spaces`
tree or asserts that one was migrated or deleted.
