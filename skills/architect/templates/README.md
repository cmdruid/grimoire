# Design system

This is `design/` — the regenerable **seed**. It is the present-tense, standing source of truth
for what this project *is* and how it works; the project's code is the disposable **build
output** compiled from it. When code and seed disagree, the seed is not automatically right — but
the seed is what a rebuild reads, so drift here is drift that propagates.

## Layout

```
design/
  README.md        — you are here: entry point, layout, pointers
  VISION.md         — north star + design pillars (durable what/why)
  PHILOSOPHY.md      — core ideals ("tenets") that govern every system
  GLOSSARY.md        — shared vocabulary
  MAP.md             — system index + seam graph
  src/<system>.md    — one two-tier spec per system (CONTRACT + REFERENCE ARCHITECTURE)
```

The four root files (`VISION`, `PHILOSOPHY`, `GLOSSARY`, `MAP`) are the **required spine** —
`/architect check` fails if any is missing. `design/src/` holds the compilable per-system specs,
roughly 1:1 with code units, organized by the same durability gradient: the spine is the
constitution; `src/` is the source code of the design.

## Pointers

- **`VISION.md`** — what the product is, and why it exists.
- **`PHILOSOPHY.md`** — the tenets every system must honor.
- **`GLOSSARY.md`** — shared terms, so specs don't redefine vocabulary in place.
- **`MAP.md`** — which systems exist, where their specs and code live, and how they couple.
- **`src/<system>.md`** — the standing spec for one system: a binding Contract plus a disposable
  Reference Architecture.

## A warning worth repeating

**Reference-arch is a disposable snapshot — verify before trusting.** Every `src/<system>.md`
Reference Architecture tier is a best-guess description of the *current* implementation, stamped
with the commit/ADR/date it was last distilled through. It rots as code moves. Before relying on
it — especially before a rebuild — check it against the actual code it points at. The Contract
tier is binding; the Reference Architecture tier is not.
