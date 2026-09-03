#!/usr/bin/env bash
# anchor-test.sh — managed project debrief route lifecycle.
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")"&&pwd)";SKILL="$(CDPATH='' cd -P "$HERE/../.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh";ANCHOR="$SKILL/scripts/trackers-anchor.sh";SCOPED="$SKILL/scripts/scoped-commit.sh"
ROUTE="$SKILL/templates/agents-route.md";POINTER="$SKILL/templates/agents-pointer.md"
HEADING='## Skill routes (self-registered)'
TMP="$(mktemp -d "${TMPDIR:-/tmp}/backlog-anchor-test.XXXXXX")";trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out";ERR="$TMP/err";pass=0;fail=0

has(){ if grep -qF -- "$2" "$1";then pass=$((pass+1));else echo "FAIL missing [$2] in $1" >&2;fail=$((fail+1));fi;}
absent(){ if grep -qF -- "$2" "$1";then echo "FAIL unexpected [$2] in $1" >&2;fail=$((fail+1));else pass=$((pass+1));fi;}
eq(){ if [ "$2" = "$3" ];then pass=$((pass+1));else echo "FAIL $1 want=[$2] got=[$3]" >&2;fail=$((fail+1));fi;}
no(){ rc=0;"$@">"$OUT" 2>"$ERR"||rc=$?;if [ "$rc" -eq 2 ];then pass=$((pass+1));else echo "FAIL expected rc=2 got=$rc: $*" >&2;fail=$((fail+1));fi;}
fact(){ sed -n "s/^$1=//p" "$OUT"|head -n1;}
preview(){ if [ "${2:-}" = remove ];then "$ANCHOR" preview --root "$1" --remove;else "$ANCHOR" preview --root "$1";fi;}
apply_preview(){
  local root="$1" operation="${2:-install}" base candidate
  if [ "$operation" = remove ];then preview "$root" remove>"$OUT" 2>"$ERR";else preview "$root">"$OUT" 2>"$ERR";fi
  base="$(fact base-sha256)";candidate="$(fact candidate-sha256)"
  if [ "$operation" = remove ];then "$ANCHOR" apply --root "$root" --remove --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate">"$OUT" 2>"$ERR"
  else "$ANCHOR" apply --root "$root" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate">"$OUT" 2>"$ERR";fi
}
new_root(){
  local root="$1";mkdir -p "$root";git -C "$root" init -q;git -C "$root" config user.name Test;git -C "$root" config user.email test@example.com
  printf 'seed\n'>"$root/.seed";git -C "$root" add .seed;git -C "$root" commit -qm seed
  "$SETUP" "$root" --apply>"$OUT" 2>"$ERR";git -C "$root" add .trackers;git -C "$root" commit -qm tracker-layer
}

for needle in '<!-- skill:backlog BEGIN built-against:__BUILT_AGAINST__ -->' '### /backlog — capture project follow-ups' 'child/delegate contexts' 'custodial caller' 'Reusable-skill feedback never enters project trackers' 'read `.trackers/README.md`' 'Edges: produces `tracker`.' '<!-- skill:backlog END -->';do has "$ROUTE" "$needle";done

# Install is preview-bound and creates one managed block without touching the tracker layer.
missing="$TMP/missing";new_root "$missing";tracker_before="$(git -C "$missing" status --porcelain -- .trackers)"
no "$ANCHOR" apply --root "$missing";has "$ERR" 'reason=confirmation-required'
preview "$missing">"$OUT" 2>"$ERR";has "$OUT" 'action=install';has "$OUT" 'status=change';has "$OUT" 'path=AGENTS.md';has "$OUT" 'base-sha256=absent';has "$OUT" 'candidate-sha256=';has "$OUT" '<!-- skill:backlog BEGIN built-against:'
[ ! -e "$missing/AGENTS.md" ]&&pass=$((pass+1))||fail=$((fail+1));base="$(fact base-sha256)";candidate="$(fact candidate-sha256)"
"$ANCHOR" apply --root "$missing" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate">"$OUT" 2>"$ERR";has "$OUT" 'wrote=AGENTS.md';has "$missing/AGENTS.md" '### /backlog — capture project follow-ups'
eq 'install leaves tracker layer untouched' "$tracker_before" "$(git -C "$missing" status --porcelain -- .trackers)"

# Insert under the shared heading, refresh only the owned span, then no-op.
existing="$TMP/existing";new_root "$existing";printf '%s\n' '# Existing' '' '## Skill routes (self-registered)' '' '<!-- skill:other BEGIN built-against:v1 -->' 'other' '<!-- skill:other END -->' '' '## Later' 'KEEP' >"$existing/AGENTS.md";git -C "$existing" add AGENTS.md;git -C "$existing" commit -qm door
cp "$existing/AGENTS.md" "$TMP/existing.before";apply_preview "$existing";has "$OUT" 'wrote=AGENTS.md';has "$existing/AGENTS.md" '<!-- skill:other BEGIN built-against:v1 -->';has "$existing/AGENTS.md" '## Later';has "$existing/AGENTS.md" '<!-- skill:backlog BEGIN built-against:'
sed 's/skill:backlog BEGIN built-against:[^ ]*/skill:backlog BEGIN built-against:stale/' "$existing/AGENTS.md">"$TMP/stale";mv "$TMP/stale" "$existing/AGENTS.md"
preview "$existing">"$OUT";has "$OUT" 'action=refresh';has "$OUT" 'status=change';apply_preview "$existing";absent "$existing/AGENTS.md" 'built-against:stale'
preview "$existing">"$OUT";has "$OUT" 'action=refresh';has "$OUT" 'status=noop';apply_preview "$existing";has "$OUT" 'status=noop'

# Removal owns only Backlog's exact span and remains available with an unhealthy layer.
cp "$existing/AGENTS.md" "$TMP/before-remove";rm "$existing/.trackers/history.tsv";preview "$existing" remove>"$OUT";has "$OUT" 'action=remove';has "$OUT" 'status=change';apply_preview "$existing" remove;has "$OUT" 'removed=AGENTS.md';absent "$existing/AGENTS.md" '<!-- skill:backlog BEGIN';has "$existing/AGENTS.md" '<!-- skill:other BEGIN';has "$existing/AGENTS.md" 'KEEP'
preview "$existing" remove>"$OUT";has "$OUT" 'status=noop';no preview "$existing";has "$ERR" 'reason=ledger-recovery-required'

# Removal needs only front-door custody, even when the layer or install-only package resources fail.
missing_layer="$TMP/remove-missing-layer";new_root "$missing_layer";apply_preview "$missing_layer";mv "$missing_layer/.trackers" "$TMP/missing-layer-state";apply_preview "$missing_layer" remove;has "$OUT" 'removed=AGENTS.md'
malformed_layer="$TMP/remove-malformed-layer";new_root "$malformed_layer";apply_preview "$malformed_layer";printf 'malformed\n'>"$malformed_layer/.trackers/history.tsv";apply_preview "$malformed_layer" remove;has "$OUT" 'removed=AGENTS.md'
damaged_package="$TMP/damaged-package";cp -R "$SKILL" "$damaged_package";damaged_root="$TMP/remove-damaged-package";new_root "$damaged_root";apply_preview "$damaged_root";mv "$damaged_package/templates/agents-route.md" "$TMP/agents-route.missing"
"$damaged_package/scripts/trackers-anchor.sh" preview --root "$damaged_root" --remove>"$OUT" 2>"$ERR"
base="$(fact base-sha256)";candidate="$(fact candidate-sha256)";"$damaged_package/scripts/trackers-anchor.sh" apply --root "$damaged_root" --remove --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate">"$OUT" 2>"$ERR";has "$OUT" 'removed=AGENTS.md'

# Exact legacy output migrates; customized project prose survives alongside the managed route.
legacy="$TMP/legacy";new_root "$legacy";printf '# Project preface\n\n'>"$legacy/AGENTS.md";cat "$POINTER">>"$legacy/AGENTS.md";apply_preview "$legacy";absent "$legacy/AGENTS.md" '## Project trackers';has "$legacy/AGENTS.md" '## Skill routes (self-registered)';has "$legacy/AGENTS.md" '# Project preface'
custom="$TMP/custom";new_root "$custom";sed 's/Actionable project follow-ups/Customized project follow-ups/' "$POINTER">"$custom/AGENTS.md";apply_preview "$custom";has "$custom/AGENTS.md" 'Customized project follow-ups';has "$custom/AGENTS.md" '<!-- skill:backlog BEGIN'

# Marker-like examples in fences are inert; malformed live ownership always refuses.
fenced="$TMP/fenced";new_root "$fenced";printf '%s\n' '```md' '<!-- skill:backlog BEGIN broken -->' '<!-- skill:backlog END -->' '```' >"$fenced/AGENTS.md";apply_preview "$fenced";has "$fenced/AGENTS.md" '<!-- skill:backlog BEGIN broken -->';eq 'one live begin beside fenced example' 2 "$(grep -c '<!-- skill:backlog BEGIN' "$fenced/AGENTS.md")"
for shape in orphan-begin orphan-end inverted indented outside duplicate-heading;do
  root="$TMP/malformed-$shape";new_root "$root"
  case "$shape" in
    orphan-begin)printf '%s\n' "$HEADING" '<!-- skill:backlog BEGIN built-against:v1 -->'>"$root/AGENTS.md";;
    orphan-end)printf '%s\n' "$HEADING" '<!-- skill:backlog END -->'>"$root/AGENTS.md";;
    inverted)printf '%s\n' "$HEADING" '<!-- skill:backlog END -->' '<!-- skill:backlog BEGIN built-against:v1 -->'>"$root/AGENTS.md";;
    indented)printf '%s\n' "$HEADING" ' <!-- skill:backlog BEGIN built-against:v1 -->' '<!-- skill:backlog END -->'>"$root/AGENTS.md";;
    outside)printf '%s\n' '<!-- skill:backlog BEGIN built-against:v1 -->' 'x' '<!-- skill:backlog END -->'>"$root/AGENTS.md";;
    duplicate-heading)printf '%s\n%s\n' "$HEADING" "$HEADING">"$root/AGENTS.md";;
  esac
  cp "$root/AGENTS.md" "$TMP/$shape.before";no preview "$root";cmp -s "$TMP/$shape.before" "$root/AGENTS.md"&&pass=$((pass+1))||fail=$((fail+1))
