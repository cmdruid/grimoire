# Grimoire maintainer backlog

The "simple version" backlog for **this repo's own** loose ends — maintainer follow-ups on the skill
library itself (lint gaps, doctrine debt, deferred audit items). This is grimoire-as-a-project, distinct
from the `.records/` trackers a *consuming* project gets; grimoire authors those skills, it does not run
them on itself. Phase 7's `skill-builder` steward may eventually own this list; until then it is a flat
maintainer file.

**Format.** One entry per loose end, newest concerns first. Each: an `id`, a one-line title, a `source`
(where it came from), a `status`, and a short body. Close an entry by setting `status: done` with a
one-line resolution; delete only when the reason it existed is gone.

---

## Open

### BL-37 — agent-council leftovers from the 2026-08-19 skill audit
- **source:** grok stream, skill audit / refactor (2026-08-19).
- **status:** open
- **body:** Two nits the audit folded around, not through:
  1. `scripts/read-result.sh` only extracts `### N. [seats] severity — ` with an em dash. ASCII `--` or a missing severity drops `n=0` with no error. Tests only cover the golden em-dash fixture.
  2. When-to-use allows any named path; Do-not-use forbids a source-tree code review. A convene on `src/` can contradict itself. Restrict default targets to a file, a skill package, or a spec-shaped doc; directories without `SKILL.md` should ask.
- **not this item:** review-round paths, Codex `-o`, `${TMPDIR:-/tmp}`, and the cluster-file shape landed in `4330d67`.

### BL-36 — the `clankshop` refactor is deferred; two BL-34 items ride with it
- **source:** feat stream, BL-34 items 1–2 ship (2026-08-19). Human decision.
- **status:** open (deliberately deferred, not blocked)
- **body:** BL-34's item 3 (drop the "handbook" idea, integrate `<agent-workspace>` with
  `doctrine/` + `spec/` + `workflow/`, un-nest the six workflow files) is **deferred** — clankshop
  is due a large refactor of its own and this work would be redone. Two things wait on it and
  should NOT be attempted before it:
  - **Item 4** — lint checks 12–17 (~246 lines) and their two test suites (~540 lines). They police
    the doctrine/records-home placement convention that item 3 replaces; deleting them now would
    drop enforcement of a convention still in force.
  - **Item 5** — the document-paths simplification, which depends on the workspace layout item 3
    settles.
- **the naming question, still unresolved:** the human wants `<agent-workspace>/spec/` *and* the
  records doctype `specs` (now live as of BL-34 item 2). Near-identical names in different homes.
  It did NOT bite during the rename — `blueprint/templates/design.md` was deleted rather than
  renamed to `specs.md`, so no `specs.md`/`spec.md` pair was created — but the workspace-side half
  is still open and belongs to item 3.

### BL-35 — lint check 17 cannot catch the BL-32 shape it was supposed to prevent
- **source:** feat stream, BL-34 items 1–2 ship (2026-08-19).
- **status:** done (2026-08-19, grok stream) — check 17 gained a `new --flag` arm. Planted `records.sh new --template <resolved>` FAILs; prose naming the tool still does not. Proven in `lint-records-writer-test.sh`.
- **body:** check 17 flags a bare `records.sh new` mint by keying on a span carrying **`--title`** —
  that is what makes an invocation decidable from prose merely naming the tool. BL-32's four bad
  invocations (`records.sh new --template <resolved>`, doctype positional dropped) carry no
  `--title`, so the check was blind to every one of them; they were found by hand-enumeration
  instead, twice, a session apart. BL-32's *instances* are now fixed, but nothing stops a
  recurrence.
- **fix sketch:** add an arm that flags a backticked span containing `records.sh new` immediately
  followed by a flag rather than a doctype word — decidable without `--title`, since
  `new --<anything>` is never valid. Red-proof it by planting the exact BL-32 spelling and
  asserting the check FAILs (and that the break applied).
- **note:** this is the second time check 17's `--title` key has let a real defect through
  (BL-25 was the first). The key is load-bearing for decidability; the fix should add an arm,
  not loosen it.


### BL-34 — one simple spec, then a hard cut
- **source:** feat stream, 3b post-mortem (2026-08-19, human direction).
- **status:** partly done (2026-08-19, grok stream) — `agent-templates` retired as a
  variable; templates resolve at `<agent-workspace>/templates`. Items 3–5 (clankshop
  layout, lint 12–17, document-paths) still ride with BL-36.
- **the spec:** a few lines, not a doctrine chapter. Two variables, two roots, no home nested in
  another:
  - `<agent-records>` — default `.records/` — dated, typed, closeable instances.
  - `<agent-workspace>` — default `.dev/` — `doctrine/` (living, normative) and `templates/` (schemas).
  Retire `agent-templates` as a variable; it becomes the fixed subpath `<agent-workspace>/templates`.
- **duplication is fine.** Skills stay independent and each carries its own copy of the resolver.
  That is the accepted price of independence, not debt. `skill-builder` holds the spec and enforces
  compliance — that is the single source of truth, and the lint is how copies are kept honest.
- **what actually gets cut (the point of the exercise):** the pack is in **alpha**, so legacy
  invariants and callbacks to past doctrine are deleted rather than carried —
  `records.sh:182`'s flat-template fallback; `records.sh:64,84`'s `templates` carve-out (templates
  leave the records home entirely); the legacy-flat adopt rung and the previous-home probe;
  `standup.sh`/`analyst` paths still anchored at `<agent-records>/templates`; and `DOCTRINE.md`'s
  accumulated hedging, including the `mkdir` owner-exception paragraph whose closing clause reads as
  revoking the grant three lines above it.
- **why 3b failed and this doesn't:** 3b *preserved* every legacy path while renaming, so a path
  change cost 27 files, seven slices and two migration fixtures. Deleting is cheap; the census
  problem largely evaporates once there is nothing to keep compatible.
- **absorbs:** the `agent-templates` retirement (3b, dropped), BL-28's unresolved ownership half,
  BL-19's deferred calibrate pass, BL-33 (break-verification doctrine).
- **spec:** `docs/design/2026-08-19-two-roots-simple-spec.md` (`status: current`, 2026-08-19).
- **~~open question for the human~~ — DISSOLVED 2026-08-19.** The question was mis-stated.
  `<agent-records>: dev` was never at risk — it is a variable and it resolves. The real issue was
  that such hosts also keep doctrine at `dev/doctrine/`, nesting one home in the other, which is
  what forced the `doctrine` reserved name in `records.sh`. Moving the record discriminator from
  *path* to *front-matter block* removes the need for any reserved name, so coinciding roots are
  legal and no legacy host loses support. **No decision required; the cut is unblocked.**
- **ownership rule (human direction, 2026-08-19):** a skill creates only the directories it needs
  for its own work. `journal` stops declaring the eight-store taxonomy on other skills' behalf;
  `records.sh` crawls unknown subdirectories instead of matching a known list.

### BL-33 — "prove a new check by breaking it" does not say to verify the break applied
- **source:** feat stream, BL-25 build (2026-08-19). Second occurrence in two sessions.
- **status:** done (2026-08-19, grok stream) — the prove-by-breaking bullet now requires counting occurrences before/after the mutation and failing on zero replacements.
- **body:** `skill-builder/docs/DOCTRINE.md:545-551` requires a new check to FAIL on
  deliberately-broken input, and warns that a clean first run proves nothing. It does not close the
  next hole: **a break that silently fails to apply produces a clean run too**, and the two are
  indistinguishable from the suite's output. Hit twice now — feature 3a had a red-proof whose break
  didn't apply and showed green-on-"broken" input; BL-25's check-17 proof had a `perl -0pi`
  substitution whose escaping was wrong, replaced nothing, and left the suite green. Both were
  caught only by separately counting occurrences before and after.
