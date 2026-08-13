# DOCTRINE — building skills for coding agents

The **portable design philosophy** for authoring agent skills — tools, scripts, and the skills
themselves — distilled from practice building this library. It applies to *any* skills library, not
just the one `skill-builder` ships from: install `skill-builder` anywhere and this doc, the lint gate
(`scripts/skills-lint.sh`), and the boundary-audit workflow (`docs/BOUNDARY-AUDIT.md`) travel with it.

A host library imports this doctrine into its own front-door doc (`AGENTS.md`/`CLAUDE.md`) with a
short pointer, then lists only its **local overrides** underneath — the same public-doctrine +
private-override shape a personal dotfiles config uses over a shared one. Apply this doc whenever you
add or revise a skill; `skill-builder calibrate` is what keeps it current as practice evolves.

## Two regimes: pack faces vs. everything else

This doctrine's **independence rules** — self-scoping descriptions, typed edges, the no-sibling-seam
discipline — exist so a skill routes and functions **bare**, with no composition deployed. The one
structural exception is a **pack face**: the skill dir that carries a `PACK.md` manifest (see the
pack-format spec). Composing the pack is the face's *job* — its manifest declares the members and
its prose may name them directly; that is dependency as manifest data, not a boundary leak. So the
split:

- **Every non-face skill** — pack members included, this library's `skill-builder` too — follows the
  **full portable discipline** below: independence rules, typed edges, the lint gate's boundary
  checks. A pack member is standalone by design; membership grants no exemption.
- **Pack faces** are exempt from the lint gate's independence checks (sibling-in-description,
  typed-edge blocks, sibling verb-roster) — the gate discovers faces by the presence of `PACK.md`;
  everything else — frontmatter limits, bundled-ref resolution, script syntax — applies to every
  skill regardless.

Everything below states the **portable** regime; where a rule is independence-flavored, read it as
scoped to non-face skills.

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

- **Harness-agnostic packages; harness-specifics at the edge.** A portable skill/script names only the
  generic concept ("a prefix-matching approval policy"), never a specific agent or harness. The one
  place a harness is named is its own config file (e.g. an approval-rules file), which lives outside
  the portable package.

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

