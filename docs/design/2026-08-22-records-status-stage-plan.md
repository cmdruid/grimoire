---
doctype: plans
status: open
created: 2026-08-22
updated: 2026-08-22
tags: [plan]
---

# Records `status` / `stage` — Implementation Plan

Tracer: register the portable front-matter contract at
`skills/skill-builder/specs/` (the newest path, and the document journal
and writers must honor), then walk that contract through `records.sh`
end to end (two predicates, live-set `list`, migrate-then-check), then
widen every live writer copy the verify `rg` hits. Each slice is
independently testable and committable.

Spec: `docs/design/2026-08-21-records-status-stage.md`
(`status: open`; latest stamp **approve**, 2026-08-22; F1–F5 and N1–N4
folded). The spec’s Slices / Mechanism / Verification blocks are the
coverage map; this file sequences them against live HEAD.

Grounded 2026-08-22 against worktree `HEAD` `762c040`.
`ground-check.sh` on the spec: `checked=18` `unresolved_count=3` —

- `skills/skill-builder/specs/README.md` (slice 1 create)
- `skills/skill-builder/specs/records-front-matter.md` (slice 1 create)
- `docs/DOCTRINE.md` — Review-history quotes of the pre-N1/N4 path;
  live Mechanism already cites `skills/skill-builder/docs/DOCTRINE.md`

No other drift. Prior art: **no** `skills/skill-builder/specs/` directory.
`records.sh` still has one `is_closing` (line 62) serving both file
status and `--as` disposition. `cmd_list` filters only when `--status`
is set (line 147: `s != "" && $3 != s`). No `--stage` anywhere. Mint
default status is whatever the template plants (`status: open`), not a
tool default.

Do **not** size from the spec’s cited line numbers without re-reading
— they are snapshots (F1 named 62 / 340 / 351 / 476–488; all four still
resolve and still mean what the spec says).

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Patient-zero.** This plan lives in `docs/design/`. Do not mint
  `.records/`. Do not add door blocks to this library’s `AGENTS.md`.
  Tests use `mktemp` fixtures only.
- **Stay on `main`.** Do not `/workstream load skills`. Sibling streams
  exist; do not drive them. Do not start
  `docs/design/2026-08-21-architect-contractor-inspector.md`.
- **Two predicates, never one.** File closed ⇔ `status: archived`.
  Disposition ⇔ `done|dropped|superseded|consumed` (ledger `--as` only).
  Do not rename `is_closing` to cover both; split it. `done` stamps the
  **file** `archived` and appends `--as` to the ledger.
  `check` requires an archived file to have *a* ledger line; it does
  **not** require `$disp == $status`.
- **Journal knows no doctype.** `--type` matches the front-matter
  `doctype:` string (open set). Slice 3 is “what the verify `rg` hits
  under `skills/`,” not a store taxonomy. No `stage` values are
  introduced.
- **`list` TSV width stays six** (path, doctype, status, updated, tags,
  title). `--stage` filters internally; agents that need the value read
  the file.
- **Doctrine does not restate the enum.** Rule 5 *points* at the
  registered spec. Writer `SKILL.md` in-package contracts restate
  `draft` | `published` live; `archived` closed.
- **Uniqueness is a writer rule** where a skill already has one
  (blueprint / contractor “one living artifact per subject”). Map
  `current` → `published`; do not delete that writer convention, and do
  not add it to journal.
- **Mint `--status <disposition>` still means close.**
  `record-mint.sh` / `note-mint.sh` / `bug-mint.sh` today route
  `--status done|dropped|superseded|consumed` to
  `records.sh done --as <word>`. Keep that routing via
  `is_disposition`. File-mode stamp of those words writes `archived`,
  not the disposition word. Delete the name `is_closing` so the verify
  `rg` is clean (mint scripts land in slice 2 with the journal tool).
- **Gate.** `bash skills/skill-builder/scripts/skills-lint.sh .` →
  `fails=0` after each slice. Slice 2 also
  `bash skills/journal/scripts/tests/run.sh` and
  `bash skills/{notepad,debugger,backlog}/scripts/tests/run.sh`.
  Slice 3 also the remaining writer tests it reddens (analyst,
  classify). Red-proofs must fail when their check is disabled
  (count the plant before/after; restore byte-identity).
- **HEAD line numbers (re-read before editing; they drift):**
  - `skills/journal/scripts/records.sh` 62 `is_closing`; 63 `is_status`;
    12 / 42 `touch --status open|current`; 132–154 `cmd_list`;
    156–194 `cmd_grep`; 321–322 touch refuse; 340 / 343 / 351 `cmd_done`;
    405 prune; 438–439 / 476–490 `cmd_check`.
  - `skills/journal/scripts/standup.sh` **56–73** copy (or skip);
    **111–114** `check` only (no migrate).
  - `skills/skill-builder/docs/DOCTRINE.md` 350–355 rule 5 enum;
    363–367 rule 7 reopen `open`.
- **Do not push.** Do not mix this work with the untracked inspector
  spec.

## Slices

