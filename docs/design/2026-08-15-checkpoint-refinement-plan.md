# Checkpoint refinement plan — 2026-08-15

**Status:** open · **Owner:** rev stream (unit 2) · **Target:** `skills/checkpoint/`

Refine the `checkpoint` skill from three independent agent reviews (Claude via
`/skill-builder check`, Codex, Grok — 2026-08-15, machine-local untracked reports; their
verified findings are restated inline below, so this plan is self-contained). All load-bearing
claims were re-verified against the live tree before planning; both reported script defects
were **reproduced** (unborn-repo `branch=HEAD` + stray `unknown` line; exit 141 SIGPIPE on a
~3000-file dirty list).

**Decisions settled with the owner (2026-08-15):**
1. **Full structural split** — thin `SKILL.md` router + `disciplines.md` (the citable export) +
   on-demand verb files, the workstream/journal shape.
2. **Description**: attempt a self-scoped rewrite (no sibling named); a fresh-sub-agent
   **routing probe gates the ship** — if the "save a checkpoint inside a stream" case
   misroutes, restore the contrast clause and re-probe.
3. **Recovery anchor**: add an explicit **`anchor` action** (propose the front-door block as a
   one-off approved edit); the save-time check stays and now points at it.

**Global constraints (bind every slice):**
- Patient zero: exercise everything against mktemp fixtures; never deploy into grimoire itself.
- Prove every new check/fixture by breaking it (planted-input red before trusted green).
- No `\b` in portable `grep -E`; bash-3.2-safe; macOS TMPDIR trailing slash.
- The four discipline **names** are load-bearing API — `workstream` cites "Save/Resume/
  Lifecycle/Recovery discipline" by name at `verbs/load.md:23`, `verbs/save.md:17`,
  `flow.md:184/232/252/261`. The split may move their home; it must not rename them, and
  SKILL.md must keep one-line glosses so borrow sites still degrade gracefully.
- Ship cadence per-stage: three landing points (after S2, S4, S6) — revisions are inert until
  landed (installed symlinks resolve to the root clone).

---

## Slice 1 — prose correctness (SKILL.md, no structure change)

