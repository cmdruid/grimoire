#!/usr/bin/env bash
# anchor-test.sh — explicit, absent-only tracker-layer discovery pointer.
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh"
ANCHOR="$SKILL/scripts/trackers-anchor.sh"
SCOPED="$SKILL/scripts/scoped-commit.sh"
POINTER="$SKILL/templates/agents-pointer.md"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/backlog-anchor-test.XXXXXX")";trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out";ERR="$TMP/err";pass=0;fail=0

has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing [$2] in $1" >&2;fail=$((fail+1));fi;}
absent(){ if grep -qF -- "$2" "$1";then echo "FAIL unexpected [$2] in $1" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}
no(){ rc=0;"$@">"$OUT" 2>"$ERR"||rc=$?;if [ "$rc" -eq 2 ];then pass=$((pass+1));else echo "FAIL expected rc=2 got=$rc: $*" >&2;fail=$((fail+1));fi;}

EXPECTED_POINTER="$TMP/expected-pointer.md"
printf '%s\n' '## Project trackers' '' \
  'Actionable project follow-ups live in `.trackers/`, with queue tables for current items and lifecycle history for observations and resolutions. Read `.trackers/README.md` before inspecting or changing tracker state; it explains the local contract and adjacent tracker tool.' \
  >"$EXPECTED_POINTER"
if cmp -s "$EXPECTED_POINTER" "$POINTER";then pass=$((pass+1));else
  echo 'FAIL tracker pointer prose drifted' >&2;fail=$((fail+1));fi
cp "$POINTER" "$TMP/pointer-drift.md"
sed 's/Actionable project follow-ups/Project follow-ups/' "$TMP/pointer-drift.md">"$TMP/pointer-drift.tmp"
mv "$TMP/pointer-drift.tmp" "$TMP/pointer-drift.md"
if cmp -s "$EXPECTED_POINTER" "$TMP/pointer-drift.md";then
  echo 'FAIL exact pointer guard accepted drift' >&2;fail=$((fail+1))
else pass=$((pass+1));fi
for verb_text in 'git status --porcelain=v1 -- AGENTS.md' \
  'reason=commit-custody-required detail=AGENTS.md' 'approved destination';do
  has "$SKILL/verbs/anchor.md" "$verb_text"
done

new_root(){
  local root="$1"
  mkdir -p "$root";git -C "$root" init -q
  git -C "$root" config user.name Test;git -C "$root" config user.email test@example.com
  printf 'seed\n'>"$root/.seed";git -C "$root" add .seed;git -C "$root" commit -qm seed
  "$SETUP" "$root" --apply >"$OUT" 2>"$ERR"
  git -C "$root" add .trackers;git -C "$root" commit -qm tracker-layer
}

# Missing AGENTS.md: preview is read-only and apply creates exactly the pointer.
missing="$TMP/missing";new_root "$missing";head_before="$(git -C "$missing" rev-parse HEAD)"
no "$ANCHOR" apply --root "$missing";has "$ERR" 'reason=confirmation-required'
"$ANCHOR" preview --root "$missing">"$OUT" 2>"$ERR"
has "$OUT" 'action=create';has "$OUT" 'path=AGENTS.md';has "$OUT" 'Read `.trackers/README.md`'
[ ! -e "$missing/AGENTS.md" ]&&pass=$((pass+1))||fail=$((fail+1))
eq 'preview preserves HEAD' "$head_before" "$(git -C "$missing" rev-parse HEAD)"
"$ANCHOR" apply --root "$missing" --confirmed>"$OUT" 2>"$ERR"
has "$OUT" 'wrote=AGENTS.md'
if cmp -s "$POINTER" "$missing/AGENTS.md";then pass=$((pass+1));else echo 'FAIL canonical pointer mismatch' >&2;fail=$((fail+1));fi
absent "$missing/AGENTS.md" '<!--'

# Existing prose survives byte-for-byte before the appended section; exact
# caller custody creates one AGENTS-only commit, and reruns are no-ops.
existing="$TMP/existing";new_root "$existing"
printf '# Existing instructions\n\nKeep this rule.'>"$existing/AGENTS.md"
git -C "$existing" add AGENTS.md;git -C "$existing" commit -qm door
cp "$existing/AGENTS.md" "$TMP/existing.before"
"$ANCHOR" apply --root "$existing" --confirmed>"$OUT" 2>"$ERR";has "$OUT" 'wrote=AGENTS.md'
head -c "$(wc -c <"$TMP/existing.before"|tr -d '[:space:]')" "$existing/AGENTS.md">"$TMP/existing.prefix"
if cmp -s "$TMP/existing.before" "$TMP/existing.prefix";then pass=$((pass+1));else echo 'FAIL existing prefix changed' >&2;fail=$((fail+1));fi
"$SCOPED" "$existing" 'Add tracker layer pointer' AGENTS.md >/dev/null
eq 'scoped commit contains only AGENTS' 'AGENTS.md' "$(git -C "$existing" diff-tree --no-commit-id --name-only -r HEAD)"
"$ANCHOR" apply --root "$existing" --confirmed>"$OUT" 2>"$ERR"
has "$OUT" 'action=noop';absent "$OUT" 'wrote=';eq 'rerun clean' '' "$(git -C "$existing" status --porcelain)"

