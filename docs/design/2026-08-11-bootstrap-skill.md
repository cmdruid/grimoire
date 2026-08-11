# `bootstrap` — idea to founding repository

**Status: executed 2026-08-11** (owner-approved; scaffolded via `/skill-builder new`, gate green at
`fails=0`, routing probe 7/7 — see `docs/boundary-audit.md`). A new **standalone** library member —
deliberately outside the `clankshop` pack and carrying no reference to it.

## Problem

Starting a new project has a gap nothing in this library covers. `feature brainstorm` assumes a
host project (it tunes to the host's gate and templates, and is artifact-free by design —
"brainstorm's approach lives in context"). `clankshop setup` assumes a repository already exists
(precondition 3: *"A git repo. No repo → offer `git init` first"*). Neither serves the moment
when there is no directory, no facts, and no gate — only an idea.

The public ecosystem has the pieces but not the arc. Matt Pocock's `grilling` supplies an
excellent interview protocol; Obra's `superpowers:brainstorming` covers idea → spec; several
skills (`repo-init`, `Claude-Code-Scaffolding-Skill`, `claude-scaffold-skill`) dispense project
templates. Nothing takes a rigorously-interrogated design and lands it as a repository whose
**founding documents are a consequence of the design** rather than a template pick.

## Decision (proposed)

A standalone `bootstrap` skill: an intense design-tree interview that terminates in a new git
repository containing **five founding documents**. It writes no project code, runs no gate, and
creates no trackers.

**Scope boundary — founding documents only.** The skill's entire deliverable is prose. Code,
build tooling, gate commands, CI, and issue trackers are explicitly downstream and belong to
whatever process the owner runs next.

## The grammar

| verb | does | writes to disk |
|---|---|---|
| `grill [<prompt-or-path>]` | design-tree interview until the design is settled | **nothing** |
| `land` | create the directory, write the docs, `git init`, first commit, optional remote | everything |
| `bootstrap` (bare) | `grill` then `land` | — |

**The disk boundary is the skill's defining invariant:** nothing touches the filesystem until
`land`. The project's *name and location are outputs of the grill*, not inputs — naming is a
design decision, and it is usually the last one you can make well. An abandoned grill therefore
costs nothing on disk.

`land` is independently useful: when the shape is already known, skip the grill and just get the
repository.

## The grill

The design-tree protocol is **reimplemented in-house**, not depended upon. Depending on an
external plugin (`mattpocock-skills:grilling`) would violate the boundary independence this
library requires of every skill; the protocol is short and its value is the discipline, not the
prose. Credit the source in the skill's docs.

Mechanics: model the design as a tree; work it in **rounds**; the **frontier** is every decision
whose prerequisites are settled. Ask the whole frontier in one round, numbered, each with a
recommended answer, then wait. Facts are the agent's job — never ask the user anything the
environment can answer.

**Seeded root branches.** Unlike the generic protocol, the tree's roots are seeded, because a
greenfield grill has a known shape. Five branches, each feeding a document:

| branch | feeds |
|---|---|
| Problem & users | `README.md` |
| Scope & non-goals | `README.md`, `docs/ROADMAP.md` |
| Architecture & rejected alternatives | `docs/ARCHITECTURE.md` |
| Sequencing & phases | `docs/ROADMAP.md` |
| Working conventions (name, language, verification command) | `docs/RUNBOOK.md`, `AGENTS.md` |

Seeding the roots gives the grill a **checkable termination condition** — the frontier is empty
when all five documents have what they need — and makes scope creep structural rather than a
judgment call: *a branch that feeds no document is out of scope by construction.*

Seeded roots must not mean scripted questions. The branches are seeded; everything below them is
discovered from the user's answers, or it is a questionnaire, not a grill.

**Prior material.** `grill <path-or-prompt>` reads what it is given as *facts*, marking the
branches it already settles as settled rather than asking them. Nothing is auto-detected from the
cwd — that is guesswork on a directory the skill does not own.

## The documents

```
README.md            (root)   problem, users, scope, non-goals, links out
AGENTS.md            (root)   agent-facing conventions + the declared verification command
docs/ARCHITECTURE.md          components, boundaries, interfaces, rejected alternatives
docs/ROADMAP.md               sequencing, phases (goal / scope / definition-of-done / risks)
docs/RUNBOOK.md               how to work on this project
```

**Placement rule:** root files are the *addressed* ones — `README.md` because GitHub renders it,
`AGENTS.md` because every harness looks for it there. The other three are reached by following a
link, so they cost nothing in `docs/` and keep the root legible on day one. The README links to
all three.

**The declared verification command.** `AGENTS.md` records the project's intended verification
command as a *decision*, not a proven fact — the skill neither writes nor runs it. Any agent
arriving later benefits from knowing what "green" is supposed to mean, well before code exists to
prove it.

