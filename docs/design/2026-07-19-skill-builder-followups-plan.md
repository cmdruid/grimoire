# `skill-builder` follow-ups — a plan

**Status:** Implemented (2026-07-19). Post-capstone hardening: the four follow-ups filed against
`skill-builder` as its first real tasks (BL-4, BL-6, BL-7, BL-8 in `docs/BACKLOG.md`), sequenced and
scoped. Not a new roadmap phase — the self-init roadmap is closed
(`docs/design/2026-07-18-skill-self-initialization-roadmap.md`); this is small, independent
maintenance that happens to land in the same stream/session because nothing about it needs isolation.
**All four items landed** (commits `5530c13` BL-8, `3b5b56a` BL-6, `a27ea6a` BL-7, `bbbb193` BL-4),
each independently gated (`skills-lint.sh fails=0`, warns dropping from 12 → 11 as BL-4's real fix
landed). BL-6's resolution differs from its literal ask — see §2 below — per the human's confirmed
call.

## Sequencing

Cheapest and least contentious first; the one real design call (BL-6) surfaces early so it doesn't
block the rest.

1. **BL-8** — trivial, no design call, do first.
2. **BL-6** — has a real design tension (below); resolve the call before touching code.
3. **BL-7** — mechanical once BL-6's call is made (same files, same mechanism).
4. **BL-4** — independent script-logic fix; can run in any order, listed last only because it needs a
   small fixture test, not because anything blocks it.

---

## 1. BL-8 — fix the stale status line in `2026-07-17-library-refactor.md`

**What:** That doc's §4/§8 mark `architect`'s Phase 2 ("extract a design seed from code" + "`check`
extended to design↔code drift") as *deferred*. Both shipped since, under different verb names
(`architect extract`, `architect reconcile`). Only the doc's third Phase 2 item (the spec-driven /
"ralph-loop" expansion) genuinely remains undone.

**Fix:** One status-line edit: "Phase 2: extraction + drift-check shipped (as `extract`/`reconcile`);
ralph-loop expansion still deferred." No code, no gate beyond the doc-linter.

**Effort:** trivial (~5 min).

---

## 2. BL-6 — the `register-route.sh` duplication: a design call, not just a fix

**The friction as filed:** `register-route.sh` is byte-for-byte duplicated across 5 skills
(`backlog`, `feature`, `architect`, `auditor`, `foreman`) — "keep the write-protocol in sync by
convention."

**Why "collapse into one shared script" doesn't actually work:** every skill's authoring convention
(`docs/DOCTRINE.md` § Authoring conventions) is **self-contained + location-agnostic** — a skill
references only its *own* bundled resources, never a host-project path, precisely so it works
installed alone. If `backlog`'s `init` called out to `skill-builder`'s copy of `register-route.sh`,
`backlog` would silently stop working the moment someone installs it without `skill-builder` — a real
floor, the exact thing corollary 1 ("self-init, no floor") forbids. So a literal single shared file is
off the table; it would fix the duplication by breaking independence.

**The actual fix — verify sync, don't share the file.** This is the same call BL-5 already made for a
structurally identical case (the two `## Edges` parsers in `skills-lint.sh` and `foreman-health.sh`,
deliberately *not* shared code, "mechanism vs. harness-specifics-at-the-edge"). Applied here:

- **Keep the 5 deployed copies** — each skill stays genuinely self-contained.
- **`skill-builder new`** becomes the canonical **source** — when scaffolding a durable-home skill, it
  stamps a fresh, correct `register-route.sh` copy (already planned in `verbs/new.md` step 4).
- **`skill-builder check`** gains a new drift check: diff the 5 (soon 6+) deployed copies against each
  other (or against a reference copy bundled in `skill-builder`'s own `scripts/`) and `WARN` on any
  byte divergence — turning "keep in sync by convention" into a mechanical fact, the same
  scripts-compute-facts move as everything else in this doctrine.
- **BL-6 doesn't fully close** — it downgrades from "collapse the duplication" (impossible without a
  floor) to "duplication is correct and now verified," which is the honest resolution, not a partial
  fix.

