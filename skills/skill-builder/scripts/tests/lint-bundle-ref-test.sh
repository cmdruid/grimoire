#!/usr/bin/env bash
# lint-bundle-ref-test.sh — prove package-relative specs references resolve locally.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-bundle-ref.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
LIB="$TMP/lib"
SK="$LIB/skills/widget"
OUT="$TMP/out"
mkdir -p "$SK"

write_skill() {
  cat > "$SK/SKILL.md" <<'EOF'
---
name: widget
description: "A throwaway fixture skill for bundle-reference lint proofs."
---

# widget

Follow `specs/contract.md`.

## Edges

<!-- edges:widget -->
- produces: — (none)
- handoff: — (none)
- consumes: — (none)
<!-- /edges:widget -->
EOF
}

write_skill
bash "$LINT" "$LIB" > "$OUT" 2>&1 || true
expect "missing package spec FAILs" \
  "FAIL: widget: SKILL.md references specs/contract.md (not in the bundle)" "$OUT"

mkdir -p "$SK/specs"
printf '# Contract\n' > "$SK/specs/contract.md"
bash "$LINT" "$LIB" > "$OUT" 2>&1 || true
expect_absent "bundled package spec passes" "references specs/contract.md" "$OUT"

report "lint-bundle-ref-test"
