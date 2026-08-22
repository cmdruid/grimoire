---
doctype: plans
status: published
stage: implemented
created: 2026-08-22
updated: 2026-08-22
tags: [plan]
---

# architect / contractor / inspector — Implementation Plan

Rename first (`git mv` so later slices use architect paths), then
stand up `inspector` as the critique/fold package (kind-detect +
six bundled kinds + `review` / `refine`), then strip review/revise
from the two author skills and switch `build` onto the records
gate, then compose (`PACK.md` + seed + workstream PLAN). Each
slice is independently testable. Slice 2 is not trunk-shippable
without slice 3; prefer to land slice 3 with slice 4.

Spec: `docs/design/2026-08-21-architect-contractor-inspector.md`
(`status: open`; latest review stamp **approve-with-changes**,
2026-08-22; owner 2026-08-22: caller publishes). Journal contract already
landed: `1cf8ff1` (`skills/skill-builder/specs/records-front-matter.md`).
The spec’s Slices / Mechanism / Verification blocks are the coverage
map; this file sequences them against live HEAD.

Grounded 2026-08-22 against worktree `HEAD` `1cf8ff1`.
`ground-check.sh` on the spec: `checked=14` `unresolved_count=5` —

- `skills/architect/` / `SKILL.md` / `verbs/revise.md` (slice 1 `git mv`)
- `skills/inspector/SKILL.md` (slice 2 create)
- `scripts/ground-check.sh` (spec-relative; live copies are
  `skills/blueprint/scripts/ground-check.sh` and
  `skills/contractor/scripts/ground-check.sh`)

No other path drift. Prior art:

- **`skills/blueprint/verbs/review.md` does not exist.** Spec review
  lives **inline** in `skills/blueprint/SKILL.md` (`## review`, ~260–
  326) plus founding-shaped branch in the same file. Slice 2 extracts
  that section, not a missing verb file. `verbs/revise.md` exists.
- Contractor has both `verbs/review.md` and `verbs/revise.md`.
- `PACK.md` `version: 2.4.0`. Slice 1 renames the member with **no**
  bump. Slice 4 adds `inspector` → **2.5.0**.
- `build.md:14–21` still gates on a Review-history stamp. Same gate
  restated in `contractor/SKILL.md` *Hard seams* (~109–111).
- Doctrine *Which home* is still four destinations
  (`DOCTRINE.md` 424–432).
- `records.sh touch` accepts `--status draft|published` only. There
  is **no** `--stage` writer flag. The **calling agent** writes
  `published` and, on job artifacts, `stage: approved` in
  front-matter (extra keys stay legal). Inspector `refine`
  writes `draft` and drops `stage: approved`. Inspector
  `review` writes neither.

Do **not** size from the spec’s cited paths without re-reading —
`skills/architect/…` is the post-`git mv` name.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Patient-zero.** This plan lives in `docs/design/`. Do not mint
  `.records/`. Do not add door blocks to this library’s `AGENTS.md`.
  Inventory mentions in `AGENTS.md` / `README.md` are the library
  roster, not a recovery-anchor door block.
- **Stay on `main`.** Do not `/workstream load skills`. Sibling
  streams exist; do not drive them. Do not push unless asked.
- **Journal contract is already on HEAD.** Mint `draft`; close
  `archived`. Plan gate is `status: published` plus `stage:
  approved`. After a successful walk, `stage: implemented`
  (file stays `published`). No Review-history verdict is a
  gate. Verdict words stay conversation-only.
- **Inspector approves; the caller publishes.** Passing
  `/inspector review` dumps a conversation verdict and stops.
  It does not write `status:` / `stage:`. The calling agent
  (the session that invoked review) writes `published` and,
  on plans / roadmaps / runbooks, `stage: approved`. A
  `build` waive is that same write, then walk. Architect and
  contractor **mint `draft`** and do not flip `published` at
  mint or at spec-approval.
- **`git mv`, not copy.** Slice 1 is `git mv skills/blueprint
  skills/architect`. Historical `docs/design/` keeps the old name
  as the name that shipped. Auditor’s “audit blueprint”
  (`skills/auditor/BOOTSTRAP.md` and `rules/*`) is a different
  word — do not touch.
- **Independence.** Leaves do not name sibling `/name` in
  descriptions. Composition (PACK, seed, `flow.md`) may. Inspector
  does not read architect’s `SKILL.md` or
  `templates/founding.md` at runtime. Copy the founding-shaped
  parser into `kinds/founding.md` and **inline** the six map H2s
  (authoring-time copy). Do not backtick `templates/founding.md`.
- **Inspector has no `setup`.** Missing
  `<agent-workspace>/inspector/` is not a refuse — use the bundle.
  `mkdir` of that subpath only when `<agent-workspace>` already
  exists or is the derived default `.dev` (same narrow rule as
  hooks). Never create a declared-absent workspace.
- **Persona summons stay.** Do not gut clankshop personas. Do not
  edit persona machinery except live `/blueprint` pointers in seed
  routing / workstream flow (spec *Assumed, not this spec*).
- **Gate.** `bash skills/skill-builder/scripts/skills-lint.sh .` →
  `fails=0` after each slice. A slice’s file list includes every
  path its own change reddens (README mention, PACK member dir,
  edges delimiter `<!-- edges:architect -->`).
- **Do not land slice 2 on trunk without slice 3.** After slice
  2, architect and inspector both route “review a spec” until
  slice 3 strips the author. Independently *testable*; not
  independently *shippable* as a trunk state (N1).
- **Prefer to land slice 3 with slice 4.** After slice 3,
  authors no longer review and seed/workstream still have no
  `/inspector review` until slice 4. Do not move the PLAN
  insert into slice 3 (spec N4 put it in 4). Same trunk
  caution as 2-without-3.
