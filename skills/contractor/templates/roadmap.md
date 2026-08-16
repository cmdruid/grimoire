---
doctype: plans
status: open
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [roadmap]
---

# <Track> — Roadmap

<The decision map for multi-phase work: phases with gates and declared blocking edges. Each
phase requires its own plan before build; the roadmap never carries task-level detail. Flip to
`status: current` while it governs the track.>

Spec: <path to the governing spec>

## Sequencing
<The blocking edges, stated: which phases require which, and which are parallel-eligible.
An ordered list or ASCII diagram — sequencing follows from the edges, not prose order.>

## Cross-cutting foundations
<Shared infrastructure every phase relies on, and the ADRs that settled it.>

## Phase N — <name>   <requires: —, or the phase numbers it blocks on>
- **Goal:** <one line>
- **Scope:** in: <...>; out: <...>
- **Gate:** <the exit criteria that make "done" checkable — each phase lands gate-green and
  independently valuable>
- **Risks:** <...>

_When a phase meets its gate, run `/backlog debrief` before advancing._
