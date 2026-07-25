# Workstream Compaction Survival — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `workstream` skill survive harness auto-compaction: a compacted session
re-orients from durable state instead of limping on a lossy summary.

**Architecture:** Three layers per `docs/design/2026-07-24-workstream-compaction-survival.md` —
a front-door recovery **anchor** (registered idempotently by `create` from a bundled template),
a **Scenario C** involuntary-reset ritual in `flow.md` (mirrored in the hand-off template's Loop
routine), and a **freshness** amendment (save at every feature-completion seam). All changes are
skill text (markdown); the gate is `skill-builder check` plus a fixture-based acceptance re-run.

**Tech Stack:** Markdown skill files; bash/tmux for the acceptance fixture.

## Global Constraints

- Commit style: imperative subject, `skills(workstream): ...` prefix, **no** AI-attribution
  trailers (user CLAUDE.md rule).
- Grimoire's history is public: no private project names or machine-specific paths in files or
  commit messages.
- Patient-zero caveat (grimoire `AGENTS.md`): the anchor must **never** be registered into
  grimoire's own `AGENTS.md`/front-door — fixture front-doors only.
- The design doc is the spec: `docs/design/2026-07-24-workstream-compaction-survival.md`. Verb
  files stay thin; doctrine lives in `flow.md`.
- Do not renumber `verbs/create.md`'s steps — `recycle.md` and the seed-only/in-place sections
  reference them by number ("steps 1–6 unchanged", "Skip steps 7–8").

---

### Task 1: `flow.md` — Scenario C + freshness amendments

**Files:**
- Modify: `skills/workstream/flow.md`

**Interfaces:**
- Produces: the section title **"Scenario C — involuntary reset (auto-compaction)"** and the term
  **"feature-completion checkpoint"** — Tasks 2, 4, and 5 reference both verbatim.

- [ ] **Step 1: Amend the reset-ritual intro** (save-justification + scenario count). Replace this
  paragraph (under `### Reset ritual — saves are coupled to the reset`):

```markdown
**A save is justified only by imminent context loss.** The *only* saves are (1) a user manually
invoking `save`, (2) the flow's single **pre-reset checkpoint**, and (3) `park`'s custody hand-over
(in-place streams — a parked stream may next be resumed by a *different* session, so parking without
saving would strand the loop's state; `verbs/park.md`). No other verb saves — `sync` rebases +
gates and nothing else; `ship` lands + advances and nothing else. Two scenarios (Scenario A/B describe
`delegate` mode; **`manual` mode adds a third, phase-boundary reset** at every PLAN/BUILD/SHIP seam —
see *Manual mode: the phase loop*):
```

with:

```markdown
**A save is justified by imminent — or unpredictable — context loss.** Harness auto-compaction
means loss can strike unannounced, so the saves are (1) a user manually invoking `save`, (2) the
flow's single **pre-reset checkpoint**, (3) `park`'s custody hand-over (in-place streams — a parked
stream may next be resumed by a *different* session, so parking without saving would strand the
loop's state; `verbs/park.md`), and (4) the **feature-completion checkpoint** — `save` fires at
every feature-completion seam (alongside debrief #1) even when no reset follows, bounding the
hand-off's staleness to one in-flight feature should a compaction strike. No other verb saves —
`sync` rebases + gates and nothing else; `ship` lands + advances and nothing else. Mid-feature
freshness is deliberately **not** solved by more saves: git commits + the on-disk plan carry it,
and Scenario C's reconcile recovers it. Three scenarios (A/B are `delegate` mode's deliberate
resets; C is the involuntary one; **`manual` mode adds a phase-boundary reset** at every
PLAN/BUILD/SHIP seam — see *Manual mode: the phase loop*):
```

- [ ] **Step 2: Make the between-landing-points save unconditional at the seam.** In Scenario A,
  replace:

```markdown
> **between landing points** (`milestone`/`per-track`, not yet a milestone):
> `debrief` #1 -> advance to the next feature *on the same branch* -> *(if context is heavy)* **save**
> -> reset -> `load`   *(no ship)*
```

