---
doctype: plans
status: current
created: 2026-08-17
updated: 2026-08-18
tags: [plan]
---

# clankshop review remediation — Implementation Plan

**Shipped 2026-08-18** on `stream/grok` — subject: `clankshop: fold
skill-builder review findings`.

Walked 2026-08-18 on `stream/grok` — slices 1–3 verified, lint
`fails=0`. Finding 4's check script remains deferred.

Tracer-bullet: slice 1 is the setup entry an agent actually follows (Guard
before any write) — the must-fix resume/refuse-cleanly hole plus the
migrate-scan prefer-branch. Later slices pin the door/`check` contract,
then tighten the trigger.

Spec: `docs/design/2026-08-17-clankshop-review.md`

Folded 2026-08-18 `/contractor review` (`needs-rework`, `ddba24d`).
The two must-fixes and the classify-list nice-to-have are in the
slices below; the write-back list is pruned.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Invariants:** patient-zero — do not run `/clankshop setup` or
  `/clankshop migrate` in this library and do not create `.handbook/`
  here. Walk steps stay numbered 1–5 (gather, seed, journal, door,
  check). Classify lives in the Guard as `a.`/`b.`/`c.` (not a
  second 1–3), before the walk. Resume is `setup`’s job; `migrate` only
  points at it. Do not inline `journal`’s procedure — at most name
  `/journal setup`. Do not add a `check-facts` script or extend
  `context.sh --check`. Do not bump `PACK.md` `version:`. Do not add
  an `upgrade` verb. Do not paste a full `AGENTS.md` template.
- **Live-API gotchas:** re-read each cited span against
  `<worktree>` HEAD before editing. Load-bearing wraps:
  `skills/clankshop/verbs/setup.md:7-11` (Guard),
  `:26-30` (step 3 journal standup),
  `:31-36` (step 4 door).
  `skills/clankshop/verbs/migrate.md:8-12` (Guard),
  `:49-50` (journal standup),
  `:64-65` (door).
  `skills/clankshop/verbs/check.md:19-24` (steps 4–5).
  `skills/clankshop/SKILL.md:3` (`description:`, 721 chars; hard cap
  1024, prefer ≤750).
  `scripts/seed.sh` still refuses an existing `.handbook` — resume
  must never re-invoke it. `scripts/migrate-scan.sh` already emits
  `handbook=`, `records=`, `docroot=`, `tracker-shaped=`.
- **Coexisting work:** this branch is `stream/grok` in
  `/Users/cscott/Repos/grimoire/.workstreams/grok`. Sibling `feat`
  does not own clankshop. Root checkout dirt (blueprint + mailbox
  scripts + two untracked design docs) is disjoint — do not sweep
  it in.
- **CI-safety / scope:** markdown-only. Gate is
  `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`. The
  clankshop symlink WARN is expected from a worktree. Do not run
  `check` Pass 2 (`docs/BOUNDARY-AUDIT.md`). Do not edit `seed/`,
  `scripts/`, or `tests/`. `scripts/tests/setup-journal-test.sh`
  comments still say “step 2 / step 3 / step 5” — keep those
  numbers.
- Every slice’s requirements implicitly include this section and
  the spec’s receiving locks.

## File map

| Path | Responsibility | Slice |
|---|---|---|
| `skills/clankshop/verbs/setup.md` | Guard classify + `/journal setup` pointer (1); door minimum (2) | 1, 2 |
| `skills/clankshop/verbs/migrate.md` | Guard points at setup resume (1); `/journal setup` + door minimum (1, 2) | 1, 2 |
| `skills/clankshop/verbs/check.md` | Door pointer + records-root resolution | 2 |
| `skills/clankshop/SKILL.md` | Frontmatter `description:` only | 3 |

No other files. Do not touch `PACK.md`, `seed/`, `scripts/`, or
`tests/`. `setup.md` is shared by slices 1 and 2 — that is why 2
requires 1.

## Coverage

| Finding | Slice |
|---|---|
| 1 must-fix half-finished setup cannot resume | 1 |
| 6 migrate-prefer has no test | 1 |
| 2 standup pointer (not standalone) | 1 |
| 3 door shape + records-root | 2 |
| 4 records-root only (script deferred) | 2 |
| 5 description over-triggers | 3 |

Findings 2 (as its own item) and 4 (facts script) stay out.

## Slices