- **fix sketch:** extend that bullet — a break must be **asserted**, not assumed: count the target
  occurrences before and after the mutation and fail loudly on 0 replacements (the BL-25 proof uses
  a Python `assert s.count(old) == 1` for exactly this), and restore from a backup afterward,
  confirming byte-identity. Route via `/skill-builder distill`, which owns DOCTRINE.md's upkeep —
  this is a distilled practice lesson, not a one-off edit.

### BL-32 — five skills prescribe `records.sh new --template <resolved>` with no doctype — an invalid invocation
- **source:** feat stream, BL-25 build (2026-08-19).
- **status:** done (2026-08-19, feat stream) — all five now name the doctype. `blueprint/SKILL.md`
  was fixed with the `design`→`specs` rename; `contractor/SKILL.md`, `debugger/SKILL.md`,
  `workstream/SKILL.md`, `workstream/verbs/ship.md` in the follow-up sweep. Verified by
  enumeration: `grep -rn 'records.sh new --template' skills/` returns nothing.
- **body:** `records.sh new` takes the doctype as its **first positional** (`records.sh new
  <doctype> --title "…" [--template <path>]`). Five skills write the shorthand
  `records.sh new --template <resolved>` with the doctype dropped:
  `blueprint/SKILL.md:47`, `contractor/SKILL.md:38`, `debugger/SKILL.md:47`,
  `workstream/SKILL.md:114`, `workstream/verbs/ship.md:155`. Run literally it does not degrade —
  it parses `--template` **as** the doctype and exits on usage (verified against a stood-up
  fixture). The conforming spelling already exists elsewhere in the same corpus
  (`analyst/SKILL.md:99`, `auditor/SKILL.md:80`, `debugger/SKILL.md:144`), so this is drift within
  the prescription, not an undecided convention.
- **why it survived BL-25:** lint check 17 keys on a span carrying **`--title`** — that is what
  makes an invocation decidable from prose merely naming the tool. These five spans carry no
  `--title`, so they sit exactly in its blind spot. Distinct defect, distinct guard.
- **fix sketch:** insert the doctype in all five. A second check-17 arm could FAIL a span whose
  first token after `records.sh new` starts with `--`; that rule is narrow and has no
  prose-ambiguity problem, so it is cheap. Prove by breaking, as ever.

### BL-31 — the seed's prose still calls the doctrine home "the handbook"
- **source:** feat stream, feature 3a build (2026-08-18).
- **status:** done (2026-08-19, grok stream) — seed POLICY + context.sh `HB`→`DH`; backlog/journal/blueprint "handbook" → "doctrine". `.handbook/` path literals for the legacy tree stay.
- **body:** 3a's census was of `.handbook` **path literals**, and every one of those is now
  flipped. What it did not cover is the **bare word**: a deployed doctrine home still describes
  itself as "the handbook" in `skills/clankshop/seed/review/POLICY.md` (5×),
  `skills/clankshop/seed/scripts/context.sh:36`, plus `skills/backlog/SKILL.md:94,99`,
  `skills/blueprint/SKILL.md:340`, and `skills/journal/SKILL.md:136`. The loader also still
  names its root variable `HB`. Nothing is broken — the paths all resolve — but a project whose
  doctrine lives at `.dev/doctrine/` reads doctrine that calls itself something else.
- **fix sketch:** one prose sweep for the bare word, plus `HB` → `DH` in `context.sh`. Cheap and
  mechanical; deliberately deferred out of 3a so the slice boundaries stayed checkable against
  the spec's census. Check 15/16 cannot see any of it (they match path literals), so it needs a
  human-driven sweep rather than a gate.

### BL-30 — `seed.sh` validates `--workspace`; nothing validates the door that feeds it
- **source:** feat stream, feature 3a build (2026-08-18).
- **status:** done (2026-08-19, grok stream) — kept both halves, now owned: check 16 is authoring-time; `seed.sh` is the runtime half that sees a consuming `--workspace`. Documented in both.
- **body:** 3a's Decision 13 assigns both declaration guards to lint check 16, which reads the
  **front door**. That is right for the library's own gate, but a consuming project's `setup`
  run is not linted: the verb resolves `agent-workspace:` from the door and passes it to
  `seed.sh`. S3 therefore added argument validation to `seed.sh` itself (refuse `.`, refuse an
  absolute path) — a guard the spec does not describe. It is defensive and cheap, but it means
  the "forbidden `.`" rule now has **two** enforcers with no single owner, which is exactly the
  shape Decision 13 was written to avoid.
- **fix sketch:** decide whether the script-side guard is doctrine (document it in M1 as the
  runtime half of the same rule) or redundant (drop it and rely on the verb). Do not silently
  keep both un-owned.

### BL-29 — two slices in 3a's spec would have reddened the trunk gate as written
- **source:** feat stream, feature 3a build (2026-08-18).
- **status:** done (2026-08-19, grok stream) — lesson folded into `DOCTRINE.md` authoring conventions: a slice names every file it breaks.
- **body:** Two ordering defects survived four review rounds and were caught only at build time.
  (1) **Check 15's new `.records/doctrine/` literal** was specified to land in S2 as a FAIL, but
  the literal was live in five consumer skills until S5 — it would have failed the trunk gate for
  the whole S2–S5 window. Round 3's MUST-FIX #3 caught exactly this for check 16 and gave it a
  WARN carve-out; nobody applied the same reasoning to check 15. Built with the same staging
  (WARN in S2, FAIL in S6). (2) **S3 relocating the seed broke `setup-journal-test.sh`**, a file
  the spec assigns to **S4** — so S3 could not have landed green on its own. The path was
  repointed in S3; the substantive S4 work stayed in S4.
- **fix sketch:** nothing to fix in the code. The generalizable lesson for the roadmap's standing
  discipline: **a slice's `paths` must include every file its own change breaks, not only the
  files it means to edit.** Both defects are the same class — an edit surface enumerated by
  intent rather than by consequence, which is the failure mode this feature's reviews kept
  finding in a different guise.

### BL-28 — `analyst-facts.sh` carries a second, drifted copy of the reserved-name carve-out
- **source:** feat stream, workspace-consolidation review round 2 (2026-08-18).
- **status:** done (2026-08-19, `f2c5c8f`) — `doctrine/` added to `each_record`'s carve-out, with a
  comment pinning it to `records.sh`'s set. Red-proofed: removing the new arm reddens two new
  `facts-test.sh` assertions that plant a `status: open` record in each reserved directory. The
  **ownership** half of the fix sketch is deliberately NOT resolved — two copies still exist by
  contract; that is now in scope for BL-34.
- **ownership half closed** (2026-08-19, feat stream, BL-34 item 1): there is no reserved-name
  list left to keep in step. Both `records.sh` and `analyst-facts.sh` now run the *same positive*
  test — a dated filename plus front-matter declaring a doctype — so the drift this entry
  describes has no surface to recur on. `facts-test.sh` red-proofs it by dating a planted file
  and asserting it becomes a record.
