#!/usr/bin/env bash
# setup-transaction-test.sh — durable setup intent, commit custody, and finalization.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-setup-transaction.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

# Exercise a copied package so test-only phase stops never touch the live tree.
FIXTURE_SKILL="$TMP/journal"
mkdir -p "$FIXTURE_SKILL/scripts"
cp "$SKILL/scripts/standup.sh" "$FIXTURE_SKILL/scripts/standup.sh"
cp "$SKILL/scripts/records.sh" "$FIXTURE_SKILL/scripts/records.sh"
chmod +x "$FIXTURE_SKILL/scripts/standup.sh" "$FIXTURE_SKILL/scripts/records.sh"
STANDUP="$FIXTURE_SKILL/scripts/standup.sh"
SCOPED="$SKILL/scripts/scoped-commit.sh"

setup_only() {
  "$STANDUP" setup "$1"
}

finalize_only() {
  "$STANDUP" finalize "$1"
}

writes_of() {
  sed -n 's/^wrote: //p' "$1" | sort -u
}

make_initialized_missing_provider() {
  case_root="$1"
  mkdir -p "$case_root"
  git -C "$case_root" init -q
  git -C "$case_root" config user.name Fixture
  git -C "$case_root" config user.email fixture@example.invalid
  setup_only "$case_root" >"$OUT" 2>"$ERR"
  finalize_only "$case_root"
  git -C "$case_root" add -- .records
  git -C "$case_root" commit -qm 'Initialize records layer'
  rm "$case_root/.records/records.sh"
  git -C "$case_root" add -- .records/records.sh
  git -C "$case_root" commit -qm 'Remove provider for recovery fixture'
}

assert_intent_contract() {
  contract_root="$1"
  contract_intent="$contract_root/.spaces/journal/setup.intent"
  expect "intent schema" "schema=journal/setup-intent@1" "$contract_intent"
  expect "intent project root" "root=$contract_root" "$contract_intent"
  expect "intent records root" "records_root=$contract_root/.records" "$contract_intent"
  expect "intent workspace root" "workspace_root=$contract_root/.spaces" "$contract_intent"
  expect "intent prior provider" \
    "prior_provider=$contract_root/.spaces/journal/scripts/records.sh" "$contract_intent"
}

commit_provider_once() {
  commit_root="$1"
  "$SCOPED" "$commit_root" 'Restore records provider' .records/records.sh >/dev/null
}

exercise_setup_stop() {
  stop_name="$1"; stop_event="$2"
  stop_root="$TMP/$stop_name"
  make_initialized_missing_provider "$stop_root"
  before_count="$(git -C "$stop_root" rev-list --count HEAD)"

  rc=0
  JOURNAL_SETUP_TEST_STOP_AFTER="$stop_event" setup_only "$stop_root" >"$TMP/$stop_name.first" 2>"$ERR" || rc=$?
  expect_eq "$stop_name interruption rc" "86" "$rc"
  [ -f "$stop_root/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
    echo "FAIL: $stop_name did not retain setup intent" >&2; fail=$((fail + 1)); }
  assert_intent_contract "$stop_root"

  rc=0; setup_only "$stop_root" >"$TMP/$stop_name.resume" 2>"$ERR" || rc=$?
  expect_eq "$stop_name resume rc" "0" "$rc"
  expect "$stop_name reaches ready" "phase=ready" "$stop_root/.spaces/journal/setup.intent"
  setup_only "$stop_root" >"$TMP/$stop_name.ready" 2>"$ERR"
  writes_of "$TMP/$stop_name.resume" >"$TMP/$stop_name.resume-writes"
  writes_of "$TMP/$stop_name.ready" >"$TMP/$stop_name.ready-writes"
  if cmp -s "$TMP/$stop_name.resume-writes" "$TMP/$stop_name.ready-writes"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $stop_name ready rerun changed the complete path union" >&2
    fail=$((fail + 1))
  fi
  expect "$stop_name reports provider" ".records/records.sh" "$TMP/$stop_name.ready-writes"

  commit_provider_once "$stop_root"
  setup_only "$stop_root" >"$TMP/$stop_name.after-commit" 2>"$ERR"
  writes_of "$TMP/$stop_name.after-commit" >"$TMP/$stop_name.after-commit-writes"
  if cmp -s "$TMP/$stop_name.ready-writes" "$TMP/$stop_name.after-commit-writes"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $stop_name lost path custody after commit" >&2
    fail=$((fail + 1))
  fi
  finalize_only "$stop_root"
  [ ! -e "$stop_root/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
    echo "FAIL: $stop_name intent remains after finalization" >&2; fail=$((fail + 1)); }
  after_count="$(git -C "$stop_root" rev-list --count HEAD)"
  expect_eq "$stop_name makes one setup commit" "$((before_count + 1))" "$after_count"
  [ -z "$(git -C "$stop_root" status --porcelain)" ] && pass=$((pass + 1)) || {
    echo "FAIL: $stop_name left an outstanding setup change" >&2; fail=$((fail + 1)); }
  [ -z "$(git -C "$stop_root" ls-files -- .spaces/journal/setup.intent)" ] && pass=$((pass + 1)) || {
    echo "FAIL: $stop_name staged or committed the intent" >&2; fail=$((fail + 1)); }
}

