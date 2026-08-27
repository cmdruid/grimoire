#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; API="$HERE/../tracker-api.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/tracker-api-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing: $2" >&2;fail=$((fail+1));fi;}
lacks(){ if grep -qF -- "$2" "$1";then echo "FAIL present: $2" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}

R="$T/root"; mkdir -p "$R/.trackers"; git -C "$R" init -q
cp "$API" "$R/.trackers/tracker-api.sh"; chmod +x "$R/.trackers/tracker-api.sh"
printf 'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult\n' > "$R/.trackers/receipts.tsv"
printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/routines.tsv"
RUN=("$R/.trackers/tracker-api.sh" --root "$R" --records-root .records --workspace .spaces --trackers-root .trackers)
OUT="$T/out"

no "$API" --root "$R" --records-root .records --workspace .spaces --trackers-root .trackers describe

"${RUN[@]}" describe > "$OUT"; has "$OUT" 'schema=tracker@1'; has "$OUT" 'commands=describe,catalog,create,page,update,observe,consume'
out="$("${RUN[@]}" create --tracker routines --text 'When release starts, rerun checks' --evidence docs/release.md)"
id1="$(printf '%s\n' "$out" | sed -n 's/^id=//p')"; eq 'first id' routines-1 "$id1"
out="$("${RUN[@]}" create --tracker routines --text 'When CI flakes, collect diagnostics')"; id2="$(printf '%s\n' "$out"|sed -n 's/^id=//p')"; eq 'second id' routines-2 "$id2"
no "${RUN[@]}" create --tracker routines --text $'bad\ttext'
no "${RUN[@]}" create --tracker receipts --text nope

"${RUN[@]}" page --tracker routines --status open --limit 1 > "$OUT"
has "$OUT" $'routines-1\t'; has "$OUT" 'next=routines-1'; lacks "$OUT" $'routines-2\t'
"${RUN[@]}" page --tracker routines --status open --limit 2 --after routines-1 > "$OUT"; has "$OUT" $'routines-2\t'
no "${RUN[@]}" page --tracker routines --status open --limit 2 --after routines-99
before="$(wc -l < "$R/.trackers/receipts.tsv" | tr -d ' ')"; "${RUN[@]}" page --tracker routines --status all --limit 9 >/dev/null
eq 'page is side-effect free' "$before" "$(wc -l < "$R/.trackers/receipts.tsv" | tr -d ' ')"

"${RUN[@]}" observe --consumer foreman/tune --tracker routines --ids routines-1 > "$OUT"; has "$OUT" 'receipt=receipt-1'
"${RUN[@]}" observe --consumer foreman/tune --tracker routines --ids routines-1 > "$OUT"; has "$OUT" 'unchanged=routines-1'
"${RUN[@]}" update --tracker routines --id routines-1 --text 'When release starts, rerun all checks'
"${RUN[@]}" page --tracker routines --status open --limit 9 --consumer foreman/tune --unobserved > "$OUT"
lacks "$OUT" $'routines-1\t'; has "$OUT" $'routines-2\t'

no "${RUN[@]}" consume --consumer foreman/tune --tracker routines --ids routines-1
"${RUN[@]}" consume --consumer foreman/tune --tracker routines --ids routines-1 routines-99 --resolution 'Covered by release operation' --result .spaces/foreman/operations/release.md > "$OUT"
has "$OUT" 'receipt=receipt-2'; has "$OUT" 'missing=routines-99'
"${RUN[@]}" consume --consumer other/tool --tracker routines --ids routines-1 --resolution duplicate > "$OUT"; has "$OUT" 'already-consumed=routines-1'
no "${RUN[@]}" update --tracker routines --id routines-1 --text changed
"${RUN[@]}" page --tracker routines --status consumed --limit 9 > "$OUT"; has "$OUT" $'routines-1\t'; lacks "$OUT" $'routines-2\t'
"${RUN[@]}" page --tracker receipts --status all --limit 9 > "$OUT"; has "$OUT" $'receipt-2\t'; no "${RUN[@]}" page --tracker receipts --status open --limit 9
no "${RUN[@]}" page --tracker receipts --status all --limit 9 --consumer foreman/tune --unobserved
no "${RUN[@]}" observe --consumer foreman/tune --tracker receipts --ids receipt-1

# Removing and recreating a tracker allocates above retained receipt item IDs.
mv "$R/.trackers/routines.tsv" "$T/old.tsv"; printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/routines.tsv"
out="$("${RUN[@]}" create --tracker routines --text recreated)"; eq 'receipt prevents id collision' routines-2 "$(printf '%s\n' "$out"|sed -n 's/^id=//p')"

# Red-proof schema guard: mutate one header byte, require failure, restore byte-identically.
cp "$R/.trackers/routines.tsv" "$T/queue.before"; sed '1s/^id/bad/' "$T/queue.before" > "$R/.trackers/routines.tsv"
no "${RUN[@]}" catalog
cp "$T/queue.before" "$R/.trackers/routines.tsv"; cmp "$T/queue.before" "$R/.trackers/routines.tsv" >/dev/null || { echo 'FAIL restore drift' >&2; fail=$((fail+1)); }
ok "${RUN[@]}" catalog

no "$R/.trackers/tracker-api.sh" --root "$R" --records-root .trackers/archive --workspace .spaces --trackers-root .trackers describe
ln -s "$T" "$R/link"; no "$R/.trackers/tracker-api.sh" --root "$R" --records-root .records --workspace .spaces --trackers-root link describe

echo "tracker-api-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
