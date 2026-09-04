# DOCTRINE — building skills for coding agents

The **portable design philosophy** for authoring agent skills — tools, scripts, and the skills
themselves — distilled from practice building this library. It applies to *any* skills library, not
just the one `skill-builder` ships from: install `skill-builder` anywhere and this doc, the lint gate
(`scripts/skills-lint.sh`), and the boundary-audit workflow (`docs/BOUNDARY-AUDIT.md`) travel with it.

A host library imports this doctrine into its own front-door doc (`AGENTS.md`/`CLAUDE.md`) with a
short pointer, then lists only its **local overrides** underneath — the same public-doctrine +
private-override shape a personal dotfiles config uses over a shared one. Apply this doc whenever you
add or revise a skill; `skill-builder calibrate` is what keeps it current as practice evolves.

## One regime: every skill is independent

This doctrine's **independence rules** — self-scoping descriptions, typed edges, and the
no-sibling-seam discipline — apply to every skill. A `PACK.md` is a pure distribution bundle, not a
skill surface. Placing one beside `SKILL.md` grants no exception: the skill must still route and
function bare, pass every boundary check, and carry its own typed-edge block. Pack membership also
grants no exception. Composition belongs in the pack manifest and its human-readable body, outside
the member skills.

## Design philosophy

- **Scripts compute facts; agents decide.** Push mechanical, deterministic state-analysis into small
  **read-only** scripts that print compact `key=value` facts + evidence, and keep the judgment in the
  agent prose. A script is stateless — it can't see session context ("I already did X this turn") — so
  a *recommendation* it emits will sometimes be confidently wrong, and a confident-wrong verdict is
  worse than none. Facts have no such failure mode. This also pays off in tokens and turns: if the
  agent would otherwise run several commands and reason over their raw output to make a routine call,
  one structured read replaces all of it.

- **One stable entrypoint for approval.** Wrap commands whose arguments vary per run (per-stream
  paths, IDs) behind a single program, so a prefix-matching approval policy can permit the whole
  capability with one rule. You can't allowlist what you can't enumerate.

- **Safe-by-default = allow the safe, let the rest prompt.** When unmatched commands prompt the user,
  you only ever *add* allows for safe, reversible commands; destructive ones keep prompting for free.
  No deny rules, no enumerating the dangerous.

- **A snapshot must never pose as authoritative.** Any derived or cached artifact (an orientation map,
  a precomputed classification) is a snapshot of a moving target. Make it **pointer-heavy** (paths and
  IDs rot gracefully; pasted content rots silently), **stamp what it was built against**, and ship a
  **cheap validator** that flags drift. Say "verify before trusting" in the artifact itself.

- **Prefer the simplest portable rule over a configurable one.** A simple rule that is identical
  everywhere and errs toward the safe/expensive choice beats a precise rule that needs per-host wiring
  — e.g. classify "docs vs build" as *every changed path ends in `.md`*, not host-specific globs.
  Zero-config and conservative travels.

- **Fix the doctrine, not just the tool.** When you change a rule, change it in the prose every agent
  reads — not only in the one script that consumes it. Otherwise the script and the doctrine disagree,
  and that divergence is tech debt.

- **Harness-agnostic packages; harness-specifics at the edge.** Ordinary workflow skills name the
  generic concept ("a prefix-matching approval policy"), not a particular agent or harness; concrete
  harness configuration lives outside those packages. A skill whose own domain is harness execution
  or cross-harness routing may name the mechanisms it supports, but keeps those names at its dispatch
  boundary and does not leak them into unrelated project workflow doctrine.

- **Skills are living artifacts — capture the friction of using them.** Strong, concrete feedback about
  a skill you just used (a friction, a gap, a win worth keeping) is a signal that *improves* the skill,
  not noise to absorb. Route it to the **skills' home feedback channel** — tagged by skill, never a
  consuming project's tracker, where it strands and the authors never see it (a public library's
  default channel is typically its issue tracker; an installation may override it with its own
  collection file). The bar: *would this change the skill?*

