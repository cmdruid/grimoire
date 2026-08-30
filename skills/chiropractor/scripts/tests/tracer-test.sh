#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SCAN="$HERE/../spine-scan.sh"
TEST_NAME=tracer-test
export TEST_NAME
# shellcheck source=/dev/null
. "$HERE/lib.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/chiropractor-tracer.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cp -R "$HERE/fixtures/tracer/." "$tmp/"
chmod +x "$tmp/scripts/release.sh"
git -C "$tmp" init -q
git -C "$tmp" add AGENTS.md README.md docs/setup.md scripts/release.sh
git -C "$tmp" -c user.name=test -c user.email=test@example.invalid commit -qm seed
printf '# New operational note\n' >"$tmp/docs/untracked.md"

before="$tmp.before"
git -C "$tmp" status --porcelain=v1 --untracked-files=all >"$before"
facts="$tmp.facts"; candidates="$tmp.candidates"
"$SCAN" "$tmp" >"$facts"
"$SCAN" "$tmp" --candidates >"$candidates"
after="$tmp.after"
git -C "$tmp" status --porcelain=v1 --untracked-files=all >"$after"
if cmp -s "$before" "$after"; then ok; else not_ok "scanner mutated tracer fixture"; fi

require_line "$facts" 'agents_state=regular'
require_line "$facts" $'edge=markdown\tAGENTS.md\tdocs/setup.md'
require_line "$facts" $'edge=markdown\tdocs/setup.md\tscripts/release.sh'
if grep -F $'candidate\tdocs/untracked.md\tdocumentation\tuntracked\t' "$candidates" >/dev/null; then ok; else not_ok "untracked candidate missing"; fi
fact_count="$(sed -n 's/^candidate_count=//p' "$facts")"
full_count="$(sed -n 's/^candidate_count=//p' "$candidates")"
if [ "$fact_count" = "$full_count" ]; then ok; else not_ok "candidate modes disagree"; fi
if [ "$(grep -c $'^candidate\t' "$candidates")" = "$full_count" ]; then ok; else not_ok "candidate rows do not match count"; fi

# Red-proof the route assertion in a disposable copy: remove exactly one live edge, demand red,
# restore byte-identically, then demand green again.
cp "$tmp/AGENTS.md" "$tmp/AGENTS.before"
count="$(grep -cF '[setup guide](docs/setup.md)' "$tmp/AGENTS.md")"
if [ "$count" -eq 1 ]; then ok; else not_ok "route plant precondition count=$count"; fi
sed 's|\[setup guide\](docs/setup.md)|setup guide|' "$tmp/AGENTS.md" >"$tmp/AGENTS.changed"
mv "$tmp/AGENTS.changed" "$tmp/AGENTS.md"
"$SCAN" "$tmp" >"$tmp.red"
if grep -Fqx $'edge=markdown\tAGENTS.md\tdocs/setup.md' "$tmp.red"; then
  not_ok "route guard stayed green after removal"
else
  ok
fi
cp "$tmp/AGENTS.before" "$tmp/AGENTS.md"
if cmp -s "$tmp/AGENTS.before" "$tmp/AGENTS.md"; then ok; else not_ok "route fixture restore drifted"; fi
"$SCAN" "$tmp" >"$tmp.green"
if grep -Fqx $'edge=markdown\tAGENTS.md\tdocs/setup.md' "$tmp.green"; then ok; else not_ok "restored route stayed red"; fi

finish
