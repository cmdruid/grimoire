#!/usr/bin/env bash
# migrate-records-root-test.sh — whole-root migration, refusals, and Git recovery.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"

MIGRATE="$SKILL/scripts/migrate-records-root.sh"
PROVIDER="$SKILL/scripts/records.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-migrate-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

init_repo() {
  repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name Fixture
  git -C "$repo" config user.email fixture@example.invalid
}

seed_dedicated() {
  repo="$1"; source="${2:-docs/records}"
  mkdir -p "$repo/$source/notes"
  printf '%s\n' '---' 'doctype: notes' 'status: published' \
    'schema: notepad/note@1' 'tags: []' '---' '' '# Kept byte-for-byte' \
    >"$repo/$source/notes/2026-08-30-kept.md"
  printf '' >"$repo/$source/history.tsv"
  printf '%s\n' '# Project records' '' 'Keep this prose.' >"$repo/$source/README.md"
  printf '%s\n' 'old-provider-canary' >"$repo/$source/records.sh"
  chmod +x "$repo/$source/records.sh"
}

commit_all() {
  git -C "$1" add -- .
  git -C "$1" commit -qm fixture
}

expect_clean() {
  if [ -z "$(git -C "$1" status --porcelain --untracked-files=all)" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $2 — worktree is dirty" >&2; git -C "$1" status --short >&2
    fail=$((fail + 1))
  fi
}

expect_refusal() {
  label="$1"; reason="$2"; shift 2
  rc=0; "$MIGRATE" "$@" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$label rc" 2 "$rc"
  expect "$label reason" "reason=$reason" "$ERR"
}

# Preview is byte-, index-, and commit-read-only. Bare migration resolves the one
# retired declaration; apply moves the complete root in one clean commit.
success="$TMP/success"; init_repo "$success"; seed_dedicated "$success"
printf '%s\n' '# Agent front door' 'agent-records: docs/records' 'Keep this line.' \
  >"$success/AGENTS.md"
printf 'Claude prefix\nrecords-root: docs/records' >"$success/CLAUDE.md"
commit_all "$success"
cp "$success/docs/records/notes/2026-08-30-kept.md" "$TMP/record.before"
cp "$success/docs/records/history.tsv" "$TMP/ledger.before"
head_before="$(git -C "$success" rev-parse HEAD)"
index_before="$(git -C "$success" write-tree)"
"$MIGRATE" preview --root "$success" >"$OUT" 2>"$ERR"
expect "preview source" 'source=docs/records' "$OUT"
expect "preview record path" 'path=docs/records/notes/2026-08-30-kept.md' "$OUT"
expect "preview ready" 'ready=yes' "$OUT"
expect_eq "preview preserves HEAD" "$head_before" "$(git -C "$success" rev-parse HEAD)"
expect_eq "preview preserves index" "$index_before" "$(git -C "$success" write-tree)"
expect_clean "$success" "preview"

before_count="$(git -C "$success" rev-list --count HEAD)"
"$MIGRATE" apply --root "$success" --confirmed >"$OUT" 2>"$ERR"
expect_eq "apply creates one commit" "$((before_count + 1))" \
  "$(git -C "$success" rev-list --count HEAD)"
if [ ! -e "$success/docs/records" ] && [ -d "$success/.records" ]; then
  pass=$((pass + 1))
else echo 'FAIL: wholesale root move missing' >&2; fail=$((fail + 1)); fi
if cmp -s "$TMP/record.before" "$success/.records/notes/2026-08-30-kept.md"; then
  pass=$((pass + 1))
else echo 'FAIL: record bytes changed' >&2; fail=$((fail + 1)); fi
if cmp -s "$TMP/ledger.before" "$success/.records/history.tsv"; then
  pass=$((pass + 1))
else echo 'FAIL: ledger bytes changed' >&2; fail=$((fail + 1)); fi
printf '%s\n' '# Agent front door' 'Keep this line.' >"$TMP/agents.expected"
printf 'Claude prefix\n' >"$TMP/claude.expected"
if cmp -s "$TMP/agents.expected" "$success/AGENTS.md"; then pass=$((pass + 1));
else echo 'FAIL: AGENTS surrounding bytes changed' >&2; fail=$((fail + 1)); fi
if cmp -s "$TMP/claude.expected" "$success/CLAUDE.md"; then pass=$((pass + 1));
else echo 'FAIL: CLAUDE surrounding bytes changed' >&2; fail=$((fail + 1)); fi
if cmp -s "$PROVIDER" "$success/.records/records.sh"; then pass=$((pass + 1));
else echo 'FAIL: provider was not refreshed' >&2; fail=$((fail + 1)); fi
if [ -x "$success/.records/records.sh" ]; then pass=$((pass + 1));
else echo 'FAIL: provider is not executable' >&2; fail=$((fail + 1)); fi
"$success/.records/records.sh" check >"$OUT" 2>"$ERR"
expect "installed check passes" 'records check: OK' "$OUT"
if [ ! -e "$success/.spaces/journal/setup.intent" ]; then pass=$((pass + 1));
else echo 'FAIL: setup intent remains' >&2; fail=$((fail + 1)); fi
expect_clean "$success" "successful migration"
if [ -n "$(git -C "$success" diff-tree --no-commit-id --name-status -r HEAD -- docs/records)" ]; then
  pass=$((pass + 1))
else echo 'FAIL: commit omits old endpoint' >&2; fail=$((fail + 1)); fi
if [ -n "$(git -C "$success" diff-tree --no-commit-id --name-only -r HEAD -- .records)" ]; then
  pass=$((pass + 1))
else echo 'FAIL: commit omits new endpoint' >&2; fail=$((fail + 1)); fi

# Apply cannot turn a preview request into consent.
confirmation="$TMP/confirmation"; init_repo "$confirmation"; seed_dedicated "$confirmation"
commit_all "$confirmation"
confirmation_head="$(git -C "$confirmation" rev-parse HEAD)"
expect_refusal "confirmation" confirmation-required apply --root "$confirmation" \
  --source docs/records
expect_eq "confirmation refusal preserves HEAD" "$confirmation_head" \
  "$(git -C "$confirmation" rev-parse HEAD)"
expect_clean "$confirmation" "confirmation refusal"

# Every unsafe or mixed input refuses before writes.
mixed="$TMP/mixed"; init_repo "$mixed"; seed_dedicated "$mixed"
printf '%s\n' foreign >"$mixed/docs/records/random.txt"; commit_all "$mixed"
expect_refusal "mixed source" mixed-source preview --root "$mixed" --source docs/records
expect "mixed lists foreign path" 'foreign=docs/records/random.txt' "$ERR"
expect_clean "$mixed" "mixed refusal"

ignored="$TMP/ignored"; init_repo "$ignored"; seed_dedicated "$ignored"
printf '%s\n' 'docs/records/cache.bin' >"$ignored/.gitignore"; commit_all "$ignored"
printf '%s\n' ignored >"$ignored/docs/records/cache.bin"
expect_refusal "ignored source" ignored-source-entry preview --root "$ignored" \
  --source docs/records
expect_clean "$ignored" "ignored refusal"

dirty="$TMP/dirty"; init_repo "$dirty"; seed_dedicated "$dirty"; commit_all "$dirty"
printf '%s\n' dirty >>"$dirty/docs/records/README.md"
expect_refusal "dirty tree" dirty-worktree preview --root "$dirty" --source docs/records

destination="$TMP/destination"; init_repo "$destination"; seed_dedicated "$destination"
mkdir -p "$destination/.records"; printf '%s\n' incumbent >"$destination/.records/keep"
commit_all "$destination"
expect_refusal "destination" destination-present preview --root "$destination" \
  --source docs/records
expect_clean "$destination" "destination refusal"

conflict="$TMP/conflict"; init_repo "$conflict"; seed_dedicated "$conflict"
printf '%s\n' 'agent-records: docs/records' >"$conflict/AGENTS.md"
printf '%s\n' 'records-root: other/records' >"$conflict/CLAUDE.md"; commit_all "$conflict"
expect_refusal "conflicting declarations" conflicting-records-declarations preview \
  --root "$conflict"
expect_clean "$conflict" "conflict refusal"

mismatch="$TMP/mismatch"; init_repo "$mismatch"; seed_dedicated "$mismatch"
printf '%s\n' 'agent-records: docs/records' >"$mismatch/AGENTS.md"; commit_all "$mismatch"
expect_refusal "explicit mismatch" source-declaration-mismatch preview --root "$mismatch" \
  --source other/records
expect_clean "$mismatch" "mismatch refusal"

bare="$TMP/bare"; init_repo "$bare"; seed_dedicated "$bare"; commit_all "$bare"
expect_refusal "bare source" source-required preview --root "$bare"
expect_clean "$bare" "bare-source refusal"

symlinked="$TMP/symlinked"; init_repo "$symlinked"; mkdir -p "$symlinked/real/notes"
printf '%s\n' target >"$symlinked/real/notes/keep"; ln -s real "$symlinked/records"
commit_all "$symlinked"
expect_refusal "symlink source" symlink-source preview --root "$symlinked" --source records
expect_clean "$symlinked" "symlink refusal"

# A content failure after the Git move deliberately leaves only an ordinary
# inspectable Git diff; there is no migration manifest or hidden resume state.
post="$TMP/post-write"; init_repo "$post"; mkdir -p "$post/old/notes"
printf '%s\n' '---' 'doctype: notes' 'status: published' '---' '# Invalid record' \
  >"$post/old/notes/2026-08-30-invalid.md"
printf '' >"$post/old/history.tsv"; commit_all "$post"
post_head="$(git -C "$post" rev-parse HEAD)"
rc=0; "$MIGRATE" apply --root "$post" --source old --confirmed >"$OUT" 2>"$ERR" || rc=$?
if [ "$rc" -ne 0 ]; then pass=$((pass + 1));
else echo 'FAIL: invalid post-write fixture succeeded' >&2; fail=$((fail + 1)); fi
expect "post-write reports Git recovery" 'inspect or revert this ordinary Git diff' "$ERR"
expect_eq "post-write creates no commit" "$post_head" "$(git -C "$post" rev-parse HEAD)"
if [ ! -e "$post/old" ] && [ -d "$post/.records" ]; then pass=$((pass + 1));
else echo 'FAIL: post-write failure did not expose move diff' >&2; fail=$((fail + 1)); fi
if [ -n "$(git -C "$post" status --porcelain --untracked-files=all)" ]; then
  pass=$((pass + 1))
else echo 'FAIL: post-write failure left no visible diff' >&2; fail=$((fail + 1)); fi
if find "$post" -iname '*manifest*' -o -iname '*migrate*.intent' | grep -q .; then
  echo 'FAIL: post-write failure created migration state' >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "migrate-records-root-test"
