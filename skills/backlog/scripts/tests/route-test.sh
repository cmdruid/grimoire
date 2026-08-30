#!/usr/bin/env bash
# route-test.sh — debrief-anchor classification and bounded mutation fixtures.
set -u

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
STATUS="${BACKLOG_ROUTE_STATUS:-$SKILL/scripts/route-status.sh}"
REGISTER="${BACKLOG_REGISTER_ROUTE:-$SKILL/scripts/register-route.sh}"
TEMPLATE="$SKILL/templates/debrief-anchor.md"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-route-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0

pass_one() { pass=$((pass + 1)); }
fail_one() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }
expect_eq() {
  label="$1"; want="$2"; got="$3"
  if [ "$want" = "$got" ]; then pass_one; else fail_one "$label want=[$want] got=[$got]"; fi
}
expect_line() {
  label="$1"; needle="$2"; file="$3"
  if grep -Fxq -- "$needle" "$file"; then pass_one; else fail_one "$label missing=[$needle]"; fi
}
expect_absent() {
  label="$1"; needle="$2"; file="$3"
  if grep -Fq -- "$needle" "$file"; then fail_one "$label found=[$needle]"; else pass_one; fi
}
run_status() {
  status_script="$1"; target="$2"; output="$3"
  if "$status_script" "$TEMPLATE" "$target" > "$output" 2>&1; then STATUS_RC=0; else STATUS_RC=$?; fi
}
expect_status() {
  label="$1"; target="$2"; want_rc="$3"; want_fact="$4"; output="$T/status.out"
  run_status "$STATUS" "$target" "$output"
  expect_eq "$label exit" "$want_rc" "$STATUS_RC"
  expect_line "$label fact" "$want_fact" "$output"
  if [ "$want_rc" -ne 0 ]; then expect_absent "$label has no extent" 'route_begin_line=' "$output"; fi
}
newroot() { mkdir -p "$1"; git -C "$1" init -q; }

# Exact current and safe replaceable states.
{
  printf '# Project\n\n'
  cat "$TEMPLATE"
  printf '\n## Tail\nkeep-tail\n'
} > "$T/current.md"
expect_status current "$T/current.md" 0 'route_status=current'
expect_line 'current begin line' 'route_begin_line=3' "$T/status.out"

sed 's/Inspect project trackers/Inspect stale project trackers/' "$TEMPLATE" > "$T/drift-block.md"
{
  printf '# Project\n\n'
  cat "$T/drift-block.md"
} > "$T/drifted.md"
expect_status drifted-current "$T/drifted.md" 0 'route_status=drifted-current'

{
  printf '# Prefix\nprefix-byte-canary\n'
  printf '<!-- skill:backlog BEGIN built-against:abc1234 -->\n'
  printf '### /backlog — project follow-up trackers\n'
  printf 'Cadence: old commit-stamped route.\n'
  printf '<!-- skill:backlog END -->\n'
  printf 'suffix-byte-canary\n'
} > "$T/commit-predecessor.md"
expect_status commit-predecessor "$T/commit-predecessor.md" 0 'route_status=replaceable-managed'

{
  printf 'prefix-byte-canary\n'
  printf '<!-- skill:backlog BEGIN opaque-predecessor -->\n'
  printf 'opaque-body-must-not-survive\n'
  printf '<!-- skill:backlog END -->\n'
  printf 'suffix-byte-canary\n'
} > "$T/opaque-predecessor.md"
expect_status opaque-predecessor "$T/opaque-predecessor.md" 0 'route_status=replaceable-managed'

printf '# Project\n' > "$T/absent.md"
expect_status absent "$T/absent.md" 0 'route_status=absent'
expect_status missing "$T/missing.md" 0 'route_status=absent'
expect_line 'missing target fact' 'route_target_missing=true' "$T/status.out"

