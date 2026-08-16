# Checkpoint refinement plan — 2026-08-15

**Status:** done (2026-08-15 — all six slices built; LP1 shipped at 225e379, LP2 ships the
rest; probe outcomes logged in `docs/boundary-audit.md`; the contrast-restore contingency was
not needed) · **Owner:** rev stream (unit 2) · **Target:** `skills/checkpoint/`
**Revised 2026-08-15** after a three-lens independent review (correctness skeptic:
needs-rework, narrow; groundedness + coverage/oracles: approve-with-changes). Every fold below
was re-grounded against the tree or executed before folding; the review's finding list is
summarized in *Review history* at the foot.

Refine the `checkpoint` skill from three independent agent reviews (Claude, Codex, Grok —
2026-08-15, machine-local untracked reports; verified findings restated inline, so this plan is
self-contained). Both reported script defects were reproduced before planning.

**Decisions settled with the owner (2026-08-15):**
1. **Full structural split** — thin `SKILL.md` router + a citable disciplines file + on-demand
   verb files.
2. **Description**: attempt a self-scoped rewrite; a fresh-sub-agent **routing probe gates the
   ship**. Fallback on a stream-case misroute: restore the contrast clause — recorded as a
   **documented exception** to `skill-builder/docs/BOUNDARY-AUDIT.md:50` ("sharper self-scope,
   never a restored cross-reference"): the north star gates on routing accuracy, and this
   misroute is *observed* (2026-08-14), not hypothetical. The exception and probe outcome land
   in `docs/boundary-audit.md` (the repo-root log, not skill-builder's bundled doc).
3. **Recovery anchor**: add an explicit **`anchor` action**; the save-time check stays and
   points at it.

**Global constraints (bind every slice):**
- Patient zero: mktemp fixtures only; prove every new check by breaking it; no `\b` in portable
  `grep -E`; bash-3.2-safe.
- **The frozen borrow surface is larger than the four discipline names.** Cross-skill citations
  that must survive the split verbatim (grep-verified 2026-08-15): the four discipline names
  (Save/Resume/Lifecycle/Recovery — including a lowercase "resume discipline" at
  `workstream/flow.md:249`, seven discipline sites total); the **anchor-line technique** name
  (`workstream/templates/workstream-handoff.md:134` + deployed hand-offs); the
  **recovery-anchor convention** name (`workstream/verbs/create.md:128`,
  `workstream/templates/compaction-anchor.md:3`); the **failed-compaction rule** label
  (`flow.md:253`); and the Lifecycle discipline's **checkpoint-moment ordinals** — "the third
  checkpoint moment" is cited (`flow.md:261`), so the three moments keep their number and
  order. Slice 6 verifies this surface **by re-running the grep** across `skills/`,
  `templates/`, and root `*.md` and opening each hit — never by asserting a fixed list.
- Ship cadence per-stage: **two landing points** (after S3; after S6) — the review killed the
  old LP2 (it shipped a longer SKILL.md immediately before the split shrank it, and left a
  procedural dead-end — see S1.2).
- Description budget: the lint measures the *value* (`len=${#desc}`): currently **748** of the
  750 aim — **2 chars of headroom**, so the rewrite is a from-scratch draft, not a trim; keep
  it colon-space-free or quoted (unquoted `": "` is a lint **FAIL**).

---

## Slice 1 — prose correctness (SKILL.md, no structure change)

1. **Invert the stale lint note** (edge section ~line 296): the BL-4 exclusion *covers* the
   `checkpoint-doc` intra-skill chain; **a `checkpoint-doc` WARN appearing means the pair
   broke** and is real. *(Verified against `skills-lint.sh:270-274` + clean runs.)*
2. **Resolve the resume contradiction — completely.** Resume stays strictly read-only;
   staleness is *reported* and, on the human's confirm, hands off to a separate `save`. Three
   companion edits the review showed are load-bearing, all in this slice:
   - **Ownership transfers with the transition** (kills the LP1 dead-end): completing Resume
     steps 1–2 plus the human's confirm **confers ownership**; the resume→save transition
     carries it, so save's foreign-checkpoint guard cannot fire against the session mid-resume.
   - **A refusal branch**: if the save is refused anyway (stream guard, tracked file), report
     the refusal and leave the file stale — disk remains truth for this session; no silent
     dead-end.
   - **Amend Done-when**: resume's bullet becomes "the file is untouched **by resume
     itself**; a confirmed stale-refresh is a separate `save` with its own done-when."
   Mirror the "trust disk, refresh **via `save`**" wording in the Lifecycle discipline's
   stale-file state (~line 106).
3. **Tracked-file collision + exclude resolution**: before writing the root file, a tracked
   `CHECKPOINT.md` (`git -C <root> ls-files --error-unmatch CHECKPOINT.md` succeeds) → STOP
   and surface (an exclude line cannot untrack). Resolve the exclude file via
   `git -C <root> rev-parse --git-path info/exclude` **and resolve the (possibly cwd-relative)
   result against `<root>`** before appending; re-check `check-ignore` after. The mechanics
   become *facts from S3's guard script*; the prose cites it. Fixtures live in S2/S3's suite.
4. **Normalize the edge-tenet citation** to the portable `docs/DOCTRINE.md` home — in
   checkpoint **and** the byte-identical blocks in `mailbox/SKILL.md:147` and
   `delegate/SKILL.md:244` (one-line edits; normalizing one alone would mint a third variant).

**Verify (a checklist, not "lint clean" — lint cannot see any of these prose edits):**
(a) grep proves the old "known false-positive" wording is gone; (b) a written three-way
consistency read of Resume discipline + procedure + Done-when, checking each of the three
companion edits landed; (c) the tracked/exclude mechanics deferred to S2/S3 fixtures are
named there. Lint runs too, as regression only.

## Slice 2 — `repo-snapshot.sh` hardening + fixture suite

1. **Branch fact, structurally single-line** (pattern executor-verified on unborn + detached
   fixtures 2026-08-15):
   `b="$(git -C "$root" symbolic-ref --short -q HEAD || true)"` — unborn branch prints its
   name, exit 0; `[ -n "$b" ] || b="$(git -C "$root" rev-parse --short --verify -q HEAD || true)"`
   — `--verify -q` emits **nothing** on failure (never the stray `HEAD` line the naive
   fallback reintroduces); `[ -n "$b" ] || b=unknown`. **Contract pinned:** always exactly one
   `branch=` line; a new `detached=true|false` fact (a bare sha in `branch=` reads as a branch
   name in document-structure §7 otherwise); fixtures pin expected values per case.
2. **SIGPIPE at the dirty-path cap**: replace `printf | head -20 | sed` with
   `awk 'NR<=20 { print "  " $0 }'` (consumes all input; no early-close under `pipefail`).
   Audit for other early-closing readers (none known — `git log … || echo` at :42 is safe).
3. **Fixture suite** at `skills/checkpoint/scripts/tests/` (the clankshop/journal harness
   shape: `lib.sh` + `snapshot-test.sh` + `run.sh`): non-repo, unborn (one branch line,
   `detached=false`, exit 0), normal, detached (`branch=<short-sha>`, `detached=true`), large
   dirty list (exit 0, capped). **Assertions normalize the non-deterministic fields**
   (`date=`, `%h` hashes) — match shape, not literals. Prove each by breaking (reintroduce
   the bug or plant a broken fixture → red).

## Slice 3 — mechanize the save guards + PACK seam

1. New self-contained **`scripts/save-guard.sh <dir>`** — facts, not verdicts; the refusal
   decision stays prose. Emits the stream facts (`worktree_stream=`, `inplace_stream=`,
   `inplace_branch_match=`, toplevel) **and the S1.3 write-guards facts**
   (`checkpoint_tracked=`, `checkpoint_ignored=`, `exclude_file=<absolute>`), so every
   mechanical pre-save check is one read with one canonical implementation. No dependency on
   the workstream skill; **canonical for checkpoint's prose sites** (workstream's own probe is
   out of scope and stays live — the wording must not claim library-wide canonicality).
2. Save step 1 shrinks to: run the script; refuse on a stream hit with the `/workstream save`
   pointer; refuse on `checkpoint_tracked=true`. The *Two layers* paragraph cites the script.
3. **PACK.md seam line**: one line naming the checkpoint/workstream seam (root-session
   save-state vs stream hand-off; canonical probe for checkpoint's sites =
   `save-guard.sh`). **Version: owner's call, proposed no bump** — PACK.md states no bump
   rule (the "member-set" rule is stream lore, not manifest text), and `install.sh` stamps
   `pack_version` into lock files, so a content edit under an unchanged `2.1.0` is the honest
   default; flag it in the ship summary.
4. Fixture coverage in the same suite (`save-guard-test.sh`): plain repo, worktree-stream,
   in-place (branch held / released), tracked-`CHECKPOINT.md`, linked-worktree exclude
   resolution — **plus a cross-skill fixture built from workstream's own
   `templates/workstream-handoff.md`**, so a workstream rename of `isolation:` /
   `.workstreams/` / the hand-off filename turns this suite red (the only check that actually
   closes the "canonical probe rots silently" finding). Each proven by breaking.

**Verify:** suite green (incl. the live positive: this worktree reports
`worktree_stream=true`); lint clean.

**→ LANDING POINT 1** (ship S1–S3: correctness + hardening, immediately valuable installed).

## Slice 4 — ownership + anchor model

1. **`anchor` action** (tiny): front door carries the block → say which file; absent →
   propose the copy-paste block as a one-off approved edit, apply on OK (committing stays the
   host's convention). Save step 6's warn ends "…run `/checkpoint anchor` to install it."
   **Authored move-aware**: written as a self-contained section at its final boundaries so S6
   cut-pastes it into `verbs/anchor.md` without rewriting.
2. **Ownership rules, compaction-proof — four, not three** (the review broke the three-rule
   version: a compacted session with no anchor that merely *sees* the file was pushed to
   "foreign" by rule 2, spawning the competing second file the guard exists to prevent):
   - Recovery confers ownership (a compacted session that finds the root file and runs the
     reconcile IS the owner);
   - reading-while-exploring is not resuming;
   - **foreignness requires positive evidence of another session** (content describing
     unrelated work, a different root) — a compacted session finding a checkpoint whose
     content matches its own in-flight work runs Recovery's reconcile rather than refusing;
   - the foreign guard's refusal is always surface-and-ask, never silent.
3. **Honest guarantee wording lives in the Recovery discipline text itself** (not the anchor
   section — S6 moves that to a verb file, and the discipline is what workstream's
   `flow.md:232` borrow actually reads): automatic compaction recovery is anchor-dependent;
   without the anchor the product is a resumable save-state.

**Verify — a real oracle, proven by breaking:** a fresh-sub-agent **scenario probe** (same
machinery as S5's routing probe): the rewritten ownership/guard text only + three scenario
prompts (compacted-with-anchor; compacted-without-anchor-but-file-discovered; fresh reader) +
expected verdicts. **Break-first:** run the probe against the *current* text first — it must
misjudge compacted-self-as-foreign; the rewrite must then pass all three. Outcomes recorded in
the plan's Review history.

## Slice 5 — description rewrite + routing probe (BEFORE the split's prose freeze)

*(Reordered ahead of the split: the probe settles the router's scope wording; running it after
the split would reopen the router on a case-(b) misroute.)*

1. Draft the self-scoped trigger (from scratch against the 750 budget; direction as before —
   scoped by artifact, no sibling named, compaction/recovery trigger phrases kept).
2. **Probe battery** (fresh sub-agent, descriptions only), pass = all route correctly:
   (a) "save a checkpoint", plain root session → checkpoint
   (b) "save a checkpoint", stream context stated in prompt → workstream save
   (b′) **the observed misroute**: no stream context in the prompt, cwd = root checkout, HEAD
   on a stream branch (in-place) → workstream save
   (c) "resume where we left off" post-compaction → checkpoint
   (d) "snapshot the repo state" → checkpoint (not journal)
   (e) a workstream-load prompt → workstream
   (f) "remember this for later" / "note this down" → backlog (checkpoint's When-to-use
   currently claims "I want to come back to this later" — the rewrite must cede this)
   (g) "close out / wrap up the finished work" → the done/debrief/ship triple resolves
   sensibly (checkpoint `done` only when a checkpoint file is the subject)
   (h) "save a checkpoint to `docs/foo.md`" → checkpoint (escape hatch); decoy "save this to
   the records" → journal/backlog
   (i) "write the result to a scratch file for the parent to pick up" → mailbox
   (j) "we're about to run out of context" → checkpoint
   (k) "write a handoff doc for the next session" → checkpoint (post-rename decoy)
   **Control run (break-first): the battery runs against the OLD description too** — cases
   (f)/(g) failing there and passing on the rewrite is the probe proving it can go red.
   Optional, non-gating: one behavioral case (mid-work transcript stub → does the agent
   save early unprompted?) — recorded as data for the follow-up below.
3. Misroute on (b)/(b′) → restore the contrast clause under the documented exception
   (decision 2), re-probe, log both runs in `docs/boundary-audit.md`.

## Slice 6 — the full split

Target shape: **`SKILL.md`** (thin router — journal's is the size model at ~1,230 words;
"well under half of 3,047" is asserted in the verify, not aspired to): description (from S5) +
overview; scope; When-to-use; Where-it-writes + guards summary (citing `save-guard.sh`); verb
dispatch table (`save`/`resume`/`done`/`anchor` → `verbs/<verb>.md`); the four discipline
names with one-line **non-normative** glosses + pointer; the **unprompted behaviors** block
(first-save-early, refresh at checkpoint moments, anchor-line leads every substantial status
message — promoted to a during-the-session rule); edges. **`references/disciplines.md`** —
the citable export (four disciplines in full, authority order, both techniques; **not** a
bare-root file: `references/` is inside lint's `bundle_prefixes`, a bare `disciplines.md`
would be lint-invisible). **`verbs/save.md`** (procedure + document structure — with a
**required/optional heading tier**: a minimal mid-session subset (TL;DR, What's been done,
What's pending, Repo state, first action) vs the full-save set, resolving the
twelve-headings-vs-synthesize tension instead of relabeling it), **`verbs/resume.md`**,
**`verbs/done.md`**, **`verbs/anchor.md`** (S4's section, cut-paste). Recovery lives whole in
the disciplines file. **Routing-prose trim, itemized** (the review's four surviving sites):
the When-to-use workstream redirect (:50-51) shrinks to one clause; the bare-word suggestion
(:70) keeps the workstream pointer minimal; the explicit-path freshness caveat (:61-67) keeps
its rule, loses the sibling essay; the `/workstream create` anchor note (:257) compresses to
one line in `verbs/anchor.md`. One **normative** home per fact; router glosses are pointers.

**Deliberate no (recorded):** no red-flag/rationalization tables — the library has no such
convention; the unprompted-behaviors block is the enforcement surface. A behavioral pressure
test of unprompted early save + anchor-line usage is a **follow-up**, not this unit (S5's
optional case gathers first data).

**Verify (the battery the review demanded):** (a) lint clean incl. bundled-ref resolution;
(b) **coupling grep re-run** (global constraints list) with every cited site opened and read;
(c) **inventory diff**: every heading and named rule in today's SKILL.md appears in exactly
one normative home in the new layout (a written table, not an impression); (d) router word
count ≤ ~1,500 asserted by `wc -w`; (e) the S2+S3 fixture suites green; (f) a fresh-agent
**navigation probe**: given only the router, locate the save procedure and name the four
disciplines; (g) grep the library for `checkpoint/SKILL.md:` line-anchored citations (zero
known outside this plan — cheap insurance, promoted out of Risks); (h) the seven-plus
borrow-site grep from the global constraints, one final time post-move.

**→ LANDING POINT 2** (ship S4–S6; unit complete, debrief).

---

## Explicitly out of scope

- Workstream's own guard/anchor registration and its probe copy (S3's fixture makes a rename
  visible; fixing one is a new unit).
- A registration/`register-route` revival.
- Legacy `HANDOFF.md` migration.
- The behavioral pressure test of unprompted saves (follow-up; S5 gathers first data).

## Risks

- **Routing regressions** from the description rewrite — mitigated: probe gates the ship,
  break-first control run, recorded fallback (documented exception).
- **2-char description headroom** — the rewrite is from-scratch; the lint FAIL on unquoted
  `": "` binds the draft.
- **The frozen borrow surface** is verified by grep, but a *semantic* drift (a discipline's
  meaning changing under a borrow site) is judgment — the S6 site-open read is the control.

## Review history (2026-08-15 independent three-lens review)

- **Correctness skeptic — needs-rework (narrow), all must-fixes folded:** coupling inventory
  was false (→ frozen-surface list + grep verification); LP1 shipped an ownership dead-end
  (→ ownership-transfer clause moved into S1.2); no refusal exit on the resume→save
  transition (→ S1.2 refusal branch); Done-when still contradicted (→ amended); ownership
  rules left the compacted-no-anchor hole (→ fourth rule); naive branch fallback could
  reintroduce the two-line bug (→ `--verify -q` pattern, executor-verified); bare-root
  disciplines file lint-invisible (→ `references/`); `--git-path` cwd-relativity (→ resolve
  against root); anchor-honesty clause in a file the borrow never reads (→ into the
  discipline); "canonical" overclaim (→ scoped); 762→748 (→ headroom framing).
- **Groundedness — approve-with-changes, all folded:** description is 748 (value, not line);
  PACK.md has no bump rule (→ owner's call); a seventh lowercase borrow site
  (`flow.md:249`); zero external line-anchored citations (churn risk retired);
  mailbox/delegate carry byte-identical edge citations (→ S1.4 widened); journal is the
  router-size model; boundary-audit path qualified.
- **Coverage/oracles — approve-with-changes, all must-fixes folded:** S5(now S6) had no
  verify (→ battery a–h); S4's desk-check was self-graded (→ break-first scenario probe);
  tracked-file guard needed red-able fixtures (→ S3 facts + suite); probe battery expanded
  (b′, f, g, h, i, j, k + control run); the contrast-restore fallback recorded as a
  documented exception; LP2 double-write killed (→ two landing points, S4 authored
  move-aware); probe reordered before the split's prose freeze; G7 heading tiers; G4
  deliberate-no recorded.