exercise_setup_stop after-intent intent
exercise_setup_stop after-provider provider
exercise_setup_stop after-ready ready

exercise_fresh_stop() {
  fresh_event="$1"
  fresh_root="$TMP/fresh-$fresh_event"
  mkdir -p "$fresh_root"
  git -C "$fresh_root" init -q
  git -C "$fresh_root" config user.name Fixture
  git -C "$fresh_root" config user.email fixture@example.invalid
  printf '%s\n' '# Fixture' >"$fresh_root/project.md"
  git -C "$fresh_root" add -- project.md
  git -C "$fresh_root" commit -qm init
  fresh_before="$(git -C "$fresh_root" rev-list --count HEAD)"
  rc=0
  JOURNAL_SETUP_TEST_STOP_AFTER="$fresh_event" setup_only "$fresh_root" \
    >"$TMP/fresh-$fresh_event.first" 2>"$ERR" || rc=$?
  expect_eq "fresh $fresh_event interruption rc" "86" "$rc"
  setup_only "$fresh_root" >"$TMP/fresh-$fresh_event.resume" 2>"$ERR"
  setup_only "$fresh_root" >"$TMP/fresh-$fresh_event.ready" 2>"$ERR"
  writes_of "$TMP/fresh-$fresh_event.resume" >"$TMP/fresh-$fresh_event.resume-writes"
  writes_of "$TMP/fresh-$fresh_event.ready" >"$TMP/fresh-$fresh_event.ready-writes"
  if cmp -s "$TMP/fresh-$fresh_event.resume-writes" "$TMP/fresh-$fresh_event.ready-writes"; then
    pass=$((pass + 1))
  else
    echo "FAIL: fresh $fresh_event resume changed the complete union" >&2; fail=$((fail + 1))
  fi
  for fresh_path in .records/records.sh .records/history.tsv .records/README.md; do
    expect "fresh $fresh_event union includes $fresh_path" "$fresh_path" \
      "$TMP/fresh-$fresh_event.ready-writes"
  done
  "$SCOPED" "$fresh_root" 'Stand up records layer' \
    .records/records.sh .records/history.tsv .records/README.md >/dev/null
  finalize_only "$fresh_root"
  expect_eq "fresh $fresh_event makes one setup commit" "$((fresh_before + 1))" \
    "$(git -C "$fresh_root" rev-list --count HEAD)"
  [ -z "$(git -C "$fresh_root" status --porcelain)" ] && pass=$((pass + 1)) || {
    echo "FAIL: fresh $fresh_event left an outstanding change" >&2; fail=$((fail + 1)); }
}

exercise_fresh_stop ledger
exercise_fresh_stop readme