- **Do not implement spec Kind template “publish write”.**
  That clause is superseded by the 2026-08-22 owner note.
  Inspector verb files own verdict words, confirm parse, and
  apply rules. Publish is the caller. Do not amend the spec
  in this walk unless asked.
- **PACK versioning exception.** PACK.md says a rename bumps.
  Spec N1 wins: slice 1 rename, **no** bump; slice 4 add
  `inspector` → `2.5.0`. Do not “fix” slice 1 to 2.5.0.
- **Do not mix** this walk with unrelated dirty work.

## Slices

- [x] **Slice 1: rename `blueprint` → `architect`** <requires: —>

  Rename so later slices use architect paths. Directory, routing
  name, inventory, and live invoke pointers match the job.
  Review/revise files still present. No `inspector` package yet.
  No live `/inspector` pointer yet.

  - Files:
    - `git mv skills/blueprint skills/architect`
    - modify `skills/architect/SKILL.md` (`name:`, `description:`,
      body `/blueprint` invokes, heading, edges delimiter
      `blueprint` → `architect`)
    - modify `skills/architect/verbs/{revise,deploy,new}.md`
      (invoke strings `/blueprint` → `/architect`)
    - modify `skills/architect/docs/ideal-use.md`
    - modify `skills/architect/scripts/ground-check.sh` (comment)
    - modify `skills/clankshop/PACK.md` — **rename member only**:
      `optional:` token `blueprint` → `architect`; roster table
      row. `version:` stays `2.4.0` even though PACK.md’s own
      rule bumps on rename (spec N1). Transition note keeps
      `feature` → `blueprint` as history.
    - modify `README.md` (helpers sentence + inventory table row
      + contractor row still lists review until slice 3)
    - modify `AGENTS.md` helpers roster (`blueprint` →
      `architect`)
    - modify `skills/clankshop/seed/core/ROUTING.md`
    - modify `skills/clankshop/seed/build/workflows/feature.md`
    - modify `skills/workstream/flow.md` (two `/blueprint spec`
      sites: autonomy rule ~68, manual PLAN ~280)
    - modify `skills/workstream/verbs/create.md`
    - modify `skills/workstream/templates/design.md`
    - modify `skills/workstream/templates/workstream-handoff.md`
    - modify `skills/delegate/SKILL.md` (live “never says use
      `/blueprint`” — the spec’s verify `rg` misses this file;
      after `git mv` it is a live pointer at a missing skill)
  - Change:
    1. `git mv skills/blueprint skills/architect`.
    2. Frontmatter `name: architect`. Description routes on
       `/architect`; drop no review/revise triggers **yet** (slice
       3). Keep genesis / brainstorm / grill / spec.
    3. Replace live `/blueprint` and skill-dir identity
       (`# blueprint`, `edges:blueprint`) inside the moved
       package. Bare `/architect` stays `brainstorm`.
    4. Inventory + composition pointers listed above:
       `/blueprint` → `/architect` only. Do **not** insert
       `/inspector review` (N4).
    5. PACK member rename, no version bump.
  - Verify:
    - `test ! -e skills/blueprint`
    - `test -f skills/architect/SKILL.md`
    - `test -f skills/architect/verbs/revise.md`
    - `test ! -e skills/architect/verbs/review.md` (already true
      at HEAD; keep it true)
    - `rg -n "/blueprint" skills/architect skills/contractor skills/clankshop/seed skills/workstream/flow.md skills/workstream/verbs skills/workstream/templates skills/delegate/SKILL.md README.md AGENTS.md skills/clankshop/PACK.md`
      — no live invoke hits. Historical `feature → blueprint` in
      the PACK transition note is allowed. `docs/design/` exempt.
    - `rg -n "^name: blueprint" skills/architect/SKILL.md` — no
      hits
    - `bash skills/skill-builder/scripts/skills-lint.sh .` →
      `fails=0`
    - No `skills/inspector/` yet.