- [ ] **Slice 1: register the contract** <requires: —>

  The tracer. New registry + doctrine points at it; `new` scaffolds the
  new vocabulary; lint green. No `records.sh` edits.

  - Files:
    - create `skills/skill-builder/specs/README.md`
    - create `skills/skill-builder/specs/records-front-matter.md`
    - modify `skills/skill-builder/SKILL.md`
    - modify `skills/skill-builder/docs/DOCTRINE.md`
    - modify `skills/skill-builder/verbs/new.md`
    - modify `skills/skill-builder/verbs/calibrate.md`
  - Change:

    1. **`specs/README.md`** — exact bytes:

       ```markdown
       # skill-builder specs

       Portable format/authoring contracts that every skills library
       installing `skill-builder` must honor. `check`, `new`, and
       writer rule 5 read these. Doctrine
       (`docs/DOCTRINE.md`) stays philosophy and points here; it does
       not restate enums that can drift.

       ## Belongs

       Format/authoring contracts (records front-matter; later contracts
       of the same class).

       ## Does not belong

       A host library’s feature specs. Pack-format
       (`docs/spec/pack-format.md` at the host library root — this
       change does not move it). Doctrine essays
       (`docs/DOCTRINE.md`). Project-deployed kind templates.

       ## Index

       | spec | what |
       |---|---|
       | `records-front-matter.md` | Record `status` / `stage`, filters, in-package contract |
       ```

       Relative links in this file are from `skills/skill-builder/`
       (`docs/DOCTRINE.md`, not the long repo path).

    2. **`specs/records-front-matter.md`** — Mechanism only (status /
       stage / filters / in-package contract). Copy those four
       subsections from the governing spec *verbatim in substance*:
       three-value `status` table (`draft` ← `open`, `published` ←
       `current`, `archived` ← the four close words); two predicates;
       `touch --status` accepts only `draft` | `published` and refuses
       `archived`; `done` stamps the file `archived` and appends `--as`;
       `check` requires a ledger line for `archived`, not
       `$disp == $status`; file-mode close rewrites `status: archived`
       and `updated:` only; optional `stage` (presence ⇒ non-empty after
       trim; journal does not enum-check); filter table (three rows:
       `list` default live set, `grep` whole corpus, `history`
       unchanged) with the live-set note **under** the table, not inside
       it; `--type` is an open `doctype:` string; `--status` /
       `--stage` repeatable → OR; unknown `--stage` is not an error;
       TSV width unchanged; writer in-package contract restates
       `draft` | `published` live, `archived` closed, optional `stage`.
       Do **not** copy Problem, Approach, Registry, Migration, Out of
       scope, Slices, or Review history.

    3. **`SKILL.md` *What this skill bundles*.** After the
       `docs/DOCTRINE.md` bullet, add:

       `- **`specs/`** — portable format/authoring contracts the
       lint gate, `new`, and writer rule 5 honor. Indexed by
       `specs/README.md`. The records contract is
       `specs/records-front-matter.md`.`

    4. **`docs/DOCTRINE.md` rule 5.** Replace the parenthetical enum
       with a pointer. Exact replacement for the status-vocabulary
       clause (lines 350–355):

       > 5. **In-package contract.** The writer states the five keys
       > (`doctype`, `status`, `created`, `updated`, `tags`), the
       > status / stage vocabulary **as registered in
       > `specs/records-front-matter.md`** (do not restate the enum
       > here — that file is the contract), the dated slug
       > (`YYYY-MM-DD-<slug>.md`), and the record-link form
       > (`→ <store>/<file>.md`) in *its own* package. It does not
       > send the agent to another skill's `SKILL.md` for those bytes.
       > Pack composition (the face / runbook) still names journal as
       > the format authority; leaves do not.

       Rule 7 (lines 365–366): `rewrite status: back to \`open\`` →
       `rewrite status: back to \`draft\``. “already-closing status” →
       “already-archived status”.

       References: add
       `- \`specs/records-front-matter.md\` — record status / stage
       contract (writer rule 5).`

    5. **`verbs/new.md` step 3 (record-writer yes).** Expand the
       in-package-contract bullet so a scaffolded skill states:
       five keys; `status`: `draft` | `published` live, `archived`
       closed; optional `stage` (non-empty if present; values declared
       here if this skill uses the key); dated slug; record-link form;
       file-mode close → `archived`, not a ledger disposition word.
       Point at `specs/records-front-matter.md` (relative to the
       skill root — `skills/skill-builder/`). Do not scaffold a
       `stage` key onto templates.

    6. **`verbs/calibrate.md`.** After step 3 (“Draft the fold”), one
       sentence: `calibrate` may add a file under `specs/`; it does
       not fold enum tables back into `docs/DOCTRINE.md`.

  - Verify:
    - `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0`
    - `rg "open \\| current live" skills/skill-builder/docs/DOCTRINE.md`
      — no hits
    - `rg "specs/records-front-matter.md" skills/skill-builder/docs/DOCTRINE.md skills/skill-builder/SKILL.md skills/skill-builder/verbs/new.md`
      — all three point at it
    - `new.md` names `draft` / `archived` / optional `stage`