# Literal guide mentions satisfy discovery. The canonical heading without the
# path is reserved and refuses rather than duplicating project prose.
mentioned="$TMP/mentioned";new_root "$mentioned"
printf 'Read `.trackers/README.md` for queues.\n'>"$mentioned/AGENTS.md";git -C "$mentioned" add AGENTS.md;git -C "$mentioned" commit -qm mentioned
"$ANCHOR" preview --root "$mentioned">"$OUT" 2>"$ERR";has "$OUT" 'action=noop'
conflict="$TMP/conflict";new_root "$conflict"
printf '## Project trackers\n\nDifferent prose.\n'>"$conflict/AGENTS.md";git -C "$conflict" add AGENTS.md;git -C "$conflict" commit -qm conflict
no "$ANCHOR" preview --root "$conflict";has "$ERR" 'reason=reserved-heading'

# Current layer and safe-root prerequisites refuse without a front-door write.
absent_root="$TMP/absent";mkdir -p "$absent_root";git -C "$absent_root" init -q
git -C "$absent_root" config user.name Test;git -C "$absent_root" config user.email test@example.com
printf 'seed\n'>"$absent_root/.seed";git -C "$absent_root" add .seed;git -C "$absent_root" commit -qm seed
no "$ANCHOR" preview --root "$absent_root";has "$ERR" 'reason=setup-required'
for broken in provider readme history;do
  root="$TMP/broken-$broken";new_root "$root"
  case "$broken" in
    provider) printf '# stale\n'>>"$root/.trackers/trackers.sh";;
    readme) sed 's/## Use the tracker tool/## Stale tracker tool/' "$root/.trackers/README.md">"$TMP/readme";mv "$TMP/readme" "$root/.trackers/README.md";;
    history) rm "$root/.trackers/history.tsv";;
  esac
  no "$ANCHOR" preview --root "$root"
  case "$broken" in provider|readme)has "$ERR" 'reason=repair-required';;history)has "$ERR" 'reason=ledger-recovery-required';;esac
done
unsafe="$TMP/unsafe";new_root "$unsafe";printf outside>"$TMP/outside";ln -s "$TMP/outside" "$unsafe/AGENTS.md"
no "$ANCHOR" preview --root "$unsafe";has "$ERR" 'reason=invalid-target'
no "$ANCHOR" preview --root relative;has "$ERR" 'reason=root-not-absolute'

# A change after apply's initial classification survives and blocks the write.
race="$TMP/race";new_root "$race";printf '# Existing\n'>"$race/AGENTS.md";git -C "$race" add AGENTS.md;git -C "$race" commit -qm door
hook="$TMP/race-hook.sh";printf '%s\n' '#!/bin/sh' 'printf "CONCURRENT_PROJECT_EDIT\\n" >>"$1/AGENTS.md"'>"$hook";chmod +x "$hook"
rc=0;BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT="$hook" "$ANCHOR" apply --root "$race" --confirmed>"$OUT" 2>"$ERR"||rc=$?
eq 'race refusal rc' 2 "$rc";has "$ERR" 'reason=concurrent-project-edit detail=AGENTS.md';has "$race/AGENTS.md" 'CONCURRENT_PROJECT_EDIT';absent "$race/AGENTS.md" 'Read `.trackers/README.md`'

deleted="$TMP/deleted";new_root "$deleted"
printf '# Existing\n'>"$deleted/AGENTS.md";git -C "$deleted" add AGENTS.md;git -C "$deleted" commit -qm door
delete_hook="$TMP/delete-hook.sh"
printf '%s\n' '#!/bin/sh' 'rm "$1/AGENTS.md"'>"$delete_hook";chmod +x "$delete_hook"
rc=0
BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT="$delete_hook" \
  "$ANCHOR" apply --root "$deleted" --confirmed>"$OUT" 2>"$ERR"||rc=$?
eq 'concurrent deletion refusal rc' 2 "$rc"
has "$ERR" 'reason=concurrent-project-edit detail=AGENTS.md'
[ ! -e "$deleted/AGENTS.md" ]&&pass=$((pass+1))||{
  echo 'FAIL anchor recreated concurrently deleted AGENTS.md' >&2;fail=$((fail+1));}

# Setup, repair, queue administration, and provider calls stay front-door neutral.
neutral="$TMP/neutral";new_root "$neutral";printf 'BACKLOG_FRONT_DOOR_CANARY\n'>"$neutral/AGENTS.md";git -C "$neutral" add AGENTS.md;git -C "$neutral" commit -qm door
cp "$neutral/AGENTS.md" "$TMP/neutral.before"
"$SETUP" "$neutral" --apply >/dev/null;"$SETUP" "$neutral" repair >/dev/null
"$SETUP" "$neutral" tracker-add decisions >/dev/null;"$SETUP" "$neutral" tracker-remove decisions >/dev/null
"$neutral/.trackers/trackers.sh" catalog >/dev/null
if cmp -s "$TMP/neutral.before" "$neutral/AGENTS.md";then pass=$((pass+1));else echo 'FAIL non-anchor operation changed AGENTS.md' >&2;fail=$((fail+1));fi

echo "anchor-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