- **body:** `skills/journal/scripts/records.sh:64,82` is not the only place the reserved-name list
  lives. `skills/analyst/scripts/analyst-facts.sh:76-81` independently filters
  `grep -v -e "^$RR/templates/" -e "^$RR/scripts/"` — and **omits `doctrine/`**, so analyst already
  scans `.records/doctrine/` as if it were a store. Two copies, one already drifted, is why the
  spec's framing of the carve-out as living in a single place was wrong.
- **fix sketch:** decide whether the list has one owner (journal, exposed via `records.sh`) or is
  duplicated by contract. Feature 3b touches `analyst-facts.sh` anyway — fold it there, or fix
  standalone. Prove by breaking: plant a front-matter-less file in each reserved dir and confirm
  both tools skip it.
- **addendum (2026-08-18, review round 3):** a **third** copy, drifted the same way.
  `skills/clankshop/verbs/migrate.md:58` states the reserved set as
  "(`templates/`, `scripts/`, `history.tsv`)" — three names, **omitting `doctrine/`**, against
  `records.sh:64`'s four (`templates/*|scripts/*|doctrine/*|history.tsv`). So it is now three copies
  with two drifted, and both that drifted dropped the *same* name. That strengthens the one-owner
  reading in the fix sketch: prose copies of a tool's contract rot toward whatever the author
  remembered. Whoever fixes this should sweep for further copies rather than patch the three known
  ones.

### BL-27 — `standup.sh` creates a **declared** records home, which Doctrine-touching rule 3 forbids
- **source:** feat stream, workspace-consolidation review round 2 (2026-08-18).
- **status:** done (2026-08-19, grok stream) — 3a's owner exception landed: journal assembles the records home and may create a declared one. `standup.sh` now matches doctrine; no script change.
- **body:** `skills/journal/scripts/standup.sh:44` runs `mkdir -p "$rr/scripts"` regardless of
  whether `$rr` was *derived* or *declared*. `DOCTRINE.md` rule 3 permits creating a home "only when
  the home is the derived default" and says "never create an explicitly declared home that is
  absent." The incumbent tool does not obey the rule the doctrine publishes. Surfaced while
  specifying the same branch for the workspace home — feature 3a resolves the *doctrine* side by
  adding an **owner exception** to rule 3 (the skill that assembles a home may create it even when
  declared); this entry is the records side, which 3a does not touch.
- **fix sketch:** once 3a's owner exception lands, confirm `journal` qualifies as the records home's
  assembler and that the rule's wording covers it — or change `standup.sh` to refuse a declared,
  absent home. Do not fix before 3a; the rule it must satisfy is being edited.

### BL-26 — `skill-builder new` will keep minting skills that carry retired path variables
- **source:** feat stream, workspace-consolidation review round 2 (2026-08-18).
- **status:** done (2026-08-19, grok stream) — `new.md` now inlines the records resolver and
  the templates home as `<agent-workspace>/templates/<name>/`. Check 16 bans the retired
  `agent-templates` literal.
- **was:** **partly done (2026-08-18)** — feature 3a's S6 added the `agent-workspace`
  resolver to `new.md`'s list, so a newly scaffolded doctrine-touching skill is no longer born
  failing check 16. The `agent-templates` half stays open for **3b**.
- **body:** `skills/skill-builder/verbs/new.md:35-36` tells the scaffolder to inline "the
  agent-records / **agent-templates** resolvers (default paths named literally)". Feature 3b retires
  `agent-templates`; feature 3a retires `agent-doctrine`. Until `new.md` is updated, every skill
  scaffolded after those land is born carrying a retired variable — forward debt that grows with
  each new skill, and the new lint check 16 (3a) would FAIL them on creation.
- **fix sketch:** update `new.md`'s resolver list as the **last** step of 3a and again after 3b, so
  the scaffolder never prescribes a variable that no longer resolves. Cheap; easy to forget because
  it is a *producer* of violations rather than a carrier of one.

### BL-25 — `contractor`'s job verbs drifted from the `--template` form its own SKILL.md prescribes
- **source:** feat stream, workspace-consolidation review round 2 (2026-08-18).
- **status:** **done (2026-08-19)** — roadmap Phase 2. The three verbs mint via
  `--template <resolved>`; **lint check 17** now FAILs on any bare mint, and journal's
  `records-test.sh` cuts the fallback out of a fixture copy of `records.sh` to show the prescribed
  form survives and the bare form hard-errors. The census turned up a **fourth** carrier this
  entry never named — `debugger/templates/investigation.md:3` — flipped in the same batch.
  The fallback is now provably reachable only by a bare mint, so 3b may delete it.
- **body:** `contractor/SKILL.md:38` prescribes minting via the agent-templates rule —
  `records.sh new --template <resolved>`. But `verbs/plan.md:62`, `verbs/roadmap.md:28`, and
  `verbs/runbook.md:15` all call `records.sh new plans --title "…"` **bare**, relying on
  `records.sh:180`'s fallback (`tpl="$RR/templates/$doctype.md"`) to find `contractor/templates/plans.md`.
  Discovered because a draft proposed deleting that fallback on the claim that "both real callers
  always pass `--template`" — false, and the three bare callers would have hard-errored.
- **fix sketch:** convert the three verbs to the prescribed `--template <resolved>` form. This is a
  **precondition** for feature 3b's option to delete the fallback — until it lands, that fallback is
  load-bearing shipped surface. Prove by breaking: delete the fallback on a fixture and confirm the
  three verbs error before the fix, and pass after.

### BL-24 — the doctrine has no principle for when a skill is "too big", and payload isn't counted
- **source:** feat stream, workspace-consolidation spec discussion (2026-08-18).
- **status:** done (2026-08-19, grok stream) — surface-vs-payload folded into `DOCTRINE.md` authoring conventions. The "keep everything in clankshop" decision stands.
- **body:** Splitting `clankshop` was proposed three times in one session — extract the doctrine
  layer as `handbook`; then extract the management verbs as `foreman`. Every review that checked
  found **no principle in `DOCTRINE.md` grounding the concern** (the skeptic lens: *"on the evidence
  in the repo, Problem 2 is aesthetic"*; the nearest hits are about self-contained examples and
  boundary scoping, `:86-128`). That is a **doctrine gap, not a refuted instinct** — there is
  nothing to test the concern against, so it keeps returning.
  Measurement then inverted the premise: `clankshop` has the **smallest `SKILL.md` in the pack**
  (54 lines vs blueprint 370, workstream 233, journal 139) and 4 verbs (vs workstream 9,
  contractor 6) — while carrying the **most files** (31; 16 are `seed/`, 9 are `scripts/`).
  So there are two distinct sizes and the library names neither: the **surface** an agent loads to
  route and operate (`SKILL.md` + verbs), and the **payload** it carries to deploy (seed content,
  scripts). Coupling lives in surface; splitting by role moves payload without reducing it.
- **fix sketch:** a `/skill-builder calibrate` pass folding a surface-vs-payload distinction into
  `DOCTRINE.md` — what each is, which one a split actually relieves, and any rough bound worth
  stating. Then the next "this skill feels big" has something to test against. Note the decision
  this came from: everything stays in `clankshop` (2026-08-18, human, on the measurement).

