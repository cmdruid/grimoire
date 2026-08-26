#!/usr/bin/env bash
# setup-test.sh — explicit Notepad deployment, custody, and safety fixtures.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
SETUP="$HERE/../notepad-setup.sh"
pass=0 fail=0

ok() { if "$@"; then pass=$((pass + 1)); else echo "FAIL: $*" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL: $1 — want <$2>, got <$3>" >&2; fail=$((fail + 1)); fi; }
has() { if printf '%s\n' "$3" | grep -qF -- "$2"; then pass=$((pass + 1)); else echo "FAIL: $1 — missing <$2>" >&2; fail=$((fail + 1)); fi; }
absent() { if [ ! -e "$2" ] && [ ! -L "$2" ]; then pass=$((pass + 1)); else echo "FAIL: $1 — exists: $2" >&2; fail=$((fail + 1)); fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/notepad-setup.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

new_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.name Fixture
  git -C "$dir" config user.email fixture@example.invalid
  printf '# Fixture\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -qm init
}

# Standalone setup commits only its reported write and leaves unrelated index
# and working-tree changes exactly where it found them.
ROOT="$TMP/standalone"; new_repo "$ROOT"
printf 'staged base\n' > "$ROOT/staged.txt"
printf 'unstaged base\n' > "$ROOT/unstaged.txt"
git -C "$ROOT" add staged.txt unstaged.txt
git -C "$ROOT" commit -qm fixtures
printf 'staged change\n' > "$ROOT/staged.txt"; git -C "$ROOT" add staged.txt
printf 'unstaged change\n' > "$ROOT/unstaged.txt"
OUT="$(bash "$SETUP" "$ROOT")"
DEST="$ROOT/.spaces/notepad/templates/notes.md"
ok test -f "$DEST"
has "created report" 'created=.spaces/notepad/templates/notes.md' "$OUT"
has "commit report" 'committed=.spaces/notepad/templates/notes.md' "$OUT"
eq "standalone commit exact path" '.spaces/notepad/templates/notes.md' "$(git -C "$ROOT" show --pretty='' --name-only HEAD | sed '/^$/d')"
eq "unrelated staged state survives" 'M  staged.txt' "$(git -C "$ROOT" status --short staged.txt)"
eq "unrelated unstaged state survives" ' M unstaged.txt' "$(git -C "$ROOT" status --short unstaged.txt)"
HEAD1="$(git -C "$ROOT" rev-parse HEAD)"
OUT="$(bash "$SETUP" "$ROOT")"
eq "no-op rerun makes no commit" "$HEAD1" "$(git -C "$ROOT" rev-parse HEAD)"
has "no-op reports zero writes" 'writes=0' "$OUT"

# A declared sweep is write-only; member history remains unchanged.
SWEEP="$TMP/sweep"; new_repo "$SWEEP"; BEFORE="$(git -C "$SWEEP" rev-parse HEAD)"
OUT="$(bash "$SETUP" --write-only "$SWEEP")"
eq "write-only makes no commit" "$BEFORE" "$(git -C "$SWEEP" rev-parse HEAD)"
has "write-only returns custody" 'commit=caller' "$OUT"
eq "write-only leaves one owner path" '?? .spaces/' "$(git -C "$SWEEP" status --short)"

# Incumbent and legacy behavior.
printf '\nPROJECT CUSTOMIZATION\n' >> "$DEST"; CUSTOM="$(cksum "$DEST")"; HEAD2="$(git -C "$ROOT" rev-parse HEAD)"
bash "$SETUP" "$ROOT" >/dev/null
eq "incumbent preserved byte-for-byte" "$CUSTOM" "$(cksum "$DEST")"
eq "incumbent makes no commit" "$HEAD2" "$(git -C "$ROOT" rev-parse HEAD)"

LEG="$TMP/legacy"; new_repo "$LEG"; mkdir -p "$LEG/.records/templates/notepad"
printf '# Legacy\n' > "$LEG/.records/templates/notepad/notes.md"
if bash "$SETUP" --write-only "$LEG" >"$TMP/out" 2>&1; then echo "FAIL: legacy accepted" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi
has "legacy names migrate" '/notepad migrate' "$(cat "$TMP/out")"
absent "legacy not adopted" "$LEG/.spaces/notepad/templates/notes.md"

# Unsafe preflight and post-preflight parent exchange both refuse.
UNSAFE="$TMP/unsafe"; mkdir -p "$UNSAFE/elsewhere"; ln -s "$UNSAFE/elsewhere" "$UNSAFE/.spaces"
if bash "$SETUP" --write-only "$UNSAFE" >"$TMP/out" 2>&1; then echo "FAIL: symlink parent accepted" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi
absent "preflight writes nothing through symlink" "$UNSAFE/elsewhere/notepad/templates/notes.md"

RACE="$TMP/recheck"; mkdir -p "$RACE/.spaces/notepad" "$RACE/elsewhere"
HOOK="$TMP/exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/notepad" "$1/held-notepad"' 'ln -s "$1/elsewhere" "$1/$2/notepad"' > "$HOOK"
chmod +x "$HOOK"
if NOTEPAD_SETUP_TEST_AFTER_PREFLIGHT="$HOOK" bash "$SETUP" --write-only "$RACE" >"$TMP/out" 2>&1; then echo "FAIL: exchanged parent accepted" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi
has "recheck names symlink" 'symlinked destination parent' "$(cat "$TMP/out")"
absent "recheck writes nothing through link" "$RACE/elsewhere/templates/notes.md"

# Test-only inventory injections red-prove package and owner boundaries.
BOUND="$TMP/boundary"; mkdir -p "$BOUND"
if NOTEPAD_SETUP_TEST_ASSET='../SKILL.md' bash "$SETUP" --write-only "$BOUND" >/dev/null 2>&1; then echo "FAIL: package-only asset accepted" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi
if NOTEPAD_SETUP_TEST_DEST_REL='.spaces/delegate/templates/notes.md' bash "$SETUP" --write-only "$BOUND" >/dev/null 2>&1; then echo "FAIL: sibling destination accepted" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi
absent "boundary injections create no workspace" "$BOUND/.spaces"

echo "setup-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
