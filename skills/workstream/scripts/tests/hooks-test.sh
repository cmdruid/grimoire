#!/usr/bin/env bash
# hooks-test.sh — owner-first, one-file-per-seam hook proofs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"

HOOKS_SH="$(cd "$DIR/.." && pwd)/hooks.sh"
SKELETONS="$(cd "$DIR/../.." && pwd)/templates/hooks"
HANDOFF_TPL="$(cd "$DIR/../.." && pwd)/templates/workstream-handoff.md"
KNOWN=(--known feature-completion --known after-eventful-ship)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

fact() { sed -n -E "s/^$1=//p" "$2" | head -n 1; }
hash_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# Missing directory is a read-only empty population.
missing="$TMP/missing/workstream/hooks"
rc=0
"$HOOKS_SH" parse --dir "$missing" "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing parse rc" "0" "$rc"
expect_eq "missing status" "missing" "$(fact status "$OUT")"
expect_eq "missing first seam empty" "empty" "$(fact hook_feature_completion "$OUT")"
expect_eq "missing second seam empty" "empty" "$(fact hook_after_eventful_ship "$OUT")"
[ ! -e "$TMP/missing" ] && pass=$((pass + 1)) || {
  echo "FAIL: parse created a missing directory" >&2; fail=$((fail + 1)); }

# Parser reads only its canonical population and hashes it deterministically.
hooks="$TMP/project/.dev/workstream/hooks"
mkdir -p "$hooks"
printf '%s\n' '# Feature completion' '' '/backlog debrief' > "$hooks/feature-completion.md"
printf '%s\n' '# After eventful ship' '' > "$hooks/after-eventful-ship.md"
printf '%s\n' '# Unrelated' '' 'ignore me' > "$hooks/unrelated.md"
"$HOOKS_SH" parse --dir "$hooks" "${KNOWN[@]}" >"$OUT"
expect_eq "known filled" "filled" "$(fact hook_feature_completion "$OUT")"
expect_eq "known whitespace body empty" "empty" "$(fact hook_after_eventful_ship "$OUT")"
expect_absent "unrelated file ignored" "ignore me" "$OUT"
h1=$(fact hash "$OUT")
printf '%s\n' '# Unrelated changed' > "$hooks/unrelated.md"
"$HOOKS_SH" parse --dir "$hooks" "${KNOWN[@]}" >"$OUT"
expect_eq "unrelated file does not change population hash" "$h1" "$(fact hash "$OUT")"
printf '%s\n' '# Feature completion' '' '/backlog debrief' '' 'extra' > "$hooks/feature-completion.md"
"$HOOKS_SH" parse --dir "$hooks" "${KNOWN[@]}" >"$OUT"
h2=$(fact hash "$OUT")
[ "$h1" != "$h2" ] && pass=$((pass + 1)) || {
  echo "FAIL: known-file edit did not change population hash" >&2; fail=$((fail + 1)); }

# Compile snapshots both canonical seam files into the handoff.
handoff="$TMP/WORKSTREAM.md"
cp "$HANDOFF_TPL" "$handoff"
rc=0
"$HOOKS_SH" compile --dir "$hooks" --handoff "$handoff" --root "$TMP/project" \
  "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "compile rc" "0" "$rc"
"$HOOKS_SH" compiled-get --handoff "$handoff" >"$OUT"
expect "compile body" "/backlog debrief" "$OUT"
expect "compile empty seam" "after-eventful-ship:" "$OUT"
expect "compile owner-first source" ".dev/workstream/hooks @" "$OUT"
expect_absent "compile ignores unrelated" "ignore me" "$OUT"

# Materialize safely creates only the owner/kind path, absent-only.
root="$TMP/materialize"
mkdir -p "$root"
target="$root/.dev/workstream/hooks"
rc=0
"$HOOKS_SH" materialize --root "$root" --dir "$target" --skeleton-dir "$SKELETONS" \
  "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "materialize rc" "0" "$rc"
expect_eq "materialize created count" "2" "$(fact created "$OUT")"
[ -f "$target/feature-completion.md" ] && pass=$((pass + 1)) || {
  echo "FAIL: feature-completion skeleton missing" >&2; fail=$((fail + 1)); }
retired_hooks="$root/.dev/"hooks
[ ! -e "$retired_hooks" ] && pass=$((pass + 1)) || {
  echo "FAIL: retired top-level hooks directory created" >&2; fail=$((fail + 1)); }
printf '%s\n' 'project-owned' > "$target/feature-completion.md"
sum=$(hash_of "$target/feature-completion.md")
"$HOOKS_SH" materialize --root "$root" --dir "$target" --skeleton-dir "$SKELETONS" \
  "${KNOWN[@]}" >"$OUT"
expect_eq "materialize incumbent count" "0" "$(fact created "$OUT")"
expect_eq "materialize incumbent unchanged" "$sum" "$(hash_of "$target/feature-completion.md")"

# Unsafe parents and relative destinations fail before writes.
unsafe="$TMP/unsafe"
mkdir -p "$unsafe/real"
ln -s "$unsafe/real" "$unsafe/link"
rc=0
"$HOOKS_SH" materialize --root "$unsafe" --dir "$unsafe/link/workstream/hooks" \
  --skeleton-dir "$SKELETONS" "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "symlink parent rejected" "2" "$rc"
[ ! -e "$unsafe/real/workstream" ] && pass=$((pass + 1)) || {
  echo "FAIL: symlink target was mutated" >&2; fail=$((fail + 1)); }
rc=0
"$HOOKS_SH" parse --dir .dev/workstream/hooks "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "relative dir rejected" "2" "$rc"

# Compiled span survives a handoff template rewrite.
"$HOOKS_SH" compiled-get --handoff "$handoff" > "$TMP/span"
span_sum=$(hash_of "$TMP/span")
cp "$HANDOFF_TPL" "$handoff"
"$HOOKS_SH" compiled-put --handoff "$handoff" < "$TMP/span"
"$HOOKS_SH" compiled-get --handoff "$handoff" > "$TMP/span-after"
expect_eq "compiled span preserved" "$span_sum" "$(hash_of "$TMP/span-after")"

report "hooks-test.sh"