### BL-23 — check 14's coverage is 2 of 5, because most skills have no `## Edges` block
- **source:** feat stream, front-door-homes build, S5 (2026-08-18).
- **status:** done (2026-08-19, grok stream) — BL-17 shipped the missing blocks; auditor/debugger/workstream now `consumes: doctrine`. Check 14 can fire on all five flipped consumers.
- **body:** `skills-lint.sh` check 14 (doctrine home not resolved) is **edge-gated** — it only
  inspects skills declaring a `doctrine` typed edge. Of the five consumers flipped onto home
  resolution, only `blueprint` and `contractor` had an `## Edges` block to declare it in;
  `auditor`, `debugger`, and `workstream` have none, so check 14 cannot fire on them at all.
  Check 15 (unconditional, off-home literals) still covers those three, and the review brief's
  Home-resolution axis covers the semantic half — but the mechanical floor is thinner than it
  looks from the check's description. **Deliberately not fixed in that feature** (human,
  2026-08-18): authoring three edge blocks is BL-17's territory with its own blast radius, and
  bolting it on would have repeated scope creep the feature had already pulled back twice.
- **fix sketch:** resolve BL-17 (require an `## Edges` block), then re-check that all five
  flipped consumers declare `doctrine`. Prove by breaking: plant a hardcoded doctrine path in a
  skill with an edge block and confirm check 14 fires on it.

### BL-22 — `records.sh new` performs no reserved-name check
- **source:** feat stream, agent-doctrine spec review round 2 (2026-08-18).
- **status:** dropped (2026-08-19, feat stream) — **moot by design change.** BL-34's discriminator
  removed reserved names entirely, so there is no reserved `<doctype>` left to reject. The defect
  this described was *silent orphaning* — a record minted where `list`/`check` would never look.
  That cannot happen now: the scan is a crawl at any depth, so a dated record declaring a doctype
  is found wherever it sits, including under `templates/` or `scripts/`.
- **body:** `resolve()` (`records.sh:64`) and `stores()` (`:73`) both exclude reserved
  directories, but `cmd_new` consults neither. With a matching template planted,
  `records.sh new templates --title X` succeeds today and mints a record inside a reserved
  directory — where `list` and `check` will never see it again, so it is silently orphaned
  rather than flagged. Pre-existing and **not** doctrine-specific: it applies to `templates`
  and `scripts` as they stand. Surfaced while verifying that the agent-doctrine spec's
  two-arm fix was complete; deliberately left out of that feature's scope because it is a
  separate defect with a separate blast radius.
- **fix sketch:** have `cmd_new` reject a reserved `<doctype>` using the same case arm as
  `resolve()`, and prove it by breaking — assert `new templates` exits non-zero.

### BL-21 — mint scripts still emit `records-root=` on stdout
- **source:** grok stream, records-layer init debrief (2026-08-18).
- **status:** done (2026-08-18) — both minters now print `agent-records=` and keep
  `records-root=` as a compat line (same pair as `workstream-git.sh`). Proven in
  `note-mint-test.sh` / `record-mint-test.sh`.
- **body:** `note-mint.sh` and `record-mint.sh` still print `records-root=<path>` so existing
  verb consumers keep working. Doctrine's new fact key is `agent-records=`. Rename on the
  next edit of each script (same "until that script is edited" rule as `workstream-git.sh`,
  which now prints both). Not blocking.

### BL-20 — `records.sh check` follows example links inside code blocks; the clankshop gate is red on `main`
- **source:** `feat` stream, post-rebase full gate (2026-08-18). Reproduced on `main` @ `420488f`
  with no stream code involved — `bash skills/clankshop/scripts/tests/setup-journal-test.sh` →
  `FAIL: trackers/<date>-backlog.md — broken link → notes/2026-08-01-fact.md`.
- **status:** done (2026-08-18) — `records.sh check`'s link extractor now skips code blocks
  (fenced and four-space-indented) before matching `→ <store>/<file>.md`. Both suites green.
  **The first-segment filter turned out to be no defense here** — an example teaching the
  tracker-line form *must* name a real store to be useful, which is exactly what that filter
  keys on; only skipping code blocks fixes the class. Regression test in
  `skills/journal/scripts/tests/records-test.sh` covers both fence styles plus the indent, and
  carries a red-proof: a real broken link outside a code block, added while the examples remain,
  still fails — so the skip cannot decay into a blanket amnesty. Proven by breaking (skip
  disabled → 2 readable FAILs; restored → 56 passed).
- **body:** `skills/backlog/templates/trackers.md` illustrates the tracker-line format with two
  four-space-indented example lines (a markdown indented code block) that contain a path-shaped
  token, `notes/2026-08-01-fact.md`. `records.sh check`'s link checker extracts link targets
  without skipping code blocks — indented or fenced — so it treats the *example* as a real
  reference and reports it broken the moment a record is minted from that template. The
  `setup-journal-test` fixture mints exactly that record, so the suite goes red.
  **Candidate fix (preferred):** teach the link checker to skip code blocks — a checker should
  never follow an illustrative path, and this will recur for any template that shows a
  path-shaped example. **Alternative:** make the template's example non-path-shaped, which
  treats the symptom and leaves the checker wrong. Prove whichever fix by breaking it: plant a
  real broken link outside a code block and confirm the checker still catches it, so the
  code-block skip cannot become a blanket amnesty.

### BL-19 — a skill-owned deployed template set is a new convention with no doctrine home
- **source:** `analyst` build (2026-08-18, `feat` stream); named in
  `docs/design/2026-08-18-analyst-skill-design.md` and **deliberately deferred by the human** so
  the build could proceed.
- **status:** open — deferred on purpose, not overlooked.
- **body:** three different "a skill owns template files" shapes now coexist and none of them is
  named in `skill-builder`'s `docs/DOCTRINE.md`: (1) **journal's doctype-mint templates** — flat
  `<records-root>/templates/<doctype>.md`, slot-filled, consumed by `records.sh new`; (2)
  **debugger's bundled body-shape template** (`templates/investigation.md`) — shapes a `reports/`
  record's body, never deployed; (3) **analyst's deployed catalog** —
  `<records-root>/templates/analyst/*.md`, lazily deployed *specifically so the project can
  customize it*, never consumed by `records.sh`. Mechanically they don't collide (`records.sh`
  ignores `templates/` subdirectories — verified at review), so this is a doctrine gap, not a bug.
  **Follow-up:** a `/skill-builder calibrate` pass to name the generalized pattern (what a
  skill-owned template set is, where it deploys, who wins on conflict, whether an upgrade may ever
  overwrite), and then a journal-contract subsection if the pattern warrants one. Until then
  `analyst` documents its own deploy behavior in its own `SKILL.md` and journal's contract is
  untouched.

### BL-18 — `records.sh new` cannot set `tags:` at mint time
- **source:** `analyst` spec review (2026-08-18, `feat` stream) — the soundness reviewer caught a
  spec mechanism that the tool could not actually perform; verified against
  `skills/journal/scripts/records.sh`.
- **status:** done (2026-08-18) — `new` accepts repeatable `--tag`; the
  `<tags>` slot fills `tags: [a, b]` (omitted → `[]`). Proven in
  `records-test.sh`. File-mode minters substitute the same slot empty.