- **Self-scoping descriptions — the runbook holds the glue, not the leaves.** A skill's frontmatter
  `description:` is its **routing surface**, and it must route **on its own**: the harness selects from
  descriptions alone, and a bare install (skills present, no pack deployed) has no seam map in context.
  So a description states only its **own** job and domain; it does **not** name a sibling to defer,
  disambiguate, or contrast (*"for X use /other"*, *"distinct from /other"*, *"peer to /other"*) — that
  contrast is the runbook's job. Two narrow exceptions: a **router** may name the mechanisms it
  dispatches among (describing its own function), and a genuine **fragment** may carry one orientation
  pointer to its parent. A **body** may keep a soft operational pointer a reader needs mid-task, but
  must not re-document or own another skill's seam — point, don't paste. **Competence is the hard
  constraint:** drop a cross-reference only when the two self-scopes still route correctly without it
  (verify with a routing probe — see `docs/BOUNDARY-AUDIT.md`); where they can't, **sharpen the scope,
  never restore the pointer**. Independence is maximized under routing accuracy, never traded for it.

- **Cross-skill seams live in the runbook.** How two skills compose — who owns what, where one stops
  and the next starts — belongs in the pack/runbook that composes them, never duplicated into a leaf's
  frontmatter. The load-bearing invariant: **no skill crosses another's seam.** A seam asserted in a
  leaf but absent from the runbook is drift; a seam duplicated into a leaf is co-mingling — audit for
  both (`docs/BOUNDARY-AUDIT.md`).

- **Glue is content vs. mechanism.** A runbook may describe the seam, while the
  owning skill implements the reader and a project owns any local overlay body.
  **Project hook files** live at
  `.agents/skilldata/<skill>/hooks/<seam>.md`; there is no composer skill or
  pack-level writer. The same ownership rule applies to `operations/`, `hooks/`, and
  `templates/`: a publisher writes only beneath its own skill namespace.

- **Skills self-initialize and self-describe via typed edges; the composer wires the seams.** The
  tenets above govern what a skill's `description:` may *say*; this one — their extension from
  **routing to initialization** — governs what a skill's `setup` may *write* and what its edges may
  *name*. A skill stands up **its own** home so its state works **bare**, with no composer deployed.
  Front-door registration is a separate, optional public surface: a skill owns one only when
  always-loaded routing is independently justified, never merely because the skill persists data.
  What it declares
  about its place in a workflow is a set of **typed edges** (`produces` / `consumes` / `handoff`) keyed
  on artifact/capability **types, never sibling names**; a composer **derives** the cross-skill seams
  by *matching* one skill's edges against another's. A skill that names its successor has authored a
  seam — the co-mingling the tenets above removed, one level up. See *Typed edges* and *Self-init tiers*
  below for the mechanics; **§ Corollaries** for the four testable rules.

## The three layers a skill may self-describe

1. **Typed edges** (`produces`/`consumes`/`handoff`) — the mechanical wiring points. **Required of
   every portable skill** (an all-empty block is a *stated* fact, "I'm a pure mechanism," not an
   omission; pure bundles are not skills and carry no edge block — § One regime).
2. **Ideal-use examples** — self-contained *"how to use me"* route/workflow a composer or role skill
   can ingest to understand usage. **Enrichment.**
3. **Deployable seed** — project-customizable assets (for example,
   `.agents/skilldata/<skill>/templates/`) plus an authoring verb. **Enrichment.**

Edges are the minimum; layers 2–3 are optional. **Examples stay self-contained** — a cross-skill
workflow is a seam the composer *generates* from edges, never a hardcoded sibling reference. A
deployable-assets home (layer 3) does **not** make an operator a steward — it just means the skill has
customizable files.

## Self-init tiers — template the scaffold to the skill's shape, not one-size-fits-all

Four tiers, empirically derived from scoring an existing ten-skill library against this doctrine
(`skill-builder new` asks which tier fits when scaffolding a skill):

| tier | shape | self-init |
|---|---|---|
| **durable-home** | owns a real project artifact store (a tracker, a rubric, a seed) | idempotent scaffold of that home, **no dependency on a composer having run first** |
| **in-place steward** | maintains a layer of the *host repo itself* (docs, the skill set) in place | **none** — nothing private to scaffold; operates directly on what's already there |
| **scratch-only** | needs a working area but it's ephemeral | **none** — a gitignored dir, lazily created on first use; no protocol |
| **pure mechanism** | a router/transport with no storage | **none** — nothing to create |

