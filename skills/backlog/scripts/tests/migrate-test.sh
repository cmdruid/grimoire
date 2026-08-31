#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
MIGRATE="$SKILL/scripts/migrate-trackers.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-migrate-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0

pass_one(){ pass=$((pass+1)); }
fail_one(){ echo "FAIL: $*" >&2;fail=$((fail+1)); }
ok(){ if "$@" >"$T/out" 2>"$T/err";then pass_one;else fail_one "rejected: $*";cat "$T/err" >&2;fi; }
no(){ if "$@" >"$T/out" 2>"$T/err";then fail_one "accepted: $*";else pass_one;fi; }
has(){ if grep -qF -- "$2" "$1";then pass_one;else fail_one "missing '$2' in $1";fi; }
exact_paths(){
  local output="$1" actual="$T/paths.actual" expected="$T/paths.expected";shift
  sed -n 's/^path=//p' "$output"|sort >"$actual"
  printf '%s\n' "$@"|sort >"$expected"
  cmp "$expected" "$actual" >/dev/null&&pass_one||fail_one 'preview path inventory differs'
  has "$output" "paths=$#"
}

new_repo(){
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.name Fixture
  git -C "$1" config user.email fixture@example.invalid
  printf '# Fixture\n' >"$1/README.md"
  git -C "$1" add README.md
  git -C "$1" commit -qm init
}

seed_v1(){
  local root="$1" source="$2" layer
  layer="$root/$source"
  mkdir -p "$layer"
  printf '%s\n' '# Legacy tracker guide' >"$layer/README.md"
  printf '%s\n' '# Backlog debrief routing' '' \
    'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.' \
    '' '## tasks' '' 'Route task leftovers here.' >"$layer/DEBRIEF.md"
  printf '%s\n' '#!/usr/bin/env bash' "cat <<'EOF'" 'schema=tracker@1' 'EOF' >"$layer/trackers.sh"
  chmod +x "$layer/trackers.sh"
  printf '%s\n' \
    $'id\tcreated\ttext\tevidence' \
    $'tasks-1\t2026-08-30T00:00:00Z\tfirst row\tdocs/one' \
    $'tasks-2\t2026-08-30T00:01:00Z\tsecond row\tdocs/two' >"$layer/tasks.tsv"
  printf '%s\n' \
    $'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult' \
    $'receipt-1\t2026-08-30T00:02:00Z\tanalyst/status\ttasks\ttasks-1\tobserved\t\t' \
    $'receipt-2\t2026-08-30T00:03:00Z\tcontractor/build\ttasks\ttasks-1\tconsumed\tdone\tdocs/result' >"$layer/receipts.tsv"
  git -C "$root" add -- "$source"
  git -C "$root" commit -qm tracker1
}

# In-place preview is write-free; apply requires confirmation and preserves front-door bytes.
R="$T/in-place";new_repo "$R";seed_v1 "$R" .trackers
printf '%s\n' '<!-- skill:backlog BEGIN broken -->' >"$R/AGENTS.md"
git -C "$R" add AGENTS.md;git -C "$R" commit -qm front-door
cp "$R/AGENTS.md" "$T/agents.before"
cp "$R/.trackers/tasks.tsv" "$T/tasks.before"
cut -f2- "$R/.trackers/receipts.tsv" >"$T/history-fields.before"
before="$(git -C "$R" rev-parse HEAD)"
ok "$MIGRATE" preview --root "$R"
has "$T/out" 'source=.trackers';has "$T/out" 'destination=.trackers';has "$T/out" 'ready=yes'
exact_paths "$T/out" .trackers/DEBRIEF.md .trackers/README.md .trackers/receipts.tsv .trackers/tasks.tsv .trackers/trackers.sh
[ "$before" = "$(git -C "$R" rev-parse HEAD)" ]&&[ -z "$(git -C "$R" status --porcelain)" ]&&pass_one||fail_one 'preview changed Git state'
no "$MIGRATE" apply --root "$R"
[ "$before" = "$(git -C "$R" rev-parse HEAD)" ]&&[ -z "$(git -C "$R" status --porcelain)" ]&&pass_one||fail_one 'missing confirmation changed Git state'
ok "$MIGRATE" apply --root "$R" --confirmed
[ "$(git -C "$R" rev-list --count HEAD)" -eq 4 ]&&pass_one||fail_one 'migration did not create exactly one commit'
[ ! -e "$R/.trackers/tasks.tsv" ]&&[ ! -e "$R/.trackers/receipts.tsv" ]&&pass_one||fail_one 'legacy TSV remains'
cmp "$T/tasks.before" "$R/.trackers/tables/tasks.tsv" >/dev/null&&pass_one||fail_one 'queue bytes changed'
cut -f2- "$R/.trackers/history.tsv" >"$T/history-fields.after"
cmp "$T/history-fields.before" "$T/history-fields.after" >/dev/null&&pass_one||fail_one 'non-ID history bytes changed'
has "$R/.trackers/history.tsv" $'event-1\t';has "$R/.trackers/history.tsv" $'event-2\t'
cmp "$T/agents.before" "$R/AGENTS.md" >/dev/null&&pass_one||fail_one 'migration changed AGENTS.md'
"$R/.trackers/trackers.sh" page --tracker tasks --status consumed --limit 20 >"$T/page"
"$R/.trackers/trackers.sh" history --limit 20 >"$T/history"
has "$T/page" $'tasks-1\t';has "$T/history" $'event-2\t'
[ -z "$(git -C "$R" status --porcelain)" ]&&pass_one||fail_one 'migration left dirty worktree'