# Reproduce a process death at the actual destination commit point, before
# post-write bookkeeping can run. The copied helper gains one counted exit
# immediately after the selected durable mutation. Write-ahead custody must
# already name that path, and the unmodified helper must retain it on resume.
exercise_commit_point_crash() {
  crash_name="$1"; crash_needle="$2"; crash_path="$3"
  crash_root="$TMP/commit-point-$crash_name"
  crash_skill="$TMP/commit-point-skill-$crash_name/journal"
  mkdir -p "$crash_root" "$crash_skill/scripts"
  cp "$STANDUP" "$crash_skill/scripts/standup.sh"
  cp "$FIXTURE_SKILL/scripts/records.sh" "$crash_skill/scripts/records.sh"
  if [ "$crash_name" = legacy ]; then
    mkdir -p "$crash_root/.spaces/journal/scripts"
    printf '%s\n' 'prior-provider-commit-point-canary' \
      >"$crash_root/.spaces/journal/scripts/records.sh"
  fi
  expect_eq "$crash_name commit-point target count" "1" \
    "$(grep -Fxc -- "$crash_needle" "$crash_skill/scripts/standup.sh")"
  awk -v needle="$crash_needle" '
    $0 == needle { print; print "  exit 86"; changed++; next }
    { print }
    END { if (changed != 1) exit 1 }
  ' "$crash_skill/scripts/standup.sh" >"$crash_skill/scripts/standup.sh.tmp"
  mv "$crash_skill/scripts/standup.sh.tmp" "$crash_skill/scripts/standup.sh"
  chmod +x "$crash_skill/scripts/standup.sh" "$crash_skill/scripts/records.sh"

  rc=0
  "$crash_skill/scripts/standup.sh" setup "$crash_root" \
 >"$TMP/commit-point-$crash_name.first" 2>"$ERR" || rc=$?
  expect_eq "$crash_name commit-point interruption rc" "86" "$rc"
  expect "$crash_name has write-ahead custody" "pending=$crash_path" \
    "$crash_root/.spaces/journal/setup.intent"

  if [ "$crash_name" = provider ]; then
    mv "$crash_root/.records/records.sh" "$crash_root/provider-held"
    ln -s "$crash_root/provider-held" "$crash_root/.records/records.sh"
    rc=0
    setup_only "$crash_root" >"$TMP/commit-point-provider.refusal" 2>"$ERR" || rc=$?
    expect_eq "pending provider refusal rc" "2" "$rc"
    expect_absent "pending provider is not reported before completion" \
      "wrote: .records/records.sh" "$TMP/commit-point-provider.refusal"
    rm "$crash_root/.records/records.sh"
    mv "$crash_root/provider-held" "$crash_root/.records/records.sh"
  fi

  setup_only "$crash_root" >"$TMP/commit-point-$crash_name.resume" 2>"$ERR"
  expect "$crash_name resume retains path custody" "wrote: $crash_path" \
    "$TMP/commit-point-$crash_name.resume"
  expect "$crash_name promotes completed custody" "completed=$crash_path" \
    "$crash_root/.spaces/journal/setup.intent"
  expect "$crash_name reaches ready after commit-point crash" "phase=ready" \
    "$crash_root/.spaces/journal/setup.intent"
  finalize_only "$crash_root"
}

exercise_commit_point_crash provider '  atomic_install_provider' '.records/records.sh'
exercise_commit_point_crash ledger '  atomic_create_ledger' '.records/history.tsv'
exercise_commit_point_crash readme '  atomic_install_readme' '.records/README.md'
exercise_commit_point_crash legacy '    rm "$legacy"' '.spaces/journal/scripts/records.sh'

# Setup alone owns the exact prior-provider deletion. A tracked deletion stays
# in the scoped commit; an untracked deletion remains reported but has no
# commit-eligible path.
tracked_root="$TMP/tracked-prior"
make_initialized_missing_provider "$tracked_root"
setup_only "$tracked_root" >"$OUT" 2>"$ERR"
commit_provider_once "$tracked_root"
finalize_only "$tracked_root"
mkdir -p "$tracked_root/.spaces/journal/scripts"
cp "$FIXTURE_SKILL/scripts/records.sh" "$tracked_root/.spaces/journal/scripts/records.sh"
chmod +x "$tracked_root/.spaces/journal/scripts/records.sh"
git -C "$tracked_root" add -- .spaces/journal/scripts/records.sh
git -C "$tracked_root" commit -qm 'Track prior provider'
tracked_before="$(git -C "$tracked_root" rev-list --count HEAD)"
rc=0
JOURNAL_SETUP_TEST_STOP_AFTER=legacy setup_only "$tracked_root" >"$TMP/tracked.first" 2>"$ERR" || rc=$?
expect_eq "tracked prior interruption rc" "86" "$rc"
setup_only "$tracked_root" >"$TMP/tracked.resume" 2>"$ERR"
expect "tracked prior deletion reported" ".spaces/journal/scripts/records.sh" "$TMP/tracked.resume"
"$SCOPED" "$tracked_root" 'Remove prior records provider' \
  .spaces/journal/scripts/records.sh >/dev/null