- **body:** `records.sh new <doctype> --title "…"` accepts **only** `--title`, and the bundled
  `templates/reports.md` hardcodes `tags: []` with no tag slot; `touch` sets only `--status`. So no
  freshly-minted record can be tagged through the tool — any skill that wants a queryable tag on a
  record it mints must hand-edit the front-matter afterwards. `list --tag` exists and works, so the
  query half of the feature is already there; only the write half is missing. `analyst` works
  around it by filling the minted skeleton's `tags:` line along with its body (harmless — it is
  writing the body anyway), but the asymmetry will bite the next skill that mints records, and it
  makes "mint then query by tag" read as unsupported when it is merely manual. **Follow-up:** add
  `--tag` (repeatable) to `records.sh new`, and a `<tags>` slot to the doctype templates that want
  one. Low risk, contained to journal's own tool.

### BL-17 — the lint gate does not require an `## Edges` block, and SEVEN skills have none
- **source:** `analyst` build (2026-08-18, `feat` stream) — noticed while choosing coarse edge
  types to match against existing ones. **Recount 2026-08-18 (front-door-homes build):** the
  real number is **seven**, not four — `auditor`, `backlog`, `clankshop`, `debugger`,
  `journal`, `scheduler`, `workstream`. See [[BL-23]] for the lint-coverage follow-on.
- **status:** done (2026-08-18) — check 8 WARNs on a missing typed-edge block
  (pack faces still exempt). Proven red then green in `lint-edges-test.sh`.
  Backfilled `journal`, `backlog`, `auditor`, `debugger`, plus `workstream`
  and `scheduler` (same hole, not named in the original count). `journal`
  `produces: record` retires the false `analyst` orphan WARN.
  <!-- REVIEW(conflict): grok sync 2026-08-18 — incoming left BL-17 open with the seven-count; we kept done (the WARN shipped) and kept the recount + BL-23 pointer. -->
- **body:** `docs/DOCTRINE.md` says typed edges are **"required of every portable skill"** (an
  all-empty block being a *stated* disposition, not an omission), and `skill-builder new` scaffolds
  the block for new skills. But `skills-lint.sh` only validates a block that **exists** — a skill
  with no `## Edges` section at all passes silently. Four current members have none:
  `journal`, `backlog`, `auditor`, `debugger` (verified 2026-08-18; each carries zero
  `<!-- edges:` delimiters). The immediate consequence is invisible: `analyst` declares
  `consumes: record` and the gate reports it as a single-use orphan type, because the skill that
  actually *produces* records declares nothing — the warn is real but points at the wrong skill.
  **Follow-up:** decide whether a missing block should be a FAIL or a WARN (WARN first, probably,
  to avoid a flag-day), add the check, then backfill the four blocks — journal at least clearly
  produces a `record` type. Prove the new check by breaking it, per the gate doctrine.

### BL-13 — `routing-targets` emitter only matches bare backticked `/name` tokens in column-0 rows
- **source:** front-door architecture final review (2026-07-27,
  `docs/design/2026-07-26-front-door-architecture.md`).
- **status:** dropped (2026-08-19, grok stream) — **moot.** `foreman` and `foreman-health.sh` are retired; there is no `routing-targets` emitter left.
- **was:** open — first real-world run (atelier migration, 2026-07-27) passed: all 7 targets in
  the stamped door were bare backticked tokens, extracted correctly. The verbed/indented gap
  remains latent.
- **body:** the `routing-targets` emitter in `skills/foreman/scripts/foreman-health.sh` only
  matches bare backticked `` /name `` tokens in column-0 table rows — verbed targets
  (`` `/backlog bug` ``) and indented tables are missed. Revisit when the emitter meets a real
  deployed front door.

### BL-15 — migrate scaffolded a parallel doctrine beside a live incumbent system (fixed; watch for recurrence)
- **source:** atelier dogfood migration (2026-07-27).
- **status:** verb fixed (migrate.md *Absorb, don't parallel* section, 2026-07-27); entry kept for
  the pattern — re-audit after the next brownfield migration of a host with its own playbooks.
- **body:** on a host with live process doctrine in nonstandard form (project-local playbooks),
  `migrate`'s gap-fill copied grimoire's generic ROUTING/PLANNING docs in beside the incumbent
  conventions — producing a routing walk whose capture lane contradicted the host's own (shadowing)
  `/backlog` playbook, plus tracker stubs the incumbent never used. The procedure had no
  doctrine-absorption step; the executing agent surfaced the collision instead of reconciling it.
  Fix = the new migrate.md section + the atelier reconciliation pass.

### BL-14 — spine-scan resolves backtick code-span refs root-relative only
- **source:** chiropractor rubric shakedown on a migrated host (2026-07-27).
- **status:** fixed (2026-07-28) — two changes in `spine-scan.sh`: a doc-relative fallback in the
  stale-candidate existence check, and absolute-path tokens (leading `/` — runtime/OS paths, e.g.
  a vault path like `/atelier/theme.json`) excluded from candidacy entirely (they were being
  checked against the real filesystem root). Field result on the shakedown host: 298 → 244. The
  original "~250 false positives" estimate was wrong — the residual is a legitimately mixed set
  (genuine rot: deleted source files cited in rubric content; plus deliberate deleted-path
  citations in narrative docs), which stays the judge's triage per facts-not-verdicts.
- **body:** `skills/chiropractor/scripts/spine-scan.sh` resolved backtick code-span path refs
  against the repo root only, so a doc inside a nested home (e.g. an audit rubric's README
  referencing its sibling `prompts/01-security.md`) read as a stale ref even though the sibling
  resolves doc-relative.

### BL-16 — `built-against` stamps go permanently stale against a live skills library
- **source:** atelier dogfood (2026-07-27) — the host's `skill:foreman` stamp went stale within
  hours because grimoire itself advanced; refreshed once mid-session, stale again by the next
  grimoire commit touching the skill dir.
- **status:** dropped (2026-08-19, grok stream) — **moot.** `foreman` is retired; there is no `stale-stamp` check left to teach. `built-against` on workstream cheat sheets is a different, live mechanism.
- **body:** `built-against` records the skill directory's last commit sha; every commit to a skill
  in the library re-flags every deployed host's block for that skill. On an actively developed
  library this turns `/foreman check`'s `stale-stamp` fact from drift signal into a permanent nag,
  training agents to ignore it.

### BL-12 — harness-compaction spike methodology + doctrine candidates from the survival work
- **source:** compaction-survival spike + implementation (2026-07-24,
  `docs/design/2026-07-24-workstream-compaction-survival.md`); debrief sweep 2026-07-25.
- **status:** partly done (2026-08-19, grok stream) — doctrine candidates already live in workstream `flow.md` Scenario C. Methodology half still rides with BL-10 (deferred).
- **body:** two durable byproducts of the spike, parked here so they outlive the design doc's
  evidence section. **(1) Reusable methodology:** the spike validated skill-text behavior under a
  *context event* (compaction) with a planted-token fixture — a throwaway repo with a queue of
  ~40k-token files each hiding a verifiable token, driven by REAL interactive harness sessions
  (tmux-scripted Claude Code + Codex), with the harness's own transcript/rollout JSONL as pass/fail
  evidence (compaction boundary → subsequent tool calls). This is the event-driven sibling of
  BL-10's pressure-test methodology (baseline/pass scenarios for *invocation*; this tests
  *survival*), and its natural home is the same: `skill-builder`'s testing discipline. Two
  fixture gotchas worth carrying: random word-salad filler makes Claude's summarizer refuse
  deterministically (use benign fake telemetry), and small/fast models shell-script around
  ingestion (`cat >/dev/null` + `rg`) unless the fixture forbids text-processing shortcuts — which
  is also a real-world observation: small models compact less than window size suggests, then
  compact densely once genuinely ingesting. **(2) Doctrine candidates for the next
  `/skill-builder calibrate`:** "state that must survive context loss lives in a
  front-door-registered anchor + on-disk artifact, never in the transcript" (front-door files are
  re-injected every request in both harnesses — compaction-proof by construction; spike-verified);
  and the gotcha that compaction itself can *fail* two ways (content refusal; window exhaustion —
  recurrent on small models), so a durable-record + fresh-session path must always exist beneath it.

