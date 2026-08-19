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

Some values genuinely vary per host project. The canonical example is the **agent-records
home** — the directory typed records live under, default `.records/`: right for every fresh
project, but a brownfield host may have years of history under another name. Hardcoding such a
value everywhere turns the default into a constant; a **front-door variable** keeps it *a
pointer with a safe default*.

A front-door variable is **one line in the host project's front-door doc** (`AGENTS.md`, or
`CLAUDE.md` where that is the front-door), at line start, kebab-case name:

    agent-records: dev

The records home also accepts the legacy synonym `records-root:` — first match of either name
wins (`AGENTS.md` then `CLAUDE.md`). Beside it sits one sibling defaulting *under* the resolved
records home, so **one `agent-records:` line moves both**:

- the **agent-templates home** (schema, not instances) defaults to
  `<resolved-agent-records>/templates`.

Declare it only as an override:

    agent-templates: schemas

A third variable stands on its own root rather than under the records home:

    agent-workspace: .dev

The **agent-workspace home** is where a project's development environment lives — today its
doctrine (living normative prose — see *Doctrine-touching skills* below), at the fixed subpath
`<agent-workspace>/doctrine`. Default `.dev`. Declare it only as an override; there is **no**
legacy synonym, because the variable is new and has no prior declarations to honor. A declared
value of `.` is forbidden — it would place doctrine at `./doctrine`, colliding with real project
directories.

**The doctrine home is a fixed subpath, not a variable of its own.** It was one — retired into
`<agent-workspace>/doctrine` because it had no demonstrated variance case, and because
defaulting it *inside* the records home forced that layer to disown a subdirectory it did not
own. A host that wants its development environment somewhere else moves the whole workspace in
one line.

**`agent-workspace` does not echo `.dev`, and that is deliberate — do not "fix" it.**
`agent-records` → `.records` echoes; this pair does not. The **variable** names the concept
precisely, for the prose that has to explain what the home is *for*; the **directory** stays
short and legible for a literal that appears at depth —
`.dev/doctrine/test/workflows/audit/GUIDE.md` reads where
`.workspace/doctrine/test/workflows/audit/GUIDE.md` stutters against `workflows/`. The
consistency cost is small because the rule just below requires default paths written literally,
so the mapping is stated wherever it is used and learned once.

Skill prose keeps naming each default path literally (`.records/plans/…`,
`.records/templates/backlog/…`, `.dev/doctrine/test/workflows/audit/…`) — never
`$RECORDS_ROOT/plans/…`.

**A note on `agent-workspace`'s justification, so a later reader can re-weigh it.** The bar
below demands the value *truly vary per host*. For `agent-records` that was established
brownfield reality. For `agent-workspace` it is **not** an evidence claim, and should not be
dressed as one: the single live variance case — a legacy host whose records already sit at
`dev/`, declaring `agent-workspace: dev` so the two homes keep coinciding — exists *because*
this doctrine chose `.dev` as the default. A variance case a design manufactures is migration
friction, not demonstrated host variance. The variable is carried on **architecture** instead:
the front door should express where the development environment lives as one declaration, and a
host that wants it elsewhere should not have to fork the library. That is a design position,
held openly. The other two legs — a default right for every fresh project, and readers that
consume it — hold today.

One declaration mechanism, same precedence (declared value if present, else the default).
Three readers:

- **Agents** need no mechanism at all: the front-door is always loaded, and front-door
  instructions outrank skill defaults. An agent substitutes the declared home when the
  front-door carries one. Zero rewording, zero indirection for the common case.
- **Mint/write scripts** take the resolved paths as arguments and **do not scan the front
  door**. The verb resolves; the script never opens `AGENTS.md` / `CLAUDE.md`.
- **State-analysis helpers** that must emit `agent-records=` without a verb (today
  `workstream-git.sh`) inline the resolver and accept both records-declaration names.
  Print the resolved value as a fact (`agent-records=…`) so the agent sees which home
  the run used. Existing `records-root=` fact keys stay until that script is edited.

The canonical records resolver (bash-3.2 safe; both declaration names):

    # Front-door variable `agent-records` (default `.records`; also accepts
    # legacy `records-root:`) -- see the front-door-variables doctrine.
    # Prints the resolved repo-relative path.
    resolve_agent_records() {
      local root="$1" fd decl=""
      for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
        if [ -z "$decl" ] && [ -f "$fd" ]; then
          decl="$(sed -n -E 's/^(agent-records|records-root):[[:space:]]*//p' "$fd" \
                  | head -n 1 | sed 's/[[:space:]]*$//')"
        fi
      done
      printf '%s\n' "${decl:-.records}"
    }