# Every malformed marker topology refuses without exposing an extent.
{
  cat "$TEMPLATE"
  printf '\n'
  cat "$TEMPLATE"
} > "$T/duplicate.md"
expect_status duplicate "$T/duplicate.md" 1 'route_error=marker-structure'
{
  printf '<!-- skill:backlog BEGIN opaque-a -->\n'
  printf '<!-- skill:backlog BEGIN opaque-b -->\n'
  printf '<!-- skill:backlog END -->\n'
} > "$T/nested.md"
expect_status nested "$T/nested.md" 1 'route_error=marker-structure'
{
  printf '<!-- skill:backlog END -->\n'
  printf '<!-- skill:backlog BEGIN opaque -->\n'
} > "$T/reversed.md"
expect_status reversed "$T/reversed.md" 1 'route_error=marker-order'
printf '<!-- skill:backlog BEGIN opaque -->\n' > "$T/unmatched-begin.md"
expect_status unmatched-begin "$T/unmatched-begin.md" 1 'route_error=marker-structure'
printf '<!-- skill:backlog END -->\n' > "$T/unmatched-end.md"
expect_status unmatched-end "$T/unmatched-end.md" 1 'route_error=marker-structure'
{
  printf '<!-- skill:backlog BEGIN opaque-a -->\n'
  printf '<!-- skill:backlog END -->\n'
  printf '<!-- skill:backlog BEGIN opaque-b -->\n'
  printf '<!-- skill:backlog END -->\n'
} > "$T/overlapping.md"
expect_status overlapping "$T/overlapping.md" 1 'route_error=marker-structure'

# The exact structural H3 is reserved only outside Markdown code.
{
  printf '# Project\n\n'
  printf '### /backlog — project follow-up trackers\n'
} > "$T/unmarked-heading.md"
expect_status unmarked-heading "$T/unmarked-heading.md" 1 'route_error=reserved-heading'
printf '   ### /backlog — project follow-up trackers ###   \n' > "$T/indented-unmarked-heading.md"
expect_status indented-unmarked-heading "$T/indented-unmarked-heading.md" 1 'route_error=reserved-heading'
{
  cat "$TEMPLATE"
  printf '\n### /backlog — project follow-up trackers\n'
} > "$T/managed-plus-heading.md"
expect_status managed-plus-heading "$T/managed-plus-heading.md" 1 'route_error=reserved-heading'
{
  printf '# Project\n\n````markdown\n'
  printf '### /backlog — project follow-up trackers\n'
  printf '```\n### /backlog — project follow-up trackers\n````\n'
  printf '    ### /backlog — project follow-up trackers\n'
  printf '\t### /backlog — project follow-up trackers\n'
} > "$T/code-examples.md"
expect_status code-examples "$T/code-examples.md" 0 'route_status=absent'
{
  printf '# Project\n\n~~~~markdown\n'
  printf '### /backlog — project follow-up trackers\n````\n'
  printf '### /backlog — project follow-up trackers\n~~~~\n'
} > "$T/mixed-fence.md"
expect_status mixed-fence "$T/mixed-fence.md" 0 'route_status=absent'

mkdir "$T/directory-target"
expect_status directory-target "$T/directory-target" 1 'route_error=invalid-target'
printf '# target\n' > "$T/real-target.md"
ln -s real-target.md "$T/symlink-target.md"
expect_status symlink-target "$T/symlink-target.md" 1 'route_error=invalid-target'

# Invalid package templates refuse before target analysis.
cp "$TEMPLATE" "$T/broken-template.md"
sed '1s/debrief-anchor@1/debrief-anchor@2/' "$T/broken-template.md" > "$T/broken-template.tmp"
mv "$T/broken-template.tmp" "$T/broken-template.md"
if "$STATUS" "$T/broken-template.md" "$T/absent.md" > "$T/status.out" 2>&1; then rc=0; else rc=$?; fi
expect_eq 'invalid template exit' 2 "$rc"
expect_line 'invalid template fact' 'route_error=invalid-template' "$T/status.out"

