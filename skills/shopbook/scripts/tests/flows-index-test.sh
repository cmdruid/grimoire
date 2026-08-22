#!/usr/bin/env bash
# flows-index-test.sh — red-proofs 14, 15, 18 (index half). Patient-zero: mktemp only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

IDX="$SKILL/scripts/flows-index.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

# Missing dir → flows_dir=missing matches=0 exit 0. Do not mkdir.
pmiss="$TMP/missing"
mkdir -p "$pmiss"
rc=0; "$IDX" search --root "$pmiss" --workspace .dev --query bug >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing dir rc" "0" "$rc"
expect_eq "missing dir flows_dir" "missing" "$(fact flows_dir "$OUT")"
expect_eq "missing dir matches" "0" "$(fact matches "$OUT")"
[ ! -e "$pmiss/.dev" ] && pass=$((pass + 1)) \
  || { echo "FAIL: missing-dir search created .dev" >&2; fail=$((fail + 1)); }

# Fixture tree
p="$TMP/tree"
mkdir -p "$p/.dev/flows"
cat > "$p/.dev/flows/cut-tag.md" <<'EOF'
---
title: Cut a tag
use-when: cut a tag
---

# Cut a tag
EOF
# use-when-only hit: "release" lives only in use-when (not stem/title/H1).
cat > "$p/.dev/flows/ship-it.md" <<'EOF'
---
title: Ship it
use-when: release
---

# Ship it
EOF
cat > "$p/.dev/flows/start-env.md" <<'EOF'
---
title: Start the environment
use-when: boot, local
---

# Start the environment
EOF
cat > "$p/.dev/flows/publish.md" <<'EOF'
---
title: Publish notes
use-when: docs
---

# Publish notes
EOF
# Unquoted on-disk FM still parses.
cat > "$p/.dev/flows/unquoted.md" <<'EOF'
---
title: Unquoted Title
use-when: plain
---

# Unquoted Title
EOF

rc=0; "$IDX" list --root "$p" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "list rc" "0" "$rc"
expect_eq "list matches 5" "5" "$(fact matches "$OUT")"
expect "list has cut-tag" "cut-tag" "$OUT"
expect "list has unquoted" "unquoted" "$OUT"

# 14. use-when containing release → matches=1 (stem/title/H1 do not)
rc=0; "$IDX" search --root "$p" --workspace .dev --query release >"$OUT" 2>"$ERR" || rc=$?
expect_eq "14 search release rc" "0" "$rc"
expect_eq "14 search release matches" "1" "$(fact matches "$OUT")"
expect_eq "14 search release stem" "ship-it" "$(fact stems "$OUT")"

# Title-only hit still matches on title (publish).
rc=0; "$IDX" search --root "$p" --workspace .dev --query "Publish notes" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "14 title-only matches" "1" "$(fact matches "$OUT")"
expect_eq "14 title-only stem" "publish" "$(fact stems "$OUT")"

# Disable use-when match; title-only still hits; restore.
sed '/haystack=/s/$use_when //' "$IDX" > "$TMP/idx-no-uw.sh"
chmod +x "$TMP/idx-no-uw.sh"
rc=0; bash "$TMP/idx-no-uw.sh" search --root "$p" --workspace .dev --query release >"$OUT" 2>"$ERR" || rc=$?
expect_eq "14 disabled use-when release matches 0" "0" "$(fact matches "$OUT")"
rc=0; bash "$TMP/idx-no-uw.sh" search --root "$p" --workspace .dev --query "Publish notes" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "14 disabled use-when title still hits" "1" "$(fact matches "$OUT")"

# Unquoted title is searchable.
rc=0; "$IDX" search --root "$p" --workspace .dev --query Unquoted >"$OUT" 2>"$ERR" || rc=$?
expect_eq "unquoted title matches" "1" "$(fact matches "$OUT")"

# 15. Two title hits → matches=2, no singular path=
cat > "$p/.dev/flows/alpha.md" <<'EOF'
---
title: Shared token zzzy
use-when: a
---

# Alpha
EOF
cat > "$p/.dev/flows/beta.md" <<'EOF'
---
title: Other zzzy hit
use-when: b
---

# Beta
EOF
rc=0; "$IDX" search --root "$p" --workspace .dev --query zzzy >"$OUT" 2>"$ERR" || rc=$?
expect_eq "15 two title hits matches" "2" "$(fact matches "$OUT")"
expect_absent "15 no singular path=" "path=" "$OUT"
# paths= (plural) is fine
expect "15 plural paths=" "paths=" "$OUT"

# 18. Look-up does not invent. matches=0 does not create a file; $DST stays absent.
p18="$TMP/p18"
mkdir -p "$p18"
rc=0; "$IDX" search --root "$p18" --workspace .dev --query bug >"$OUT" 2>"$ERR" || rc=$?
expect_eq "18 empty search rc" "0" "$rc"
expect_eq "18 empty search matches" "0" "$(fact matches "$OUT")"
[ ! -e "$p18/.dev" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 18 search created .dev" >&2; fail=$((fail + 1)); }
[ ! -e "$p18/.dev/flows/bug.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 18 search invented bug.md" >&2; fail=$((fail + 1)); }

report "flows-index-test"