Only the **durable-home** tier requires a real `setup` verb for its home scaffold. Front-door
registration is independent of tier, per *Typed edges & registration* below. The other three do not
gain setup merely from their tier,
though a skill of any tier may route setup for a declared deployable project surface. With no such
surface, skip the ceremony — "no home" and "all-`—` edges" are legitimate, recorded dispositions,
not gaps to fill in later.

### Setup and repair verbs

`setup` is the explicit reconciliation verb for a skill-owned durable project surface. It creates
missing owned pieces, preserves valid incumbents and user data, refreshes only declared
package-managed artifacts, and is a no-op when current. A rerun completes only missing steps. Use a
durable intent only when choices or completed-path custody cannot be reconstructed safely from
resulting state; do not add receipts or transaction files by default.

`repair` is optional, not the second half of a required pair. Add it only when an initialized layer
has a small package-managed operational surface that can become missing or stale independently of
its configuration and data. Repair uses the same reconciler with a smaller write set; it never
initializes the layer, reselects configuration, migrates, or mutates user data. Missing prerequisites
direct to `setup`. Skills with only absent-only templates, hooks, or doctrine normally need `setup`
alone.

**Registration tracks a justified always-loaded route, not mere existence or durable state.** Any
skill tier may own registration when agents must discover or execute a concise route before loading
the skill, but that public surface must be selected and justified independently. Otherwise skip it:
the skill's own routing metadata and a self-describing durable home are sufficient, and an extra
block would only bloat the front door. Persisting captured items does not by itself confer front-door
ownership.

**A project-layer pointer is not route registration.** A durable public layer with a fixed local
guide and adjacent provider may expose an explicitly invoked, absent-only pointer from the project
front door to that guide when bare discoverability is independently justified. The pointer names
project state, not a skill route or verb roster. It uses a fixed canonical path, previews exact prose,
requires confirmation, and becomes project-owned immediately: no package markers, version, refresh,
replacement, or removal lifecycle. An existing literal guide-path mention satisfies it; a conflicting
reserved heading refuses. Setup, repair, migration, runtime, and composition never install or require
the pointer. The layer README remains package-managed because it evolves with the adjacent provider,
and together they must support ordinary use without the source skill. Maintenance still stops when
the owning skill is unavailable. A patient-zero library tests the pointer only in throwaway projects.

## Typed edges & registration — the mechanics

An **edge** is a one-line declaration: `<kind>: <type>[, <type>...] [— <note>]`, in a delimited
`## Edges` section of the skill's own doc (not the frontmatter — that stays the lean routing surface):

```markdown
## Edges
<!-- edges:<skill-name> -->
- produces: <type> — <what, briefly>
- handoff: — (none; ...)
- consumes: — (none; ...)
<!-- /edges:<skill-name> -->
```

Three kinds, by control-flow strength:

| kind | means | composer reads it as |
|---|---|---|
| `produces: T` | "I emit an artifact/state of type `T`." | a **data source** for `T` |
| `consumes: T` | "I read/act on an artifact/state of type `T` as input." | a **data sink** for `T` |
| `handoff: T` | "I *terminate* expecting a successor; the baton is `T`." | a **control-flow seam** — pair with a `consumes: T` |

The composer's matching rule: `handoff: T` on A + `consumes: T` on B identifies a candidate
**seam** (control may flow A→B). `produces: T` on A + `consumes: T` on B identifies a candidate
**dependency** (B may read A's output, with no implied control). Equality is necessary, not
sufficient: the composer still checks the notes and ownership. Owner-local skilldata kinds such
as `doctrine`, `hooks`, and `templates` do not cross owner namespaces merely because their coarse
type strings match. Unmatched edges are legal — a producer with no consumer is a leaf output; a
consumer with no producer takes its input from outside the skill set. **A and B never name each
other** — the composer supplies both names after matching on `T`. Types are plain, open strings;
prefer coarse, shared types (`plan`, not `feature-plan-v2`) over a precise-but-lonely one per skill.

**Registration**, when independently declared by a skill of any tier, idempotently projects a route
into the host's always-loaded front-door doc, inside a `## Skill routes (self-registered)` section:

```markdown
<!-- skill:<name> BEGIN built-against:<sha-or-version> -->
### /<name> — <one-line role>
Route: <what it does>. `/<name> <verbs>`.
Edges: produces `<type>`.
<!-- skill:<name> END -->
```

**Content-vs-arrangement split:** the skill owns only the bytes between its own `skill:<name>`
delimiters; a composer owns everything around the blocks (section header, ordering, derived seam
notes) and must never orphan a skill's delimiters. Write protocol: **absent → append** (creating the
section if needed); **present → replace only between the delimiters**; **malformed → report and touch
nothing** (safe-by-default — never clobber hand-edited content).