done

# Both preview identities and the final live file are revalidated.
stale="$TMP/stale-digest";new_root "$stale";preview "$stale">"$OUT";base="$(fact base-sha256)";candidate="$(fact candidate-sha256)";bad_candidate="1${candidate:1}";[ "$bad_candidate" != "$candidate" ]||bad_candidate="0${candidate:1}"
no "$ANCHOR" apply --root "$stale" --confirmed --base-sha256 "$base" --candidate-sha256 "$bad_candidate";has "$ERR" 'reason=candidate-changed'
printf 'concurrent\n'>"$stale/AGENTS.md";no "$ANCHOR" apply --root "$stale" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate";has "$ERR" 'reason=base-changed'
race="$TMP/race";new_root "$race";printf '# Existing\n'>"$race/AGENTS.md";preview "$race">"$OUT";base="$(fact base-sha256)";candidate="$(fact candidate-sha256)"
hook="$TMP/race-hook.sh";printf '%s\n' '#!/bin/sh' 'printf "CONCURRENT_PROJECT_EDIT\n" >>"$1/AGENTS.md"'>"$hook";chmod +x "$hook"
rc=0;BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT="$hook" "$ANCHOR" apply --root "$race" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate">"$OUT" 2>"$ERR"||rc=$?;eq 'race refusal rc' 2 "$rc";has "$ERR" 'reason=concurrent-project-edit detail=AGENTS.md';has "$race/AGENTS.md" 'CONCURRENT_PROJECT_EDIT';absent "$race/AGENTS.md" '### /backlog'
deleted="$TMP/deleted";new_root "$deleted";printf '# Existing\n'>"$deleted/AGENTS.md";preview "$deleted">"$OUT";base="$(fact base-sha256)";candidate="$(fact candidate-sha256)"
delete_hook="$TMP/delete-hook.sh";printf '%s\n' '#!/bin/sh' 'mv "$1/AGENTS.md" "$1/AGENTS.md.concurrently-deleted"'>"$delete_hook";chmod +x "$delete_hook"
rc=0;BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT="$delete_hook" "$ANCHOR" apply --root "$deleted" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate">"$OUT" 2>"$ERR"||rc=$?;eq 'concurrent deletion refusal rc' 2 "$rc";has "$ERR" 'reason=concurrent-project-edit detail=AGENTS.md'
[ ! -e "$deleted/AGENTS.md" ]&&[ -f "$deleted/AGENTS.md.concurrently-deleted" ]&&pass=$((pass+1))||{ echo 'FAIL anchor recreated concurrently deleted front door' >&2;fail=$((fail+1));}