# Ensure replaces only the bounded extent and imports no predecessor content.
R="$T/replace-root";newroot "$R";cp "$T/opaque-predecessor.md" "$R/AGENTS.md"
printf 'prefix-byte-canary\n' > "$T/expected-prefix"
printf 'suffix-byte-canary\n' > "$T/expected-suffix"
if "$REGISTER" ensure --root "$R" > "$T/register.out"; then pass_one; else fail_one 'opaque ensure failed'; fi
expect_line 'opaque ensure reports write' 'wrote=AGENTS.md' "$T/register.out"
expect_absent 'opaque body not imported' 'opaque-body-must-not-survive' "$R/AGENTS.md"
head -n 1 "$R/AGENTS.md" > "$T/actual-prefix"
tail -n 1 "$R/AGENTS.md" > "$T/actual-suffix"
if cmp -s "$T/expected-prefix" "$T/actual-prefix"; then pass_one; else fail_one 'replacement changed prefix'; fi
if cmp -s "$T/expected-suffix" "$T/actual-suffix"; then pass_one; else fail_one 'replacement changed suffix'; fi
sed -n '2,$p' "$R/AGENTS.md" | sed '$d' > "$T/extracted-block"
if cmp -s "$TEMPLATE" "$T/extracted-block"; then pass_one; else fail_one 'replacement is not byte-exact'; fi
cp "$R/AGENTS.md" "$T/current-before"
if "$REGISTER" ensure --root "$R" > "$T/register.out"; then pass_one; else fail_one 'current ensure failed'; fi
if [ ! -s "$T/register.out" ]; then pass_one; else fail_one 'current ensure reported a write'; fi
if cmp -s "$T/current-before" "$R/AGENTS.md"; then pass_one; else fail_one 'current ensure changed bytes'; fi

# Fresh append uses the incumbent routes heading and missing-door creation is valid.
A="$T/append-root";newroot "$A";printf '# Project\n\n## Skill routes (self-registered)\n\nproject-route\n' > "$A/AGENTS.md"
"$REGISTER" ensure --root "$A" > "$T/register.out" || fail_one 'append ensure failed'
expect_eq 'one routes heading' 1 "$(grep -Fxc '## Skill routes (self-registered)' "$A/AGENTS.md")"
expect_eq 'one current begin' 1 "$(grep -Fxc '<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->' "$A/AGENTS.md")"
N="$T/new-root";newroot "$N";"$REGISTER" ensure --root "$N" > "$T/register.out" || fail_one 'missing-door ensure failed'
expect_line 'missing-door heading' '## Skill routes (self-registered)' "$N/AGENTS.md"

# Removal owns only the delimited block and absent removal is a no-op.
cp "$R/AGENTS.md" "$T/remove-before"
"$REGISTER" remove --root "$R" > "$T/register.out" || fail_one 'route remove failed'
expect_line 'remove reports write' 'wrote=AGENTS.md' "$T/register.out"
expect_absent 'remove drops marker' 'skill:backlog' "$R/AGENTS.md"
expect_line 'remove keeps prefix' 'prefix-byte-canary' "$R/AGENTS.md"
expect_line 'remove keeps suffix' 'suffix-byte-canary' "$R/AGENTS.md"
cp "$R/AGENTS.md" "$T/absent-before"
"$REGISTER" remove --root "$R" > "$T/register.out" || fail_one 'absent remove failed'
if [ ! -s "$T/register.out" ] && cmp -s "$T/absent-before" "$R/AGENTS.md"; then pass_one; else fail_one 'absent remove was not a no-op'; fi

# Failure before replacement and a race before rename never install a partial block.
F="$T/failure-root";newroot "$F";cp "$T/commit-predecessor.md" "$F/AGENTS.md";cp "$F/AGENTS.md" "$T/failure-before"
printf '%s\n' '#!/bin/sh' 'exit 86' > "$T/fail-hook.sh";chmod +x "$T/fail-hook.sh"
if BACKLOG_ROUTE_TEST_BEFORE_REPLACE="$T/fail-hook.sh" "$REGISTER" ensure --root "$F" > "$T/register.out" 2>&1; then fail_one 'before-replace failure was accepted'; else pass_one; fi
if cmp -s "$T/failure-before" "$F/AGENTS.md"; then pass_one; else fail_one 'before-replace failure changed target'; fi
"$REGISTER" ensure --root "$F" >/dev/null || fail_one 'clean replacement did not converge'
expect_status converged "$F/AGENTS.md" 0 'route_status=current'