with:

```markdown
> **between landing points** (`milestone`/`per-track`, not yet a milestone):
> `debrief` #1 -> **save** (the feature-completion checkpoint) -> advance to the next feature *on
> the same branch* -> *(if context is heavy)* reset -> `load`   *(no ship)*
```

- [ ] **Step 3: Insert Scenario C** immediately after the Scenario B block (after the paragraph
  ending "(Save-then-reset = checkpoint; reset-without-save = rollback to the last save.)"):

```markdown
**Scenario C — involuntary reset (auto-compaction).** The harness summarized your context mid-loop:
no save preceded it and no session boundary fired `load`. You detect it by the
compaction/continuation summary sitting where your conversation history should be (both Claude Code
and Codex leave one), or by the host front-door's recovery anchor pointing you here. Ritual:

> stop current work -> re-read `<worktree>/WORKSTREAM.md` in full -> re-read this `flow.md` -> run
> the hand-off's START HERE guard -> reconcile: `git -C <worktree> log` and the durable records
> (tracker files, the plan, `.records/`) are truth for everything committed; the compaction summary
> is truth only for in-flight intent — merge them -> continue the current task **without a user
> round-trip** if the next action is KNOWN.

The pre-compaction session already held its launch confirm — re-confirming after a compaction is a
nag, not a seam. Round-trip only if the reconcile surfaces genuine ambiguity (a real fork, or the
summary contradicting disk). This is `load`-lite: `load`'s resume discipline run in place, minus
the session-boundary mechanics and minus the launch-confirm seam.

**When compaction itself fails, treat it as a hard session boundary.** Two observed modes
(design doc, *Failure modes*): the summarizer **refuses** (content grounds; retries fail
deterministically) or **runs out of room** (small context windows; the session hard-stalls with a
"start a new thread" error, sometimes only after several successful compactions). Either way the
session is pinned at the limit: **save if the session can still act**, then reset / start a fresh
session and `load` — the hand-off + durable records carry the stream across. This is the classic
reset ritual, nothing new.

**Context-pressure warning = checkpoint cue.** If the harness surfaces a context-low warning,
treat it as Scenario B arriving early: run **save** proactively and recommend a reset — beat the
compactor to a clean checkpoint instead of gambling on the summary.
```

- [ ] **Step 4: Verify the edits landed coherently**

Run: `grep -n "Scenario C\|feature-completion checkpoint\|unpredictable" skills/workstream/flow.md`
Expected: the intro amendment, the Scenario A line, and the Scenario C section all present; no
remaining `Two scenarios` phrasing (`grep -c "Two scenarios" skills/workstream/flow.md` → 0).

- [ ] **Step 5: Commit**

```bash
git add skills/workstream/flow.md
git commit -m "skills(workstream): Scenario C involuntary reset + feature-seam saves in the flow" -- skills/workstream/flow.md
```

---

### Task 2: `verbs/save.md` — cadence doctrine

**Files:**
- Modify: `skills/workstream/verbs/save.md`

**Interfaces:**
- Consumes: Task 1's terms "Scenario C" / "feature-completion checkpoint" (must match verbatim).

- [ ] **Step 1: Replace the justification paragraph.** Replace:

```markdown
**A save is justified only by an imminent reset** (`flow.md` -> *Reset ritual* — read it if not
already in context): it exists to
survive a context reset, so the only saves are a user invoking `save` directly and the flow's single
pre-reset checkpoint. No other verb calls it.
```

with:

```markdown
**A save is justified by imminent — or unpredictable — context loss** (`flow.md` -> *Reset ritual*
— read it if not already in context): it exists to survive a context reset, and harness
auto-compaction (`flow.md` -> *Scenario C*) means loss can strike unannounced. The saves are: a
user invoking `save` directly, the flow's single pre-reset checkpoint, and the flow's
**feature-completion checkpoint** (fires at every feature-completion seam alongside debrief #1,
reset or not — bounding the hand-off's staleness to one in-flight feature). No other verb calls it.
```

