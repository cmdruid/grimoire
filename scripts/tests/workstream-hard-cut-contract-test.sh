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

custody_paths=(
  AGENTS.md
  skills/checkpoint/SKILL.md
  skills/checkpoint/verbs/save.md
  skills/checkpoint/scripts/save-guard.sh
  skills/debugger/SKILL.md
  skills/delegate/SKILL.md
  skills/delegate/references/codex.md
  skills/journal/SKILL.md
  skills/notepad/SKILL.md
  skills/workstream/templates/compaction-anchor.md
)
if rg -ni 'in-place|inplace_|\.streams/\*/WORKSTREAM' "${custody_paths[@]/#/$ROOT/}" >/dev/null; then
  fail_with 'retired topology remains in active custody paths'
else
  pass=$((pass + 1))
fi

if rg -ni 'checkpoint' "$ROOT/skills/workstream" >/dev/null; then
  fail_with 'Workstream retains a Checkpoint reference'
else
  pass=$((pass + 1))
fi

recovery_anchor_clean() { # file
  local file="$1"
  grep -qF 'read-current' "$file" &&
    ! grep -qF '.streams/*/WORKSTREAM.md' "$file" &&
    ! grep -qiE '^(scan|read|open|cat|parse) .*(raw (runbook|tracker|workstream\.tsv)|\.streams/.*/WORKSTREAM\.md)' "$file"
}
for anchor in "$ROOT/AGENTS.md" "$ROOT/skills/workstream/templates/compaction-anchor.md"; do
  if recovery_anchor_clean "$anchor"; then pass=$((pass + 1)); else fail_with "recovery anchor escaped bounded current-worktree admission: $anchor"; fi
done

cp "$ROOT/skills/workstream/templates/compaction-anchor.md" "$TMP/recovery-mutated.md"
printf '%s\n' 'Scan .streams/*/WORKSTREAM.md for custody.' >>"$TMP/recovery-mutated.md"
expect_count="$(grep -cF '.streams/*/WORKSTREAM.md' "$TMP/recovery-mutated.md")"
if [ "$expect_count" -eq 1 ] && ! recovery_anchor_clean "$TMP/recovery-mutated.md"; then pass=$((pass + 1)); else fail_with 'sibling-scan recovery guard has no counted red arm'; fi
cp "$ROOT/skills/workstream/templates/compaction-anchor.md" "$TMP/recovery-mutated.md"
printf '%s\n' 'Read raw workstream.tsv for recovery.' >>"$TMP/recovery-mutated.md"
expect_count="$(grep -ciF 'Read raw workstream.tsv' "$TMP/recovery-mutated.md")"
if [ "$expect_count" -eq 1 ] && ! recovery_anchor_clean "$TMP/recovery-mutated.md"; then pass=$((pass + 1)); else fail_with 'raw-projection recovery guard has no counted red arm'; fi

mkdir -p "$TMP/workstream-copy"
cp "$ROOT/skills/workstream/SKILL.md" "$TMP/workstream-copy/SKILL.md"
printf '%s\n' 'Checkpoint coupling mutation.' >>"$TMP/workstream-copy/SKILL.md"
if [ "$(rg -ni -c 'checkpoint' "$TMP/workstream-copy/SKILL.md")" -eq 1 ]; then pass=$((pass + 1)); else fail_with 'Workstream cross-reference guard has no counted red arm'; fi
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
if grep -qF 'revalidates the sole `.streams/STREAM` coordinate against the Git worktree registry' \
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