finalize_only "$tracked_root"
expect_eq "tracked prior deletion commits once" "$((tracked_before + 1))" \
  "$(git -C "$tracked_root" rev-list --count HEAD)"

untracked_root="$TMP/untracked-prior"
make_initialized_missing_provider "$untracked_root"
setup_only "$untracked_root" >"$OUT" 2>"$ERR"
commit_provider_once "$untracked_root"
finalize_only "$untracked_root"
mkdir -p "$untracked_root/.spaces/journal/scripts"
cp "$FIXTURE_SKILL/scripts/records.sh" "$untracked_root/.spaces/journal/scripts/records.sh"
untracked_before="$(git -C "$untracked_root" rev-list --count HEAD)"
setup_only "$untracked_root" >"$TMP/untracked.setup" 2>"$ERR"
expect "untracked prior deletion reported" ".spaces/journal/scripts/records.sh" "$TMP/untracked.setup"
if git -C "$untracked_root" ls-files --error-unmatch -- \
  .spaces/journal/scripts/records.sh >/dev/null 2>&1; then
  echo "FAIL: untracked prior fixture unexpectedly became tracked" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
finalize_only "$untracked_root"
expect_eq "untracked prior deletion makes no commit" "$untracked_before" \
  "$(git -C "$untracked_root" rev-list --count HEAD)"

write_guard_intent() {
  guard_root="$1"; guard_schema="${2:-journal/setup-intent@1}"; guard_phase="${3:-applying}"
  mkdir -p "$guard_root/.spaces/journal"
  {
    printf 'schema=%s\n' "$guard_schema"
    printf 'phase=%s\n' "$guard_phase"
    printf 'root=%s\n' "$guard_root"
    printf 'records_root=%s/.records\n' "$guard_root"
    printf 'workspace_root=%s/.spaces\n' "$guard_root"
    printf 'prior_provider=%s/.spaces/journal/scripts/records.sh\n' "$guard_root"
    printf 'pending=\n'
  } >"$guard_root/.spaces/journal/setup.intent"
}

corrupt_guard_intent() {
  guard_name="$1"; guard_root="$2"
  case "$guard_name" in
    duplicate-fixed) printf '%s\n' 'schema=journal/setup-intent@1' >>"$guard_root/.spaces/journal/setup.intent" ;;
    missing-fixed) sed -i.bak '/^phase=/d' "$guard_root/.spaces/journal/setup.intent"; rm "$guard_root/.spaces/journal/setup.intent.bak" ;;
    duplicate-pending) printf '%s\n' 'pending=' >>"$guard_root/.spaces/journal/setup.intent" ;;
    missing-pending) sed -i.bak '/^pending=/d' "$guard_root/.spaces/journal/setup.intent"; rm "$guard_root/.spaces/journal/setup.intent.bak" ;;
    unsupported-pending) sed -i.bak 's#^pending=.*#pending=outside.txt#' "$guard_root/.spaces/journal/setup.intent"; rm "$guard_root/.spaces/journal/setup.intent.bak" ;;
    unsupported-field) printf '%s\n' 'mystery=value' >>"$guard_root/.spaces/journal/setup.intent" ;;
    unsupported-schema) sed -i.bak 's#^schema=.*#schema=journal/setup-intent@99#' "$guard_root/.spaces/journal/setup.intent"; rm "$guard_root/.spaces/journal/setup.intent.bak" ;;
    unsupported-phase) sed -i.bak 's#^phase=.*#phase=paused#' "$guard_root/.spaces/journal/setup.intent"; rm "$guard_root/.spaces/journal/setup.intent.bak" ;;
    conflicting-root) sed -i.bak "s#^records_root=.*#records_root=$guard_root/other#" "$guard_root/.spaces/journal/setup.intent"; rm "$guard_root/.spaces/journal/setup.intent.bak" ;;
    unsupported-path) printf '%s\n' 'completed=outside.txt' >>"$guard_root/.spaces/journal/setup.intent" ;;
    duplicate-path) printf '%s\n' 'completed=.records/records.sh' 'completed=.records/records.sh' >>"$guard_root/.spaces/journal/setup.intent" ;;
    symlink)
      mv "$guard_root/.spaces/journal/setup.intent" "$guard_root/intent-target"
      ln -s "$guard_root/intent-target" "$guard_root/.spaces/journal/setup.intent"
      ;;
  esac
}