- [ ] **Step 2: Verify**

Run: `grep -n "unpredictable\|feature-completion checkpoint\|Scenario C" skills/workstream/verbs/save.md`
Expected: all three present in the first paragraph.

- [ ] **Step 3: Commit**

```bash
git add skills/workstream/verbs/save.md
git commit -m "skills(workstream): save fires at feature seams — loss is now unpredictable" -- skills/workstream/verbs/save.md
```

---

### Task 3: bundled anchor template + `create` registration step

**Files:**
- Create: `skills/workstream/templates/compaction-anchor.md`
- Modify: `skills/workstream/verbs/create.md` (inside step 6 — do NOT renumber steps)

**Interfaces:**
- Produces: the template file path `templates/compaction-anchor.md` and its heading
  `## Workstream compaction recovery` (the idempotency grep key). Task 6's acceptance run
  registers this exact content.

- [ ] **Step 1: Create the bundled anchor template** with exactly this content (the design doc's
  narrowed three-clause block — no sentinel; that was spike scaffolding):

```markdown
## Workstream compaction recovery

Applies only when your context has just been compacted or summarized (you see a
compaction/continuation summary in place of the full conversation), and only to the tree your
working directory is inside (`git rev-parse --show-toplevel`):

- If `WORKSTREAM.md` exists at that tree's **top level**, you are the session driving that
  workstream — STOP before any further work: re-read it in full, reconcile it against the durable
  progress records it names, and only then resume from its recorded queue state.
- If instead a `.workstreams/<stream>/WORKSTREAM.md` under the top level records
  `isolation: in-place` **and** HEAD is on that stream's branch, the same applies — you are in the
  shared tree that stream holds.
- Hand-offs visible under `.workstreams/` from the root checkout otherwise belong to **other
  sessions'** worktrees: never read, load, or recover them.
```

- [ ] **Step 2: Add the registration sub-step to `verbs/create.md`.** Insert as a new bullet in
  step 6's sub-step list, immediately after the `worktree-exclude.sh` bullet (the one ending
  "...blocks a clean `git worktree remove`.)") and before the **Build the Cheat sheet** bullet:

```markdown
   - **Ensure the front-door recovery anchor — idempotently.** Check the host's always-loaded
     front-door doc (`AGENTS.md`, or `CLAUDE.md` where that is the host's front-door):
     `grep -q '^## Workstream compaction recovery' <root>/AGENTS.md` → present, no-op (the normal
     case after the first stream). Absent → **propose** appending this skill's bundled
     `templates/compaction-anchor.md` (resolve from the skill's own base directory, never a host
     path) to the front-door and, on the human's OK, commit it under the root-contention rules
     (stage + commit in one call, explicit pathspec): `git -C <root> add AGENTS.md && git -C <root>
     commit -m "Register workstream compaction-recovery anchor" -- AGENTS.md`. The block is generic
     convention text — one registration serves every stream forever (worktrees inherit it from the
     branch; in-place streams read it from the root). **Unattended or `--seed-only` create** → do
     not commit to the root: skip, and record `anchor: unregistered` in the hand-off's *Pointers /
     open questions* so the next attended session proposes it. (Why it matters: the front-door is
     re-injected every request in both harnesses, so this block survives compaction by construction
     — it is what points a compacted session back to the hand-off; `flow.md` -> *Scenario C*.)
```

- [ ] **Step 3: Verify placement and the seed-only carve-out**

Run: `grep -n "compaction-anchor\|anchor: unregistered" skills/workstream/verbs/create.md`
Expected: the sub-step sits inside step 6 (between the exclude bullet and the Cheat-sheet bullet);
seed-only text ("steps 1–6 unchanged") needs no edit because the sub-step itself carves out
seed-only/unattended.

- [ ] **Step 4: Commit**

