# Clankshop audit reconciliation — rebuild concept retired, merge damage repaired

**Status: executed 2026-08-10** (owner-approved; see the reconciliation plan beside this doc).
Follows the role merge (`docs/design/2026-08-10-clankshop-role-merge.md`, executed at `d412eef`/
`c928bcc`) and repairs what its full-skill audit found; amends
`docs/design/2026-08-06-clankshop-pack.md`'s design doctrine by retiring the rebuild workflow.

## Problem

The role merge was executed largely by mechanical moves and `sed` rewrites. A full-read audit of
the merged skill (run at `c928bcc`; every moved/rewritten file read in full, hat-fidelity diffed
against the deleted SKILL.mds, routing/ask probes run) found the result green but not coherent:

- **A verb-name collision.** Architect's old `check` verb collided with the face's `check`
  (assembly validation): ~16 bare `` `check` `` tokens across the design verbs, the design
  doctrine, and a projected template now silently mis-resolve. The intended referent is
  `/clankshop design health`.
- **Sed corruption.** Three copy-pasteable commands invoke `scripts/clankshop design-check.sh`
  (a filename with an embedded space; the script is `architect-check.sh`); two links read
  `docs/DOC-docs/DOC-RUBRIC.md`.
- **The retired world survives in prose.** `seed.md` Step 7 still self-registers "architect's
  route" via a `register-route.sh` the bundle no longer carries, claims the single-role
  pre-stamp install-block license retired at `c802796`, and calls itself "`setup`" (~15×) — now
  a different live verb. `init` (two renames stale) survives in seven places; "calibrator" as a
  live persona in five.
- **`prep` is cited as invocable but pending.** `plan.md`'s second altitude, the projected
  `MAP.md` template, and the architect hat all lean on a verb that has never existed.
- **Dropped shared disciplines.** The real-date rule ("`date +%Y-%m-%d` — never guess it"), the
  root-resolution ladder, and `calibrate intake`'s promotion-bar hook died with the deleted
  SKILL.mds; the unstamped-root posture is split (route/verify/intake refuse; design verbs lost
  the guard; docs/ask run anywhere by design).

Full findings: the audit report (machine-local scratch, 2026-08-10; findings B1–B8, S1–S5,
E1–E11 — the IDs cited below).

## Decisions (owner-ratified)

1. **Scope: reconcile + reshape** — fix the damage *and* restructure where the audit exposed a
   wrong shape, rather than minimally patching.
2. **The rebuild concept leaves clankshop entirely.** "Code is the disposable build output of
   the seed", Plan B, `prep`, the clear-run/build-run mechanics, and the `/feature` two-run
   obligation are removed — too large a concept to store inside this pack. `prep` dies with it
   (router, hat, plan.md, MAP template). Git history is the archive.
3. **The sufficiency discipline survives, reframed.** The seed's justification becomes: the
   standing source of truth agents build against, held to one bar — *a fresh agent can act on it
   without guessing* (the read-test). The circularity trap survives as "observation isn't
   decided intent — a human ratifies"; the rebuild-specific machinery (frozen seed, prep-gap
   metrics, independently-authored acceptance) goes.
4. **Unstamped posture: judgment anywhere, writes need a home.** Every intent verb loads its hat
   and works on any repo — reading, judging, advising. A verb whose procedure writes into the
   deployed layout (`.handbook/`, `.records/`) states plainly: no stamped root → report what's
   missing, point at `setup`/`migrate`, write nothing. Consequence, made explicit: `seed` and
   `extract` lose their old pre-stamp write licenses — the face owns *all* bootstrap (finishing
   what `c802796` started).
5. **`seed` becomes an explicit design subverb**, with bare `design` as its alias — every
   existing `/clankshop design seed` citation becomes true as written.
6. **Execution shape: doctrine-first cascade** (approach A) — the doctrine rewrite lands before
   the verbs that cite it; the provably-safe mechanical batch goes first.

## The reframe (what changes in the design doctrine)

| surface | today | after |
|---|---|---|
| `docs/DESIGN-DOCTRINE.md` § The keystone | clear/build runs, deletion-as-context-hygiene, `/feature` two-run rule | removed |
| § Sufficiency, and its circularity | rebuild as the empirical sufficiency test | kept: circularity trap + fresh-agent read-test as the semantic gate |
| durability gradient (spine law; ref-arch disposable, pointer-heavy) | — | kept unchanged |
| doc preamble | "the portable methodology every verb links to" | scoped to the design verbs |
| `roles/architect.md:4` | "regenerable source of truth that code is the disposable build output of" | "the clean, present-tense source of truth the project builds against"; `prep` leaves the read-list |
| `verbs/design/health.md` | "no contract = not rebuildable"; "sufficient to rebuild from" | "no contract = nothing binding to build against"; read-test framing |
| `verbs/design/extract.md` | gaps = "what a rebuild would have to guess" | gaps = "what an agent acting on this spec would have to guess"; SUFFICIENCY-GAPS.md and the provisional stamp stay |
| `verbs/design/plan.md` | second altitude sequences prep modes (`prep replace`/`prep extend`) | sequences spec revisions + build work: each item tagged *spec revision only* or *spec + build work → `/feature`* |
| `templates/design/system-spec.md:16` | "acceptance criteria a rebuild must pass; `check` flags placeholders" | "…the implementation must pass; `design health` flags placeholders" |
| `templates/design/MAP.md:3` | "the input `design prep` and `design plan` read" | "the input `design plan` reads" |

## The naming set