guard_case() {
  guard_name="$1"
  guard_root="$TMP/guard-$guard_name"
  make_initialized_missing_provider "$guard_root"
  write_guard_intent "$guard_root"
  corrupt_guard_intent "$guard_name" "$guard_root"
  rc=0; setup_only "$guard_root" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$guard_name intent refusal rc" "2" "$rc"
  [ ! -e "$guard_root/.records/records.sh" ] && pass=$((pass + 1)) || {
    echo "FAIL: $guard_name intent allowed a provider write" >&2; fail=$((fail + 1)); }
}

for guard_name in duplicate-fixed missing-fixed duplicate-pending missing-pending \
  unsupported-pending unsupported-field unsupported-schema unsupported-phase conflicting-root \
  unsupported-path duplicate-path symlink; do
  guard_case "$guard_name"
done

# Red-prove each parser guard by changing exactly its recognizable source line
# in a copied helper. The original negative fixture must have failed above;
# disabling its guard must make that fixture reach the provider write. The
# package source is compared byte-for-byte after every mutation.
cp "$STANDUP" "$TMP/live-standup.before"

mutate_helper_once() {
  mutation_name="$1"; mutation_needle="$2"; mutation_replacement="$3"
  mutation_skill="$TMP/mutation-$mutation_name/journal"
  mkdir -p "$mutation_skill/scripts"
  cp "$STANDUP" "$mutation_skill/scripts/standup.sh"
  cp "$FIXTURE_SKILL/scripts/records.sh" "$mutation_skill/scripts/records.sh"
  mutation_count="$(grep -Fxc -- "$mutation_needle" "$mutation_skill/scripts/standup.sh")"
  expect_eq "$mutation_name mutation target count" "1" "$mutation_count"
  awk -v needle="$mutation_needle" -v replacement="$mutation_replacement" '
    $0 == needle { print replacement; changed++; next }
    { print }
    END { if (changed != 1) exit 1 }
  ' "$mutation_skill/scripts/standup.sh" >"$mutation_skill/scripts/standup.sh.tmp"
  mv "$mutation_skill/scripts/standup.sh.tmp" "$mutation_skill/scripts/standup.sh"
  chmod +x "$mutation_skill/scripts/standup.sh" "$mutation_skill/scripts/records.sh"
  MUTATED_STANDUP="$mutation_skill/scripts/standup.sh"
}

