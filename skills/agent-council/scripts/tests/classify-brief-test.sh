#!/usr/bin/env bash
# classify-brief-test.sh — throwaway fixtures for classify-brief.sh.
# Facts only. Nothing touches the library tree except reading the script.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
CLASSIFY="$SKILL/scripts/classify-brief.sh"

pass=0
fail=0

expect_eq() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent() {
  if printf '%s' "$3" | grep -qE "$2"; then
    echo "FAIL: $1 — expected NOT to match: $2" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

kv() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -n 1
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/classify-brief-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd)"
trap 'rm -rf "$TMP"' EXIT

# --- fixtures ---------------------------------------------------------------
mkdir -p "$TMP/skillpkg"
printf '%s\n' '# demo' >"$TMP/skillpkg/SKILL.md"

printf '%s\n' '# demo' >"$TMP/SKILL.md"

cat >"$TMP/design-spec.md" <<'EOF'
---
doctype: specs
status: draft
tags: [spec]
---

# A design
EOF

cat >"$TMP/doctype-spec.md" <<'EOF'
---
doctype: spec
---

# A spec
EOF

cat >"$TMP/founding.md" <<'EOF'
---
doctype: specs
status: draft
tags: [founding]
---

# Founding
EOF

cat >"$TMP/founding-list.md" <<'EOF'
---
doctype: specs
tags:
  - founding
---

# Founding list
EOF

cat >"$TMP/plans.md" <<'EOF'
---
doctype: plans
status: published
tags: [roadmap]
---

# A roadmap
EOF

printf '%s\n' 'just some notes' >"$TMP/notes.txt"
mkdir -p "$TMP/plaindir"
printf '%s\n' 'readme' >"$TMP/plaindir/README.md"

# substring trap: "founding" inside another word must not select spec
cat >"$TMP/founding-substr.md" <<'EOF'
---
doctype: notes
tags: [founding-documents]
---

# Not founding
EOF

# --- cases ------------------------------------------------------------------
OUT="$(/bin/bash "$CLASSIFY" "$TMP/skillpkg")"
expect_eq "skill dir brief" "skill" "$(kv "$OUT" brief)"
expect_eq "skill dir kind" "skill" "$(kv "$OUT" kind)"
expect_eq "skill dir workdir" "$TMP/skillpkg" "$(kv "$OUT" workdir)"
expect_eq "skill dir readable" "true" "$(kv "$OUT" readable)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/SKILL.md")"
expect_eq "SKILL.md file brief" "skill" "$(kv "$OUT" brief)"
expect_eq "SKILL.md file workdir" "$TMP" "$(kv "$OUT" workdir)"
expect_eq "SKILL.md file target is parent" "$TMP" "$(kv "$OUT" target)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/design-spec.md")"
expect_eq "doctype design brief" "spec" "$(kv "$OUT" brief)"
expect_eq "doctype design kind" "spec" "$(kv "$OUT" kind)"
expect_absent "design is not skill" 'brief=skill' "$OUT"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/doctype-spec.md")"
expect_eq "doctype spec brief" "spec" "$(kv "$OUT" brief)"
expect_absent "spec doctype is not skill" 'brief=skill' "$OUT"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/founding.md")"
expect_eq "founding tag brief" "spec" "$(kv "$OUT" brief)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/founding-list.md")"
expect_eq "founding list-tag brief" "spec" "$(kv "$OUT" brief)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/plans.md")"
expect_eq "doctype plans is generic" "generic" "$(kv "$OUT" brief)"
expect_eq "doctype plans kind" "other" "$(kv "$OUT" kind)"
expect_absent "plans is not spec" 'brief=spec' "$OUT"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/notes.txt")"
expect_eq "random file brief" "generic" "$(kv "$OUT" brief)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/plaindir")"
expect_eq "non-skill dir brief" "generic" "$(kv "$OUT" brief)"
expect_eq "non-skill dir workdir" "$TMP/plaindir" "$(kv "$OUT" workdir)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/founding-substr.md")"
expect_eq "founding substring is generic" "generic" "$(kv "$OUT" brief)"

OUT="$(/bin/bash "$CLASSIFY" "$TMP/does-not-exist")"
expect_eq "missing brief empty" "" "$(kv "$OUT" brief)"
expect_eq "missing kind" "unreadable" "$(kv "$OUT" kind)"
expect_eq "missing readable" "false" "$(kv "$OUT" readable)"
expect_absent "missing is not generic" 'brief=generic' "$OUT"

OUT="$(/bin/bash "$CLASSIFY")"
expect_eq "no-arg brief empty" "" "$(kv "$OUT" brief)"
expect_eq "no-arg kind" "unreadable" "$(kv "$OUT" kind)"

expect_absent "no verdict words" '(convene|recommend|should)' "$OUT"

echo "classify-brief-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
