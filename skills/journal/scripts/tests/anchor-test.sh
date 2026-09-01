#!/usr/bin/env bash
# anchor-test.sh — explicit, absent-only records-layer discovery pointer.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

STANDUP="$SKILL/scripts/standup.sh"
ANCHOR="$SKILL/scripts/records-anchor.sh"
SCOPED="$SKILL/scripts/scoped-commit.sh"
POINTER="$SKILL/templates/agents-pointer.md"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-anchor-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

# Guard the ADR's canonical pointer independently from the package template.
EXPECTED_POINTER="$TMP/expected-pointer.md"
printf '%s\n' '## Project records' '' \
  'Durable project decisions, plans, reports, and notes live in `.records/`. Read `.records/README.md` before searching or changing record state; it defines what counts as a record and explains the adjacent lifecycle tool.' \
  >"$EXPECTED_POINTER"
if cmp -s "$EXPECTED_POINTER" "$POINTER"; then pass=$((pass + 1)); else
  echo 'FAIL: records pointer drifted from the canonical prose' >&2; fail=$((fail + 1)); fi
cp "$POINTER" "$TMP/pointer-drift.md"
sed 's/Durable project decisions/Durable project artifacts/' "$TMP/pointer-drift.md" \
  >"$TMP/pointer-drift.tmp"; mv "$TMP/pointer-drift.tmp" "$TMP/pointer-drift.md"
if cmp -s "$EXPECTED_POINTER" "$TMP/pointer-drift.md"; then
  echo 'FAIL: exact pointer guard accepted a prose drift' >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

for verb_text in 'git status --porcelain=v1 -- AGENTS.md' \
  'reason=commit-custody-required detail=AGENTS.md' 'approved destination'; do
  expect "standalone custody contract: $verb_text" "$verb_text" "$SKILL/verbs/anchor.md"
done
expect_absent "anchor does not deny migration's bounded front-door write" \
  'only Journal operation that writes a project front door' "$SKILL/verbs/anchor.md"

new_root() {
  anchor_root="$1"
  mkdir -p "$anchor_root"
  git -C "$anchor_root" init -q
  git -C "$anchor_root" config user.email test@example.com
  git -C "$anchor_root" config user.name Test
  printf 'seed\n' >"$anchor_root/.seed"
  git -C "$anchor_root" add .seed
  git -C "$anchor_root" commit -qm seed
  "$STANDUP" setup "$anchor_root" >"$OUT" 2>"$ERR"
  "$STANDUP" finalize "$anchor_root"
  git -C "$anchor_root" add .records
  git -C "$anchor_root" commit -qm records-layer
}

run_no() {
  rc=0
  "$@" >"$OUT" 2>"$ERR" || rc=$?
  [ "$rc" -eq 2 ] || {
    echo "FAIL: expected rc 2 from: $* (got $rc)" >&2
    fail=$((fail + 1))
    return 1
  }
  pass=$((pass + 1))
}

# A missing front door previews without writing, then creates exactly the
# canonical project-owned prose after explicit confirmation.
missing="$TMP/missing"; new_root "$missing"
head_before="$(git -C "$missing" rev-parse HEAD)"
run_no "$ANCHOR" apply --root "$missing"
expect "apply requires confirmation" 'reason=confirmation-required' "$ERR"
rc=0; "$ANCHOR" preview --root "$missing" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing preview rc" "0" "$rc"
expect "missing preview action" 'action=create' "$OUT"
expect "missing preview path" 'path=AGENTS.md' "$OUT"
expect "missing preview content" 'Read `.records/README.md`' "$OUT"
[ ! -e "$missing/AGENTS.md" ] && pass=$((pass + 1)) || fail=$((fail + 1))
expect_eq "preview preserves HEAD" "$head_before" "$(git -C "$missing" rev-parse HEAD)"
rc=0; "$ANCHOR" apply --root "$missing" --confirmed >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing apply rc" "0" "$rc"
expect "missing apply reports exact path" 'wrote=AGENTS.md' "$OUT"
if cmp -s "$POINTER" "$missing/AGENTS.md"; then pass=$((pass + 1)); else
  echo 'FAIL: missing AGENTS.md does not equal canonical pointer' >&2; fail=$((fail + 1)); fi
