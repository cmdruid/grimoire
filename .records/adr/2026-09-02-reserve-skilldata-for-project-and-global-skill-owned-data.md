---
doctype: adr
status: published
schema: architect/adr@1
tags: [storage, skilldata, paths]
---

# Reserve skilldata for project and global skill-owned data

- **Deciders:** Project owner, 2026-09-02
- **Related:** → `specs/2026-09-02-skilldata-hard-cut-and-workspace-retirement.md`;
  → `specs/2026-09-02-foreman-first-use-and-global-operation-templates.md`;
  → `specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md`;
  → `specs/2026-08-25-agent-workspace-naming.md`;
  → `specs/2026-08-30-canonical-fixed-project-homes-and-records-root-migration.md`;
  → `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`

## Context

Skills need a legible home for support data that belongs neither in typed records nor in public
trackers. Grimoire currently uses the top-level `.spaces/<skill>/<kind>/...` tree for project-owned
support. That name hides both the agent-facing nature of the data and its owner boundary, while the
standalone Workspace skill turns a simple path convention into another project operation. The
widely recognized `.agents/` scope is a clearer place to reserve an explicit, verbose child without
mixing mutable data into `.agents/skills/`, where installed package bytes may be replaced or
symlinked to a source checkout.

Some globally installed skills also need durable user-owned data that spans projects. Project
`.records`, project `.agents/skilldata`, and `.trackers` are unsuitable when the subject is the
installed skill itself rather than one consuming project. A single name at both scopes makes the
relationship visible while preserving separate ownership and lifecycle.

The user-level `~/.agents/` directory already separates agent instructions and installed skills, but
it has no reserved location for global skill-owned data. A generic `~/.agents/data/` root would
invite unrelated agent applications and tools to assign it incompatible ownership or layout rules.
Giving every skill a new top-level `~/.agents/<skill>/` directory avoids the shared-root question but
makes it harder to distinguish durable skill state from instructions, audits, documentation, and
other user workbench content.

## Decision

1. **D1 — Reserve project `.agents/skilldata/` for owner-first skill support.** Project-owned
   support uses `.agents/skilldata/<skill-name>/<kind>/...`. Owner names match `[a-z0-9-]+` and are
   open-ended. Project kinds remain the closed set `doctrine`, `drafts`, `hooks`, `operations`,
   `scripts`, and `templates`. `.agents/skills/` remains package installation space and is never a
   project support-data home.
2. **D2 — Reserve global `~/.agents/skilldata/` for justified user-owned skill data.** A globally
   installed skill that truly needs cross-project state uses
   `~/.agents/skilldata/<skill-name>/`, with the same installation slug. Global storage is opt-in
   per skill, not implied by project storage. Its internal layout is owner-defined rather than
   constrained to the project kind set.
3. **D3 — Ownership begins below each shared root.** A skill may create the relevant shared
   directory and its own child, but owns and mutates only that child. At project scope, an explicit
   cross-owner consumer may read only its declared artifact kind; it cannot mutate sibling owners or
   validate the whole root. At global scope, a skill must not enumerate, validate, repair, migrate,
   or delete sibling children. Neither root has a shared manifest, version, provider, README
   contract, or lifecycle.
4. **D4 — Keep both paths fixed and scope-sensitive.** Project data is constructed from the resolved
   project root. Global data is constructed from the current user's resolved home. Production code
   accepts no alternate-root selector. A skill does not fall back between scopes or make global
   content project authority unless that skill explicitly defines a reviewed materialization step.
   Tests isolate roots at the process boundary rather than widening the production interface.
5. **D5 — Each owner defines the artifact contract and custody.** File schemas, permissions,
   providers, setup, repair, retention, and lifecycle remain the owning skill's responsibility.
   A project actor validates only the path it is about to own or explicitly consume; no successor central
   workspace validator is introduced. Global data needs a separate design justification, and a
   project may override global input only under the owning skill's declared precedence rule.
6. **D6 — Do not confuse global skill state with Grimoire package-manager state.** Source caches,
   trust, desired installations, locks, and package-manager transactions remain under the separate
   Grimoire home specified by the package manager. `skilldata/` contains runtime data owned by the
   installed skills themselves, not distribution state.
7. **D7 — Scope disambiguates ordinary artifact names.** A global skill-owned artifact need not force
   project-owned queues or records with the same ordinary noun to rename. In particular, global
   `skill-feedback` and a project's `feedback` tracker remain distinct because their owners, roots,
   subjects, and lifecycles differ. Their classifiers state where the remedy belongs; no forwarding,
   shared schema, or globally unique artifact vocabulary is introduced.
