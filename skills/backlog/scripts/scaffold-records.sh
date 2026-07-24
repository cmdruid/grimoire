#!/usr/bin/env bash
# scaffold-records.sh <root>
#
# Idempotently stand up the `.records/` trackers `/backlog` owns, per
# docs/TAXONOMY.md -- the "self-init, no floor" corollary of the typed-edge
# tenet (docs/design/2026-07-18-skill-self-init-model.md §1). Creates ONLY the
# five capture homes backlog owns (tasks/issues/feedback + the notes/ and bugs/
# store dirs); the wider `.records/` tree (plans/, archive/, adr/, reports/,
# logs/, audit/) belongs to other skills' init -- backlog makes its own drawers,
# not the whole cabinet, and depends on no `/foreman init` having run first.
#
# DOCTRINE: a mutating mechanical helper (sibling of scoped-commit.sh). It
# mutates only the paths it owns, and only to CREATE them when missing -- an
# existing tracker is NEVER rewritten, so filed entries always survive. Prints
# `created=`/`exists=` facts per path (evidence for the verb's report and for
# A4's idempotency proof); the verb prose keeps the judgment.
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
rec="$root/$rec_rel"

created=0 existed=0

mkfile() {  # mkfile <relpath> <heredoc-on-stdin> -- create-if-absent only
  local rel="$1" abs="$rec/$1"
  mkdir -p "$(dirname "$abs")"
  if [ -e "$abs" ]; then echo "exists=$rel"; existed=$((existed + 1))
  else cat > "$abs"; echo "created=$rel"; created=$((created + 1)); fi
}

mkfile "tasks.md" <<'EOF'
# Tasks — things to build / do

_Flat living list (`/backlog task`). One top-level header; one section per durable
domain / milestone group. Plain `-` bullets, **no checkboxes** — an item is open
while listed and simply removed when it ships (the commit is the record)._
_Per item: concrete description (with `file:line`) · **why** (one line) · effort
`(S/M/L)` · trailing `· added YYYY-MM-DD`. Schema: backlog's `docs/TAXONOMY.md`._

## Loose ends

## Adjacent improvements

## Open questions

## Future scope
EOF

mkfile "issues.md" <<'EOF'
# Issues — project problems / concerns / limitations

_Flat log (`/backlog issue`) for problems that aren't reproducible defects and
aren't build items. Category-prefixed running numbers — `P#` (problem /
limitation), `R#` (risk / concern); take the next free number, never renumber._
_Each entry: `### <prefix><n> — <title> (<HIGH|MEDIUM|LOW>)`, then **What's
wrong** / **Impact** / **Suggested direction**. Schema: backlog's `docs/TAXONOMY.md`._

## Problems / limitations (P#)

## Risks / concerns (R#)
EOF

mkfile "feedback.md" <<'EOF'
# Feedback — dev-experience observations

_Flat dated list (`/backlog feedback`) — the **single** dev-experience channel
(skills / scripts / tooling / environment). Newest added at the bottom of the
live region. Schema: backlog's `docs/TAXONOMY.md`._
_Each entry: `### <short title> · YYYY-MM-DD` + a short body noting whether it's
positive / a concern / a friction / a directional idea, and where it might lead._

<!-- live region: newest entries below -->
EOF

mkfile "notes/README.md" <<'EOF'
# notes/ — durable project facts (store dir)

Files: `<slug>.md` from backlog's `templates/note.md` (`/backlog note`). Each
carries `type: note` frontmatter (the doc-linter gate rejects a store-dir file
without it). A note is **subordinate** — reached through the tracker entry it
backs, never browsed. This README and any `archive/` carry no frontmatter.
Schema: backlog's `docs/TAXONOMY.md`.
EOF

mkfile "bugs/README.md" <<'EOF'
# bugs/ — reproducible defect reports (store dir)

Files: `<YYYY-MM-DD>-<slug>.md` from backlog's `templates/bug-report.md`
(`/backlog bug`). Each carries `type: bug` frontmatter (doc-linter gated). A
**store, not a work queue** — a report is tracked from a linked actionable item
(a `tasks.md` line or `issues.md` entry), never fished out for work; fixed
reports move to `archive/`. This README and `archive/` carry no frontmatter.
Schema: backlog's `docs/TAXONOMY.md`.
EOF

echo "records-root=$rec_rel records-home=$rec created=$created existed=$existed"