- [ ] **Slice 2: journal tool** <requires: 1>

  Walk the registered contract through `records.sh`, standup, and the
  journal verbs — and every file that `check` then reddens (templates
  that mint `open`, mint scripts that stamp close-words onto `status:`,
  mint tests that copy `JOURNAL_RS`). Tests drive the script; they do
  not “run” agent verbs.

  - Files:
    - modify `skills/journal/scripts/records.sh`
    - modify `skills/journal/scripts/tests/records-test.sh`
    - modify `skills/journal/scripts/standup.sh`
    - modify `skills/journal/scripts/tests/standup-test.sh`
    - modify `skills/journal/SKILL.md`
    - modify `skills/journal/verbs/done.md`
    - modify `skills/journal/verbs/curate.md`
    - modify `skills/journal/verbs/setup.md`
    - modify `skills/journal/verbs/search.md`
    - journal has **no** bundled record templates (HEAD: none under
      `skills/journal/templates/`)
    - modify `skills/blueprint/templates/{adr,spec,founding}.md`
    - modify `skills/auditor/templates/reports.md`
    - modify `skills/debugger/templates/{bugs,reports}.md`
    - modify `skills/notepad/templates/notes.md`
    - modify `skills/contractor/templates/{plan,plans,roadmap}.md`
    - modify `skills/analyst/templates/reports.md`
    - modify `skills/workstream/templates/{reports,plans}.md`
    - modify `skills/backlog/templates/trackers.md` (front-matter
      line only; body `open` is slice 3)
    - modify `skills/backlog/scripts/record-mint.sh`
    - modify `skills/notepad/scripts/note-mint.sh`
    - modify `skills/debugger/scripts/bug-mint.sh`
    - modify `skills/notepad/scripts/tests/note-mint-test.sh`
    - modify `skills/debugger/scripts/tests/bug-mint-test.sh`
    - modify `skills/backlog/scripts/tests/record-mint-test.sh`
  - Change:

    1. **Predicates (replace lines 62–63).** Delete `is_closing`.
       Exact bytes:

       ```sh
       is_disposition() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }
       is_archived()    { [ "$1" = archived ]; }
       is_status()      { case "$1" in draft|published|archived) return 0 ;; *) return 1 ;; esac; }
       ```

    2. **Header / `usage()`.** `touch` line:
       `[--status draft|published]`. `list` / `grep` lines add
       `[--stage s]`. Add a `migrate-status` usage row. Comment at
       the top: closure stamps the file `archived` and appends `--as`
       to the ledger; `list` default is the live set
       (`draft` ∪ `published`).

    3. **Repeatable `--status` / `--stage` + live-set `list`.**
       Replace HEAD last-wins `f_status="$2"` in **both** `cmd_list`
       and `cmd_grep`. In `cmd_grep`, add `--stage` **before** the
       `--*) usage` / pattern arm (`records.sh:165`). Init
       `f_status=""` , `f_stage=""` (newline-separated), and
       `f_stage_given=0`. Exact cases:

       ```sh
       --status)
         [ $# -ge 2 ] || usage
         is_status "$2" || err "unknown status: $2"
         f_status="${f_status:+$f_status }$2"
         shift 2 ;;
       --stage)
         [ $# -ge 2 ] || usage
         f_stage_given=1
         nl="$(printf '\n')"
         f_stage="${f_stage:+$f_stage$nl}$2"
         shift 2 ;;
       ```

       Shared row filter after `meta_row` (replace the duplicated awk
       at `cmd_list:145–152` and `cmd_grep:185–192`; do not wrap it):

       ```sh
       # live=1 → default hide archived; live=0 → no default status filter.
       filter_rows() {
         live="$1"
         awk -F'\t' -v t="$f_type" -v s="$f_status" -v g="$f_tag" \
             -v a="$f_since" -v z="$f_until" -v live="$live" '
           function in_set(val, set,   n, arr, i) {
             if (set == "") return 0
             n = split(set, arr, " ")
             for (i = 1; i <= n; i++) if (arr[i] == val) return 1
             return 0
           }
           t != "" && $2 != t { next }
           live && s == "" && $3 != "draft" && $3 != "published" { next }
           s != "" && !in_set($3, s) { next }
           g != "" && index("," $5 ",", "," g ",") == 0 { next }
           a != "" && $4 < a { next }
           z != "" && $4 > z { next }
           { print }
         '
       }

       stage_ok() {  # rel; f_stage is newline-separated wanted values
         [ "$f_stage_given" -eq 0 ] && return 0
         val="$(fm_field "$RR/$1" stage)"
         val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
         [ -n "$val" ] || return 1
         printf '%s\n' "$f_stage" | grep -qxF -- "$val"
       }
       ```

       `cmd_list`:
       `records | while IFS= read -r r; do stage_ok "$r" || continue;
       meta_row "$r"; done | filter_rows 1 | sort …`
       `cmd_grep`: **keep** the body-pattern walk (`:174–181`); then
       `stage_ok` + `meta_row` + `filter_rows 0`. Do not copy the
       list pipeline onto grep. TSV still six columns — do not add
       `stage` to `meta_row`. Never `exit` from `stage_ok`.

    4. **`cmd_touch` (321–322).** Keep `is_status` unknown-status
       refuse. Replace `is_closing "$new_status"` with
       `is_archived "$new_status"` and the same “closing status goes
       through 'done'” message. `touch --status done` is now
       `unknown status` (not in the three). Reopen is
       `touch --status draft` on an archived file (do **not** refuse
       touching an archived file *to* `draft` / `published`).

    5. **`cmd_done`.** Line 340: `is_disposition "$disposition"`.
       Line 343: `is_archived "$status" && err "already closed ($status)"`.
       Line 351: `stamp "$abs" "$today" "archived"` — **not**
       `$disposition`. Ledger line still uses `$disposition`.

    6. **`cmd_prune_candidates` line 405.**
       `is_archived "$(fm_field … status)" || continue`.

    7. **`cmd_check`.** Awk enum (438–439):
       `fm["status"] !~ /^(draft|published|archived)$/`.
       In the same awk `infm` block, parse `stage:`: if the key is
       present, trim value; empty → `print "stage is empty"`. Missing
       key: no finding. Unknown non-empty stage string: no finding.
       Replace the coherence arm (476–490) with:

       ```sh
       status="$(fm_field "$RR/$rel" status)"
       if is_archived "$status"; then
         disp=""
         if [ -f "$LEDGER" ]; then
           disp="$(awk -F'\t' -v p="$rel" '$3 == p { print $2; exit }' "$LEDGER")"
         fi
         if [ -z "$disp" ]; then
           echo "FAIL: $rel — archived but no history.tsv ledger line" >&2
           fails=$((fails + 1))
         fi
         # deliberately no: elif [ "$disp" != "$status" ]
       fi
       ```

       Ledger well-formedness (four disposition words) is unchanged.

    8. **`cmd_migrate_status` (new).** Crawl `records`. Rewrite the
       `status:` line only (do **not** bump `updated:`; do **not**
       touch `history.tsv`). **Do not call `stamp()`** — it always
       rewrites `updated:`. Copy `stamp`’s `infm` guard, omit the
       `updated:` arm:

       ```sh
       migrate_status_line() {  # abs
         tmp="$1.tmp"
         awk '
           BEGIN { infm = 0; fmdone = 0 }
           NR == 1 && $0 == "---" { infm = 1; print; next }
           infm && !fmdone && $0 == "---" { fmdone = 1; infm = 0; print; next }
           infm && /^status:/ {
             v = $0; sub(/^status:[ \t]*/, "", v)
             if      (v == "open")                              v = "draft"
             else if (v == "current")                           v = "published"
             else if (v ~ /^(done|dropped|superseded|consumed)$/) v = "archived"
             print "status: " v; next
           }
           { print }
         ' "$1" > "$tmp" && mv "$tmp" "$1"
       }
       ```

       Count `migrated=` as files whose `status:` **actually changed**
       (compare before/after). Idempotent: already
       `draft`/`published`/`archived` is a no-op. Unknown values
       left (check will fail). Dispatch next to `list`/`grep`/… in
       the command `case` (before `*)`).

    9. **`standup.sh`.** After the script is current-or-refreshed
       (after the `cmp`/`cp` block, and also on first visit), **before**
       `check`: `"$rr/scripts/records.sh" migrate-status`. Always, even
       when the script was already byte-identical. Then `check`. A
       failing check still exits 0 (tool layer is up; curate). Do not
       invent ledger lines.

    10. **Journal prose.**
        - `SKILL.md` *Status vocabulary*: `draft` | `published` while
          live; `archived` to close. A closing status is `archived` and
          **requires a** `history.tsv` ledger line (disposition is the
          ledger `--as` word, not the file status). Drop the
          “matching disposition” sentence.
        - `verbs/done.md` step 2: “leave it draft, or `touch --status
          draft|published`”. Step 3: script stamps `status: archived`
          and appends the ledger line; never hand-edit a status to
          `archived`.
        - `verbs/curate.md` step 2: unfiltered `list` is the live set
          (archived rows: `list --status archived`).
          `prune-candidates` still walks the ledger, not `list`.
        - `verbs/setup.md` later-visit paragraph: refresh copies
          `records.sh`, **migrates statuses**, then `check`. Qualify
          “Converting legacy record *content*” so it still excludes
          adopting foreign docs, but status-vocab rewrite is this verb.
        - `verbs/search.md` step 4: add `--stage` to the filter list;
          one line that `list` without `--status` hides `archived`,
          `grep` without `--status` does not.

    11. **`records-test.sh` — rewrite every planted `status: open` /
        `current` / `done` and the assertions they drive.** Concrete
        HEAD edits (re-read the file; line numbers drift):

        - Templates and plants: `status: open` → `status: draft`
          (lines 33, 39, 49, 206, 279, 287, 323, 414).
        - List TSV (69): third field `draft` not `open`.
        - `touch --status current` (80–81) → `--status published` /
          `status: published`.
        - `done --as consumed` (85–87): ledger still `consumed`;
          **file** `status: archived` (not `consumed`).
        - Double-done (103): `already closed (archived)`.
        - Closing via touch (105–107): `--status archived` still
          routes to done. Add: `touch --status done` →
          `unknown status: done`.
        - Reopen (227): `touch --status draft` (not `open`).
        - Closed-without-ledger (148–151): plant `status: archived`;
          message `archived but no history.tsv ledger line`.
        - **Invert the disposition-mismatch plant (374–381).** Today
          it expects FAIL on file `done` + ledger `dropped`. After
          this spec that pair is illegal file status; the legal pair
          is file `archived` + ledger `dropped` and must **PASS**.
          Replace with: plant `status: archived` + ledger `consumed`
          → check green (the two-predicates proof). Keep a separate
          archived-without-ledger fail (already above).
        - **New cases** (add after the lifecycle round-trip, before
          “proven by breaking”):
          - unfiltered `list` after `done` hides the archived row;
            `list --status archived` shows it;
            `list --status draft --status published` OR-union;
            `grep <archived-body-token>` without flags still hits it.
          - `--stage`: plant `stage: approved` on one live record;
            `list --stage approved` keeps it; `list --stage no-such`
            is empty and rc 0; `list --stage approved --stage other`
            OR (two live records with different stages — last-wins
            cannot pass); `list --stage ""` is empty rc 0 (flag
            present, empty want matches nothing); `grep <body-token>
            --stage approved` keeps the body hit. Plant `stage: totally-unknown` on a live
            record in the main fixture → `check` green. Empty
            `stage:`: **throwaway fixture** (or plant / assert /
            `rm` like sneaky) — `check` fails `stage is empty`; do
            not leave it in the shared fixture.
          - `migrate-status`: in a fresh fixture, plant one `open`
            with `updated: 2020-01-01`, one `current`, one
            `consumed` (file) with a matching ledger line whose
            disposition is `consumed`; run `migrate-status`; expect
            `draft` / `published` / `archived`; **`updated:
            2020-01-01` still**; ledger line still `consumed`;
            `migrated=` equals 3; second `migrate-status` prints
            `migrated=0`.
          - Red-proof the new `check` enum: copy the deployed script,
            plant `status: open` on a dated record, demand check red
            (`status not in the contract: open`), restore. Count the
            plant before/after.
          - Red-proof live-set `list`: after `done`, assert the
            archived path is absent from unfiltered `list`; then
            temporarily comment out the live-default awk arm on a
            copy and assert the archived path reappears.
          - Red-proof no `$disp == $status`: copy the script, restore
            `elif [ "$disp" != "$status" ]`, show the
            archived+consumed plant goes red; restore byte-identity.

    12. **`standup-test.sh`.** Add: a later-visit fixture with an
        existing `status: open` record and a drifted `records.sh`.
        After standup: file is `draft`, check is green (`OK`), stdout
        still reports `refreshed`. This is spec F3: migrate then
        check, not copy-then-reject. Also: later visit, **already-
        current** script, planted `open` → `draft` (migrate is not
        only in the refresh `else`). First-visit empty root stays
        `OK (0 records)`.

    13. **Templates + mint scripts + mint tests** (every file slice 2
        `check` reddens). Front-matter `status: open` →
        `status: draft` on:
        `skills/blueprint/templates/{adr,spec,founding}.md`
        `skills/auditor/templates/reports.md`
        `skills/debugger/templates/{bugs,reports}.md`
        `skills/notepad/templates/notes.md`
        `skills/contractor/templates/{plan,plans,roadmap}.md`
        `skills/analyst/templates/reports.md`
        `skills/workstream/templates/{reports,plans}.md`
        `skills/backlog/templates/trackers.md`
        (front-matter line only.)

        In each of `record-mint.sh` / `note-mint.sh` / `bug-mint.sh`:
        replace `is_closing` with `is_disposition` (same four words).
        Records.sh branch: `is_disposition "$status"` then
        `records.sh done --as "$status"`. File-mode / out-of-root:
        if `is_disposition "$status"`,
        `file_stamp "$path" "$(date +%Y-%m-%d)" "archived"`; else
        `file_stamp "$path" "$(date +%Y-%m-%d)" "$status"`. Keep
        HEAD’s date command, not an unbound `$today`.

        Mint tests:
        - `note-mint-test.sh:60` `status: open` → `draft`;
          `:91` and `:131` `^status: superseded$` →
          `^status: archived$`; records-mode also ledger `--as
          superseded`; file-mode still no `history.tsv`.
        - `bug-mint-test.sh:60` → `draft`; `:86` and `:115` →
          `archived`; records-mode ledger `--as done`.
        - `record-mint-test.sh:60,102,140` → `draft`; `:95` and
          `:133` → `archived`.

  - Verify:
    - `bash skills/journal/scripts/tests/run.sh` green, including
      two predicates, `done --as consumed` (file archived / ledger
      consumed), live-set `list`, migrate-then-check, empty `stage:`
      fails `check`, unknown `stage` does not, `touch --status
      archived` refuses, grep without flags hits an archived body,
      `list --stage a --stage b` OR, `grep --stage`.
    - `bash skills/notepad/scripts/tests/run.sh`
    - `bash skills/debugger/scripts/tests/run.sh`
    - `bash skills/backlog/scripts/tests/run.sh`
    - `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0`

