# Pre-Deployment Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute `docs/design/2026-08-10-pre-deployment-cleanup.md` — harden the gates against the
three defect classes that escaped the reconciliation campaign, ship doctrine v2, bring every skill
description under budget, and close the remaining prose gaps before the live deployment test.

**Architecture:** Five independent tasks over two gates and one doctrine. Generic checks extend
`skills-lint.sh` (portable); the face-shape check is a new member of clankshop's shell suite. Each
new check is proven against a deliberately-broken scratch copy before it is trusted.

**Tech Stack:** bash (lint gate + shell test suite, POSIX-ish + awk/grep), markdown skill files.

## Global Constraints

- **The owner works concurrently in this tree.** Immediately before EVERY commit: re-run
  `git status --porcelain && git log --oneline -3`; if HEAD moved since the task started, re-read
  any file you edited that also changed upstream before committing.
- **Pathspec-scoped commits only** — `git add <exact paths>`, `git commit -- <exact paths>`; never
  `git add -A`, never `commit -a`. No AI-attribution trailers (no `Co-Authored-By`).
- **Baselines.** Entering this plan: shell suite 174 asserts + spine-scan PASS; lint
  `fails=0 warns=8`; cargo 36 green; drift `checked=3 drift=0`. The plan *intentionally* moves two
  of these: the suite gains the face-test (new total recorded, not held), and lint's warn count
  drops to **1**. Every other baseline holds at every commit.
- **Never weaken a gate to make it pass.** If a new check FAILs on legitimate content, fix the
  check's precision — never delete the check or add a blanket exemption. If you cannot make a
  check both correct and quiet, STOP and report BLOCKED with the false positives.
- **Scratch work goes in the session scratchpad**, never in the repo tree.
- Paths are repo-root-relative. Line numbers are as of `8f22723`;
  verify quoted strings before editing and re-locate by phrasing if they moved.

---

### Task 1: Lint check 2 — resolve `docs/` refs (two-stage)

