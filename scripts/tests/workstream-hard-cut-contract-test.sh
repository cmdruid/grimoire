#!/usr/bin/env bash
# Live-source census for Workstream's atomic `.streams` hard cut.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-hard-cut.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
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

retired_current_topology_clean() { # newline-delimited file list
  ! xargs rg -ni '\.workstreams|ALLOW_PARKED|inplace_|--in-place|isolation[[:space:]:]+(worktree|in-place)|(^|[^[:alnum:]_-])(park(ed|ing)?|unpark)([^[:alnum:]_-]|$)' <"$1" >/dev/null 2>&1
}

grep -vE '/scripts/workstream-migrate\.sh$|/verbs/migrate\.md$' "$production" >"$TMP/current-production.files"
if retired_current_topology_clean "$TMP/current-production.files"; then
  pass=$((pass + 1))
else
  fail_with 'retired topology remains in the current Workstream surface'
fi

# The legacy spelling is legal only in the migration procedure, package helper,
# migration fixture, and this source guard.
legacy_files_for_root() { # root output
  local root="$1" output="$2"
  rg -l '\.workstreams' "$root/AGENTS.md" "$root/README.md" "$root/PACK.md" \
    "$root/skills" "$root/scripts" "$root/crates/grimoire-pack" \
    --glob '*.md' --glob '*.sh' --glob '*.rs' 2>/dev/null |
    sed "s#^$root/##" | LC_ALL=C sort -u >"$output" || true
}

legacy_files="$TMP/legacy.files"
legacy_files_for_root "$ROOT" "$legacy_files"
printf '%s\n' \
  'scripts/tests/workstream-hard-cut-contract-test.sh' \
  'skills/workstream/scripts/tests/migration-test.sh' \
  'skills/workstream/scripts/workstream-migrate.sh' \
  'skills/workstream/verbs/migrate.md' >"$TMP/legacy.expected"
if cmp -s "$TMP/legacy.expected" "$legacy_files"; then
  pass=$((pass + 1))
else
  fail_with 'legacy .workstreams spelling escaped the migration boundary'
  diff -u "$TMP/legacy.expected" "$legacy_files" >&2 || true
fi

# Red-prove the exact allowlist in a disposable source tree, then restore bytes.
mkdir -p "$TMP/legacy-copy/skills/workstream/scripts/tests" \
  "$TMP/legacy-copy/skills/workstream/verbs" "$TMP/legacy-copy/scripts/tests" \
  "$TMP/legacy-copy/crates/grimoire-pack"
touch "$TMP/legacy-copy/AGENTS.md" "$TMP/legacy-copy/README.md" "$TMP/legacy-copy/PACK.md"
for path in \
  scripts/tests/workstream-hard-cut-contract-test.sh \
  skills/workstream/scripts/tests/migration-test.sh \
  skills/workstream/scripts/workstream-migrate.sh \
  skills/workstream/verbs/migrate.md; do
  cp "$ROOT/$path" "$TMP/legacy-copy/$path"
done
legacy_files_for_root "$TMP/legacy-copy" "$TMP/legacy-copy.clean"
if cmp -s "$TMP/legacy.expected" "$TMP/legacy-copy.clean"; then pass=$((pass + 1)); else fail_with 'disposable legacy allowlist fixture is not initially clean'; fi
printf '# disallowed .workstreams runtime probe\n' >"$TMP/legacy-copy/skills/workstream/scripts/workstream.sh"
legacy_files_for_root "$TMP/legacy-copy" "$TMP/legacy-copy.mutated"
if cmp -s "$TMP/legacy.expected" "$TMP/legacy-copy.mutated"; then fail_with 'legacy allowlist stayed green after runtime mutation'; else pass=$((pass + 1)); fi
rm "$TMP/legacy-copy/skills/workstream/scripts/workstream.sh"
legacy_files_for_root "$TMP/legacy-copy" "$TMP/legacy-copy.restored"
if cmp -s "$TMP/legacy.expected" "$TMP/legacy-copy.restored" && cmp -s "$TMP/legacy-copy.clean" "$TMP/legacy-copy.restored"; then
  pass=$((pass + 1))
else
  fail_with 'legacy allowlist did not restore byte-exactly after mutation'
fi

