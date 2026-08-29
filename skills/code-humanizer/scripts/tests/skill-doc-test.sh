#!/usr/bin/env bash
# skill-doc-test.sh — grep gates on the live package. Red-proofs the stop.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

for v in mark map walk; do
  if [ -f "$SKILL/verbs/$v.md" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
  if grep -qF "\`verbs/$v.md\`" "$SKILL/SKILL.md"; then
    pass=$((pass + 1))
  else
    echo "FAIL: SKILL.md does not cite verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

flatten() { tr '\n' ' ' < "$1" | tr -s ' '; }
router="$(flatten "$SKILL/SKILL.md")"
mark="$(flatten "$SKILL/verbs/mark.md")"
map="$(flatten "$SKILL/verbs/map.md")"
walk="$(flatten "$SKILL/verbs/walk.md")"
landmarks="$(flatten "$SKILL/references/landmarks.md")"

expect_match "write-time names names-and-shape" 'Names a human can scan' "$router"
expect_match "write-time forbids extra sweep" 'Do not start a second sweep of the tree' "$router"
expect_match "no-floor records.sh" 'Missing `records.sh` is not an error' "$router"
expect_match "no-floor journal standup" 'Journal standup is never a precondition' "$router"
expect_match "schema is package-owned" 'code-humanizer/map@1' "$router"
expect_match "records home literal" '<agent-records>/maps/' "$router"
expect_match "default cap 20" 'Default cap is 20' "$router"
expect_match "scope script cited" 'scripts/scope.sh' "$router"
expect_match "not-v1 forbids extracts" 'File splits, helper extracts' "$router"
expect_match "edges produce record" 'produces: record' "$router"

expect_match "mark stops before edits" 'Wait for a short go-ahead' "$mark"
expect_match "mark same-breath ban" 'Do not print the summary and edit in the same breath' "$mark"
expect_match "mark no renames" 'no renames, no extracts, no control-flow' "$mark"
expect_match "mark does not commit" 'Do not commit; git is the review' "$mark"
expect_match "mark reads landmarks" 'references/landmarks.md' "$mark"
expect_match "dot is not whole-repo" 'A path of `.` is not that permission' "$mark"

expect_match "map is conversational default" 'lives in the conversation unless the human asks to save' "$map"
expect_match "map stamps revision" 'Built against:' "$map"
expect_match "map verify before trusting" 'Verify before trusting' "$map"
expect_match "map no paste" 'Do not paste function bodies' "$map"

expect_match "walk pauses" 'After the first two or three stops, ask whether to continue' "$walk"
expect_match "walk no mark side-effect" 'Do not mark source as a side effect of a walk' "$walk"

expect_match "landmarks why-not-what" 'Why, not what' "$landmarks"
expect_match "landmarks mark cannot rename" '`mark` may add only the items above. It may not rename' "$landmarks"

# --- red-proof: the stop needle is actually in the file (plant would hit) ---
tmp="$(mktemp -d "${TMPDIR:-/tmp}/code-humanizer-doc.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
planted="$(printf '%s\n' "$mark" | sed 's/Wait for a short go-ahead./Then edit immediately./')"
if [ "$planted" = "$mark" ]; then
  echo "FAIL: stop-phrase plant did not apply (needle missing or drifted)" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
printf '%s\n' "$planted" > "$tmp/mark.planted"
if grep -q 'Wait for a short go-ahead' "$tmp/mark.planted"; then
  echo "FAIL: planted copy still has the stop" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -q 'Wait for a short go-ahead' "$SKILL/verbs/mark.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: live mark.md lost the stop while planting a copy" >&2
  fail=$((fail + 1))
fi

finish