# An external source is never inferred; an explicit source moves wholesale to `.trackers`.
E="$T/external";new_repo "$E";seed_v1 "$E" legacy/trackers
no "$MIGRATE" preview --root "$E"
has "$T/err" 'reason=source-not-directory'
ok "$MIGRATE" preview --root "$E" --source legacy/trackers
has "$T/out" 'source=legacy/trackers';has "$T/out" 'ready=yes'
exact_paths "$T/out" legacy/trackers/DEBRIEF.md legacy/trackers/README.md legacy/trackers/receipts.tsv legacy/trackers/tasks.tsv legacy/trackers/trackers.sh
ok "$MIGRATE" apply --root "$E" --source legacy/trackers --confirmed
[ ! -e "$E/legacy/trackers" ]&&[ -x "$E/.trackers/trackers.sh" ]&&pass_one||fail_one 'external source was not moved'
[ -z "$(git -C "$E" status --porcelain)" ]&&pass_one||fail_one 'external migration left dirty worktree'

# Unsupported or unsafe sources refuse before writes.
D="$T/dirty";new_repo "$D";seed_v1 "$D" .trackers;printf 'dirty\n' >"$D/untracked"
no "$MIGRATE" preview --root "$D";has "$T/err" 'reason=dirty-worktree'
U="$T/unknown";new_repo "$U";seed_v1 "$U" .trackers;printf 'unknown\n' >"$U/.trackers/extra.txt";git -C "$U" add .trackers/extra.txt;git -C "$U" commit -qm unknown
before="$(git -C "$U" rev-parse HEAD)";no "$MIGRATE" apply --root "$U" --confirmed;has "$T/err" 'reason=mixed-source'
[ "$before" = "$(git -C "$U" rev-parse HEAD)" ]&&[ -z "$(git -C "$U" status --porcelain)" ]&&pass_one||fail_one 'mixed refusal changed Git state'
M="$T/malformed";new_repo "$M";seed_v1 "$M" .trackers;printf 'bad\n' >"$M/.trackers/tasks.tsv";git -C "$M" add .trackers/tasks.tsv;git -C "$M" commit -qm malformed
no "$MIGRATE" preview --root "$M";has "$T/err" 'reason=malformed-tracker'

# Already-current, detached, unsafe, symlinked, ignored, and colliding inputs stay write-free.
no "$MIGRATE" preview --root "$R";has "$T/err" 'reason=mixed-source'
H="$T/detached";new_repo "$H";seed_v1 "$H" .trackers;git -C "$H" checkout -q --detach
no "$MIGRATE" preview --root "$H";has "$T/err" 'reason=detached-head'
no "$MIGRATE" preview --root "$D" --source ../trackers;has "$T/err" 'reason=invalid-source'
if (cd "$D"&&"$MIGRATE" preview --root . >"$T/out" 2>"$T/err");then fail_one 'accepted relative root';else pass_one;fi
has "$T/err" 'reason=root-not-absolute'
Y="$T/symlink";new_repo "$Y";seed_v1 "$Y" legacy/trackers;ln -s legacy/trackers "$Y/tracker-link";git -C "$Y" add tracker-link;git -C "$Y" commit -qm symlink
no "$MIGRATE" preview --root "$Y" --source tracker-link;has "$T/err" 'reason=symlink-source'
I="$T/ignored";new_repo "$I";seed_v1 "$I" .trackers;printf '%s\n' '.trackers/ignored.dat' >"$I/.gitignore";git -C "$I" add .gitignore;git -C "$I" commit -qm ignore;printf 'ignored\n' >"$I/.trackers/ignored.dat"
no "$MIGRATE" preview --root "$I";has "$T/err" 'reason=ignored-source-entry'
C="$T/collision";new_repo "$C";seed_v1 "$C" legacy/trackers;mkdir "$C/.trackers";printf 'occupied\n' >"$C/.trackers/canary";git -C "$C" add .trackers;git -C "$C" commit -qm collision
no "$MIGRATE" preview --root "$C" --source legacy/trackers;has "$T/err" 'reason=destination-present'
P="$T/provider";new_repo "$P";seed_v1 "$P" .trackers;printf '%s\n' '#!/usr/bin/env bash' 'echo unknown' >"$P/.trackers/trackers.sh";chmod +x "$P/.trackers/trackers.sh";git -C "$P" add .trackers/trackers.sh;git -C "$P" commit -qm malformed-provider
no "$MIGRATE" preview --root "$P";has "$T/err" 'reason=malformed-provider'
Q="$T/receipts";new_repo "$Q";seed_v1 "$Q" .trackers;printf 'bad\n' >"$Q/.trackers/receipts.tsv";git -C "$Q" add .trackers/receipts.tsv;git -C "$Q" commit -qm malformed-receipts
no "$MIGRATE" preview --root "$Q";has "$T/err" 'reason=malformed-receipts'
W="$T/prompt";new_repo "$W";seed_v1 "$W" .trackers;printf 'bad\n' >"$W/.trackers/DEBRIEF.md";git -C "$W" add .trackers/DEBRIEF.md;git -C "$W" commit -qm malformed-prompt
no "$MIGRATE" preview --root "$W";has "$T/err" 'reason=malformed-prompt'
V="$T/readme";new_repo "$V";seed_v1 "$V" .trackers;printf '%s\n' '<!-- backlog:trackers-tool BEGIN -->' >>"$V/.trackers/README.md";git -C "$V" add .trackers/README.md;git -C "$V" commit -qm malformed-readme
no "$MIGRATE" preview --root "$V";has "$T/err" 'reason=malformed-readme'
N="$T/nested-git";new_repo "$N";seed_v1 "$N" .trackers;git -C "$N/.trackers" init -q;before="$(git -C "$N" rev-parse HEAD)"
no "$MIGRATE" preview --root "$N";has "$T/err" 'reason=mixed-source'
[ "$before" = "$(git -C "$N" rev-parse HEAD)" ]&&[ -z "$(git -C "$N" status --porcelain)" ]&&pass_one||fail_one 'nested Git refusal changed outer repository'

