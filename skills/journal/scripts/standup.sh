#!/bin/sh
# standup.sh — stand up the records *tool layer* in a target project (the
# mechanical half of `journal setup`; judgment — resolving the root, reading
# a declared agent-records: / records-root:, whether to commit — stays with
# the verb).
#
#   standup.sh <target-root> [--records-root <rel>]
#
# Creates <target-root>/<records-root> (default .records): scripts/records.sh
# (the deployed asset), an empty history.tsv ledger, and README.md if
# absent. It does NOT create store directories, .gitkeep files, or
# templates/ — the skill that mints a store creates that store; the first
# lock-in copy creates <templates-home>/<skill>/. Additive: a first visit
# writes the tool layer; a later visit refreshes records.sh when the skill
# copy has drifted (`cmp`) and never truncates the ledger or overwrites
# README. A home that merely EXISTS (a legacy path, or a notepad-created
# .records/notes/ with no tool) is fine — the tool is written beside what
# is there. Exit codes: 0 ok · 1 usage / bad --records-root · 2 failed
# (missing target or skill-side records.sh). A failing records check after
# a successful write still exits 0 (tool layer is up; curate the records).
set -eu

SKILL="$(cd "$(dirname "$0")/.." && pwd)"

usage() { echo "usage: standup.sh <target-root> [--records-root <rel>]" >&2; exit 1; }

valid_rel_dir() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
  return 0
}

[ $# -ge 1 ] || usage
root="$1"; shift
rr_rel=".records"
while [ $# -gt 0 ]; do
  case "$1" in
    --records-root) [ $# -ge 2 ] || usage; rr_rel="$2"; shift 2 ;;
    *) usage ;;
  esac
done
valid_rel_dir "$rr_rel" || {
  echo "standup.sh: --records-root must be a relative path with no .. segment: $rr_rel" >&2
  exit 1
}

[ -d "$root" ] || { echo "no such directory: $root" >&2; exit 2; }
[ -f "$SKILL/scripts/records.sh" ] || { echo "records.sh missing beside this script: $SKILL/scripts/records.sh" >&2; exit 2; }
rr="$root/$rr_rel"
rr_from_root="${rr#"$root"/}"
wrote_script=0
wrote_ledger=0
wrote_readme=0

if [ -e "$rr/scripts/records.sh" ]; then
  if cmp -s "$SKILL/scripts/records.sh" "$rr/scripts/records.sh"; then
    label="journal, current"
    [ -x "$rr/scripts/records.sh" ] || wrote_script=1
    chmod +x "$rr/scripts/records.sh"
  else
    cp "$SKILL/scripts/records.sh" "$rr/scripts/records.sh"
    chmod +x "$rr/scripts/records.sh"
    label="journal, refreshed"
    wrote_script=1
  fi
else
  mkdir -p "$rr/scripts"
  cp "$SKILL/scripts/records.sh" "$rr/scripts/records.sh"
  chmod +x "$rr/scripts/records.sh"
  label="journal"
  wrote_script=1
fi

if [ ! -e "$rr/history.tsv" ]; then
  : > "$rr/history.tsv"
  wrote_ledger=1
fi

if [ ! -e "$rr/README.md" ]; then
  cat > "$rr/README.md" <<EOF
# Records

Records accumulated during development. A **record** is a markdown file named
\`YYYY-MM-DD-<slug>.md\` carrying the front-matter contract
(doctype/status/created/updated/tags). \`scripts/records.sh\` is the query +
lifecycle tool (\`list\`, \`grep\`, \`new\`, \`touch\`, \`done\`, \`history\`,
\`prune-candidates\`, \`check\`) and the sole writer of \`history.tsv\`, the
closure ledger.

The directory layout under this root is the writers' business: a skill creates
only the directories it needs for its own work, so the tool crawls this root at
any depth instead of matching a list of store names. Nothing here needs
reserving — a file that is not a dated record declaring a doctype simply is not
a record, which is why this home can be shared with other homes. Project
templates live at \`<agent-workspace>/templates/<skill>/\` (default
\`.dev/templates/<skill>/\`) and arrive with the writer that mints them;
they are undated, so they are not records. Project **doctrine** resolves
through the agent-workspace home (default \`.dev/doctrine/\`). Journal setup
deploys this tool layer only.

Stood up by journal on $(date +%Y-%m-%d).
EOF
  wrote_readme=1
fi

echo "records: $rr ($label)"
[ "$wrote_script" -eq 1 ] && echo "wrote: $rr_from_root/scripts/records.sh"
[ "$wrote_ledger" -eq 1 ] && echo "wrote: $rr_from_root/history.tsv"
[ "$wrote_readme" -eq 1 ] && echo "wrote: $rr_from_root/README.md"
if ! "$rr/scripts/records.sh" check; then
  echo "records check failed — tool layer is up; run /journal curate" >&2
  exit 0
fi
