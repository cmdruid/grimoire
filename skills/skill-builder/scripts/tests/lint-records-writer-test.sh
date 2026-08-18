#!/usr/bin/env bash
# lint-records-writer-test.sh — prove the two records-writer lint checks by
# breaking them (doctrine: a check is not trusted until it FAILs on
# deliberately-broken input). Fixtures live in a mktemp dir; nothing
# touches the library's own tree.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-records.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

# A throwaway library with one non-exempt skill. Other lint checks will
# also fire (symlink, README); we assert only the records-writer FAIL
# strings this suite owns.
lib="$TMP/lib"
sk="$lib/skills/widget"
mkdir -p "$sk"

write_skill() { # write_skill <body-extra>
  cat > "$sk/SKILL.md" <<EOF
---
name: widget
description: "A throwaway fixture skill for records-writer lint proofs."
---

# widget

$1
EOF
}

run_lint() {
  SKILLS_LINT_FLOOR=1 bash "$LINT" "$lib" >"$OUT" 2>"$ERR" || true
}

# --- check 12: journal-floor phrase ------------------------------------------
write_skill 'Requires a stood-up records layer — it guards rather than standing one up.'
run_lint
if grep -q 'FAIL: widget: SKILL.md:.*journal-floor phrase' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: planted floor phrase did not FAIL check 12" >&2
  echo "      lint out:" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

write_skill 'journal standup is never a precondition.'
run_lint
if grep -q 'journal-floor phrase' "$OUT"; then
  echo "FAIL: prohibition matched check 12 (must stay green)" >&2
  grep 'journal-floor phrase' "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

write_skill 'stop and point at `/journal setup`.'
run_lint
if grep -q 'FAIL: widget: SKILL.md:.*journal-floor phrase' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: planted stop-and-point phrase did not FAIL check 12" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

write_skill ''
run_lint
if grep -q 'journal-floor phrase' "$OUT"; then
  echo "FAIL: clean body still matched check 12" >&2
  grep 'journal-floor phrase' "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 13: project-templates heading -------------------------------------
mkdir -p "$sk/templates"
printf '# foo\n' > "$sk/templates/foo.md"
write_skill ''
run_lint
if grep -q 'FAIL: widget: templates/\*.md present but SKILL.md has no ## Project templates heading' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: missing heading did not FAIL check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

write_skill '## Project templates

none'
run_lint
if grep -q 'templates/\*.md present but SKILL.md has no ## Project templates heading' "$OUT"; then
  echo "FAIL: heading present still matched check 13" >&2
  grep 'Project templates heading' "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 12 stays off on the live tree without the flag --------------------
# (the fixture just proved the check works; the gate is the env var)
unset SKILLS_LINT_FLOOR
write_skill 'Requires a stood-up records layer'
bash "$LINT" "$lib" >"$OUT" 2>"$ERR" || true
if grep -q 'journal-floor phrase' "$OUT"; then
  echo "FAIL: check 12 fired without SKILLS_LINT_FLOOR=1" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "lint-records-writer-test"
