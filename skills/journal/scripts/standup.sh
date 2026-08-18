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
# lock-in copy creates <agent-templates>/<skill>/. Additive and
# idempotent-safe: it never overwrites an existing file, and it refuses a
# root that is already stood up (scripts/records.sh present — an upgrade is
# a diff, not a re-standup). A home that merely EXISTS (a legacy path, or a
# notepad-created .records/notes/ with no tool) is fine — the tool is
# written beside what is there. Exit codes: 0 ok · 1 usage · 2 refused/failed.
set -eu

SKILL="$(cd "$(dirname "$0")/.." && pwd)"

usage() { echo "usage: standup.sh <target-root> [--records-root <rel>]" >&2; exit 1; }

[ $# -ge 1 ] || usage
root="$1"; shift
rr_rel=".records"
while [ $# -gt 0 ]; do
  case "$1" in
    --records-root) [ $# -ge 2 ] || usage; rr_rel="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -d "$root" ] || { echo "no such directory: $root" >&2; exit 2; }
[ -f "$SKILL/scripts/records.sh" ] || { echo "records.sh missing beside this script: $SKILL/scripts/records.sh" >&2; exit 2; }
rr="$root/$rr_rel"

if [ -e "$rr/scripts/records.sh" ]; then
  echo "refusing: $rr is already stood up (upgrade is a diff, not a re-standup)" >&2
  exit 2
fi

mkdir -p "$rr/scripts"
cp "$SKILL/scripts/records.sh" "$rr/scripts/records.sh"
chmod +x "$rr/scripts/records.sh"

[ -e "$rr/history.tsv" ] || : > "$rr/history.tsv"

if [ ! -e "$rr/README.md" ]; then
  cat > "$rr/README.md" <<EOF
# Records

Records accumulated during development. Each store directory holds markdown
records carrying the front-matter contract (doctype/status/created/updated/tags);
\`scripts/records.sh\` is the query + lifecycle tool (\`list\`, \`new\`, \`touch\`,
\`done\`, \`history\`, \`prune-candidates\`, \`check\`) and the sole writer of
\`history.tsv\`, the closure ledger. \`templates/\`, \`scripts/\`,
\`doctrine/\`, and \`history.tsv\` are reserved — not stores. This directory is
the records *home*; sibling homes (project templates, project doctrine) default
underneath it without being part of the records layer.

Stores appear when a skill first writes. Project templates live in the
agent-templates home (default \`.records/templates/<skill>/\`) and arrive
with the writer. Journal setup deploys this tool layer only.

Stood up by journal on $(date +%Y-%m-%d).
EOF
fi

echo "records: $rr (journal)"
"$rr/scripts/records.sh" check