- **Glue is content (the pack's) vs. mechanism (the engine's) — birth vs. growth.** The glue *content*
  — the seams, the initial front-door wiring — is owned by the pack/runbook, which **births** the
  constellation. A workflow-hub skill (this library's `foreman`) is the pack-agnostic **oven**: it
  **stamps** whatever the recipe specifies and **grows** it afterward, but it **never authors** the
  pack-specific glue. Recipe owns *what*; oven owns *how* and *ongoing*.

- **Skills self-initialize and self-describe via typed edges; the composer wires the seams.** The
  tenets above govern what a skill's `description:` may *say*; this one — their extension from
  **routing to initialization** — governs what a skill's `init` may *write* and what its edges may
  *name*. A skill stands up **its own** home and registers **its own** route into the always-loaded
  front-door doc, so the constellation works **bare**, with no composer deployed. What it declares
  about its place in a workflow is a set of **typed edges** (`produces` / `consumes` / `handoff`) keyed
  on artifact/capability **types, never sibling names**; a composer **derives** the cross-skill seams
  by *matching* one skill's edges against another's. A skill that names its successor has authored a
  seam — the co-mingling the tenets above removed, one level up. See *Typed edges* and *Self-init tiers*
  below for the mechanics; **§ Corollaries** for the four testable rules.

## The three layers a skill may self-describe

1. **Typed edges** (`produces`/`consumes`/`handoff`) — the mechanical wiring points. **Required of
   every portable skill** (an all-empty block is a *stated* fact, "I'm a pure mechanism," not an
   omission; pack faces carry none — § Two regimes).
2. **Ideal-use examples** — self-contained *"how to use me"* route/workflow a composer or role skill
   can ingest to understand usage. **Enrichment.**
3. **Deployable seed** — project-customizable assets (e.g. a `templates/` home) plus an authoring
   verb. **Enrichment.**

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

Only the **durable-home** tier gets a real `init` verb (home-scaffold + front-door registration, per
*Typed edges & registration* below). The other three declare their tier honestly in their `## Edges`
block and skip the ceremony — "no home" and "all-`—` edges" are legitimate, recorded dispositions, not
gaps to fill in later.

**Registration tracks captured items / durable routes, not mere existence.** Register the durable-home
+ steward skills — the payoff (visibility without a composer) is real only where the skill has
something durable to surface. Make it **optional** for scratch-only skills and **skip it** for
pure-mechanism plumbing: registering a transport with no captured items would only bloat the
front-door section this doctrine fights to keep lean.

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

The composer's matching rule: `handoff: T` on A + `consumes: T` on B → a **seam** (control flows A→B).
`produces: T` on A + `consumes: T` on B → a **dependency** (B reads A's output, no implied control).
Unmatched edges are legal — a producer with no consumer is a leaf output; a consumer with no producer
takes its input from outside the skill set. **A and B never name each other** — the composer supplies
both names by matching on `T`. Types are **plain strings, matched by equality, open** (no registry to
import) — prefer coarse, shared types (`plan`, not `feature-plan-v2`) over a precise-but-lonely one
per skill.

**Registration** (durable-home/steward tier only) idempotently projects a route into the host's
always-loaded front-door doc, inside a `## Skill routes (self-registered)` section:

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
doc. Exercise `init`/registration against a throwaway fixture instead. The library that teaches the
mechanism is not thereby a self-registering deployment of it.

## Front-door variables — one declaration, two readers

Some values genuinely vary per host project. The canonical example is the **records root** — the
directory typed records live under, default `.records/`: right for every fresh project, but a
brownfield host may have years of history under another name. Hardcoding such a value everywhere
turns the default into a constant; a **front-door variable** keeps it *a pointer with a safe
default*.

A front-door variable is **one line in the host project's front-door doc** (`AGENTS.md`, or
`CLAUDE.md` where that is the front-door), at line start, kebab-case name:

    records-root: dev

One declaration mechanism serves both kinds of reader, with the same precedence rule (declared
value if present, else the default):

- **Agents** need no mechanism at all: the front-door is always loaded, and front-door
  instructions outrank skill defaults. Skill prose therefore keeps naming the default literally
  (`.records/plans/…`, never `$RECORDS_ROOT/plans/…`) — an agent substitutes the declared root
  when its front-door carries one. Zero rewording, zero indirection for the common case.
- **Scripts** resolve it mechanically: scan the front-door docs for the first `^<name>:` match;
  absent → the default. Each consuming script **inlines** the canonical resolver below
  (self-contained packages — never source it from a sibling skill) and prints the resolved value
  as a fact (`records-root=…`), so the agent sees which root the run used.

The canonical resolver (bash-3.2 safe; adapt the variable name):

    # Front-door variable `records-root` (default `.records`) -- see the
    # front-door-variables doctrine. Prints the resolved repo-relative path.
    resolve_records_root() {
      local root="$1" fd decl=""
      for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
        if [ -z "$decl" ] && [ -f "$fd" ]; then
          decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
                  | sed 's/[[:space:]]*$//')"
        fi
      done
      printf '%s\n' "${decl:-.records}"
    }

Rules of the road: **declare once** — first match wins; when *documenting* a variable (this doc,
skill prose) keep the literal off line start or inside indented code, so documentation never
parses as declaration; the value is a repo-relative path (or plain token), never absolute. And
the **bar for adding one is high** — *prefer the simplest portable rule over a configurable one*
still governs. A variable is justified only when the value truly varies per host (usually
brownfield reality), the default is right for every fresh project (nobody *must* set it), and
both readers consume it. A skills library that authors this doctrine never declares variables in
its own front-door (patient-zero, as with registration above).

## Corollaries (four testable rules)

1. **Self-init, no floor.** A durable-home skill can create its own home; it depends on no other
   skill's `init` having scaffolded it first.
2. **Visibility by construction.** Registration lands in the *always-loaded* front-door, so a bare
   reader sees the route (and captured items) without a composer reading the skill.
3. **Edges name types, not siblings.** The type namespace is shared; the sibling namespace is
   invisible to a leaf.
4. **Optimization, not dependency.** The bare self-init + registration experience is complete on its
   own; a composer/runbook *enriches* (arranges, derives seams, drains accumulation) but is never
   required for a skill to **function**.

**Name your floor.** Corollary 1 restated as an authoring discipline: when you scaffold a skill,
state explicitly what it depends on to work — ideally *nothing* (no other skill's `init`, no composer
present). If a real dependency exists, name it as a **typed edge** (`consumes: T`), never as an
assumption baked silently into the skill's own procedure.

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

## References

- `docs/BOUNDARY-AUDIT.md` — the independence-auditing workflow (`skill-builder check`).
- `scripts/skills-lint.sh` — the mechanical gate (`skill-builder check`).
- `verbs/new.md` — scaffolds a skill against this doctrine's tiers.
- `verbs/calibrate.md` — folds accreted authoring decisions back into this doc.
