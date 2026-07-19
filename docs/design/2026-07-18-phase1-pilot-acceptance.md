# Phase 1 — Pilot acceptance evidence

**Status:** Passed (2026-07-18). Deliverable of roadmap Phase 1
(`docs/design/2026-07-18-skill-self-initialization-roadmap.md`), proving the model in
`docs/design/2026-07-18-skill-self-init-model.md` §5 on two skill shapes before the tenet promotes to
`AGENTS.md` (Phase 2) and the lint gains the edge/no-sibling checks — *doctrine trailing reality by zero*.

**What this is.** The transcript + checklist backing the two pilots. The mechanism is *built and tested*
in grimoire but exercised only against **throwaway fixtures** under the scratchpad — grimoire's own
`AGENTS.md` is authored library doctrine and must never accrete self-registration blocks (model §3.2).
Re-run the transcripts by replaying the commands below against a fresh temp root.

---

## Pilot A — `backlog`, Layer 1 (core mechanism)

**Shipped:** `skills/backlog/verbs/init.md` (A1+A3), `skills/backlog/scripts/scaffold-records.sh` (A1),
`skills/backlog/scripts/register-route.sh` (A3), the `## Edges` section in `skills/backlog/SKILL.md`
(A2), and the `/backlog init` dispatch row + description update.

### A4 — idempotency + independence (fixture transcript)

Fixture: a temp project root with a hand-authored front-door doc carrying pre-existing content that must
survive registration verbatim.

- **A4.1 scaffold from empty** → `created=5` (`tasks.md`, `issues.md`, `feedback.md`, `notes/README.md`,
  `bugs/README.md`); the wider `.records/` tree (`plans/`, `archive/`, …) is *not* created — backlog
  makes only its own drawers. **No `/foreman` present or consulted** (bare-install proof).
- **A4.2 scaffold again** → `created=0 existed=5` — create-if-absent; a populated home is a no-op.
- **A4.3 register (section absent)** → `result=appended`: the `## Skill routes (self-registered)` section
  and the `skill:backlog` block are created; the authored front-door content is preserved above it.
- **A4.4 register again, same `built-against`** → `result=replaced`, and `diff` reports **byte-identical**.
- **A4.5 hand-add a sibling `skill:feature` block, re-init backlog with a fresh stamp** →
  `feature-block-intact: 1`, `feature-body-intact: 1`, `backlog-new-stamp: 1`, `backlog-old-stamp: 0`,
  `authored-line-intact: 1`. Backlog rewrites **only** its own delimited block; the sibling block and the
  composer-owned surrounding bytes are untouched (corollary 3, mechanical).
- **A4.6 malformed (one delimiter deleted)** → the writer prints
  `FAIL: … malformed (BEGIN=1, END=0); leaving file untouched` and exits non-zero — safe-by-default,
  never clobbers hand-broken content.

Final fixture front-door (both blocks, backlog's stamp refreshed):

```markdown
# AGENTS.md — fixture project front-door

Authored doctrine line the composer/human owns. Must survive registration verbatim.

## Build / test / run
- gate: `make check`

## Skill routes (self-registered)

<!-- skill:backlog BEGIN built-against:ffff999 -->
### /backlog — capture bureau
Route: file/sweep/curate follow-ups into `.records/` trackers. `/backlog task|bug|issue|note|feedback|debrief|curate`.
Edges: produces `tracker-entry`.
<!-- skill:backlog END -->

<!-- skill:feature BEGIN built-against:deadbee -->
### /feature — planning spine
Route: brainstorm/design/plan/build a feature to gate-green.
Edges: produces `plan`, `gate-green-code`.
<!-- skill:feature END -->
```

**Bug caught by the proof (kept as evidence the test earns its keep).** The first A4 run surfaced
`awk: newline in string` on the replace/append-in-section paths: BSD/macOS `awk` rejects a newline in a
`-v` variable value, so `register-route.sh` aborted *before* writing (the file was left untouched —
fail-safe, but the replace never happened). Fixed by passing the multi-line block through the
environment (`ENVIRON["BLK"]`) instead of `-v`. Re-run: all six A4 assertions pass. Portability note for
the roadmap: any future block-splicing helper must avoid multi-line `-v` under BSD awk.

---

## Pilot B — `feature`, Layers 2–3 (enrichment)

**Shipped:** `skills/feature/docs/ideal-use.md` (B1, the self-contained worked arc), the `## Edges`
section in `skills/feature/SKILL.md` (B2), `skills/feature/scripts/seed-templates.sh` (B3), the
`## templates` verb + resolution-order note in `design`/`plan` (B4), and the description update.

### B self-init (templates-as-seed) — fixture transcript

- **seed from empty** → `created=5` (`adr.md`, `plan-design.md`, `plan-implementation.md`, `roadmap.md`,
  `README.md`) into `<root>/.agents/feature/templates/`. **No `/foreman` present** (self-init, no floor).
- **edit an override, re-run** → `created=0 existed=5`, and the project's edit to `adr.md` is preserved
  (`override-preserved ✓`) — create-if-absent never clobbers a project override; re-run only backfills.

### B1/B2 — example + edges self-containment

- The `docs/ideal-use.md` arc ends on the typed edge `handoff: gate-green-code`, naming **no** successor
  skill; a composer supplies the consumer by matching the type.
- `## Edges` declares `produces: design, plan, gate-green-code`; `handoff: gate-green-code`;
  `consumes: design, plan`. The `design→plan→build` produces↔consumes pairs are **same-skill** and are
  documented as excluded from seam derivation (the composer must not draw a "feature → feature" arrow).

---

## §5.3 cross-pilot acceptance — the gate before Phase 2

| Criterion | Result |
|---|---|
| Both skills self-init their homes with **no `/foreman`** present | ✓ backlog `init` scaffolds `.records/`; feature `templates` scaffolds `.agents/feature/templates/` |
| Both declare `## Edges`; **starter-vocabulary strings match** where §2.2 predicts | ✓ `backlog.produces: tracker-entry` (consumer: foreman/backlog-curate); `feature.handoff: gate-green-code` (consumer: workstream-ship) |
| Registration is **idempotent** and **non-destructive** to sibling blocks | ✓ A4.4 byte-identical; A4.5 sibling block survives |
| **No leaf names a sibling** — grep the two skills' **edges + example** for a `/name` sibling slug | ✓ zero hits (backticked and bare) |
| `bash scripts/skills-lint.sh` → `fails=0` throughout | ✓ `fails=0 warns=9` |

**Known soft WARN (not a FAIL).** `backlog`'s description grew to **895 chars** with the self-init
clause, tripping the `>750 aim` WARN — squarely in the peer band (`architect` 943, `mailbox` 896,
`foreman` 845). Left as-is: trimming to chase a soft aim half the suite already exceeds isn't worth the
routing-clarity cost. Revisit if Phase 5's rollout pushes it toward the 1024 FAIL ceiling.

**Verdict:** Phase 1 acceptance met. The tenet may promote to `AGENTS.md` and the lint may gain the
edge/no-sibling checks in **Phase 2**.
