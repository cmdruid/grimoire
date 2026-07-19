# Phase 4 — `/foreman` Re-scope (bootstrapper/stamper → composer/extractor/drain)

**Status:** Implemented (2026-07-19, shipped at milestone #2 `1abad3c`). Deliverable of **Phase 4** of
`docs/design/2026-07-18-skill-self-initialization-roadmap.md`, consuming **Phase 3**'s disposition
table (`docs/design/2026-07-19-phase3-skill-dispositions.md`, especially **F4** and the §5 type-pairing
table) and settling the questions the model doc (`docs/design/2026-07-18-skill-self-init-model.md`) §4
deferred here. Flagged by the roadmap as the **highest-stakes verb change** — treat like `migrate`.
Landed in `skills/foreman/{BOOTSTRAP.md,SKILL.md,verbs/{init,check,calibrate}.md,scripts/foreman-health.sh}`;
this doc stays as the historical record of the redesign's reasoning.

**What this doc is.** The concrete redesign of `/foreman`'s four re-scoped responsibilities: (1) **init's
per-skill dispatch** — who scaffolds what once skills self-init; (2) **edge-matching seam derivation** —
the algorithm and where it runs; (3) **projection write/validation** — `check`'s promotion from baseline
to primary, and the concrete on-disk seam-annotation format; (4) the **seed-vs-record** disposition for
`calibrate`'s drained doctrine. It also fixes **skill discovery** — a gap the current verbs assume but
never specify.

**What it is not.** It does not touch `/foreman route` (the bug/patch/feature/spike change-router) —
that classification is orthogonal to self-init and is unchanged (see §5). It does not re-author
`migrate`'s locate→classify→confirm→relocate flow (§6 notes the one place it interacts). It does not
implement Phase 5's actual per-skill edge blocks — those are rolled out skill-by-skill in Phase 5,
foreman last (F4).

---

## 1. Recap — why `/foreman` re-scopes

Pre-self-init, `/foreman init` was a **bootstrapper**: it scaffolded every skill's home directly (the
whole `.records/` tree, every seed under `.agents/`) from its own bundled `BOOTSTRAP.md` manifest, because
nothing else could. Post-self-init (Phase 1–3 landed, Phase 5 rolls it out), each durable-home skill
scaffolds **its own** home with no floor (corollary 1) and registers **its own** route (corollary 2).
`/foreman`'s job shrinks to what only a composer can do — see the four skills below, none of which any
individual skill can do for itself without naming siblings (which the tenet forbids):

1. **Dispatch** — at `init` time, hand each skill's home-scaffolding to that skill's own `init`, falling
   back to legacy scaffolding only for skills not yet converted (§2).
2. **Derive seams** — match one skill's `handoff`/`produces` edges against another's `consumes` edges,
   without either skill naming the other (§3).
3. **Validate the projection** — confirm the front-door doc's `## Skill routes (self-registered)` section
   still reflects the installed skills and their current edges; flag drift (§4).
4. **Drain accumulated signal into doctrine** — already `calibrate`'s job; §7 settles *where* the drained
   content lives.

Everything below is the concrete mechanism for these four. `/foreman` remains **optimization, not
dependency** (corollary 4) throughout: every step here has a stated "and if this isn't run, the skill
still functions bare" — re-affirmed per-section, not just asserted once.

---

## 2. Skill discovery (a gap the current verbs assume but never name)

Before dispatch, derivation, or validation can run, `/foreman` must answer "what skills are installed?"
— and no current verb specifies *how*. Fix it:

- **Resolution order** (parameterized, never hardcoded — same discipline as the front-door path, model
  §3.2): (1) an explicit `<skills-root>` the user names; (2) `~/.claude/skills/` if it exists (the
  Claude Code install target — `install.sh`'s default); (3) a dir-scanning harness's own skills root, if
  the conversation names one (Codex-style: point the harness at a dir directly, per `install.sh`'s own
  comment); (4) ask.
- **A skill is "installed"** if `<skills-root>/<name>/SKILL.md` exists. Grimoire's own `skills/` (the
  library clone) is a **source**, never a discovery target for a deployed project's `init`/`check` —
  those introspect the **consuming project's** resolved skills root, exactly as `register-route.sh`
  never writes to grimoire's own `AGENTS.md` (patient-zero, model §3.2).
- **Record the resolved root** in the same stamp `init` already writes (verbs/init.md step 9) so
  `check`/`calibrate` reuse it without re-asking.