The **agent-templates** home resolves the same way, falling back *through* it (same precedence,
same front-door order, bash-3.2 safe):

    # Front-door variable `agent-templates` (default `<agent-records>/templates`).
    resolve_agent_templates() {
      local root="$1" fd decl=""
      for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
        if [ -z "$decl" ] && [ -f "$fd" ]; then
          decl="$(sed -n -E 's/^agent-templates:[[:space:]]*//p' "$fd" \
                  | head -n 1 | sed 's/[[:space:]]*$//')"
        fi
      done
      printf '%s\n' "${decl:-$(resolve_agent_records "$root")/templates}"
    }

The **agent-workspace** home uses the same mechanism but a **flat default** — it does not fall
back through another home, and it accepts only its own name:

    # Front-door variable `agent-workspace` (default `.dev`). The doctrine home is
    # the fixed subpath `<agent-workspace>/doctrine`.
    resolve_agent_workspace() {
      local root="$1" fd decl=""
      for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
        if [ -z "$decl" ] && [ -f "$fd" ]; then
          decl="$(sed -n -E 's/^agent-workspace:[[:space:]]*//p' "$fd" \
                  | head -n 1 | sed 's/[[:space:]]*$//')"
        fi
      done
      printf '%s\n' "${decl:-.dev}"
    }

Rules of the road: **declare once** — first match wins; when *documenting* a variable (this doc,
skill prose) keep the literal off line start or inside indented code, so documentation never
parses as declaration; the value is a repo-relative path (or plain token), never absolute. And
the **bar for adding one is high** — *prefer the simplest portable rule over a configurable one*
still governs. A variable is justified only when the value truly varies per host (usually
brownfield reality), the default is right for every fresh project (nobody *must* set it), and
the readers consume it. A skills library that authors this doctrine never declares variables in
its own front-door (patient-zero, as with registration above).

## Record-writing skills

A skill that mints a typed record follows these rules. Portable — any skills library, not just
this pack. `skill-builder new` scaffolds them; `check` and `review` enforce them.

1. **Destination.** A typed record is written under the agent-records home (resolver above).
   Skill prose keeps naming the default path literally. Mint/write scripts take resolved
   paths as arguments and do not scan the front door. State-analysis helpers that must emit
   `agent-records=` without a verb inline the resolver and accept both declaration names.
2. **Carry your templates; declare the lock-in set.** A skill that mints store `D` ships
   a doctype template named `D.md` (five keys + `<title>` / `<date>`). Body scaffolds may
   also live under `templates/`. A `## Project templates` list in `SKILL.md` names every
   bundled file that is project-lock-in (copied to the agent-templates home). Files not
   on the list are package-only. The review brief flags: a writer whose store has no
   in-package doctype template; a list entry with no bundled file; a copy of a file the
   list does not name.
3. **Own-store standup.** On first write, `mkdir` that skill's store (and the agent-records
   home directory if needed). Do not create a deployed `records.sh`, `history.tsv`, other
   stores, the records README, or the *flat* `<agent-records>/templates/<doctype>.md`.
   Creating `<agent-records>/templates/<skill>/` on first lock-in copy is required.
4. **No floor.** Missing `records.sh` is not an error. Journal standup is never a
   precondition. A description must not say the skill requires a stood-up records layer.
   A verb must not refuse and send the operator to journal standup.
5. **In-package contract.** The writer states the five keys (`doctype`, `status`, `created`,
   `updated`, `tags`), the status vocabulary (`open` | `current` live; `done` | `dropped` |
   `superseded` | `consumed` closed), the dated slug (`YYYY-MM-DD-<slug>.md`), and the
   record-link form (`→ <store>/<file>.md`) in *its own* package. It does not send the
   agent to another skill's `SKILL.md` for those bytes. Pack composition (the face /
   runbook) still names journal as the format authority; leaves do not.
6. **Opportunistic `records.sh`.** If `<agent-records>/scripts/records.sh` is executable, use
   `new --template <resolved>` / `touch` / `done` / `list`. Otherwise write the same contract
   shape from the resolved template. Resolution is the agent-templates rule (incumbent
   skill-namespaced file, then legacy flat adopt for store-named lock-ins, else the
   bundled copy). Never write a second copy at the *flat*
   `<agent-records>/templates/<doctype>.md`.