- [x] **Slice 2: stand up `inspector` package** <requires: 1>

  Critique and fold as one skill. Author skills still carry
  review/revise (slice 3 strips). Doctrine grows the fifth
  landing class.

  - Files:
    - create `skills/inspector/SKILL.md`
    - create `skills/inspector/verbs/review.md`
    - create `skills/inspector/verbs/refine.md`
    - create `skills/inspector/kinds/{spec,adr,founding,plan,roadmap,runbook}.md`
    - create `skills/inspector/scripts/ground-check.sh` (copy
      `skills/architect/scripts/ground-check.sh`; retarget the
      comment)
    - modify `skills/skill-builder/docs/DOCTRINE.md` *Which home*
      (fifth class) and the hooks “fourth landing class” sentence
      so the count stays honest
    - modify `README.md` inventory table — add `inspector` row
      (check 4 WARN otherwise)
    - modify `skills/skill-builder/scripts/skills-lint.sh`
      `bundle_prefixes` — add `kinds` so backticked
      `kinds/<kind>.md` is a real bundled-ref
  - Change:
    1. **`SKILL.md`.** In-place steward (no `init`). Description
       routes `/inspector`, review a spec or plan (or named kind),
       how should we refine / revise this, apply review findings.
       Names no sibling `/architect` or `/contractor`. Bare
       `/inspector` **asks**. Dispatch: `review` / `refine`.
       Status vocabulary: the `status` enum is
       `specs/records-front-matter.md`. Writer `stage` values
       are in-package (journal does not own them): **review**
       writes neither `status` nor `stage`; **refine** leaves
       `draft` and drops `stage: approved` if present. This
       package does **not** write `published`. Edges:
       `consumes: spec, plan, review, doctrine` — findings
       baton + artifacts + station context; `produces` /
       `handoff` empty (verdict is conversation-only). No
       floor: missing workspace copy uses the bundle.
    2. **Kind-detect** (in `review` / `refine`, once): `tags:` /
       `doctype` / shape / founding-shaped parser. Load
       `<agent-workspace>/inspector/<kind>.md` if present, else
       bundled `kinds/<kind>.md`. Unknown kind → ask or refuse;
       do not invent a rubric. `mkdir` rule as Global Constraints.
    3. **`verbs/review.md`.** Union of architect’s inline
       `## review` (`skills/architect/SKILL.md` after slice 1)
       and `skills/contractor/verbs/review.md`, behind
       kind-detect. **Drop both source “wrong artifact set”
       refuses** (architect: specs/docs only, refuse a plan;
       contractor: plans only, refuse a spec). Kind-detect is
       the only artifact gate. The six bundled kinds are
       in-scope. Unknown kind → ask or refuse; do not invent
       a rubric. Two-axis critique; **axes from the template**.
       Run this package’s `scripts/ground-check.sh`. Do not amend.
       Do not mint a record. Do not write Review history — do
       not copy the stamp write-back (“Every verdict writes a
       dated stamp”). Do not create or append `## Review
       history`. Conversation verdict: `approve` /
       `approve-with-changes` / `needs-rework`.
       - Failing (`needs-rework`): stop. Leave `draft`. Do not
         write front-matter.
       - Passing: dump the verdict. Stop. Do **not** ask
         “publish?”. Do **not** write `status:` / `stage:`.
         The calling agent writes `published` (and `stage:
         approved` on job artifacts) if they accept that
         approval.
       A `build` waive is slice 3 (the caller writes the same
       gate, then walks). Inspector does not walk and does not
       publish.
    4. **`verbs/refine.md`.** Move the shipped propose-then-apply
       machine from `skills/architect/verbs/revise.md` and
       `skills/contractor/verbs/revise.md` (live numbering,
       questions → proposal → confirm → apply → stop-or-named-
       review). Kind-specific deltas (grill-park vs spec-park,
       founding mapped H2, job-aimed push-back, legal edit
       locations) go in the **kind file**, not a forked verb.
       After apply: always `status: draft`; **drop** `stage:
       approved` if present; offer `review`. Do not copy the
       stamp-keyed After-confirm split. Do **not** copy
       Review-history disposition writes (“Do not delete
       Review history; add dispositions”). Do not create or
       append `## Review history`. Open Review-history blocks
       already on disk remain a **read** findings source; they
       are not a write target and are not required. Confirm-parse
       tokens are this skill’s `review` (or `/inspector review`).
       Do not copy `/architect review` or `/contractor review`.
       Drop contractor’s After-confirm waive-and-proceed `build`
       offer. Inspector does not walk. Named re-review runs
       this skill’s `review` on the current file. No skip-
       proposal token. Findings sources: in-session list, named
       markdown, council `RESULT.md`.
    5. **Kind files** — minimum four sections: discriminator,
       soundness axes, groundedness extras (or “none beyond
       ground-check + re-read”), refine legal locations.
       Lift from HEAD (post-slice-1 paths):
       - `spec` / `adr`: architect SKILL.md review axes +
         revise “Legal for this kind” (feature spec / ADR).
       - `founding`: copy the founding-shaped parser
         (architect SKILL.md *Founding-shaped*) into this file
         as the discriminator. **Inline** the six map H2s
         (authoring-time copy from
         `skills/architect/templates/founding.md`): `Problem
         & users`, `Scope & non-goals`, `Architecture
         (components, boundaries, interfaces)`, `Rejected
         alternatives and why`, `Working conventions &
         layout`, `Declared verification command (intended,
         not proven)`. Do not backtick `templates/founding.md`.
         Do not read architect at runtime. Soundness = those
         six H2s + leftover/gap; refine may fill a mapped H2,
         never add an H2.
       - `plan` / `roadmap` / `runbook`: contractor
         `verbs/review.md` axes + `verbs/revise.md` legal
         locations (named slice / phase / conductor step).
       Templates do not override inspector’s shared machine
       (verdict words, confirm parse). They do not publish.
    6. **Doctrine *Which home*.** Add a fifth destination to the
       block at 424–432:

       > **Inspector kinds** are undated judgment templates
       > (not mint shells, not records, not the audit rubric)
       > → `<agent-workspace>/inspector/<kind>.md`.

       Default `.dev/inspector/<kind>.md`. No new front-door
       variable. Incumbent wins; upgrade is a judgment-assisted
       diff. Amend the hooks paragraph that currently says
       “Fourth landing class” so the numbering stays true
       (hooks remain skill-keyed overlays; inspector kinds are
       the fifth). Add the narrow mkdir sentence next to
       **Narrow hooks mkdir** (same predicate).
  - Verify:
    - `test -f skills/inspector/kinds/{spec,adr,founding,plan,roadmap,runbook}.md`
    - `test -x skills/inspector/scripts/ground-check.sh` (or
      `-f` + `chmod +x` if the copy dropped the bit)
    - `rg -n "Which home" -A 20 skills/skill-builder/docs/DOCTRINE.md`
      lists five destinations including inspector kinds
    - inspector description contains review/refine and does
      **not** contain `/architect` or `/contractor`
    - `rg -n "publish\\?|touch --status published" skills/inspector`
      — no hits (caller publishes; inspector does not)
    - `rg -n "/architect|/contractor" skills/inspector` — no hits
    - `rg -n "wrong artifact|specs and design docs only|plan / runbook only" skills/inspector`
      — no hits (wrong-set refuses dropped)
    - `rg -n "write a dated stamp|add dispositions|Every verdict writes" skills/inspector`
      — no hits (no Review-history write)
    - `rg -n "waive-and-proceed|offer \`build\`" skills/inspector`
      — no hits (inspector does not walk)
    - `rg -n "Problem & users|Scope & non-goals|Architecture \\(components, boundaries, interfaces\\)|Rejected alternatives and why|Working conventions & layout|Declared verification command" skills/inspector/kinds/founding.md`
      — all six map H2s are inlined (six hits)
    - `rg -n "templates/founding.md" skills/inspector` — no hits
    - `grep -q '\`inspector\`' README.md`
    - `bash skills/skill-builder/scripts/skills-lint.sh .` →
      `fails=0`
    - Author skills still have review/revise (strip is slice 3).
      Do not land this slice on trunk without slice 3.

