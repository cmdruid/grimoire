#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; BASE="$(CDPATH='' cd -P "$HERE/../.." && pwd)"; CTX="$HERE/../runtime-context.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-routing-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir "$R"; GOAL='.records/goals/2026-08-26-release.md'; OUT="$T/out"
"$CTX" --root "$R" --goal "$GOAL" >"$OUT"; eq "no owner" none "$(fact owner "$OUT")"; eq "missing recovery warning" unavailable "$(fact recovery "$OUT")"; eq "presence is not admission" none "$(fact checkpoint "$OUT")"
CP="$R/CHECKPOINT.md"
printf 'Goal: %s\nNext: /foreman goal resume %s\n' "$GOAL" "$GOAL" >"$CP"
"$CTX" --root "$R" --goal "$GOAL" >"$OUT"; eq "root file is not auto-admitted" none "$(fact owner "$OUT")"
"$CTX" --root "$R" --goal "$GOAL" --checkpoint "$CP" >"$OUT"; eq "root owner" checkpoint "$(fact owner "$OUT")"
if "$CTX" --root "$R" --goal "$GOAL" --checkpoint "$R/other.md" >"$OUT" 2>&1; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "alternate checkpoint path refused" 'invalid root checkpoint path' "$OUT"
printf 'source: %s\nNext: /foreman goal resume %s\n' "$GOAL" "$GOAL" >"$R/WORKSTREAM.md"
"$CTX" --root "$R" --goal "$GOAL" >"$OUT"; eq "stream owner" workstream "$(fact owner "$OUT")"
if "$CTX" --root "$R" --goal "$GOAL" --checkpoint "$CP" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "dual custody refused" 'reason=dual-runtime-state' "$OUT"

broken="$T/runtime-context.sh"; cp "$CTX" "$broken"; before="$(grep -c '^if \[ "$cp_has".*ws_has' "$broken")"; sed -i.bak 's/if \[ "$cp_has" = true \] && \[ "$ws_has" = true \]; then/if false; then/' "$broken"; rm "$broken.bak"; after="$(grep -c 'if false; then' "$broken")"
eq "state mutation target" 1 "$before"; eq "state guard disabled" 1 "$after"; chmod +x "$broken"
"$broken" --root "$R" --goal "$GOAL" --checkpoint "$CP" >"$OUT"; lacks "disabled guard misses refusal" 'dual-runtime-state' "$OUT"

for needle in 'ordinary `/checkpoint save`' 'never writes `CHECKPOINT.md`' \
  'project-level recovery across a reset is unavailable' 'dual Checkpoint/Workstream custody refuses' \
  'destructive action' 'credential selection' 'verification waiver' 'goal status' 'goal close'; do
  has "goal route $needle" "$needle" "$BASE/verbs/goal.md"
done
eq "resume and status both gate through compiler" 2 "$(grep -c 'scripts/goal-compile.sh check --root <root>' "$BASE/verbs/goal.md")"
resume_check="$(grep -n 'scripts/goal-compile.sh check --root <root>' "$BASE/verbs/goal.md"|sed -n '1s/:.*//p')"
runtime_read="$(grep -n 'Then run `scripts/runtime-context.sh`' "$BASE/verbs/goal.md"|sed -n '1s/:.*//p')"
ok test "$resume_check" -lt "$runtime_read"
for needle in 'source-current draft' 'digest-stably promoted active' 'every child stays goal-eligible' \
  'then and only then report' 'reports drift without reading runtime state'; do
  has "provisional routing $needle" "$needle" "$BASE/verbs/goal.md"
done
for needle in 'git cat-file -e <target>:<path>' 'refuses before stream creation' 'public seed-only procedure' \
  'generic prime helper' 'Load exactly the same stream' 'one queue unit' 'never advance, ship, recycle, or close'; do
  has "stream launch $needle" "$needle" "$BASE/verbs/goal.md"
done

G="$T/git"; mkdir "$G"; git -C "$G" init -q; git -C "$G" config user.name Fixture; git -C "$G" config user.email fixture@example.invalid
mkdir -p "$G/.records/goals" "$G/.agents/skilldata/foreman/operations"; printf 'goal\n' >"$G/.records/goals/committed.md"; printf 'operation\n' >"$G/.agents/skilldata/foreman/operations/committed.md"
git -C "$G" add .records/goals/committed.md .agents/skilldata/foreman/operations/committed.md; git -C "$G" commit -qm seed
if git -C "$G" cat-file -e HEAD:.records/goals/committed.md && git -C "$G" cat-file -e HEAD:.agents/skilldata/foreman/operations/committed.md; then pass=$((pass+1)); else fail=$((fail+1)); fi
printf 'uncommitted\n' >"$G/.records/goals/uncommitted.md"
if git -C "$G" cat-file -e HEAD:.records/goals/uncommitted.md 2>/dev/null; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok test ! -e "$R/.agents/skilldata/foreman/runtime"; ok test ! -e "$R/.records/runtime"
report goal-routing-test