**Open call for the human:** does this resolution — keep 5 copies, add a `skill-builder check` drift
check instead of merging them — match what you meant by "collapse," or did you want something else
(e.g. a copied-from-single-source-with-a-generation-step model, or accepting the status quo and just
closing BL-6 as won't-fix)? Flagging this now because it changes what actually gets built.

**Effort once resolved:** small — one new `scripts/register-route-drift.sh` (or a `check` verb step)
+ a reference copy in `skill-builder/scripts/`; no changes to the 5 existing skills' files themselves.

---

## 3. BL-7 — `built-against` collapses to one value across a monorepo skills-root

**What:** every skill's `init` (and `foreman-health.sh check-projection`'s "current version" side)
stamps `built-against` as `git -C <skill-dir> rev-parse --short HEAD` — the **whole repo's** HEAD, not
a per-directory version. Harmless today (grimoire is the only skills-root any of this runs against),
but breaks the moment a skills library is nested inside a bigger monorepo: every skill stamps the
identical sha regardless of which one actually changed.

**Fix:** swap the formula to a path-scoped log: `git -C <skill-dir> log -1 --format=%h -- .` (the last
commit that actually touched *this skill's directory*, not the whole repo's tip).

**Touches:**
- `verbs/init.md` in `backlog`, `feature`, `architect`, `auditor`, `foreman` (5 files) — each states
  the stamp formula in its own *Procedure* step; update the prose in each (self-contained skills, no
  shared code to fix once).
- `skills/foreman/scripts/foreman-health.sh` — `cmd_check_projection`'s "current version" computation
  (the drift-detector's own side of the same comparison).
- `skills/skill-builder/verbs/new.md` — the scaffold template a maintainer copies for a *new*
  durable-home skill should teach the correct formula from day one, so this regression can't recur.

**Verify:** re-run each skill's `init`/`check-projection` against a scratch fixture (same discipline
every self-init verb already uses — never grimoire's own `AGENTS.md`) and confirm the stamp changes
only when the skill's *own* files change, not on an unrelated commit elsewhere in the repo.

**Effort:** medium — mechanical but touches 7 files; no behavior change for grimoire itself today
(single-skills-root), so low regression risk.

---

## 4. BL-4 — check 8's single-use WARN misfires on intra-skill produce↔consume pairs

**What:** `skills-lint.sh` check 8 WARNs when an edge *type* is declared by exactly one **skill**
across the suite — meant to catch orphans/typos. But `handoff`'s real self-chain (`produces:
handoff-doc` + `consumes: handoff-doc`, save→resume) is legitimately single-skill and will WARN
forever; it's currently indistinguishable from a genuine orphan (a type only ever `produces`d, no
consumer anywhere).

**Fix:** track edge **kind** alongside type+skill when building the intermediate `edge_types` file
(currently just `type<TAB>skill`, kind-blind); at the orphan-summary step, a type declared by exactly
one skill is a **real orphan** only if that skill's own declarations for the type are all the same
kind (pure `produces` with no `consumes`, or vice versa) — if the *same* skill has **both** a
`produces` and a `consumes` line for the type, that's a stated intra-skill chain, not an orphan, and
should not WARN.

**Mirror in `foreman-health.sh derive-seams`** — its orphan note "mirrors skills-lint.sh check 8's
orphan WARN" (per its own comment); apply the identical kind-aware refinement there so the two parsers
stay in sync (the exact discipline BL-5 already asks for).

**Test:** a small fixture (2–3 synthetic skill dirs under the scratchpad, per the standing fixture
discipline) covering: (a) one skill, `produces`+`consumes` same type → no WARN; (b) one skill,
`produces` only, no consumer anywhere → WARN (still catches real orphans); (c) two skills, producer +
consumer → no WARN (already correct, regression-guard only).

**Effort:** small-medium — real script logic in two places + a fixture test, but self-contained
(doesn't touch any skill's own `SKILL.md`).

---

## Gate & landing

All four are build-relevant once BL-6/BL-7/BL-4 land (script edits) — full `skills-lint.sh` pass
required, not just the doc-linter, even though BL-8 alone would only need the fast path. Land as
independent, reviewable commits (one per item) in the sequence above, same stream, same discipline as
every prior phase (`docs/BACKLOG.md` entries closed with a one-line resolution as each lands, not
deleted).