- [x] **Slice 3: strip author skills** <requires: 2>

  Review is no longer the author. `build` reads the records
  gate.

  - Files:
    - modify `skills/architect/SKILL.md` — drop review/refine
      from description, verb table rows (`review` / `revise`),
      pipeline ascii (`revise → review`) **and** the “except a
      `revise` confirmation” sentence under it, “`review` /
      `brainstorm` stay inline”, inline `## review`, `## After
      the verdict`, `## State between verbs` lines that name
      review/revise, Structure portability list
      (`verbs/revise.md`); **also** the opening spine
      (`review` + `revise` as this skill’s verbs), Brief the
      human “After `revise`”, “`grill` and `review` are
      primitives”, Founding-shaped parser share-list
      (`review` / `revise` — keep the parser for `grill` /
      `spec` / `deploy`), leftover class “is a `review`
      finding” → critique finding (deploy still refuses),
      feature-spec branch (`grill` / `spec` / `review` →
      `grill` / `spec` only); drop
      `consumes: review`; Status promotion, Status
      vocabulary, and `spec` step 5: mint stays `draft`, do
      not `touch --status published` (architect may keep
      “one published spec per subject” as writer prose)
    - delete `skills/architect/verbs/revise.md`
    - modify `skills/architect/templates/spec.md` (body
      “promoted to `status: published`” → published after a
      passing review, by the caller)
    - modify `skills/architect/docs/ideal-use.md` (“On
      approval: `touch --status published`” → stay `draft`;
      caller publishes after inspector approval)
    - modify `skills/contractor/SKILL.md` (description, dispatch
      table, pipeline, Brief the human, Hard seams stamp gate,
      Status vocabulary, `consumes: review`)
    - delete `skills/contractor/verbs/review.md`
    - delete `skills/contractor/verbs/revise.md`
    - modify `skills/contractor/verbs/build.md` (step 2)
    - modify `skills/contractor/verbs/plan.md` — the whole
      Output paragraph (`:70–80`): “next verb is `review`”
      **and** “running `review` first is recommended” → the
      host’s review of the job artifact / an approved plan,
      not `/contractor review`
    - modify `skills/contractor/verbs/roadmap.md` — drop
      “Flip `status: published`”; mint stays `draft`
    - modify `skills/contractor/templates/roadmap.md` body copy
      — same; no mint-time publish
    - modify `skills/contractor/verbs/runbook.md` — “passed
      `review`” → each referenced plan is `published` +
      `stage: approved` (or a caller waive of that gate)
    - modify `README.md` contractor inventory row (drop review /
      revise)
    - modify `skills/clankshop/PACK.md` contractor roster blurb
      if it still says “review / build” (content-only; still
      no bump until slice 4)
  - Change:
    1. Architect description: brainstorm / grill / spec / new /
       deploy only. Pipeline becomes
       `spec → (host review) → (caller publishes) → (host
       sequences)`. Do not name `/inspector` in the
       description. Body may keep a soft “the critique skill
       reviews documents” without a sibling slash-name; prefer
       “hand the spec to the host’s review”. Delete inline
       `## review` **and** the leftover headings/rows listed
       under Files. Delete `verbs/revise.md`. `consumes:
       doctrine` only (plus conversation/draft as today).
       Status promotion / Status vocabulary / `spec` step 5 /
       `templates/spec.md` / `docs/ideal-use.md`: the artifact
       stays `draft`. The caller writes `published` after a
       passing inspector verdict. Architect may keep “one
       published spec per subject” as writer prose, not as a
       mint-time write. Delete the leftover body sites listed
       under Files (opening spine, Brief after-revise,
       primitives sentence, Founding-shaped share-list,
       leftover “review finding” → critique finding,
       feature-spec branch) — not only the named headings.
    2. Contractor description: roadmap / plan / runbook /
       execute. Drop review / revise / “how should we revise a
       plan.” Dispatch rows for `review` / `revise` go. Pipeline:

       ```
       plan  →  (host review)  →  (caller publishes)  →  build
       ```

       Bare `/contractor` still **asks**. Status vocabulary:
       mint `draft`; caller writes `published` + `stage:
       approved` after inspector approval (do not say this
       skill “promotes to `published`”). Writer `stage` values
       in-package: caller publish on jobs → `published` +
       `stage: approved`; walk → `stage: implemented`.
       `roadmap.md` and `templates/roadmap.md`: land `draft`;
       drop the mint-time flip to `published`. `plan.md`
       Output paragraph: the host’s review / an approved plan,
       not this skill’s `review` verb.
    3. **`build.md` step 2** — replace the Review-history stamp
       gate with:

       Walk a **plan** only when `status:` is `published` **and**
       `stage:` is `approved`. Missing / not `approved` /
       `implemented` → refuse. Do not read a Review-history
       verdict. An explicit human waive: the **caller** writes
       the **same** gate (`status: published` and `stage:
       approved`) — via `records.sh touch --status published`
       plus a `stage: approved` front-matter write, or
       file-mode — notes the waive in conversation, **then**
       walks. It does not walk a `draft`. Runbooks:
       completeness check additional; each referenced **plan**
       must pass this plan gate (`runbook.md` restates that,
       not “passed review”).
    4. Restate that gate in contractor `SKILL.md` *Hard seams*
       (replace the stamp paragraph). After a successful walk,
       contractor sets `stage: implemented` (plan stays
       `published`). Archive is a later close, not automatic.
  - Verify:
    - `test ! -e skills/architect/verbs/review.md`
    - `test ! -e skills/architect/verbs/revise.md`
    - `test ! -e skills/contractor/verbs/review.md`
    - `test ! -e skills/contractor/verbs/revise.md`
    - `rg -n "verbs/review.md|verbs/revise.md" skills/architect skills/contractor`
      — no hits
    - `rg -n "latest Review history stamp|Review-history stamp" skills/contractor/verbs/build.md skills/contractor/SKILL.md`
      — no hits
    - `rg -n "stage: approved|status: published" skills/contractor/verbs/build.md`
      — the new gate is present
    - `rg -n "Flip \`status: published\`|Flip to \`status: published\`|promoted to \`status: published\`|is promoted to \`status: published\`" skills/architect skills/contractor`
      — no hits
    - `rg -n "touch --status published|touch <spec> --status published" skills/architect skills/contractor/verbs/plan.md skills/contractor/verbs/roadmap.md skills/contractor/verbs/runbook.md skills/contractor/SKILL.md skills/contractor/templates`
      — no hits (waive write in `verbs/build.md` is the
      exception; do not run this pattern on `build.md`)
    - `rg -n "passed \`review\`" skills/contractor/verbs/runbook.md`
      — no hits
    - architect / contractor descriptions have no review/revise
      triggers and no sibling `/inspector`
    - `rg -n "After the verdict|verbs/revise.md|the cross-cutting \`review\`|After \`revise\`|grill\` and \`review\` are primitives" skills/architect/SKILL.md`
      — no hits
    - `rg -n "\`review\`|\`revise\`" skills/architect/SKILL.md`
      — no hits except listed exceptions: “self-review”,
      “host’s review”, “grounded review” (the greenfield
      check). Founding-shaped parser share-list names
      `grill` / `spec` / `deploy` only.
    - `bash skills/skill-builder/scripts/skills-lint.sh .` →
      `fails=0`

