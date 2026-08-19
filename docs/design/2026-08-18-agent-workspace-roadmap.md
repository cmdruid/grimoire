---
doctype: plans
status: current
created: 2026-08-18
updated: 2026-08-18
tags: [roadmap]
---

# Two homes — `agent-records` + `agent-workspace` — Roadmap

The decision map for the front-door path consolidation. Each phase requires its own spec/plan
before build; no task-level detail lives here.

Spec (phase 1): `2026-08-18-agent-workspace-consolidation.md`
Draft (phase 3): `2026-08-18-agent-templates-home.md`

**Why this map exists.** The direction was worked out across one long session and lived only in a
worktree-local hand-off, which **never merges**. Everything below — the architecture, the blocking
edges, and the reason `handbook` died — would have been lost when the stream closed.

## The direction, in one paragraph

The front door carried **three** path variables (`agent-records`, `agent-templates`,
`agent-doctrine`) where only the first ever demonstrated per-host variance, and the other two
defaulted *inside* it — which forced `records.sh` to carve three of its own subdirectories out of
its store enumeration. The replacement is **two** homes: `.records/` as the file cabinet (dated,
typed, closeable documents) and `.dev/` (`agent-workspace`) as the development environment
(doctrine, templates, scripts). The retired variables become fixed subpaths, so one declaration
moves them together.

## Sequencing

```
Phase 1  (3a) doctrine home ──┬──> Phase 3  (3b) templates home
                              └──> Phase 4  /clankshop curate
Phase 2  BL-25 contractor drift ──> (unblocks Phase 3's fallback deletion)

Phase 2 is parallel-eligible with Phase 1.
Phases 3 and 4 are parallel-eligible with each other.
```

- **Phase 1 blocks 3 and 4** — both need `agent-workspace` to exist.
- **Phase 2 blocks one *option* inside Phase 3**, not Phase 3 itself: until contractor's verbs are
  fixed, `records.sh:180`'s template fallback is load-bearing shipped surface and cannot be deleted.
- **Nothing blocks Phase 2.** It is small and independent; do it whenever.

## Cross-cutting foundations

- **`agent-workspace` (Phase 1)** — the variable every later phase resolves. Default `.dev/`; the
  variable/directory name mismatch is deliberate and documented in the spec. **Naming is closed**;
  five candidates were burned with recorded evidence.
- **Lint check 16 (Phase 1)** — a new *unconditional absence* check. Check 14 is edge-gated and
  `.md`-only, so it structurally cannot prove a variable is retired. Check 16 is what makes
  "retired" verifiable rather than asserted, and **Phase 3 reuses it** for `agent-templates`.
- **Rule 3's owner exception (Phase 1)** — *the skill that assembles a home may create it even when
  declared; every other skill resolves, tests, and degrades.* Phase 1 adds it for the workspace;
  **BL-27** is the records-side instance and must wait for it.
- **BL-26 is a tail step on both Phase 1 and Phase 3** — `skill-builder/verbs/new.md` prescribes the
  resolvers new skills are scaffolded with, so until it is updated each phase keeps *producing*
  violations of the check it just installed.

### Standing discipline for this track

Two process lessons, paid for with five review lenses across two rounds. They apply to every phase.

1. **Generate the census; do not assert it.** Three consecutive review rounds failed on the same
   defect: a grep was run, the *composition* of its results was asserted in prose, and the instances
   were never opened. Every phase that claims an edit surface must produce that list mechanically
   and check it in, so the census is a verifiable artifact rather than a claim.
2. **Prose callers are callers.** The most expensive miss was scoping "callers of `records.sh`" to
   shell scripts, when agent-run verb prose calls it too. In this library, a `.md` file issuing a
   command is a caller with the same standing as a `.sh` file.

## Phase 1 — `agent-doctrine` → `<agent-workspace>/doctrine`   *requires: —*

- **Goal:** introduce `agent-workspace`, retire `agent-doctrine` into it, and close the live
  regression where five consumer skills read a variable that nothing writes.
