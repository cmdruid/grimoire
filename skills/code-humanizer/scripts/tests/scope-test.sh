#!/usr/bin/env bash
# scope-test.sh — throwaway git fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

SCOPE="$SKILL/scripts/scope.sh"
chmod +x "$SCOPE"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/code-humanizer-scope.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# --- non-git root ---
mkdir -p "$tmp/nogit"
out="$("$SCOPE" "$tmp/nogit" 2>/dev/null)" || rc=$?
rc="${rc:-0}"
expect_eq "non-git exits 2" "2" "$rc"
expect_eq "non-git git=0" "0" "$(kv git "$out")"

# --- dirty tree uses uncommitted files, not last commit ---
repo="$tmp/dirty"
init_git_repo "$repo"
printf 'fn committed() {}\n' > "$repo/old.rs"
git -C "$repo" add old.rs
git -C "$repo" commit -q -m old
printf 'fn dirty() {}\n' > "$repo/new.rs"
printf 'fn also() {}\n' > "$repo/tracked.rs"
git -C "$repo" add tracked.rs
printf '# notes\n' > "$repo/README.md"
out="$("$SCOPE" "$repo")" || true
expect_eq "dirty scope=diff" "diff" "$(kv scope "$out")"
expect_eq "dirty selected" "2" "$(kv selected "$out")"
expect_match "dirty includes new.rs" '^file=new\.rs$' "$out"
expect_match "dirty includes tracked.rs" '^file=tracked\.rs$' "$out"
expect_absent_match "dirty omits last-commit old.rs" '^file=old\.rs$' "$out"
expect_absent_match "dirty omits markdown" '^file=README\.md$' "$out"

# --- clean tree uses last commit ---
clean="$tmp/clean"
init_git_repo "$clean"
printf 'fn a() {}\n' > "$clean/a.rs"
printf 'fn b() {}\n' > "$clean/b.py"
printf 'docs\n' > "$clean/notes.md"
git -C "$clean" add a.rs b.py notes.md
git -C "$clean" commit -q -m first
out="$("$SCOPE" "$clean")" || true
expect_eq "clean scope=last-commit" "last-commit" "$(kv scope "$out")"
expect_eq "clean selected" "2" "$(kv selected "$out")"
expect_match "clean includes a.rs" '^file=a\.rs$' "$out"
expect_match "clean includes b.py" '^file=b\.py$' "$out"
expect_absent_match "clean omits notes.md" '^file=notes\.md$' "$out"

# --- named file path ---
out="$("$SCOPE" "$clean" --path a.rs)" || true
expect_eq "path-file scope" "path" "$(kv scope "$out")"
expect_eq "path-file selected" "1" "$(kv selected "$out")"
expect_eq "path-file path_arg" "a.rs" "$(kv path_arg "$out")"
expect_eq "path-file only a.rs" "a.rs" "$(files_of "$out")"

# --- named directory ---
mkdir -p "$clean/pkg"
printf 'fn p() {}\n' > "$clean/pkg/p.rs"
printf 'fn q() {}\n' > "$clean/pkg/q.rs"
git -C "$clean" add pkg
git -C "$clean" commit -q -m pkg
out="$("$SCOPE" "$clean" --path pkg)" || true
expect_eq "path-dir selected" "2" "$(kv selected "$out")"
expect_match "path-dir p.rs" '^file=pkg/p\.rs$' "$out"
expect_match "path-dir q.rs" '^file=pkg/q\.rs$' "$out"
expect_absent_match "path-dir excludes sibling a.rs" '^file=a\.rs$' "$out"

# --- cap truncates ---
caprepo="$tmp/cap"
init_git_repo "$caprepo"
i=1
while [ "$i" -le 5 ]; do
  printf 'fn f() {}\n' > "$caprepo/f$i.rs"
  i=$((i + 1))
done
git -C "$caprepo" add .
git -C "$caprepo" commit -q -m five
out="$("$SCOPE" "$caprepo" --cap 2)" || true
expect_eq "cap selected" "2" "$(kv selected "$out")"
expect_eq "cap total" "5" "$(kv total "$out")"
expect_eq "cap omitted" "3" "$(kv omitted "$out")"
file_n="$(files_of "$out" | sed '/^$/d' | wc -l | tr -d ' ')"
expect_eq "cap file lines" "2" "$file_n"

# --- excluded vendor path ---
vend="$tmp/vend"
init_git_repo "$vend"
mkdir -p "$vend/src" "$vend/vendor/pkg"
printf 'fn s() {}\n' > "$vend/src/s.rs"
printf 'fn v() {}\n' > "$vend/vendor/pkg/v.rs"
git -C "$vend" add -f src vendor
git -C "$vend" commit -q -m vend
out="$("$SCOPE" "$vend" --path .)" || true
expect_eq "vendor omitted from path ." "1" "$(kv selected "$out")"
expect_match "vendor keeps src" '^file=src/s\.rs$' "$out"
expect_absent_match "vendor drops vendor/" 'vendor/' "$out"

# --- missing path ---
rc=0
"$SCOPE" "$clean" --path no-such.rs >/dev/null 2>"$tmp/err" || rc=$?
expect_eq "missing path exits 2" "2" "$rc"

finish
