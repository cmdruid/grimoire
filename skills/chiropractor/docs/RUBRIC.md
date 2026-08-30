# Chiropractor rubric

Judge the agent-facing documentation spine, not general prose quality. Each check is `solid`, `drift`,
or `gap` and cites repository evidence.

- `solid` — the required route or authority is clear and works in the current tree.
- `drift` — it still works, but ambiguity, depth, duplication, or weak signposting creates avoidable
  navigation cost.
- `gap` — an important route is absent, broken, contradictory, or cannot establish authority.

An unresolved source, inspection, or disposition prevents Routing and Reach from being `solid`.
Counts are facts, not severities, until archives, generated material, vendor content, nested roots,
and internal helpers are dispositioned.

## Checks

1. **Door** — root `AGENTS.md` is canonical, concise, and coherent with compatibility and scoped
   doors.
2. **Routing** — the door dispatches recognizable task intent to substantive entry points. A raw
   filename menu without a “when” cue is not sufficient.
3. **Reach** — every important task and artifact has one unambiguous route to authoritative
   instructions or a runnable entry point.
4. **Currency** — live links, anchors, paths, imports, and command targets resolve in the working
   tree.
5. **Authority** — one canonical source owns each instruction; other documents point instead of
   maintaining divergent copies.
6. **Altitude** — the door retains routing cues and non-negotiable tripwires while mechanisms and
   rationale live in task-specific leaves.
7. **Scope** — nested doors and nested repositories preserve their local authority and standalone
   boundaries without stranding the root reader.

## Route expectation

Project-wide tasks should dispatch directly from `AGENTS.md` to their authoritative entry point.
Subsystem tasks may pass through one scoped door or one substantive router. More than two navigation
actions, an ambiguous branch, a menu-only hop, or a leaf that omits its runnable entry point is
presumed `drift` unless repository structure supplies a concrete justification.

For every important task record:

```text
task | route | navigation actions | result | evidence
```

## Evidence hierarchy

Classify importance in this descending order:

1. A maintainer explicitly names the task or artifact.
2. `AGENTS.md` declares it or a scoped door governs it.
3. A primary README or contributor guide presents it as supported.
4. Build, package, CI, release, or deployment configuration exposes an entry point.
5. Multiple live documents or workflows invoke it directly.

One strong source can be enough, but explain why an agent must invoke, modify, or understand the
candidate directly. A conventional filename or CI invocation creates a candidate, not an automatic
importance verdict. A helper reached only through a documented caller is normally `internal`.

## Door diet

When an always-loaded section duplicates a leaf, preserve the line that says when to open the leaf
and every surprising constraint or “never” rule. Replace copied mechanism, paths, and rationale with
the authoritative link. A surviving door line routes or constrains; it does not summarize the leaf.

Do not require a glossary, index, frontmatter, uniform headings, house style, or a docs taxonomy.
Propose one only when it directly repairs a demonstrated route or authority failure.
