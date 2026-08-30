#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SCAN="$HERE/../spine-scan.sh"
TEST_NAME=walkthrough-branch-test
export TEST_NAME
# shellcheck source=/dev/null
. "$HERE/lib.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/chiropractor-branches.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# 01 — neither door: inventory facts exist, but no root reachability score can be established.
root="$tmp/neither"; mkdir -p "$root"; printf '# Overview\n' >"$root/README.md"; printf 'all:\n\t@true\n' >"$root/Makefile"
"$SCAN" "$root" >"$tmp/neither.facts"
require_line "$tmp/neither.facts" 'agents_state=missing'
require_line "$tmp/neither.facts" 'claude_state=missing'
require_line "$tmp/neither.facts" 'candidate_count=2'
require_line "$tmp/neither.facts" 'reachable_count=0'

# 03 — divergent doors: exact unequal digests and no import force an authority decision.
root="$tmp/divergent"; mkdir -p "$root"; printf 'Build with make.\n' >"$root/AGENTS.md"; printf 'Build with npm.\n' >"$root/CLAUDE.md"
"$SCAN" "$root" >"$tmp/divergent.facts"
require_line "$tmp/divergent.facts" 'claude_imports_agents=0'
agents_digest="$(sed -n 's/^agents_digest=//p' "$tmp/divergent.facts")"
claude_digest="$(sed -n 's/^claude_digest=//p' "$tmp/divergent.facts")"
if [ -n "$agents_digest" ] && [ -n "$claude_digest" ] && [ "$agents_digest" != "$claude_digest" ]; then ok; else not_ok "divergent doors did not expose unequal digests"; fi

# 04 — graph reachability does not repair an ambiguous task label.
root="$tmp/ambiguous"; mkdir -p "$root/docs" "$root/scripts"
printf '%s\n' '# Door' 'Use the [workflows](docs/workflows.md).' >"$root/AGENTS.md"
printf '%s\n' '# Workflows' '[Deploy](../scripts/deploy.sh)' '[Release](../scripts/release.sh)' >"$root/docs/workflows.md"
printf '#!/usr/bin/env bash\n' >"$root/scripts/deploy.sh"; printf '#!/usr/bin/env bash\n' >"$root/scripts/release.sh"
"$SCAN" "$root" >"$tmp/ambiguous.facts"
require_line "$tmp/ambiguous.facts" $'reachable=scripts/deploy.sh\t2'
require_line "$tmp/ambiguous.facts" $'reachable=scripts/release.sh\t2'
if grep -Fq 'Use the [workflows]' "$root/AGENTS.md"; then ok; else not_ok "ambiguous label fixture missing"; fi

# 10 — any changed target invalidates the saved preview digest; nothing is applied.
root="$tmp/stale"; cp -R "$HERE/fixtures/tracer" "$root"
before="$(shasum -a 256 "$root/AGENTS.md" | awk '{print $1}')"
cp "$root/AGENTS.md" "$tmp/stale.preimage"
printf '\nConcurrent maintainer edit.\n' >>"$root/AGENTS.md"
after="$(shasum -a 256 "$root/AGENTS.md" | awk '{print $1}')"
if [ "$before" != "$after" ]; then ok; else not_ok "stale target digest did not change"; fi
if cmp -s "$tmp/stale.preimage" "$root/AGENTS.md"; then not_ok "stale target still matched preview preimage"; else ok; fi

# 12 — a broken executable remains a reported target, never an adjustment target.
root="$tmp/broken-script"; mkdir -p "$root/docs" "$root/scripts"
printf '%s\n' '# Door' '[Release](docs/release.md)' >"$root/AGENTS.md"
printf '%s\n' '# Release' '[Run release](../scripts/release.sh)' >"$root/docs/release.md"
printf '%s\n' '#!/usr/bin/env bash' 'if then' >"$root/scripts/release.sh"; chmod +x "$root/scripts/release.sh"
script_before="$(shasum -a 256 "$root/scripts/release.sh" | awk '{print $1}')"
"$SCAN" "$root" >"$tmp/broken-script.facts"
script_after="$(shasum -a 256 "$root/scripts/release.sh" | awk '{print $1}')"
require_line "$tmp/broken-script.facts" $'edge=markdown\tdocs/release.md\tscripts/release.sh'
if grep -Fqx 'if then' "$root/scripts/release.sh" && [ "$script_before" = "$script_after" ]; then ok; else not_ok "scanner repaired or changed broken script"; fi

finish
