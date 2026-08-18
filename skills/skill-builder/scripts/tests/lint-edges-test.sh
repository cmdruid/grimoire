#!/usr/bin/env bash
# lint-edges-test.sh — prove check 8's missing-block WARN by breaking it
# (doctrine: a check is not trusted until it fires on deliberately-broken
# input). Fixtures live in a mktemp dir; nothing touches the library tree.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-edges.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

lib="$TMP/lib"
sk="$lib/skills/widget"
mkdir -p "$sk"

write_skill() { # write_skill <body>
  cat > "$sk/SKILL.md" <<EOF
---
name: widget
description: "A throwaway fixture skill for the missing-edges lint proof."
---

# widget

$1
EOF
}

run_lint() {
  bash "$LINT" "$lib" >"$OUT" 2>"$ERR" || true
}

# --- missing block WARNs (BL-17) ---------------------------------------------
write_skill ''
run_lint
if grep -q 'WARN: widget: SKILL.md has no typed-edge block' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: missing edges block did not WARN" >&2
  echo "      lint out:" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- present (even all-empty) is not the missing-block WARN ------------------
write_skill '## Edges
<!-- edges:widget -->
- produces: — (none)
- handoff: — (none)
- consumes: — (none)
<!-- /edges:widget -->'
run_lint
if grep -q 'WARN: widget: SKILL.md has no typed-edge block' "$OUT"; then
  echo "FAIL: present edges block still matched missing-block WARN" >&2
  grep 'typed-edge block' "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- pack face is exempt -----------------------------------------------------
printf '# face\n' > "$sk/PACK.md"
write_skill ''
run_lint
if grep -q 'WARN: widget: SKILL.md has no typed-edge block' "$OUT"; then
  echo "FAIL: pack face was not exempt from missing-block WARN" >&2
  grep 'typed-edge block' "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "lint-edges-test"