- **Scope:** in: the variable + resolution rule; `.handbook/` → `<workspace>/doctrine/`; the stamp
  relocation; the 15-file `<agent-doctrine>` carrier flip; clankshop's verbs, `seed.sh`,
  `migrate-scan.sh`; `DOCTRINE.md`; lint checks 14/15/16.
  out: **everything `agent-templates`** — `records.sh` and its reserved list, `records.sh:180`, the
  mint scripts, `analyst`, `backlog`, `notepad`.
- **Gate:** six slices landed; all **eight** test suites green; `skills-lint.sh` `fails=0` with
  warns ≤ 22; check 16 red-proofed on a fixture carrying the retired literal; and the Problem-3
  proof — on a default-layout fixture declaring **nothing**, the path `seed.sh` wrote equals the
  literal each of the five consumers names.
- **Risks:** the spec is a scope change plus a self-authored fold and **has not been reviewed since
  the split** — the exact combination that produced `needs-rework` twice. A delta re-review is the
  entry condition, not an optional extra. The atomic retirement carries a consciously accepted risk
  (`DOCTRINE.md:226-228` publishes the declaration being retired); its required mitigation is
  removing that example in the same change.

## Phase 2 — BL-25: contractor's `--template` drift   *requires: —*

- **Goal:** bring `contractor`'s `plan` / `roadmap` / `runbook` verbs back to the
  `records.sh new --template <resolved>` form its own `SKILL.md:38` prescribes.
- **Scope:** in: the three verb files and their proof. out: any change to `records.sh` itself.
- **Gate:** the three verbs mint via `--template`; prove by breaking — delete `records.sh:180`'s
  fallback on a fixture and confirm the verbs still work (they must no longer depend on it).
- **Risks:** low. The one hazard is doing it *after* Phase 3 assumes it, rather than before.

## Phase 3 — `agent-templates` → `<agent-workspace>/templates`   *requires: phase 1 (+2 for the fallback option)*

- **Goal:** retire the second variable into the workspace, and demote `records.sh`'s reserved-name
  list from architectural to legacy-compat.
- **Scope:** in: the 24-file / 50-ref carrier set; the mint scripts' **positional CLI contract**;
  the legacy-flat adopt ladder; `records.sh:180`; `analyst`'s front-door resolver and its drifted
  second carve-out (BL-28); `standup.sh`.
- **Gate:** all eight suites green; check 16 extended to `agent-templates` and red-proofed; a
  brownfield fixture carrying a legacy-flat `templates/` survivor still passes `records.sh check`.
- **Risks:** **this is the half that failed three censuses.** The retired variable is a *tool
  contract*, not prose. Deleting `records.sh:180`'s fallback is only safe after Phase 2.
  De-reserving `templates/` breaks brownfield hosts whose legacy-flat files persist **by design**
  (`DOCTRINE.md:362` — "do not delete the old file"), so the demotion may have to stay conditional.
  Its draft carries seven verified inherited findings — read them before scoping.

## Phase 4 — `/clankshop curate`   *requires: phase 1*

- **Goal:** implement the seed-diff upgrade path that `clankshop/SKILL.md:23` and `verbs/setup.md:19`
  have promised and no verb performs.
- **Scope:** in: a `curate` verb on the clankshop face; the widened `context.sh --check`. out: any
  extraction — the `handbook` skill was **closed as superseded** (2026-08-18); everything stays in
  `clankshop`, which measurement showed is the smallest `SKILL.md` in the pack.
- **Gate:** `curate` reports divergence on a fixture with a hand-edited chapter and classifies
  nothing automatically; each new `--check` arm independently red-proofed.
- **Risks:** inherits five verified findings from the closed extraction spec's Review history —
  most importantly that a links-check arm **cannot go green-controlled** (the seed contains zero
  markdown links) and that the seeded-vs-foreign boundary is undefined (`auditor` deposits into the
  station tree by design). Do not re-derive them.

## Out of scope for this track

- **`personify`** — a voice-adoption primitive; a separate track whose go/no-go is a routing
  question, not a path question.
- **BL-24** (no skill-size principle in the doctrine) — a `/skill-builder calibrate` job.
- **BL-27** (`standup.sh` creates a declared home) — waits on Phase 1's rule-3 owner exception, then
  is an independent fix.

_When a phase meets its gate, run the project's close-the-books sweep — for grimoire, entries in
`docs/BACKLOG.md` — before advancing._