- [ ] **Slice 3: writer restatement** <requires: 2>

  Remaining live contract copies under `skills/` after slice 2:
  in-package paragraphs, verb flags, analyst facts, classify
  fixtures, template *body* copy. Historical `docs/design/` is
  exempt. No `stage` values. Templates, mint scripts, and mint tests
  already landed in slice 2.

  Re-run the verify `rg` at the start of this slice — mint/templates
  should already be clean.

  - Files and exact edits:

    **Template body copy** (front-matter already `draft` from slice 2):
    - `skills/blueprint/templates/spec.md` line 13:
      `` `status: current` `` → `` `status: published` ``
    - `skills/contractor/templates/roadmap.md` line 13: same.
    - `skills/backlog/templates/trackers.md` line 19: “stays `open`”
      → “stays `draft`”.

    **Notepad live listing:**
    - `skills/notepad/verbs/write.md:9–13`: if `records.sh` is
      executable, `records.sh list --type notes` (no `--status`;
      live-set default). File-mode: skip `archived`, and still skip
      `done|dropped|superseded|consumed` for unmigrated trees.
    - `skills/notepad/verbs/find.md:3–11`: default live =
      `draft` ∪ `published`; same list invocation (or requested
      status). File-mode filter on `status:` using those values plus
      `archived` as closed.

    **`revise.md`:**
    - `skills/blueprint/verbs/revise.md:6,214` and
      `skills/contractor/verbs/revise.md:6,199`:
      “Do not promote/flip `status:` to `current`” →
      “to `published`”.

    **In-package contract paragraphs (new vocabulary, optional
    `stage` sentence only where the skill already restated status;
    still no `stage` values):**
    - `skills/notepad/SKILL.md` 57–59: Live `draft`, `published`.
      Closed `archived` (ledger `--as` is `done` / `dropped` /
      `superseded` / `consumed` when the tool exists). File-mode
      close writes `archived`.
    - `skills/backlog/SKILL.md` 49–50: same. Line 60 “live vs
      closing `status:`” → live vs `archived`.
    - `skills/analyst/SKILL.md` 109–112: same three-value
      restatement. Keep “never invent a sixth” (analyst does not
      use `stage`; extra keys stay legal, this package still does
      not mint them).
    - `skills/blueprint/SKILL.md`: every `status: open` →
      `status: draft`; every `status: current` →
      `status: published`; Status vocabulary block (65–70) restates
      the three + “one `published` spec per subject” (writer rule,
      keep); `touch --status current` (55, 252–253) →
      `--status published`. Founding-shaped files stay `draft`.
    - `skills/contractor/SKILL.md` 47–50 and 75: `open`/`current` →
      `draft`/`published`; closure through `records.sh done`.
    - `skills/contractor/verbs/roadmap.md` 33:
      `status: published`.
    - `skills/contractor/verbs/review.md` 38:
      `status: published` spec.
    - `skills/blueprint/docs/ideal-use.md` 18 and 32:
      `status: draft` / `--status published`.
    - `skills/clankshop/verbs/migrate.md` 53:
      living spec `status: published`. Lines 88–89: backfill only
      non-closing statuses (`draft`, or `published` for a living
      spec).
    - `skills/clankshop/seed/design/POLICY.md` 18 and 31:
      `status: published`; “exactly one `published` spec” stays a
      station policy (writer/station rule, not journal).

    **Analyst facts (live-set semantics, not a second enum owner):**
    - `skills/analyst/scripts/analyst-facts.sh`
      `cmd_status` (185–201): `case draft` / `published`; **keep
      fact keys** `open_records=` / `current_records=` (output
      contract). Print `$st` in the listing, not a literal `open`.
      Usage line 55: “draft records, trackers, streams now”.
      `cmd_health` (240, 245): match `draft`; keep keys `open_bugs`
      / `stale_open_records`.
    - `skills/analyst/scripts/tests/facts-test.sh`: every planted
      `status: open` → `draft`; `status: current` → `published`;
      `mk_record plans … "done"` (43–45) → `"archived"`; BREAK sed
      `status: open`/`done` → `draft`/`archived`. Assert
      `open_records=` / `current_records=` (same key names).
      Shared-home plants too (126).
    - `skills/analyst/templates/briefing.md:22` and
      `diagnostics.md:19`: records still `` `open` `` → `` `draft` ``.

    **Council classify fixtures** (classification keys on doctype /
    tags, not status — still rewrite so the `rg` is clean):
    `skills/agent-council/scripts/tests/classify-brief-test.sh`
    47 / 65 `status: open` → `draft`; 85 `status: current` →
    `published`. Re-run that test script.

  - Verify:
    - `rg "status: open|status: current|is_closing.*done\\|dropped|--status open|--status current" skills/`
      — no live contract copies. (`docs/design/` is outside
      `skills/` and is exempt.)
    - Also clean (the spec’s `rg` misses these):
      `rg "Live statuses:|open \\\\| current live" skills/`
    - `bash skills/analyst/scripts/tests/run.sh`
    - `bash skills/agent-council/scripts/tests/run.sh`
    - `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0`