**If you are building/testing this mechanism inside the library that authors the doctrine itself**
(the way this doctrine was proven here): never register against that library's own real front-door
doc. Exercise `setup`/registration against a throwaway fixture instead. The library that teaches the
mechanism is not thereby a self-registering deployment of it.

## Fixed project homes

Project-owned skill state uses three canonical roots beneath the project root. Project-local
installed package bytes, when present, live separately under `.agents/skills/` and are never a
mutable skill-data destination:

- `.records/` holds dated typed records, Journal's adjacent `records.sh`, and `history.tsv`.
- `.agents/skilldata/` holds owner-first skill support at `.agents/skilldata/<skill>/...`.
  Owner names are open `[a-z0-9-]+`. The owner defines that folder's internal layout.
  Shared landing names (`doctrine`, `drafts`, `hooks`, `operations`, `scripts`,
  `templates`) remain vocabulary for those artifact types; they are not a closed set of
  children. Trackers never live under skilldata — they use `.trackers/`.
- `.trackers/` holds public tracker tables under `tables/`, lifecycle events in `history.tsv`,
  Backlog's adjacent `trackers.sh`, and the editable `DEBRIEF.md` routing prompt.

These are constants, not defaults. Project front doors do not select alternate homes, and package
scripts do not accept home-selection arguments. A skill constructs its owned path directly from the
project root and the relevant canonical literal. Adjacent first-class providers self-locate and
require their canonical parent; callers invoke the installed provider rather than bundled bytes.

The three layers remain semantically distinct even though their locations are fixed. Typed work
products belong in `.records`; owner-local support belongs in `.agents/skilldata`; public queues and their
routing surface belong in `.trackers`. A skill materializes only the paths it owns. Skill prose
names canonical paths literally—for example `.records/plans/`,
`.agents/skilldata/auditor/doctrine/test/workflows/audit/`, and `.trackers/tables/tasks.tsv`—rather than inventing a
root placeholder or resolver.

Brownfield layout is a migration concern, not a runtime configuration feature. A skill may expose a
narrow, explicit migration for content it owns, but ordinary setup and runtime code never probes,
adopts, aliases, or dual-reads a prior home. Historical evidence may retain retired spellings; live
instructions and implementations may name them only in a bounded rejection or migration surface.

The hard-cut rule is intentionally easy to audit: fixed construction is visible at each reader and
writer, while the library lint rejects retired declarations, selectors, and symbolic-home tokens.

The former `.spaces/` project root is retired by a hard cut: live skills do not read, write, probe,
migrate, alias, warn about, or remove it. Historical records may retain it as evidence, and a
same-line annotated negative fixture may name it only to prove rejection; existing trees are inert
and remain the project owner's responsibility.

## Global skilldata

User-owned data that genuinely spans projects lives beneath the fixed global owner root
`~/.agents/skilldata/<skill>/...`. This scope is opt-in and independent of project durability. The
owner defines its internal layout, artifact schema, permissions, initialization, retention, and
sensitive-data behavior, as with project skilldata; there is no extra global kind vocabulary,
registry, provider, or sibling validator. A skill creates or inspects only its own child and never follows installed-package
symlinks as data destinations. Installed packages remain under `~/.agents/skills/` and must not
contain mutable runtime data.

Global data is user-private input, not project authority. A package that sees both scopes states its
lookup order, invalid-entry behavior, and reviewed transfer or materialization boundary. Project
content normally wins for the same declared input. A global authoring artifact may seed a complete
project preview, but it is never directly executed, imported as a project identity, or written back
during project work.

