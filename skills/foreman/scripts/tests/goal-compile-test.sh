#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; CHECK="$HERE/../operation-check.sh"; GOAL="$HERE/../goal-compile.sh"; JOURNAL="$(CDPATH='' cd -P "$HERE/../../../journal/scripts" && pwd)/records.sh"; FIX="$HERE/fixtures/migration/clean-operation.md"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-goal-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
OUT="$T/out"
prepare_root() {
  R="$1"; mkdir -p "$R/.spaces/foreman/operations"; awk '{print}' "$FIX" >"$R/.spaces/foreman/operations/release.md"
  "$CHECK" --root "$R" --workspace .spaces --operation foreman/release >"$OUT"; d="$(fact digest "$OUT")"
  sed -i.bak -e 's/status: draft/status: active/' -e "/^tags:/a\\
verified-against: $d" "$R/.spaces/foreman/operations/release.md"; rm "$R/.spaces/foreman/operations/release.md.bak"
}

R="$T/file-root"; prepare_root "$R"
"$GOAL" render --root "$R" --workspace .spaces --operation foreman/release --objective 'Prepare release' --output "$T/goal-a.md" >"$OUT"
"$GOAL" render --root "$R" --workspace .spaces --operation foreman/release --objective 'Prepare release' --output "$T/goal-b.md" >/dev/null
ok cmp -s "$T/goal-a.md" "$T/goal-b.md"
for needle in 'doctype: goals' 'schema: foreman/goal@1' 'Source digest: `sha256:' '### `foreman/release`' \
  'Never delegate destructive actions' '/foreman goal resume goals/'; do has "compiled goal $needle" "$needle" "$T/goal-a.md"; done
body_before="$T/body-before"; awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next}!fm{print}' "$T/goal-a.md" >"$body_before"
"$GOAL" publish --root "$R" --workspace .spaces --records-root .records --input "$T/goal-a.md" >"$OUT"
eq "file mode" file "$(fact mode "$OUT")"; rel="$(fact path "$OUT")"; has "published status" 'status: published' "$R/.records/$rel"
body_after="$T/body-after"; awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next}!fm{print}' "$R/.records/$rel" >"$body_after"; ok cmp -s "$body_before" "$body_after"
if "$GOAL" publish --root "$R" --workspace .spaces --records-root .records --input "$T/goal-a.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "immutable destination" 'reason=goal-exists' "$OUT"; ok test ! -e "$R/.spaces/foreman/runtime"

R2="$T/records-root"; prepare_root "$R2"; mkdir -p "$R2/.spaces/journal/scripts"; cp "$JOURNAL" "$R2/.spaces/journal/scripts/records.sh"; chmod +x "$R2/.spaces/journal/scripts/records.sh"
"$GOAL" render --root "$R2" --workspace .spaces --operation foreman/release --objective 'Publish release evidence' --output "$T/goal-records.md" >/dev/null
"$GOAL" publish --root "$R2" --workspace .spaces --records-root .records --input "$T/goal-records.md" >"$OUT"
eq "staged records mode" records "$(fact mode "$OUT")"; has "staged published" 'status: published' "$R2/.records/$(fact path "$OUT")"

# Decision-boundary red-proof: removing the exclusion is observable.
template="$T/template.md"; awk '{print}' "$HERE/../../templates/goal.md" >"$template"; before="$(grep -c 'credential selection' "$template")"; sed -i.bak '/credential selection/d' "$template"; rm "$template.bak"; after="$(grep -c 'credential selection' "$template" || true)"
eq "decision guard mutation target" 1 "$before"; eq "decision guard removal visible" 0 "$after"
report goal-compile-test