**Files:**
- Modify: `skills/skill-builder/scripts/skills-lint.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: a lint gate that FAILs on a backticked `docs/…` path resolving in neither the skill
  bundle nor the repo root. Later tasks rely on lint still reporting `fails=0`.

- [ ] **Step 1: Read the current check 2 and its header comment**

Read `skills/skill-builder/scripts/skills-lint.sh` — the check-2 implementation and the header
comment block (lines ~13–19). Note the existing prefix list
(`scripts/|templates/|verbs/|references/|rules/`) and how it resolves a hit against the skill dir.

- [ ] **Step 2: Write the failing case first (prove the gap exists)**

In the scratchpad (NOT the repo), make a throwaway copy of one skill and inject a bad ref:
```bash
S=<scratchpad>/lintfix
rm -rf "$S" && mkdir -p "$S/skills"
cp -R skills/clankshop "$S/skills/clankshop"
printf '\nBogus ref: `docs/NOPE-does-not-exist.md`\n' >> "$S/skills/clankshop/SKILL.md"
bash skills/skill-builder/scripts/skills-lint.sh "$S" 2>&1 | tail -5
```
Expected NOW: no FAIL mentioning `NOPE-does-not-exist` (that is the gap). Record the output.

- [ ] **Step 3: Implement two-stage `docs/` resolution**

Extend check 2 so a backticked `docs/<path>` hit resolves when EITHER `<skill-dir>/docs/<path>`
OR `<repo-root>/docs/<path>` exists; FAIL only when neither does. Keep the existing five prefixes
resolving skill-dir-only exactly as today (do not loosen them). Match the file's existing style
(same helper functions, same `FAIL:` line format with evidence: skill, file, and the offending
ref). Update the header comment: replace the `(docs/ is excluded -- verbs use it host-relative;
check 3 covers bundled docs.)` note with the two-stage rule.

- [ ] **Step 4: Prove the check catches the bad ref, and stays quiet on the real tree**

```bash
bash skills/skill-builder/scripts/skills-lint.sh "$S" 2>&1 | grep -i "NOPE"      # expect: a FAIL line
bash skills/skill-builder/scripts/skills-lint.sh . 2>&1 | tail -1
```
Expected: the scratch copy FAILs on the injected ref; the real tree still reports
`fails=0 warns=8`. If the real tree FAILs, a legitimate `docs/` ref does not resolve — report each
one; do NOT exempt `docs/` to make it pass.

- [ ] **Step 5: Retro-check against the historical defect**

Confirm the check would have caught the campaign's real bug:
```bash
cp skills/clankshop/verbs/docs.md "$S/skills/clankshop/verbs/docs.md"
git show c928bcc:skills/clankshop/verbs/docs.md | grep -c "DOC-docs"    # expect: 2 (the historical typo)
```
Then temporarily place that historical file into the scratch skill and confirm lint FAILs on
`docs/DOC-docs/DOC-RUBRIC.md`. Record the result in the report; restore nothing in the repo (the
scratch copy is disposable).

- [ ] **Step 6: Clean up scratch and commit**

```bash
rm -rf "$S"
git add skills/skill-builder/scripts/skills-lint.sh
git commit -m "skill-builder(gate): check 2 resolves docs/ refs two-stage (bundle, then repo root) -- the exclusion is why two broken DOC-RUBRIC links survived a whole merge in the verb that audits broken links" -- skills/skill-builder/scripts/skills-lint.sh
```

---

### Task 2: Lint — § citation resolution + stale terminology

**Files:**
- Modify: `skills/skill-builder/scripts/skills-lint.sh`

**Interfaces:**
- Consumes: Task 1's check-2 changes (same file — re-read it before editing).
- Produces: a new numbered check; the header comment's check list grows by one entry.

- [ ] **Step 1: Survey the real citation shapes before writing the matcher**

```bash
grep -rnoE '`[a-zA-Z0-9_./-]+\.md` §[^.;)]*' skills/ --include='*.md' | head -30
grep -rnoE '§ [A-Z][^.;)]*' skills/clankshop --include='*.md' | wc -l
```
Read the output. The check must handle the dominant real shape (a backticked `.md` path followed
by `§ Heading`, possibly with words between) and must NOT try to resolve a bare `§ Heading` with
no file named — those cite the current file or a section by prose and are out of scope.

- [ ] **Step 2: Write the failing case**

In the scratchpad, copy a skill and inject a bogus citation:
```bash
S=<scratchpad>/lintsec
rm -rf "$S" && mkdir -p "$S/skills" && cp -R skills/clankshop "$S/skills/clankshop"
printf '\nSee `docs/DESIGN-DOCTRINE.md` § This Heading Does Not Exist for details.\n' >> "$S/skills/clankshop/SKILL.md"
```

- [ ] **Step 3: Implement the check**

Add it as the next numbered check. Rules:
- Trigger only when a backticked path ending `.md` and a `§ <Heading>` appear in the same
  sentence, the path resolves (bundle, then repo root — reuse Task 1's resolver), and the target
  is a readable markdown file.
- The cited heading matches when the target file has a `#`-heading whose text contains the cited
  heading text, compared case-insensitively with backticks and trailing punctuation stripped
  (citations legitimately abbreviate: `§ Cheap health, deep reconcile` vs the real
  `## Cheap \`health\`, deep \`reconcile\``).
- FAIL with evidence: citing file, cited file, the heading text that did not resolve.
- Add the header-comment entry describing it.

- [ ] **Step 4: Prove it both ways**

```bash
bash skills/skill-builder/scripts/skills-lint.sh "$S" 2>&1 | grep -i "This Heading Does Not Exist"   # expect FAIL
bash skills/skill-builder/scripts/skills-lint.sh . 2>&1 | tail -1        # expect fails=0 warns=8
```
If the real tree FAILs, each hit is either a real dangling citation (fix it in this commit and say
so in the report) or a matcher false positive (tighten the matcher). Do not exempt § checking.

- [ ] **Step 5: Retro-check against a historical defect**

The reconciliation fixed `reconcile.md`'s snapshot-rule citation. Confirm the check catches the
old form:
```bash
git show c928bcc:skills/clankshop/verbs/design/reconcile.md | grep -n "snapshot must not pose"
```
Place that historical line into the scratch skill and confirm a FAIL (the rule's real home is
skill-builder's `docs/DOCTRINE.md`, so the citation to `docs/DESIGN-DOCTRINE.md` names no such
heading). Record the result.

- [ ] **Step 6: Fix the gate's own stale terminology**