# Generated controls and one generated runtime worktree obey the same hard cut.
generated="$TMP/generated-project"
mkdir -p "$generated"; git -C "$generated" init -q
git -C "$generated" config user.name Fixture; git -C "$generated" config user.email fixture@example.invalid
printf 'seed\n' >"$generated/file"; git -C "$generated" add file; git -C "$generated" commit -qm seed
git -C "$generated" branch -M main
"$ROOT/skills/workstream/scripts/workstream.sh" "$generated" setup >/dev/null
"$generated/.streams/workstream.sh" "$generated" runtime-init generated main generated >/dev/null
find "$generated/.streams" -type f -print | LC_ALL=C sort >"$TMP/generated.files"
if retired_current_topology_clean "$TMP/generated.files"; then pass=$((pass + 1)); else fail_with 'generated control surface contains retired topology'; fi

fixture="$generated/.streams/generated/WORKSTREAM.md"
printf '%s\n' "$fixture" >"$TMP/generated-mutation.files"
for mutation in '.workstreams' 'ALLOW_PARKED' 'inplace_' '--in-place' 'isolation: worktree' 'park' 'parked' 'parking' 'unpark'; do
  cp "$fixture" "$TMP/generated.before"
  printf '%s\n' "$mutation" >>"$fixture"
  if [ "$(grep -cF -- "$mutation" "$fixture")" -eq 1 ] && ! retired_current_topology_clean "$TMP/generated-mutation.files"; then
    pass=$((pass + 1))
  else
    fail_with "generated topology guard stayed green after mutation: $mutation"
  fi
  cp "$TMP/generated.before" "$fixture"
  if cmp -s "$TMP/generated.before" "$fixture" && retired_current_topology_clean "$TMP/generated-mutation.files"; then
    pass=$((pass + 1))
  else
    fail_with "generated topology guard did not restore after mutation: $mutation"
  fi
done

if grep -qF 'never read or edit the TSV directly' "$ROOT/skills/workstream/SKILL.md" &&
   ! rg -n '(^|[^Nn]ever )(read|edit|write|parse)[^.]*(workstream\.tsv|the TSV)' \
      "$ROOT/skills/workstream/SKILL.md" "$ROOT/skills/workstream/verbs" >/dev/null; then
  pass=$((pass + 1))
else
  fail_with 'raw tracker-reading instruction escaped the helper boundary'
fi

cross_skill_topology_clean() {
  ! rg -n 'Coordinates `branch:`|isolation: in-place.*Coordinates' "$@" >/dev/null
}
if ! cross_skill_topology_clean \
     "$ROOT/skills/debugger/SKILL.md" "$ROOT/skills/delegate/SKILL.md" \
     "$ROOT/skills/journal/SKILL.md" "$ROOT/skills/notepad/SKILL.md"; then
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
custody_topology_clean() { ! rg -ni 'in-place|inplace_|\.streams/\*/WORKSTREAM' "$@" >/dev/null; }
if ! custody_topology_clean "${custody_paths[@]/#/$ROOT/}"; then
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
for mutation in 'Coordinates `branch:`' 'isolation: in-place Coordinates'; do
  cp "$TMP/custody/debugger.md" "$TMP/custody.before"
  printf '%s\n' "$mutation" >>"$TMP/custody/debugger.md"
  if [ "$(grep -cF "$mutation" "$TMP/custody/debugger.md")" -eq 1 ] && ! cross_skill_topology_clean "$TMP/custody/debugger.md"; then
    pass=$((pass + 1))
  else
    fail_with "cross-skill topology guard stayed green after mutation: $mutation"
  fi
  cp "$TMP/custody.before" "$TMP/custody/debugger.md"
  if cmp -s "$TMP/custody.before" "$TMP/custody/debugger.md" && cross_skill_topology_clean "$TMP/custody/debugger.md"; then
    pass=$((pass + 1))
  else
    fail_with "cross-skill topology guard did not restore after mutation: $mutation"
  fi
done

cp "$ROOT/skills/workstream/templates/compaction-anchor.md" "$TMP/custody-topology.md"
for mutation in 'in-place' 'inplace_' '.streams/*/WORKSTREAM'; do
  cp "$TMP/custody-topology.md" "$TMP/custody-topology.before"
  printf '%s\n' "$mutation" >>"$TMP/custody-topology.md"
  if [ "$(grep -cF "$mutation" "$TMP/custody-topology.md")" -eq 1 ] && ! custody_topology_clean "$TMP/custody-topology.md"; then
    pass=$((pass + 1))
  else
    fail_with "custody topology guard stayed green after mutation: $mutation"
  fi
  cp "$TMP/custody-topology.before" "$TMP/custody-topology.md"
  if cmp -s "$TMP/custody-topology.before" "$TMP/custody-topology.md" && custody_topology_clean "$TMP/custody-topology.md"; then
    pass=$((pass + 1))
  else
    fail_with "custody topology guard did not restore after mutation: $mutation"
  fi
done

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
