#!/bin/sh
# standup.sh — stage Journal's engine and stand up the records substrate.
#
#   standup.sh <target-root> --workspace <rel> --records-root <rel>
#
# The package engine is staged at <workspace>/journal/scripts/records.sh.
# The ledger and README live at <records-root>. No store or template directory
# is created. Package bytes win for the staged engine; project records win.
set -eu

SKILL="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  echo "usage: standup.sh <target-root> --workspace <rel> --records-root <rel>" >&2
  exit 1
}

valid_rel_dir() {
  [ -n "$1" ] || return 1
  case "$1" in .|/*) return 1 ;; esac
  case "/$1/" in */../*|*/./*|*//*) return 1 ;; esac
  return 0
}

safe_tree() { # verify existing parents from root to target
  target="$1"
  case "$target" in "$root"/*) rel="${target#"$root"/}" ;; *) return 1 ;; esac
  current="$root"
  old_ifs=$IFS
  IFS='/'; set -- $rel; IFS=$old_ifs
  for part in "$@"; do
    current="$current/$part"
    if [ -L "$current" ]; then
      return 1
    elif [ -e "$current" ] && [ ! -d "$current" ]; then
      return 1
    fi
  done
}

make_tree() { # create after every existing parent has passed safe_tree
  target="$1"
  rel="${target#"$root"/}"
  current="$root"
  old_ifs=$IFS
  IFS='/'; set -- $rel; IFS=$old_ifs
  for part in "$@"; do
    current="$current/$part"
    if [ ! -e "$current" ]; then mkdir "$current"; fi
    [ -d "$current" ] && [ ! -L "$current" ] || return 1
  done
}

[ $# -ge 1 ] || usage
root="$1"; shift
workspace_rel=""
records_rel=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) [ $# -ge 2 ] || usage; workspace_rel="$2"; shift 2 ;;
    --records-root) [ $# -ge 2 ] || usage; records_rel="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$workspace_rel" ] && [ -n "$records_rel" ] || usage
valid_rel_dir "$workspace_rel" || {
  echo "standup.sh: --workspace must be relative, non-dot, and contain no .. segment" >&2
  exit 1
}
valid_rel_dir "$records_rel" || {
  echo "standup.sh: --records-root must be relative, non-dot, and contain no .. segment" >&2
  exit 1
}
[ -d "$root" ] && [ ! -L "$root" ] || { echo "no safe target directory: $root" >&2; exit 2; }
root="$(cd "$root" && pwd)"
source_engine="$SKILL/scripts/records.sh"
[ -f "$source_engine" ] || { echo "records.sh missing beside this script: $source_engine" >&2; exit 2; }

workspace="$root/$workspace_rel"
records="$root/$records_rel"
script_dir="$workspace/journal/scripts"
deployed="$script_dir/records.sh"

safe_tree "$script_dir" && safe_tree "$records" || {
  echo "standup.sh: unsafe workspace or records parent" >&2
  exit 2
}
for entry in "$deployed" "$records/history.tsv" "$records/README.md"; do
  if [ -L "$entry" ] || { [ -e "$entry" ] && [ ! -f "$entry" ]; }; then
    echo "standup.sh: unsafe incumbent: $entry" >&2
    exit 2
  fi
done
[ -z "${JOURNAL_SETUP_TEST_AFTER_PREFLIGHT:-}" ] || {
  [ -x "$JOURNAL_SETUP_TEST_AFTER_PREFLIGHT" ] || { echo "standup.sh: test hook is not executable" >&2; exit 2; }
  "$JOURNAL_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$workspace_rel" "$records_rel"
}
make_tree "$script_dir" || { echo "standup.sh: unsafe workspace parent during creation" >&2; exit 2; }
make_tree "$records" || { echo "standup.sh: unsafe records parent during creation" >&2; exit 2; }

wrote_script=0
write_count=0
after_write() {
  write_count=$((write_count + 1))
  echo "wrote: $1"
  [ -z "${JOURNAL_SETUP_TEST_AFTER_WRITE:-}" ] || {
    [ -x "$JOURNAL_SETUP_TEST_AFTER_WRITE" ] || {
      echo "standup.sh: test post-write hook is not executable" >&2; exit 2;
    }
    "$JOURNAL_SETUP_TEST_AFTER_WRITE" "$root" "$workspace_rel" "$records_rel" "$1" "$write_count"
  }
}
if [ -e "$deployed" ] && cmp -s "$source_engine" "$deployed"; then
  label="journal, current"
  [ -x "$deployed" ] || wrote_script=1
else
  was_present=0
  [ -e "$deployed" ] && was_present=1
  safe_tree "$script_dir" || { echo "standup.sh: unsafe workspace parent during write" >&2; exit 2; }
  cp "$source_engine" "$deployed"
  label="journal"
  [ "$was_present" -eq 0 ] || label="journal, refreshed"
  wrote_script=1
fi
safe_tree "$script_dir" || { echo "standup.sh: unsafe workspace parent during write" >&2; exit 2; }
chmod +x "$deployed"
[ "$wrote_script" -eq 0 ] || after_write "$workspace_rel/journal/scripts/records.sh"

if [ ! -e "$records/history.tsv" ]; then
  safe_tree "$records" || { echo "standup.sh: unsafe records parent during write" >&2; exit 2; }
  : > "$records/history.tsv"
  after_write "$records_rel/history.tsv"
fi

if [ ! -e "$records/README.md" ]; then
  safe_tree "$records" || { echo "standup.sh: unsafe records parent during write" >&2; exit 2; }
  cat > "$records/README.md" <<EOF
# Records

Records accumulated during development. A **record** is a Markdown file named
\`YYYY-MM-DD-<slug>.md\` carrying the four-key front-matter contract:
\`doctype\`, \`status\`, \`schema\`, and \`tags\`. The filename date is the
creation-date authority; Git is the durable modification history.
\`$workspace_rel/journal/scripts/records.sh\` is the query and lifecycle engine;
every invocation passes \`--root <root> --records-root $records_rel\`. It is the
sole writer of \`history.tsv\`, the closure ledger.

The directory layout under this root belongs to record writers. The engine
crawls records at any depth and knows no store roster. Project templates live
at \`<agent-workspace>/<skill>/templates/\` (for example,
\`.spaces/notepad/templates/\`); project doctrine lives at
\`<agent-workspace>/<skill>/doctrine/\`. Journal setup deploys the engine,
ledger, and this README only.

Stood up by journal on $(date +%Y-%m-%d).
EOF
  after_write "$records_rel/README.md"
fi

echo "records: $records ($label)"
if ! "$deployed" --root "$root" --records-root "$records_rel" check; then
  echo "records check failed — tool layer is up; run the owning skill's migrate verb for legacy records, then /journal curate" >&2
fi
