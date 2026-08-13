#!/usr/bin/env bash
# lint-exemption-test.sh — the lint gate's pack-face exemption, proven both ways on a
# throwaway mini-library: a face (PACK.md present) naming a sibling is exempt from the
# sibling-in-description check; the same prose in a non-face still warns; removing the
# PACK.md removes the exemption. Guards the v2 recalibration (core:-key removal).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/../../.." && pwd)/skill-builder/scripts/skills-lint.sh"
. "$DIR/lib.sh"

[ -f "$LINT" ] || { echo "SKIP: skills-lint.sh not present at $LINT (standalone install)"; exit 0; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-lint-exemption-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"

lib="$TMP/lib"
mkdir -p "$lib/skills/aface" "$lib/skills/bhelper"
printf -- '---\nname: aface\ndescription: "A face that names `/bhelper` directly."\n---\n# aface\n' > "$lib/skills/aface/SKILL.md"
printf -- '---\nname: aface\nversion: 1.0.0\ndescription: "pack"\nrequired: bhelper\n---\n# pack\n' > "$lib/skills/aface/PACK.md"
printf -- '---\nname: bhelper\ndescription: "A helper that names `/aface` directly."\n---\n# bhelper\n' > "$lib/skills/bhelper/SKILL.md"

bash "$LINT" "$lib" >"$OUT" 2>&1 || true
expect "non-face sibling ref warns" "bhelper: description names sibling \`/aface\`" "$OUT"
expect_absent "face sibling ref exempt" "aface: description names sibling" "$OUT"

rm "$lib/skills/aface/PACK.md"
bash "$LINT" "$lib" >"$OUT" 2>&1 || true
expect "exemption gone without PACK.md" "aface: description names sibling \`/bhelper\`" "$OUT"

report "lint-exemption-test"