- [x] **Slice 4: pack + composition** <requires: 3>

  Member set changes here. Insert `/inspector review` into the
  PLAN pipeline now that the skill exists.

  - Files:
    - modify `skills/clankshop/PACK.md` — add `inspector` to
      `optional:` and the roster table; `version: 2.5.0`;
      transition note line for 2.5.0 (`architect` rename landed
      in 2.4.0-content / this bump is the member add — say:
      Slice 1 renamed `blueprint` → `architect` with no bump;
      **2.5.0:** `inspector` joins — critique and fold, both
      artifact sets)
    - modify `skills/clankshop/seed/core/ROUTING.md` — after
      `/architect` (spec), `/inspector review`, then
      `/contractor plan` only when sequencing is required;
      caller-publish reminder (after accept, not unattended)
    - modify `skills/clankshop/seed/build/workflows/feature.md`
      — same pipeline; “have it reviewed” becomes `/inspector
      review` where the seed may name skills; same reminder
    - modify `skills/workstream/flow.md` (autonomy rule +
      manual PLAN; same reminder)
    - modify `skills/workstream/templates/workstream-handoff.md`
      (same reminder)
    - modify `skills/workstream/verbs/create.md` if it still
      only names `/architect spec`
    - modify `README.md` / `AGENTS.md` helpers roster to
      include `inspector`
  - Change:
    1. PACK member add + minor bump. Face prose may name
       members (PACK.md is a pack face).
    2. Insert `/inspector review` into PLAN: `/architect spec`
       → `/inspector review` → `/contractor plan` only when
       sequencing is required → `/contractor build`. After a
       passing `/inspector review` **the caller accepts**, they
       write `published` (job artifacts: also `stage:
       approved`) before `/contractor plan` or `/contractor
       build`. Not a new skill. Not an unattended step — do
       not publish without that accept. One reminder sentence
       in seed `feature.md`, `ROUTING.md`, `flow.md`, and
       `workstream-handoff.md`. `build` still refuses a draft
       plan if the write was skipped.
  - Verify:
    - `rg -n "optional:.*inspector" skills/clankshop/PACK.md`
    - `rg -n "version: 2.5.0" skills/clankshop/PACK.md`
    - `rg -n "/inspector review" skills/clankshop/seed/core/ROUTING.md skills/clankshop/seed/build/workflows/feature.md skills/workstream/flow.md skills/workstream/templates/workstream-handoff.md`
    - `rg -n "caller accepts" skills/clankshop/seed/core/ROUTING.md skills/clankshop/seed/build/workflows/feature.md skills/workstream/flow.md skills/workstream/templates/workstream-handoff.md`
      — the caller-publish reminder is present (after a passing
      review the caller accepts, they write `published`)
    - spec mechanical `rg`:
      `rg -n "/blueprint" skills/architect skills/contractor skills/inspector skills/clankshop/seed skills/workstream/flow.md skills/workstream/verbs skills/workstream/templates`
      — no live invoke hits
    - `bash skills/skill-builder/scripts/skills-lint.sh .` →
      `fails=0`

## Done when

- `test ! -e skills/blueprint`. Live name is `/architect`.
- `skills/inspector/` ships `review` + `refine` + six kind files
  + a `ground-check.sh` copy. Standalone (no workspace kinds
  dir) still reviews from the bundle.
- Architect and contractor have no `verbs/review.md` or
  `verbs/revise.md`. Descriptions do not route review/refine.
  They mint `draft` and do not write `published`.
- Inspector `review` dumps a conversation verdict and does
  not write front-matter or Review history. The calling agent
  writes `published` (and `stage: approved` on job artifacts)
  after a passing approval they accept. `refine` leaves
  `draft`, drops `stage: approved`, and does not write
  Review history. Kind-detect is the only artifact gate
  (no wrong-set refuses). `kinds/founding.md` inlines the
  six map H2s.
- `build` refuses a plan that is not `published` +
  `stage: approved`. Waive is the caller writing that gate,
  then walking. No Review-history stamp gate remains in
  contractor.