- **`health` is the canonical token** wherever bare `` `check` `` meant seed validation
  (`reconcile.md` ~12×, `distill.md` ×2, `brainstorm.md:85`, DESIGN-DOCTRINE §
  *Cheap `check`, deep `reconcile`* → *Cheap `health`, deep `reconcile`*, `system-spec.md:16`).
  Per-occurrence editorial — some instances are plain English.
- **`architect-check.sh` → `design-check.sh`** (`git mv` + script header + `DESIGN-DOCTRINE.md`
  + `seed.md`); the three sed-broken commands become correct with the space removed. No test
  references the old name.
- **`calibrator-test.sh` → `calibrate-test.sh`** (+ `run.sh`'s roster line) — the last live
  "calibrator" outside prose; prose tokens (`distill.md:10`, `intake.md:5`,
  `calibrate/doctrine.md:10,26`, `doctrine/README.md:134`) reword to the chiropractor/the loop.
- **`DOC-RUBRIC.md` retitles** to the face's framing ("the 12-dimension spine rubric behind
  `docs`"); body untouched.
- **Router row edits:** `seed` joins the subverb list (bare stays its alias); `prep` disappears;
  `health` gains the gloss "seed completeness/drift facts" (closes the probe ambiguity, E11).

## Shared disciplines, restored once

One block in `SKILL.md` directly under the dispatch rule, inherited by every verb (hatted or
not): resolve the root (a project dir the conversation references → cwd → ask; project-relative
paths); get the date with `date +%Y-%m-%d` — never guess it. Verb-specific restorations:
`calibrate intake` step 3 regains "needs a human call → `/backlog promote`; the item stays
claimed"; `roles/chiropractor.md` gains guardian's parallel "keeps no seat, no chapters" line.

## Per-file verdicts

**Rewrites:** `docs/DESIGN-DOCTRINE.md` (the reframe + `init` tokens + prose casualties E3);
`verbs/design/plan.md` (prep out; design→`/feature` seam; stranded `<project:…>` slot, dead
§-citations, and the repo-root-relative PACK.md path cleaned); `verbs/design/seed.md` (Step 7 + Report tail deleted; `setup` self-name →
seed ~15×; fixed command; posture line); `verbs/design/reconcile.md` (health sweep; seam table's
first row re-drawn against `design health`, with a new row for the real neighbor
`/clankshop check`; `init` token).

**Touch-ups:** `extract.md` (`init` ×4, `setup` at :58, reframe, posture line — it writes
`.records/design/draft/`), `brainstorm.md` (`init` §-ref
→ the right seed step, `check`→`health`, PACK.md path → `docs/RUNBOOK.md`), `distill.md`,
`health.md`, `docs.md` (paths ×3, "role of the pack" line), `verify/tend.md` + `verify/judge.md`
(posture normalization; sibling verbs spelled as full routes), `calibrate/intake.md` (posture,
promote hook, dispatch list in hat/member terms), `calibrate/doctrine.md`, `roles/architect.md`,
`roles/chiropractor.md`, `SKILL.md` (router row + shared-discipline block),
`doctrine/README.md` (:134 + roster gains the two optional proxies, E7), `templates/design/`
(`MAP.md`, `system-spec.md`, `README.md` wrap), `verbs/check.md` ("installed roles" phrase, E8).

**Keeps:** `roles/foreman.md`, `roles/guardian.md`, `verbs/route.md` (posture wording only),
`verbs/ask.md`, `docs/RUNBOOK.md`, `PACK.md` (version bump only), `verbs/setup.md`,
`verbs/migrate.md`, remaining templates.

## Commit sequence

Doctrine-first cascade; full suite + lint after each commit; re-ground on `HEAD` before each
(the owner works concurrently); pathspec-scoped; no AI-attribution trailers.

1. `clankshop(reconcile): design doc` — this document.
2. `clankshop(reconcile): mechanical batch` — `DOC-docs/` paths, `init` tokens, calibrator prose
   tokens (audit batch items, provably safe).
3. `clankshop(reconcile): doctrine reframe` — DESIGN-DOCTRINE rewrite, script rename,
   DOC-RUBRIC retitle.
4. `clankshop(reconcile): design verbs` — seed/plan/reconcile rewrites; design touch-ups;
   architect hat; templates; router row.
5. `clankshop(reconcile): posture + disciplines` — SKILL.md shared block; route/verify/calibrate
   posture; intake promote hook; chiropractor hat line.
6. `clankshop(reconcile): editorial sweep + version` — E-item residue; `calibrator-test.sh`
   rename; `PACK.md` → `1.1.0` + crate-test pin update.

## Verification & versioning

Baselines to hold: lint `fails=0 warns=8`; shell suite 174 asserts + spine-scan PASS; drift
`checked=3 drift=0` (post-merge baseline — architect's `register-route.sh` died with the skill).
`cargo test --workspace` gates commit 6 (the version-pin change; roster untouched otherwise).
After the router edits, re-run the routing probe (a fresh agent, description + router table
only) — the previously-ambiguous "validate that our design docs are complete" should resolve to
`design health`. `PACK.md` bumps to `1.1.0`: a content reshape on deployed members must be
visible to installs; the crate test's pinned `1.0.0` (`crates/grimoire-pack/tests/clankshop.rs`)
updates with it.

## Out of scope

The live deployment test (greenfield `setup` + brownfield `migrate` on real repos) follows this
reconciliation as its own effort. `auditor`, the instruments, pipelines, and helpers are
untouched. The record schema and doctrine chapters (`doctrine/rules|workflows|testing`) are
untouched — no `doctrine-version` bump. Where the rebuild workflow lands, if anywhere, is a
future design — nothing here reserves a home for it.