expect_absent "pointer has no ownership marker" '<!--' "$missing/AGENTS.md"

# Existing project prose survives. The caller can commit exactly the reported
# front-door path, and a rerun is a clean no-op.
existing="$TMP/existing"; new_root "$existing"
printf '# Existing instructions\n\nKeep this project rule.' >"$existing/AGENTS.md"
git -C "$existing" add AGENTS.md; git -C "$existing" commit -qm front-door
cp "$existing/AGENTS.md" "$TMP/existing.before"
"$ANCHOR" apply --root "$existing" --confirmed >"$OUT" 2>"$ERR"
expect "existing apply reports path" 'wrote=AGENTS.md' "$OUT"
head -c "$(wc -c <"$TMP/existing.before" | tr -d '[:space:]')" "$existing/AGENTS.md" >"$TMP/existing.prefix"
if cmp -s "$TMP/existing.before" "$TMP/existing.prefix"; then pass=$((pass + 1)); else
  echo 'FAIL: existing front-door prefix changed' >&2; fail=$((fail + 1)); fi
"$SCOPED" "$existing" 'Add records layer pointer' AGENTS.md >/dev/null
expect_eq "scoped commit contains only AGENTS" "AGENTS.md" \
  "$(git -C "$existing" diff-tree --no-commit-id --name-only -r HEAD)"
"$ANCHOR" apply --root "$existing" --confirmed >"$OUT" 2>"$ERR"
expect "idempotent rerun is current" 'action=noop' "$OUT"
expect_absent "idempotent rerun reports no write" 'wrote=' "$OUT"
expect_eq "idempotent rerun is clean" "" "$(git -C "$existing" status --porcelain)"

# Any literal guide mention satisfies discovery, while the reserved heading
# without that path refuses instead of creating duplicate project prose.
mentioned="$TMP/mentioned"; new_root "$mentioned"
printf 'See `.records/README.md` for local details.\n' >"$mentioned/AGENTS.md"
git -C "$mentioned" add AGENTS.md; git -C "$mentioned" commit -qm mentioned
"$ANCHOR" preview --root "$mentioned" >"$OUT" 2>"$ERR"
expect "literal mention is a no-op" 'action=noop' "$OUT"
conflict="$TMP/conflict"; new_root "$conflict"
printf '## Project records\n\nDifferent project prose.\n' >"$conflict/AGENTS.md"
git -C "$conflict" add AGENTS.md; git -C "$conflict" commit -qm conflict
run_no "$ANCHOR" preview --root "$conflict"
expect "reserved heading refusal" 'reason=reserved-heading' "$ERR"

# The anchor requires a current initialized layer and a safe canonical root.
absent="$TMP/absent"; mkdir -p "$absent"; git -C "$absent" init -q
git -C "$absent" config user.email test@example.com; git -C "$absent" config user.name Test
printf 'seed\n' >"$absent/.seed"; git -C "$absent" add .seed; git -C "$absent" commit -qm seed
run_no "$ANCHOR" preview --root "$absent"
expect "missing layer refusal" 'reason=setup-required' "$ERR"

for broken in ledger provider readme; do
  broken_root="$TMP/broken-$broken"; new_root "$broken_root"
  case "$broken" in
    ledger) rm "$broken_root/.records/history.tsv" ;;
    provider) printf '# stale\n' >>"$broken_root/.records/records.sh" ;;
    readme) sed -i.bak 's/## Use the records tool/## Stale records tool/' "$broken_root/.records/README.md"; rm "$broken_root/.records/README.md.bak" ;;
  esac
  run_no "$ANCHOR" preview --root "$broken_root"
  case "$broken" in
    ledger) expect "missing ledger requires setup" 'reason=setup-required' "$ERR" ;;
    *) expect "$broken requires repair" 'reason=repair-required' "$ERR" ;;
  esac