- Doctrine *Which home* lists inspector kinds as a fifth
  landing class.
- PACK `2.5.0` members include `architect` and `inspector`.
  PLAN pointers are `/architect spec`, `/inspector review`,
  `/contractor plan` (when sequencing is required). Seed /
  flow remind that after a passing review the caller
  **accepts**, they write `published` before plan/build.
- Lint `fails=0`.

_On completion (before landing), run the host's close-the-books sweep._

## Spec → plan coverage

| Spec requirement | Slice |
|---|---|
| `git mv` blueprint → architect; no `/blueprint` alias | 1 |
| PACK rename member only, no bump; seed/workstream rename invokes only | 1 |
| Inspector package: review (kind-detect + templates; verdict only; drop wrong-set refuses; no Review-history write), refine (propose-then-apply, always draft after apply; no disposition write; `/inspector review` tokens; no `build` offer) | 2 |
| Six bundled kinds; founding H2s inlined; fifth landing class; narrow mkdir; no setup floor | 2 |
| In-package writer `stage` values (review writes neither key; refine → `draft` + drop `approved`) | 2 |
| Strip review/revise from architect + contractor (body leftovers, not only headings); authors mint `draft`; Status vocabulary is caller-publish | 3 |
| Caller publishes after inspector approval; `build` gate = `published` + `stage: approved`; waive is the same caller write | 3 |
| PACK add inspector + minor bump; insert `/inspector review` in PLAN; caller-publish reminder after accept | 4 |
| Mechanical Verification (`git mv`, rgs, lint, kind files, build grep) | each slice |
| Judgment Verification (routing, fail/pass stop, caller publishes, refine, waive, unknown kind, standalone bundle) | 2–3 (prose + grep); exercise at build |
| Out of scope (journal contract, skill-builder/specs registry, persona deletion, auditor, council, review store, TSV width) | none — do not implement |

## Review history

### 2026-08-22 — needs-rework

Same-session author; depth dial off. Ground-check: `checked=33`
`unresolved_count=12` — all future `skills/architect/` /
`skills/inspector/` paths plus the known-missing
`skills/blueprint/verbs/review.md` (inline review; plan already
names that). Re-read HEAD `1cf8ff1` for the gate writes.

Must-fix:

- **F1** Spec: architect mints; inspector publishes. Slice 3
  strips `## review` / `revise.md` but leaves architect still
  writing `published`:
  `skills/blueprint/SKILL.md:55` (Status promotion
  `touch --status published`), `:248–254` (`spec` step 5 “On
  approval… flip via `touch --status published`”),
  `templates/spec.md:13` (“promoted to `status: published`”),
  `docs/ideal-use.md:32` (“On approval: `touch --status
  published`”). An implementer who follows slice 3 as written
  ships two publishers; `list --status published` is the
  author’s write. **Fix:** slice 3 (or 2) names those four
  sites; mint stays `draft`; only inspector (or a `build`
  waive) writes `published`.
  - resolved — those four sites on slice 3; mint stays
    `draft`. Owner override: inspector does **not** write
    `published`; the calling agent does, based on a passing
    verdict (`build` waive is the same caller write). Spec
    Mechanism restated to match.
- **F2** Same hole on the job side. `skills/contractor/verbs/roadmap.md:33`
  “Flip `status: published` while the map governs” and
  `templates/roadmap.md` body copy teach contractor to publish
  at mint. Spec: mint `draft`; publish is inspector
  (`published` + `stage: approved`). **Fix:** add both files
  to slice 3; land as `draft`; drop the flip.
  - resolved — `roadmap.md` + template on slice 3; mint
    `draft`. Caller publishes after inspector approval.
- **F3** Slice 3 change 1 under-names leftover review/revise
  in `skills/architect/SKILL.md` after deleting `## review`
  and `verbs/revise.md`: verb table rows (`review` / `revise`),
  pipeline ascii (`revise → review`), “`review` / `brainstorm`
  stay inline”, `## After the verdict` (`revise` /
  `verbs/revise.md`), `## State between verbs`, Structure
  portability list (`verbs/revise.md`). Those stay live and
  point at a deleted file. **Fix:** name every heading / row
  that still teaches review or revise.
  - resolved — verb table, pipeline, inline stay-inline line,
    After the verdict, State between verbs, Structure list
    named on slice 3 Files + Change 1.
- **F4** `skills/contractor/verbs/runbook.md:35–36`: “`build`
  still requires each referenced plan to have passed `review`
  (or a human waiver).” Not on slice 3’s file list. Slice 3
  verify `rg` for “Review history stamp” misses it. **Fix:**
  add the file; restated gate is `published` + `stage:
  approved`.
  - resolved — `runbook.md` on slice 3; gate restated;
    verify `rg` for `passed review`.

Nice-to-have:

- **N1** Dual review descriptions between slice 2 and 3
  (architect still routes “review a spec”; inspector does too).
  Spec ordered that overlap; lint `fails=0`. Do not land slice
  2 on trunk without slice 3, or move description-strip into
  slice 2.
  - resolved — Global Constraints: independently testable,
    not independently shippable; slice 2 verify repeats it.
- **N2** PACK.md’s own versioning rule bumps on rename. Spec
  N1 says no bump. Spell the exception so an implementer does
  not “fix” slice 1 to 2.5.0.
  - resolved — Global Constraints + slice 1 PACK bullet.
- **N3** `kinds/` is not in `skills-lint.sh` `bundle_prefixes`.
  Backticked `kinds/foo.md` is unchecked. Keep the `test -f`
  verify (already there); optional: add `kinds` to the prefix
  list in the same slice.
  - resolved — slice 2 adds `kinds` to `bundle_prefixes`.