### BL-11 — extract the compaction-survival machinery into `/handoff` (on a second consumer)
- **source:** `docs/design/2026-07-24-workstream-compaction-survival.md` (*Changes* → boundary
  call: "workstream-first, shaped for extraction"); handoff simplification (2026-07-25, commit
  `2755d80`).
- **status:** open
- **body:** the involuntary-reset problem is not workstream-specific — any session keeping its
  state in a hand-off artifact (e.g. a root `HANDOFF.md` marathon) faces the same
  compaction-with-no-resume-trigger gap. The generic halves that would lift into `/handoff`:
  the "compaction = involuntary reset" re-entry ritual (stop → re-read the artifact in full →
  reconcile durable records against the summary → continue) as Resume-discipline doctrine; a
  generalized anchor clause (today's `templates/compaction-anchor.md` keys on `WORKSTREAM.md` /
  `.workstreams/` custody — a generic contract would let an artifact declare its location
  convention + durable records + re-entry ritual); and the freshness principle ("a save is
  justified by imminent or unpredictable loss"). Workstream would keep only its specifics
  (START HERE, Coordinates, `flow.md`, seams). **Deliberately deferred** until a second real
  consumer feels the pain (e.g. a root-`HANDOFF.md` session observed limping through a
  compaction) — one data point is not a generic interface; two lets the contract fall out of
  their differences. The 2026-07-25 root-only simplification of `/handoff` (one artifact, one
  lifecycle) already shrank the target contract.

### BL-10 — port `writing-skills`' pressure-test methodology into `skill-builder`
- **source:** `feature-debugger-refinements` workstream (2026-07-23), item 3's `superpowers`
  comparison research; deliberately deferred by the human rather than built in that stream (scope —
  it's `skill-builder`'s own tooling, not that stream's brief).
- **status:** open
- **body:** the `superpowers` plugin's `writing-skills` skill treats skill-authoring as TDD applied to
  process documentation: write a pressure-test scenario, dispatch a fresh subagent *without* the skill
  and watch it fail (baseline), write the skill, re-run the same scenario and watch it pass, then
  refactor to close any rationalization loopholes the agent found. `skill-builder` already has one
  instance of "test with a fresh agent" — the routing-probe in `docs/BOUNDARY-AUDIT.md` — but that only
  checks whether a `description:` routes correctly, never whether a skill's *body* actually changes
  behavior once invoked. **Follow-up:** add a pressure-test pass to `skill-builder new` (baseline a
  fresh agent against the target scenario before the skill exists) and/or `skill-builder check`
  (re-verify compliance after an edit) — scope the concrete verb/step shape when it's actually picked
  up, this entry is a pointer, not a design. Natural home: alongside `skill-builder`'s existing
  routing-probe discipline.

### BL-9 — `skill-builder` exists now: BL-5/BL-6/BL-7 have a concrete owner, still unresolved
- **source:** Phase 7 capstone (2026-07-19), debrief on landing
  `docs/design/2026-07-19-phase7-skill-builder.md`.
- **status:** done (2026-08-19, grok stream) — BL-6 and BL-7 shipped earlier; BL-5 is moot (`foreman` retired). Owner exists; no remaining first-task from this entry.
- **body:** Phase 7 built the `skill-builder` skill (`new`/`check`/`distill`) that BL-5, BL-6, and BL-7
  each named as their *future* natural home — that skill is real now, but Phase 7 deliberately did
  **not** use it to fix any of the three (scope discipline: the capstone's deliverable was the skill +
  the doc reconciliation, not a refactor pass). All three remain open with the same bodies; they're
  candidate first tasks for `skill-builder new`/`check` rather than hand-authored fixes. **A genuine
  implementation surprise worth recording:** moving `scripts/skills-lint.sh` into the skill bundle
  (`skills/skill-builder/scripts/`) broke its own default `<agents-root>` resolution — it used to derive
  the root from its own script path (`dirname "$0"/..`), which only worked because the script lived
  exactly one level above `skills/`. Three levels deep inside a bundled skill, that trick resolves to
  the wrong directory. Fixed by defaulting to `$(pwd)` instead (a maintainer naturally runs the gate
  from the library root). **Lesson for any future "move a script into a skill bundle" migration:**
  audit self-path-relative defaults before moving a script — they're an easy silent break.

### BL-8 — `2026-07-17-library-refactor.md`'s "Phase 2 deferred" status is now partly stale
- **source:** Phase 6 doc-reconciliation pass (2026-07-19), incidental find while distilling the
  self-init roadmap's own accreted docs.
- **status:** done (2026-07-19) — status line + Phase 2 section updated to reflect `extract`/`reconcile`
  shipped; ralph-loop expansion called out as still deferred, in place.
- **body:** that doc's §4/§8 mark `architect`'s **Phase 2** ("extract a design seed from code" +
  "`check` extended to design ↔ code drift") as *deferred*. Both have since landed — under different
  verb names than the doc predicted: extraction is `architect extract` (writing
  `.records/design-draft/`, exactly the described shape) and the drift-check is `architect reconcile`
  (not an extension of `check`). The doc's third Phase 2 item — the spec-driven / "ralph-loop"
  expansion — genuinely remains undone. **Follow-up:** update that doc's status line to something like
  "Phase 2: extraction + drift-check shipped (as `extract`/`reconcile`); ralph-loop expansion still
  deferred" — a small, low-risk edit, just outside this roadmap's own Phase 6 scope (that doc predates
  this roadmap and isn't one of its accreted design docs), so left for whoever next touches
  `architect`'s doc trail, or a Phase 7 `skill-builder` sweep.

### BL-7 — `built-against: git rev-parse HEAD` collapses to one value across a monorepo skills-root
- **source:** Phase 5 rollout, `foreman` landing (2026-07-19); reproduced via
  `foreman-health.sh check-projection` against a scratch fixture registering `backlog`/`auditor`/
  `foreman` from grimoire's own `skills/`.
- **status:** done (2026-07-19) — swapped the formula to `git -C <skill-dir> log -1 --format=%h -- .`
  (path-scoped, not whole-repo `HEAD`) in `backlog`/`architect`/`feature`/`auditor`'s registration
  prose, `foreman-health.sh`'s `cmd_check_projection`, and `skill-builder new`'s scaffold template
  (so future skills get it right from day one). Re-verified against a scratch fixture:
  `check-projection` now stamps `backlog` at its own last-touch sha (`4b32a2b`), not the repo tip.
- **body:** every `init`'s `built-against` stamp (and `check-projection`'s "current version" side) is
  computed as `git -C <skill-dir> rev-parse --short HEAD` (backlog's `verbs/init.md`, and now
  feature/architect/auditor/foreman's equivalents, plus `foreman-health.sh`'s `cmd_check_projection`).
  That command returns the **whole repo's HEAD**, not a per-directory version, whenever `<skill-dir>`
  is a subdirectory of one git repo rather than its own repo/submodule — exactly grimoire's own shape,
  and exactly what a consuming project would get if it vendors grimoire's `skills/` as a git submodule
  rather than a flat copy. Reproduced: registering `backlog`+`auditor` in one commit then `foreman` in a
  later commit, `check-projection` reports **both** earlier skills as `stale-stamp` with an identical
  `now=<latest-repo-HEAD>` — even though neither skill's own files changed since it registered. A flat,
  non-git copy of `skills/` (the more common deployed shape, per BOOTSTRAP's playbook) sidesteps this
  cleanly (`git -C` fails, falls back to `unknown` on both sides, no spurious diff) — so this is a
  **monorepo/submodule-specific** false-positive, not universal. **Follow-up:** swap the formula to a
  per-directory last-touch stamp — `git -C <repo-root> log -1 --format=%h -- <skill-dir>` (or `(cd
  <skill-dir> && git log -1 --format=%h -- .)`) — in both the registering skills' `init` prose and
  `check-projection`'s `cmd_check_projection`. Advisory severity (a spurious `stale-stamp` just prompts
  an unnecessary re-`init`, no data loss — distinct from BL-3's silent-write-failure class), so deferred
  rather than fixed inline; natural home: alongside BL-5/BL-6, once Phase 5's rollout finishes and every
  `init` site touching the formula is known.

### BL-6 — register-route.sh is now duplicated per-skill; keep the write-protocol in sync
- **source:** Phase 5 rollout, `feature` landing (2026-07-19); commit `77c2a52`.
- **status:** done (2026-07-19) — a literal shared file was rejected (would make every durable-home
  skill silently depend on `skill-builder` being installed, breaking "self-init, no floor").
  Resolution: `skill-builder` bundles the **reference** copy (`scripts/register-route.sh`) and a new
  **drift check** (`scripts/register-route-drift.sh`, wired into `skill-builder check` Pass 2) that
  diffs every deployed copy's functional body (comments stripped) against it — `checked=5 drift=0` as
  of this fix. `skill-builder new` now stamps fresh copies from the reference for future skills. The
  duplication itself is unchanged (correct, not a defect) — "keep in sync by convention" is now
  "keep in sync, mechanically checked." See `docs/design/2026-07-19-skill-builder-followups-plan.md`.
- **body:** `feature` landed its own front-door self-registration by bundling a **second copy** of
  backlog's `scripts/register-route.sh` (byte-identical mechanism, only the doc comment reworded) —
  deliberate, per the *self-contained skill directory* rule: a portable skill carries no cross-skill
  script dependency, so `feature` cannot `source` or shell out to `../backlog/scripts/register-route.sh`.
  Phase 5 will produce a **third and fourth** copy (`architect`, `auditor`; `foreman` last). All four
  copies share one write **contract** — delimiter syntax (`skill:<name> BEGIN built-against:<ba>` /
  `skill:<name> END`), the `## Skill routes (self-registered)` section name, and the
  absent→append / present→replace / malformed→refuse-and-report idempotency rule (model §3.4) — with
  **no shared code**, by the same design tradeoff BL-5 already accepted for the edge-block parsers.
  **Follow-up:** no fix needed now (each copy is independently tested — see the fixture transcript in
  commit `77c2a52`'s neighbor) — but a **future change to the write protocol** (a new delimiter shape, a
  different section name) must update every copy, and nothing mechanical catches a divergence. Same
  candidate remedy as BL-5: a shared test fixture the write-protocol tests run against per copy, so an
  edit that updates one copy's behavior without the others fails visibly. Natural home: alongside BL-5,
  once Phase 5's rollout finishes and the final copy count is known (up to 5: `backlog`, `feature`,
  `architect`, `auditor`, `foreman` — `foreman` still writes its **own** `skill:foreman` block as a
  registering leaf per Phase 4 §5.3, even though it is *also* the composer that owns the arrangement
  around every skill's block).

### BL-5 — keep skills-lint.sh check 8 and foreman-health.sh derive-seams parsers in sync
- **source:** Phase 4 `/foreman` re-scope (2026-07-19);
  `docs/design/2026-07-19-phase4-foreman-rescope.md` §4.2, §9.
- **status:** dropped (2026-08-19, grok stream) — **moot.** `foreman-health.sh` is gone; only the lint parser remains, so there is nothing left to keep in sync.
- **body:** `skills/skill-builder/scripts/skills-lint.sh` check 8 (grimoire's dev-time gate, moved into
  `skill-builder`'s bundle at Phase 7) and
  `skills/foreman/scripts/foreman-health.sh derive-seams` (the shipped runtime composer) both parse the
  identical `## Edges` block format (delimiters, `- kind: type,type — note` lines, the
  produces/consumes/handoff vocabulary, `/`-prefixed values as sibling names not types) — deliberately
  **not** shared code, since one is a dev-only gate over the library clone and the other ships inside
  the deployed `foreman` skill bundle (mechanism vs. harness-specifics-at-the-edge). **Follow-up:** no
  fix needed now — both parsers are correct and tested (fixture transcript in the Phase 4 design doc
  §4.2's neighbor commit) — but a **future change to the block format** (a new delimiter syntax, a
  fourth edge kind) must update both. No mechanical backstop catches a divergence; this is a **process**
  note for whoever next touches either parser, not a code fix. Candidate: a shared test fixture (a
  sample `## Edges` block both scripts' tests run against) so a future edit that only updates one parser
  fails the other's test. Natural home: alongside Phase 5's rollout (which will exercise `derive-seams`
  against real multi-skill data for the first time) or Phase 7's `skill-builder`.
  **2026-07-19 addendum:** BL-4's kind-aware orphan fix landed in both parsers together (by hand, not
  via a shared fixture) — the standing process note above still applies to the *next* format change;
  the shared-test-fixture candidate remains open, unclaimed.

### BL-4 — check-8 single-use WARN misfires on intra-skill produce↔consume pairs
- **source:** Phase 3 disposition audit (2026-07-19); `docs/design/2026-07-19-phase3-skill-dispositions.md` §5.
- **status:** done (2026-07-19) — both `skills-lint.sh` check 8 and `foreman-health.sh`'s
  `derive-seams` orphan note now track edge **kind** alongside type+skill and suppress the
  single-skill WARN when that lone skill pairs a producer-side kind (produces/handoff) with a
  consumer-side kind (consumes) for the type. `handoff-doc`'s WARN is gone (`warns=12`→`11` on the
  real tree); a fixture confirmed a genuine single-direction orphan still fires. Both parsers fixed
  together, closing BL-5's sync concern for this specific rule too.
- **body:** `scripts/skills-lint.sh` **check 8** WARNs on a type used by exactly one skill (orphan/typo
  signal). But a legitimate **intra-skill chain** — `handoff` `produces: handoff-doc` **and** `consumes:
  handoff-doc` (save→resume), `feature` `design→plan→build` — is a *single skill* on both ends and will
  trip the single-use WARN even though it is correctly paired. This is distinct from the *rollout*
  orphan-WARNs (a type with no consumer yet), which resolve once Phase 5 wires consumers; the intra-skill
  WARN never resolves. **Follow-up (Phase 5):** refine check 8 to count producer-vs-consumer *skills*
  separately, so a same-skill produce↔consume pair does not read as single-use (it also cleanly covers
  feature's internal chain). Keep the genuine cross-skill orphan WARN. Alternative: accept the WARN as a
  documented known case. Recommend the refinement.

### BL-3 — block-splicing helpers must avoid multi-line `awk -v` (BSD/macOS portability)
- **source:** Phase 1 pilot A4 (2026-07-18); `docs/design/2026-07-18-phase1-pilot-acceptance.md`;
  commit `4b32a2b`.
- **status:** done (2026-08-19, grok stream) — constraint is carried: `skills-lint.sh` documents BSD-safe no multi-line `awk -v`; live `-v` uses are single-line scalars.
- **body:** `skills/backlog/scripts/register-route.sh` splices a skill's route block into a front-door
  doc. The first cut passed the multi-line block via `awk -v blk=…`; **BSD/macOS awk rejects a newline
  in a `-v` value** (`awk: newline in string`) and the script aborted before writing (fail-safe, but
  the write silently didn't happen). Fixed by passing the block through the environment
  (`ENVIRON["BLK"]`). **Follow-up (not a fix — a constraint to carry):** Phase 5 rolls this registration
  mechanism out to the remaining 8 skills, and Phase 4's composer will *rebuild* the projection
  wholesale — any new block-splicing/registration helper must use `ENVIRON[]` (or a temp file), never
  multi-line `-v`. Candidate for a `bash -n`-adjacent lint note or a shared helper both skills call, so
  the constraint isn't re-learned per skill. `register-route.sh` + `scaffold-records.sh` are the reusable
  reference implementations.

### BL-1 — check-7 (skills-lint) has no body-level backstop for re-documentation
- **source:** boundary body audit (2026-07-18); `docs/boundary-audit.md` §"Known limitation";
  `FEEDBACK.md` [foreman] entry; commit `4688039`.
- **status:** partially done (2026-07-23) — `skill-builder check`'s `scripts/skills-lint.sh` gained
  **check 9**: WARNs when a body names 3+ distinct verbs of the same sibling within one paragraph
  (proximity-scoped to a blank-line-delimited block, so a wrapped multi-line roster still counts as
  one unit but two unrelated pointers elsewhere in the file never merge — a real false positive the
  check caught on its own first run against `workstream`'s body, fixed before landing). This closes
  the **backticked-per-verb-token** shape of the rot exactly, including the historical `foreman`
  example. **Not closed:** a prose-listed roster with no per-verb backticks, or a restated
  protocol/seam narrative (rubric item 3's broader case) — both still need the manual scan. See
  `skills/skill-builder/docs/BOUNDARY-AUDIT.md` § *The mechanical backstop*.
- **body:** `scripts/skills-lint.sh` **check 7** WARNs only on *description*-level backticked `/name`
  refs to a sibling. **Body-level re-documentation** (rubric V1 — a body section restating a sibling's
  verb roster / protocol / seam, the *bigger* class) has **no mechanical backstop**; it is caught only by
  the manual boundary-audit scan (step 2), and it *silently rots* (the `foreman` roster listed
  `architect`'s verbs as `init/brainstorm/plan/prep/distill/check` long after `architect` gained
  `extract`/`reconcile`). **Follow-up:** evaluate a `check 8` that flags a body section which enumerates
  another skill's verb set (e.g. a run of backticked `/sibling <verb>` tokens, or a "Companion
  skills / Scope boundary" heading). Keep it a **WARN, not FAIL** — some cross-mention is legitimate;
  the maintainer judges against the rubric. Natural home: Phase 2's lint work, or Phase 7's
  `skill-builder audit`.
- **Phase 2 evaluation (2026-07-19):** *deferred, not folded in.* Phase 2 added `skills-lint.sh`
  **check 8** (typed-edge blocks), but a body-roster backstop does **not** fit that pass — check 8
  parses the *delimited, bounded* `<!-- edges:<name> -->` block, whereas BL-1 must scan *all body
  prose* for runs of `/sibling <verb>` attributions, a different pass with real false-positive risk
  (routers legitimately name sibling verbs) that needs the boundary-audit rubric to tune. Rushing it
  under the milestone would ship a noisy check that erodes gate trust. Reaffirmed home: **Phase 7's
  `skill-builder audit`** (or a dedicated pass), not check 8.

### BL-2 — the body-roster sweep was targeted, not exhaustive
- **source:** boundary body audit (2026-07-18); commits `0380885`, `689309f`, `da76945`.
- **status:** done (2026-08-19, grok stream) — check 9 still reports zero rosters. One-pass grep of every `skills/*/SKILL.md` for prose verb-set / `/foreman` / `/architect` roster shapes: none. Remaining BL-1 gap (prose-listed roster with no backticks) stays a manual scan, not a second lint.
- **was:** partially done (2026-07-23) — BL-1's check 9 landed and, run against the current
  12-skill tree, reports **zero** enumerated-roster findings (`warns=11`, unchanged) — an exhaustive
  sweep for the backticked-per-verb-token shape, for free, every gate run from now on. Still open for
  the shape check 9 can't see: a prose-listed roster or a restated protocol/seam narrative (rubric
  item 3's broader case) genuinely needs a one-time manual pass to rule out — not yet done.
- **body:** the body audit fixed the roster-rot pattern where it was *found* — `foreman`, `backlog`,
  and `workstream`'s templates — but did not confirm an **exhaustive** scan of all 10 skills' bodies for
  the same pattern (a body restating a sibling's verbs/protocol that can rot when the sibling changes).
  With no mechanical backstop (BL-1), an unswept body could carry a stale roster today. **Follow-up:** a
  one-pass sweep of every `skills/*/SKILL.md` + `verbs/*` body against boundary-audit rubric V1,
  recording per-skill "clean / fixed" — folded naturally into **Phase 3** (evaluate all skills) or run
  standalone. Closing BL-1 (a lint) would make future recurrences cheap to catch and largely retire
  this manual sweep.
- **Phase 3 note (2026-07-19):** *still open — Phase 3 was a different lens.* The Phase 3 disposition
  audit (`docs/design/2026-07-19-phase3-skill-dispositions.md`) read all 10 `SKILL.md` bodies, but
  scored them for **self-init / typed edges / registration**, not for rubric-V1 **sibling-verb-roster
  rot**. The exhaustive roster sweep was **not** performed here; it remains a distinct pass (best done
  once BL-1's lint exists to ground it).
- **2026-07-22 addendum:** the library has since grown an 11th skill (`skill-builder`, Phase 7,
  2026-07-19) — the two "10" counts above are frozen facts about what the 2026-07-18 audit and Phase 3
  actually covered, not live scope. The still-open Follow-up already names its target as every
  `skills/*/SKILL.md` + `verbs/*` (a glob, not a count), so the eventual sweep covers `skill-builder`
  too without needing this entry re-edited again the next time a skill is added.

---

## Done

_(none yet)_

---

> **Provenance note (2026-07-18).** The roadmap seeds this file with *"`#4`/`#5` from the body audit."*
> That numbering lived in the body-audit *session's* working notes and was never committed as an
> artifact, so **BL-1/BL-2 are reconstructed** from the committed record — `FEEDBACK.md`,
> `docs/boundary-audit.md`'s "Known limitation", and the body-thinning commits — which together capture
> the substantive deferred items (the check-7 body gap and the non-exhaustive sweep). If the original
> `#4`/`#5` were something else, amend here.
