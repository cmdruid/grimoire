#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
START="$HERE/../goal-start.sh"; COMPILE="$HERE/../goal-compile.sh"; FIX="$HERE/fixtures/migration/clean-operation.md"
JOURNAL="$(CDPATH='' cd -P "$HERE/../../../journal/scripts" && pwd)/records.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-start-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
render_bundle() { # root identity objective prefix
  "$START" render --root "$1" --identity "$2" --objective "$3" --candidate "$4-candidate.md" \
    --goal-output "$4-goal.md" --manifest-output "$4-manifest" >"$4-render.out"
}
apply_bundle() { # root prefix
  digest="$(fact preview_digest "$2-render.out")"
  "$START" apply --root "$1" --candidate "$2-candidate.md" --goal-input "$2-goal.md" \
    --manifest-input "$2-manifest" --expected-preview-digest "$digest" >"$2-apply.out"
}

R="$T/root"; mkdir -p "$R"; P="$T/main"; cp "$FIX" "$P-candidate.md"
render_bundle "$R" foreman/prepare-release 'Prepare release' "$P"
eq "manifest has four lines" 4 "$(wc -l <"$P-manifest" | tr -d ' ')"
eq "candidate raw hash bound" "$(sha "$P-candidate.md")" "$(sed -n '2s/^operation_sha256=//p' "$P-manifest")"
eq "goal raw hash bound" "$(sha "$P-goal.md")" "$(sed -n '4s/^goal_sha256=//p' "$P-manifest")"
has "provisional marker" 'Provisional root: `foreman/prepare-release@sha256:' "$P-goal.md"
ok test ! -e "$R/.agents/skilldata"; ok test ! -e "$R/.records"
apply_bundle "$R" "$P"
record="$(sed -n '3s/^goal_record=//p' "$P-manifest")"
op="$R/.agents/skilldata/foreman/operations/prepare-release.md"; goal="$R/.records/$record"
ok cmp -s "$P-candidate.md" "$op"; has "goal published" 'status: published' "$goal"
"$COMPILE" check --root "$R" --input "$goal" >"$T/check.out"
eq "published provisional goal valid" true "$(fact provisional "$T/check.out")"
op_before="$(sha "$op")"; goal_before="$(sha "$goal")"
apply_bundle "$R" "$P"
eq "duplicate operation preserved" "$op_before" "$(sha "$op")"; eq "duplicate goal preserved" "$goal_before" "$(sha "$goal")"
eq "duplicate operation reports preserve" preserved "$(fact operation_result "$P-apply.out")"
eq "duplicate goal reports preserve" preserved "$(fact goal_result "$P-apply.out")"
ok test ! -e "$R/CHECKPOINT.md"; ok test ! -e "$R/.agents/skilldata/foreman/runtime"

# Exact partial publication converges by preserving the operation and adding only the goal.
RP="$T/partial-root"; mkdir -p "$RP"; Q="$T/partial"; cp "$FIX" "$Q-candidate.md"
render_bundle "$RP" foreman/partial 'Recover partial publication' "$Q"
mkdir -p "$RP/.agents/skilldata/foreman/operations"; cp "$Q-candidate.md" "$RP/.agents/skilldata/foreman/operations/partial.md"
apply_bundle "$RP" "$Q"
eq "partial operation preserved" preserved "$(fact operation_result "$Q-apply.out")"
eq "partial goal published" published "$(fact goal_result "$Q-apply.out")"

# An interruption after the operation write leaves only the accepted draft; retry converges.
FR="$T/interrupted-root"; mkdir -p "$FR"; F="$T/interrupted"; cp "$FIX" "$F-candidate.md"
render_bundle "$FR" foreman/interrupted 'Recover interrupted publication' "$F"
FHOOK="$T/stop-after-operation.sh"; printf '%s\n' '#!/bin/sh' 'exit 86' >"$FHOOK"; chmod +x "$FHOOK"
if FOREMAN_GOAL_START_TEST_AFTER_OPERATION_WRITE="$FHOOK" apply_bundle "$FR" "$F"; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok cmp -s "$F-candidate.md" "$FR/.agents/skilldata/foreman/operations/interrupted.md"
frel="$(sed -n '3s/^goal_record=//p' "$F-manifest")"; ok test ! -e "$FR/.records/$frel"
apply_bundle "$FR" "$F"
eq "interrupted retry preserves operation" preserved "$(fact operation_result "$F-apply.out")"
eq "interrupted retry publishes goal" published "$(fact goal_result "$F-apply.out")"
ok test -f "$FR/.records/$frel"

