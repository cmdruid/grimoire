#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/skill-feedback-boundary.XXXXXX")"
trap 'rm -rf "$T"' EXIT
H="$T/home"; new_home "$H"
mkdir -p "$T/project" "$T/installed" "$T/fake-bin"
printf 'project-canary\n' > "$T/project/canary"
printf 'installed-canary\n' > "$T/installed/canary"
printf 'legacy\n' > "$H/.agents-legacy-source"
mkdir -p "$H/.agents"; printf 'global instructions\n' > "$H/.agents/AGENTS.md"; printf 'legacy feedback\n' > "$H/.agents/FEEDBACK.md"
cp "$T/project/canary" "$T/project-before"; cp "$T/installed/canary" "$T/installed-before"
cp "$H/.agents/AGENTS.md" "$T/agents-before"; cp "$H/.agents/FEEDBACK.md" "$T/legacy-before"
for name in curl wget ssh scp nc; do
  printf '%s\n' '#!/bin/sh' 'printf invoked >> "${NETWORK_CANARY:?}"' 'exit 99' > "$T/fake-bin/$name"
  chmod +x "$T/fake-bin/$name"
done
NETWORK_CANARY="$T/network" PATH="$T/fake-bin:$PATH" HOME="$H" "$PROVIDER" init >/dev/null
capture_out="$(NETWORK_CANARY="$T/network" PATH="$T/fake-bin:$PATH" capture_one "$H" architect win)"
capture_id="$(printf '%s\n' "$capture_out"|sed -n 's/^captured=//p')"
NETWORK_CANARY="$T/network" PATH="$T/fake-bin:$PATH" HOME="$H" "$PROVIDER" query >/dev/null
NETWORK_CANARY="$T/network" PATH="$T/fake-bin:$PATH" HOME="$H" "$PROVIDER" resolve \
  --entry "$capture_id" rejected 'The observation does not survive revalidation.' '' >/dev/null
[ ! -e "$T/network" ] && pass || fail 'network executable invoked'
same "$T/project/canary" "$T/project-before"
same "$T/installed/canary" "$T/installed-before"
same "$H/.agents/AGENTS.md" "$T/agents-before"
same "$H/.agents/FEEDBACK.md" "$T/legacy-before"
[ -f "$(store_for "$H")" ] && pass || fail 'canonical store missing'
[ ! -e "$H/.agents/skilldata/skill-feedback/../FEEDBACK.md" ] && pass || fail 'legacy migrated into skilldata'

# Red-prove the network detector itself with one counted disposable invocation.
NETWORK_CANARY="$T/network-red" "$T/fake-bin/curl" >/dev/null 2>&1 || true
[ "$(wc -c < "$T/network-red" | tr -d '[:space:]')" = 7 ] && pass || fail 'network detector red proof failed'

finish boundary-test
