#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SKILL="$(cd "$HERE/../.." && pwd)"; SKELETON="$SKILL/templates/hooks/byproducts.md"; SETUP="$SKILL/scripts/delegate-setup.sh"; pass=0 fail=0
ok(){ if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else echo "FAIL $*" >&2; fail=$((fail+1)); fi; }
no(){ if "$@" >/dev/null 2>&1; then echo "FAIL accepted $*" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }
eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail+1)); fi; }

deploy() {
  root="$1"; ws="$2"
  [ "$ws" = .spaces ] || printf 'agent-workspace: %s\n' "$ws" > "$root/AGENTS.md"
  "$SETUP" --write-only "$root" >/dev/null
}

[ -f "$SKELETON" ] && [ ! -s "$SKELETON" ] && pass=$((pass+1)) || fail=$((fail+1))
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
ok deploy "$ROOT" .spaces; eq "fresh zero bytes" "0" "$(wc -c < "$ROOT/.spaces/delegate/hooks/byproducts.md" | tr -d ' ')"
ok deploy "$ROOT" .spaces
printf 'project policy\n' > "$ROOT/.spaces/delegate/hooks/byproducts.md"; sum="$(shasum "$ROOT/.spaces/delegate/hooks/byproducts.md" | awk '{print $1}')"; ok deploy "$ROOT" .spaces
eq "incumbent preserved" "$sum" "$(shasum "$ROOT/.spaces/delegate/hooks/byproducts.md" | awk '{print $1}')"

DECL="$(mktemp -d)"; ok deploy "$DECL" ops; [ -f "$DECL/ops/delegate/hooks/byproducts.md" ] && pass=$((pass+1)) || fail=$((fail+1))
ESC="$(mktemp -d)"; BAD="$(mktemp -d)"; ln -s "$ESC" "$BAD/.spaces"; no deploy "$BAD" .spaces; eq "parent symlink escape" "0" "$(find "$ESC" -mindepth 1 | wc -l | tr -d ' ')"
DEST="$(mktemp -d)"; mkdir -p "$DEST/.spaces/delegate/hooks"; ln -s "$ESC/policy" "$DEST/.spaces/delegate/hooks/byproducts.md"; no deploy "$DEST" .spaces; [ ! -e "$ESC/policy" ] && pass=$((pass+1)) || fail=$((fail+1))
FILEP="$(mktemp -d)"; mkdir "$FILEP/.spaces"; : > "$FILEP/.spaces/delegate"; no deploy "$FILEP" .spaces
BADDECL="$(mktemp -d)"; printf 'agent-workspace: ../escape\n' > "$BADDECL/AGENTS.md"; no "$SETUP" --write-only "$BADDECL"

GITROOT="$(mktemp -d)"; git -C "$GITROOT" init -q; git -C "$GITROOT" config user.email test@example.com; git -C "$GITROOT" config user.name Test
printf '# Fixture\n' > "$GITROOT/README.md"; git -C "$GITROOT" add README.md; git -C "$GITROOT" commit -qm init; ok "$SETUP" "$GITROOT"
eq "standalone commit clean" "" "$(git -C "$GITROOT" status --porcelain)"
eq "standalone commit one path" ".spaces/delegate/hooks/byproducts.md" "$(git -C "$GITROOT" show --pretty='' --name-only HEAD)"
HEAD1="$(git -C "$GITROOT" rev-parse HEAD)"; ok "$SETUP" "$GITROOT"
eq "single-asset no-op makes no commit" "$HEAD1" "$(git -C "$GITROOT" rev-parse HEAD)"

RACE="$(mktemp -d)"; mkdir -p "$RACE/.spaces/delegate" "$RACE/elsewhere"; HOOK="$RACE/exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/delegate" "$1/held"' 'ln -s "$1/elsewhere" "$1/$2/delegate"' > "$HOOK"; chmod +x "$HOOK"
if DELEGATE_SETUP_TEST_AFTER_PREFLIGHT="$HOOK" "$SETUP" --write-only "$RACE" >/dev/null 2>&1; then fail=$((fail+1)); else pass=$((pass+1)); fi
[ ! -e "$RACE/elsewhere/hooks/byproducts.md" ] && pass=$((pass+1)) || fail=$((fail+1))

# Red proof: the planted symlink fixture would catch a deploy that followed parents.
MUT="$(mktemp -d)"; TARGET="$(mktemp -d)"; ln -s "$TARGET" "$MUT/.spaces"; mkdir -p "$MUT/.spaces/delegate/hooks"; cp "$SKELETON" "$MUT/.spaces/delegate/hooks/byproducts.md"
[ -f "$TARGET/delegate/hooks/byproducts.md" ] && pass=$((pass+1)) || fail=$((fail+1))

rm -rf "$DECL" "$ESC" "$BAD" "$DEST" "$FILEP" "$MUT" "$TARGET" "$GITROOT" "$BADDECL" "$RACE"
echo "setup-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
