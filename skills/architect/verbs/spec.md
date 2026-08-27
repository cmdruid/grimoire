# `spec [doc]` — synthesize, grill the gaps, argue the result

Produce the **argued specification** — concrete enough that a gap between
design and code is detectable, and measurable once found. Start from a
`brainstorm` draft, an existing doc, or the conversation itself.

If `[doc]` is named, classify it **before** the steps below. Resolve `<agent-workspace>` through
SKILL.md *Project homes*. A regular non-symlink Markdown file beneath the canonical
`<agent-workspace>/architect/drafts/` home whose body follows
`templates/draft.md` is a workspace draft. Otherwise apply SKILL.md *Founding-shaped* exactly:
founding-shaped → synthesize into the six map H2s on that same file; run `grill` on those sections;
do not write Problem / Goal / Approach as H2s; skip the records mint, `templates/specs.md` rewrite,
and status promotion. Refuse the otherwise-case. Never scan cwd.

Feature `spec` mints or rewrites a `specs/` record (SKILL.md destination).
Founding-shaped stays on the named file.

## Procedure

1. **Synthesize first** — assemble everything already decided (conversation,
   draft, prior ADRs) into the spec's shape before asking anything. From a workspace draft, carry
   forward settled decisions and links to completed spike records that the design actually relies
   on. Do not copy raw spike notes, transient experiment code, or exploratory chatter.
2. **Grill the gaps** — run `grill` on the assembled draft: every remaining
   open branch gets resolved, not papered over.
3. **Write the spec** per `templates/specs.md` (skip this reshape when the
   named file is founding-shaped): **Problem** (root need, not a
   surface knob), **Goal**, **Approach** (+ alternatives rejected and why),
   **Mechanism** (concrete enough to implement from), **Verification** (how
   we'll know it works). A small feature may add the optional **Slices** stub
   in that same file (id / verify command / paths). A cross-cutting decision
   that surfaced gets its ADR (`templates/adr.md`, the `adr/` store) — one per
   decision, linked. **A numeric before/after acceptance target needs a
   population ATTRIBUTION, not just a count:** dump a few instances of the
   metric's population, section one, and name which mechanism/class produces it
   — a real count over the *wrong class* passes every review and dies only at
   measurement (observed: a headline "162 → 0" whose population belonged
   entirely to a class the mechanism deliberately excluded).
4. **Self-review** — run this package's `scripts/ground-check.sh`
   `<root> <doc>` (`<root>` is `git rev-parse --show-toplevel` of the
   checkout that holds the doc; resolve the script from this skill's own
   base directory). Unresolved refs are facts, not a refuse: re-read or
   rewrite those paths. A resolving reference can still point at the wrong
   code — re-read the load-bearing signatures the claims rest on. Then
   placeholders (TBD/vague), internal contradictions, scope
   (one feature's worth?), ambiguity (any requirement readable two ways → pick
   one, make it explicit). **And the greenfield check:** is any mechanism
   shaped by a constraint we could *delete* instead (a code built-in, an
   integer substrate, a frozen baseline that could re-baseline)? Name each such
   constraint explicitly as pay-the-debt vs design-around — grounded review
   structurally cannot supply this (a reviewer refuting claims against `HEAD`
   never flags that `HEAD` itself is the problem).
5. **Promote a workspace draft after the spec exists.** First create or update the
   `architect/spec@1` record and verify its dated path. Only then change the source draft's body
   disposition to `promoted`, add the returned `→ specs/<file>.md` link under Related records, and
   save it through `scripts/architect-artifacts.sh draft-save`. If spec creation fails, leave the
   draft active. Existing draft spec records remain ordinary spec inputs and are never converted
   into workspace drafts.
6. **User-review gate** — the human reads the written spec before anything is
   sequenced against it. For an ADR-tier spec, the host's review first is
   recommended by default — design-stage review has caught must-fix defects
   before any cut existed. The artifact stays `status: draft`. The caller
   writes `published` after a passing verdict they accept (the superseded
   spec, if any, closes `--as superseded` naming its successor).

Output: the argued spec. Tell the human where it is and that they should
read it before anything is sequenced against it. Then **stop**.
Implementation sequencing is a different job.

## Done when

The argued spec is on disk at `status: draft` (founding-shaped: the named
file, still `draft`, still founding-shaped). A workspace source draft, when used, was marked
`promoted` and linked only after that spec path existed. Ground-check ran on the spec.
The human was told the path and asked to read it. No `published` write. No
successor skill invoked.
