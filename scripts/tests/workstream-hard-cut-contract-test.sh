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

production=()
while IFS= read -r -d '' path; do production+=("$path"); done < <(
  find "$ROOT/skills/workstream" -type f \( -name '*.md' -o -name '*.sh' \) \
    ! -path '*/scripts/tests/*' -print0
)

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
custody_files=()
for path in "${custody_paths[@]}"; do custody_files+=("$ROOT/$path"); done

printf '%s\n' 'workstream-hard-cut population:'
printf '  %s\n' "${production[@]}" "${custody_files[@]}"

rg_absent() {
  local rc=0
  rg "$@" >"$TMP/rg.out" 2>"$TMP/rg.err" || rc=$?
  case "$rc" in
    0) return 1 ;;
    1) return 0 ;;
    *) cat "$TMP/rg.err" >&2; return "$rc" ;;
  esac
}

rg_present() {
  local rc=0
  rg "$@" >"$TMP/rg.out" 2>"$TMP/rg.err" || rc=$?
  case "$rc" in
    0) return 0 ;;
    1) return 1 ;;
    *) cat "$TMP/rg.err" >&2; return "$rc" ;;
  esac
}

token_census_clean() { # root token
  local root="$1" token="$2" path
  local files=()
  while IFS= read -r -d '' path; do files+=("$path"); done < <(
    find "$root/skills/workstream" -type f \( -name '*.md' -o -name '*.sh' \) \
      ! -path '*/scripts/tests/*' -print0
  )
  rg_absent -nF -- "$token" "${files[@]}"
}

for token in '.records/streams' '.spa''ces/workstream' 'after-eventful-ship' 'flow.md' 'workstream-handoff.md' \
  'templates/manifest.md' 'templates/debrief.md'; do
  if ! token_census_clean "$ROOT" "$token"; then
    fail_with "retired production token remains: $token"
  else
    pass=$((pass + 1))
  fi
done

if rg_absent -ni 'callback registry|callback dispatcher|general callback' "${production[@]}"; then
  pass=$((pass + 1))
else
  fail_with 'general Callback machinery remains in Workstream production prose or its census failed'
fi

retired_topology_pattern='\.workstreams|ALLOW_PARKED|inplace_|--in-place|isolation[[:space:]:]+(worktree|in-place)|(^|[^[:alnum:]_-])(park(ed|ing)?|unpark)([^[:alnum:]_-]|$)'
retired_current_topology_clean() { rg_absent -ni "$retired_topology_pattern" "$@"; }
retired_current_topology_present() { rg_present -ni "$retired_topology_pattern" "$@"; }

current_production=()
for path in "${production[@]}"; do
  case "$path" in
    "$ROOT/skills/workstream/scripts/workstream-migrate.sh"|"$ROOT/skills/workstream/verbs/migrate.md") ;;
    *) current_production+=("$path") ;;
  esac
done
if retired_current_topology_clean "${current_production[@]}"; then
  pass=$((pass + 1))
else
  fail_with 'retired topology remains in the current Workstream surface or its census failed'
fi
set +e
retired_current_topology_clean "$TMP/missing-active-source.md" >/dev/null 2>&1
census_rc=$?
set -e
if [ "$census_rc" -gt 1 ]; then
  pass=$((pass + 1))
else
  fail_with 'retired topology census treated an inspection error as clean'
fi

# The legacy spelling is legal only in the migration procedure, package helper,
# migration fixture, and this source guard.
legacy_files_for_root() { # root output
  local root="$1" output="$2" raw="$2.raw" rc=0
  rg -l '\.workstreams' "$root/AGENTS.md" "$root/README.md" "$root/PACK.md" \
    "$root/skills" "$root/scripts" "$root/crates/grimoire-pack" \
    --glob '*.md' --glob '*.sh' --glob '*.rs' >"$raw" 2>"$TMP/rg.err" || rc=$?
  case "$rc" in
    0|1) ;;
    *) cat "$TMP/rg.err" >&2; rm -f "$raw"; return "$rc" ;;
  esac
  sed "s#^$root/##" "$raw" | LC_ALL=C sort -u >"$output"
  rm -f "$raw"
}

legacy_files="$TMP/legacy.files"
if ! legacy_files_for_root "$ROOT" "$legacy_files"; then
  fail_with 'legacy allowlist census failed'
  : >"$legacy_files"
fi
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
if ! legacy_files_for_root "$TMP/legacy-copy" "$TMP/legacy-copy.clean"; then fail_with 'disposable legacy allowlist census failed'; fi
if cmp -s "$TMP/legacy.expected" "$TMP/legacy-copy.clean"; then pass=$((pass + 1)); else fail_with 'disposable legacy allowlist fixture is not initially clean'; fi
printf '# disallowed .workstreams runtime probe\n' >"$TMP/legacy-copy/skills/workstream/scripts/workstream.sh"
if ! legacy_files_for_root "$TMP/legacy-copy" "$TMP/legacy-copy.mutated"; then fail_with 'mutated legacy allowlist census failed'; fi
if cmp -s "$TMP/legacy.expected" "$TMP/legacy-copy.mutated"; then fail_with 'legacy allowlist stayed green after runtime mutation'; else pass=$((pass + 1)); fi
rm "$TMP/legacy-copy/skills/workstream/scripts/workstream.sh"
if ! legacy_files_for_root "$TMP/legacy-copy" "$TMP/legacy-copy.restored"; then fail_with 'restored legacy allowlist census failed'; fi
if cmp -s "$TMP/legacy.expected" "$TMP/legacy-copy.restored" && cmp -s "$TMP/legacy-copy.clean" "$TMP/legacy-copy.restored"; then
  pass=$((pass + 1))