## Done when

- Portable contract lives at
  `skills/skill-builder/specs/records-front-matter.md`; doctrine rule 5
  points at it and does not restate the six-value enum.
- `records.sh`: mint default `draft` (via templates); `touch --status
  published`; `done --as consumed` → file `archived` + ledger
  `consumed`; `touch --status archived` refuses; `list` hides
  archived; `list --status archived` shows them; `grep` without flags
  still hits an archived body; `--stage` filters; empty `stage:` fails
  `check`; unknown `stage` does not; old six fail `check` after
  migrate; archived-without-ledger fails `check`; archived+ledger
  `consumed` passes.
- Setup refresh migrates, then `check`.
- Writer copies under `skills/` teach `draft` / `published` /
  `archived`. No `is_closing` four-word file-status copies.
- Lint `fails=0`. Journal and reddened writer tests green.

_On completion (before landing), run the host's close-the-books sweep._

## Spec → plan coverage

| Spec requirement | Slice |
|---|---|
| `skill-builder/specs/` registry + README rule + Mechanism-only contract | 1 |
| Doctrine rule 5 points; no restated six; `new` scaffolds new vocab; `calibrate` may add a spec | 1 |
| Two predicates; `done` stamps `archived`; `check` ledger-line not equality | 2 |
| `touch` refuses `archived`; reopen `draft` | 2 |
| `list` live-set default; `grep` whole corpus; `--status`/`--stage` repeatable; TSV width 6 | 2 |
| Empty `stage:` fails `check`; unknown `stage` does not; `--type` open set | 2 |
| Setup refresh: migrate then `check`; no invented ledger lines | 2 |
| Writer templates + mint scripts + mint tests (files `check` reddens) | 2 |
| Writer SKILL.md contracts, verb flags, analyst, remaining fixtures | 3 |
| Mechanical Verification block (records-test + doctrine `rg` + lint) | 2 + 1 + each slice |
| Judgment Verification (citable `list --status published`; writer `stage` without journal change; ledger answers *why*) | 2 (filters + ledger) + 3 (no `stage` values added) |
| Out of scope (architect/inspector, kind templates, pack-format move, TSV 7th column, uniqueness in journal, review stamps) | none — do not implement |

