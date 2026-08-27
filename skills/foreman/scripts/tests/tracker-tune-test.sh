#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";BASE="$(CDPATH='' cd -P "$HERE/../.."&&pwd)";REPO="$(CDPATH='' cd -P "$BASE/../.."&&pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-tune-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
R="$T/root";mkdir -p "$R/.trackers";git -C "$R" init -q
cp "$REPO/skills/backlog/scripts/tracker-api.sh" "$R/.trackers/tracker-api.sh";chmod +x "$R/.trackers/tracker-api.sh"
printf 'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult\n' > "$R/.trackers/receipts.tsv"
printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/routines.tsv"
API=("$R/.trackers/tracker-api.sh")
"${API[@]}" create --tracker routines --text 'release trigger and response' >/dev/null
"${API[@]}" create --tracker routines --text 'similar release evidence' >/dev/null
"${API[@]}" create --tracker routines --text 'insufficient sample' >/dev/null
OUT="$T/out"
"${API[@]}" page --tracker routines --status open --limit 10 --consumer foreman/tune --unobserved > "$OUT"
has 'bounded page sees first' $'routines-1\t' "$OUT";has 'bounded page sees third' $'routines-3\t' "$OUT"
"${API[@]}" consume --consumer foreman/tune --tracker routines --ids routines-1 routines-2 --resolution 'Accepted release operation' --result .spaces/foreman/operations/release.md >/dev/null
"${API[@]}" observe --consumer foreman/tune --tracker routines --ids routines-3 >/dev/null
"${API[@]}" page --tracker routines --status open --limit 10 --consumer foreman/tune --unobserved > "$OUT"
lacks 'resolved rows absent' $'routines-1\t' "$OUT";lacks 'deferred row observed' $'routines-3\t' "$OUT"
"${API[@]}" page --tracker routines --status open --limit 10 > "$OUT";has 'all-open can reconsider deferred' $'routines-3\t' "$OUT"

V="$BASE/verbs/tune.md"
for needle in 'page as a whole' 'compare incumbent operations' 'explicit acceptance' 'Call `observe`' 'Missing provider state';do has "tune contract $needle" "$needle" "$V";done
# Mutation red-proof: remove the acceptance guard in a copy and require the assertion to fail.
cp "$V" "$T/tune.before";count="$(grep -cF 'explicit acceptance' "$T/tune.before")";eq 'mutation target count' 1 "$count"
sed 's/explicit acceptance/approval/g' "$T/tune.before" > "$T/tune.broken"
if grep -qF 'explicit acceptance' "$T/tune.broken";then fail=$((fail+1));else pass=$((pass+1));fi
cmp "$V" "$T/tune.before" >/dev/null||fail=$((fail+1))
report tracker-tune-test
