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

# A nonempty deployable inventory must have a route-shaped dispatch plus
# file-by-file coverage in both its setup procedure and setup test.
write_skill '## Project templates

- `foo.md`

Use foo.md at runtime.'
run_lint
if grep -q 'FAIL: widget: nonempty Project templates inventory has no routed setup' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: missing setup route did not FAIL check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

mkdir -p "$sk/verbs" "$sk/scripts/tests"
printf '# setup\n\nDeploy `foo.md` absent-only.\n' > "$sk/verbs/setup.md"
printf '#!/bin/sh\n# covers foo.md\n' > "$sk/scripts/tests/setup-test.sh"
write_skill 'Optional prose mentions `/widget setup` and `verbs/setup.md`, but does not dispatch it.

```
| `/widget setup` | `verbs/setup.md` | example only |
```

## Project templates

- `foo.md`

Use foo.md at runtime.'
run_lint
if grep -q 'FAIL: widget: nonempty Project templates inventory has no routed setup' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: a prose-only setup mention bypassed check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

printf '# setup\n\nDeploy the active inventory.\n' > "$sk/verbs/setup.md"
write_skill '| `setup [<root>]` | `verbs/setup.md` | deploy active templates |

## Project templates

- `foo.md`

Use foo.md at runtime.'
run_lint
if grep -q 'FAIL: widget: declared project template lacks setup procedure coverage: foo.md' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: missing per-file setup procedure coverage did not FAIL check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

printf '# setup\n\nDeploy `foo.md` absent-only.\n' > "$sk/verbs/setup.md"
printf '#!/bin/sh\n# claims coverage for foo.md without exercising it\n' > "$sk/scripts/tests/setup-test.sh"
run_lint
if grep -q 'FAIL: widget: declared project template lacks setup test coverage: foo.md' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: missing per-file setup test coverage did not FAIL check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

printf '#!/bin/sh\ntest -f "$root/foo.md"\n' > "$sk/scripts/tests/setup-test.sh"
run_lint
if grep -qE 'nonempty Project templates inventory has no routed setup|declared project template lacks setup (procedure|test) coverage|has no setup test carrier' "$OUT"; then
  echo "FAIL: routed and covered setup still failed check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# Inline setup owners have no verbs/setup.md. Fenced usage examples must not
# masquerade as their live route or procedure carrier.
rm -f "$sk/verbs/setup.md"
write_skill '```
`/widget setup` runs an example deploy for foo.md.
```

## Project templates

- `foo.md`

Use foo.md at runtime.'
run_lint
if grep -q 'FAIL: widget: nonempty Project templates inventory has no routed setup' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: a fenced inline setup example bypassed check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

write_skill '`/widget setup` runs the package-local deployer for `foo.md`.

## Project templates

- `foo.md`

Use foo.md at runtime.'
run_lint
if grep -qE 'nonempty Project templates inventory has no routed setup|declared project template lacks setup (procedure|test) coverage|has no setup test carrier' "$OUT"; then
  echo "FAIL: live inline setup route and coverage still failed check 13" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
rm -rf "$sk/verbs" "$sk/scripts"

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

write_skill "${tpl_head}Workshop: mint \`records.sh new plans --schema widget/plan@1 --template <resolved> --title \"<title>\"\`."
run_lint
if grep -q "$c17" "$OUT"; then
  echo "FAIL: the prescribed --schema form still matched check 17" >&2
  grep "$c17" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# A conforming invocation broken across a line exactly as the live tree breaks
# one. Whitespace normalization is what keeps this green.
write_skill "${tpl_head}Resolve it, then \`records.sh new
reports --schema widget/report@1 --template <resolved> --title \"<investigation title>\"\` when the tool exists."
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

# BL-35: `new --<flag>` (doctype dropped) is never valid — no --title needed.
c17_flag='new --flag'
write_skill "${tpl_head}Workshop: mint \`records.sh new --schema widget/plan@1 --template <resolved>\`."
run_lint
if grep -q "FAIL: widget: SKILL.md: $c17_flag" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: planted BL-32 spelling (new --template, no doctype) did not FAIL check 17" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

write_skill "${tpl_head}Dated records minted by \`records.sh new\` are sortable."
run_lint
if grep -q "$c17_flag" "$OUT"; then
  echo "FAIL: prose naming the tool matched the new --flag arm" >&2
  grep "$c17_flag" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- checks 19–21: package schema and template roles -------------------------
write_skill "${tpl_head}Use foo.md at runtime. Mint \`records.sh new plans --schema other/plan@1 --title X\`."
run_lint
if grep -q 'schema writer-prefix mismatch: other/plan@1' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: foreign schema prefix did not fail check 19" >&2; cat "$OUT" >&2; fail=$((fail + 1))
fi

write_skill "${tpl_head}Use foo.md at runtime. Mint \`records.sh new plans --schema widget/plan@1 --title X\`."
run_lint
if grep -q 'schema writer-prefix mismatch' "$OUT"; then
  echo "FAIL: owned schema prefix failed check 19" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

printf '%s\n' '---' 'schema: widget/plan@1' '---' '# Body' > "$sk/templates/foo.md"
run_lint
if grep -q 'declared project template templates/foo.md selects a schema' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: project template front matter did not fail check 20" >&2; cat "$OUT" >&2; fail=$((fail + 1))
fi

printf '# Body\n' > "$sk/templates/foo.md"
write_skill "$tpl_head"
run_lint
if grep -q 'templates/foo.md has no live read site outside its declaration' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: unused declared template did not fail check 20" >&2; cat "$OUT" >&2; fail=$((fail + 1))
fi

mkdir -p "$sk/scripts"
printf '%s\n' '#!/bin/sh' 'cp "$SKILL/templates/foo.md" "$dest/foo.md"' > "$sk/scripts/copy.sh"
write_skill '## Project templates

none

Use the package-only foo.md while working.'
run_lint
if grep -q 'package-only template templates/foo.md is named on a copy command' "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: package-only copy did not fail check 21" >&2; cat "$OUT" >&2; fail=$((fail + 1))
fi

report "lint-records-writer-test"
