#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; API="$HERE/../trackers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/trackers-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok(){ if "$@" >/dev/null 2>&1;then pass=$((pass+1));else echo "FAIL $*" >&2;fail=$((fail+1));fi;}
no(){ if "$@" >/dev/null 2>&1;then echo "FAIL accepted $*" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing: $2" >&2;fail=$((fail+1));fi;}
lacks(){ if grep -qF -- "$2" "$1";then echo "FAIL present: $2" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}

R="$T/root"; mkdir -p "$R/.trackers/tables"; touch "$R/.trackers/tables/.gitkeep"; git -C "$R" init -q
cp "$API" "$R/.trackers/trackers.sh"; chmod +x "$R/.trackers/trackers.sh"
printf 'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult\n' > "$R/.trackers/history.tsv"
printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/tables/routines.tsv"
RUN=("$R/.trackers/trackers.sh")
OUT="$T/out"

no "$API" describe

"${RUN[@]}" describe > "$OUT"; has "$OUT" 'schema=tracker@2'; has "$OUT" 'commands=describe,catalog,history,create,page,update,observe,consume'
out="$("${RUN[@]}" create --tracker routines --text 'When release starts, rerun checks' --evidence docs/release.md)"
id1="$(printf '%s\n' "$out" | sed -n 's/^id=//p')"; eq 'first id' routines-1 "$id1"
has <(printf '%s\n' "$out") 'wrote=tables/routines.tsv'
out="$("${RUN[@]}" create --tracker routines --text 'When CI flakes, collect diagnostics')"; id2="$(printf '%s\n' "$out"|sed -n 's/^id=//p')"; eq 'second id' routines-2 "$id2"
no "${RUN[@]}" create --tracker routines --text $'bad\ttext'
printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/tables/receipts.tsv"
out="$("${RUN[@]}" create --tracker receipts --text 'ordinary queue')";eq 'receipt word has no reserved meaning' receipts-1 "$(printf '%s\n' "$out"|sed -n 's/^id=//p')"
rm "$R/.trackers/tables/receipts.tsv"
printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/tables/history.tsv"
out="$("${RUN[@]}" create --tracker history --text 'ordinary queue')";eq 'history word has no reserved stem meaning' history-1 "$(printf '%s\n' "$out"|sed -n 's/^id=//p')"
rm "$R/.trackers/tables/history.tsv"

"${RUN[@]}" page --tracker routines --status open --limit 1 > "$OUT"
has "$OUT" $'routines-1\t'; has "$OUT" 'next=routines-1'; lacks "$OUT" $'routines-2\t'
"${RUN[@]}" page --tracker routines --status open --limit 2 --after routines-1 > "$OUT"; has "$OUT" $'routines-2\t'
no "${RUN[@]}" page --tracker routines --status open --limit 2 --after routines-99
before="$(wc -l < "$R/.trackers/history.tsv" | tr -d ' ')"; "${RUN[@]}" page --tracker routines --status all --limit 9 >/dev/null
eq 'page is side-effect free' "$before" "$(wc -l < "$R/.trackers/history.tsv" | tr -d ' ')"

# Debrief can keep one open failure family through the unchanged tracker@2 API.
printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/tables/failures.tsv"
history_before="$(wc -l <"$R/.trackers/history.tsv"|tr -d ' ')"
out="$("${RUN[@]}" create --tracker failures --text 'cargo test: timeout after tui_runtime' --evidence ci/run-1.log)"
failure_id="$(printf '%s\n' "$out"|sed -n 's/^id=//p')";eq 'failure family id' failures-1 "$failure_id"
failure_created="$(awk -F '\t' '$1=="failures-1"{print $2}' "$R/.trackers/tables/failures.tsv")"
"${RUN[@]}" update --tracker failures --id "$failure_id" --text 'cargo test: tui_runtime hangs after terminal restore' --evidence ci/run-3.log >/dev/null
eq 'failure update preserves id and created' "failures-1\t$failure_created\tcargo test: tui_runtime hangs after terminal restore\tci/run-3.log" "$(awk -F '\t' '$1=="failures-1"{print $1"\\t"$2"\\t"$3"\\t"$4}' "$R/.trackers/tables/failures.tsv")"
"${RUN[@]}" page --tracker failures --status open --limit 9 >"$OUT"
eq 'matching family remains one row' 1 "$(grep -c '^failures-' "$OUT")"
"${RUN[@]}" create --tracker failures --text 'shellcheck: SC2034 in setup helper' --evidence local/shellcheck.log >/dev/null
"${RUN[@]}" page --tracker failures --status open --limit 9 >"$OUT"
eq 'unrelated signature creates a second row' 2 "$(grep -c '^failures-' "$OUT")"
eq 'failure create/update leaves history alone' "$history_before" "$(wc -l <"$R/.trackers/history.tsv"|tr -d ' ')"

# Red-proof page scratch allocation: a predictable-name symlink must never be opened.
PAGE_TMP="$T/page-tmp";mkdir "$PAGE_TMP";PAGE_WRAP="$T/page-wrap.sh"
printf '%s\n' '#!/bin/sh' 'target="$1"' 'shift' 'ln -s "$target" "$TMPDIR/tracker-page-rows.$$"' 'exec "$@"' > "$PAGE_WRAP";chmod +x "$PAGE_WRAP"
printf 'queue sentinel\n' > "$T/queue-sentinel"
TMPDIR="$PAGE_TMP" "$PAGE_WRAP" "$T/queue-sentinel" "${RUN[@]}" page --tracker routines --status open --limit 1 >/dev/null
eq 'queue page ignores predictable symlink' 'queue sentinel' "$(sed -n '1p' "$T/queue-sentinel")"
printf 'history sentinel\n' > "$T/history-sentinel"
TMPDIR="$PAGE_TMP" "$PAGE_WRAP" "$T/history-sentinel" "${RUN[@]}" history --limit 1 >/dev/null
eq 'history page ignores predictable symlink' 'history sentinel' "$(sed -n '1p' "$T/history-sentinel")"
CLEAN_TMP="$T/clean-page-tmp";mkdir "$CLEAN_TMP"
env TMPDIR="$CLEAN_TMP" "${RUN[@]}" page --tracker routines --status open --limit 1 >/dev/null
env TMPDIR="$CLEAN_TMP" "${RUN[@]}" history --limit 1 >/dev/null
no env TMPDIR="$CLEAN_TMP" "${RUN[@]}" history --limit 1 --after event-99
[ -z "$(find "$CLEAN_TMP" -name 'tracker-page-rows.*' -print -quit)" ]&&pass=$((pass+1))||{ echo 'FAIL page scratch remained' >&2;fail=$((fail+1));}

"${RUN[@]}" observe --consumer foreman/tune --tracker routines --ids routines-1 > "$OUT"; has "$OUT" 'event=event-1';has "$OUT" 'wrote=history.tsv'
"${RUN[@]}" observe --consumer foreman/tune --tracker routines --ids routines-1 > "$OUT"; has "$OUT" 'unchanged=routines-1'
"${RUN[@]}" update --tracker routines --id routines-1 --text 'When release starts, rerun all checks'
created2="$(awk -F '\t' '$1=="routines-2"{print $2}' "$R/.trackers/tables/routines.tsv")"
"${RUN[@]}" update --tracker routines --id routines-2 --text 'literal\nvalue' --evidence 'evidence\tvalue'
expected="$(printf 'routines-2\t%s\tliteral\\nvalue\tevidence\\tvalue' "$created2")"
actual="$(sed -n '3p' "$R/.trackers/tables/routines.tsv")"
eq 'update preserves literal backslashes' "$expected" "$actual"
eq 'update remains one physical row' 3 "$(wc -l < "$R/.trackers/tables/routines.tsv" | tr -d ' ')"
ok "${RUN[@]}" catalog
"${RUN[@]}" page --tracker routines --status open --limit 9 --consumer foreman/tune --unobserved > "$OUT"
lacks "$OUT" $'routines-1\t'; has "$OUT" $'routines-2\t'

no "${RUN[@]}" consume --consumer foreman/tune --tracker routines --ids routines-1
"${RUN[@]}" consume --consumer foreman/tune --tracker routines --ids routines-1 routines-99 --resolution 'Covered by release operation' --result .agents/skilldata/foreman/operations/release.md > "$OUT"
has "$OUT" 'event=event-2'; has "$OUT" 'missing=routines-99'
"${RUN[@]}" consume --consumer other/tool --tracker routines --ids routines-1 --resolution duplicate > "$OUT"; has "$OUT" 'already-consumed=routines-1'
no "${RUN[@]}" update --tracker routines --id routines-1 --text changed
"${RUN[@]}" page --tracker routines --status consumed --limit 9 > "$OUT"; has "$OUT" $'routines-1\t'; lacks "$OUT" $'routines-2\t'
"${RUN[@]}" history --limit 1 > "$OUT";has "$OUT" 'schema=tracker@2';has "$OUT" 'next=event-1';has "$OUT" $'event-1\t';lacks "$OUT" $'event-2\t'
"${RUN[@]}" history --limit 1 --after event-1 > "$OUT";has "$OUT" 'next=';has "$OUT" $'event-2\t';lacks "$OUT" $'event-1\t'
no "${RUN[@]}" history --limit 1 --consumer foreman/tune
no "${RUN[@]}" page --tracker absent --status all --limit 9
cp "$R/.trackers/history.tsv" "$T/history.before";sed -n '2p' "$T/history.before" >>"$R/.trackers/history.tsv";no "${RUN[@]}" describe
cp "$T/history.before" "$R/.trackers/history.tsv";cmp "$T/history.before" "$R/.trackers/history.tsv" >/dev/null||{ echo 'FAIL history restore drift' >&2;fail=$((fail+1));}

# Removing and recreating a tracker allocates above retained history item IDs.
mv "$R/.trackers/tables/routines.tsv" "$T/old.tsv"; printf 'id\tcreated\ttext\tevidence\n' > "$R/.trackers/tables/routines.tsv"
out="$("${RUN[@]}" create --tracker routines --text recreated)"; eq 'history prevents id collision' routines-2 "$(printf '%s\n' "$out"|sed -n 's/^id=//p')"

# Red-proof schema guard: mutate one header byte, require failure, restore byte-identically.
cp "$R/.trackers/tables/routines.tsv" "$T/queue.before"; sed '1s/^id/bad/' "$T/queue.before" > "$R/.trackers/tables/routines.tsv"
no "${RUN[@]}" catalog
cp "$T/queue.before" "$R/.trackers/tables/routines.tsv"; cmp "$T/queue.before" "$R/.trackers/tables/routines.tsv" >/dev/null || { echo 'FAIL restore drift' >&2; fail=$((fail+1)); }
ok "${RUN[@]}" catalog

# A root-level TSV is an incompatible tracker@1 layout, including receipts.tsv.
cp "$R/.trackers/tables/routines.tsv" "$R/.trackers/legacy.tsv";no "${RUN[@]}" describe;rm "$R/.trackers/legacy.tsv"
printf 'legacy\n' > "$R/.trackers/receipts.tsv";no "${RUN[@]}" describe;rm "$R/.trackers/receipts.tsv"

ln -s "$R/.trackers" "$R/link"; no "$R/link/trackers.sh" describe
mkdir -p "$R/real/nested/tables";touch "$R/real/nested/tables/.gitkeep";cp "$API" "$R/real/nested/trackers.sh";chmod +x "$R/real/nested/trackers.sh"
cp "$R/.trackers/history.tsv" "$R/real/nested/history.tsv";cp "$R/.trackers/tables/routines.tsv" "$R/real/nested/tables/routines.tsv"
ln -s "$R/real" "$R/alias";no "$R/alias/nested/trackers.sh" describe

mkdir -p "$R/child/.trackers/tables";touch "$R/child/.trackers/tables/.gitkeep"
cp "$API" "$R/child/.trackers/trackers.sh";chmod +x "$R/child/.trackers/trackers.sh"
cp "$R/.trackers/history.tsv" "$R/child/.trackers/history.tsv"
cp "$R/.trackers/tables/routines.tsv" "$R/child/.trackers/tables/routines.tsv"
no "$R/child/.trackers/trackers.sh" describe

mkdir -p "$T/outside/.trackers/tables" "$T/symlink-root";touch "$T/outside/.trackers/tables/.gitkeep"
git -C "$T/symlink-root" init -q
cp "$API" "$T/outside/.trackers/trackers.sh";chmod +x "$T/outside/.trackers/trackers.sh"
cp "$R/.trackers/history.tsv" "$T/outside/.trackers/history.tsv"
cp "$R/.trackers/tables/routines.tsv" "$T/outside/.trackers/tables/routines.tsv"
ln -s "$T/outside/.trackers" "$T/symlink-root/.trackers"
no "$T/symlink-root/.trackers/trackers.sh" describe

echo "trackers-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
