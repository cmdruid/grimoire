#!/usr/bin/env bash
# scaffold-records.sh <root>
#
# Idempotently stand up the `.records/trackers/` stores the records instrument
# owns, per the record schema (the installation's `.handbook/rules/RECORDS.md`,
# canonical in clankshop's doctrine). Creates ONLY the five capture stores
# (tasks/issues/feedback + the notes/ and bugs/ store dirs) under `trackers/`;
# the wider `.records/` tree (tickets/, done/, plans/, reports/, audit/, ...)
# is created by its writers on first use or by the pack onramps -- backlog makes
# its own drawers, not the whole cabinet, and needs no prior setup.
#
# DOCTRINE: a mutating mechanical helper (sibling of scoped-commit.sh). It
# mutates only the paths it owns, and only to CREATE them when missing -- an
# existing tracker is NEVER rewritten, so filed entries always survive. Prints
# `created=`/`exists=` facts per path; the verb prose keeps the judgment.
set -euo pipefail

# Front-door variable `records-root` (default `.records`) -- see the
# front-door-variables doctrine. Prints the resolved repo-relative path.
resolve_records_root() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
              | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

root="${1:?usage: scaffold-records.sh <root>}"
[ -d "$root" ] || { echo "FAIL: root $root is not a directory" >&2; exit 2; }
rec_rel="$(resolve_records_root "$root")"
rec="$root/$rec_rel/trackers"

created=0 existed=0

mkfile() {  # mkfile <relpath> <heredoc-on-stdin> -- create-if-absent only
  local rel="$1" abs="$rec/$1"
  mkdir -p "$(dirname "$abs")"
  if [ -e "$abs" ]; then echo "exists=trackers/$rel"; existed=$((existed + 1))
  else cat > "$abs"; echo "created=trackers/$rel"; created=$((created + 1)); fi
}

mkfile "tasks.md" <<'EOF'
# Tasks — things to build / do

<!-- spine-doc v1
kind: tasks
entry: ^- (T-[0-9]+) —
ids: T
paused: \[⇧ TK-[^]]+\]
-->

_Flat living list (`/backlog task`). Wire format (schema: the installation's
`.handbook/rules/RECORDS.md`): `- T-041 — <task text> · added YYYY-MM-DD`. Take the next
free `T-` number scanning the live list AND the done log — IDs are never reused. Counter
IDs are allocated on the trunk only; a branch-side capture writes `((pending: <slug>))` in
the ID position and curation stamps the real ID at landing. An entry is open while listed:
completing it removes the line — its done-log line is the archive._

## Loose ends

## Adjacent improvements

## Open questions

## Future scope
EOF

mkfile "issues.md" <<'EOF'
# Issues — project problems / concerns / limitations

<!-- spine-doc v1
kind: issues
entry: ^### (I-[0-9]+) —
ids: I
paused: \[⇧ TK-[^]]+\]
-->

_Flat log (`/backlog issue`) for problems that aren't reproducible defects and aren't
build items. Entries `### I-017 — <title> (HIGH|MEDIUM|LOW)` grouped under `##` category
headings, then **What's wrong** / **Impact** / **Suggested direction**. Take the next free
`I-` number scanning the live file AND the done log; never renumber. Migrated entries keep
`(alias <old>)` on the heading line. Schema: the installation's
`.handbook/rules/RECORDS.md`._

## Problems / limitations

## Risks / concerns
EOF

mkfile "feedback.md" <<'EOF'
# Feedback — dev-experience observations

<!-- spine-doc v1
kind: feedback
entry: ^### (F-[0-9]+) ·
ids: F
paused: \[⇧ TK-[^]]+\]
-->

_Flat dated list (`/backlog feedback`) — the **single** dev-experience channel (skills /
scripts / tooling / environment). Entries `### F-003 · <short title> · YYYY-MM-DD`, newest
at the bottom of the live region; take the next free `F-` number scanning the live file
AND the done log. Schema: the installation's `.handbook/rules/RECORDS.md`._

<!-- live region: newest entries below -->
EOF

mkfile "notes/README.md" <<'EOF'
# notes/ — durable project facts (store dir)

Files: `<slug>.md`, one per fact (`/backlog note`). Each carries frontmatter
`type: note` + `id: N-007` + `status` + `updated` (counter IDs trunk-allocated; a
branch-side capture leaves `id:` pending until curation stamps it). A note is
**subordinate** — reached through the tracker entry it backs, never browsed. Completion
advances `status:`; curation may age resolved files into `archive/`. This README and
`archive/` carry no frontmatter. Schema: the installation's `.handbook/rules/RECORDS.md`.
EOF

mkfile "bugs/README.md" <<'EOF'
# bugs/ — reproducible defect reports (store dir)

Files: `<YYYY-MM-DD>-<slug>.md` from backlog's `templates/bug-report.md` (`/backlog bug`).
Each carries frontmatter `type: bug` + `id: B-009` + `status` + `updated` (counter IDs
trunk-allocated). A **store, not a work queue** — a report is tracked from a linked
actionable item (a `tasks.md` line or `issues.md` entry), never fished out for work;
completion advances `status:`, and curation may age resolved reports into `archive/`.
This README and `archive/` carry no frontmatter. Schema: the installation's
`.handbook/rules/RECORDS.md`.
EOF

echo "records-root=$rec_rel trackers-home=$rec created=$created existed=$existed"
