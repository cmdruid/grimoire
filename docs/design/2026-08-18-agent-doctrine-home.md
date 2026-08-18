---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `agent-doctrine` — a front-door home for project doctrine — Draft

Brainstorm draft, `stream/feat` **feature 2**. Grounded against `1707ede` (post-`grok`
records-layer-init landing). Not yet argued into a spec — `grill` or `spec` resolves the
open questions at the foot.

Companion feature: `2026-08-18-handbook-skill-extraction.md` (feature 3), which this one
unblocks.

## Problem

Skills that read or write **project doctrine** have no shared home resolution. Records got
one in `1707ede` — the **agent-records home** (declared `agent-records:`, else legacy
`records-root:`, else `.records/`), with the rule that a record-writing skill resolves that
home, carries its own template, and never refuses for lack of a `journal` floor. Doctrine
never got the equivalent, and three symptoms follow.

1. **Doctrine homes are improvised per skill.** `auditor`'s rubric — `GUIDE.md` +
   per-dimension `rules/` + `metrics.sh` — is doctrine by any reading, and its standalone
   default is a hardcoded `docs/audit/`, confirmed once at setup (`auditor/SKILL.md:31`).
   Its own walk says "doctrine has one home" for the workshop path (`:93`) and then falls
   back to an ad-hoc directory when bare. That is the general shape: on a workshop host,
   doctrine has a home; off one, each skill picks something.

2. **Consumers ask a boolean where they need a path.** Six skills (`auditor`, `blueprint`,
   `contractor`, `debugger`, `workstream`, `clankshop`) grep `.handbook/README.md` for
   `Seeded from clankshop` to decide whether doctrine exists. `1707ede`'s DOCTRINE rule 8
   already stripped this probe of its records job — it now gates *only* station and
   playbook context. So all six ask "is a workshop deployed?" when what they actually need
   is "where does doctrine live, and is the piece I need in it?"

3. **Doctrine is unavailable bare.** With no workshop, a skill that would consult or record
   normative project material has nowhere to put it, so it either hardcodes a path or does
   without. Rule 8 forbids the tempting shortcut — *"Do not create `.handbook/` as a records
   side effect"* — but offers no alternative destination.

## Goal

One resolution rule for project doctrine, owned by the **framework** (`skill-builder`'s
portable doctrine), available to every skill whether or not any workshop, `handbook`, or
`clankshop` is installed.

## Approach (settled 2026-08-18, human)

**A front-door variable `agent-doctrine:`**, resolved as: the project's declared
`agent-doctrine:` line, else the derived default **`<agent-records>/doctrine`**.

This is a second instance of an existing, documented mechanism, not a new one:
`DOCTRINE.md:203` *Front-door variables — one declaration, two readers* already names the
agent-records home as "**the canonical example**", and fixes the form (one line at the
front door, line start, kebab-case).

**Why derive the default from the records home** rather than a flat `.doctrine/`:

- A brownfield host declaring `agent-records: dev` gets `dev/doctrine` with **no second
  declaration**. A flat default would force every such host to declare twice.
- It structurally guarantees what rule 8 currently only asks for in prose: a bare
  doctrine-writing skill can never create `.handbook/` as a side effect, because its
  default home is elsewhere by construction.

**Ownership.** `skill-builder` defines the variable, the default, and the classification
test, and lints conformance. `handbook` (feature 3) does **not** own it — it *declares*
it: `setup` deploys `.handbook/` and writes `agent-doctrine: .handbook` at the front door.
That keeps exactly one resolution rule everywhere, with no skill holding override status,
identical in shape to a brownfield host declaring `agent-records: dev`. Consumers need no
knowledge that `handbook` exists.

### Two-level resolution (the part that is easy to get wrong)