Every package that reads or writes this scope carries this machine-detectable declaration in
`SKILL.md`, with exactly one nonempty bullet for each required field:

```markdown
## Global skilldata

- Scope: user-global, <artifact boundary>.
- Path: `~/.agents/skilldata/<skill>/<owned-tail>/`.
- Access: read-only | read-write; <initialization behavior>.
- Safety: <unsafe-state, permissions, and sensitive-data behavior>.
- Justification: <why project and installed-package storage are unsuitable>.
```

A global-only package also states that it writes no project data. A package using project and global
data states precedence and materialization explicitly. Merely owning a durable project home never
grants global storage.

## Record-writing skills

A skill that mints a typed record follows these rules. Portable — any skills library, not just
this pack. `skill-builder new` scaffolds them; `check` and `review` enforce them.

1. **Destination.** A typed record is written under fixed `.records/`.
   Skill prose names the fixed path literally. Mint/write scripts derive it from the project root
   and do not scan the front door.
2. **Carry schemas and active templates; keep them distinct.** Each record format has a
   package-owned schema identifier, validator, and migration chain. A project template is an
   optional, body-only authoring scaffold the skill actually resolves while working; it cannot
   declare or select a schema. A `## Project templates` list in `SKILL.md` names every bundled
   file that the owning skill's explicit `setup` may deploy absent-only to
   `.agents/skilldata/<skill>/templates/`. Every listed file has a live read site and setup
   coverage. Files not on the list are package-only and are never deployed. Retired generic record
   shells do not remain as unused project lock-ins.
3. **Own-store standup.** On first write, `mkdir` that skill's store (and `.records`
   if needed). Do not create a deployed `records.sh`, `history.tsv`, other
   stores, the records README, or the *flat* `.records/templates/<doctype>.md`.
   Ordinary writing never creates `.agents/skilldata`; only the owning skill's explicit setup may
   deploy its project template.
4. **No floor.** Missing `records.sh` is not an error. Journal standup is never a
   precondition. A description must not say the skill requires a stood-up records layer.
   A verb must not refuse and send the operator to journal standup.
5. **In-package contract.** The writer states the four keys (`doctype`, `status`, `schema`,
   `tags`), its package-owned `schema` values, the status / stage vocabulary **as registered in
   `specs/records-front-matter.md`** (do not restate the enum
   here — that file is the contract), the dated slug
   (`YYYY-MM-DD-<slug>.md`), and the record-link form
   (`→ <store>/<file>.md`) in *its own* package. It does not
   send the agent to another skill's `SKILL.md` for those bytes.
   Pack composition (the bundle runbook) still names journal as
   the format authority; leaves do not.
6. **Opportunistic `records.sh`.** If `.records/records.sh` is executable, use it directly before
   `new --schema <owned-schema> [--template <resolved-body>]` / `touch` / `done` / `list`.
   Otherwise write the same four-key front matter in file mode and use the resolved body scaffold.
   Resolution is the **project-templates rule** below.
   Never write a second copy at the *flat*
   `.records/templates/<doctype>.md`.
7. **Never hand-write `history.tsv`.** File-mode close rewrites `status:` only; ordinary edits
   never stamp generic dates or revisions. After a later journal standup, `.records/records.sh check` will flag a closed record with
   no ledger line. Repair is journal `curate`: rewrite `status:` back to `draft`, then
   `.records/records.sh done`. `.records/records.sh done` refuses an already-archived status — that is why
   the writer must not pretend file-mode close is a ledger close.
8. **Pack installation is not project policy.** A pack lock records installed
   content, not whether a project has opted into a workflow. Writers never gate
   record creation, destination resolution, or permission to act on a pack
   marker. Do not create doctrine or invoke a pack lifecycle as a side effect.

The **project-templates** resolution, per declared project template `<file>` (the verb
resolves the records home and the templates home and passes them in; the mint script
never opens the front door):