7. **Never hand-write `history.tsv`.** File-mode close rewrites `status:` (and `updated:`)
   only. After a later journal standup, `records.sh check` will flag a closed record with
   no ledger line. Repair is journal `curate`: rewrite `status:` back to `open`, then
   `records.sh done`. `records.sh done` refuses an already-closing status — that is why
   the writer must not pretend file-mode close is a ledger close.
8. **Workshop stamp is orthogonal — and no longer picks any home.** The probe
   (`Seeded from clankshop` in `<agent-workspace>/doctrine/README.md`, default
   `.dev/doctrine/README.md`) answers one question: *is a workshop assembled here?* That is
   a **policy** question — may this project's workshop-specific lanes run — not a location
   one. Station context, playbooks, and lanes are doctrine and resolve through
   `<agent-workspace>/doctrine`; records resolve through `<agent-records>`. The stamp picks
   **neither**, and does not decide whether a record is minted. Do not create the doctrine
   home as a side effect of anything. Do not run a workshop onramp as a side effect.

   **The probe now costs a resolution first.** Because the stamp lives inside the workspace,
   a prober must resolve `<agent-workspace>` before it can locate the file — so what this
   rule calls a simple probe is a resolve-then-test, the same shape as rule 2's two-level
   access. That does not convert it into a location question: the resolution buys you the
   path, not the answer.

   **The stamp still has legitimate consumers — do not "finish the migration" by deleting
   them.** A skill may keep probing it for a genuine *policy* decision, and two do today:
   `debugger` gates entering its fix phase on it (may fixes land on a project that has not
   opted into a workshop?), and `workstream` gates `<debrief>` routing and Backlog
   tracker-line permission on it. Neither is a leftover. The test when you meet a stamp
   probe: **if removing it would change *where a file is read from*, it is a location
   question and belongs to a home resolver; if it would change *whether an action is
   allowed*, it is a policy question and the stamp is correct.** Conflating the two is the
   defect this rule was written after, and the tempting cleanup is to conflate them again in
   the other direction.

The **agent-templates** resolution, per declared project template `<file>` (the verb
resolves both homes and passes them in; the mint script never opens the front door):

1. `<agent-templates>/<skill>/<file>` if present → use it (incumbent; never overwrite).
2. Else, **only for store-named lock-ins** (the filename stem *is* the store: `notes.md`,
   `bugs.md`, `tickets.md`, `trackers.md`, `plans.md`, `specs.md`, `adr.md`,
   `reports.md` — the *conventional* set, not an enforced taxonomy: `records.sh` owns no
   directory names, so a project may mint any store its writers need): if
   `<agent-records>/templates/<doctype>.md` is present (legacy flat) →
   copy that file to `<agent-templates>/<skill>/<file>`, then use the new path. Do not
   delete the old file. Body scaffolds skip this step.
3. Else copy the bundled `templates/<file>` to `<agent-templates>/<skill>/<file>`, then
   use it.

Package-only templates skip this resolver. They are read from the skill's own
`templates/` and are never copied into the project.

## Doctrine-touching skills

A skill that reads **or writes** project doctrine follows these rules. Portable — any skills
library. Reading counts: you must resolve a path to read from it, so a reader that hardcodes a
doctrine path is exactly as wrong as a writer that does.

1. **Which home.** Three destinations, one test:

   > **Records** are dated, typed, closeable instances → `<agent-records>`.
   > **Templates** are the schemas instances mint from → `<agent-templates>`.
   > **Doctrine** is living, normative, undated, and never closes →
   > `<agent-workspace>/doctrine`.

   Doctrine: an audit rubric, a diagnostics playbook, a build lane, a station chapter. Not
   doctrine: a spec (a dated `specs/` record), a captured project fact, an audit *report*.

   **The test classifies where a thing LANDS, not where it ships from.** A skill's own
   bundled `templates/`- or seed-style content is package-only until deployed; the same bytes
   are package content in the skill and host doctrine once copied. Classify the destination.

2. **Two-level access.** Resolving the home is not finding the artifact. Resolve the home,
   *then* test for the specific file. Present → use it; absent → **degrade exactly as the
   skill degrades with no doctrine at all**. Never treat home-exists as artifact-exists: a
   doctrine home containing no chapters must make a consumer fall back, not fail.

