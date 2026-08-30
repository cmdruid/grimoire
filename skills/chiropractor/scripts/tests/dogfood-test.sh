#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SCAN="$HERE/../spine-scan.sh"
TEST_NAME=dogfood-test
export TEST_NAME
# shellcheck source=/dev/null
. "$HERE/lib.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/chiropractor-dogfood.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root="$tmp/project"
cp -R "$HERE/fixtures/dogfood" "$root"
chmod +x "$root"/scripts/*.sh "$root/scripts/private/common.sh"
mv "$root/docs/missing.md" "$tmp/missing-guide.removed"
for n in $(seq -w 1 25); do printf '# Archived decision %s\n' "$n" >"$root/archive/decision-$n.md"; done

mkdir -p "$root/nested-tool/docs"
printf '# Nested tool\n' >"$root/nested-tool/AGENTS.md"
printf '# Nested documentation\n' >"$root/nested-tool/docs/README.md"
git -C "$root/nested-tool" init -q
git -C "$root/nested-tool" add -A
git -C "$root/nested-tool" -c user.name=test -c user.email=test@example.invalid commit -qm nested

git -C "$root" init -q
git -C "$root" add -A 2>/dev/null
git -C "$root" -c user.name=test -c user.email=test@example.invalid commit -qm seed
printf '\nMaintainer staged note.\n' >>"$root/docs/development.md"
git -C "$root" add docs/development.md
printf '\nMaintainer unstaged note.\n' >>"$root/docs/operations.md"
printf '# Local untracked note\n' >"$root/docs/local.md"

git -C "$root" status --short >"$tmp/status.before"
git -C "$root" diff HEAD >"$tmp/diff.before"
shasum -a 256 "$root/docs/local.md" >"$tmp/untracked.before"
"$SCAN" "$root" >"$tmp/facts"
"$SCAN" "$root" --candidates >"$tmp/candidates"
git -C "$root" status --short >"$tmp/status.after"
git -C "$root" diff HEAD >"$tmp/diff.after"
shasum -a 256 "$root/docs/local.md" >"$tmp/untracked.after"

if cmp -s "$tmp/status.before" "$tmp/status.after" && cmp -s "$tmp/diff.before" "$tmp/diff.after" && cmp -s "$tmp/untracked.before" "$tmp/untracked.after"; then ok; else not_ok "dogfood audit changed fixture bytes or status"; fi
require_line "$tmp/facts" 'agents_state=regular'
require_line "$tmp/facts" 'claude_state=regular'
require_line "$tmp/facts" 'claude_imports_agents=1'
require_line "$tmp/facts" 'nested_agents=scoped/AGENTS.md'
require_line "$tmp/facts" 'nested_git_roots=nested-tool'
require_line "$tmp/facts" $'broken_reference=AGENTS.md\tmarkdown\tdocs/missing.md'
require_line "$tmp/facts" $'edge=markdown\trunbooks/release.md\tscripts/release.sh'
require_line "$tmp/facts" $'edge=markdown\tAGENTS.md\tarchive/README.md'
if grep -q '^candidate_truncated=' "$tmp/facts"; then ok; else not_ok "dogfood population did not exceed cap"; fi
if [ "$(sed -n 's/^candidate_count=//p' "$tmp/facts")" = "$(sed -n 's/^candidate_count=//p' "$tmp/candidates")" ]; then ok; else not_ok "dogfood candidate counts drifted"; fi
if [ "$(grep -c $'^dirty_candidate=' "$tmp/facts")" -eq 3 ]; then ok; else not_ok "dogfood dirty population was not staged/unstaged/untracked trio"; fi
reject_text "$tmp/candidates" $'nested-tool/docs/README.md\t'

finish