- [x] **Slice 1: setup entry (the tracer)** <requires: —>

  - Files: Modify `skills/clankshop/verbs/setup.md`,
    `skills/clankshop/verbs/migrate.md`
  - Findings: 1, 6 (+ finding 2 pointer)
  - Change: two surgical replacements in `setup.md`, two in
    `migrate.md`. Do not rewrite the walk’s numbered steps 1, 2,
    4, or 5. Do not call `seed.sh` from the Guard.

    1. **`setup.md` Guard** (`:7-11`). Replace the three-sentence
       Guard with:

       ```
       **Guard:** resolve the project root first — a project directory the conversation
       references, else the working directory, else ask. Then classify *before any write*:

       a. **Journal present?** If `/journal setup` is not available, stop: say so and do
          not improvise a records layer. Write nothing.
       b. **Inventory.** `scripts/migrate-scan.sh <root>` (facts). If `handbook=absent` and
          any of `docroot=`, `tracker-shaped=`, `records=present` fire, prefer `migrate` —
          show the human those keys and stop unless they confirm greenfield anyway.
       c. **Existing `.handbook`?**
          - Absent → continue the walk.
          - Present, and a `check` would be green (stamp, slots, door pointer, records
            layer) → already seeded. Stop. An upgrade the human asked for is a
            judgment-assisted diff against the current seed, anchored by the README
            stamp line — not a re-seed, not this walk.
          - Present but `check` would not be green (missing stamp, leftover `<gate>` /
            `<trunk>`, no door pointer, records layer absent) → **resume**. Start at the
            first unfinished *walk* step (1–5). Do not re-run `seed.sh` (it refuses). Do
            not treat this as "already seeded."
       ```

    2. **`setup.md` step 3** (`:26-30`). Replace:

       ```
       3. **Stand up the records layer — delegate to `journal`** (a required pack member; the records
          layer is its domain). Run its standup for `<root>`: the `.records/` stores, templates,
          `records.sh`, and the history ledger are its deployed assets, not this skill's. If
          `journal` is not available, say so and stop short of improvising a records layer — the
          workshop is doctrine-only until it stands up.
       ```

       with:

       ```
       3. **Stand up the records layer — `/journal setup`** (a required pack member; the records
          layer is its domain). Run `/journal setup` for `<root>`: the `.records/` stores,
          templates, `records.sh`, and the history ledger are its deployed assets, not this
          skill's. Do not inline journal's walk. If `journal` is not available, say so and
          stop — the Guard should have caught this; write nothing further.
       ```

    3. **`migrate.md` Guard** (`:8-9`). Replace:

       ```
       **Guard:** resolve the project root first (conversation → cwd → ask). If `<root>/.handbook`
       exists, stop — already seeded. On a genuinely bare repo prefer `setup` (nothing to migrate).
       ```

       with:

       ```
       **Guard:** resolve the project root first (conversation → cwd → ask). If `<root>/.handbook`
       exists, stop and point at `setup` — resume when `check` would be red; upgrade-as-diff
       when the human asked and `check` is green. On a genuinely bare repo prefer `setup`
       (nothing to migrate).
       ```

       Leave the workstream-worktree paragraph (`:10-12`) untouched.

    4. **`migrate.md` step 3 journal bullet** (`:49-50`). Replace:

       ```
       - Stand up the records machinery via `journal` (its standup owns `.records/` scaffolding,
         templates, `records.sh`) — pointed at the declared records root.
       ```

       with:

       ```
       - Stand up the records machinery via `/journal setup` (it owns `.records/` scaffolding,
         templates, `records.sh`) — pointed at the declared records root. Do not inline
         journal's walk.
       ```

  - Verify: from the worktree,

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "If \`<root>/\.handbook\` already exists, stop|organic structure worth adopting|Run its standup" \
        skills/clankshop/verbs/setup.md skills/clankshop/verbs/migrate.md ; \
      rg -n "classify \\*before any write\\*|prefer \`migrate\`|\\*\\*resume\\*\\*" \
        skills/clankshop/verbs/setup.md ; \
      rg -n "/journal setup" skills/clankshop/verbs/setup.md skills/clankshop/verbs/migrate.md ; \
      rg -n "point at \`setup\`" skills/clankshop/verbs/migrate.md ; \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "FAIL:|clankshop:"
    ```

    Expected: first grep empty; classify / resume / prefer-migrate
    hit in `setup.md`; `/journal setup` hits both verbs; migrate
    points at setup; lint `fails=0`; clankshop line is only the
    symlink WARN. Walk headings `1.` … `5.` still present.

- [x] **Slice 2: door contract + records-root** <requires: 1>

  - Files: Modify `skills/clankshop/verbs/setup.md`,
    `skills/clankshop/verbs/migrate.md`,
    `skills/clankshop/verbs/check.md`
  - Findings: 3 (+ finding 4’s records-root sentence)
  - Change: pin the door’s minimum bytes and the one resolution
    rule. Do not add a script. Do not paste a whole `AGENTS.md`.

    1. **`setup.md` step 4** (`:31-36`). Replace step 4
       (`:31-36`) with:

       ```
       4. **Write the door.** Integrate into `<root>/AGENTS.md` (create it if absent; integrate,
          never clobber — existing content stays). Minimum bytes — not a template:

          - a pointer that names `.handbook/README.md` (the workshop's doctrine lives in
            `.handbook/`; start there);
          - a thin routing table compiled from `core/ROUTING.md`'s dispatch rows (kind of
            work → lane). Detail stays in the handbook; the door only routes;
          - `records-root: <rel>` at line start only when the records root is not
            `.records/` (omit the line for the default).

          Do not invent a third location. Do not rewrite unrelated existing content.
       ```

    2. **`migrate.md` step 4 door sentence** (`:64-65`). Replace:

       ```
       The door is written **into** the existing
       `AGENTS.md`: pointer + thin routing table, existing content preserved.
       ```

       with:

       ```
       The door is written **into** the existing `AGENTS.md` to setup's minimum
       (pointer naming `.handbook/README.md`, thin dispatch table, `records-root:`
       only when not `.records/`); existing content preserved.
       ```

       Leave step 2’s “declared in place via the door’s
       `records-root:` line” (`:22-23`) — that is still the
       legacy-root rule.

    3. **`check.md` steps 4–5** (`:19-24`). Replace with:

       ```
       4. **Links** — every relative `.md` link inside `.handbook/` resolves, and the door
          (`AGENTS.md`) exists and names `.handbook/README.md`.
       5. **Records** — resolve the records root: the first line-start `records-root:` in
          `<root>/AGENTS.md` or `<root>/CLAUDE.md`, else `.records/`. Where
          `<records-root>/scripts/records.sh` exists, run it `check`: front-matter
          conformance and status↔ledger coherence are its facts. Missing → report the
          records layer as absent (setup's step 3 unfinished), not as a pass.
       ```

       Leave steps 1–3 and 6. Leave the intro’s “Facts come from
       the deployed scripts” — the script fold is deferred; do
       not “fix” that sentence by adding a script.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "records-root: <rel>|names \`\.handbook/README\.md\`" \
        skills/clankshop/verbs/setup.md ; \
      rg -n "setup's minimum" skills/clankshop/verbs/migrate.md ; \
      rg -n "first line-start \`records-root:\`" skills/clankshop/verbs/check.md ; \
      rg -n "under the records root's" skills/clankshop/verbs/check.md ; \
      test ! -e skills/clankshop/scripts/check-facts.sh && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: setup minimum and check resolver hit; “under the
    records root's” gone; no `check-facts.sh`; lint `FAIL:` empty.

- [x] **Slice 3: trigger** <requires: —> (parallel with 1)

  - Files: Modify `skills/clankshop/SKILL.md` (frontmatter
    `description:` only)
  - Finding: 5
  - Change: replace the quoted `description:` value. Keep
    `setup` / `migrate` / `check` / persona summons and the
    Use-when. Drop “operate” and the four-station inventory.

    Current `description:` (721 chars) becomes:

    ```
    description: "Set up or migrate an agentic workshop around a code project: doctrine (.handbook/), records (.records/), and the AGENTS.md door. Verbs: setup (greenfield bootstrap: seed the handbook, stand up records via journal, write the door), migrate (brownfield onramp: inventory, one confirmed mapping table, adopt), check (assembly validation), and persona summons (architect/foreman/guardian/admin). Use when asked to set up or migrate the workshop/handbook on a project, validate its assembly, or talk to a station persona."
    ```

    Count chars inside the quotes. Must be ≤1024, prefer ≤750
    (this draft is 516). If a later edit exceeds 750, drop the
    parenthetical verb blurbs, not the verb names or the
    Use-when.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      python3 -c 'import re; t=open("skills/clankshop/SKILL.md").read(); s=re.search(r"^description:\s+\"(.*)\"\s*$",t,re.M).group(1); print(len(s)); assert "setup" in s and "migrate" in s and "check" in s and "persona" in s; assert "operate" not in s; assert "the architect" not in s; assert len(s)<=1024' && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "FAIL:|clankshop:"
    ```

    Expected: printed length ≤750; assert exits 0; lint
    `fails=0`; clankshop line is only the symlink WARN.

## Done when

Findings 1, 3, 5, and 6 (and the finding-2 pointer) have a landed
slice. Finding 4’s script remains deferred. From the worktree:

```
cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
  rg -n "If \`<root>/\.handbook\` already exists, stop|organic structure worth adopting|Run its standup|Set up and operate" \
    skills/clankshop/SKILL.md skills/clankshop/verbs && \
  rg -n "\\*\\*resume\\*\\*|/journal setup|first line-start \`records-root:\`" \
    skills/clankshop/verbs && \
  test ! -e skills/clankshop/scripts/check-facts.sh && \
  test ! -e .handbook && \
  python3 -c 'import re; t=open("skills/clankshop/SKILL.md").read(); s=re.search(r"^description:\s+\"(.*)\"\s*$",t,re.M).group(1); assert "operate" not in s and "the architect" not in s; assert len(s)<=1024' && \
  skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
```

Expected: the stale-phrase grep is empty; resume / `/journal
setup` / records-root resolver hit; no `check-facts.sh` and no
`.handbook/` in this library; description has no `operate` / `the
architect` and is ≤1024; lint `FAIL:` empty. Body station color
(`SKILL.md:14`, `verbs/persona.md`) is allowed to keep “the
architect”.

_On completion (before landing), run the host's close-the-books sweep._