mutation_case() {
  mutation_name="$1"; invalid_case="$2"; mutation_needle="$3"; mutation_replacement="$4"
  second_needle="${5:-}"; second_replacement="${6:-}"
  mutation_root="$TMP/mutation-fixture-$mutation_name"
  make_initialized_missing_provider "$mutation_root"
  write_guard_intent "$mutation_root"
  corrupt_guard_intent "$invalid_case" "$mutation_root"
  if [ "$mutation_name" = duplicate-path ]; then
    sed -i.bak 's#completed=.records/records.sh#completed=.records/README.md#g' \
      "$mutation_root/.spaces/journal/setup.intent"
    rm "$mutation_root/.spaces/journal/setup.intent.bak"
  fi
  mutate_helper_once "$mutation_name" "$mutation_needle" "$mutation_replacement"
  if [ -n "$second_needle" ]; then
    second_count="$(grep -Fxc -- "$second_needle" "$MUTATED_STANDUP")"
    expect_eq "$mutation_name second mutation target count" "1" "$second_count"
    awk -v needle="$second_needle" -v replacement="$second_replacement" '
      $0 == needle { print replacement; changed++; next }
      { print }
      END { if (changed != 1) exit 1 }
    ' "$MUTATED_STANDUP" >"$MUTATED_STANDUP.tmp"
    mv "$MUTATED_STANDUP.tmp" "$MUTATED_STANDUP"
    chmod +x "$MUTATED_STANDUP"
  fi
  rc=0
  "$MUTATED_STANDUP" setup "$mutation_root" \
    >"$OUT" 2>"$ERR" || rc=$?
  if [ "$rc" -eq 0 ] && [ -x "$mutation_root/.records/records.sh" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $mutation_name mutation did not prove its refusal guard" >&2
    fail=$((fail + 1))
  fi
  if cmp -s "$TMP/live-standup.before" "$STANDUP"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $mutation_name mutation changed the live helper" >&2; fail=$((fail + 1))
  fi
}

mutation_case fixed-count duplicate-fixed \
  '    die "setup intent requires exactly one of each fixed field"' '    :'
mutation_case unknown-field unsupported-field \
  '      *) die "unsupported setup intent field: $intent_key" ;;' '      *) : ;;'
mutation_case schema unsupported-schema \
  '  [ "$intent_schema" = "$INTENT_SCHEMA" ] || die "unsupported setup intent schema: $intent_schema"' '  :'
mutation_case phase unsupported-phase \
  '  case "$phase" in applying|ready) ;; *) die "unsupported setup intent phase: $phase" ;; esac' \
  '  case "$phase" in applying|ready|paused) ;; *) die "unsupported setup intent phase: $phase" ;; esac'
mutation_case roots conflicting-root \
  '    die "setup intent conflicts with current roots"' '    :'
mutation_case completed-kind unsupported-path \
  '          die "unsupported completed path in setup intent: $intent_value"' '          :'
mutation_case pending-kind unsupported-pending \
  '    die "unsupported pending path in setup intent: $pending_path"' '    pending_path=""'
mutation_case duplicate-path duplicate-path \
  '  is_completed "$1" && die "duplicate completed path in setup intent: $1"' '  is_completed "$1" && :'
mutation_case intent-symlink symlink \
  '  [ ! -L "$intent" ] && [ -f "$intent" ] || die "unsafe setup intent: $intent"' \
  '  [ -f "$intent" ] || die "unsafe setup intent: $intent"' \
  '  safe_regular_or_absent "$intent" || die "unsafe setup intent during write: $intent"' '  :'

# Simulate interruption after the scoped commit: the ready rerun must retain
# the union, avoid a second commit, and remain finalizable.
commit_root="$TMP/after-commit"
make_initialized_missing_provider "$commit_root"
commit_before="$(git -C "$commit_root" rev-list --count HEAD)"
setup_only "$commit_root" >"$TMP/commit.setup" 2>"$ERR"
commit_provider_once "$commit_root"
setup_only "$commit_root" >"$TMP/commit.resume" 2>"$ERR"
writes_of "$TMP/commit.setup" >"$TMP/commit.setup-writes"
writes_of "$TMP/commit.resume" >"$TMP/commit.resume-writes"
if cmp -s "$TMP/commit.setup-writes" "$TMP/commit.resume-writes"; then
  pass=$((pass + 1))
else
  echo "FAIL: post-commit resume lost the complete union" >&2; fail=$((fail + 1))
fi
expect_eq "post-commit rerun needs no second commit" "$((commit_before + 1))" \
  "$(git -C "$commit_root" rev-list --count HEAD)"
finalize_only "$commit_root"

# A refusal immediately before finalization retains a ready, revalidatable
# intent; a later finalize removes only that file.
final_root="$TMP/before-finalize"
make_initialized_missing_provider "$final_root"
setup_only "$final_root" >"$TMP/final.setup" 2>"$ERR"
commit_provider_once "$final_root"
rc=0
JOURNAL_SETUP_TEST_STOP_AFTER=before-finalize finalize_only "$final_root" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "before-finalize interruption rc" "86" "$rc"
expect "before-finalize retains ready intent" "phase=ready" "$final_root/.spaces/journal/setup.intent"
finalize_only "$final_root"
[ ! -e "$final_root/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
  echo "FAIL: before-finalize rerun retained the intent" >&2; fail=$((fail + 1)); }

# A current layer is a true no-op: no write report and no transaction file.
setup_only "$final_root" >"$OUT" 2>"$ERR"
expect_absent "clean setup reports no writes" "wrote:" "$OUT"
[ ! -e "$final_root/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
  echo "FAIL: clean setup created an intent" >&2; fail=$((fail + 1)); }

report "setup-transaction-test"
