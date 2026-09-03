#!/usr/bin/env bash
# Live-source census for Workstream's atomic `.streams` hard cut.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-hard-cut.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

fail_with() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }

for path in \
  skills/workstream/flow.md \
  skills/workstream/scripts/hooks.sh \
  skills/workstream/scripts/workstream-setup.sh \
  skills/workstream/templates/workstream-handoff.md \
  skills/workstream/templates/manifest.md \
  skills/workstream/templates/debrief.md; do
  if [ -e "$ROOT/$path" ]; then fail_with "retired artifact remains: $path"; else pass=$((pass + 1)); fi
done

production="$TMP/production.files"
find "$ROOT/skills/workstream" -type f \( -name '*.md' -o -name '*.sh' \) \
  ! -path '*/scripts/tests/*' -print >"$production"

token_census_clean() { # root token
  local root="$1" token="$2" files="$TMP/census.files"
  find "$root/skills/workstream" -type f \( -name '*.md' -o -name '*.sh' \) \
    ! -path '*/scripts/tests/*' -print >"$files"
  ! xargs grep -nF -- "$token" <"$files" >/dev/null 2>&1
}

for token in '.records/streams' '.spa''ces/workstream' 'after-eventful-ship' 'flow.md' 'workstream-handoff.md' \
  'templates/manifest.md' 'templates/debrief.md'; do
  if ! token_census_clean "$ROOT" "$token"; then
    fail_with "retired production token remains: $token"
  else
    pass=$((pass + 1))
  fi
done

if xargs grep -niE 'callback registry|callback dispatcher|general callback' <"$production" >"$TMP/hits" 2>/dev/null; then
  fail_with 'general Callback machinery remains in Workstream production prose'
else
  pass=$((pass + 1))
fi

# The legacy spelling is legal only in the explicit migration implementation,
# migration procedure, and migration fixture.
legacy_files="$TMP/legacy.files"
rg -l '\.workstreams' "$ROOT/AGENTS.md" "$ROOT/README.md" "$ROOT/PACK.md" \
  "$ROOT/skills" "$ROOT/scripts" "$ROOT/crates/grimoire-pack" \
  --glob '*.md' --glob '*.sh' --glob '*.rs' | sed "s#^$ROOT/##" | sort -u >"$legacy_files" || true
printf '%s\n' \
  'scripts/tests/workstream-hard-cut-contract-test.sh' \
  'skills/workstream/scripts/tests/migration-test.sh' \
  'skills/workstream/scripts/workstream.sh' \
  'skills/workstream/verbs/migrate.md' >"$TMP/legacy.expected"
if cmp -s "$TMP/legacy.expected" "$legacy_files"; then
  pass=$((pass + 1))
else
  fail_with 'legacy .workstreams spelling escaped the migration boundary'
  diff -u "$TMP/legacy.expected" "$legacy_files" >&2 || true
fi

if grep -qF 'never read or edit the TSV directly' "$ROOT/skills/workstream/SKILL.md" &&
   ! rg -n '(^|[^Nn]ever )(read|edit|write|parse)[^.]*(workstream\.tsv|the TSV)' \
      "$ROOT/skills/workstream/SKILL.md" "$ROOT/skills/workstream/verbs" >/dev/null; then
  pass=$((pass + 1))
else
  fail_with 'raw tracker-reading instruction escaped the helper boundary'
fi

if rg -n 'Coordinates `branch:`|isolation: in-place.*Coordinates' \
     "$ROOT/skills/debugger/SKILL.md" "$ROOT/skills/delegate/SKILL.md" \
     "$ROOT/skills/journal/SKILL.md" "$ROOT/skills/notepad/SKILL.md" >/dev/null; then
  fail_with 'retired workstream identity grammar remains in cross-skill custody prose'
else
  pass=$((pass + 1))
fi
mkdir -p "$TMP/custody"
for skill in debugger delegate journal notepad; do cp "$ROOT/skills/$skill/SKILL.md" "$TMP/custody/$skill.md"; done
# Backticks are literal documentation text.
# shellcheck disable=SC2016
printf '%s\n' 'Coordinates `branch:`' >>"$TMP/custody/debugger.md"
if rg -n 'Coordinates `branch:`|isolation: in-place.*Coordinates' "$TMP/custody" >/dev/null; then
  pass=$((pass + 1))
else
  fail_with 'cross-skill custody grammar guard has no live red arm'
fi

# Backticks are literal documentation text.
# shellcheck disable=SC2016
if grep -qF 'revalidates `.streams/STREAM` against the Git worktree registry' \
     "$ROOT/skills/workstream/verbs/close.md" &&
   grep -qF 'Do not delete `.streams` control files' "$ROOT/skills/workstream/verbs/close.md"; then
  pass=$((pass + 1))
else
  fail_with 'close no longer states its exact-target and no-generic-cleanup boundary'
fi

# Red-prove the actual production-token predicate in a disposable package copy.
mkdir -p "$TMP/mutated/skills/workstream"
printf '# clean production fixture\n' >"$TMP/mutated/skills/workstream/SKILL.md"
for token in '.records/streams' '.spa''ces/workstream' 'after-eventful-ship' 'flow.md'; do
  fixture="$TMP/mutated/skills/workstream/SKILL.md"
  cp "$fixture" "$TMP/fixture.before"
  printf '%s\n' "$token" >>"$fixture"
  if token_census_clean "$TMP/mutated" "$token"; then fail_with "production census stayed green after mutation: $token"; else pass=$((pass + 1)); fi
  cp "$TMP/fixture.before" "$fixture"
  if token_census_clean "$TMP/mutated" "$token"; then pass=$((pass + 1)); else fail_with "production census did not recover: $token"; fi
done

echo "workstream-hard-cut-contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
