#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh";STATUS="$SKILL/scripts/tracker-readme-status.sh";TEMPLATE="$SKILL/templates/trackers-readme-block.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-readme-test.XXXXXX")";trap 'rm -rf "$T"' EXIT
pass=0;fail=0
has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing $2" >&2;fail=$((fail+1));fi;}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}
state(){ "$STATUS" "$TEMPLATE" "$1"|sed -n 's/^readme_status=//p';}

M="$T/missing";eq absent absent "$(state "$M")"
printf 'project prose\n'>"$T/plain";eq absent absent "$(state "$T/plain")"
cp "$TEMPLATE" "$T/current";eq current current "$(state "$T/current")"
sed 's/sole writer/only writer/' "$TEMPLATE">"$T/drifted";eq drifted drifted "$(state "$T/drifted")"
for shape in duplicate nested reversed begin-only end-only;do
  case "$shape" in
    duplicate) { cat "$TEMPLATE";cat "$TEMPLATE";} >"$T/$shape";;
    nested) { head -n 1 "$TEMPLATE";cat "$TEMPLATE";tail -n +2 "$TEMPLATE";} >"$T/$shape";;
    reversed) { tail -n 1 "$TEMPLATE";head -n 1 "$TEMPLATE";} >"$T/$shape";;
    begin-only) head -n 1 "$TEMPLATE">"$T/$shape";;
    end-only) tail -n 1 "$TEMPLATE">"$T/$shape";;
  esac
  eq "$shape" malformed "$(state "$T/$shape")"
done
cp "$TEMPLATE" "$T/broken-template";sed '1s/BEGIN/BROKEN/' "$T/broken-template">"$T/broken-template.tmp";mv "$T/broken-template.tmp" "$T/broken-template"
if "$STATUS" "$T/broken-template" "$T/current" >/dev/null 2>&1;then echo 'FAIL accepted broken package template' >&2;fail=$((fail+1));else pass=$((pass+1));fi

R="$T/root";mkdir -p "$R/.trackers";git -C "$R" init -q;printf 'before canary\n'>"$R/.trackers/README.md"
"$SETUP" "$R" --workspace .spaces --records-root .records --apply >/dev/null
git -C "$R" add .;git -C "$R" -c user.name=test -c user.email=test@example.invalid commit -qm setup
printf '\nafter canary\n'>>"$R/.trackers/README.md";git -C "$R" add .trackers/README.md;git -C "$R" -c user.name=test -c user.email=test@example.invalid commit -qm prose
sed 's/## Use the tracker tool/## Drifted tracker tool/' "$R/.trackers/README.md">"$T/readme.drift";mv "$T/readme.drift" "$R/.trackers/README.md"
"$SETUP" "$R" --workspace .spaces --records-root .records --apply >/dev/null
eq managed current "$(state "$R/.trackers/README.md")";has "$R/.trackers/README.md" 'before canary';has "$R/.trackers/README.md" 'after canary'
eq marker-count 1 "$(grep -cFx '<!-- backlog:trackers-tool BEGIN -->' "$R/.trackers/README.md")"
for needle in 'current package-owned `tracker@1` tool contract' '`README.md` is this local guide' '`receipts.tsv` is the' 'Git owns history' '`trackers.sh` is the sole writer' 'Direct TSV inspection is allowed' 'never hand-edit' 'stable consumer keys' '`consume` requires a resolution' 'evidence and result references are optional' 'tracker-root-relative `wrote=` paths' '/backlog repair' 'Do not hand-repair' 'do not run the bundled provider';do has "$R/.trackers/README.md" "$needle";done
for cmd in describe catalog page create update observe consume;do has "$R/.trackers/README.md" "./trackers.sh $cmd";done

# Execute each representative command family against the installed adjacent provider.
P="$R/.trackers/trackers.sh";"$P" describe >/dev/null;"$P" catalog >/dev/null;"$P" page --tracker tasks --status open --limit 20 >/dev/null
"$P" create --tracker tasks --text 'README exercise' --evidence doc >/dev/null
"$P" update --tracker tasks --id tasks-1 --text 'README exercise updated' --evidence doc >/dev/null
"$P" observe --consumer example/review --tracker tasks --ids tasks-1 >/dev/null
"$P" consume --consumer example/review --tracker tasks --ids tasks-1 --resolution Resolved --result doc >/dev/null
grep -qF 'README exercise updated' "$R/.trackers/tasks.tsv"&&pass=$((pass+1))||fail=$((fail+1))
[ "$(wc -l <"$R/.trackers/receipts.tsv"|tr -d ' ')" -eq 3 ]&&pass=$((pass+1))||fail=$((fail+1))

echo "readme-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
