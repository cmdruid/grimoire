#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; CHECK="$HERE/../operation-check.sh"; GOAL="$HERE/../goal-compile.sh"; WRITE="$HERE/../operation-write.sh"; JOURNAL="$(CDPATH='' cd -P "$HERE/../../../journal/scripts" && pwd)/records.sh"; FIX="$HERE/fixtures/migration/clean-operation.md"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-goal-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
OUT="$T/out"
prepare_root() {
  R="$1"; mkdir -p "$R/.agents/skilldata/foreman/operations"; awk '{print}' "$FIX" >"$R/.agents/skilldata/foreman/operations/release.md"
  "$CHECK" --root "$R" --operation foreman/release >"$OUT"; d="$(fact digest "$OUT")"
  sed -i.bak -e 's/status: draft/status: active/' -e "/^tags:/a\\
verified-against: $d" "$R/.agents/skilldata/foreman/operations/release.md"; rm "$R/.agents/skilldata/foreman/operations/release.md.bak"
}

R="$T/file-root"; prepare_root "$R"
"$GOAL" render --root "$R" --operation foreman/release --objective 'Prepare release' --output "$T/goal-a.md" >"$OUT"
"$GOAL" render --root "$R" --operation foreman/release --objective 'Prepare release' --output "$T/goal-b.md" >/dev/null
ok cmp -s "$T/goal-a.md" "$T/goal-b.md"
for needle in 'doctype: goals' 'schema: foreman/goal@1' 'Source digest: `sha256:' '### `foreman/release`' \
  'Never delegate destructive actions' '/foreman goal resume goals/'; do has "compiled goal $needle" "$needle" "$T/goal-a.md"; done
eq "proven render has no provisional marker" 0 "$(grep -c '^Provisional root:' "$T/goal-a.md" || true)"
proven_digest="$(sed -n -E 's/^- `foreman\/release` — `(sha256:[0-9a-f]{64})`.*/\1/p' "$T/goal-a.md")"
awk -v marker="Provisional root: \`foreman/release@$proven_digest\`" \
  '{print} /^- `foreman\/release`/{print marker}' "$T/goal-a.md" >"$T/proven-with-marker.md"
if "$GOAL" check --root "$R" --input "$T/proven-with-marker.md" >"$OUT"; then
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
has "marker planted on proven draft is refused" 'reason=provisional-marker-on-proven-goal' "$OUT"
body_before="$T/body-before"; awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next}!fm{print}' "$T/goal-a.md" >"$body_before"
"$GOAL" publish --root "$R" --input "$T/goal-a.md" >"$OUT"
eq "file mode" file "$(fact mode "$OUT")"; rel="$(fact path "$OUT")"; has "published status" 'status: published' "$R/.records/$rel"
body_after="$T/body-after"; awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next}!fm{print}' "$R/.records/$rel" >"$body_after"; ok cmp -s "$body_before" "$body_after"
"$GOAL" check --root "$R" --input "$R/.records/$rel" >"$OUT"; eq "proven goal check" false "$(fact provisional "$OUT")"
"$GOAL" publish --root "$R" --input "$T/goal-a.md" >"$OUT"
eq "exact repeat preserves" preserved "$(fact status "$OUT")"; eq "repeat writes zero" 0 "$(fact writes "$OUT")"; ok test ! -e "$R/.agents/skilldata/foreman/runtime"

R2="$T/records-root"; prepare_root "$R2"; mkdir -p "$R2/.records"; cp "$JOURNAL" "$R2/.records/records.sh"; chmod +x "$R2/.records/records.sh"
"$GOAL" render --root "$R2" --operation foreman/release --objective 'Publish release evidence' --output "$T/goal-records.md" >/dev/null
"$GOAL" publish --root "$R2" --input "$T/goal-records.md" >"$OUT"
eq "staged records mode" records "$(fact mode "$OUT")"; has "staged published" 'status: published' "$R2/.records/$(fact path "$OUT")"

