---
doctype: plans
status: done
created: 2026-08-21
updated: 2026-08-21
tags: [plan]
---

# Project hooks — Implementation Plan

Tracer-bullet: `hooks.sh parse` + `hooks.sh materialize` (absolute
`--file`, refuse overwrite, cwd-independent) called from both
`create.md` and `recycle.md`, then widen into compile / drop the stamp
fill / preserve-compiled, then clankshop glue, then doctrine. Each
slice is independently testable and committable. Tests drive scripts
the verbs name; they do not “run” agent verbs.

Spec: `/Users/cscott/Repos/grimoire/.workstreams/skills/docs/design/2026-08-20-project-hooks.md`
(on the stream branch until ship; `status: open`; latest stamp **approve**;
A1 folded 2026-08-21). The spec’s Slices / Mechanism / Verification blocks
are the coverage map; this file sequences them against live HEAD.

Grounded 2026-08-21 against worktree `HEAD` `4bdb07d` (post-sync; trunk
`google-developer-style` is now on this branch).
`ground-check.sh` on the spec: `checked=24` `unresolved_count=4` — the four
are slice-1 create paths (`skills/workstream/scripts/hooks.sh`,
`skills/workstream/scripts/tests/hooks-test.sh`,
`skills/workstream/scripts/tests/run.sh`,
`skills/workstream/templates/hooks.md`). No other drift.

Prior art: `skills/workstream/scripts/workstream-git.sh` (facts, not
verdicts; bash-3.2; one stable entrypoint — **read-only**; do not copy
“never mutate” into `hooks.sh`). `compile` / `materialize` /
`compiled-put` are `seed.sh`-class writers. Test harness pattern:
`skills/journal/scripts/tests/lib.sh` and
`skills/clankshop/scripts/tests/lib.sh` (copy the small expect helpers
locally; do **not** source a sibling). Live clankshop tests drive
`seed.sh` / `standup.sh`, not `setup.md`. No existing workstream tests
dir. No existing hooks parser. Face must not shell `hooks.sh` (floor).

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Patient-zero.** Never write `.dev/hooks/` (or any workshop layout) into
  this library’s own tree as a side effect of tests. Fixtures in `mktemp`
  only. Do not mint this feature into a records home. Do not unpark BL-36.
  Do not invoke `/backlog`.
- **`$HOOKS` is always absolute**
  `<root>/<agent-workspace>/hooks/workstream.md`. Create uses the same
  `<root>` Coordinates will record (steps 1–4 already have it). Recycle
  **must** read Coordinates `root checkout:` — cwd is the worktree.
  Never a cwd-relative `hooks/workstream.md` or a worktree-local
  `.dev/hooks/` twin.
- **Instance path is Coordinates `this hand-off:`**, never a guessed
  `<worktree>/WORKSTREAM.md`. In-place compile/save target is
  `<root>/.workstreams/<stream>/WORKSTREAM.md`.
- **Never overwrite a present hooks file** (structure or bodies).
- **No generic template.** Workstream keeps *its own*
  `skills/workstream/templates/hooks.md`. No `skill-builder new` scaffold
  of a generic `hooks.md`. No `<agent-workspace>/templates/hooks.md`.
- **Stamp fill is deleted in slice 2, not before.** Slice 1 still runs
  today’s `<debrief>` fill so the hand-off keeps working.
- **`save` must preserve `## Hooks (compiled)` and `hooks-compiled:`**
  via `hooks.sh compiled-get` / `compiled-put` (slice 2). Load does not
  recompile.
- **Face does not shell `hooks.sh`.** `skills/clankshop/scripts/hooks-glue.sh`
  duplicates the empty-body strip. Setup / migrate / check name that
  path.
- **PACK.md `version:` does not bump** (member set unchanged).
- **Coexisting work.** Sibling `stream/app` owns the TUI / crates — do not
  touch. Parked on the root checkout only: revise propose-then-apply
  spec+plan; auditor field-calibration plan. Do not start those.
- **Gate.** Host full gate is
  `cd <worktree> && bash skills/skill-builder/scripts/skills-lint.sh .`
  (`fails=0`). Slice 1 also stands `skills/workstream/scripts/tests/run.sh`.
  Slice 3 adds clankshop harness cases. Red-proofs must fail when their
  check is disabled (doctrine: prove a new check by breaking it).
- **HEAD line numbers (re-read before editing; they drift):**
  - `skills/workstream/verbs/create.md` 119–123 — stamp→`<debrief>` fill.
  - `skills/workstream/verbs/save.md` **18–21** — regenerates from the
    bundled template (would wipe a compiled block). 10–16 already require
    Coordinates `this hand-off:`; do not re-teach them.
  - `skills/workstream/SKILL.md` 101–106 — stamp governs **two** things
    (debrief fill + tracker-line). 146–149 — “hand-off IS
    `<worktree>/WORKSTREAM.md`”. 168–169 — `` `/backlog debrief`'s captures ``.
  - `skills/clankshop/verbs/setup.md` 24–31 — three exhaustive arms,
    range `(1–5)`.
  - `skills/clankshop/verbs/check.md` 39 — step **6 Report**: “Fixes are
    ordinary routed work, not part of the check.”
  - `skills/clankshop/verbs/migrate.md` 104–105 — “not installed until
    step 5 is green”.
  - `skills/clankshop/PACK.md` — `workstream` is `optional:`; `version: 2.4.0`.
  - `skills/skill-builder/docs/DOCTRINE.md` 96–100 — glue bullet still names
    `foreman` as oven. 384–387 — stamp consumers still include workstream
    `<debrief>` routing. 420–426 — **three** destinations. 447–451 — rule 3
    `never mkdir` except clankshop/journal.
  - `docs/design/2026-08-19-two-roots-simple-spec.md` 21 — holds-column
    has no `hooks/`.
  - `skills/workstream/verbs/recycle.md` 49 — blanks TL;DR / Queue state /
    What’s been done / What’s next. `## Hooks (compiled)` is **not** on
    that list. Recycle restates a *subset* of create step 6 (not a
    transclude); cwd is the worktree (line 1).
  - `skills/workstream/templates/workstream-handoff.md` 129–132 —
    `<debrief>` fill probe. Loop still uses `<debrief>` tokens (84–85,
    147–178). Next heading after Coordinates is `## Delegation route` (48).
  - `skills/workstream/verbs/load.md` 18–23 — in-place find vs
    `<worktree>/WORKSTREAM.md` read (same in-place lie).