8. **D8 — Hard-cut the retired project spelling.** `.spaces/` receives no compatibility reader,
   selector, alias, migration command, or cleanup automation. Live skill prose and implementations
   use `.agents/skilldata/`; historical records may retain `.spaces` as evidence, and rejection
   fixtures may name it only to prove the old path is not accepted. Skill-builder's bounded
   retirement doctrine and the lint implementation may also name the token solely to define and
   enforce its rejection; they never resolve, read, write, migrate, or emit that path. This decision supersedes the
   project-root name, Workspace-skill, and workspace-selection requirements in
   → `specs/2026-08-25-agent-workspace-naming.md`, plus the `.spaces` parts of D1, D2, D4, and D6
   in → `adr/2026-08-30-fix-project-owned-homes-at-canonical-roots.md`. Their `.records`,
   `.trackers`, and unrelated provider decisions remain authoritative; their rationale for
   `.spaces` remains historical evidence rather than current direction.

## Alternatives considered

- **Keep project `.spaces/` and reserve `skilldata` only globally.** This minimizes churn but leaves
  two names for the same owner boundary and keeps project data in an opaque top-level namespace.
- **Repurpose Workspace as the `skilldata` validator.** This preserves a familiar command, but a
  shared validator would still inspect sibling owners and make a directory convention depend on a
  separately installed skill. Package-time lint and owner-local runtime checks are the narrower
  boundaries.
- **Use `.agents/data/<skill>/` and `~/.agents/data/<skill>/`.** Owner-naming below the root helps,
  but `data` is too generic to reserve confidently inside a workbench shared with harnesses and
  unrelated agent tools.
- **`~/.agents/skills/<skill>/data/`.** Co-locates package and state, but package replacement,
  read-only snapshots, and source-tree symlinks make that state unsafe and non-durable.
- **`~/.agents/<skill>/`.** Gives each skill an obvious owner-local home, but consumes the common
  top-level namespace and makes skill runtime state visually indistinguishable from user-authored
  agent configuration and documents.
- **The XDG state directory.** It is a sound platform convention, but this library's global
  installation and instruction surfaces already meet under `~/.agents/`. Splitting installed-skill
  data into another root would make discovery and backup less legible, especially on systems where
  XDG variables are absent.
- **A shared state manifest or provider.** Could validate every child centrally, but would make
  independent skills depend on a coordinator and couple unrelated schemas and migrations. The
  owner-first directory boundary provides collision avoidance without shared machinery.
- **Dual-read or automatic migration from `.spaces`.** Would soften the cut, but every reader would
  inherit precedence, collision, and eventual-removal logic. Existing project paths are deliberately
  left for their owners to clean up.

## Consequences

Project support becomes visibly agent-owned and remains owner-first. Global durable-home skills gain
a predictable location that survives package updates, cannot accidentally write through an
installation symlink, and remains distinct from generic user workbench data. Backups and privacy
reviews can include or exclude one namespace, while each skill retains complete ownership of its
own schema and lifecycle.

The shared root is intentionally weak: no central tool can infer that every child is valid, current,
private, or safe to remove. Colliding installed skill names also collide in `skilldata/`; that is
consistent with the installation namespace and must be resolved there rather than by inventing a
second alias system for state. Uninstalling a skill leaves its data intact unless the user explicitly
requests removal under a separately designed lifecycle.

Project tracker stems remain stable when a global skill uses related terminology. This avoids
migrations whose only purpose is lexical uniqueness, but it makes the subject boundary load-bearing:
project feedback is about remedies owned by the project, while global skill feedback is about
remedies owned by the reusable installed package.

The hard cut requires coordinated edits across current skill prose, scripts, tests, README and pack
inventory, and `skill-builder` doctrine and lint. It deliberately provides no automated cleanup of
existing `.spaces` trees. Removing Workspace also removes the single command that reported every
invalid sibling owner at once; each owner now checks its own custody at a read or write boundary,
while `skill-builder` prevents authors from publishing new path violations.

Portable skill-authoring doctrine must now teach both scopes. It requires project support to use the
closed owner/kind grammar, permits global state only when separately justified, and prevents global
content from silently becoming project instruction. No skill is required to adopt global storage
merely because the namespace exists.