Three header comments say "foreman BOOTSTRAP"; the BOOTSTRAP is `auditor`'s (`skills/auditor/
BOOTSTRAP.md`) and foreman is a hat, not a skill. Update check 3's description and the two
explanatory comments (~lines 19-20, ~43, ~120) to name `auditor`. Leave line ~187's
`.agents/foreman/` example alone if it illustrates a path-separator false-positive case — read it
and judge; say which you chose in the report.

- [ ] **Step 7: Clean up and commit**

```bash
rm -rf "$S"
git add skills/skill-builder/scripts/skills-lint.sh
git commit -m "skill-builder(gate): section-citation resolution -- a backticked .md plus a section citation must name a heading that exists; gate comments name auditor's BOOTSTRAP (foreman is a hat now)" -- skills/skill-builder/scripts/skills-lint.sh
```

---

### Task 3: Face-shape test (router ↔ disk ↔ hats)

**Files:**
- Create: `skills/clankshop/scripts/tests/face-test.sh`
- Modify: `skills/clankshop/scripts/tests/run.sh`

**Interfaces:**
- Consumes: `skills/clankshop/scripts/tests/lib.sh` — reuse its `expect`/`expect_absent`/
  `expect_eq` helpers and its pass/fail counting convention (read an existing member such as
  `calibrate-test.sh` and follow its shape exactly: same shebang, same `set` flags, same summary
  line format `<name>: pass=N fail=0`).
- Produces: a new suite member; `run.sh`'s roster grows by one; the suite's assert total rises.

- [ ] **Step 1: Read the conventions**

Read `skills/clankshop/scripts/tests/lib.sh` and `skills/clankshop/scripts/tests/calibrate-test.sh`
in full. Match their structure — this test is a sibling, not a new style.

- [ ] **Step 2: Write the test**

`face-test.sh` asserts, against the live bundle (`skills/clankshop/`, resolved relative to the
script, never a hardcoded absolute path):

1. **No phantom routes.** Parse the `SKILL.md` router table's verb column. For every verb naming a
   file path in its row (the rows cite `verbs/<x>.md` or `verbs/<x>/`), that path exists.
2. **No orphan verb files.** Every `verbs/**/*.md` file is reachable from the router: either named
   directly in a row, or living under a directory a row names (e.g. `verbs/design/` covers
   `verbs/design/plan.md`).
3. **Hat pointers resolve.** Every verb file under a directory the router pairs with a hat opens
   with a `Hat: \`roles/<role>.md\`` line within its first 5 lines, and that `roles/<role>.md`
   exists.
4. **The hat set is closed.** `roles/` contains exactly the four hats the router's hat column
   names (architect, foreman, guardian, chiropractor) — no extra file, no missing one.

Keep each assertion a separate `expect`/`expect_eq` call with a descriptive label (`face: no
phantom routes`, `face: <verb> carries a Hat pointer`, …) so a failure names itself.

- [ ] **Step 3: Prove each assertion fails on a broken copy**

Copy the bundle to the scratchpad, break it four ways (one at a time), and confirm the matching
assertion fails each time:
```bash
S=<scratchpad>/facetest
# (a) phantom route: add a router row naming verbs/design/prep.md   -> assertion 1 fails
# (b) orphan file: create verbs/orphan.md                            -> assertion 2 fails
# (c) strip a Hat: line from a verb file                             -> assertion 3 fails
# (d) add roles/calibrator.md                                        -> assertion 4 fails
```
A check that never fails on known-bad input is not a check — record all four results in the report.
Then delete the scratch copy.

- [ ] **Step 4: Wire it into the runner and run the full suite**

Add `face-test.sh` to `run.sh`'s roster (follow the existing list's order and style — put it
first, since it validates the face the other tests deploy).

Run: `bash skills/clankshop/scripts/tests/run.sh`
Expected: ALL GREEN; every prior member's counts unchanged (onramp 82, backlog 35, escalation 13,
mirror 28, calibrate 16, spine-scan PASS) plus the new `face: pass=N fail=0`. **Record the new
total** — it replaces 174 as the recorded baseline.

- [ ] **Step 5: Lint and commit**

```bash
bash skills/skill-builder/scripts/skills-lint.sh .   # expect fails=0 warns=8
git add skills/clankshop/scripts/tests/face-test.sh skills/clankshop/scripts/tests/run.sh
git commit -m "clankshop(tests): face-shape suite -- router rows resolve to real verb files, no orphan verbs, every hatted verb carries a resolving Hat pointer, the hat set is closed; the phantom-prep class is now mechanically caught" -- skills/clankshop/scripts/tests/face-test.sh skills/clankshop/scripts/tests/run.sh
```

---

### Task 4: Doctrine v2 — RECORDS wording + version bump

**Files:**
- Modify: `skills/clankshop/doctrine/rules/RECORDS.md`
- Modify: all 13 files under `skills/clankshop/doctrine/` carrying `doctrine-version: 1`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: `doctrine-version: 2` everywhere. Consumers derive the value (`check-facts.sh:381`,
  `onramp-test.sh:18`, `backlog/scripts/records-projection.sh:35`) — do NOT hardcode 2 anywhere.

