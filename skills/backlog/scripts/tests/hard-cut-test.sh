#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";B="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";REPO="$(CDPATH='' cd -P "$B/../.."&&pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-hard-cut.XXXXXX")";trap 'rm -rf "$T"' EXIT
R="$T/root";legacy_workspace_dir="$R/.spaces/backlog/""trackers";mkdir -p "$R/.records/trackers" "$legacy_workspace_dir";git -C "$R" init -q
legacy_record='LEGACY_RECORD_CANARY_8421';legacy_workspace='LEGACY_WORKSPACE_CANARY_9532';live='LIVE_TRACKER_CANARY_1064'
printf '%s\n' "$legacy_record" > "$R/.records/trackers/old.md"
printf '%s\n' "$legacy_workspace" > "$legacy_workspace_dir/tasks.tsv"
SETUP="$B/scripts/backlog-setup.sh";"$SETUP" "$R" --apply > "$T/setup.out"
API=("$R/.trackers/trackers.sh")
"${API[@]}" create --tracker tasks --text "$live" > "$T/create.out"
"${API[@]}" catalog > "$T/catalog.out";"${API[@]}" page --tracker tasks --status open --limit 20 > "$T/page.out"
"$REPO/skills/analyst/scripts/analyst-facts.sh" status "$R" > "$T/analyst.out"
combined="$T/combined";awk 'FNR==1{print "---"FILENAME} {print}' "$T/setup.out" "$T/catalog.out" "$T/page.out" "$T/analyst.out" > "$combined"
pass=0;fail=0
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
lacks(){ if grep -qF -- "$2" "$1";then echo "FAIL surfaced $2" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted retired command" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL rejected current command" >&2;fail=$((fail+1));fi;}
has "$R/.records/trackers/old.md" "$legacy_record";has "$legacy_workspace_dir/tasks.tsv" "$legacy_workspace"
has "$combined" "$live";lacks "$combined" "$legacy_record";lacks "$combined" "$legacy_workspace"
for cmd in complete drop reorder migrate-import;do no "${API[@]}" "$cmd";done
[ -x "$B/scripts/trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1));[ ! -e "$B/scripts/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1));[ -f "$B/verbs/migrate.md" ]&&[ -x "$B/scripts/migrate-trackers.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
[ ! -e "$R/.trackers/tracker-api.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
legacy_owner_path='.spaces/backlog/'"trackers"
lacks "$B/SKILL.md" "$legacy_owner_path";lacks "$B/verbs/debrief.md" '.records/trackers'

# Ordinary setup remains tracker@1-blind; migration behavior has its own exhaustive suite.
OLD="$T/tracker1";mkdir -p "$OLD/.trackers";git -C "$OLD" init -q
printf '%s\n' $'id\tcreated\ttext\tevidence' $'tasks-1\t2026-08-30T00:00:00Z\tfirst row\tdocs/one' $'tasks-2\t2026-08-30T00:01:00Z\tsecond row\tdocs/two' >"$OLD/.trackers/tasks.tsv"
printf '%s\n' $'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult' $'receipt-1\t2026-08-30T00:02:00Z\tanalyst/status\ttasks\ttasks-1\tobserved\t\t' $'receipt-2\t2026-08-30T00:03:00Z\tcontractor/build\ttasks\ttasks-1\tconsumed\tdone\tdocs/result' >"$OLD/.trackers/receipts.tsv"
cp -R "$OLD/.trackers" "$T/tracker1.before"
no "$SETUP" "$OLD" --apply
diff -r "$T/tracker1.before" "$OLD/.trackers" >/dev/null&&pass=$((pass+1))||{ echo 'FAIL old layout changed during refusal' >&2;fail=$((fail+1));}

if rg -n 'tracker@1|receipt-[1-9]|receipts\.tsv' "$B/scripts/trackers.sh" "$B/scripts/backlog-setup.sh" "$B/scripts/tracker-layer-status.sh" >/dev/null;then
  echo 'FAIL live runtime retains tracker@1 compatibility' >&2;fail=$((fail+1))
else pass=$((pass+1));fi
echo "hard-cut-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