This is a one-line addition to the existing stamp, not a new artifact — but it must be **explicit**,
because §3–§4 both depend on it and neither can function against an unresolved root.

---

## 3. Init's per-skill dispatch (the "route dispatch model")

**Terminology note.** The hand-off's "route dispatch model" phrasing risked conflating this with
`/foreman route` (the bug/patch/feature/spike change-router, `verbs/route.md`) — **it does not touch
that verb**. This section is about a different dispatch: at **`init`/`migrate` time**, which party
scaffolds a given skill's home. Renamed here to avoid the collision.

### 3.1 The dispatch rule (keyed on Phase 3's F1 tiers)

For each installed skill, per `docs/design/2026-07-19-phase3-skill-dispositions.md` §4 F1:

| tier | skills (today) | `init`'s action |
|---|---|---|
| **durable-home, self-init present** | `backlog` (done); `feature`/`architect`/`auditor`/`foreman` once Phase 5 lands their own `init`/`deploy` verb | **dispatch** — invoke the skill's own init verb (or, if running as a human-directed session rather than a script, instruct: "run `/backlog init`"). `/foreman init` does **not** write that skill's `.records/`/`.agents/<skill>/` files directly. |
| **durable-home, self-init not yet landed** | any durable-home skill mid-Phase-5 rollout | **legacy fallback** (§3.2) — `init` scaffolds it directly, exactly as today, so a partially-migrated fleet still reaches a complete, `check`-valid state. |
| **in-place steward** (no private home) | `chiropractor` | **no scaffold** — nothing to create. |
| **scratch-only** (gitignored, lazily created) | `workstream`, `handoff`, `mailbox` | **no scaffold** — the skill creates its own scratch dir on first use; `init` does not pre-create it. |
| **pure mechanism** (no storage) | `delegate` | **no scaffold.** |

`init` **always** retains: creating the `.agents/` root directory itself (so self-initializing seed
skills have a place to land their own homes — it does not populate them), writing the **ownership
index** (`.agents/README.md` + `.records/README.md`), wiring `AGENTS.md`'s *Build/test/run* section +
composition list, wiring the linter, and the version/skills-root stamp (§2, §9 of `verbs/init.md`
unchanged).

### 3.2 The legacy fallback is temporary — mark it, don't hide it

Until every durable-home skill lands its own `init` (Phase 5, foreman last per F4), `/foreman init` keeps
its current scaffold code as a named **fallback path** — not deleted, not silently kept as the default.
Concretely: `verbs/init.md` gets a clearly delimited **"Legacy scaffold (pre-Phase-5 compatibility,
remove in Phase 6)"** subsection wrapping the existing step-2/3 `.records/` + seed scaffolding, entered
only for skills the dispatch table (§3.1) resolves to "not yet landed." This keeps the removal
mechanical and reviewable later rather than a doc-archaeology exercise — **no silent caps**: `init`'s
report names which skills it dispatched to vs. which it fell back to scaffolding itself, so a
partially-migrated fleet is visible, not silently uniform.

**Why not delete it now?** Only `backlog` has landed self-init; `feature`/`architect`/`auditor`/`foreman`
have not (Phase 5). Deleting the fallback today would break `init` on eight of ten skills. This is the
`migrate`-reuses-`init`'s-scaffold pattern (`verbs/migrate.md` §"What this reuses from init") generalized
one step further: both `migrate`'s gap-fill and `init`'s legacy-fallback are the *same* code path,
entered for *different* reasons (brownfield gap vs. not-yet-self-initializing) — `migrate` already reuses
`init` verbatim, so this doesn't add a second scaffold implementation, only a second **reason** to enter
the existing one.

---

## 4. Edge-matching seam derivation

### 4.1 The algorithm (model §2.1, made concrete)

Given the set of installed skills (§2) and each one's parsed `## Edges` block (delimiters
`<!-- edges:<name> -->` … `<!-- /edges:<name> -->`, format per model §2.3 — the **same** format
`scripts/skills-lint.sh` check 8 already parses for grimoire's own skills):

