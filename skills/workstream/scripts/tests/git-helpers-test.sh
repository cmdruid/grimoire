#!/usr/bin/env bash
# git-helpers-test.sh — fixture proofs for Workstream's git fact and lifecycle helpers.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$DIR/.." && pwd)"
FACTS="$SCRIPTS/workstream-git.sh"
EXCLUDE="$SCRIPTS/worktree-exclude.sh"
TEARDOWN="$SCRIPTS/worktree-teardown.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-git-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/repo"
mkdir "$ROOT"
ROOT="$(cd "$ROOT" && pwd -P)"
git -C "$ROOT" init -q
git -C "$ROOT" branch -m main
git -C "$ROOT" config user.name test
git -C "$ROOT" config user.email test@example.invalid
printf '.workstreams/\n' > "$ROOT/.gitignore"
printf '# fixture\n' > "$ROOT/README.md"
printf 'base\n' > "$ROOT/code.txt"
git -C "$ROOT" add .gitignore README.md code.txt
git -C "$ROOT" commit -qm initial
mkdir "$ROOT/.workstreams"
WT="$ROOT/.workstreams/demo"
git -C "$ROOT" worktree add -q -b stream/demo "$WT" main

fact() { sed -n "s/^$1=//p" "$2" | head -n 1; }
OUT="$TMP/out"

"$EXCLUDE" "$WT"
"$EXCLUDE" "$WT"
exclude="$(git -C "$WT" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$WT/$exclude" ;; esac
expect_eq "handoff exclusion is idempotent" "1" "$(grep -cFx WORKSTREAM.md "$exclude")"

"$FACTS" stream-state "$WT" stream/demo main > "$OUT"
expect_eq "stream-state branch guard" "true" "$(fact branch_matches "$OUT")"
expect_eq "stream-state toplevel guard" "true" "$(fact toplevel_matches "$OUT")"
expect_eq "fresh stream ahead" "0" "$(fact ahead "$OUT")"

mkdir -p "$WT/.records/streams"
printf '# next\n' > "$WT/.records/streams/next.md"
"$FACTS" stream-state "$WT" stream/demo main > "$OUT"
expect_eq "stream manifest draft is classified" ".records/streams/next.md" "$(fact drafted_next_plan "$OUT")"
expect_eq "stream manifest draft is not real WIP" "false" "$(fact wip_tracked "$OUT")"
printf 'scratch\n' > "$WT/scratch.txt"
"$FACTS" stream-state "$WT" stream/demo main > "$OUT"
expect_eq "other dirt is real WIP" "true" "$(fact wip_tracked "$OUT")"
rm "$WT/scratch.txt" "$WT/.records/streams/next.md"
rmdir "$WT/.records/streams" "$WT/.records"

printf '# stream docs\n' > "$WT/stream.md"
git -C "$WT" add stream.md
git -C "$WT" commit -qm 'docs: stream change'
"$FACTS" gate-facts "$WT" stream/demo main > "$OUT"
expect_eq "own markdown is docs-only" "true" "$(fact own_docs_only "$OUT")"
expect_eq "no incoming change yet" "true" "$(fact incoming_empty "$OUT")"

printf 'main changed\n' > "$ROOT/code.txt"
git -C "$ROOT" add code.txt
git -C "$ROOT" commit -qm 'code: main change'
"$FACTS" gate-facts "$WT" stream/demo main > "$OUT"
expect_eq "incoming code is not docs-only" "false" "$(fact incoming_docs_only "$OUT")"
"$FACTS" land-readiness "$ROOT" "$WT" stream/demo main > "$OUT"
expect_eq "moved target is not ff-safe" "false" "$(fact ff_safe "$OUT")"
expect_eq "root remains on target" "true" "$(fact root_on_target "$OUT")"

cat > "$WT/WORKSTREAM.md" <<'EOF'
# fixture handoff

## Cheat sheet

- live: `README.md`
- stale: `missing.md`

## Queue state
Parked: true
EOF
"$FACTS" cheatsheet-check "$WT" > "$OUT"
expect_eq "cheatsheet checks both refs" "2" "$(fact checked "$OUT")"
expect_eq "cheatsheet reports one stale ref" "1" "$(fact stale "$OUT")"

mkdir "$ROOT/.workstreams/inplace"
printf '%s\n' '# in-place' '- isolation: in-place' > "$ROOT/.workstreams/inplace/WORKSTREAM.md"
"$FACTS" inplace-scan "$ROOT" > "$OUT"
expect_eq "in-place scan finds recorded stream" "inplace" "$(fact inplace_streams "$OUT")"
"$FACTS" inplace-state "$ROOT" demo stream/demo main > "$OUT"
expect_eq "root checkout is not holding stream branch" "false" "$(fact on_stream_branch "$OUT")"
expect_eq "root checkout is on target" "true" "$(fact on_target "$OUT")"
expect_eq "in-place state reads handoff custody" "true" "$(fact handoff_parked "$OUT")"
rm -f "$ROOT/.workstreams/inplace/WORKSTREAM.md"
rmdir "$ROOT/.workstreams/inplace"

if "$TEARDOWN" "$ROOT" demo --wrong >/dev/null 2>&1; then
  echo "FAIL: teardown accepted an unknown flag" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "rejected teardown preserves worktree" "true" "$([ -d "$WT" ] && echo true || echo false)"

"$TEARDOWN" "$ROOT" demo --force >/dev/null
expect_eq "teardown removes worktree" "false" "$([ -e "$WT" ] && echo true || echo false)"
expect_eq "teardown removes branch" "false" \
  "$(git -C "$ROOT" show-ref --verify --quiet refs/heads/stream/demo && echo true || echo false)"

report "git-helpers-test.sh"
