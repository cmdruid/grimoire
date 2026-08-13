# Clankshop v2 — execution roadmap

Companion to `2026-08-12-clankshop-v2.md` (the settled design — read it first; nothing here
re-argues it). Phases are ordered by dependency; each phase lands gate-green and
committable on its own. Per library rule, no new check is trusted until it has FAILed on
deliberately broken input.

## Phase 1 — the face: rebuild `clankshop`

> **Shipped 2026-08-13** (`stream/v2`, "clankshop(build): v2 face rebuild"). Exit criteria met:
> fixture harness ALL GREEN (seed → `context.sh --check` green on a throwaway repo),
> `context.sh --check` and the recalibrated gate exemption both proven by breaking, face lints
> at zero FAILs. Gate recalibration landed as the pack-face exemption (`core:` key retired).

Replace `skills/clankshop/` internals with v2. Everything else depends on this.

- **Seed handbook**: `README.md` (flow narrative + layout/load/precedence rules + stamp
  slot), the four `core/` docs, four station chapters with the persona preambles from the
  spec. V1 content relocates through the new shape: the four lanes → `build/workflows/`,
  the testing chapters fold into the test station, the spine audit becomes
  `review/workflows/`.
- **`context.sh`** (render / `--list` / `--check`, persona aliases).
- **Verbs**: `setup` (delegating records standup to journal), `migrate` (the brownfield
  procedure), `check`, `<persona>` summon.
- **`PACK.md`**: v2 roster and tiers; `journal` marked required.
- **Teardown rides along**: the v1 machinery (spine scripts, stewardship maps, registration
  protocol, doctrine versioning) is deleted by the rebuild, not migrated.
- **Gate recalibration is part of this phase**: `skill-builder`'s lint encodes the v1
  door-block protocol and the `PACK.md` `core:` exemption; recalibrate it as the rebuilt
  face lands, and prove it still fails on broken input.

**Exit**: fixture harness under `scripts/tests/` runs `setup` against a throwaway repo and
`check` comes back green; `context.sh --check` proven by breaking a load set; the face
lints green under the recalibrated gate.

## Phase 2 — `journal` (rewrite, not rename)

`backlog` → `journal`; it owns the records layer. 168 v1-machinery references — the
heaviest member. Requires phase 1 (the delegation seam).

- **`records.sh`** (`list` / `show` / `new` / `touch` / `done` / `history` / `check`),
  `.records/templates/`, the front-matter contract, and the **history ledger**
  (`.records/history.tsv` — closure in place, `done` as its sole writer, `check` enforcing
  status↔ledger coherence).
- **Standup both ways**: standalone on a bare repo, and the delegated seam `setup` calls.
- **Verbs reframed to v2**: capture by kind, curate, escalate, debrief — against the eight
  stores, date-slug filenames, no counters, no done log.
- **`bug`/`task` proxies** re-pointed at journal.

**Exit**: `records.sh check` proven by breaking; standalone standup on a bare repo; the
phase-1 fixture exercises setup → journal delegation end to end.

## Phase 3 — helper upgrades

Requires phases 1–2 (helpers probe the install stamp and call `records.sh`). In
dependency-weight order:

- **`auditor`** (36 refs): strip registration/seat machinery; enrichment via the
  install-stamp probe; findings drain through `records.sh`.
- **`workstream`** (29 refs): `.handbook` paths → v2; build-station context summon.
  Done-records are resolved by the spec's history ledger: shipped units land as ledger
  entries, plus a `reports` record tagged `debrief` when the unit warrants narrative.
- **`blueprint`** (27 refs + the new design): rename from `feature`; the six verbs
  (`brainstorm` / `grill` / `spec` / `roadmap` / `plan` / `review`); dual-mode entry
  (install-stamp probe, bundled templates, confirmed output home standalone).

**Exit**: each member lints green and passes the boundary audit; summons and records
writes exercised against the phase-1 fixture.

## Phase 4 — `scheduler` port *(independent — parallel to 2–3)*

From thinklab's `agent-scheduler` (`templates/.../task-scheduler` is its retired
ancestor).

- **`schedule.sh`** (`install` / `uninstall` / `list` / `status`) owning the facts: plist
  generation, cron↔launchd conversion, `flock` on the cron path, systemd-timer
  (`Persistent=true`) option on Linux.
- **Runner fallback ladder**: `spawn-agent` when on `$PATH`, else direct `claude -p` /
  `codex exec` — no hard dependency on a private binary.

**Exit**: install/uninstall/list/status round-trips on a fixture; the cron↔launchd
conversion proven by breaking (the weekday-numbering trap specifically). Consider
back-porting `schedule.sh` to thinklab.

## Phase 5 — light touches and library refresh

After phase 3 (needs the final names and shapes).

- `debugger` (2 refs), `checkpoint` rename (1 ref), `pack-format.md` touch-up.
- Repo-root `README.md` + `AGENTS.md` rewritten to the v2 inventory and vocabulary.

**Exit**: the dependency-check sweep from the spec re-run — zero v1-machinery references
outside `docs/design/` and `.scratch/`.

## Phase 6 — live deployment test (the finish line)

The test v1 never got. After everything above.

- **Greenfield**: `/clankshop setup` on a real new repo; work a change through the full
  line (design → build → test → review), chores scheduled via `scheduler`.
- **Brownfield**: `/clankshop migrate` on a legacy project with a `dev/` records root
  (declare-in-place, never a bulk `git mv`).

**Exit**: `check` green on both deployments; every friction point captured as feedback —
the first real input to the review station's improvement loop.

## Sequencing summary

```
1 (face + gate) ──► 2 (journal) ──► 3 (helpers) ──► 5 (refresh) ──► 6 (deploy test)
                                    4 (scheduler) ──────────┘
```