C="$T/race-root";newroot "$C";printf '# Project\n' > "$C/AGENTS.md"
printf '%s\n' '#!/bin/sh' 'printf "race-byte-canary\\n" >> "$2"' > "$T/race-hook.sh";chmod +x "$T/race-hook.sh"
if BACKLOG_ROUTE_TEST_BEFORE_RENAME="$T/race-hook.sh" "$REGISTER" ensure --root "$C" > "$T/register.out" 2>&1; then fail_one 'before-rename race was accepted'; else pass_one; fi
expect_line 'race keeps concurrent byte' 'race-byte-canary' "$C/AGENTS.md"
expect_absent 'race installs no partial anchor' 'skill:backlog' "$C/AGENTS.md"
"$REGISTER" ensure --root "$C" >/dev/null || fail_one 'clean append did not converge after race'
expect_status race-converged "$C/AGENTS.md" 0 'route_status=current'

# Mutation red proofs: every topology/heading guard must demonstrably catch its fixture.
mutate_and_prove() {
  label="$1"; target="$2"; expression="$3"; replacement="$4"
  copied="$T/route-status-$label.sh"
  cp "$STATUS" "$copied"
  count="$(grep -Fxc -- "$expression" "$copied" || true)"
  expect_eq "$label mutation target count" 1 "$count"
  awk -v old="$expression" -v new="$replacement" '{ if ($0 == old) { print new; changed++ } else print } END { if (changed != 1) exit 9 }' "$copied" > "$copied.tmp" || {
    fail_one "$label mutation did not apply exactly once"; return
  }
  mv "$copied.tmp" "$copied";chmod +x "$copied"
  run_status "$copied" "$target" "$T/mutation.out"
  if [ "$STATUS_RC" -eq 0 ]; then pass_one; else fail_one "$label weakened classifier still refused"; fi
  cp "$STATUS" "$copied"
  if cmp -s "$STATUS" "$copied"; then pass_one; else fail_one "$label source copy did not restore byte-exactly"; fi
}

mutate_and_prove unmarked-heading "$T/unmarked-heading.md" \
  '  target_error reserved-heading' \
  '  echo "route_status=absent"; exit 0'
mutate_and_prove marker-order "$T/reversed.md" \
  '[ "$begin_line" -lt "$end_line" ] || target_error marker-order' \
  ': # weakened marker-order guard'
mutate_and_prove outside-heading "$T/managed-plus-heading.md" \
  '[ "$outside_headings" -eq 0 ] || target_error reserved-heading' \
  ': # weakened outside-heading guard'

# Duplicate detection needs both line collectors bounded; count both edits before applying them.
cp "$STATUS" "$T/route-status-marker-structure.sh"
for expression in \
  'begin_lines="$(grep -n '\''^<!-- skill:backlog BEGIN'\'' "$front_door" | cut -d: -f1 || true)"' \
  'end_lines="$(grep -Fn "$end_marker" "$front_door" | cut -d: -f1 || true)"' \
  'if [ "$begins" -ne 1 ] || [ "$ends" -ne 1 ]; then target_error marker-structure; fi'; do
  count="$(grep -Fxc -- "$expression" "$T/route-status-marker-structure.sh" || true)"
  expect_eq 'marker-structure mutation target count' 1 "$count"
done
sed \
  -e 's/| cut -d: -f1 || true)/| cut -d: -f1 | head -n 1 || true)/' \
  -e 's/if \[ "$begins" -ne 1 \] || \[ "$ends" -ne 1 \]; then target_error marker-structure; fi/: # weakened marker-structure guard/' \
  "$T/route-status-marker-structure.sh" > "$T/route-status-marker-structure.tmp"
mv "$T/route-status-marker-structure.tmp" "$T/route-status-marker-structure.sh";chmod +x "$T/route-status-marker-structure.sh"
run_status "$T/route-status-marker-structure.sh" "$T/overlapping.md" "$T/mutation.out"
if [ "$STATUS_RC" -eq 0 ]; then pass_one; else fail_one 'weakened marker-structure classifier still refused'; fi
cp "$STATUS" "$T/route-status-marker-structure.sh"
if cmp -s "$STATUS" "$T/route-status-marker-structure.sh"; then pass_one; else fail_one 'marker-structure source copy did not restore'; fi

echo "route-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