# A provisional goal admits exactly one draft Foreman root and keeps every child on the proven lane.
RP="$T/provisional-root"; mkdir -p "$RP"; C="$T/provisional-operation.md"; cp "$FIX" "$C"
record_path='goals/2026-09-02-first-use.md'
"$GOAL" render-provisional --root "$RP" --operation foreman/first-use --candidate "$C" \
  --objective 'Exercise first use' --record-path "$record_path" --output "$T/provisional.md" >"$OUT"
eq "render identifies provisional" yes "$(fact provisional "$OUT")"
has "marker emitted once" 'Provisional root: `foreman/first-use@sha256:' "$T/provisional.md"
eq "one marker" 1 "$(grep -c '^Provisional root:' "$T/provisional.md")"
"$WRITE" put --root "$RP" --identity foreman/first-use --candidate "$C" >/dev/null
"$GOAL" check --root "$RP" --input "$T/provisional.md" >"$OUT"
eq "draft marker accepted" true "$(fact provisional "$OUT")"

sed '/^Provisional root:/d' "$T/provisional.md" >"$T/missing-marker.md"
if "$GOAL" check --root "$RP" --input "$T/missing-marker.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "draft requires marker" 'reason=ineligible-operation' "$OUT"
awk '{print} /^Provisional root:/{print}' "$T/provisional.md" >"$T/duplicate-marker.md"
if "$GOAL" check --root "$RP" --input "$T/duplicate-marker.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "duplicate marker refused" 'reason=duplicate-provisional-marker' "$OUT"
sed 's/@sha256:[0-9a-f]\{64\}/@sha256:0000000000000000000000000000000000000000000000000000000000000000/' "$T/provisional.md" >"$T/mismatch-marker.md"
if "$GOAL" check --root "$RP" --input "$T/mismatch-marker.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "marker digest mismatch" 'reason=provisional-marker-mismatch' "$OUT"
sed 's/Provisional root: `foreman\//Provisional root: `debugger\//' "$T/provisional.md" >"$T/foreign-marker.md"
if "$GOAL" check --root "$RP" --input "$T/foreign-marker.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign marker refused" 'reason=foreign-provisional-root' "$OUT"
marker="$(grep '^Provisional root:' "$T/provisional.md")"
awk -v marker="$marker" '/^Provisional root:/{next} /^## Sources$/{print marker} {print}' "$T/provisional.md" >"$T/misplaced-marker.md"
if "$GOAL" check --root "$RP" --input "$T/misplaced-marker.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "misplaced marker refused" 'reason=misplaced-provisional-marker' "$OUT"
awk -v marker="$marker" '/^Provisional root:/{next} /^- `/{if(!placed){print marker;placed=1}} {print}' "$T/provisional.md" >"$T/early-marker.md"
if "$GOAL" check --root "$RP" --input "$T/early-marker.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "marker must follow source rows" 'reason=misplaced-provisional-marker' "$OUT"

PF="$RP/.agents/skilldata/foreman/operations/first-use.md"
"$CHECK" --root "$RP" --operation foreman/first-use >"$OUT"; pd="$(fact digest "$OUT")"
sed 's/status: draft/status: published/' "$T/provisional.md" >"$T/provisional-published.md"
sed -i.bak -e 's/status: draft/status: active/' -e "/^tags:/a\\
verified-against: $pd" "$PF"; rm "$PF.bak"
"$GOAL" check --root "$RP" --input "$T/provisional-published.md" >"$OUT"; eq "digest-stable promotion remains valid" true "$(fact provisional "$OUT")"
sed -i.bak 's/status: active/status: deprecated/' "$PF"; rm "$PF.bak"
if "$GOAL" check --root "$RP" --input "$T/provisional-published.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "deprecated provisional root refused" 'reason=provisional-root-status' "$OUT"

