# Clankshop v2 — Phase 7 plan: live deployment test (DRAFT — uncommitted; refine before build)

Companion to `2026-08-12-clankshop-v2.md` and the roadmap's Phase 7 — the finish line, the test
v1 never got. Needs Phases 1–6 shipped (1–5 landed as of 2026-08-14, main @ 89dd367; 6 — the
journal/backlog split — pending).

## Shape

Two live deployments, run for real — not fixtures. **Patient-zero caveat still binds:** neither
deployment happens in the grimoire repo itself; both need real (or realistic scratch) target
repos, and the human names them.

## Tasks

1. **Greenfield**: `/clankshop setup` on a real new repo.
   - Full workshop stands up: seeded `.handbook/`, `journal`-delegated `.records/`, the
     `AGENTS.md` door; `check` green immediately after setup.
   - Work one real change through the full line: design → build → test → review.
   - Schedule a chore via `scheduler` (a real tick fires; `.scheduler/` self-gitignores).
2. **Brownfield**: `/clankshop migrate` on a legacy project with a `dev/` records root —
   declare-in-place (`records-root: dev`), never a bulk `git mv`.
   - The inventory + one confirmed mapping table; adopt without moving history.
   - `check` green post-migrate; the declared root resolves through the door.
3. **Friction capture**: every rough edge in both runs captured as feedback, tagged by skill —
   the first real input to the review station's improvement loop. (Per this machine's
   convention, skill feedback lands in `~/.agents/FEEDBACK.md`; project-level friction lands in
   the target repo's own records.)

## Exit (roadmap)

`check` green on both deployments; every friction point captured as feedback.

## Decisions to settle before build

- **Target repos**: which new repo for greenfield, which legacy project for brownfield
  (thinklab is the known `dev/`-rooted candidate — human's call).
- Whether the greenfield "real change" is a scripted exercise or a genuinely pending piece of
  work in the target repo.