# Surrounding bytes and file mode survive install; the preservation oracle is red-proved.
bytes="$TMP/bytes";new_root "$bytes";printf 'FIRST\r\nSECOND'>"$bytes/AGENTS.md";chmod 640 "$bytes/AGENTS.md";cp "$bytes/AGENTS.md" "$TMP/bytes.before";mode_before="$(stat -f '%Lp' "$bytes/AGENTS.md" 2>/dev/null||stat -c '%a' "$bytes/AGENTS.md")";apply_preview "$bytes"
head -c "$(wc -c <"$TMP/bytes.before"|tr -d ' ')" "$bytes/AGENTS.md">"$TMP/bytes.prefix";cmp -s "$TMP/bytes.before" "$TMP/bytes.prefix"&&pass=$((pass+1))||{ echo 'FAIL surrounding bytes changed' >&2;fail=$((fail+1));}
eq 'mode preserved' "$mode_before" "$(stat -f '%Lp' "$bytes/AGENTS.md" 2>/dev/null||stat -c '%a' "$bytes/AGENTS.md")"
printf X>>"$TMP/bytes.prefix";if cmp -s "$TMP/bytes.before" "$TMP/bytes.prefix";then echo 'FAIL corrupted preservation oracle passed' >&2;fail=$((fail+1));else pass=$((pass+1));fi