## Slices

- [x] **Slice 1: parser + skeleton + materialize (tracer)**
  <requires: —>
  - Files:
    - Create: `skills/workstream/templates/hooks.md` — exact bytes:

      ```markdown
      # workstream hooks

      Empty section = no extra glue command.

      ## Feature completion

      ## After eventful ship
      ```

      No `/backlog`. No `<debrief>`. Trailing newline after the last
      heading. Known H2 strings are exact: `Feature completion`,
      `After eventful ship`.
    - Create: `skills/workstream/scripts/hooks.sh` — bash-3.2, `set -euo
      pipefail`. Header documents argv, body delimiter, and fact-key
      transliteration. Slice-1 subcommands: `parse`, `materialize`.
      `compile` / `compiled-get` / `compiled-put` may stub `usage` and
      exit 2 until slice 2 — tests must not call them yet.

      Fact keys: `--known` slugs may contain hyphens
      (`feature-completion`); printed `hook_<key>` **transliterates
      `-` → `_`** so the fact is `hook_feature_completion=` (matches
      spec red-proof 2). Pin this in the script header.

      Hash: `shasum -a 256` if present, else `sha256sum`; print hex
      (first field). Missing file → `hash=none`.

      ```
      hooks.sh parse --file <abs> --known <slug>=<H2> [--known <slug>=<H2> ...]
      hooks.sh materialize --file <abs> --skeleton <abs>
      ```

      **parse** is read-only. Never writes `--file`. `--file` missing
      or not a file → print `file=<path-or-empty>` `hash=none`
      `status=missing` `hook_<key>=empty` for every `--known`,
      `unknown=` (empty), exit 0. Do not require `--handoff`.

      Prints:

      ```
      file=<path>
      hash=<sha256-hex>|none
      status=missing|ok|fail
      hook_<key>=empty|filled
      unknown=<H2>[,<H2>...]
      ```

      Structural H2s: lines matching `^##[ \t]+\S` that are **not**
      inside a fenced code block (a line that is exactly ` ``` ` or
      ` ```<lang>` toggles). Body = bytes after the heading line until
      the next structural H2 or EOF; strip surrounding whitespace
      (leading/trailing space, tab, newlines); then empty → `empty`,
      else `filled`. Duplicate H2 (same heading text) → `status=fail`,
      exit 2 (still print `status=fail`; do not write the file). Extra
      H2 not in `--known` → `unknown=` comma-separated in first-seen
      order, not a fail. Known H2 missing from an existing file → that
      key is `empty`; do not edit the file to add headings.

      For each **filled** hook, after the fact block:

      ```
      --HOOK-BODY-BEGIN-- <slug>
      <body bytes, post-strip>
      --HOOK-BODY-END-- <slug>
      ```

      (`<slug>` here is the `--known` slug, hyphens intact.)

      **materialize** is a writer (seed.sh-class). `--file` must be an
      absolute path (starts with `/`); relative → usage, exit 2. Never
      reads cwd for the destination. `--skeleton` must exist.
      - `--file` exists → `status=present`, do not copy, exit 0
        (checksum unchanged).
      - `--file` missing and parent directory missing →
        `status=no-parent`, **do not mkdir**, exit 0.
      - `--file` missing and parent exists → `cp` skeleton onto
        `--file`, `status=created`, exit 0.

      Prints `file=` `status=present|created|no-parent`.
    - Create: `skills/workstream/scripts/tests/lib.sh` — copy the small
      `expect` / `expect_absent` / `expect_eq` / `report` helpers from
      `skills/journal/scripts/tests/lib.sh` (same function names and
      argv). Do not `source` a sibling path. Patient-zero comment:
      fixtures in `mktemp` only.
    - Create: `skills/workstream/scripts/tests/hooks-test.sh` — red-proofs
      **1, 3, 4, 5** plus missing-file / fence / materialize cwd.
      Resolve `HOOKS_SH` from `../hooks.sh` relative to the test file.
      Known flags every parse call:
      `--known feature-completion=Feature completion --known after-eventful-ship=After eventful ship`.
      Cases:
      1. Empty parse: copy the bundled skeleton to a temp file → both
         `hook_feature_completion` and `hook_after_eventful_ship` are
         `empty`, `hash` nonempty (not `none`), exit 0. Then disable
         the whitespace-strip, confirm a `" \n"` body becomes `filled`,
         restore, confirm byte-identity of `hooks.sh`. Count the strip
         site before/after; fail on zero replacements.
      1b. `--file` missing → `status=missing` `hash=none` exit 0.
          Disable that branch, confirm fail, restore.
      3. Duplicate H2 → exit 2, `status=fail`.
      4. Unknown H2: extra `## Other` → `unknown=Other`, exit 0, known
         keys still emit. Two extras `## Other` then `## Extra` →
         `unknown=Other,Extra`.
      4b. Fenced `## Other` inside a ` ``` ` block → `unknown=` empty,
          not `fail`.
      5. Overwrite refuse: plant a file with a non-empty
         `Feature completion` body; `materialize --file <abs>
         --skeleton <bundled>` from a **different cwd** (a fake
         worktree) → checksum unchanged, `status=present`.
      5b. Relative `--file` (`hooks/workstream.md` or
         `.dev/hooks/workstream.md`) → exit 2.
      5c. `--file` absolute, parent missing (declared-absent home) →
          `status=no-parent`, no directory created.
      Fixture roots are `mktemp -d`. Never touch the library tree.
    - Create: `skills/workstream/scripts/tests/run.sh` — same shape as
      `skills/clankshop/scripts/tests/run.sh`: `set -u`, loop
      `hooks-test.sh` only this slice, print
      `workstream tests: ALL GREEN` / `FAILURES`, exit the aggregate rc.
    - Modify: `skills/workstream/verbs/create.md` step 6 (Hand-off
      instantiation), **before** copying the bundled hand-off template.
      Use the same `<root>` create already captured (steps 1–4), which
      Coordinates will record as `root checkout:` — Coordinates do not
      exist yet on first create.

      1. Resolve `<agent-workspace>` in **prose** (do not paste the
         bash resolver): first line-start `agent-workspace:` in
         `<root>/AGENTS.md` then `<root>/CLAUDE.md`, else `.dev`.
      2. Set `HOOKS=<root>/<agent-workspace>/hooks/workstream.md`
         (absolute). Never a relative `hooks/workstream.md`.
      3. `mkdir` the parent of `$HOOKS` only when (a)
         `<root>/<agent-workspace>` **already exists** as a directory,
         or (b) the home is the derived default `.dev` and the mkdir is
         `hooks/` only (creates `.dev` as a container for `hooks/`,
         **never** `doctrine/`). Declared `agent-workspace:` that is
         absent → do not mkdir; treat hooks as empty. This is the
         narrow exception doctrine rule 3 will record in slice 4;
         slice 1 names it so the landing does not contradict HEAD
         447–451 without a comment.
      4. Run `hooks.sh materialize --file "$HOOKS" --skeleton
         <skill-base>/templates/hooks.md`. Do **not** `cp` in the
         verb; the script is the copy-if-absent.
      5. Run `hooks.sh parse --file "$HOOKS" --known feature-completion=Feature completion --known after-eventful-ship=After eventful ship`.
         `status=fail` → STOP. Missing / no-parent is not a fail.
      6. Continue today’s hand-off instantiation **including** the
         stamp→`<debrief>` fill (lines 119–123 stay). Do **not** compile
         in this slice.

      Grep (slice-1 verify, not a substitute for 5/5b/5c): `create.md`
      and `recycle.md` each contain `hooks.sh materialize --file "$HOOKS"`.
      The `$HOOKS=` assignment’s RHS must include `<root>/` or `"$root"/`
      (fail if a line is `HOOKS=hooks/workstream.md` or
      `HOOKS=.dev/hooks/…`). Do **not** `rg hooks/workstream.md` as a
      negative check — that hits the legal absolute assignment.
    - Modify: `skills/workstream/verbs/recycle.md` step 4 — inherit is
      **not** a transclude. After the `this hand-off:` path check, add
      explicit bullets (cwd is the worktree, line 1):
      1. `<root>` = Coordinates `root checkout:` (not `pwd`).
      2. Resolve `<agent-workspace>` the same way as create.
      3. `HOOKS=<root>/<agent-workspace>/hooks/workstream.md` (absolute).
      4. `hooks.sh materialize --file "$HOOKS" --skeleton …` then
         `parse --file "$HOOKS"`. Fail → STOP.
      5. Then the existing restatement: preserve Coordinates, blank
         TL;DR / Queue state / What’s been done / What’s next.
      Do not add `## Hooks (compiled)` to the blanked list.
    - Modify: `skills/workstream/SKILL.md` Helper scripts — add
      `scripts/hooks.sh` next to `workstream-git.sh` (parse/materialize
      now; compile/preserve in slice 2). Do not add `hooks.md` to
      Project templates (package-only).
  - Change: Mechanism *Path and tree* + `hooks.sh parse` +
    `materialize`. Tracer is: skeleton exists, `materialize` copies it
    to an absolute `--file` even when cwd is a fake worktree, parse
    reports both keys empty, a present file is left byte-identical,
    recycle names the same absolute `$HOOKS`.
  - Verify:
    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
      bash skills/workstream/scripts/tests/run.sh
    ```
    Expect: ALL GREEN. Named red-proofs go red when disabled and green
    after restore. Verb greps (fail on 0): `create.md` and `recycle.md`
    each contain `hooks.sh materialize --file "$HOOKS"`; each `$HOOKS=`
    RHS contains `<root>/` or `"$root"/`. Lint `fails=0`.

- [x] **Slice 2: compile snapshot; remove `<debrief>` fill**
  <requires: 1>
  - Files:
    - Modify: `skills/workstream/scripts/hooks.sh` — add:

      ```
      hooks.sh compile --file <abs> --handoff <abs> [--root <abs>] --known <slug>=<H2> [...]
      hooks.sh compiled-get --handoff <abs>
      hooks.sh compiled-put --handoff <abs>
      ```

      `--handoff` is Coordinates `this hand-off:` (absolute). `--root`
      is **optional** (spec argv is `--file --handoff --known`; a
      required `--root` would make that line exit 2). When present
      (Coordinates `root checkout:`), rel path for `hooks-compiled:`
      is `--file` with the `--root`/ prefix stripped; if `--file` is
      not under `--root`, write `none`. When absent, derive rel as
      the suffix of `--file` matching `[^/]+/hooks/workstream.md`
      (`.dev/hooks/workstream.md`, `.workspace/hooks/workstream.md`,
      …); else `none`. Verb may pass `--root` when it has the root.

      **Exclusive compiled span** (shared by compile and compiled-put):
      from the line `## Hooks (compiled)` up to **but not including**
      the next structural H2 (`^##[ \t]+\S`) or EOF. `##` inside a
      compiled body does not count (compiled bodies are glue, not
      headings; still: do not put `## ` in a glue body). If the span
      is absent, **insert immediately after the Coordinates block**
      (before `## Delegation route`). Never append a second
      `## Hooks (compiled)`.

      `compile` is deterministic projection (seed.sh-class). It does
      **not** rewrite the bundled skeleton. `parse` first (fail →
      propagate exit 2, write nothing). Then exclusive-replace or
      insert:

      ```markdown
      ## Hooks (compiled)
      hooks-compiled: <rel-or-none> @ <sha256-12-or-none>

      feature-completion:
      <body or (empty)>

      after-eventful-ship:
      <body or (empty)>
      ```

      Hash is the first 12 hex chars of parse’s `hash=` (`none` when
      missing). Unknown H2s are not listed. `--handoff` missing →
      usage, exit 2.

      `compiled-get`: print the exclusive span to stdout (empty if
      absent). Read-only.
      `compiled-put`: read a span from stdin.
      - stdin nonempty and span present → exclusive-replace.
      - stdin nonempty and span absent → insert after Coordinates.
      - stdin empty **and span present** → **no-op** (do not insert,
        do not delete). This is save after a template rewrite: the
        placeholder is already there.
      - stdin empty and span absent → no-op (do not insert).
    - Modify: `skills/workstream/scripts/tests/hooks-test.sh` — add
      red-proofs **2, 7, 9, 10**. Do **not** “run create” or “run save.”
      2. Plant `/backlog debrief` under `Feature completion` only →
         `hook_feature_completion=filled`; compile inlines that body
         under `feature-completion:` in `--handoff`;
         `after-eventful-ship` listed `(empty)`. `--handoff` is a temp
         copy of the bundled hand-off template. After compile,
         `## Delegation route` is still present; exactly one
         `## Hooks (compiled)`.
      7. Stamp-fill deletion: `rg -c 'Seeded from clankshop' skills/workstream/verbs/create.md`
         is 0 after the fill paragraph is deleted. `compile` of an
         **empty** hooks file into a temp hand-off → both slugs
         `(empty)` (no `/backlog debrief` in the compiled span).
         Disable: restore the fill paragraph, confirm the create.md
         count is ≥1, restore. Do not invoke create.
      9. In-place compile target: `compile --handoff
         <tmp-root>/.workstreams/<stream>/WORKSTREAM.md --root
         <tmp-root>`. That path exists and contains the compiled
         span. `<tmp-root>/WORKSTREAM.md` is absent.
      10. Preserve: `compile` a filled snapshot into a temp hand-off;
          `compiled-get` → span file; copy the bundled template over
          the hand-off (simulates save.md 18–21 rewrite); `compiled-put`
          the span. Compiled block byte-identical to pre-rewrite;
          `## Delegation route` present; exactly one
          `## Hooks (compiled)`. Disable `compiled-put`, repeat the
          template copy, confirm the filled body is gone (placeholder
          or missing), restore.
      10b. Empty put: copy the bundled template (placeholder present,
          never compiled) to a temp hand-off; `compiled-put` with empty
          stdin → exactly one `## Hooks (compiled)`; `## Delegation
          route` still present. Same with stdin empty on a file that
          has **no** compiled span → still no compiled heading added.

      Grep gate excludes `scripts/tests/**` so these plants of
      `/backlog debrief` do not fail the gate.
    - Modify: `skills/workstream/templates/workstream-handoff.md`:
      - Add `## Hooks (compiled)` **immediately after Coordinates**
        (before `## Delegation route`) — the insert location compile
        uses when the span is absent:

        ```markdown
        ## Hooks (compiled)
        hooks-compiled: none @ none

        feature-completion:
        (empty)

        after-eventful-ship:
        (empty)
        ```
      - Replace every `<debrief>` **glue-command** token in Loop
        routine / phase map / Pointers (HEAD 84–85, 129–132, 147–178)
        with: “the compiled hook **Feature completion** (skip the glue
        command if empty)” / “**After eventful ship** (skip the glue
        command if empty; only when the ship was eventful)”. Do **not**
        drop the rest of the feature-completion ritual. Delete the
        129–132 fill-probe paragraph.
    - Modify: `skills/workstream/verbs/create.md`:
      - After parse, `compile --file "$HOOKS" --handoff <this hand-off:>
        --root <root>` (optional `--root`; pass it when the verb has
        `<root>`) with the two `--known` pairs. Compile target is
        Coordinates `this hand-off:`, never `<root>/WORKSTREAM.md`.
      - **Delete** the stamp→`<debrief>` fill (today 119–123). Write
        only Coordinates `this hand-off:`.
      - `--seed-only` still makes **no** root commit. Attended create
        that just materialized `$HOOKS` may **propose** a
        pathspec-scoped root commit for that one path. Unattended /
        `--seed-only`: write, do not commit, record `hooks: uncommitted`
        in Pointers.
    - Modify: `skills/workstream/verbs/save.md` **18–21** (the
      regenerate-from-template paragraph):
      1. Path check 10–16 unchanged (must equal `this hand-off:`).
      2. `compiled-get --handoff <this hand-off:>` → span (may be empty).
      3. Regenerate from the bundled template into that same path.
      4. `compiled-put --handoff <this hand-off:>` with the saved span
         (empty stdin + span present = no-op; placeholder stays). Do
         **not** recompile.
      5. Stop saying the regenerate target IS
         `<worktree>/WORKSTREAM.md`. In-place write path is
         `<root>/.workstreams/<stream>/WORKSTREAM.md`;
         `<root>/WORKSTREAM.md` must not appear.
    - Modify: `skills/workstream/verbs/recycle.md` — `$HOOKS` bullets
      from slice 1 stay. After materialize+parse, add
      `compile --file "$HOOKS" --handoff <this hand-off:> --root <root>`
      (`--root` optional; pass it). Blank per-unit sections **before**
      compile so the blank list cannot eat a just-written compiled
      span (the span is already off that list; keep this order).
      Confirm `## Hooks (compiled)` is **not** in the blanked per-unit
      list (TL;DR / Queue state / What’s been done / What’s next).
    - Modify: `skills/workstream/SKILL.md`:
      - *Host layout*: delete “filled `<debrief>` is `/backlog debrief`
        when stamped”. Stamp now governs **exactly one** thing
        (Backlog tracker-line permission, and only when that tracker
        file already exists). Add: at `create`/`recycle`, read `$HOOKS`
        (absolute `<root>/<agent-workspace>/hooks/workstream.md`) when
        present; empty or absent → no extra glue command.
      - Discipline live-hand-off bullet: the live hand-off **is**
        Coordinates `this hand-off:`.
      - Discipline root-contention example: generalize
        `` `/backlog debrief`'s captures `` to “debrief / tracker
        captures from compiled hooks”.
      - Helper scripts already names `hooks.sh` (slice 1); add
        compile / compiled-get / compiled-put.
      - Description still must not name `clankshop` or `backlog`.
    - Modify: `skills/workstream/flow.md` — compiled glue command, not
      `<debrief>` and not `/backlog`. Skip-if-empty is the glue command
      only. Scenario C reads Coordinates `this hand-off:`.
    - Modify: `skills/workstream/verbs/close.md` — optional pre-close
      sweep is “the compiled Feature completion hook if nonempty.”
    - Modify: `skills/workstream/verbs/load.md` — step 2 reads
      Coordinates `this hand-off:`, not a guessed
      `<worktree>/WORKSTREAM.md` (in-place lie at 18–23).
  - Change: Mechanism *workstream consumer* compile + Host layout +
    save preserve via `compiled-get`/`compiled-put`. Stamp no longer
    fills debrief.
  - Verify:
    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
      bash skills/workstream/scripts/tests/run.sh
    ```
    ALL GREEN, including red-proofs 2, 7, 9, 10, 10b.
    Verb greps (fail on 0): `save.md` contains `compiled-get` and
    `compiled-put`; `create.md` and `recycle.md` contain
    `hooks.sh compile`.
    Grep gate (two commands, both under `skills/workstream/` excluding
    `scripts/tests/**` — plants in tests are allowed):
    1. `rg -n '<debrief>'` → empty.
    2. `rg -n 'Seeded from clankshop'` → **exactly one** hit, and that
       hit is the Host-layout tracker-line permission bullet (today
       there are two: create.md:121 and SKILL.md:101; after slice 2
       only SKILL.md remains).
    Lint `fails=0`.

- [x] **Slice 3: clankshop materialize + fill + PACK seam**
  <requires: 2>
  - Files:
    - Create: `skills/clankshop/scripts/hooks-glue.sh` — bash-3.2.
      Face-local. Does **not** invoke
      `skills/workstream/scripts/hooks.sh`. Strip surrounding
      whitespace the **same way** `hooks.sh parse` does (copy the strip
      function; n11 / red-proof 8 dies on `" \n"` otherwise).

      ```
      hooks-glue.sh presence --clankshop-dir <abs>
      hooks-glue.sh fill --file <abs> --skeleton <abs>
      hooks-glue.sh check --file <abs> --presence true|false
      ```

      `presence`: sibling `../workstream/templates/hooks.md` from
      `--clankshop-dir`. Prints `presence=true|false`. Exit 0.

      `fill` (writer): `--file` must be absolute (starts with `/`);
      relative → usage, exit 2 (same reject as `materialize`). If
      `presence` would be false, no-op (do not create `$HOOKS`). Else:
      if `--file` missing and parent directory missing →
      `status=no-parent`, **do not mkdir**, exit 0. If `--file`
      missing and parent exists → copy `--skeleton` there. For each
      of `Feature completion` and `After eventful ship`: if that H2
      **exists** and its body is empty after strip, write a single
      line `/backlog debrief`. Non-empty → leave it. Missing H2 → do
      not add it. Prints `status=filled|skipped|noop|no-parent`.

      `check` (read-only): no write. Unfinished = `presence=true` AND
      (`--file` missing OR a known H2 is present with empty body after
      strip). Missing known H2 is **not** unfinished. Prints
      `finding=true|false` and, when true, `name=/clankshop setup`.
      Tree checksum must be unchanged.

      `setup.md`, `migrate.md`, and `check.md` **name this script by
      path** (`scripts/hooks-glue.sh`, skill-base like `seed.sh`).
      Drop any “or inside the test lib” option.
    - Modify: `skills/clankshop/verbs/setup.md`
      - Insert **step 5 = hooks walk** (`hooks-glue.sh fill`); today’s
        validate/`check` becomes **step 6**.
      - Quote-edit Guard 24–31 as **three** targets:
        1. STOP / already-seeded: extend the green list — unfinished
           hooks (`hooks-glue.sh check` would `finding=true`) means
           **not** seeded.
        2. Resume parenthetical: add unfinished hooks. Empty `$HOOKS`
           with stamp/door/records present must hit **this** arm.
        3. Range: `(1–5)` → **`(1–6)`**.
      - Notes commit pathspec: add `<agent-workspace>/hooks/`.
    - Modify: `skills/clankshop/verbs/migrate.md` — run
      `hooks-glue.sh fill` after the door is written, **before**
      `check`. Retarget Notes “step 5 is green” to check step 6.
    - Modify: `skills/clankshop/verbs/check.md` — after records (today
      step 5), add a hooks finding by running `hooks-glue.sh check`
      (report-only). Names `/clankshop setup` when `finding=true`.
      **Report stays the last step** (becomes step 7; do not keep it
      numbered 6). “Fixes are ordinary routed work, not part of the
      check” stays on Report.
    - Modify: `skills/clankshop/PACK.md` — content-only seam note, **no
      `version:` bump** (same paragraph as before this revise).
    - Modify: `skills/clankshop/scripts/tests/run.sh` — add
      `hooks-fill-test.sh` to the `for t in …` list.
    - Create: `skills/clankshop/scripts/tests/hooks-fill-test.sh` —
      red-proofs **6, 8, 11, 12**. Invoke `hooks-glue.sh` and
      `hooks.sh compile`, not `setup.md` / `create.md`.
      6. (a) Skeleton present, `$HOOKS` absent → `fill` creates the
         file; both bodies are `/backlog debrief`.
         (b) File present with non-empty `Feature completion` → that
         body unchanged; empty sibling still filled.
         (c) Copy **only** the clankshop skill dir into `mktemp` (no
         `../workstream` sibling). `presence=false`; `fill` is noop;
         no file created.
      6d. Whitespace-only body (`" \n"` under `Feature completion`) →
          `fill` treats it as empty and writes `/backlog debrief`
          (n11 / red-proof 8).
      6e. Relative `--file` (`hooks/workstream.md`) → exit 2. Parent
          missing → `status=no-parent`, no mkdir.
      8. Primary path: `fill` (skeleton present) then
         `hooks.sh compile --file "$HOOKS" --handoff <this hand-off:>
         --root <tmp-root>`. Compiled span lists `/backlog debrief`
         for both ids. `--handoff` is
         `<tmp-root>/.workstreams/<stream>/WORKSTREAM.md`, not
         `<tmp-root>/WORKSTREAM.md`.
      11. Already-seeded fixture (doctrine + stamp + door + records +
          sibling skeleton). `seed.sh` still refuses re-seed.
          (a) `$HOOKS` absent → `fill` creates+fills; `check`
          `finding=false`.
          (b) `$HOOKS` present, both known H2s empty → `fill` fills
          bodies, does not recreate structure; `check`
          `finding=false`.
          Guard prose: `setup.md` STOP green-list, resume
          parenthetical, and range `(1–6)` all mention unfinished
          hooks. Disable the resume-parenthetical sentence, confirm
          that grep no longer matches, restore (dead-branch proof for
          the markdown if/else — not “run setup.md”).
      12. (a) Face-only `mktemp` (no workstream sibling) →
          `check --presence false` → `finding=false`; tree checksum
          unchanged.
          (b) Skeleton present, `$HOOKS` empty headings →
          `finding=true` `name=/clankshop setup`; checksum unchanged.
          (c) Skeleton present, file present, `## Feature completion`
          omitted → `finding=false`; checksum unchanged.
  - Change: Mechanism *clankshop glue*. Check stays report-only.
    Presence test shared. Guard three arms, range (1–6), grep-bound.
  - Verify:
    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/skills && \
      bash skills/clankshop/scripts/tests/run.sh && \
      bash skills/workstream/scripts/tests/run.sh
    ```
    Both ALL GREEN. Slice 1–2 tests still green.
    Verb greps (fail on 0): `setup.md`, `migrate.md`, and `check.md`
    each contain `hooks-glue.sh`.

- [x] **Slice 4: doctrine convention** <requires: 2>
  - Files:
    - Modify: `skills/skill-builder/docs/DOCTRINE.md`
      - Add a **Project hooks** section next to doctrine-touching /
        record-writing (fourth landing class, not a front-door
        variable). Hooks are skill-keyed overlay steps →
        `<agent-workspace>/hooks/<skill>.md`, default
        `.dev/hooks/<skill>.md`. Stem matches frontmatter `name:`.
      - Amend **Which home** (today 420–426) from three destinations
        to four; add `hooks/`.
      - Amend rule 3 with the **narrow hooks mkdir**: `mkdir` `hooks/`
        only when `<agent-workspace>` already exists, or when the home
        is the derived default `.dev` and the mkdir is `hooks/` only
        (creates `.dev` as a container for `hooks/`, never
        `doctrine/`). Declared absent home → do not create; treat
        hooks as empty. Leaf is not the workspace assembler.
      - Glue bullet (today 96–100): the retired `foreman` oven is not
        the glue surface. Project hooks files are. Pack/runbook still
        authors *what* the glue says; there is no composer skill to
        invoke.
      - Stamp-consumers sentence (today 384–387): `workstream` no
        longer gates `<debrief>` on the stamp. It still gates Backlog
        tracker-line permission. `debugger` Phase 4 is unchanged.
        **This sentence lands only after slice 2** (slice 4 requires 2
        so it is not a lie).
      - Optional: a `skills/skill-builder/docs/` example of the format,
        never `templates/hooks.md`, never copied to a project.
      - No new `skills-lint.sh` number.
    - Modify: `skills/skill-builder/verbs/new.md` — after the
      record-writer question (orthogonal to tier): ask *does this
      skill have a named-seam loop the pack or a later agent might
      extend?* Yes → a sentence in `SKILL.md` plus known ids on the
      parse line. **No** generic scaffold. **Do not** create
      `templates/hooks.md`. Do not add a lint check that requires the
      file.
    - Modify: `docs/design/2026-08-19-two-roots-simple-spec.md`
      holds-column (line 21) to
      `doctrine/`, `spec/`, `workflow/`, `templates/`, `scripts/`,
      `hooks/`. Content-only layout line; **not** BL-36 unpark.
    - Modify: `skills/skill-builder/docs/BOUNDARY-AUDIT.md` only if a
      one-line pointer is needed (glue lives in hooks files, not in
      leaf descriptions). Skip if the existing independence prose
      already covers “leaves do not name glue authors.”
  - Change: Mechanism *Convention*. May run in parallel with slice 3
    once slice 2 is in.
  - Verify: lint `fails=0`. Doctrine contains
    `<agent-workspace>/hooks/<skill>.md`. Two-roots holds-column lists
    `hooks/`. `new.md` asks the hooks question and does not scaffold
    `templates/hooks.md`. No `foreman` oven in the glue bullet.
    Stamp-consumers sentence no longer says workstream gates
    `<debrief>`.

## Done when

All four slices checked. Spec Verification block green.

- `hooks-glue.sh fill` then `hooks.sh compile` on a fixture: hand-off
  compiled hooks are `/backlog debrief` for both ids, written at
  `this hand-off:`.
- Already-seeded tree: `seed.sh` refuses re-seed; `fill` fills `$HOOKS`;
  `hooks-glue.sh check` is `finding=false`. `migrate.md` names fill
  before check.
- `create.md` stamp-fill site count is 0; compile of an empty hooks
  file stays `(empty)`.
- Second `materialize` leaves planted glue intact (`status=present`).
- Face-only tree (no workstream sibling): no file created, no finding.
- `hooks-glue.sh check` never writes the file (checksum).
- `compiled-put` after a template rewrite preserves `## Hooks (compiled)`.
- In-place compile does not plant `<root>/WORKSTREAM.md`.
- No `<agent-workspace>/templates/hooks.md`. `new.md` does not
  scaffold a generic `hooks.md`.
- Doctrine states the convention; two-roots lists `hooks/`;
  `workstream` is the only implemented consumer.
- Host gate: `bash skills/skill-builder/scripts/skills-lint.sh .`
  `fails=0`. Workstream parser suite green. Clankshop harness green.

Close-the-books: `docs/BACKLOG.md` only if this walk surfaces a new
leftover (remaining `/backlog task` / `issue` mentions in workstream
are already scoped out). Do not invoke `/backlog`. Do not unpark BL-36.

## Coverage (spec → plan)

| Spec requirement | Slice |
|---|---|
| Skeleton + `hooks.sh parse` + materialize-if-absent, refuse overwrite | 1 |
| Absolute `$HOOKS`; recycle names it; no compile yet; `<debrief>` fill still runs | 1 |
| Red-proofs 1, 3, 4, 5 | 1 |
| `compile` into Coordinates `this hand-off:`; delete stamp fill | 2 |
| Save preserves compiled block via `compiled-get`/`put`; in-place path; Host layout one stamp job | 2 |
| Red-proofs 2, 7, 9, 10; grep gate | 2 |
| Setup step 5 / migrate before check / check report-only via `hooks-glue.sh` | 3 |
| Guard three arms, range (1–6); unfinished = missing file OR empty present H2 | 3 |
| Presence test; missing H2 is not a finding; PACK seam, no version bump | 3 |
| Red-proofs 6, 8, 11, 12 (6c/12a on a face-only fixture) | 3 |
| Doctrine Project hooks; four destinations; rule 3 narrow mkdir | 4 |
| Glue bullet; stamp-consumers after slice 2; `new.md` question; two-roots `hooks/` | 4 |

No uncovered Goal / Mechanism / Out-of-scope item is sequenced. Out of
scope stays out (BL-36 layout, `/backlog task`/`issue` in workstream,
generic engine, re-parse on load, other consumers).

## Self-review

- Placeholder scan: none. Script argv, facts, exclusive span, and
  fact-key transliteration are pinned. “Run create/setup/save” is gone.
- Type/name consistency: `$HOOKS`, slugs `feature-completion` /
  `after-eventful-ship`, fact keys `hook_feature_completion` /
  `hook_after_eventful_ship`, H2s `Feature completion` / `After eventful
  ship`, `this hand-off:`, `hooks-compiled:`, `hooks-glue.sh`.
- `--root` on `compile` is **optional**. Spec argv (`--file --handoff
  --known`) still works; when the verb has `<root>` it passes `--root`.

_On completion (before landing), run the host's close-the-books sweep._

## Review history

### 2026-08-21 — needs-rework

Independent review (author did not self-stamp). Three read-only lenses
(soundness skeptic, HEAD groundedness, spec→plan coverage) plus
`ground-check.sh` on this file (`checked=30` `unresolved_count=5` — the
five slice-1 create paths). HEAD citations in Global Constraints still
match live `4bdb07d`. Spec coverage of slices / red-proofs 1–12 / grep
gate / done-when / out-of-scope is complete. The defect is that
**verify would go green while the verb bugs the spec already found
stay in prose.**

Must-fix (do not sequence until these are folded):

1. **Slice 1 is not an end-to-end tracer through create.** Location:
   Slice 1 case 5 (“the same `cp` if-absent the verb will call”) and
   Verify (“`create.md` names `$HOOKS=…`”). `create.md` is agent prose;
   this repo’s harnesses drive scripts (`seed.sh`, `standup.sh`). Case 5
   tests a parallel copy. Resolver, `$HOOKS` assignment, mkdir rule, and
   `parse --file "$HOOKS"` are unexercised. Recycle is not edited and
   restates a *subset* of step 6 (`recycle.md` 42–50) from a worktree
   cwd — inherit is not a transclude (D4). Fix: add
   `hooks.sh materialize --file <abs> --skeleton <abs>` (copy-if-absent,
   refuse overwrite, never cwd-relative). `create.md` and `recycle.md`
   call it with Coordinates `root checkout:` as the root. Red-proof 5
   runs the subcommand with `cwd` ≠ that root. Drop “same `cp`” and
   “new bullets come along.”

2. **Later red-proofs for D3 / G1 / stamp-fill / primary path do not
   bind the verbs.** Location: Slice 2 cases 7, 9, 10 (“fixture create”,
   “or the helper the verb will call”); Slice 3 cases 6, 8, 11, 12
   (“run setup”). Live `setup-journal-test.sh` runs `seed.sh` +
   `standup.sh`, not `setup.md`. Delete “or the helper.” Pin a
   testable surface each verb is required to name:
   - 7: count the stamp-fill site in `create.md` (absent after slice 2);
     compile an empty hooks file → both slugs `(empty)`. Do not “run
     create.”
   - 9: `hooks.sh compile --handoff <root>/.workstreams/<stream>/WORKSTREAM.md`;
     `<root>/WORKSTREAM.md` absent.
   - 10: extract the preserve splice (`hooks.sh preserve --handoff`
     or a listed helper `save.md` must call). Assert exactly one
     `## Hooks (compiled)` and that `## Delegation route` survives.
     Disable the helper, confirm wipe, restore.
   - 6/11/12: a clankshop helper **in `skills/clankshop/scripts/`**
     that `setup.md` / `migrate.md` / `check.md` name by path (drop
     “or inside the new test file’s sourced lib”). Guard 11 is also a
     quoted-prose grep of all three arms + range `(1–6)`, not
     “run setup.md.”

3. **Compile/save splice can eat `## Delegation route` or duplicate
   the compiled block.** Location: Slice 2 compile “replace from that
   heading through the next `## `”; save “capture the section and the
   `hooks-compiled:` line.” Next heading after Coordinates is
   `## Delegation route` (`workstream-handoff.md` 48). Inclusive
   replace deletes it. Stamp line is inside the section — capturing
   both invites a double splice. Template already has the placeholder
   after slice 2, so rewrite-then-append duplicates. Fix: exclusive
   replace from `## Hooks (compiled)` up to **but not including** the
   next structural H2 (`^##[ \t]+\S`) or EOF. If absent, insert
   immediately after the Coordinates block. Save captures that same
   exclusive span once and replaces the placeholder span with it.

4. **Presence tests 6c / 12a never fire in this checkout.** Location:
   Slice 3; presence path `../workstream/templates/hooks.md`. The
   sibling skeleton always exists under `skills/clankshop`. Fix: those
   cases copy the face into `mktemp` **without** `../workstream`.
   Assert the presence path is unresolved, checksum unchanged, no
   setup-named finding.

5. **Fact-key spelling disagrees with red-proof 2.** Location: parse
   prints `hook_<slug>=` with slug `feature-completion` →
   `hook_feature-completion=`; red-proof 2 (and spec 545) expects
   `hook_feature_completion=filled`. Fix: pin one spelling in the
   `hooks.sh` header and in every test (transliterate `-` → `_` in
   fact keys, *or* change the red-proof to the hyphenated form).

Nice-to-have: missing-file `status=missing` red-proof; fenced `##`
ignored; mkdir three arms (declared-absent home); in-place **save**
write path; `load.md` still says `<worktree>/WORKSTREAM.md` at step 2;
`SKILL.md` Helper scripts roster should name `hooks.sh`; clankshop
whitespace-only body (n11 / red-proof 8); `shasum -a 256` vs
`sha256sum` fallback; `hooks-compiled:` needs `--root` or a
repo-relative stamp because `--file` is on the root checkout not the
worktree; slice 1 mkdir vs doctrine rule 3 until slice 4; check.md
Report numbering after inserting a finding; grep gate’s
`scripts/tests/**` exclusion so red-proof plants do not fail the gate.

Confidence: high on 1–4 (live `create.md` / `save.md` / `setup.md` /
`recycle.md` / `setup-journal-test.sh` / hand-off section order). High
on 5 (string mismatch). Medium that `--root` for `hooks-compiled:` is
must-fix vs a verb-side rewrite of the stamp.

Independent reviewers: read-only explore (skeptic, groundedness,
coverage). Author did not fold.

### 2026-08-21 — revise dispositions

| Id | Action | Disposition |
|---|---|---|
| F1 (must-fix 1) | keep | resolved — `hooks.sh materialize --file <abs> --skeleton <abs>`; create.md and recycle.md call it; red-proof 5/5b/5c drive the script from a foreign cwd; dropped “same `cp`” and “new bullets come along” |
| F2 (must-fix 2) | keep | resolved — red-proofs 7/9/10 drive `compile` / `compiled-get`/`put` and a create.md fill-site count; slice 3 drives `hooks-glue.sh`; Guard 11 is a quoted grep of three arms + range `(1–6)`; dropped “or the helper” / “run create/setup/save” |
| F3 (must-fix 3) | keep | resolved — exclusive span up to but not including the next structural H2; insert after Coordinates if absent; save uses compiled-get then compiled-put; red-proof 10 asserts Delegation route + exactly one compiled block |
| F4 (must-fix 4) | keep | resolved — 6c/12a copy the face into `mktemp` without `../workstream` |
| F5 (must-fix 5) | keep | resolved — fact keys transliterate `-` → `_` (`hook_feature_completion=`) |
| n1 missing-file parse | keep-optional taken | resolved — case 1b |
| n2 fenced `##` | keep-optional taken | resolved — case 4b |
| n3 mkdir / no-parent | keep | resolved — materialize `status=no-parent` does not mkdir (5c); create.md still states the three mkdir arms in prose |
| n4 in-place save path | keep-optional taken | resolved — save.md write path is `this hand-off:`; red-proof 9 covers in-place compile; save.md forbids `<root>/WORKSTREAM.md` |
| n5 `load.md` in-place lie | keep-optional taken | resolved — slice 2 modifies `load.md` to read `this hand-off:` |
| n6 Helper scripts roster | keep-optional taken | resolved — slice 1 names `hooks.sh` |
| n7 whitespace-only fill | keep-optional taken | resolved — case 6d |
| n8 `shasum` fallback | keep-optional taken | resolved — `shasum -a 256` else `sha256sum` |
| n9 `--root` for stamp | keep | resolved — `compile --root` optional; absent → suffix `[^/]+/hooks/workstream.md` else `none` (D3) |
| n10 mkdir vs doctrine window | keep-optional taken | resolved — slice 1 names the narrow exception slice 4 will record |
| n11 check.md Report numbering | keep-optional taken | resolved — Report becomes step 7 (last) |
| n12 grep tests exclusion | keep-optional taken | resolved — gate explicitly excludes `scripts/tests/**` |
| n13 save.md 18–21 cite | keep-optional taken | resolved — Global Constraints now cite 18–21 for the wipe |

### 2026-08-21 — needs-rework (delta)

Delta pass on the fold (Review history + Slices 1–3), not a full re-read of the spec. F1–F5 **are in the slice text** (materialize, compiled-get/put, exclusive span, face-only 6c/12a, fact-key `_`). The original hole is **not fully closed**: `run.sh` ALL GREEN still does not prove the *verbs* call those scripts.

Must-fix:

1. **Slice 2/3 Verify must grep the verbs, not only drive the scripts.** Location: Slice 2 Verify (only `run.sh` + `<debrief>` gate); Slice 3 Verify (both `run.sh`). `save.md` can keep HEAD 18–21 (wipe) while red-proof 10 greens on `compiled-put` in isolation. `create.md` / `recycle.md` can omit `hooks.sh compile`. `setup.md` walk can omit `hooks-glue.sh fill` while Guard greps still match. Fix: add these counts to Verify (fail on 0). After slice 2: `save.md` contains `compiled-get` and `compiled-put`; `create.md` and `recycle.md` contain `hooks.sh compile`. After slice 3: `setup.md`, `migrate.md`, and `check.md` contain `hooks-glue.sh`. Also: the `$HOOKS=` assignment’s RHS must include `<root>/` (or `"$root"/`); a line `HOOKS=hooks/workstream.md` next to `materialize --file "$HOOKS"` must fail the grep — do not use a bare `rg hooks/workstream.md` (that hits the legal absolute assignment).

2. **`compiled-put` empty stdin can still duplicate `## Hooks (compiled)`.** Location: Slice 2 `compiled-put` “exclusive-replace or insert-after-Coordinates” vs “If stdin is empty, leave the placeholder.” After save’s template rewrite the placeholder is already there; empty stdin + insert ⇒ two compiled blocks. Red-proof 10 only puts a filled span. Fix: if stdin is empty **and** a span is present, no-op (do not insert). Add a case: `compiled-get` of a never-compiled template hand-off → put that (or empty) stdin → exactly one `## Hooks (compiled)`.

3. **Required `--root` breaks the spec’s pinned compile argv.** Location: Slice 2 compile; spec 337–338 is `compile --file --handoff --known` with no `--root`; plan says missing `--root` → exit 2. Fix: `--root` is **optional**. When present, rel path is `--file` stripped of `--root`/. When absent, derive rel as the suffix of `--file` matching `[^/]+/hooks/workstream.md` (`.dev/hooks/workstream.md`, `.workspace/hooks/workstream.md`, …); else `none`. Spec argv keeps working.

4. **`hooks-glue.sh fill --file` must be absolute** (same reject as `materialize`). Location: Slice 3 fill table vs materialize. Relative `--file` is D4 for a worktree cwd. Fix: relative → usage, exit 2. Parent-missing → no mkdir (align with `no-parent`); copy only when parent exists.

Nice-to-have: create.md mkdir arms remain prose (5c only proves materialize does not mkdir; declared-absent + a rogue `mkdir -p` of the workspace still greens); `load.md` in Files but not in Verify; recycle “re-apply step 6” plus new bullets may double-call materialize (idempotent) — compile-then-blank order must stay compile-after-blank or blank must not eat the compiled span (already off the blanked list).

Confidence: high on 1–3 against the current Verify blocks and spec argv; high on 4 as D4 drift; medium that create.md mkdir-in-prose is still must-fix (dirname of `$HOOKS` is `hooks/`, not `doctrine/`).

Independent delta: read-only explore (fold check + remaining-hole skeptic). Do not sequence until 1–4 are folded.

### 2026-08-21 — revise dispositions (delta)

Human chose fold D1–D4 in place and waive a third independent pass.

| Id | Action | Disposition |
|---|---|---|
| D1 verb greps | keep | resolved — Slice 1/2/3 Verify count `materialize` / `$HOOKS=` RHS `<root>/` / `compiled-get`+`put` / `hooks.sh compile` / `hooks-glue.sh`; no bare `rg hooks/workstream.md` |
| D2 empty compiled-put | keep | resolved — empty stdin + span present = no-op; case 10b |
| D3 `--root` required | keep | resolved — `--root` optional; suffix fallback when absent |
| D4 fill `--file` relative | keep | resolved — fill requires absolute `--file`; parent-missing = `no-parent`, no mkdir |
