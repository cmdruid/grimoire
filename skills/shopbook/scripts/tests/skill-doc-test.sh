#!/usr/bin/env bash
# skill-doc-test.sh — grep gates 4, 6, 7, 8 and red-proofs 18, 20.
# Plants against the live skill files; always restores.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP=$(mktemp -d)
restore() {
  [ -f "$TMP/SKILL.md.bak" ] && mv "$TMP/SKILL.md.bak" "$SKILL/SKILL.md"
  [ -f "$TMP/query.md.bak" ] && mv "$TMP/query.md.bak" "$SKILL/verbs/query.md"
  rm -f "$SKILL/verbs/new.md"
  rm -rf "$TMP"
}
trap restore EXIT

# --- gate 4: no oven / register-route in the live package (tests excluded) ---
hits=$(rg -n 'skill:.*BEGIN|register-route' "$SKILL" --glob '!**/scripts/tests/**' || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 4 skill:BEGIN/register-route:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- gate 6: no verbs/migrate.md under shopbook excluding tests --------------
hits=$(rg -n 'verbs/migrate.md' "$SKILL" --glob '!**/scripts/tests/**' || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 6 verbs/migrate.md:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- gate 7: no clankshop in SKILL.md and verbs/ -----------------------------
hits=$(rg -n 'clankshop' "$SKILL/SKILL.md" "$SKILL/verbs" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 7 clankshop in SKILL.md/verbs:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- gate 8: alias/mint verb files absent; no path strings in SKILL/verbs ----
for v in new list search find add author; do
  if [ -e "$SKILL/verbs/$v.md" ]; then
    echo "FAIL: gate 8 verbs/$v.md exists" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done
hits=$(rg -n 'verbs/(new|list|search|find|add|author)\.md' "$SKILL/SKILL.md" "$SKILL/verbs" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 8 alias path strings:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi
# Plant verbs/new.md; existence gate red; restore.
printf '' > "$SKILL/verbs/new.md"
if [ -e "$SKILL/verbs/new.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 8 plant did not create verbs/new.md" >&2
  fail=$((fail + 1))
fi
rm -f "$SKILL/verbs/new.md"
if [ ! -e "$SKILL/verbs/new.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 8 restore left verbs/new.md" >&2
  fail=$((fail + 1))
fi
# Plant the path string in SKILL.md; content grep red; restore.
cp "$SKILL/SKILL.md" "$TMP/SKILL.md.bak"
printf '\n`verbs/new.md`\n' >> "$SKILL/SKILL.md"
hits=$(rg -n 'verbs/(new|list|search|find|add|author)\.md' "$SKILL/SKILL.md" "$SKILL/verbs" || true)
if [ -n "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: gate 8 planted path string did not go red" >&2
  fail=$((fail + 1))
fi
mv "$TMP/SKILL.md.bak" "$SKILL/SKILL.md"

# --- 18. query walk lives in verbs/query.md; not inlined in SKILL.md ---------
Q="$SKILL/verbs/query.md"
S="$SKILL/SKILL.md"
for needle in 'test `$DST/<stem>.md`' 'do not call `flows-create.sh`' \
  'a miss leaves `$DST` absent' 'continue to step 3 and search'; do
  if grep -qF -- "$needle" "$Q"; then
    pass=$((pass + 1))
  else
    echo "FAIL: 18 query.md missing: $needle" >&2
    fail=$((fail + 1))
  fi
  if grep -qF -- "$needle" "$S"; then
    echo "FAIL: 18 SKILL.md inlines walk byte: $needle" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done
if grep -qF 'Query walk' "$S"; then
  echo "FAIL: 18 SKILL.md contains Query walk heading" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -qF '$DST/<stem>.md' "$S"; then
  echo "FAIL: 18 SKILL.md contains \$DST/<stem>.md" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
# Delete the kebab bullets; greps go red; restore.
cp "$Q" "$TMP/query.md.bak"
# Count before, delete the four distinctive strings' lines, demand red.
before=$(grep -cF 'do not call `flows-create.sh`' "$Q" || true)
awk '
  /test `\$DST\/<stem>\.md`/ { next }
  /do not call `flows-create.sh`/ { next }
  /a miss leaves `\$DST` absent/ { next }
  /continue to step 3 and search/ { next }
  { print }
' "$Q" > "$TMP/query.stripped"
mv "$TMP/query.stripped" "$Q"
after=$(grep -cF 'do not call `flows-create.sh`' "$Q" || true)
if [ "$before" -gt 0 ] && [ "$after" -eq 0 ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 18 delete plant did not remove walk bytes (before=$before after=$after)" >&2
  fail=$((fail + 1))
fi
mv "$TMP/query.md.bak" "$Q"

# --- 20. Dispatch table in SKILL.md; Query walk heading in query.md ----------
if grep -qF '/shopbook query' "$S"; then
  pass=$((pass + 1))
else
  echo "FAIL: 20 SKILL.md missing /shopbook query row" >&2
  fail=$((fail + 1))
fi
if grep -qF '/shopbook bug' "$S" && grep -qF 'bare `/shopbook`' "$S"; then
  pass=$((pass + 1))
else
  echo "FAIL: 20 SKILL.md missing unknown-slash ask row" >&2
  fail=$((fail + 1))
fi
if grep -qF 'how do we handle X' "$S"; then
  pass=$((pass + 1))
else
  echo "FAIL: 20 SKILL.md missing how-do-we-X trigger" >&2
  fail=$((fail + 1))
fi
if grep -qE '^## Query walk' "$Q"; then
  pass=$((pass + 1))
else
  echo "FAIL: 20 query.md missing Query walk heading" >&2
  fail=$((fail + 1))
fi
# Drop the heading; grep red; restore.
cp "$Q" "$TMP/query.md.bak"
awk '/^## Query walk/ { next } { print }' "$Q" > "$TMP/query.nohead"
mv "$TMP/query.nohead" "$Q"
if grep -qE '^## Query walk' "$Q"; then
  echo "FAIL: 20 heading plant did not drop Query walk" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
mv "$TMP/query.md.bak" "$Q"

# 20(b) forbidden slash forms
for needle in '/shopbook <query>' 'bare `/shopbook` [query] → find' \
  '`/shopbook new`' ; do
  : # checked as more specific greps below
done
if grep -qF '/shopbook <query>' "$S"; then
  echo "FAIL: 20(b) SKILL.md has /shopbook <query> slash form" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -qF 'bare `/shopbook` [query] → find' "$S"; then
  echo "FAIL: 20(b) SKILL.md maps bare shopbook to find" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
# `/shopbook new` must not map to a verb file. The unknown row may name the
# invocation as ask; it must not cite verbs/new.md (gate 8) or verbs/create.md
# on the same line as `/shopbook new`.
if awk '
  /\/shopbook new/ && /verbs\/(new|create)\.md/ { found=1 }
  END { exit found ? 0 : 1 }
' "$S"; then
  echo "FAIL: 20(b) SKILL.md maps /shopbook new to a verb file" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if awk '
  /\/shopbook add/ && /verbs\/create\.md/ { found=1 }
  END { exit found ? 0 : 1 }
' "$S"; then
  echo "FAIL: 20(b) SKILL.md maps /shopbook add to verbs/create.md" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if awk '
  /\/shopbook author/ && /verbs\/create\.md/ { found=1 }
  END { exit found ? 0 : 1 }
' "$S"; then
  echo "FAIL: 20(b) SKILL.md maps /shopbook author to verbs/create.md" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
# Plant a forbidden mapping; grep red; restore.
cp "$S" "$TMP/SKILL.md.bak"
printf '\n`/shopbook add` → `verbs/create.md`\n' >> "$S"
if awk '
  /\/shopbook add/ && /verbs\/create\.md/ { found=1 }
  END { exit found ? 0 : 1 }
' "$S"; then
  pass=$((pass + 1))
else
  echo "FAIL: 20(b) planted add→create.md did not go red" >&2
  fail=$((fail + 1))
fi
mv "$TMP/SKILL.md.bak" "$S"

# test -f verbs/query.md
if [ -f "$Q" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: verbs/query.md missing" >&2
  fail=$((fail + 1))
fi

# description has no runbook
if grep -q runbook "$S"; then
  echo "FAIL: SKILL.md contains runbook" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "skill-doc-test"