`ARCHITECTURE.md` is where the grill's highest-value output lands: the settled design **and the
rejected alternatives**. Without it, the reasoning that justified an intense interview has
nowhere to live.

## Landing

1. Create the directory at the grill's chosen location and name.
2. Write the five documents.
3. `git init`, first commit.
4. **Remote is opt-in only** — `gh repo create` on explicit request, private unless stated
   otherwise, confirmed before running. Claiming a public namespace is outward-facing and
   effectively irreversible; it is never a default.

**Incomplete grills.** If branches remain open, `land` reports exactly what is unsettled and
asks. Anything the user accepts becomes a visible *Open questions* section in the relevant
document — never a silent `TODO:`. Deferred-by-choice and unsettled-by-omission must look
different on the page; five documents quietly full of `TODO:` markers are exactly the failure
this skill exists to prevent.

## Boundaries

- **No `clankshop` coupling of any kind.** Not a pack member, absent from `PACK.md`, no
  reference in prose, no detection, no optional handoff. `bootstrap` stands alone and must be
  installable in any skills library.
- **No bundled scaffold templates.** The skill carries generic instruction only, per this
  library's *instruct generically; let the project resolve specifics* convention. Bundled
  stack templates rot, cover the wrong stack, and pull toward the template-zoo failure mode.
- **No state file.** A grill lives in conversation context and does **not** survive a session
  reset — the same trade `feature brainstorm` already makes. Accepted knowingly: a state file
  meant a slug registry, a location convention, and staleness handling, for a skill whose value
  is being simple.
- **No trackers, no records, no `setup` verb.** Route registration is pack machinery an
  independent skill should not need.

## Rejected alternatives

| considered | rejected because |
|---|---|
| Ship a running code skeleton so a downstream gate question has a real answer | Owner scoped the skill to founding documents; a declared-but-unproven verification command in `AGENTS.md` recovers most of the benefit at zero scope cost |
| Depend on `mattpocock-skills:grilling` | External plugin dependency breaks boundary independence; protocol is ~20 lines to restate |
| Make it a `clankshop` verb (`/clankshop new`) | Every `clankshop` verb begins by resolving a root; this skill runs when no root exists. A verb whose first act violates its own skill's precondition contract is misplaced — and a terminus inside `clankshop setup` would make the face call itself |
| Make it a `feature` verb (`/feature genesis`) | `feature`'s stages are primitives an orchestrator sequences; this is a layer up |
| Require a pre-made or up-front-named directory | Forces the name at the moment of least information and orphans an empty directory when a long grill is abandoned |
| Persist grill state to `~/.bootstrap/<slug>.md` | Owner cut it as over-complication; multi-session grills are the accepted casualty |
| Drain grill output into trackers | Owner's call — trackers stay untouched until the project is fully deployed; the roadmap carries forward-looking scope instead |
| Auto-write `LICENSE` / `.gitignore` | A license is a legal commitment; auto-writing makes an unmade decision look settled |
| Commit the raw grill log into the repo | `ARCHITECTURE.md` already owns that content; two records of the same decisions means the unpolished one silently wins |
| Name it `newproject` / `genesis` | `bootstrap` is the word the owner reached for unprompted — the best evidence of what will be typed. Collisions (Bootstrap CSS, `bootstrap.sh`) are nouns; this triggers on a verb phrase about starting a project |

## Out of scope

Code generation, build tooling, CI, branch protection, licence selection, issue-tracker
provisioning, and any post-landing development process.

## Residual assumptions

1. No `.gitignore` or `LICENSE` is written, and the grill does not ask about them.
2. The skill is authored at `skills/bootstrap/` — a standalone library member outside the pack.
3. No `bootstrap setup` verb.

## Execution notes

Scaffolded as a **pure-mechanism** skill (no durable store → no `init` verb, no front-door
registration, per the tier table). Package: `SKILL.md` + `verbs/grill.md` + `verbs/land.md`.

Two things the gate caught that were worth fixing rather than suppressing:

- **Bundled-ref ambiguity.** Verb bodies referenced `docs/ARCHITECTURE.md` and friends, which the
  lint reads as *this skill's own bundled docs* — and so would a human reader. They are paths in the
  repository `land` creates. Rewritten as `<project>/docs/...`.
- **The overloaded name.** `clankshop setup` is self-described as the "greenfield bootstrap", the
  one genuine collision. The probe held 7/7 including two decoys, and named the discriminator —
  whether a repository already exists — which was then folded into the description.

`roadmap` is declared as a produced type with no consumer in this library: `feature` would be the
natural match, but pack core members carry no typed-edge blocks by the two-regimes rule. A standing
single-direction type, not a defect.