- [ ] **Step 1: Fix the retired persona token**

`skills/clankshop/doctrine/rules/RECORDS.md` line ~99 reads
`landed → the calibrator confirms uptake, then \`backlog done … --outcome drained\`; a workstream`.
The calibrator role was retired (folded into the chiropractor hat; the verb is
`/clankshop calibrate`). Replace `the calibrator confirms uptake` with `the improvement loop
confirms uptake` — chapter prose is projected into consuming projects and must name no hat or
skill it does not have to (the cold-clone rule), so prefer the functional name over a hat name.
Re-wrap the line if the edit pushes it past the file's wrap.

- [ ] **Step 2: Verify no other retired token remains in the doctrine**

```bash
grep -rniE "calibrator|/architect|/foreman|/guardian|/chiropractor|\bprep\b|rebuild" skills/clankshop/doctrine/
```
Expected: only legitimate hits — `doctrine/README.md`'s roster line naming the four hats,
`workflows/feature.md`'s "as the architect (`/clankshop design`)" hat language, and the words
"architecture"/"architectural" in `workflows/bug.md` and `testing/DIAGNOSTICS.md`. Report anything
else and fix it in this commit.

- [ ] **Step 3: Bump the version in every declaration block**

```bash
grep -rln "doctrine-version: 1" skills/clankshop/doctrine/    # expect 13 files
```
Change `doctrine-version: 1` → `doctrine-version: 2` in each. Do not touch any other version
token (`PACK.md` stays `1.1.0`; `origin-version:` values in fixtures are derived at projection).

- [ ] **Step 4: Confirm consumers derive, not hardcode**

```bash
grep -rn "doctrine.version" skills/clankshop/scripts/check-facts.sh skills/clankshop/scripts/tests/onramp-test.sh skills/backlog/scripts/records-projection.sh
```
Confirm each reads the value from `doctrine/README.md` (awk on the `doctrine-version:` line) rather
than comparing to a literal `1`. If any hardcodes `1`, that is the real bump ripple — fix it and
say so in the report.

- [ ] **Step 5: Full gates**

```bash
bash skills/clankshop/scripts/tests/run.sh          # ALL GREEN, counts per Task 3's new total
bash skills/skill-builder/scripts/skills-lint.sh .   # fails=0 warns=8
cargo test --workspace                               # 36 green
```
The onramp fixture derives `DV` from the doctrine, so a green suite here is the real proof the
bump rippled correctly (projected chapters carry `origin-version: 2`, RECORDS carries
`built-against: clankshop-doctrine@2`).

- [ ] **Step 6: Commit**

```bash
git add skills/clankshop/doctrine/
git commit -m "clankshop(doctrine): v2 -- RECORDS names the improvement loop, not the retired calibrator; doctrine-version bumped across all 13 declaration blocks per the doctrine's own rule, landed before first deployment so no install is born carrying the retired persona" -- skills/clankshop/doctrine/
```

---

### Task 5: Description budget + prose gaps

**Files:**
- Modify: `skills/mailbox/SKILL.md`, `skills/skill-builder/SKILL.md`, `skills/auditor/SKILL.md`,
  `skills/workstream/SKILL.md`, `skills/feature/SKILL.md`, `skills/backlog/SKILL.md`,
  `skills/delegate/SKILL.md` (frontmatter `description:` only)