```bash
git add skills/workstream/templates/compaction-anchor.md skills/workstream/verbs/create.md
git commit -m "skills(workstream): create registers the compaction-recovery anchor" -- skills/workstream/templates/compaction-anchor.md skills/workstream/verbs/create.md
```

---

### Task 4: hand-off template — Loop routine mirror + seam anchor line

**Files:**
- Modify: `skills/workstream/templates/workstream-handoff.md`

**Interfaces:**
- Consumes: Task 1's "Scenario C" section title and save-cadence wording (mirror, don't diverge).

- [ ] **Step 1: Add the seam anchor line rule.** In `## Loop routine`, append to the opening
  paragraph (after "...(`sync` and `ship` do not save).")

```markdown
**Every seam-status message leads with the anchor line** `WORKSTREAM <stream> — hand-off: <abs
path to this file>` — repeated, salient state a compaction summarizer reliably keeps, covering the
case where this file was last read long before the compaction.
```

- [ ] **Step 2: Mirror the feature-seam save.** Replace the between-landing-points bullet:

```markdown
- **Feature complete, between landing points (`milestone`/`per-track`, not yet a milestone):**
  `/backlog debrief` #1 -> advance to the next feature *on the same branch* (**no ship**; under `milestone`
  first *propose* a land if this looks like a natural milestone) -> *(if context heavy)*
  **`/workstream save`** -> reset -> `load`. Unshipped features stay on the branch for the next milestone.
```

with:

```markdown
- **Feature complete, between landing points (`milestone`/`per-track`, not yet a milestone):**
  `/backlog debrief` #1 -> **`/workstream save`** (the feature-completion checkpoint — fires at
  every feature seam, reset or not) -> advance to the next feature *on the same branch* (**no
  ship**; under `milestone` first *propose* a land if this looks like a natural milestone) ->
  *(if context heavy)* reset -> `load`. Unshipped features stay on the branch for the next milestone.
```

- [ ] **Step 3: Add the Scenario C bullet** after the "Context polluted" bullet in the
  Reset-ritual list:

```markdown
- **Context auto-compacted (involuntary reset — Scenario C):** a compaction/continuation summary
  sits where your conversation should be -> STOP -> re-read this WORKSTREAM.md in full -> re-read
  the skill's `flow.md` -> run START HERE -> reconcile against `git log` + the durable records
  (they outrank the summary for anything committed) -> continue **without a user round-trip** if
  the next action is KNOWN. If compaction itself **failed** (refusal or out-of-room — the session
  is pinned at the limit): save if still possible, then reset / new session -> `load`.
```

- [ ] **Step 4: Verify**

Run: `grep -n "Scenario C\|anchor line\|feature-completion checkpoint" skills/workstream/templates/workstream-handoff.md`
Expected: all three additions present; wording of "feature-completion checkpoint" matches Task 1.

- [ ] **Step 5: Commit**

```bash
git add skills/workstream/templates/workstream-handoff.md
git commit -m "skills(workstream): hand-off mirrors Scenario C + seam anchor line" -- skills/workstream/templates/workstream-handoff.md
```

---

### Task 5: `SKILL.md` — discipline pointer

**Files:**
- Modify: `skills/workstream/SKILL.md`

- [ ] **Step 1: Add one discipline bullet** at the end of the `## Discipline` list (after the
  "Gate before landing code..." bullet):

```markdown
- **Auto-compaction is an involuntary reset (Scenario C).** If your context has just been
  compacted/summarized mid-loop, stop and run `flow.md` -> *Scenario C*: re-read the hand-off +
  `flow.md`, reconcile against git and the durable records, then continue without a user
  round-trip if the next action is KNOWN. (`create` registers the host front-door anchor that
  points a compacted session here; a *failed* compaction is a hard session boundary — save if
  possible, reset, `load`.)
```

- [ ] **Step 2: Verify + lint-level sanity**

