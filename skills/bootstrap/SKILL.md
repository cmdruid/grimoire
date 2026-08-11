---
name: bootstrap
description: "Turn an idea into a brand-new git repository carrying five founding documents -- README, AGENTS, architecture, roadmap, runbook. `/bootstrap grill` runs a relentless design-tree interview (rounds of numbered questions, each with a recommended answer) settling problem, scope, architecture, sequencing and conventions, writing nothing to disk; `/bootstrap land` then creates the directory, writes the documents, runs `git init`, and commits, with an optional confirmed remote. Use when the user runs `/bootstrap ...`, or wants to start a new project, repo, or codebase from scratch and no repository exists yet. Founding documents only -- never project code, build tooling, or CI."
---

# bootstrap -- idea to founding repository

`/bootstrap` covers the moment before a project exists: no directory, no facts, no build -- only an
idea. It interrogates that idea until the design is settled, then lands a fresh git repository whose
**founding documents are a consequence of the design** rather than a template pick.

This skill is **self-contained**: it depends on no other skill, reads no host configuration, and
bundles no stack templates. It works identically wherever it is installed.

## Scope -- founding documents only

The entire deliverable is prose. `bootstrap` writes **no project code, no build tooling, no CI, no
gate command, and no issue tracker.** Everything executable is downstream and belongs to whatever
development process follows.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does | Touches disk |
|---|---|---|---|
| `grill [<prompt-or-path>]` | `verbs/grill.md` | Design-tree interview until the design is settled | **no** |
| `land` | `verbs/land.md` | Create the directory, write the documents, `git init`, commit, optional remote | yes |
| `bootstrap` (bare) | both, in order | `grill` then `land` | yes |

`land` is independently useful: when the shape is already known, skip the grill and just get the
repository.

## The defining invariant -- nothing touches disk until `land`

`grill` writes nothing, anywhere. The project's **name and location are outputs of the grill, not
inputs** -- naming is a design decision, and usually the last one that can be made well. An abandoned
grill therefore costs nothing on disk, and no half-made directory is ever orphaned.

## The five founding documents

```
README.md            (root)   problem, users, scope, non-goals, links out
AGENTS.md            (root)   agent-facing conventions + the declared verification command
docs/ARCHITECTURE.md          components, boundaries, interfaces, rejected alternatives
docs/ROADMAP.md               sequencing, phases (goal / scope / definition-of-done / risks)
docs/RUNBOOK.md               how to work on this project
```

**Placement rule:** root holds the *addressed* files -- `README.md` because forges render it,
`AGENTS.md` because harnesses look for it there. The other three are reached by following a link, so
they live in `docs/` and keep a day-one root legible. The README links to all three.

## Session-bound by design

A grill lives in conversation context and **does not survive a session reset**. There is no state
file, no slug registry, no resume protocol -- deliberately, to keep the skill simple. A grill
interrupted by a reset is re-run, and since it wrote nothing, re-running is free.

## Disposition (scored against the authoring doctrine)

- **Self-init / home:** none -- a **pure mechanism**. It owns no durable store: its output is a
  repository handed to the user, not a home it maintains across runs.
- **Front-door registration:** skipped. Registration surfaces durable captured items; a skill with no
  store would only bloat the front door.

## Edges

`bootstrap`'s **typed edges** -- its place in a workflow declared as artifact *types*, never as
sibling names. It is a **producer with an open successor**: it terminates expecting development to
follow, but names nothing that might do it.

<!-- edges:bootstrap -->
- produces: founding-documents, roadmap, architecture-doc — the five documents seeded into a new repo
- handoff: git-repository — a fresh repo carrying founding documents and no code; development follows
- consumes: design-notes — optional prior material (notes, a spec, a sketch), read as facts
<!-- /edges:bootstrap -->