# A post-write failure leaves the exact ordinary Git recovery diff and no migration commit.
F="$T/post-write";new_repo "$F";seed_v1 "$F" .trackers;before="$(git -C "$F" rev-parse HEAD)"
STOP="$T/stop-after-move.sh";printf '%s\n' '#!/bin/sh' 'exit 86' >"$STOP";chmod +x "$STOP"
no env BACKLOG_MIGRATE_TEST_AFTER_MOVE="$STOP" "$MIGRATE" apply --root "$F" --confirmed
has "$T/err" 'migration stopped after the first move';has "$T/err" 'diff --git'
[ "$before" = "$(git -C "$F" rev-parse HEAD)" ]&&[ -n "$(git -C "$F" status --porcelain)" ]&&pass_one||fail_one 'post-write failure hid its Git diff'

# The exact v1 contract permits an intentionally empty queue population.
Z="$T/empty";new_repo "$Z";seed_v1 "$Z" .trackers
git -C "$Z" rm -q .trackers/tasks.tsv
printf '%s\n' '# Backlog debrief routing' '' \
  'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.' >"$Z/.trackers/DEBRIEF.md"
printf '%s\n' $'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult' >"$Z/.trackers/receipts.tsv"
git -C "$Z" add .trackers;git -C "$Z" commit -qm empty-population
ok "$MIGRATE" apply --root "$Z" --confirmed
[ "$(find "$Z/.trackers/tables" -name '*.tsv'|wc -l|tr -d ' ')" -eq 0 ]&&pass_one||fail_one 'empty population gained queues'
[ -z "$(git -C "$Z" status --porcelain)" ]&&pass_one||fail_one 'empty migration left dirty worktree'

# `history` was an ordinary tracker@1 queue stem; in-place migration must not confuse it with the
# tracker@2 lifecycle destination.
J="$T/history-queue";new_repo "$J";seed_v1 "$J" .trackers
git -C "$J" mv .trackers/tasks.tsv .trackers/history.tsv
sed 's/^tasks-/history-/' "$J/.trackers/history.tsv" >"$T/history-queue.tsv";mv "$T/history-queue.tsv" "$J/.trackers/history.tsv"
sed 's/^## tasks$/## history/' "$J/.trackers/DEBRIEF.md" >"$T/history-prompt.md";mv "$T/history-prompt.md" "$J/.trackers/DEBRIEF.md"
sed $'s/\ttasks\ttasks-/\thistory\thistory-/' "$J/.trackers/receipts.tsv" >"$T/history-receipts.tsv";mv "$T/history-receipts.tsv" "$J/.trackers/receipts.tsv"
git -C "$J" add .trackers;git -C "$J" commit -qm history-queue
cp "$J/.trackers/history.tsv" "$T/history-queue.before"
ok "$MIGRATE" preview --root "$J"
exact_paths "$T/out" .trackers/DEBRIEF.md .trackers/README.md .trackers/history.tsv .trackers/receipts.tsv .trackers/trackers.sh
ok "$MIGRATE" apply --root "$J" --confirmed
cmp "$T/history-queue.before" "$J/.trackers/tables/history.tsv" >/dev/null&&pass_one||fail_one 'history queue bytes changed'
"$J/.trackers/trackers.sh" page --tracker history --status consumed --limit 20 >"$T/history-queue.page"
has "$T/history-queue.page" $'history-1\t';has "$J/.trackers/history.tsv" $'event-2\t'
[ -z "$(git -C "$J" status --porcelain)" ]&&pass_one||fail_one 'history queue migration left dirty worktree'

echo "migrate-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
