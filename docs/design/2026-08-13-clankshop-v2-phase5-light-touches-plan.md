# Clankshop v2 — Phase 5 plan: light touches + library refresh

Companion to `2026-08-12-clankshop-v2.md` and the roadmap's Phase 5. Needs Phases 1–4 shipped
(final names and shapes) — all landed as of 2026-08-13 (main @ 29e2656).

**Scope note:** task 2 grew from a rename into the phase's biggest task — the `checkpoint`
redesign has its own design doc, `2026-08-13-checkpoint-skill-design.md` (twice Codex-reviewed,
findings folded in, human-approved 2026-08-14). The rest of the phase stays light-touch.

## Decisions (settled with the human, 2026-08-13/14 — do not re-ask)

- **register-route: RETIRE both scripts** (task 5). skill-builder's copy is the only one left in
  the library (zero deployed per-skill copies remain, so the drift check has no candidates);
  `docs/DOCTRINE.md` does not depend on them. Strip the refs from skill-builder's SKILL.md /
  `verbs/new.md` / `verbs/check.md`; BACKLOG history entries stay as history.
- **checkpoint: full redesign, not just a rename** — per the design doc: living save-state
  lifecycle, four named disciplines (Save / Resume / Lifecycle / Recovery), new `done` verb,
  compaction-persistence machinery moves from workstream which borrows it back by
  locally-complete citation. All settled decisions live in the design doc's *Decision summary*.

## Tasks

1. **`debugger` refs (2)** — re-point its v1-vocabulary references to the v2 names/shapes
   (locate via the dependency sweep, task 6).
2. **`checkpoint` — rename + redesign** (design: `2026-08-13-checkpoint-skill-design.md`; build
   in this order so each commit is coherent):
   a. Rename `skills/handoff/` → `skills/checkpoint/`; rewrite SKILL.md to the design — the four
      disciplines, `done` verb + its gate, living-lifecycle document structure (cheat-sheet
      section, living preamble), checked gitignore mechanism, foreign-checkpoint guard, worktree
      redirect, anchor convention with the two-path copy-paste block, legacy-`HANDOFF.md`
      discovery, edges block (`checkpoint-doc`), "formerly `/handoff`" note.
   b. Workstream's borrow: `flow.md` (Scenario C shrinks to Recovery-discipline citation + the
      overlays incl. re-read `flow.md`; reset-ritual cites Lifecycle), `verbs/save.md` +
      `verbs/load.md` re-point to `/checkpoint`, hand-off template cites the anchor-line
      technique, `templates/compaction-anchor.md` + `verbs/create.md` gain the
      workstream-instance annotation. Zero behavioral change; creation-timing declared an
      overlay.
   c. Grimoire's own `AGENTS.md` anchor block gains the same one-line instance annotation
      (library-doctrine edit, root-checkout content — rides the branch like every other change).
   d. PACK.md: `optional:` list `handoff` → `checkpoint`; transition note flips to landed.
   e. Desk-check the twelve lifecycle walkthroughs (design §8) against the final SKILL.md text —
      each must have one unambiguous answer; fix the text where one doesn't.
3. **`pack-format.md` touch-up** — align with the shipped manifest reality (scheduler listed,
   renames landed — including `checkpoint`).
4. **Repo-root `README.md` + `AGENTS.md` refresh** — rewrite to the v2 inventory and
   vocabulary; README's skill inventory gains `blueprint`, `journal`, `scheduler` and speaks
   `checkpoint` (clears the three expected lint WARNs).
5. **Retire register-route** — delete `skills/skill-builder/scripts/register-route.sh` +
   `register-route-drift.sh`; strip the refs from skill-builder's SKILL.md, `verbs/new.md`
   (stamping step), `verbs/check.md` (drift check in Pass 2). Verify skill-builder's own suite /
   lint stays green after the strip.
6. **Exit sweep** — re-run the spec's dependency-check sweep: zero v1-machinery references
   outside `docs/design/` and `.scratch/`; **plus** the checkpoint extension: zero `handoff`
   references meaning *the skill* — prose, scripts, templates, comments, not only
   slash-invocations (the edges-format line kind `handoff:` and generic English "hand-off" are
   out of scope) — proven by planting a stray ref, watching the sweep catch it, removing it.
   Lint fails=0 with the wiring WARNs as the only expected remainder (`checkpoint` joins them
   until `install.sh checkpoint` re-wires the harness symlink — human step, post-ship).

## Exit (roadmap)

The dependency sweep clean (zero v1-machinery refs outside docs/design + .scratch; zero
skill-meaning `handoff` refs); lints green; README/AGENTS speak v2; the checkpoint walkthroughs
desk-checked.