## Review history

### 2026-08-22 — needs-rework

Must-fix:

- **F1** Slice 2 Change 3 — `stage_ok` / flag parse / `grep`. The
  pasted `stage_ok` pipes into `while` and `exit 0`s. `records.sh` is
  `#!/bin/sh` without `pipefail`; that `exit` only ends the subshell,
  then `return 1` always runs, so `--stage` matches nothing. `exit 0`
  without a subshell would kill the whole script. The “exact bytes”
  also omit the `cmd_list` / `cmd_grep` parse loops: HEAD last-wins
  `f_status="$2"` (`records.sh:137`, `:161`); `cmd_grep`’s `--*)
  usage` (`:165`) rejects `--stage` until an arm is added *before*
  that glob. Copying the `cmd_list` pipeline onto `grep` would drop
  the body-pattern filter. **Fix:** here-doc (or non-pipe) loop with
  `return 0` on match; paste `--status` (append + `is_status`) and
  `--stage` (append, never error) into both parsers; keep `grep`’s
  pattern walk; add `list --stage a --stage b` OR so last-wins cannot
  pass.
  - resolved — `stage_ok` via `grep -qxF` (no pipe-`while`, no `exit`);
    `--status`/`--stage` parse loops in both `cmd_list` and `cmd_grep`;
    grep keeps the body-pattern walk; `list --stage a --stage b` OR
    and `grep --stage` tests.