# An adjacent records provider remains the preferred same-day publication path.
JR="$T/records-root"; mkdir -p "$JR/.records"; cp "$JOURNAL" "$JR/.records/records.sh"; chmod +x "$JR/.records/records.sh"
J="$T/records"; cp "$FIX" "$J-candidate.md"; render_bundle "$JR" foreman/records 'Publish through records' "$J"; apply_bundle "$JR" "$J"
eq "exact path uses adjacent records provider" records "$(fact goal_mode "$J-apply.out")"
jrel="$(sed -n '3s/^goal_record=//p' "$J-manifest")"; has "records projection published" 'status: published' "$JR/.records/$jrel"
before_records="$(sha "$JR/.records/$jrel")"; apply_bundle "$JR" "$J"
eq "records repeat preserves projection" "$before_records" "$(sha "$JR/.records/$jrel")"
eq "records repeat reports existing" existing "$(fact goal_mode "$J-apply.out")"

# An accepted bundle that crosses a date boundary must not bypass an adjacent records provider.
LR="$T/rollover-root"; mkdir -p "$LR/.records"; cp "$JOURNAL" "$LR/.records/records.sh"; chmod +x "$LR/.records/records.sh"
L="$T/rollover"; cp "$FIX" "$L-candidate.md"; render_bundle "$LR" foreman/rollover 'Cross date boundary' "$L"
rendered_rel="$(sed -n '3s/^goal_record=//p' "$L-manifest")"; stale_rel='goals/2000-01-01-cross-date-boundary.md'
sed -i.bak "s#$rendered_rel#$stale_rel#g" "$L-goal.md"; rm "$L-goal.md.bak"
sed -i.bak -e "s#^goal_record=.*#goal_record=$stale_rel#" \
  -e "s#^goal_sha256=.*#goal_sha256=$(sha "$L-goal.md")#" "$L-manifest"; rm "$L-manifest.bak"
stale_preview="sha256:$(sha "$L-manifest")"
if "$START" apply --root "$LR" --candidate "$L-candidate.md" --goal-input "$L-goal.md" \
  --manifest-input "$L-manifest" --expected-preview-digest "$stale_preview" >"$L-apply.out"; then
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
has "rollover refuses records-provider bypass" 'reason=records-path-mismatch' "$L-apply.out"
ok test ! -e "$LR/.agents/skilldata"
ok test ! -e "$LR/.records/$stale_rel"

# Every accepted preview byte is bound before either project destination is written.
for drift in candidate goal manifest digest; do
  DR="$T/drift-$drift-root"; mkdir -p "$DR"; D="$T/drift-$drift"; cp "$FIX" "$D-candidate.md"
  render_bundle "$DR" foreman/drift-$drift "Reject $drift drift" "$D"
  expected="$(fact preview_digest "$D-render.out")"
  case "$drift" in
    candidate) printf '\nDRIFT\n' >>"$D-candidate.md" ;;
    goal) printf '\nDRIFT\n' >>"$D-goal.md" ;;
    manifest) sed -i.bak 's/^goal_record=.*/goal_record=goals\/2026-09-02-different.md/' "$D-manifest"; rm "$D-manifest.bak" ;;
    digest) expected="sha256:$(printf bad | shasum -a 256 | awk '{print $1}')" ;;
  esac
  if "$START" apply --root "$DR" --candidate "$D-candidate.md" --goal-input "$D-goal.md" \
    --manifest-input "$D-manifest" --expected-preview-digest "$expected" >"$D-refuse.out"; then fail=$((fail+1)); else pass=$((pass+1)); fi
  ok test ! -e "$DR/.agents/skilldata"; ok test ! -e "$DR/.records"
done

# Non-identical incumbents refuse before the other destination can appear.
IR="$T/incumbent-operation"; mkdir -p "$IR"; I="$T/incumbent-op"; cp "$FIX" "$I-candidate.md"
render_bundle "$IR" foreman/incumbent 'Reject operation incumbent' "$I"
mkdir -p "$IR/.agents/skilldata/foreman/operations"; printf 'different\n' >"$IR/.agents/skilldata/foreman/operations/incumbent.md"
if apply_bundle "$IR" "$I"; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok test ! -e "$IR/.records"

GR="$T/incumbent-goal"; mkdir -p "$GR"; G="$T/incumbent-goal"; cp "$FIX" "$G-candidate.md"
render_bundle "$GR" foreman/incumbent-goal 'Reject goal incumbent' "$G"
goal_rel="$(sed -n '3s/^goal_record=//p' "$G-manifest")"; mkdir -p "$GR/.records/${goal_rel%/*}"
printf 'different\n' >"$GR/.records/$goal_rel"
if apply_bundle "$GR" "$G"; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok test ! -e "$GR/.agents/skilldata"

