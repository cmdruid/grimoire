#!/usr/bin/env bash
# git-helpers-test.sh — fixture proofs for Workstream's git fact and lifecycle helpers.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$DIR/.." && pwd)"
FACTS="$SCRIPTS/workstream-git.sh"
EXCLUDE="$SCRIPTS/worktree-exclude.sh"
TEARDOWN="$SCRIPTS/worktree-teardown.sh"
RUNTIME="$SCRIPTS/workstream.sh"
# shellcheck disable=SC1091
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-git-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/repo"
mkdir "$ROOT"
ROOT="$(cd "$ROOT" && pwd -P)"
init_repo "$ROOT"
printf '.streams/*/\n' > "$ROOT/.gitignore"
printf '# fixture\n' > "$ROOT/README.md"
printf 'base\n' > "$ROOT/code.txt"
git -C "$ROOT" add .gitignore README.md code.txt
git -C "$ROOT" commit -qm initial
mkdir "$ROOT/.streams"
WT="$ROOT/.streams/demo"
git -C "$ROOT" worktree add -q -b stream/demo "$WT" main

fact() { sed -n "s/^$1=//p" "$2" | head -n 1; }
OUT="$TMP/out"

"$EXCLUDE" "$WT"
"$EXCLUDE" "$WT"
exclude="$(git -C "$WT" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$WT/$exclude" ;; esac
for pattern in '/.streams/*/' '/WORKSTREAM.md' '/workstream.tsv'; do
  expect_eq "runtime exclusion is idempotent: $pattern" "1" "$(grep -cFx "$pattern" "$exclude")"
done

"$FACTS" stream-state "$WT" stream/demo main > "$OUT"
expect_eq "stream-state branch guard" "true" "$(fact branch_matches "$OUT")"
expect_eq "stream-state toplevel guard" "true" "$(fact toplevel_matches "$OUT")"
expect_eq "fresh stream ahead" "0" "$(fact ahead "$OUT")"

printf 'scratch\n' > "$WT/scratch.txt"
"$FACTS" stream-state "$WT" stream/demo main > "$OUT"
expect_eq "ordinary dirt is real WIP" "true" "$(fact wip_tracked "$OUT")"
rm "$WT/scratch.txt"

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
printf 'worktree\t%s\nisolation\tworktree\ntarget\tmain\nlanding\tlocal\n' "$WT" >>"$WT/WORKSTREAM.md"
printf 'record\tid\tfield\tvalue\n' >"$WT/workstream.tsv"
"$FACTS" cheatsheet-check "$WT" > "$OUT"
expect_eq "cheatsheet checks both refs" "2" "$(fact checked "$OUT")"
expect_eq "cheatsheet reports one stale ref" "1" "$(fact stale "$OUT")"

mkdir "$ROOT/.streams/inplace"
printf '%s\n' '# in-place' '- isolation: in-place' > "$ROOT/.streams/inplace/WORKSTREAM.md"
"$FACTS" inplace-scan "$ROOT" > "$OUT"
expect_eq "in-place scan finds recorded stream" "inplace" "$(fact inplace_streams "$OUT")"
printf '%s\n' '# in-place' $'isolation\tin-place' > "$ROOT/.streams/inplace/WORKSTREAM.md"
"$FACTS" inplace-scan "$ROOT" > "$OUT"
expect_eq "in-place scan accepts composed identity grammar" "inplace" "$(fact inplace_streams "$OUT")"
"$FACTS" inplace-state "$ROOT" demo stream/demo main > "$OUT"
expect_eq "root checkout is not holding stream branch" "false" "$(fact on_stream_branch "$OUT")"
expect_eq "root checkout is on target" "true" "$(fact on_target "$OUT")"
expect_eq "in-place state reads handoff custody" "true" "$(fact handoff_parked "$OUT")"
rm -f "$ROOT/.streams/inplace/WORKSTREAM.md"
rmdir "$ROOT/.streams/inplace"

if "$TEARDOWN" "$ROOT" demo --wrong >/dev/null 2>&1; then
  echo "FAIL: teardown accepted an unknown flag" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "rejected teardown preserves worktree" "true" "$([ -d "$WT" ] && echo true || echo false)"

if "$TEARDOWN" "$ROOT" demo >/dev/null 2>&1; then
  echo "FAIL: teardown discarded an uncontained branch without --force" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "uncontained teardown preserves worktree" "true" "$([ -d "$WT" ] && echo true || echo false)"

"$TEARDOWN" "$ROOT" demo --force >/dev/null
expect_eq "teardown removes worktree" "false" "$([ -e "$WT" ] && echo true || echo false)"
expect_eq "teardown removes branch" "false" \
  "$(git -C "$ROOT" show-ref --verify --quiet refs/heads/stream/demo && echo true || echo false)"

sed 's/isolation: worktree/isolation: in-place/' "$DIR/../../templates/streams-config.md" >"$ROOT/.streams/CONFIG.md"
"$RUNTIME" "$ROOT" runtime-init inplace main inplace >"$OUT"
"$TEARDOWN" "$ROOT" inplace >/dev/null
expect_eq 'in-place teardown restores target branch' main "$(git -C "$ROOT" branch --show-current)"
expect_eq 'in-place teardown removes runtime' false "$([ -e "$ROOT/.streams/inplace" ] && echo true || echo false)"
expect_eq 'in-place teardown removes branch' false "$(git -C "$ROOT" show-ref --verify --quiet refs/heads/stream/inplace && echo true || echo false)"

report "git-helpers-test.sh"
