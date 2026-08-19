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
  bash "$LINT" "$lib" >"$OUT" 2>"$ERR" || true
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

# --- check 17: bare `records.sh new` mint ------------------------------------
# Six assertions, in three opposed pairs. The pairing is the point: each
# property is only proven by showing the check moves in BOTH directions.
#   red/green      — a bare mint FAILs; the prescribed form does not.
#   wrap           — a conforming invocation that wraps mid-span still PASSes
#                    (the false-positive a line-based grep produces, live today
#                    in debugger/SKILL.md), AND a bare one that wraps still
#                    FAILs (else a violator escapes by reflowing a paragraph).
#   scope          — a fenced example does not trip it; prose naming the tool
#                    with no `--title` is not an invocation.
tpl_head='## Project templates

- `foo.md`

'

c17='bare mint'

write_skill "${tpl_head}Workshop: mint \`records.sh new plans --title \"<title>\"\`."
run_lint
if grep -q "FAIL: widget: SKILL.md: $c17" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: planted bare mint did not FAIL check 17" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

write_skill "${tpl_head}Workshop: mint \`records.sh new plans --template <resolved> --title \"<title>\"\`."
run_lint
if grep -q "$c17" "$OUT"; then
  echo "FAIL: the prescribed --template form still matched check 17" >&2
  grep "$c17" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# A conforming invocation broken across a line exactly as the live tree breaks
# one. Whitespace normalization is what keeps this green.
write_skill "${tpl_head}Resolve it, then \`records.sh new
reports --template <resolved> --title \"<investigation title>\"\` when the tool exists."
run_lint
if grep -q "$c17" "$OUT"; then
  echo "FAIL: a wrapped CONFORMING invocation matched check 17 (normalization broken)" >&2
  grep "$c17" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# The inverse: wrapping must not launder a violation.
write_skill "${tpl_head}Workshop: mint \`records.sh new plans
--title \"<Track> — Roadmap\"\`, then set tags."
run_lint
if grep -q "FAIL: widget: SKILL.md: $c17" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: a wrapped BARE mint escaped check 17" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# A fenced example is documentation, not an invocation.
write_skill "${tpl_head}The retired shape looks like this:

\`\`\`
records.sh new plans --title \"<title>\"
\`\`\`

Do not use it."
run_lint
if grep -q "$c17" "$OUT"; then
  echo "FAIL: a fenced example tripped check 17 (fence stripping broken)" >&2
  grep "$c17" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# Prose naming the tool is not a mint: no --title, no verdict.
write_skill "${tpl_head}Dated records minted by \`records.sh new\` are sortable."
run_lint
if grep -q "$c17" "$OUT"; then
  echo "FAIL: prose naming the tool matched check 17 (decidability rule broken)" >&2
  grep "$c17" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "lint-records-writer-test"
