#!/bin/sh
# standup.sh — stand up the records layer in a target project (the mechanical half
# of `journal setup`; judgment — resolving the root, reading a declared
# records-root:, whether to commit — stays with the verb).
#
#   standup.sh <target-root> [--records-root <rel>]
#
# Creates <target-root>/<records-root> (default .records): the eight store
# directories, templates/ (copied from this skill), scripts/records.sh (the
# deployed asset), and an empty history.tsv ledger. Additive and idempotent-safe:
# it never overwrites an existing file, and it refuses a root that is already
# stood up (templates/ or scripts/records.sh present — an upgrade is a diff, not
# a re-standup). A records root that merely EXISTS (a legacy dev/ tree) is fine —
# stores are added alongside what is there; converting legacy content is
# migration's job, not standup's. Exit codes: 0 ok · 1 usage · 2 refused/failed.
set -eu

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
STORES="adr bugs design notes plans reports tickets trackers"

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
[ -d "$SKILL/templates" ] || { echo "templates missing beside this script: $SKILL/templates" >&2; exit 2; }
rr="$root/$rr_rel"

if [ -e "$rr/templates" ] || [ -e "$rr/scripts/records.sh" ]; then
  echo "refusing: $rr is already stood up (upgrade is a diff, not a re-standup)" >&2
  exit 2
fi

for s in $STORES; do
  mkdir -p "$rr/$s"
  # .gitkeep so the empty store survives a commit; invisible to store scans (*.md only)
  [ -e "$rr/$s/.gitkeep" ] || : > "$rr/$s/.gitkeep"
done

mkdir -p "$rr/templates" "$rr/scripts"
for t in "$SKILL/templates/"*.md; do
  cp "$t" "$rr/templates/$(basename "$t")"
done
cp "$SKILL/scripts/records.sh" "$rr/scripts/records.sh"
chmod +x "$rr/scripts/records.sh"

[ -e "$rr/history.tsv" ] || : > "$rr/history.tsv"

if [ ! -e "$rr/README.md" ]; then
  cat > "$rr/README.md" <<EOF
# Records

Records accumulated during development. Each store directory holds markdown
records carrying the front-matter contract (doctype/status/created/updated/tags);
\`scripts/records.sh\` is the query + lifecycle tool (\`list\`, \`new\`, \`touch\`,
\`done\`, \`history\`, \`check\`) and the sole writer of \`history.tsv\`, the
closure ledger. \`templates/\`, \`scripts/\`, and \`history.tsv\` are reserved —
not stores.

Stood up by journal on $(date +%Y-%m-%d).
EOF
fi

echo "records: $rr (journal)"
"$rr/scripts/records.sh" check