1. `.agents/skilldata/<skill>/templates/<file>` present → validate and use it (incumbent; never overwrite).
2. Else, if a recognized legacy template exists at
   `.records/templates/<skill>/<file>` or an explicitly registered flat legacy path,
   refuse ordinary minting and name `/<skill> migrate <legacy-path>`. Reading never copies,
   adopts, or ignores a legacy customization.
3. Else read and use the bundled template without writing to the project. A package-only template
   never enters this ladder.

Deployment is intentional: only `/<skill> setup` copies a declared project template to its
canonical skilldata path. Setup inventories the complete owned write set before creating anything,
then rechecks every existing parent immediately before each write. Unsafe or incompatible entries
refuse that write. If a later recheck fails after earlier safe writes, setup reports both the
completed paths and the refusal; a rerun preserves those incumbents and finishes the remainder.
Project-editable templates, hooks, doctrine, operations, tracker data, and undelimited README prose
are absent-only. A layer owner may append and refresh one explicitly delimited, package-managed
README block while preserving content outside it; malformed or duplicate delimiters refuse.
Only package-managed executable tools that already define refresh semantics may be replaced or,
when their canonical path changes, removed after the replacement is safely installed.

Each owner keeps its established reporting vocabulary. Standalone setup makes one pathspec-scoped
commit containing exactly its reported writes and makes no commit on a no-op rerun. When the caller
announces a larger configuration sweep, setup is write-only and the caller may make one aggregate
commit over the approved destinations. A deployable asset with no live reader is not deployed.

The owning skill's explicit `migrate` verb moves recognized active templates into the canonical
home, strips retired record-shell front matter, and handles collisions conservatively. Schemas,
validators, and migration chains always remain inside the package; projects cannot customize them.

Package-only templates skip this resolver. They are read from the skill's own
`templates/` and are never copied into the project.

## Doctrine-touching skills

A skill that reads **or writes** project doctrine follows these rules. Portable — any skills
library. Reading counts: you must resolve a path to read from it, so a reader that hardcodes a
doctrine path is exactly as wrong as a writer that does.

1. **Which home.** Seven destinations, one test:

   > **Records** are dated, typed, closeable instances → `.records`.
   > **Templates** are project-editable authoring scaffolds actively read by their owner →
   > `.agents/skilldata/<skill>/templates/`.
   > **Doctrine** is living, normative, undated, and never closes →
   > `.agents/skilldata/<skill>/doctrine/`.
   > **Drafts** are living, opt-in incubation files, not records →
   > `.agents/skilldata/<skill>/drafts/`.
   > **Hooks** are seam overlays on a skill's own loop →
   > `.agents/skilldata/<skill>/hooks/<seam>.md`.
   > **Trackers** are public durable queues and their shared provider → `.trackers`.
   > **Inspector kinds** are undated judgment templates
   > (not mint shells, not records, not the audit rubric)
   > → `.agents/skilldata/inspector/doctrine/<kind>.md`.

   Doctrine: an audit rubric, a station chapter. Not
   doctrine: a spec (a dated `specs/` record), a captured project fact, an audit *report*,
   a host operation under `.agents/skilldata/<skill>/operations/`. The auditor rubric at
   `auditor/doctrine/test/workflows/audit/` remains doctrine (a parked nested tree). Host
   procedures are skilldata-resident files copied by their owner skill — not an eighth
   landing class. An owner may add other children under its skilldata folder; those
   names are not a closed enum.

   **The test classifies where a thing LANDS, not where it ships from.** A skill's own
   bundled `templates/`- or seed-style content is package-only until deployed; the same bytes
   are package content in the skill and host doctrine once copied. Classify the destination.

2. **Two-level access.** Resolving the home is not finding the artifact. Resolve the home,
   *then* test for the specific file. Present → use it; absent → **degrade exactly as the
   skill degrades with no doctrine at all**. Never treat home-exists as artifact-exists: a
   doctrine home containing no chapters must make a consumer fall back, not fail.

