# Pre-deployment cleanup — gate hardening, doctrine v2, description budget

**Status: proposed** (owner asked for "as much cleanup as is reasonable" before the live
deployment test, 2026-08-10). Follows
`docs/design/2026-08-10-clankshop-audit-reconciliation.md`, whose final review and *Known
residue* note supply most of this scope.

## Problem

The reconciliation campaign closed its findings, but three of its own defects escaped every
mechanical gate and were caught only by human reading or a final review:

- `docs/DOC-docs/DOC-RUBRIC.md` — two broken links that survived a whole merge **in the verb that
  audits broken links**. Lint check 2 resolves backticked `scripts/|templates/|verbs/|
  references/|rules/` paths inside the bundle but **deliberately excludes `docs/`**.
- **`prep`** — a phantom route cited in five places, listed in the router, with no file on disk.
  Nothing compares the router table to the tree.
- Dangling **§ citations** (`init`'s Step 5; reconcile's snapshot rule citing the wrong doctrine).
  Nothing resolves a section citation to a real heading.

Separately: one deliberately-deferred residue (`doctrine/rules/RECORDS.md` still names the
retired "calibrator") ships into every install; the lint warn baseline stands at **8**, which
hides any new warn; and `skill-builder`'s own gate comments carry post-merge stale terminology.

The live deployment test is the next work. These gates pay off *during* it — catching regressions
while the tree is being changed — which is why they land first.

## Decisions

1. **Generic checks go in `skills-lint.sh`** (skill-builder's portable gate — it travels to any
   skills library): the `docs/` resolution fix and § citation resolution. **The face-shape check
   goes in clankshop's own test suite** (`scripts/tests/`) — it needs knowledge of *this* face's
   structure (a router table, a `verbs/` tree, `roles/` hats), which a generic gate must not
   assume. One validator per fact; skill-builder stays generic.
2. **`docs/` resolution is two-stage:** a backticked `docs/X` resolves against the skill bundle
   first, then the repo root; FAIL only when neither has it. This covers both real uses (39 refs
   to bundled docs, 7 to repo-root `docs/design/`+`docs/spec/`) and would have caught the
   `DOC-docs/` typo, which resolves nowhere.
3. **Doctrine bumps to v2** carrying the RECORDS wording fix. Cheap by construction: 12
   declaration blocks hold the token (13 files), and every consumer (`check-facts.sh`, the onramp fixture,
   `records-projection.sh`) *derives* the version from `doctrine/README.md` — no fixture surgery,
   no hardcoded expectations. Doing it **before** first deployment means no real installation is
   ever born carrying the retired persona.
4. **Description budget: every skill ≤750 chars.** New baseline `fails=0 warns=1` — the surviving
   warn is `mailbox`'s description naming `/delegate`, a documented-legitimate router/fragment
   exception (BOUNDARY-AUDIT). A baseline of 8 hides new warns; a baseline of 1 with a known name
   does not. **Descriptions are the routing surface**, so trimming is not cosmetic: each trimmed
   description keeps its trigger vocabulary, and a routing probe re-runs afterward.
5. **Out of scope:** fixture machinery simulating the unstamped posture. The verbs are prose; a
   fixture could only assert the text, which greps already do. Exercising the posture is the live
   deployment test's job.

## The work

**A. Gate hardening (`skills/skill-builder/scripts/skills-lint.sh`).**
- Check 2 extended to `docs/` with two-stage resolution (decision 2); the header comment's
  `docs/`-exclusion note is replaced by the new rule.
- New check: **§ citation resolution** — where a backticked bundle file is followed by a `§ Some
  Heading` citation, that heading must exist in the cited file (FAIL). Scope it to citations that
  name a file in the same sentence, so it stays mechanical and false-positive-free.
- Stale terminology: the gate's own comments say "foreman BOOTSTRAP" in three places; the
  BOOTSTRAP is `auditor`'s and foreman is a hat.

**B. Face-shape test (`skills/clankshop/scripts/tests/face-test.sh`, joined to `run.sh`).**
Asserts what only a human checked this round:
- every verb the `SKILL.md` router table names exists on disk (no phantom routes — the `prep`
  case), and every file under `verbs/` is named by the router (no orphans);
- every verb file under a hatted route opens with a `Hat:` line whose `roles/<role>.md` exists;
- the four hats exist and the router's hat column names only those four.

**C. Doctrine v2 (`skills/clankshop/doctrine/`).** `rules/RECORDS.md`'s "the calibrator confirms
uptake" → the loop's post-merge name; `doctrine-version: 1` → `2` in all 13 declaration blocks
(one commit, per the doctrine's own bump rule).

**D. Description budget.** Trim `mailbox` (896), `skill-builder` (855), `auditor` (845),
`workstream` (828), `feature` (803), `backlog` (796), `delegate` (785) to ≤750, preserving trigger
vocabulary. Routing probe afterward over the trimmed set.

**E. Prose gaps.** `verbs/ask.md`: state the hat↔verb pairing explicitly (today it is only
positionally inferable from the parallel role/alias lists), and say what happens to byproducts on
a host with no records instrument. `docs/DOC-RUBRIC.md`: normalize `--` to the bundle's `—` (the
rubric that *defines* Consistency should not violate it).

## Verification

Baselines after the campaign: shell suite **ALL GREEN with the face-test added** (assert total
rises — the new figure is recorded, not held); lint **`fails=0 warns=1`** (the new baseline);
`cargo test --workspace` **36 green**; drift `checked=3 drift=0`. Two probes: the new lint checks
are proven by *deliberately* introducing each defect class in a scratch copy and confirming a
FAIL (a gate that never fails on a known-bad input is not a gate); the routing probe re-runs over
the trimmed descriptions.

No pack version bump — this is gate and doctrine work, not a change to the pack's deployed member
content. (`doctrine-version` bumps; `PACK.md` stays `1.1.0`.)
