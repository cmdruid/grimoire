#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SKILL="$(cd "$HERE/../.." && pwd)"; SKELETON="$SKILL/templates/hooks/byproducts.md"; pass=0 fail=0
ok(){ if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else echo "FAIL $*" >&2; fail=$((fail+1)); fi; }
no(){ if "$@" >/dev/null 2>&1; then echo "FAIL accepted $*" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }
eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail+1)); fi; }

deploy() {
  root="$1"; ws="$2"; case "$ws" in ''|.|/*) return 2;; esac; case "/$ws/" in */../*) return 2;; esac
  [ -f "$SKELETON" ] && [ ! -s "$SKELETON" ] || return 2
  current="$root"; rest="$ws/delegate/hooks"
  while [ -n "$rest" ]; do
    case "$rest" in */*) seg="${rest%%/*}"; rest="${rest#*/}";; *) seg="$rest"; rest="";; esac
    [ -n "$seg" ] || continue; current="$current/$seg"
    [ ! -L "$current" ] || return 2; [ ! -e "$current" ] || [ -d "$current" ] || return 2; [ -d "$current" ] || mkdir "$current"
  done
  dest="$root/$ws/delegate/hooks/byproducts.md"
  [ ! -L "$dest" ] || return 2; [ ! -e "$dest" ] || { [ -f "$dest" ] && return 0; return 2; }
  cp "$SKELETON" "$dest"
}

[ -f "$SKELETON" ] && [ ! -s "$SKELETON" ] && pass=$((pass+1)) || fail=$((fail+1))
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
ok deploy "$ROOT" .dev; eq "fresh zero bytes" "0" "$(wc -c < "$ROOT/.dev/delegate/hooks/byproducts.md" | tr -d ' ')"
ok deploy "$ROOT" .dev
printf 'project policy\n' > "$ROOT/.dev/delegate/hooks/byproducts.md"; sum="$(shasum "$ROOT/.dev/delegate/hooks/byproducts.md" | awk '{print $1}')"; ok deploy "$ROOT" .dev
eq "incumbent preserved" "$sum" "$(shasum "$ROOT/.dev/delegate/hooks/byproducts.md" | awk '{print $1}')"

DECL="$(mktemp -d)"; ok deploy "$DECL" ops; [ -f "$DECL/ops/delegate/hooks/byproducts.md" ] && pass=$((pass+1)) || fail=$((fail+1))
ESC="$(mktemp -d)"; BAD="$(mktemp -d)"; ln -s "$ESC" "$BAD/.dev"; no deploy "$BAD" .dev; eq "parent symlink escape" "0" "$(find "$ESC" -mindepth 1 | wc -l | tr -d ' ')"
DEST="$(mktemp -d)"; mkdir -p "$DEST/.dev/delegate/hooks"; ln -s "$ESC/policy" "$DEST/.dev/delegate/hooks/byproducts.md"; no deploy "$DEST" .dev; [ ! -e "$ESC/policy" ] && pass=$((pass+1)) || fail=$((fail+1))
FILEP="$(mktemp -d)"; mkdir "$FILEP/.dev"; : > "$FILEP/.dev/delegate"; no deploy "$FILEP" .dev
no deploy "$ROOT" ../escape

GITROOT="$(mktemp -d)"; git -C "$GITROOT" init -q; git -C "$GITROOT" config user.email test@example.com; git -C "$GITROOT" config user.name Test
printf '# Fixture\n' > "$GITROOT/README.md"; git -C "$GITROOT" add README.md; git -C "$GITROOT" commit -qm init; ok deploy "$GITROOT" .dev
git -C "$GITROOT" add -- .dev/delegate/hooks/byproducts.md; git -C "$GITROOT" commit -qm 'Delegate: setup' -- .dev/delegate/hooks/byproducts.md
eq "standalone commit clean" "" "$(git -C "$GITROOT" status --porcelain)"
eq "standalone commit one path" ".dev/delegate/hooks/byproducts.md" "$(git -C "$GITROOT" show --pretty='' --name-only HEAD)"

# Red proof: the planted symlink fixture would catch a deploy that followed parents.
MUT="$(mktemp -d)"; TARGET="$(mktemp -d)"; ln -s "$TARGET" "$MUT/.dev"; mkdir -p "$MUT/.dev/delegate/hooks"; cp "$SKELETON" "$MUT/.dev/delegate/hooks/byproducts.md"
[ -f "$TARGET/delegate/hooks/byproducts.md" ] && pass=$((pass+1)) || fail=$((fail+1))

rm -rf "$DECL" "$ESC" "$BAD" "$DEST" "$FILEP" "$MUT" "$TARGET" "$GITROOT"
echo "setup-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