```
for each skill S: parse {produces: [T...], consumes: [T...], handoff: [T...]}   (empty edges = "—", skip)
for each type T seen anywhere:
  H = {S : S.handoff includes T}
  P = {S : S.produces includes T}
  C = {S : S.consumes includes T}
  for A in H, B in C, A != B:              emit SEAM   A -> B  (T)   # control-flow arrow
  for A in P, B in C, A != B, (A,B,T) not already a SEAM:
                                            emit DEP    B reads A's T # dependency line, no control
  # A == B pairs (same skill on both ends) are EXCLUDED — F2's intra-skill-chain rule
  # (feature's design->plan->build; handoff's save->resume)
  # unmatched produces/consumes/handoff are legal: no arrow, not an error
```

This is **exactly** model §2.1's matching rule plus F2's exclusion, stated as pseudocode so an
implementation is unambiguous. It never invents a type or infers intent beyond string equality — types
are matched **exactly**, per the open, string-typed vocabulary (model §2.2).

### 4.2 Where it runs, and as what

**A read-only fact script**, not a verdict — same doctrine as `foreman-health.sh`'s existing
subcommands. Add a new subcommand: `foreman-health.sh derive-seams <skills-root>`. It emits:

```
seam: backlog -> foreman (tracker-entry)
dep:  feature -> workstream (plan)          # workstream consumes what feature produces, no handoff
seam: feature -> workstream (gate-green-code)
dep:  architect -> workstream (roadmap)
dep:  auditor -> foreman (audit-finding)
excluded: feature design->plan (intra-skill, produces+consumes both feature)
excluded: handoff handoff-doc (intra-skill, produces+consumes both handoff)
orphan: handoff-doc (single skill: handoff)   # informational, mirrors lint's orphan WARN
```

The verb prose (`check`/`init`) reads these facts and **writes** the seam annotations (§4.3) — the
script never touches a file. This is the same facts-not-verdicts split every other `foreman-health.sh`
subcommand already follows (`SKILL.md` → *Shared discipline*), extended to composition instead of
drift-detection.

**Why not reuse `skills-lint.sh`'s parser verbatim?** They parse the *identical* block format but at two
different lifecycle stages, over two different roots: `skills-lint.sh` is grimoire's own **dev-time
gate**, walking the library clone's `skills/` to catch a malformed block before it ships; `derive-seams`
is the **deployed runtime composer**, walking a consuming project's resolved skills root (§2) to wire
seams. Grimoire never introspects itself as a "deployed project" (patient-zero), and the deployed script
must be self-contained inside the shipped `foreman` skill bundle — sharing one bash source file across a
dev-only gate and a shipped skill would cross exactly the packaging boundary *"harness-agnostic
packages; harness-specifics at the edge"* warns against. Accept the small duplication (~30 lines each);
what must **not** drift is the **parsing contract** both honor — delimiter format, edge-kind vocabulary,
type-is-a-plain-string, `/`-prefixed values are sibling names not types. Filed as a maintainer follow-up
(§9) so a future change to one parser prompts a check of the other.

---

## 5. Projection write/validation — `check`'s promotion to primary

### 5.1 The concrete seam-annotation format

Model §3.4 fixed the **content-vs-arrangement split** (skill owns its own delimited block; composer owns
everything around the blocks, including derived seam annotations) but never specified the annotation's
on-disk shape. Fixed here:

```markdown
<!-- skill:feature END -->

<!-- seam: feature -> workstream (gate-green-code) derived-by:foreman built-against:<skills-root-stamp> -->
→ feature's `handoff: gate-green-code` is read by workstream's `consumes: gate-green-code`.
<!-- /seam: feature -> workstream (gate-green-code) -->

<!-- skill:workstream BEGIN built-against:... -->
```

Properties, deliberately **simpler** than the skill-block protocol:

- **Delimited** (`<!-- seam: A -> B (T) -->` … `<!-- /seam: A -> B (T) -->`) so it's machine-findable,
  same idiom as skill blocks.