Run: `grep -n "Scenario C" skills/workstream/SKILL.md`
Expected: exactly the new bullet. The SKILL.md `description:` frontmatter is unchanged (routing
unaffected).

- [ ] **Step 3: Commit**

```bash
git add skills/workstream/SKILL.md
git commit -m "skills(workstream): discipline pointer to Scenario C" -- skills/workstream/SKILL.md
```

---

### Task 6: gate + acceptance

**Files:**
- Test: fixture under the session scratchpad (throwaway; never committed)

- [ ] **Step 1: Run the skill lint/boundary gate**

Invoke the `skill-builder` skill: `/skill-builder check workstream`.
Expected: gate passes; no boundary/lint findings on the five touched files. Fix any findings
inline and amend the relevant task's commit.

- [ ] **Step 2: Cross-file consistency sweep**

Run: `grep -rn "feature-completion checkpoint\|Scenario C" skills/workstream/`
Expected: identical phrasing everywhere (flow.md defines; save.md, SKILL.md, hand-off template
reference); no file still says a save is justified "only by imminent" loss.

- [ ] **Step 3: Acceptance — fixture re-run with the implemented anchor.** Build a throwaway
  fixture repo (scratchpad): `git init`; `AGENTS.md` = a one-line project blurb **plus the
  contents of `skills/workstream/templates/compaction-anchor.md`** (this is the "registered by
  the implemented create" state; registering by literally running the verb is optional);
  `CLAUDE.md` containing `@AGENTS.md`; a `WORKSTREAM.md` at tree top with a queue of 14 tasks
  ("read `data/big-N.txt` in full — page through with your file reader, text-processing shortcuts
  forbidden — find the `checkpoint-marker:` line, append `TASK-N: <token>` to `notes/log.txt`,
  strict order, one file per command"); 14 `data/big-N.txt` files of ~1800 lines of generated
  fake telemetry with one planted `checkpoint-marker: the checkpoint token for this file is
  CK<N>-<random>` line each (keep an answer key OUTSIDE the fixture). Benign prose only — random
  word-salad triggers summarizer refusals.
- [ ] **Step 4: Claude Code cell.** In tmux, run `claude --model claude-sonnet-5
  --permission-mode acceptEdits` in the fixture; kick off the queue; after 2 tasks send
  `/compact`, then bare `continue`. PASS = post-compact it resumes the correct next task with the
  correct token (transcript JSONL shows `compact_boundary` followed by correct work). Optionally
  probe: "quote the workstream recovery instructions verbatim" → block present.
- [ ] **Step 5: Codex cell.** Same fixture (fresh log), `codex --sandbox workspace-write`, same
  protocol. PASS = after `/compact` + `continue`, the agent cites the recovery rule, re-reads
  `WORKSTREAM.md` + `notes/log.txt`, resumes correctly. (Auto-compact S3 is optional — it burns a
  full window; the 2026-07-24 spike already passed it 3/3 plus a 3/3 small-model pass.)
- [ ] **Step 6: Record the result.** Append a one-line "Verification re-run: <date>, both cells
  pass" note to the design doc's *Verification* section and commit:

```bash
git add docs/design/2026-07-24-workstream-compaction-survival.md
git commit -m "docs(design): record compaction-survival acceptance re-run" -- docs/design/2026-07-24-workstream-compaction-survival.md
```

---

## Self-review notes

- Spec coverage: anchor (Task 3), Scenario C (Tasks 1, 4, 5), freshness (Tasks 1, 2, 4),
  failure modes (Task 1 step 3, Task 4 step 3), verification (Task 6). PreCompact hook:
  deliberately absent (design drops it). `/handoff`: deliberately untouched.
- Terms cross-checked: "Scenario C — involuntary reset (auto-compaction)",
  "feature-completion checkpoint", heading `## Workstream compaction recovery` used identically
  across tasks.
- create.md steps are not renumbered; the anchor step is a step-6 sub-bullet with its own
  seed-only/unattended carve-out, so "steps 1–6 unchanged" in seed-only mode stays true.
