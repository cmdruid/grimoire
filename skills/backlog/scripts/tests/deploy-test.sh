#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SKILL="$(cd "$HERE/../.." && pwd)"; SETUP="$SKILL/scripts/backlog-setup.sh"; REG="$SKILL/scripts/register-route.sh"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT; pass=0 fail=0
ok(){ if "$@" >/dev/null 2>&1; then pass=$((pass+1)); else echo "FAIL $*" >&2; fail=$((fail+1)); fi; }
no(){ if "$@" >/dev/null 2>&1; then echo "FAIL accepted $*" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }
has(){ if grep -qF -- "$2" "$1"; then pass=$((pass+1)); else echo "FAIL missing $2" >&2; fail=$((fail+1)); fi; }

# Listing is inspection for the proposal phase and must not deploy anything.
out="$("$SETUP" "$ROOT" --workspace .spaces --list)"
has <(printf '%s\n' "$out") 'stem=tasks'
[ ! -e "$ROOT/.spaces" ] && pass=$((pass+1)) || { echo 'FAIL --list wrote project config' >&2; fail=$((fail+1)); }

out="$("$SETUP" "$ROOT" --workspace .spaces --apply tasks)"
has <(printf '%s\n' "$out") 'wrote=.spaces/backlog/scripts/trackers.sh'
has "$ROOT/AGENTS.md" '<!-- skill:backlog BEGIN built-against:'
has "$ROOT/AGENTS.md" "\`.spaces/backlog/\`"
out="$("$SETUP" "$ROOT" --workspace .spaces --apply --custom decisions)"
has "$ROOT/.spaces/backlog/hooks/debrief.md" '## decisions'
sum="$(shasum "$ROOT/.spaces/backlog/trackers/tasks.tsv" | awk '{print $1}')"; out="$("$SETUP" "$ROOT" --workspace .spaces --apply tasks)"
[ "$sum" = "$(shasum "$ROOT/.spaces/backlog/trackers/tasks.tsv" | awk '{print $1}')" ] && pass=$((pass+1)) || fail=$((fail+1))
if printf '%s\n' "$out" | grep -q '^wrote='; then echo "FAIL rerun wrote: $out" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi

printf '# drift\n' > "$ROOT/.spaces/backlog/scripts/trackers.sh"; out="$("$SETUP" "$ROOT" --workspace .spaces --apply tasks)"; has <(printf '%s\n' "$out") 'wrote=.spaces/backlog/scripts/trackers.sh'
cmp "$SKILL/scripts/trackers.sh" "$ROOT/.spaces/backlog/scripts/trackers.sh" >/dev/null && pass=$((pass+1)) || fail=$((fail+1))

cp "$ROOT/AGENTS.md" "$ROOT/door.before"; printf '\n<!-- skill:backlog BEGIN broken -->\n' >> "$ROOT/AGENTS.md"
no "$SETUP" "$ROOT" --workspace .spaces --apply issues
[ ! -e "$ROOT/.spaces/backlog/trackers/issues.tsv" ] && pass=$((pass+1)) || fail=$((fail+1))
mv "$ROOT/door.before" "$ROOT/AGENTS.md"

SAFE="$(mktemp -d)"; ln -s "$SAFE" "$ROOT/bad"; no "$SETUP" "$ROOT" --workspace bad --apply tasks
[ "$(find "$SAFE" -mindepth 1 | wc -l | tr -d ' ')" = 0 ] && pass=$((pass+1)) || fail=$((fail+1))

RACE="$(mktemp -d)"; mkdir -p "$RACE/.spaces/backlog" "$RACE/elsewhere"; HOOK="$RACE/exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/backlog" "$1/held"' 'ln -s "$1/elsewhere" "$1/$2/backlog"' > "$HOOK"; chmod +x "$HOOK"
if BACKLOG_SETUP_TEST_AFTER_PREFLIGHT="$HOOK" "$SETUP" "$RACE" --workspace .spaces --apply tasks >/dev/null 2>&1; then
  echo 'FAIL backlog accepted post-preflight exchange' >&2; fail=$((fail+1))
else pass=$((pass+1)); fi
[ ! -e "$RACE/elsewhere/scripts/trackers.sh" ] && pass=$((pass+1)) || fail=$((fail+1))

PARTIAL="$(mktemp -d)"; WRITE_HOOK="$PARTIAL/stop-after-tool.sh"
printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0' > "$WRITE_HOOK"; chmod +x "$WRITE_HOOK"
if BACKLOG_SETUP_TEST_AFTER_WRITE="$WRITE_HOOK" "$SETUP" "$PARTIAL" --workspace .spaces --apply tasks >"$PARTIAL/out" 2>&1; then
  echo 'FAIL backlog post-tool interruption was not exercised' >&2; fail=$((fail+1))
else pass=$((pass+1)); fi
has "$PARTIAL/out" 'wrote=.spaces/backlog/scripts/trackers.sh'
[ ! -e "$PARTIAL/.spaces/backlog/trackers/tasks.tsv" ] && pass=$((pass+1)) || fail=$((fail+1))
ok "$SETUP" "$PARTIAL" --workspace .spaces --apply tasks
[ -f "$PARTIAL/.spaces/backlog/trackers/tasks.tsv" ] && pass=$((pass+1)) || fail=$((fail+1))
has "$PARTIAL/AGENTS.md" '<!-- skill:backlog BEGIN built-against:'

ok "$REG" preflight --root "$ROOT" --workspace .spaces
ok "$REG" remove --root "$ROOT" --workspace .spaces
grep -q 'skill:backlog' "$ROOT/AGENTS.md" && { echo 'FAIL route remained' >&2; fail=$((fail+1)); } || pass=$((pass+1))

# Standalone custody: all setup paths enter one scoped commit; rerun adds none.
GITROOT="$(mktemp -d)"; git -C "$GITROOT" init -q; git -C "$GITROOT" config user.email test@example.com; git -C "$GITROOT" config user.name Test
printf '# Fixture\n' > "$GITROOT/README.md"; git -C "$GITROOT" add README.md; git -C "$GITROOT" commit -qm init
out="$("$SETUP" "$GITROOT" --workspace .spaces --apply tasks issues)"
paths=(); while IFS= read -r p; do [ -n "$p" ] && paths+=("$p"); done < <(printf '%s\n' "$out" | sed -n -e 's/^wrote=//p' -e 's/^removed=//p' | sort -u)
[ "${#paths[@]}" -gt 0 ] || { echo 'FAIL setup reported no changed paths' >&2; exit 1; }
"$SKILL/scripts/scoped-commit.sh" "$GITROOT" "Backlog: setup" "${paths[@]}" >/dev/null
[ -z "$(git -C "$GITROOT" status --porcelain)" ] && pass=$((pass+1)) || fail=$((fail+1))
count="$(git -C "$GITROOT" rev-list --count HEAD)"; out="$("$SETUP" "$GITROOT" --workspace .spaces --apply tasks issues)"
if printf '%s\n' "$out" | grep -q '^wrote='; then fail=$((fail+1)); else pass=$((pass+1)); fi
[ "$count" = "$(git -C "$GITROOT" rev-list --count HEAD)" ] && pass=$((pass+1)) || fail=$((fail+1))

rm -rf "$GITROOT"
echo "deploy-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