- **F2** Slice 3 path list / verify `rg` — notepad live listing.
  `skills/notepad/verbs/write.md:9–13` and `find.md:3–11` call
  `list --type notes --status open` / `--status current` (unknown
  after slice 2) and file-mode skip only the four close words
  (`archived` looks live). Neither `status: open` nor `Live
  statuses:` matches those lines. **Fix:** add both files. Tool
  path: unfiltered `list --type notes` (live-set default) or
  `--status draft` / `--status published`. File-mode skip
  `archived`. Widen the verify `rg` with `--status open|--status
  current`.
  - resolved — `write.md` / `find.md` added to slice 3; live-set
    `list --type notes`; file-mode skip `archived`; verify `rg`
    includes `--status open|--status current`.

- **F3** Slice 3 mint tests — close expects unnamed. Plan rewrites
  mint-default `status: open` only. Live asserts that contradict
  file-mode `archived`:
  `note-mint-test.sh:91,131` `^status: superseded$`;
  `bug-mint-test.sh:86,115` `^status: done$`;
  `record-mint-test.sh:95,133` `^status: done$`.
  Listed test edits + script change → suite red. Listed test edits
  only → tests green and disposition words stay on `status:` (the
  `rg` still passes). **Fix:** name those lines; file-mode
  `--status <disposition>` → `^status: archived$` and no
  `history.tsv`; records-mode file `archived` plus ledger `--as`
  `<word>`.
  - resolved — close expects named in slice 2 change 13 with the
    mint scripts (file `archived`, ledger `--as`).

- **F4** Slice 1 verify vs `SKILL.md` edit. Verify `rg`s
  `specs/records-front-matter.md` in `SKILL.md`; the bundled-bullet
  only adds `specs/` / `specs/README.md`. An implementer who follows
  the change fails their own gate. **Fix:** name the file in that
  bullet, or `rg specs/` in `SKILL.md`.
  - resolved — bundles bullet names `specs/records-front-matter.md`.

- **F5** Slice 2 empty-`stage:` plant. New cases go in the shared
  `records-test.sh` fixture with no `rm`. HEAD isolates failing
  plants (sneaky, mismatch). A leftover empty `stage:` reddens every
  later `check` green. **Fix:** plant, assert, `rm` (or a throwaway
  fixture).
  - resolved — empty `stage:` is a throwaway fixture (or
    plant/assert/`rm`); unknown `stage` may stay in the main fixture.