# A race after the first preflight is rechecked before publication.
RR="$T/race-root"; mkdir -p "$RR"; X="$T/race"; cp "$FIX" "$X-candidate.md"
render_bundle "$RR" foreman/race 'Reject preview race' "$X"
HOOK="$T/mutate-candidate.sh"; printf '%s\n' '#!/bin/sh' 'printf "RACE\\n" >>"$1"' >"$HOOK"; chmod +x "$HOOK"
if FOREMAN_GOAL_START_TEST_AFTER_PREFLIGHT="$HOOK" apply_bundle "$RR" "$X"; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok test ! -e "$RR/.agents/skilldata"; ok test ! -e "$RR/.records"

# Red proof: disable exactly the expected-preview guard in a disposable package copy.
BROKEN="$T/broken-skill"; mkdir -p "$BROKEN/scripts" "$BROKEN/templates"
for file in goal-start.sh goal-compile.sh operation-write.sh operation-check.sh; do cp "$HERE/../$file" "$BROKEN/scripts/$file"; done
awk '{print}' "$HERE/../../templates/goal.md" >"$BROKEN/templates/goal.md"; chmod +x "$BROKEN/scripts/"*.sh
cp "$BROKEN/scripts/goal-start.sh" "$T/goal-start.before"
before="$(grep -c '\[ "$computed_preview_digest" = "$expected_preview_digest" \] || die preview-digest-mismatch' "$BROKEN/scripts/goal-start.sh")"
sed -i.bak 's/\[ "$computed_preview_digest" = "$expected_preview_digest" \] || die preview-digest-mismatch/: # preview guard disabled/' "$BROKEN/scripts/goal-start.sh"; rm "$BROKEN/scripts/goal-start.sh.bak"
after="$(grep -c 'preview guard disabled' "$BROKEN/scripts/goal-start.sh")"
eq "preview guard mutation target" 1 "$before"; eq "preview guard disabled once" 1 "$after"
BR="$T/broken-root"; mkdir -p "$BR"; B="$T/broken"; cp "$FIX" "$B-candidate.md"
"$BROKEN/scripts/goal-start.sh" render --root "$BR" --identity foreman/broken --objective 'Witness disabled guard' \
  --candidate "$B-candidate.md" --goal-output "$B-goal.md" --manifest-output "$B-manifest" >"$B-render.out"
wrong="sha256:$(printf wrong | shasum -a 256 | awk '{print $1}')"
if "$BROKEN/scripts/goal-start.sh" apply --root "$BR" --candidate "$B-candidate.md" --goal-input "$B-goal.md" \
  --manifest-input "$B-manifest" --expected-preview-digest "$wrong" >"$B-apply.out"; then pass=$((pass+1)); else fail=$((fail+1)); fi
ok test -f "$BR/.agents/skilldata/foreman/operations/broken.md"
cp "$T/goal-start.before" "$BROKEN/scripts/goal-start.sh"; ok cmp -s "$T/goal-start.before" "$BROKEN/scripts/goal-start.sh"

# Red proof: without the start-side rollover preflight, the operation lands before the compiler
# rejects the stale records-provider path.
rollover_guard='[ "$manifest_goal_record" = "$provider_record" ] || die records-path-mismatch'
eq "rollover preflight target unique" 1 "$(grep -cF "$rollover_guard" "$BROKEN/scripts/goal-start.sh")"
sed -i.bak 's/\[ "$manifest_goal_record" = "$provider_record" \] || die records-path-mismatch/: # rollover preflight disabled/' "$BROKEN/scripts/goal-start.sh"; rm "$BROKEN/scripts/goal-start.sh.bak"
if "$BROKEN/scripts/goal-start.sh" apply --root "$LR" --candidate "$L-candidate.md" --goal-input "$L-goal.md" \
  --manifest-input "$L-manifest" --expected-preview-digest "$stale_preview" >"$T/rollover-broken.out"; then
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
ok test -f "$LR/.agents/skilldata/foreman/operations/rollover.md"
ok test ! -e "$LR/.records/$stale_rel"
cp "$T/goal-start.before" "$BROKEN/scripts/goal-start.sh"; ok cmp -s "$T/goal-start.before" "$BROKEN/scripts/goal-start.sh"

report goal-start-test