3. **Standup — explicit, narrow, and incumbent wins.** Normal reads never
   create directories. An explicit setup/deploy verb may create its declared
   owner-local skilldata tree when absent, then only
   `.agents/skilldata/<its-own-name>/...` for children it owns. It must not create,
   inspect as configuration, or interpret another owner namespace. Before each
   creation, recheck every existing parent: a symlink or non-directory parent
   is unsafe. Preflight the complete write set before creating anything; if a later immediate
   recheck fails after safe earlier writes, report the partial result and stop so a rerun can
   preserve those incumbents and finish deterministically.

   **Records-layer owner exception.** A records-format steward may create a
   declared records home because standing up that distinct layer is its explicit
   job. No skill assembles or validates the whole skilldata tree; there is no pack-level
   exception.

   **Tracker-layer owner exception.** Backlog may create the declared trackers home because
   standing up that distinct public data layer and its provider is its explicit job. Other skills
   consume the provider; they do not seed or reinterpret the layer.

   **Independent seeding.** A skill copies only the skilldata files it owns
   (`operations/` / `hooks/` / `templates/` beneath its namespace, as applicable), including the
   complete schema on any operation it copies; incumbent wins. A cross-owner finder over
   `operations/` is not a seeder of pack or sibling payload. Minting a
   host-authored stub is not seeding.

   **Owner-local creation.** A publisher creates only the children needed by the
   authorized operation. A hooks publisher creates its own `hooks/`; an operation
   publisher creates its own `operations/`; an Inspector setup creates
   `inspector/doctrine/`. None may populate another owner's namespace.

   Doctrine is **copy-bundled-then-customized**, not mint-and-accumulate: a skill seeds
   generic content, then the host edits it in place and keeps editing it for years. So
   doctrine standup follows the **project-templates** semantics — *if present → use it, never
   overwrite* — not the records semantics. **A re-run must never clobber host
   customizations.** This is the rule that actually matters for doctrine; get it wrong and a
   second `setup` silently destroys accumulated project judgment.

4. **No floor.** A missing tool is never an error. No other skill's standup is a
   precondition. A description must not claim a deployed layer is required, and a verb must
   not refuse and send the operator away to stand one up.

5. **Name the fixed home.** A doctrine producer or consumer names its literal owner-local path,
   `.agents/skilldata/<skill>/doctrine/`, in operative prose. The mechanical gate checks for `.agents/skilldata`; skill
   review confirms that the procedure uses the correct owner namespace and does not accept a
   caller-selected home.

6. **Declare the edge.** `produces: doctrine` / `consumes: doctrine` in the `## Edges` block,
   per the typed-edge mechanics above. **The edge type stays `doctrine` — it does not become
   `skilldata`.** An edge names the *kind of thing* carried, not the home it happens to
   resolve through.

**What the mechanical gate can and cannot prove.** The lint checks omission (an edge declared
with no sanctioned literal) and known-bad literals (an off-home path in prose). It **cannot**
prove that a skill's *procedure* resolves the home — a skill may carry the literal while its
operative steps name a fixed path, and no text match distinguishes that from correct usage.
That question belongs to skill review, as judgment. Claim the floor, not the ceiling: an
absence-shaped check cannot even report a `file:line`, because there is no line where a
missing sentence lives.

## Project hooks

**Hooks** are seam overlays on a skill's own loop at
`.agents/skilldata/<skill>/hooks/<seam>.md`. The `<skill>` stem matches that skill's
frontmatter `name:`; `<seam>` is a safe Markdown filename known by that owner.
Neither is a front-door variable.

A skill that owns a multi-step loop with named seams *may* publish hooks. Not
every skill. The convention does **not** require bundled skeletons. A consumer
may copy its own package skeletons absent-only. Never overwrite a present file,
never create another owner's hook, and never put hook files in templates.
`skill-builder new` does not scaffold a generic hooks file.

Each seam is one file. Format (normative):

```markdown
# <skill> — <seam>

<optional overlay instructions>
```

The consumer reads only canonical filenames it knows. Missing or whitespace-only
files mean skip. It does not glob new runtime behavior into existence.

## Corollaries (four testable rules)

1. **Self-init, no floor.** A durable-home skill can create its own home; it depends on no other
   skill's `setup` having scaffolded it first.
2. **Visibility is explicit.** A selected registration lands in the *always-loaded* front door; a
   skill without one remains discoverable through its routing metadata and self-describing owned
   state. Durable state alone never silently selects the former.