3. **Standup — the derived default only, and incumbent wins.** On first write a skill may
   `mkdir` its own subdirectory, and the home itself **only when the home is the derived
   default**. Never create an *explicitly declared* home that is absent — that declaration
   names territory the project has assigned to something else, and materializing it is how a
   skill ends up fabricating another tool's layout. An absent declared home degrades per rule
   2.

   **Owner exception — the skill that assembles a home may create it even when declared.**
   `clankshop` assembles the workspace; `journal` assembles the records layer. For those two,
   building the home *is* the job, and a host that writes `agent-workspace: .workspace` is
   asking for it to be built there — not warning the assembler off. **Every other skill
   resolves, tests, and degrades per rule 2 — never `mkdir`.** Without this exception the
   paragraph above reads as a universal prohibition that would forbid `clankshop setup` from
   seeding into a declared home at all, and would forbid what records standup already does
   today.

   Doctrine is **copy-bundled-then-customized**, not mint-and-accumulate: a skill seeds
   generic content, then the host edits it in place and keeps editing it for years. So
   doctrine standup follows the **agent-templates** semantics — *if present → use it, never
   overwrite* — not the records semantics. **A re-run must never clobber host
   customizations.** This is the rule that actually matters for doctrine; get it wrong and a
   second `setup` silently destroys accumulated project judgment.

4. **No floor.** A missing tool is never an error. No other skill's standup is a
   precondition. A description must not claim a deployed layer is required, and a verb must
   not refuse and send the operator away to stand one up.

5. **Use a sanctioned resolution literal.** Each home has a **small fixed set** of accepted
   phrasings; a conforming skill contains a member verbatim. For home `H` (one of
   `agent-records`, `agent-templates`, `agent-workspace`), the set is:

       <H>                 <- the angle-bracket path form; PREFER THIS
       the H home
       declared `H:`

   **Prefer the angle-bracket form.** It is a single token, so it cannot straddle a line
   wrap — and these documents wrap near 95 columns, so a multi-word literal frequently
   breaks across lines. A checker matching the phrase members **must normalize whitespace
   across newlines first**, or it will FAIL conforming skills purely on where their text
   happened to wrap. That failure mode is not hypothetical: a live skill writes "the" at the
   end of one line and "agent-records home." at the start of the next.

   **Why a set and not one blessed sentence.** All three members were derived from what
   conforming skills already say, not invented. One writes "under the agent-records home
   (first `agent-records:` or `records-root:` in `AGENTS.md` then `CLAUDE.md`, else
   `.records/`)"; another writes "declared `agent-records:` or `records-root:` (front-door
   `AGENTS.md`), else `.records/`"; several write only `<agent-records>/specs/`. All
   resolve correctly. A single blessed sentence would fail most of them, and no one sentence
   fits a setup walk, a probe section, and a host-layout table without contortion. The set is
   greppable and bounded; adding a member is a deliberate edit *here*, never a free-form
   reword at the call site.

6. **Declare the edge.** `produces: doctrine` / `consumes: doctrine` in the `## Edges` block,
   per the typed-edge mechanics above. **The edge type stays `doctrine` — it does not become
   `workspace`.** An edge names the *kind of thing* carried, not the home it happens to
   resolve through.

**What the mechanical gate can and cannot prove.** The lint checks omission (an edge declared
with no sanctioned literal) and known-bad literals (an off-home path in prose). It **cannot**
prove that a skill's *procedure* resolves the home — a skill may carry the literal while its
operative steps name a fixed path, and no text match distinguishes that from correct usage.
That question belongs to skill review, as judgment. Claim the floor, not the ceiling: an
absence-shaped check cannot even report a `file:line`, because there is no line where a
missing sentence lives.

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
- **Never restate a sibling's verb set (or any roster) in a skill body.** Point at the
  runbook/ownership index instead — an inlined roster rots silently the day the sibling grows a
  verb, and only *description*-level cross-refs have a lint backstop; body-level re-documentation
  has none, so the discipline is the guard.
- **Prove a new check by breaking it.** A check you just wrote — a test assertion, a lint rule, a
  reference sweep — is not trusted until it has FAILED on deliberately-broken input (plant the ref,
  demand red, then fix the plant). A clean first run proves nothing: the check may be matching
  nothing at all. Concrete portable-regex trap this rule has caught: **never use `\b` in
  `grep -E`/`git grep -E` patterns meant to be portable** — it is a GNU extension; macOS/BSD ERE
  treats it as matching *nothing*, so the whole alternative silently never fires and the sweep
  reports clean over live refs. Use plain substrings or explicit character-class boundaries.

## References

- `docs/BOUNDARY-AUDIT.md` — the independence-auditing workflow (`skill-builder check`).
- `scripts/skills-lint.sh` — the mechanical gate (`skill-builder check`).
- `verbs/new.md` — scaffolds a skill against this doctrine's tiers.
- `verbs/calibrate.md` — folds accreted authoring decisions back into this doc.