- **F6** Slice 2 is not independently committable. After the new
  `records.sh` `check` rejects `open`, mint tests that copy
  `JOURNAL_RS` and `check` still mint from `status: open` templates
  (`note-mint-test.sh:111–116`, `bug-mint-test.sh:106–111`,
  `record-mint-test.sh:124–129`). They are not on slice 2’s file
  list; slice 2’s gate is only journal `run.sh` + lint. **Fix:**
  move those template + mint-default expects into slice 2, or add
  the three test scripts to slice 2 files + verify, or drop
  independent-commit and land 2+3 together.
  - resolved — option 1: slice 2 change 13 takes templates, mint
    scripts, mint tests (default + close expects); slice 2 verify
    adds notepad/debugger/backlog `run.sh`.

- **F7** `cmd_migrate_status` vs `stamp()`. Table says rewrite
  `status:` only, do not bump `updated:`. `stamp()` always rewrites
  `updated:`. Reusing it stays green — the migrate test does not
  assert `updated:`. **Fix:** front-matter-only rewrite (copy
  `stamp`’s `infm` guard, omit the `updated:` arm). Assert a planted
  `updated: 2020-01-01` survives.
  - resolved — `migrate_status_line` copies `stamp`’s `infm` guard,
    omits `updated:`; migrate test asserts `updated: 2020-01-01`
    and `migrated=` of actually-changed files.

- **F8** Slice 3 — `revise.md` still teaches `current`.
  `skills/blueprint/verbs/revise.md:6,214` and
  `skills/contractor/verbs/revise.md:6,199`: “Do not promote/flip
  `status:` to `current`.” That is not the string `status: current`,
  so the verify `rg` misses it; `touch --status current` then
  errors. **Fix:** add both files; `current` → `published`.
  - resolved — both `revise.md` files on slice 3; `current` →
    `published`.

Nice-to-have:

- **N1** Slice 1 is newest-path (docs/registry), not the riskiest
  end-to-end. Two predicates / live-set / migrate live in slice 2.
  Matches the spec’s contract-first order; a green slice 1 does not
  prove `records.sh`.
  - deferred — spec already ordered contract-first; a label change
    does not change the job.
- **N2** `standup.sh` Global Constraints “`:111–114` copy then
  check” — those lines are only `check`. Copy is `:56–73`.
  - resolved — cite is copy `:56–73` then check `:111–114`.
- **N3** Repeatable `--stage` OR and `grep --stage` have no test.
  Last-wins `--stage` and grep without `--stage` stay green.
  - resolved — `list --stage a --stage b` OR and
    `grep --stage` added to slice 2 tests.
- **N4** `facts-test.sh:43–45` still plants file `status: done`.
  Rewrite to `archived`.
  - resolved — `mk_record plans … "archived"` in slice 3.
- **N5** `cmd_list` pipeline: restore HEAD’s `IFS= read -r`.
  - resolved — `while IFS= read -r r` in the list pipeline.
- **N6** `analyst-facts.sh:193` still prints a literal `open`
  column if the `case` arm becomes `draft`. Print `$st`. Keep fact
  keys `open_bugs` / `stale_open_records`. Prefer keeping
  `open_records` / `current_records` keys too (health kept names
  as output contract).
  - resolved — keep `open_records`/`current_records` keys; `case
    draft`/`published`; print `$st`.
- **N7** `skills/backlog/templates/trackers.md:19` body “stays
  `open`”; `skills/analyst/templates/briefing.md:22` and
  `diagnostics.md:19` teach records still `` `open` ``. Restate
  `draft`.
  - resolved — all three on slice 3.
- **N8** Byte-identical later visit + planted `open` → `draft`
  (migrate not only in the refresh `else`).
  - resolved — standup-test covers already-current script + planted
    `open`.
- **N9** Disable-restore red-proof for the no-equality `check` arm
  (copy, restore `elif [ "$disp" != "$status" ]`, show the
  archived+consumed plant goes red).
  - resolved — added next to the live-set red-proof.

### 2026-08-22 — approve-with-changes

Delta pass after F1–F8 / N2–N9 fold (N1 deferred). Same-session author;
depth dial off. Two predicates, migrate-then-check, slice 2 file list,
and notepad/`revise.md` paths match HEAD.

Must-fix: none.

Nice-to-have:

- **N10** `--stage ""`: `stage_ok` returns 0 when `f_stage` is empty
  (`[ -z "$f_stage" ]`), so a present empty flag is “no filter”
  rather than “match nothing.” Distinguish flag-absent from
  empty-want (`f_stage_given=1`, then `grep -qxF`).
  - resolved — `f_stage_given=1` on `--stage`; `stage_ok` short-
    circuits only when the flag was absent.
- **N11** `verbs/new.md` still says `docs/../specs/records-front-matter.md`
  (ground-check reports it missing). The parenthetical skill-root
  path `specs/records-front-matter.md` is the one to write.
  - resolved — slice 1 points at `specs/records-front-matter.md`
    relative to the skill root.