- **N4** Slice 2 README inventory is check 4 WARN only
  (`inspector: not mentioned`). Gate is `fails=0`. Add the
  inventory row in slice 2 if you want a clean warn bar.
  - resolved — slice 2 adds the README inventory row.

### 2026-08-22 — needs-rework

Independent session; depth dial on (groundedness, spec-coverage,
skeptic). Ground-check: `checked=42` `unresolved_count=15` — future
`skills/architect/` / `skills/inspector/` paths, known-missing
`skills/blueprint/verbs/review.md`, and spec-relative
`docs/ideal-use.md`. Re-read HEAD `1cf8ff1`. Prior F1–F4 *sites*
are on slice 3; this pass is residue plus extract holes the fold
did not cover.

Must-fix:

- **F1** Slice 2 Change 3 “union” of architect’s inline `## review`
  (`skills/blueprint/SKILL.md:269–271` — specs/docs only; refuse a
  plan) and `skills/contractor/verbs/review.md:10–11` (plans only;
  refuse a spec). Spec Mechanism is kind-detect, then the matching
  judgment — both artifact sets. The plan never says **drop those
  refuse-the-other-set clauses**. A copy-union is the intersection
  of two refuses: inspector reviews nothing. Slice 2 verify (kind
  files, description, `publish?` rg, lint) cannot see it.
  **Fix:** drop both wrong-set refuses. Kind-detect is the only
  artifact gate. The six bundled kinds are in-scope. Unknown kind
  → ask or refuse; do not invent a rubric.
  - resolved — slice 2 Change 3 drops both refuses; kind-detect
    is the only gate; verify `rg` for wrong-set refuse language.

- **F2** Slice 2 Change 4 moves the shipped `revise.md` machine.
  Confirm-parse still names the *author* review:
  `skills/blueprint/verbs/revise.md:168,198` (`/blueprint review`
  → `/architect review` after slice 1);
  `skills/contractor/verbs/revise.md:158,185` (`/contractor
  review`). Contractor After-confirm else-path still offers
  waive-and-proceed `build` (`:227–231`). Plan says named
  re-review is this skill’s `review` and inspector does not walk,
  but a mechanical copy keeps the sibling tokens and the build
  offer. Slice 2 `publish?` rg misses `/architect`, `/contractor`,
  and `build`.
  **Fix:** confirm-parse tokens are this skill’s `review` (or
  `/inspector review`). Drop the `build` offer. Inspector does
  not walk. Verify `rg` for `/architect` / `/contractor` /
  `` `build` `` in `skills/inspector` — no hits.
  - resolved — slice 2 Change 4: confirm-parse is this skill’s
    `review`; drop `/architect review` / `/contractor review`
    and the `build` offer; verify `rg`s added.

- **F3** F3 fold is incomplete. Slice 3 Files + Change 1 name
  description, verb table, pipeline, stay-inline, `## review`,
  After the verdict, State between verbs, Structure list. After
  those deletes, `skills/architect/SKILL.md` still teaches the
  deleted verbs (live lines on `skills/blueprint/SKILL.md`):
  opening spine `review` + `revise` (`:8–12`); Brief the human
  “After `revise`” (`:26–28`); “except a `revise` confirmation”
  (`:91–92`); “`grill` and `review` are primitives” (`:94–95`);
  Founding-shaped parser shared with `review` / `revise`
  (`:112–113`); leftover is a “`review` finding” (`:128`);
  feature-spec branch includes `review` (`:143`). Verify
  `After the verdict|verbs/revise.md` and description-trigger
  greps miss the body.
  **Fix:** name those paragraphs on slice 3 Files + Change 1.
  Founding-shaped keeps the parser for `grill` / `spec` /
  `deploy`; leftover is a critique finding, not this skill’s
  `review`. Add a verify `rg` for `` `review` `` / `` `revise` ``
  in `skills/architect/SKILL.md` (allow listed exceptions:
  self-review, “host’s review”).
  - resolved — slice 3 Files + Change 1 name opening spine,
    Brief after-revise, primitives sentence, Founding-shaped
    share-list, feature-spec branch (parser kept for grill /
    spec / deploy; leftover “review finding” → critique
    finding so the `` `review` `` verify is not false-red).
    Verify `rg` for `` `review` `` / `` `revise` `` with
    listed exceptions.

- **F4** Spec Approach: the artifact’s `status` / `stage` are the
  **only** durable write from this loop. Slice 2 Change 3 says
  review does not write Review history, but the union copy still
  contains the stamp write-back
  (`skills/blueprint/SKILL.md:309–319`;
  `skills/contractor/verbs/review.md:52–63`) and slice 2 verify
  does not grep it. Change 4 copies `revise` apply: “Do not
  delete Review history; add dispositions”
  (`skills/blueprint/verbs/revise.md:215–216,259–272`;
  contractor `:200–201,233–246`). That reintroduces the review
  document the spec rejected.
  **Fix:** review and refine do not create or append `## Review
  history`. After apply: `status: draft` and drop `stage:
  approved` only. Open Review-history blocks already on disk stay
  readable (findings source), not a write target. Verify:
  `rg -n "Review history|write a dated stamp|add dispositions"
  skills/inspector` — no write instruction.
  - resolved — slice 2 Change 3/4: no stamp write-back, no
    disposition writes; existing Review-history blocks are a
    read source only. Verify `rg` for write-instruction
    strings.

- **F5** Slice 2 copies the founding-shaped parser into
  `kinds/founding.md` as the discriminator. The live parser is
  not self-contained (`skills/blueprint/SKILL.md:107–110`): the
  six map H2s live in `templates/founding.md`
  (`Problem & users` … `Declared verification command
  (intended, not proven)`). Inspector has no
  `templates/founding.md`. A backticked copy FAILs lint check 2
  (`bundle_prefixes` includes `templates/`). A runtime read of
  architect breaks independence. The slice leaves the implementer
  to invent the map.
  **Fix:** `kinds/founding.md` **inlines** the six H2 strings
  (authoring-time copy from
  `skills/architect/templates/founding.md`). Do not backtick
  `templates/founding.md`. Do not read architect at runtime.
  - resolved — slice 2 Change 5 inlines the six H2s from
    `skills/architect/templates/founding.md`; no backtick; no
    runtime read. Verify `rg` for the first H2 and for
    `templates/founding.md`.

