#!/usr/bin/env bash
# migrate-records-root-test.sh — explicit whole-root move and ordinary Git recovery.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"; MIGRATE="$SKILL/scripts/migrate-records-root.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-migrate.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

init_repo() {
  mkdir -p "$1"; git -C "$1" init -q
  git -C "$1" config user.name Fixture; git -C "$1" config user.email fixture@example.invalid
}
seed_source() {
  mkdir -p "$1/docs/records/notes"
  : >"$1/docs/records/history.tsv"
  printf '# Brownfield records\n' >"$1/docs/records/README.md"
  printf '%s\n' '---' 'doctype: notes' 'status: published' 'schema: notepad/note@1' 'tags: []' \
    '---' '# Note' >"$1/docs/records/notes/2026-09-02-note.md"
  git -C "$1" add .; git -C "$1" commit -qm source
}

root="$TMP/success"; init_repo "$root"; seed_source "$root"
printf '%s\n' '# Agents' 'agent-records: docs/records' >"$root/AGENTS.md"
printf '%s\n' '# Claude' 'records-root: elsewhere' >"$root/CLAUDE.md"
git -C "$root" add AGENTS.md CLAUDE.md; git -C "$root" commit -qm declarations
cp "$root/AGENTS.md" "$TMP/agents.before"; cp "$root/CLAUDE.md" "$TMP/claude.before"
head_before="$(git -C "$root" rev-parse HEAD)"

rc=0; "$MIGRATE" preview --root "$root" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "source is required rc" 2 "$rc"
expect "source is required usage" '--source <repo-relative>' "$ERR"

"$MIGRATE" preview --root "$root" --source docs/records >"$OUT" 2>"$ERR"
expect "preview names source" 'source=docs/records' "$OUT"
expect "preview names destination" 'destination=.records' "$OUT"
expect "preview is ready" 'ready=yes' "$OUT"
expect_eq "preview preserves HEAD" "$head_before" "$(git -C "$root" rev-parse HEAD)"
expect_eq "preview leaves clean worktree" '' "$(git -C "$root" status --porcelain)"

"$MIGRATE" apply --root "$root" --source docs/records --confirmed >"$OUT" 2>"$ERR"
[ ! -e "$root/docs/records" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ -x "$root/.records/records.sh" ] && pass=$((pass + 1)) || fail=$((fail + 1))
expect "migration reports commit" 'committed=' "$OUT"
cmp -s "$TMP/agents.before" "$root/AGENTS.md" && pass=$((pass + 1)) || {
  echo 'FAIL: migration changed AGENTS.md' >&2; fail=$((fail + 1)); }
cmp -s "$TMP/claude.before" "$root/CLAUDE.md" && pass=$((pass + 1)) || {
  echo 'FAIL: migration changed CLAUDE.md' >&2; fail=$((fail + 1)); }
expect_eq "migration leaves clean worktree" '' "$(git -C "$root" status --porcelain)"
expect_eq "migration makes one commit" 1 "$(git -C "$root" rev-list --count "$head_before"..HEAD)"
"$root/.records/records.sh" check >"$OUT"
expect "migrated layer checks" 'records check: OK' "$OUT"

mixed="$TMP/mixed"; init_repo "$mixed"; seed_source "$mixed"
printf 'foreign\n' >"$mixed/docs/records/data.bin"; git -C "$mixed" add .; git -C "$mixed" commit -qm mixed
rc=0; "$MIGRATE" preview --root "$mixed" --source docs/records >"$OUT" 2>"$ERR" || rc=$?
expect_eq "mixed source refuses rc" 2 "$rc"
expect "mixed source route" 'reason=mixed-source' "$ERR"
[ -d "$mixed/docs/records" ] && [ ! -e "$mixed/.records" ] && pass=$((pass + 1)) || fail=$((fail + 1))

dirty="$TMP/dirty"; init_repo "$dirty"; seed_source "$dirty"; printf 'dirty\n' >"$dirty/untracked"
rc=0; "$MIGRATE" preview --root "$dirty" --source docs/records >"$OUT" 2>"$ERR" || rc=$?
expect_eq "dirty worktree refuses rc" 2 "$rc"
expect "dirty worktree route" 'reason=dirty-worktree' "$ERR"

post="$TMP/post"; init_repo "$post"; mkdir -p "$post/docs/records/notes"
: >"$post/docs/records/history.tsv"
printf '%s\n' '---' 'doctype: notes' 'status: published' 'tags: []' '---' '# Invalid' \
  >"$post/docs/records/notes/2026-09-02-invalid.md"
git -C "$post" add .; git -C "$post" commit -qm invalid
post_head="$(git -C "$post" rev-parse HEAD)"; rc=0
"$MIGRATE" apply --root "$post" --source docs/records --confirmed >"$OUT" 2>"$ERR" || rc=$?
expect_eq "post-move content failure rc" 2 "$rc"
expect "post-move recovery route" 'inspect or revert this ordinary Git diff' "$ERR"
expect_eq "post-move failure creates no commit" "$post_head" "$(git -C "$post" rev-parse HEAD)"
[ -d "$post/.records" ] && [ ! -e "$post/docs/records" ] && pass=$((pass + 1)) || fail=$((fail + 1))

report migrate-records-root-test