Resolving the home is not the same as finding the artifact. `contractor` summons "the build
station"; if `<agent-doctrine>` resolves to `.records/doctrine` with no station chapters in
it, there is nothing to summon. The rule is therefore: **resolve the home, then test for the
specific artifact you need** — already how `debugger` behaves (*"consult
`diagnostics.md` when that file exists"*). A missing chapter must degrade the way a missing
workshop does today, never break the consumer.

### The classification test (doctrine vs. record)

A lint can check resolution; it cannot judge what counts as doctrine. The test belongs in
the prose:

> **Doctrine is living, normative, undated, and never closes. Records are dated, typed, and
> closeable.**

By that test: an audit rubric is doctrine; a diagnostics playbook is doctrine; a station
chapter is doctrine. A spec is **not** (it is a dated `design/` record); a notepad fact is
**not**; an audit *report* is **not** (it lands in the agent-records home, per `auditor`'s
current description).

### What `skill-builder` gains

- A DOCTRINE.md section defining `agent-doctrine:`, its default, its two-level resolution,
  and the classification test.
- A lint rule + fixture, mirroring `1707ede`'s `lint-records-writer-test.sh`: a skill that
  declares it reads or writes doctrine must resolve the home rather than hardcode one, must
  not create `.handbook/` bare, and must degrade on a missing artifact.
- Prove-by-breaking: the fixture must FAIL on a deliberately hardcoded home before the rule
  is trusted.

### Consumers flipped in this feature

The six stamp-probing skills move from "does the stamp exist" to "resolve
`<agent-doctrine>`, then test for the artifact". `auditor`'s `docs/audit/` default becomes
`<agent-doctrine>/audit/`. The stamp itself is left alone here — after this feature nothing
branches on it, which is what makes feature 3's stamp question trivial.

## Why not the alternatives

- **A flat `.doctrine/` default** — one fewer indirection, but every brownfield host
  declares twice, and the "never create `.handbook/` bare" guarantee becomes prose again
  rather than structure.
- **Leave doctrine to the workshop probe** (status quo) — keeps the boolean where a path is
  needed, leaves `auditor`'s improvised home improvised, and forces feature 3 to convert
  six consumers that would need converting again later.
- **Give `handbook` the variable** — makes an optional skill load-bearing for a framework
  rule, and every consumer would need to know handbook exists.

## Risks

- **Doctrine nested under the records home reads against the distinction it encodes.**
  `.handbook` is doctrine, `.records` is work output — and the default path puts doctrine
  inside the records home. Mitigation is cheap but must be explicit: `journal` already
  reserves `templates/`, `scripts/`, and `history.tsv` as never-scanned
  (`journal/SKILL.md:28`), so `doctrine/` joins that list; and the docs must state that the
  records **home** is a directory that may host sibling layers, while the records **layer**
  is the eight typed stores. Without that sentence the default path argues against the rule.
- **Six consumer skills change.** `grok` has landed, so the contention is gone, but this is
  the second consecutive feature to rewrite the same six files.
- **`agent-doctrine` and `agent-records` become coupled by the derived default** — moving
  the records home silently moves doctrine on any host that never declared
  `agent-doctrine:`. Acceptable, but it should be stated where hosts can read it.

## Open questions (for `grill` / `spec`)

1. **Does `journal` need to know about `doctrine/` at all**, beyond adding it to the
   reserved list? Does `records.sh check` ignore it, or actively assert it is not a store?
2. **What migrates?** `auditor`'s existing `docs/audit/` rubrics are deployed in the field.
   Does this feature move them, teach `auditor` a legacy fallback (the way `records-root:`
   remains accepted), or leave them and only change the default for new setups?
3. **Is `agent-templates:` affected?** `1707ede` established the agent-templates home under
   the records root. Do doctrine-owned templates resolve there, or under
   `<agent-doctrine>`?
4. **Does anything write doctrine bare today besides `auditor`?** Worth an inventory before
   claiming the variable has multiple consumers — one live consumer plus handbook may be
   the honest count.
5. **What does the lint key on?** How does a skill *declare* that it reads or writes
   doctrine — a typed edge, a frontmatter field, or a prose convention the lint greps?
6. **Does the declaration go in `AGENTS.md` only**, or `CLAUDE.md` too where that is the
   front door (as the records home already allows)?

## Grounding

Built against `1707ede`. Verified at draft time: `DOCTRINE.md:203` defines the front-door
variable pattern with agent-records as the canonical example; `DOCTRINE.md:304` (rule 8)
decouples the stamp from records destination and forbids bare `.handbook/` creation;
`auditor/SKILL.md:31,93` confirms the improvised `docs/audit/` home; `journal/SKILL.md:28`
confirms the existing reserved-name list; `lint-records-writer-test.sh` is the lint
precedent; ten live `Seeded from clankshop` sites across six consumer skills.