- Modify: `skills/clankshop/verbs/ask.md`
- Modify: `skills/clankshop/docs/DOC-RUBRIC.md`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: lint baseline `fails=0 warns=1` (only `mailbox`'s sibling-ref warn survives).

- [ ] **Step 1: Measure before**

```bash
for d in skills/*/; do n=$(basename $d); [ -f "$d/SKILL.md" ] && awk -v n="$n" '/^description:/{sub(/^description: */,""); print length($0), n}' "$d/SKILL.md"; done | sort -rn
```
Record. Targets: mailbox 896, skill-builder 855, auditor 845, workstream 828, feature 803,
backlog 796, delegate 785 → each ≤750.

- [ ] **Step 2: Trim each description to ≤750, preserving routing signal**

**Descriptions are the routing surface — this is not cosmetic trimming.** For each: keep every
distinct trigger phrase (the verbs, nouns, and symptom words a user would say), and cut
explanation, restatement, and rationale. Do not drop a capability from the description just to fit;
if a description cannot reach 750 without losing a real trigger, leave it long and report which
one and why (a legitimate long description is better than a mis-routing short one).

Rules that must survive the edit: the `description:` stays quoted where it contains `": "`
(strict-YAML trap, lint check 1), and `mailbox`'s reference to `/delegate` stays (it is the
documented router/fragment exception that keeps warn #1).

- [ ] **Step 3: Verify the budget and the new baseline**

```bash
for d in skills/*/; do n=$(basename $d); [ -f "$d/SKILL.md" ] && awk -v n="$n" '/^description:/{sub(/^description: */,""); if (length($0)>750) print length($0), n}' "$d/SKILL.md"; done   # expect: empty
bash skills/skill-builder/scripts/skills-lint.sh . | tail -3
```
Expected: `fails=0 warns=1`, the surviving warn being mailbox's sibling reference.

- [ ] **Step 4: ask.md prose gaps**

In `skills/clankshop/verbs/ask.md`:
- The hat↔verb pairing is currently only inferable from the parallel role/alias lists (line ~7-8).
  State it explicitly — e.g. render the roles as pairs (`architect` → `design`, `foreman` →
  `route`, `guardian` → `verify`, `chiropractor` → `calibrate`/`docs`) so an agent routing work
  out of a discussion (step 4) knows the target verb without inferring it positionally.
- Step 5 says byproducts "are captured through the ordinary records instrument" — on a host with
  no framework there is none. Add the fallback: say what happens instead (surface them to the user
  in the conversation rather than writing files), consistent with the shared posture
  ("judgment runs anywhere; writes need a home").

- [ ] **Step 5: DOC-RUBRIC dash normalization**

In `skills/clankshop/docs/DOC-RUBRIC.md`, normalize the ASCII `--` dash convention to the bundle's
em dash `—`. Mechanical: only dashes used as *punctuation* (surrounded by spaces, or joining
clauses) change. Do NOT touch: `--` inside code fences, inline code spans, CLI flags
(`--pack`, `-S warning`), or any table's `|---|` separator row. Verify with
`grep -n '\-\-' skills/clankshop/docs/DOC-RUBRIC.md` afterward and confirm every survivor is one
of those legitimate cases.

- [ ] **Step 6: Routing probe over the trimmed descriptions**

Dispatch a fresh subagent with ONLY the seven trimmed descriptions (copy them into the prompt;
forbid file access) and these intent phrases, asking which skill each should route to:
"my sub-agent needs to hand a patch back without polluting context" (mailbox);
"scaffold a new skill and lint it" (skill-builder);
"audit this module's code quality against a rubric" (auditor);
"start a long-lived stream of work and keep shipping it" (workstream);
"turn this idea into a tested implementation" (feature);
"file a follow-up and mark the last one done" (backlog);
"should a cheaper model handle this grunt work?" (delegate).
Expected: 7/7. A mis-route means the trim cut a load-bearing trigger — restore it and re-probe
(a longer description that routes correctly beats a short one that does not).

- [ ] **Step 7: Full gates and commit**

```bash
bash skills/clankshop/scripts/tests/run.sh          # ALL GREEN
bash skills/skill-builder/scripts/skills-lint.sh .   # fails=0 warns=1
cargo test --workspace                               # 36 green
git add skills/mailbox/SKILL.md skills/skill-builder/SKILL.md skills/auditor/SKILL.md skills/workstream/SKILL.md skills/feature/SKILL.md skills/backlog/SKILL.md skills/delegate/SKILL.md skills/clankshop/verbs/ask.md skills/clankshop/docs/DOC-RUBRIC.md
git commit -m "library(polish): descriptions under the 750 budget (new lint baseline fails=0 warns=1 -- only mailbox's documented sibling-ref survives, so a new warn is visible again), ask.md names the hat-verb pairing and its off-framework byproduct fallback, DOC-RUBRIC speaks the bundle's em dash" -- skills/mailbox/SKILL.md skills/skill-builder/SKILL.md skills/auditor/SKILL.md skills/workstream/SKILL.md skills/feature/SKILL.md skills/backlog/SKILL.md skills/delegate/SKILL.md skills/clankshop/verbs/ask.md skills/clankshop/docs/DOC-RUBRIC.md
```

- [ ] **Step 8: Close out the design doc**

Mark `docs/design/2026-08-10-pre-deployment-cleanup.md`'s status line executed (replace
`**Status: proposed**` with `**Status: executed 2026-08-10**`), record the two moved baselines
(the suite's new assert total, lint `warns=1`) in its Verification section, and commit it
pathspec-scoped with message
`clankshop(cleanup): pre-deployment cleanup design marked executed -- new baselines recorded`.