3. **Edges name types, not siblings.** The type namespace is shared; the sibling namespace is
   invisible to a leaf.
4. **Optimization, not dependency.** Bare self-init, plus registration only when declared, is
   complete on its own; a composer/runbook *enriches* (arranges, derives seams, drains accumulation)
   but is never required for a skill to **function**.

### Optional composers call public procedures

An explicitly invoked composer may call another installed skill's public procedure when composition
is the requested job. It may not reproduce that procedure, write the other skill's state, require
the other skill to be installed for its own bare operation, or bypass the called procedure's guards.
The call is an optional runtime edge: absent capability degrades to a returned hand-off, never an
installation floor. Seam ownership and typed-edge rules remain unchanged.

**Name your floor.** Corollary 1 restated as an authoring discipline: when you scaffold a skill,
state explicitly what it depends on to work — ideally *nothing* (no other skill's `setup`, no composer
present). If a real dependency exists, name it as a **typed edge** (`consumes: T`), never as an
assumption baked silently into the skill's own procedure. A writer that needs journal's *tool*
names `consumes: records-tool` only when it *cannot* file-mode; the default is that it can.

## Authoring conventions

- **Self-contained + location-agnostic.** A skill references its own bundled resources
  (`scripts/`, `templates/`, `docs/`, `verbs/`) **relative to its own base directory** — never a
  host-project path — so it works wherever installed.
- **Instruct generically; let the project resolve specifics.** A skill says "run the host's gate /
  fast doc-linter / diagnostics" and relies on the consuming project's front-door doc to resolve that
  to concrete commands. It carries **no** project-specific commands.
- **`SKILL.md` frontmatter must be strict-YAML valid** (some harnesses enforce this): quote any
  `description:` whose value contains `: `; keep it **≤ 1024 characters** (aim ~700); it is a
  **trigger, not a summary** — when to fire + keywords, not a feature inventory (that's the body's
  job).
- **Gate every change:** `scripts/skills-lint.sh` — frontmatter limits, bundled-ref resolution,
  script syntax, cross-skill refs, edge-block well-formedness. Fix every `FAIL:`.
- **Two sizes, not one.** A skill's **surface** is what an agent loads to route and operate
  (`SKILL.md` + verbs). Its **payload** is what it carries to deploy (seed content, scripts,
  templates). Coupling lives in the surface. Splitting by role that only moves payload does
  not shrink what the agent loads, and is not grounded by "this skill feels big." Measure
  both before proposing a split.
- **A slice names every file it breaks.** When sequencing work, a slice's `paths` include
  every file its own change reddens — not only the files it means to edit. An edit surface
  enumerated by intent rather than consequence is how a green-on-its-own slice fails the
  trunk gate.
- **Never restate a sibling's verb set (or any roster) in a skill body.** Point at the
  runbook/ownership index instead — an inlined roster rots silently the day the sibling grows a
  verb, and only *description*-level cross-refs have a lint backstop; body-level re-documentation
  has none, so the discipline is the guard.
- **Prove a new check by breaking it.** A check you just wrote — a test assertion, a lint rule, a
  reference sweep — is not trusted until it has FAILED on deliberately-broken input (plant the ref,
  demand red, then fix the plant). A clean first run proves nothing: the check may be matching
  nothing at all. **A break that silently fails to apply produces the same clean run** — count the
  target occurrences before and after the mutation and fail loudly on zero replacements; restore
  from a backup and confirm byte-identity. Concrete portable-regex trap this rule has caught:
  **never use `\b` in `grep -E`/`git grep -E` patterns meant to be portable** — it is a GNU
  extension; macOS/BSD ERE treats it as matching *nothing*, so the whole alternative silently
  never fires and the sweep reports clean over live refs. Use plain substrings or explicit
  character-class boundaries.

## References

- `docs/BOUNDARY-AUDIT.md` — the independence-auditing workflow (`skill-builder check`).
- `scripts/skills-lint.sh` — the mechanical gate (`skill-builder check`).
- `specs/records-front-matter.md` — record status / stage contract (writer rule 5).
- `verbs/new.md` — scaffolds a skill against this doctrine's tiers.
- `verbs/calibrate.md` — folds accreted authoring decisions back into this doc.