done

unsafe="$TMP/unsafe"; new_root "$unsafe"; printf 'outside\n' >"$TMP/outside"
ln -s "$TMP/outside" "$unsafe/AGENTS.md"
run_no "$ANCHOR" preview --root "$unsafe"
expect "symlink front door refusal" 'reason=invalid-target' "$ERR"
run_no "$ANCHOR" preview --root relative
expect "relative root refusal" 'reason=root-not-absolute' "$ERR"

# A project edit after apply's initial classification is preserved and forces
# a complete refusal before the pointer is appended.
race="$TMP/race"; new_root "$race"
printf '# Existing\n' >"$race/AGENTS.md"; git -C "$race" add AGENTS.md; git -C "$race" commit -qm door
race_hook="$TMP/race-hook.sh"
printf '%s\n' '#!/bin/sh' 'printf "CONCURRENT_PROJECT_EDIT\\n" >>"$1/AGENTS.md"' >"$race_hook"
chmod +x "$race_hook"
rc=0
JOURNAL_ANCHOR_TEST_AFTER_PREFLIGHT="$race_hook" \
  "$ANCHOR" apply --root "$race" --confirmed >"$OUT" 2>"$ERR" || rc=$?
expect_eq "concurrent edit refusal rc" "2" "$rc"
expect "concurrent edit refusal" 'reason=concurrent-project-edit detail=AGENTS.md' "$ERR"
expect "concurrent edit survives" 'CONCURRENT_PROJECT_EDIT' "$race/AGENTS.md"
expect_absent "pointer not appended after race" 'Read `.records/README.md`' "$race/AGENTS.md"

# Deletion is also a concurrent edit. It must not turn an existing-file
# preview into permission to create a replacement front door.
deleted="$TMP/deleted"; new_root "$deleted"
printf '# Existing\n' >"$deleted/AGENTS.md"
git -C "$deleted" add AGENTS.md; git -C "$deleted" commit -qm door
delete_hook="$TMP/delete-hook.sh"
printf '%s\n' '#!/bin/sh' 'rm "$1/AGENTS.md"' >"$delete_hook"
chmod +x "$delete_hook"
rc=0
JOURNAL_ANCHOR_TEST_AFTER_PREFLIGHT="$delete_hook" \
  "$ANCHOR" apply --root "$deleted" --confirmed >"$OUT" 2>"$ERR" || rc=$?
expect_eq "concurrent deletion refusal rc" "2" "$rc"
expect "concurrent deletion refusal" 'reason=concurrent-project-edit detail=AGENTS.md' "$ERR"
[ ! -e "$deleted/AGENTS.md" ] && pass=$((pass + 1)) || {
  echo 'FAIL: anchor recreated concurrently deleted AGENTS.md' >&2
  fail=$((fail + 1))
}

# Every non-anchor Journal path remains front-door neutral.
neutral="$TMP/neutral"; new_root "$neutral"
printf '# Neutral front door\n\nJOURNAL_FRONT_DOOR_CANARY\n' >"$neutral/AGENTS.md"
git -C "$neutral" add AGENTS.md; git -C "$neutral" commit -qm neutral-door
cp "$neutral/AGENTS.md" "$TMP/neutral.before"
"$STANDUP" setup "$neutral" >"$OUT" 2>"$ERR"
"$STANDUP" repair "$neutral" >"$OUT" 2>"$ERR"
"$neutral/.records/records.sh" list >"$OUT" 2>"$ERR"
if cmp -s "$TMP/neutral.before" "$neutral/AGENTS.md"; then pass=$((pass + 1)); else
  echo 'FAIL: setup, repair, or provider changed AGENTS.md' >&2; fail=$((fail + 1)); fi

report "anchor-test"
