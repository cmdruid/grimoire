#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-identity.XXXXXX")"
trap 'rm -rf "$T"' EXIT

R="$T/root"; mkdir -p "$R/scripts"
printf '%s' $'---\nname: root\n---\n\n# Root\n' > "$R/SKILL.md"
printf '%s' $'#!/bin/sh\necho root\n' > "$R/scripts/run.sh"; chmod 755 "$R/scripts/run.sh"
actual="$($IDENTITY "$R")"
[ "$actual" = content-sha256:dac22413d43775828b480b061dc43077cf4cae3c34b6d00570fa635f2ad6122a ] && pass || fail "root golden mismatch: $actual"

H="$T/helper"; mkdir -p "$H"
printf '%s' $'---\nname: helper\n---\n\n# Helper\n' > "$H/SKILL.md"
ln -s SKILL.md "$H/copy.md"
actual="$($IDENTITY "$H")"
[ "$actual" = content-sha256:d98827d1aec853458ed2d203a4728cc308ce9dc3a9a96da1ad3e424087105abb ] && pass || fail "symlink golden mismatch: $actual"

mkdir -p "$R/.git" "$R/fixtures"; printf 'ignored\n' > "$R/.git/config"; printf 'ignored\n' > "$R/fixtures/data"
[ "$($IDENTITY "$R")" = content-sha256:dac22413d43775828b480b061dc43077cf4cae3c34b6d00570fa635f2ad6122a ] && pass || fail 'ignored substrate changed identity'

ln -s "$T/nope" "$T/link-root"
has_unknown="$($IDENTITY "$T/link-root")"
case "$has_unknown" in 'unknown reason='*) pass ;; *) fail 'unsafe root did not return unknown' ;; esac

finish skill-content-ref-test