# Safe-root guards, exact commit custody, and non-anchor neutrality remain intact.
unsafe="$TMP/unsafe";new_root "$unsafe";printf outside>"$TMP/outside";ln -s "$TMP/outside" "$unsafe/AGENTS.md";no preview "$unsafe";has "$ERR" 'reason=invalid-target'
no "$ANCHOR" preview --root relative;has "$ERR" 'reason=root-not-absolute'
nested="$TMP/nested";new_root "$nested";mkdir "$nested/child";no preview "$nested/child";has "$ERR" 'reason=root-not-git-top-level'
commit_root="$TMP/commit";new_root "$commit_root";apply_preview "$commit_root";"$SCOPED" "$commit_root" 'Install project debrief route' AGENTS.md >/dev/null;eq 'scoped commit contains only AGENTS' AGENTS.md "$(git -C "$commit_root" diff-tree --no-commit-id --name-only -r HEAD)"
if git -C "$commit_root" show --pretty='' --name-only HEAD^|grep -q '^.trackers/';then pass=$((pass+1));else echo 'FAIL setup transaction did not precede anchor commit' >&2;fail=$((fail+1));fi
failure_root="$TMP/setup-anchor-failure";new_root "$failure_root";tracker_head="$(git -C "$failure_root" rev-parse HEAD)";preview "$failure_root">"$OUT";base="$(fact base-sha256)";candidate="$(fact candidate-sha256)";printf '\ncompeting route\n'>"$failure_root/AGENTS.md"
no "$ANCHOR" apply --root "$failure_root" --confirmed --base-sha256 "$base" --candidate-sha256 "$candidate";has "$ERR" 'reason=base-changed'
eq 'anchor failure preserves setup commit' "$tracker_head" "$(git -C "$failure_root" rev-parse HEAD)"
[ -f "$failure_root/.trackers/history.tsv" ]&&pass=$((pass+1))||{ echo 'FAIL anchor failure damaged initialized trackers' >&2;fail=$((fail+1));}
neutral="$TMP/neutral";new_root "$neutral";printf 'FRONT_DOOR_CANARY\n'>"$neutral/AGENTS.md";cp "$neutral/AGENTS.md" "$TMP/neutral.before";"$SETUP" "$neutral" --apply >/dev/null;"$SETUP" "$neutral" repair >/dev/null;"$SETUP" "$neutral" tracker-add decisions >/dev/null;"$SETUP" "$neutral" tracker-remove decisions >/dev/null;"$neutral/.trackers/trackers.sh" catalog >/dev/null;cmp -s "$TMP/neutral.before" "$neutral/AGENTS.md"&&pass=$((pass+1))||{ echo 'FAIL non-anchor path changed front door' >&2;fail=$((fail+1));}

echo "anchor-test: $pass passed, $fail failed";[ "$fail" -eq 0 ]