else
  fail_with 'legacy allowlist did not restore byte-exactly after mutation'
fi

# Generated controls and one generated runtime worktree obey the same hard cut.
generated="$TMP/generated project"
mkdir -p "$generated"; git -C "$generated" init -q
git -C "$generated" config user.name Fixture; git -C "$generated" config user.email fixture@example.invalid
printf 'seed\n' >"$generated/file"; git -C "$generated" add file; git -C "$generated" commit -qm seed
git -C "$generated" branch -M main
"$ROOT/skills/workstream/scripts/workstream.sh" "$generated" setup >/dev/null
"$generated/.streams/workstream.sh" "$generated" runtime-init generated main generated >/dev/null
generated_files=()
while IFS= read -r -d '' path; do generated_files+=("$path"); done < <(find "$generated/.streams" -type f -print0)
printf '%s\n' 'workstream-hard-cut generated population:'
printf '  %s\n' "${generated_files[@]}"
if retired_current_topology_clean "${generated_files[@]}"; then pass=$((pass + 1)); else fail_with 'generated control surface contains retired topology or its census failed'; fi

fixture="$generated/.streams/generated/WORKSTREAM.md"
for mutation in '.workstreams' 'ALLOW_PARKED' 'inplace_' '--in-place' 'isolation: worktree' 'park' 'parked' 'parking' 'unpark'; do
  cp "$fixture" "$TMP/generated.before"
  printf '%s\n' "$mutation" >>"$fixture"
  if [ "$(grep -cF -- "$mutation" "$fixture")" -eq 1 ] && retired_current_topology_present "$fixture"; then
    pass=$((pass + 1))
  else
    fail_with "generated topology guard stayed green after mutation: $mutation"
  fi
  cp "$TMP/generated.before" "$fixture"
  if cmp -s "$TMP/generated.before" "$fixture" && retired_current_topology_clean "$fixture"; then
    pass=$((pass + 1))
  else
    fail_with "generated topology guard did not restore after mutation: $mutation"
  fi
done

if grep -qF 'never read or edit the TSV directly' "$ROOT/skills/workstream/SKILL.md" &&
   rg_absent -n '(^|[^Nn]ever )(read|edit|write|parse)[^.]*(workstream\.tsv|the TSV)' \
      "$ROOT/skills/workstream/SKILL.md" "$ROOT/skills/workstream/verbs"; then
  pass=$((pass + 1))
else
  fail_with 'raw tracker-reading instruction escaped the helper boundary or its census failed'
fi

# Backticks are literal documentation text.
# shellcheck disable=SC2016
cross_skill_topology_pattern='Coordinates `branch:`|isolation: in-place.*Coordinates'
cross_skill_topology_clean() { rg_absent -n "$cross_skill_topology_pattern" "$@"; }
cross_skill_topology_present() { rg_present -n "$cross_skill_topology_pattern" "$@"; }
if ! cross_skill_topology_clean \
     "$ROOT/skills/debugger/SKILL.md" "$ROOT/skills/delegate/SKILL.md" \
     "$ROOT/skills/journal/SKILL.md" "$ROOT/skills/notepad/SKILL.md"; then
  fail_with 'retired workstream identity grammar remains in cross-skill custody prose'
else
  pass=$((pass + 1))
fi

custody_topology_pattern='in-place|inplace_|\.streams/\*/WORKSTREAM'
custody_topology_clean() { rg_absent -ni "$custody_topology_pattern" "$@"; }
custody_topology_present() { rg_present -ni "$custody_topology_pattern" "$@"; }
if ! custody_topology_clean "${custody_files[@]}"; then
  fail_with 'retired topology remains in active custody paths or its census failed'
else
  pass=$((pass + 1))
fi

if rg_absent -ni 'checkpoint' "$ROOT/skills/workstream"; then
  pass=$((pass + 1))
else
  fail_with 'Workstream retains a Checkpoint reference or its census failed'
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
  if [ "$(grep -cF "$mutation" "$TMP/custody/debugger.md")" -eq 1 ] && cross_skill_topology_present "$TMP/custody/debugger.md"; then
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
  if [ "$(grep -cF "$mutation" "$TMP/custody-topology.md")" -eq 1 ] && custody_topology_present "$TMP/custody-topology.md"; then
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
  if rg_present -nF -- "$token" "$fixture"; then pass=$((pass + 1)); else fail_with "production census did not detect mutation: $token"; fi
  cp "$TMP/fixture.before" "$fixture"
  if token_census_clean "$TMP/mutated" "$token"; then pass=$((pass + 1)); else fail_with "production census did not recover: $token"; fi
done

echo "workstream-hard-cut-contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