1. **Invert the stale lint note** (edge section, ~line 296): the lint's BL-4 exclusion
   *covers* the `checkpoint-doc` intra-skill chain — replace the "legitimately WARNs / known
   false positive" paragraph with: the exclusion applies; **a `checkpoint-doc` WARN appearing
   means the pair broke** (e.g. an edge-block typo) and is real. *(Claude #1 / Codex #7;
   verified against `skills-lint.sh` BL-4 and this session's clean runs.)*
2. **Resolve the resume contradiction** *(Codex #1)*: Resume stays **strictly read-only** —
   the discipline's "rewrite nothing" and Done-when's "file untouched" govern. Resume step 3's
   stale-file handling becomes: **report** the discrepancy (file vs disk), and on the human's
   confirm, **transition into a separate `save`** — the refresh happens under save's own
   procedure (stream guard, foreign guard, ignore check included), never inside resume.
   Mirror the same wording in the Lifecycle discipline's "stale" qualified state ("trust disk,
   refresh **via `save`**").
3. **Tracked-file collision guard** *(Codex #3)*: in the ignore-check paragraph — before
   writing the root file, first check the path is not **tracked**
   (`git ls-files --error-unmatch CHECKPOINT.md` succeeds → STOP and surface; an exclude line
   cannot untrack a file, and a deleted-but-tracked one could be silently recreated). Resolve
   the exclude file via `git rev-parse --git-path info/exclude` (never assume `.git` is a
   directory — worktrees), and **re-check** `check-ignore` after appending.
4. **Normalize the edge-tenet citation** *(Claude #4)*: cite the typed-edge tenet's portable
   home (skill-builder's `docs/DOCTRINE.md`) with the library design doc as historical
   reference, matching skill-builder's own citations.

**Verify:** skills-lint clean; re-read Resume procedure + discipline + Done-when together for
consistency (the contradiction class).

## Slice 2 — `repo-snapshot.sh` hardening + fixture suite  *(Codex #2 / Grok "no tests")*

1. **Unborn-repo branch fact**: capture and test in one step — prefer
   `git symbolic-ref --short -q HEAD` (works on an unborn branch, prints the branch name;
   fails on detached HEAD → fall back to `rev-parse --short HEAD`, else `unknown`) so the
   output is always exactly one `branch=<value>` line.
2. **SIGPIPE at the dirty-path cap**: replace `printf | head -20 | sed` with a reader that
   consumes all input (`awk 'NR<=20 { print "  " $0 }'` or `sed -n '1,20p'` + prefix) — no
   early-closing pipe under `pipefail`. Audit the script for other early-exit pipe readers.
3. **Fixture suite** at `skills/checkpoint/scripts/tests/` (mirror the clankshop/journal
   harness shape: `lib.sh` + `snapshot-test.sh` + `run.sh`, mktemp fixtures): cases — non-repo
   dir, unborn repo (exactly one branch line, exit 0), normal repo (facts match a known
   fixture), large dirty list (exit 0, capped output), detached HEAD. **Prove by breaking**:
   re-introduce each bug (or plant a broken fixture) and demand red before trusting green.

**Verify:** suite green; both original repros now pass; skills-lint clean (script syntax).

## Slice 3 — mechanize the stream guard  *(Codex #4 / Claude #3)*

1. New self-contained `scripts/stream-guard.sh <dir>` — facts, not verdicts (the refusal
   decision stays in prose): `is_git_repo=`, `toplevel=`, `worktree_stream=` (a
   `WORKSTREAM.md` at toplevel), `inplace_stream=<name|none>` (a
   `.workstreams/<stream>/WORKSTREAM.md` under toplevel recording `isolation: in-place`),
   `inplace_branch_match=` (HEAD equals that stream's recorded branch). No dependency on the
   workstream skill — the probe is duplicated **by design**, and this script becomes the
   **canonical copy** the prose sites cite.
2. Save step 1's guard prose shrinks to: run the script, refuse on a hit, pointer to
   `/workstream save`. The *Two layers* paragraph cites the script as canonical.
3. **PACK.md seam line** (all three reviews): one line in the clankshop pack manifest naming
   the checkpoint/workstream seam — root-session save-state vs stream hand-off; canonical
   probe = checkpoint's `stream-guard.sh`. (Member set unchanged → no version bump.)
4. Extend the fixture suite: plain repo (no stream), worktree-stream fixture, in-place fixture
   (branch held and branch released), each proven by breaking.

**Verify:** suite green; a manual run against this very worktree reports
`worktree_stream=true` (live positive case).

**→ LANDING POINT 1** (ship slices 1–3: correctness + hardening are immediately valuable in
the installed skill).

## Slice 4 — ownership + anchor model  *(Grok's ownership hole / Codex #5)*

1. **New `anchor` action** (verb-adjacent, tiny): check the host's always-loaded front-door
   files for the recovery block; present → say which file carries it; absent → **propose** the
   copy-paste block as a one-off approved edit and apply on the human's OK (committing stays
   the host's convention — never assume the front door is tracked). Save step 6's warn now
   ends "…run `/checkpoint anchor` to install it."
2. **Ownership rules made compaction-proof** (the guard text + Recovery discipline):
   - **Recovery confers ownership**: a compacted session that finds the root file (via the
     anchor or the summary) and runs Recovery's reconcile IS the owning session — the foreign
     guard must never fire against a post-compaction self.
   - **Reading is not resuming**: a session that merely read the file while exploring has not
     resumed it; ownership requires having run the Resume procedure (including its confirm) or
     created the file.
   - The foreign guard's refusal stays surface-and-ask, never silent.
3. **Honest guarantee wording**: where the anchor is absent, the promise is "a resumable
   save-state" — automatic compaction recovery is stated as anchor-dependent (one clause at
   the Recovery-anchor section head; the new action makes it installable rather than
   merely warned).

**Verify:** desk-check the three ownership scenarios (compacted-with-anchor,
compacted-without, fresh-reader) against the rewritten text — each resolves unambiguously.

**→ LANDING POINT 2** (ship slice 4).

## Slice 5 — the full split  *(Grok's shape; decision 1)*

Target shape (the workstream/journal pattern):

- **`SKILL.md`** (thin router, aim well under half the current 3,047 words): description +
  overview; scope (two-layers, self-scoped per decision 2); *When to use*; *Where it writes*
  (incl. guards summary, pointing at the scripts); a verb dispatch table (`save` / `resume` /
  `done` / `anchor` → `verbs/<verb>.md`); the four discipline **names with one-line glosses**
  + pointer to `disciplines.md`; the **unprompted behaviors** block (first-save-early, refresh
  at checkpoint moments, **anchor-line leads every substantial status message** — promoted
  from a once-mentioned technique to a during-the-session rule, per Grok); edges block.
- **`disciplines.md`** — the citable export: the four disciplines in full, authority order,
  the two techniques. This is the file borrow sites conceptually point at; names unchanged.
- **`verbs/save.md`** (procedure + document structure/template guidance — the 12-heading
  default explicitly marked *default, synthesize-don't-transcribe governs*; borrowers supply
  their own structure), **`verbs/resume.md`**, **`verbs/done.md`**, **`verbs/anchor.md`**
  (from slice 4; the recovery-anchor section and block move here).
- Recovery is a **discipline, not a verb** — it lives whole in `disciplines.md`; the router's
  When-to-use keeps its trigger line.

Mechanics: `git mv`-free (new files + shrink SKILL.md — history of the one file stays);
every moved fact appears in exactly one home (no duplication between router and leaf files);
bundled-ref resolution must stay lint-clean.

## Slice 6 — description rewrite + routing probe  *(decision 2; gates the ship)*

1. Rewrite the description as a **trigger** (≤750 chars, no verb-by-verb inventory, no sibling
   named): draft direction — *"Keep a living save-state for the session's work and recover it
   after context loss or compaction. Use when asked to save/checkpoint/snapshot session
   context, resume prior work, recover after a compaction summary, or close out finished
   work-in-flight. Scoped to the single root session's `CHECKPOINT.md`; a session driving an
   isolated stream uses that stream's own hand-off and save verb, not this."* (Self-scoped by
   artifact — final wording at implementation.)
2. **Fresh-sub-agent routing probe** (descriptions only, no bodies), cases: (a) "save a
   checkpoint" in a plain root session → checkpoint; (b) "save a checkpoint" with stream
   context in the prompt → workstream save; (c) "resume where we left off after compaction" →
   checkpoint; (d) "snapshot the repo state into the handoff" → checkpoint (not journal);
   (e) a workstream-load prompt → workstream. **Pass = all route correctly.** Case (b)
   misroutes → restore the contrast clause (Claude's position wins on evidence), re-probe,
   record the outcome in `docs/boundary-audit.md`.
3. Full re-read of the split skill end-to-end; lint; the checkpoint fixture suite; verify the
   six workstream borrow-site citations still read correctly (names unchanged, so they must).

**→ LANDING POINT 3** (ship slices 5–6; unit complete, debrief).

---

## Explicitly out of scope

- Any change to workstream's own guard/anchor registration (its side of the seam already
  works; only the PACK seam line references it).
- A registration/`register-route` revival — the anchor action proposes a human-approved edit,
  it does not self-register.
- Migrating legacy `HANDOFF.md` batons (resume's legacy-discovery line stays as-is).

## Risks

- **The split churns line numbers** other docs may cite — grep the library for
  `checkpoint/SKILL.md:` line-anchored citations before landing slice 5 (this session's
  feedback reports cite them, but they are untracked machine-local inputs, not shipped docs).
- **Routing regressions** are the real cost of decision 2 — mitigated by the probe gating the
  ship and the recorded fallback (restore the contrast).
- **Description under 750** while keeping the compaction-recovery trigger phrases — watch the
  char count at rewrite time (currently 762).