- **Fully composer-owned, never hand-edited, no preserve-across-runs need.** Unlike a skill's own block
  (which must survive a sibling's re-`init` untouched, model §3.4), a seam annotation carries **no**
  authored content a human or skill would hand-edit — it is 100% derived from the two skills' edges. So
  `check`/`init` **delete every existing `<!-- seam: ... -->` block in the section and rewrite them all
  fresh** each pass, rather than running the replace-between-delimiters idempotency protocol skill blocks
  need. This is simpler *because* it's pure derivation with zero hand-authored content to protect —
  the one asymmetry between skill blocks and seam annotations worth stating explicitly, since it would be
  easy to over-engineer a second idempotent-write protocol here that the content doesn't warrant
  (*lightweight over configurable*).
- **`dep:` lines (produces↔consumes, no handoff) are not written as annotations by default** — a mere
  dependency without control-flow is lower-signal than a seam; `check` reports it as a fact in its own
  output (§5.2) but does not clutter the front-door doc with it. If this proves wrong in practice (a
  project wants dependency lines surfaced too), that's a `calibrate` doctrine tweak, not a Phase 4 default.

### 5.2 `check`'s new primary job

`verbs/check.md` gains a new pass, run **before** the existing `stale-refs`/`coverage` pass (which stays
unchanged — it validates the *docs* half; this validates the *projection* half):

```bash
bash <skill-dir>/scripts/foreman-health.sh derive-seams <skills-root>
bash <skill-dir>/scripts/foreman-health.sh check-projection <front-door> <skills-root>
```

`check-projection` (a new subcommand) is **read-only** and emits:

| fact | means |
|---|---|
| `registered: <name>` | a `skill:<name>` block exists in the front door |
| `unregistered: <name>` | the skill is installed + is register-worthy (durable-home/steward tier, F3) but has **no** block — should self-`init` |
| `orphaned: <name>` | a `skill:<name>` block exists but the skill is **no longer installed** at the resolved root |
| `stale-stamp: <name> built-against=<old> now=<new>` | the block's stamp doesn't match the skill's current version — the skill changed since it last registered |
| `seam-drift: missing <A> -> <B> (<T>)` | `derive-seams` found this seam but no annotation exists |
| `seam-drift: stale <A> -> <B> (<T>)` | an annotation exists for a seam `derive-seams` no longer finds (an edge changed) |

**The verb prose still decides**, exactly as `check.md`'s existing doctrine states: `unregistered` on a
plumbing-tier skill (F3: delegate/mailbox skip registration) is **not** drift, it's correct; `orphaned`
on a skill temporarily uninstalled is a judgment call (prune, or leave as a pointer for when it returns)
— `check` flags, it does not auto-prune (safe-by-default, consistent with `register-route.sh`'s
malformed-block handling). Fixing `seam-drift` (both directions) **is** mechanical — re-run the rewrite
in §5.1 — so `check` may offer to do that part directly (it is pure regeneration, not an edit to
hand-authored content), while `unregistered`/`orphaned` route to a human decision or `calibrate`.

### 5.3 Section-ownership contract — now written down, not just implied

Today **no verb file states** the content-vs-arrangement split (model §3.4) as an operational rule —
only the model doc has it. Fix: `verbs/init.md` and `verbs/check.md` both get a short **"Section
ownership"** callout: *`init`/`check` may reorder skill blocks, regroup them, and rewrite seam
annotations wholesale; they must never edit a byte inside another skill's `skill:<name>` delimiters.* This
mirrors `register-route.sh`'s own header comment (already correct) — the gap was in the **verb
prose** an agent actually reads mid-task, not the mechanism. `BOOTSTRAP.md` gets the same callout in its
§4.1 (ownership index) discussion, since that's the deployed doc a project's own agents read.

---

## 6. `migrate`'s one touch-point

`migrate`'s brownfield relocation (§6 of `verbs/migrate.md`) is unaffected in its locate→classify→
confirm→relocate front half. Its **back half** ("scaffold the gaps + write the index," step 6) already
says "reuses `init`'s scaffold verbatim" — that phrase now means **§3's dispatch table**, not the old
uniform scaffold: a migrated project's durable-home skills that have landed self-init get **dispatched**
to their own `init`, exactly as a greenfield `init` would, and only genuinely gap-filled homes (nothing
migrated *and* no self-init landed yet) take the legacy path. No wording change needed in `migrate.md`
beyond this doc existing as the referent — `migrate.md`'s existing "read `verbs/init.md`... apply it"
instruction already delegates correctly; it inherits §3 automatically once `init.md` is edited.

---

## 7. Seed vs. record for drained doctrine — settled

**The open question** (model §4): does `calibrate`'s promoted content belong in `.agents/foreman/`
(seed — hand-curated, small, stable) or `.records/docs/foreman/…` (record — grows with the code)? The
roadmap leaned record without committing.

**Resolution: the doctrine stays a seed; the *log of calibration runs* becomes a new record.** These are
two different artifacts the open question conflated:

- **Drained doctrine** (`MEMORY.md`, `GOTCHAS.md`, `DEVELOPMENT.md`/`WORKFLOWS.md`/`PLANNING.md` edits)
  is content **agents read as live instruction** — the same role `architect`'s design seed and
  `auditor`'s rubric already play. Instruction that agents follow must be curated, coherent, and
  relatively stable — the defining trait of a **seed** (`.agents/`), not an append-friendly growing log.
  `calibrate.md`'s existing behavior (promote into `.agents/foreman/MEMORY.md`/`GOTCHAS.md`/docs) is
  therefore **already correct** and needs **no change** — this was never actually in tension with the
  seed/record split; the roadmap's "leans record" instinct was reaching for something else.
- **What the roadmap's instinct was actually reaching for: a record of calibration *runs*.**
  `calibrate` currently has no durable trace of *what it did and when* — which signal it consumed, which
  doctrine line changed, which source entries it cleared. That trail is inherently append-only evidence
  (never re-read as instruction), which **is** the record shape. **New:** `calibrate`'s step 5 (Commit)
  gains a one-line addition — append a dated entry to `.records/logs/foreman-calibrate.md` (created on
  first use, per the existing `.records/logs/` slot already in the manifest — `BOOTSTRAP.md` §4,
  `packs/clankshop.md`'s layout table) summarizing the pass: which trackers were harvested, how many
  patterns became doctrine edits, which source entries were cleared. This gives calibrate the audit trail
  the "grows with the code" intuition wanted, without conflating it with the doctrine itself.

This resolves model §4's deferred row: **doctrine = seed (unchanged); calibration history = record
(new, `.records/logs/foreman-calibrate.md`)** — not an either/or on the same artifact.

---

## 8. What stays unchanged (stated explicitly so the diff is legible)

- **`/foreman route`** (the change-router) — untouched. Classification (bug/patch/feature/spike/
  seed-design) has nothing to do with who scaffolds a skill's home.
- **`/foreman calibrate`**'s core drain loop (harvest signal → doctrine edit → clear source) — unchanged
  except the one-line run-log addition (§7).
- **The edge vocabulary, block format, and registration protocol** (model §2–§3) — unchanged; Phase 4
  *consumes* them, it does not revise them.
- **`scoped-commit.sh` / the trunk-only, pathspec-atomic commit discipline** — unchanged; every new write
  this doc specifies (seam-annotation rewrite, run-log append) follows it.

---

## 9. Follow-ups filed

- **BL-5 (new, `docs/BACKLOG.md`)** — keep `skills-lint.sh` check 8's edge-block parser and
  `foreman-health.sh derive-seams`'s parser in sync (§4.2): a future change to the block format
  (delimiter syntax, edge-kind vocabulary) must update both; no shared library today, by design
  (dev-time gate vs. shipped runtime composer), so this is a **process** note, not a code fix.
- **Phase 5 inherits:** the §3.1 dispatch table names exactly which skills need their own `init`/`deploy`
  landed (`feature`, `architect`, `auditor`, `foreman` — foreman last, F4) before the legacy-fallback
  subsection (§3.2) can be deleted in Phase 6.
- **Phase 6 inherits:** delete `verbs/init.md`'s legacy-scaffold subsection once Phase 5 completes for
  all durable-home skills; reconcile `packs/clankshop.md`'s layout table with the new `.records/logs/
  foreman-calibrate.md` file.

## References

- `docs/design/2026-07-18-skill-self-initialization-roadmap.md` — the 8-phase queue (Phase 4 = this).
- `docs/design/2026-07-18-skill-self-init-model.md` — §2 edges, §3 registration, §4 hard parts (this doc
  settles the seed-vs-record row).
- `docs/design/2026-07-19-phase3-skill-dispositions.md` — F1 (self-init tiers, §3.1's table), F2
  (intra-skill exclusion, §4.1), F3 (registration tracks captured items, §5.2's `unregistered` judgment),
  F4 (foreman dual-role + sequencing, throughout), §5 (the type-pairing table §4.1's algorithm produces).
- `skills/foreman/verbs/init.md`, `verbs/check.md`, `verbs/calibrate.md`, `verbs/migrate.md`,
  `BOOTSTRAP.md` — the verbs this doc re-scopes (edits land in the same commit/PR as this doc).
- `scripts/skills-lint.sh` check 8 — the dev-time parser `derive-seams` deliberately does not share code
  with (§4.2), but must stay format-compatible with.
