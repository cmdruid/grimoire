#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";B="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";REPO="$(CDPATH='' cd -P "$B/../.."&&pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-hard-cut.XXXXXX")";trap 'rm -rf "$T"' EXIT
R="$T/root";legacy_workspace_dir="$R/.spaces/backlog/""trackers";mkdir -p "$R/.records/trackers" "$legacy_workspace_dir";git -C "$R" init -q
legacy_record='LEGACY_RECORD_CANARY_8421';legacy_workspace='LEGACY_WORKSPACE_CANARY_9532';live='LIVE_TRACKER_CANARY_1064'
printf '%s\n' "$legacy_record" > "$R/.records/trackers/old.md"
printf '%s\n' "$legacy_workspace" > "$legacy_workspace_dir/tasks.tsv"
SETUP="$B/scripts/backlog-setup.sh";"$SETUP" "$R" --workspace .spaces --records-root .records --apply > "$T/setup.out"
API=("$R/.trackers/trackers.sh")
"${API[@]}" create --tracker tasks --text "$live" > "$T/create.out"
"${API[@]}" catalog > "$T/catalog.out";"${API[@]}" page --tracker tasks --status open --limit 20 > "$T/page.out"
"$REPO/skills/analyst/scripts/analyst-facts.sh" status "$R" > "$T/analyst.out"
combined="$T/combined";awk 'FNR==1{print "---"FILENAME} {print}' "$T/setup.out" "$T/catalog.out" "$T/page.out" "$T/analyst.out" > "$combined"
pass=0;fail=0
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
lacks(){ if grep -qF -- "$2" "$1";then echo "FAIL surfaced $2" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted retired command" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has "$R/.records/trackers/old.md" "$legacy_record";has "$legacy_workspace_dir/tasks.tsv" "$legacy_workspace"
has "$combined" "$live";lacks "$combined" "$legacy_record";lacks "$combined" "$legacy_workspace"
for cmd in complete drop reorder migrate-import;do no "${API[@]}" "$cmd";done
[ -x "$B/scripts/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1));[ ! -e "$B/scripts/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1));[ ! -e "$B/verbs/migrate.md" ]&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
legacy_owner_path='<agent-workspace>/backlog/'"trackers"
lacks "$B/SKILL.md" "$legacy_owner_path";lacks "$B/verbs/debrief.md" '.records/trackers'
echo "hard-cut-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