- **F6** Spec Mechanism pipeline is `review → publish →
  plan/build`, and `publish` is a later stop by the **caller**
  (not a skill). Slice 4 Change 2 inserts only skill invokes:
  `/architect spec` → `/inspector review` → `/contractor plan` →
  `/contractor build`. Inspector review dumps the verdict and
  **stops**; it does not ask “publish?”. Seed `feature.md:26` and
  workstream `flow.md` PLAN will get the same insert. An
  orchestrator that treats those lines as the walk never writes
  `published` / `stage: approved`, then `build` refuses (or the
  human has to remember the owner rule). Spec Pack section names
  the skill invokes; Mechanism still needs the stop in the
  composed walk.
  **Fix:** slice 4 seed / `flow.md` / handoff: after a passing
  `/inspector review`, the **caller** writes `published` (job
  artifacts: also `stage: approved`) before `/contractor plan`
  or `/contractor build`. Not a new skill. One sentence in the
  PLAN prose.
  - resolved (demoted) — not an unattended pipeline box. Slice
    4 Change 2 + seed/flow/handoff: reminder that after a
    passing review **the caller accepts**, they write
    `published` (jobs: + `stage: approved`). `build` still
    refuses a draft if the write was skipped.

Nice-to-have:

- **N1** Status vocabulary still says the author-side artifact
  “is promoted to `status: published`”
  (`skills/blueprint/SKILL.md:65–66`;
  `skills/contractor/SKILL.md:47–48`). Not a `touch` writer (F1’s
  four sites are on slice 3) but still reads as the author
  publishes. Name both blocks on slice 3: mint `draft`; caller
  writes `published`; architect may keep “one published spec per
  subject” as writer prose.
  - resolved — both Status vocabulary blocks on slice 3; mint
    `draft`; caller publishes; uniqueness stays writer prose.
    Verify `rg` for `is promoted to status: published`.

- **N2** `skills/contractor/verbs/plan.md` is on slice 3 for the
  “next verb is `review`” stop (`:70–72`). `:75–80` still
  recommends running `review` first. Rephrase the whole output
  paragraph to the host’s review / an approved plan.
  - resolved — slice 3 Files + Change 2 rephrase the whole
    Output paragraph (`:70–80`).

- **N3** Slice 3 verify `rg` for `touch --status published`
  misses the live writers with a path argument (`SKILL.md:252–
  253`, `ideal-use.md:32`: `touch <spec> --status published`)
  and `Flip to` / `promoted to` in the templates; it also hits
  the named waive in `build.md`. Tighten to mint/spec/roadmap
  paths, or exclude `verbs/build.md`.
  - resolved — slice 3 verify split: `Flip` / `Flip to` /
    `promoted to` / `is promoted to` across architect +
    contractor; `touch --status published` / `touch <spec>
    --status published` excluding `verbs/build.md`.

- **N4** Spec Kind template shape still says inspector verb files
  own “publish write”
  (`docs/design/2026-08-21-architect-contractor-inspector.md:262–
  265`). Plan GC already forbids it. One Global Constraints line:
  do not implement that clause; publish is the caller. Optionally
  amend the spec sentence in the same walk (spec is still
  `status: open`).
  - resolved — Global Constraints: do not implement that
    clause; publish is the caller. Spec not amended in this
    walk.

- **N5** Plan intro says each slice is independently testable
  **and committable**. Global Constraints: do not land slice 2
  on trunk without slice 3. Align the intro.
  - resolved — intro: independently testable; slice 2 not
    trunk-shippable without 3; prefer to land 3 with 4.

- **N6** After slice 3 without slice 4, authors no longer review
  and seed/workstream still have no `/inspector review`. Spec N4
  ordered the insert into slice 4. Same trunk caution as N1
  (don’t land 3 without 4), or fold the PLAN insert into slice 3.
  - resolved — Global Constraints: prefer to land slice 3 with
    4. PLAN insert stays in slice 4 (spec N4).

- **N7** Slice 2 Status vocabulary “point at
  `specs/records-front-matter.md`” is the `status` enum. Journal
  does not own `approved` / `implemented`. Inspector and
  contractor must state those writer values in-package (review
  writes neither key; refine → `draft` and drops `stage:
  approved`; caller publish on jobs → `published` + `stage:
  approved`; walk → `stage: implemented`).
  - resolved — slice 2 SKILL.md states inspector writer
    values; slice 3 contractor Status vocabulary states job
    values (`published` + `approved`; walk → `implemented`).
    Journal pointer is the `status` enum only.

### 2026-08-22 — approve-with-changes

Named re-review after the F1–F5 fold (same-session; depth dial
off). Ground-check: `checked=43` `unresolved_count=16` — future
`architect` / `inspector` paths, known-missing
`skills/blueprint/verbs/review.md`, spec-relative
`docs/ideal-use.md`. Prior must-fix are in the slice text.

Must-fix: none.

Nice-to-have:

- **N1** Slice 1 header still says “The tracer.” Intro now
  calls it rename-first so later slices use architect paths.
  - resolved — slice 1 blurb is rename-first, not “The tracer.”
- **N2** Slice 2 founding verify greps only `Problem & users`,
  not the other five inlined H2s.
  - resolved — slice 2 verify greps all six map H2s (six hits).
- **N3** Slice 4 verify greps `/inspector review` but not the
  caller-publish reminder sentence.
  - resolved — slice 4 verify `rg` for `caller accepts` on
    seed / flow / handoff.