if "$GOAL" render-provisional --root "$RP" --operation debugger/foreign --candidate "$C" \
  --objective 'Reject foreign root' --record-path goals/2026-09-02-foreign.md --output "$T/foreign-goal.md" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign provisional render refused" 'reason=foreign-provisional-root' "$OUT"

# Red-proof the two new compiler custody guards in a disposable package copy.
BROKEN="$T/broken-skill"; mkdir -p "$BROKEN/scripts" "$BROKEN/templates"
cp "$GOAL" "$BROKEN/scripts/goal-compile.sh"; cp "$CHECK" "$BROKEN/scripts/operation-check.sh"
awk '{print}' "$HERE/../../templates/goal.md" >"$BROKEN/templates/goal.md"; chmod +x "$BROKEN/scripts/"*.sh
cp "$BROKEN/scripts/goal-compile.sh" "$T/compiler.before"
marker_guard='[ "$goal_status" = published ] || die provisional-marker-on-proven-goal'
eq "proven-marker guard target unique" 1 "$(grep -cF "$marker_guard" "$BROKEN/scripts/goal-compile.sh")"
sed -i.bak 's/\[ "$goal_status" = published \] || die provisional-marker-on-proven-goal/: # proven-marker guard disabled/' "$BROKEN/scripts/goal-compile.sh"; rm "$BROKEN/scripts/goal-compile.sh.bak"
if "$BROKEN/scripts/goal-compile.sh" check --root "$R" --input "$T/proven-with-marker.md" >"$OUT"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
eq "disabled proven-marker guard admits forged marker" true "$(fact provisional "$OUT")"
cp "$T/compiler.before" "$BROKEN/scripts/goal-compile.sh"; ok cmp -s "$T/compiler.before" "$BROKEN/scripts/goal-compile.sh"

R3="$T/records-rollover"; prepare_root "$R3"; mkdir -p "$R3/.records"; cp "$JOURNAL" "$R3/.records/records.sh"; chmod +x "$R3/.records/records.sh"
"$BROKEN/scripts/goal-compile.sh" render --root "$R3" --operation foreman/release --objective 'Compiler rollover' --output "$T/rollover-goal.md" >/dev/null
records_guard='[ -z "$record_path" ] || [ "$record_path" = "$engine_path" ] || die records-path-mismatch'
eq "records path guard target unique" 1 "$(grep -cF "$records_guard" "$BROKEN/scripts/goal-compile.sh")"
sed -i.bak 's/\[ -z "$record_path" \] || \[ "$record_path" = "$engine_path" \] || die records-path-mismatch/: # records path guard disabled/' "$BROKEN/scripts/goal-compile.sh"; rm "$BROKEN/scripts/goal-compile.sh.bak"
if "$BROKEN/scripts/goal-compile.sh" publish --root "$R3" --input "$T/rollover-goal.md" \
  --record-path goals/2000-01-01-compiler-rollover.md >"$OUT"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
has "disabled records guard mutates the provider before mismatch" 'reason=staged-path-mismatch' "$OUT"
ok test -f "$R3/.records/goals/$(date +%Y-%m-%d)-compiler-rollover.md"
ok test ! -e "$R3/.records/goals/2000-01-01-compiler-rollover.md"
cp "$T/compiler.before" "$BROKEN/scripts/goal-compile.sh"; ok cmp -s "$T/compiler.before" "$BROKEN/scripts/goal-compile.sh"

# Decision-boundary red-proof: removing the exclusion is observable.
template="$T/template.md"; awk '{print}' "$HERE/../../templates/goal.md" >"$template"; before="$(grep -c 'credential selection' "$template")"; sed -i.bak '/credential selection/d' "$template"; rm "$template.bak"; after="$(grep -c 'credential selection' "$template" || true)"
eq "decision guard mutation target" 1 "$before"; eq "decision guard removal visible" 0 "$after"
report goal-compile-test
