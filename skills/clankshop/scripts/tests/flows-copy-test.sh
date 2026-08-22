#!/usr/bin/env bash
# flows-copy-test.sh — red-proofs 2–4, 6, 7, 12. Patient-zero: mktemp only
# except 12 plants/restores one live payload file under a trap.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

COPY="$SKILL/scripts/flows-copy.sh"
DOOR="$SKILL/scripts/flows-door.sh"
SEED="$SKILL/scripts/seed.sh"
SETUP_MD="$SKILL/verbs/setup.md"
CHECK_MD="$SKILL/verbs/check.md"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

hash_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}
fact() { sed -n -E "s/^$1=//p" "$2" | head -n 1; }

stems="bug.md feature.md patch.md spike.md diagnostics.md doc-audit.md"

# --- 2. Flows copy, doctrine not ---------------------------------------------
p2="$TMP/p2"
mkdir -p "$p2"
git init -q "$p2"
"$SEED" "$p2" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
rc=0; "$COPY" copy --root "$p2" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "2 copy rc" "0" "$rc"
for s in $stems; do
  [ -f "$p2/.dev/flows/$s" ] && pass=$((pass + 1)) \
    || { echo "FAIL: 2 missing $s" >&2; fail=$((fail + 1)); }
  grep -q '^title:' "$p2/.dev/flows/$s" && pass=$((pass + 1)) \
    || { echo "FAIL: 2 $s missing title" >&2; fail=$((fail + 1)); }
  grep -q '^use-when:' "$p2/.dev/flows/$s" && pass=$((pass + 1)) \
    || { echo "FAIL: 2 $s missing use-when" >&2; fail=$((fail + 1)); }
done
[ ! -e "$p2/.dev/doctrine/build/workflows" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 2 workflows/ landed inside doctrine" >&2; fail=$((fail + 1)); }
[ ! -e "$p2/.dev/doctrine/test/workflows" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 2 test/workflows/ inside doctrine" >&2; fail=$((fail + 1)); }
[ ! -e "$p2/.dev/doctrine/review/workflows" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 2 review/workflows/ inside doctrine" >&2; fail=$((fail + 1)); }

# Disable seed-tree deletion: restore a workflows dir into a copy of seed, seed, confirm inside doctrine.
fake="$TMP/fake-skill"
mkdir -p "$fake/seed/build/workflows" "$fake/scripts"
cp -R "$SKILL/seed/." "$fake/seed/"
cp "$SEED" "$fake/scripts/seed.sh"
chmod +x "$fake/scripts/seed.sh"
printf '# leftover lane\n' > "$fake/seed/build/workflows/feature.md"
# seed.sh reads PACK.md beside the skill
cp "$SKILL/PACK.md" "$fake/PACK.md"
p2d="$TMP/p2d"
mkdir -p "$p2d"
git init -q "$p2d"
"$fake/scripts/seed.sh" "$p2d" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
[ -f "$p2d/.dev/doctrine/build/workflows/feature.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 2 disable-deletion did not land inside doctrine" >&2; fail=$((fail + 1)); }

# --- 3. Incumbent flow --------------------------------------------------------
p3="$TMP/p3"
mkdir -p "$p3/.dev/flows"
git init -q "$p3"
"$SEED" "$p3" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
printf 'UNIQUE-INCUMBENT-BYTES\n' > "$p3/.dev/flows/feature.md"
sum3=$(hash_of "$p3/.dev/flows/feature.md")
rc=0; "$COPY" copy --root "$p3" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "3 copy rc" "0" "$rc"
expect_eq "3 incumbent checksum" "$sum3" "$(hash_of "$p3/.dev/flows/feature.md")"
expect "3 incumbent bytes kept" "UNIQUE-INCUMBENT-BYTES" "$p3/.dev/flows/feature.md"
[ -f "$p3/.dev/flows/bug.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 3 other stems not copied" >&2; fail=$((fail + 1)); }

# --- 4. seed.sh does not copy flows ------------------------------------------
p4="$TMP/p4"
mkdir -p "$p4"
git init -q "$p4"
"$SEED" "$p4" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
[ ! -e "$p4/.dev/flows" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 4 seed.sh created flows/" >&2; fail=$((fail + 1)); }

# --- 6. Resume copy + missing pointer ----------------------------------------
# (i) doctrine present, one dest stem missing → copy runs, seed.sh not re-run
p6="$TMP/p6"
mkdir -p "$p6"
git init -q "$p6"
"$SEED" "$p6" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
"$COPY" copy --root "$p6" --workspace .dev >"$OUT" 2>"$ERR"
rm -f "$p6/.dev/flows/bug.md"
stamp=$(grep -F 'Seeded from clankshop' "$p6/.dev/doctrine/README.md")
rc=0; "$COPY" copy --root "$p6" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6i copy rc" "0" "$rc"
[ -f "$p6/.dev/flows/bug.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 6i missing stem not restored" >&2; fail=$((fail + 1)); }
expect_eq "6i stamp unchanged" "$stamp" "$(grep -F 'Seeded from clankshop' "$p6/.dev/doctrine/README.md")"
rc=0; "$SEED" "$p6" --gate 'make test' --trunk main >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6i seed.sh still refuses" "2" "$rc"

# (ii) stems present, pointer absent → door apply, then check green
write_agents() {
  printf '%s\n' "$@" > "$1"
}
write_agents "$p6/AGENTS.md" '# AGENTS.md' 'Doctrine: .dev/doctrine/README.md'
rc=0; "$DOOR" apply --root "$p6" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6ii apply rc" "0" "$rc"
expect "6ii pointer present" ".dev/flows/" "$p6/AGENTS.md"
rc=0; "$DOOR" check --root "$p6" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6ii door check green" "0" "$rc"
rc=0; "$COPY" check --root "$p6" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6ii copy check green" "0" "$rc"

# Guard prose: resume parenthetical names unfinished copy + flows pointer
expect "6 Guard unfinished copy in setup.md" "unfinished copy" "$SETUP_MD"
expect "6 Guard flows-door.sh check" "flows-door.sh check" "$SETUP_MD"
expect "6 Guard range (1–6)" "(1–6)" "$SETUP_MD"
expect "6 resume parenthetical names pointer unfinished" "missing/malformed/wrong-path flows pointer" "$SETUP_MD"
# Disable resume parenthetical, confirm grep no longer matches, restore (copy).
awk '/missing\/malformed\/wrong-path flows pointer/ {
  gsub(/missing\/malformed\/wrong-path flows pointer/, "");
} { print }' "$SETUP_MD" > "$TMP/setup-cut.md"
cut_hits=$(grep -cF 'missing/malformed/wrong-path flows pointer' "$TMP/setup-cut.md" || true)
expect_eq "6 disabled resume parenthetical gone" "0" "$cut_hits"
expect "6 original setup.md still has it" "missing/malformed/wrong-path flows pointer" "$SETUP_MD"

# --- 7. Unfinished copy is a check finding -----------------------------------
p7="$TMP/p7"
mkdir -p "$p7"
git init -q "$p7"
"$SEED" "$p7" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
"$COPY" copy --root "$p7" --workspace .dev >"$OUT" 2>"$ERR"
rm -f "$p7/.dev/flows/spike.md"
sum7=$(find "$p7" -type f | sort | while IFS= read -r f; do hash_of "$f"; done)
rc=0; "$COPY" check --root "$p7" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "7 check rc" "1" "$rc"
expect_eq "7 unfinished true" "true" "$(fact unfinished "$OUT")"
expect "7 names setup" "/clankshop setup" "$OUT"
expect "7 missing spike" "spike.md" "$OUT"
sum7b=$(find "$p7" -type f | sort | while IFS= read -r f; do hash_of "$f"; done)
expect_eq "7 tree unchanged" "$sum7" "$sum7b"
expect "7 check.md unfinished copy step" "unfinished=true" "$CHECK_MD"

# --- 12. Grep gate 3 ---------------------------------------------------------
# Live tree must be empty of leftover station-workflows paths (excluding tests).
gate3=$(cd "$SKILL/../.." && rg -n 'build/workflows|test/workflows|review/workflows' skills/clankshop \
  --glob '!**/scripts/tests/**' --glob '!**/2026-08-21-clankshop-glue-foreman-spec.md' || true)
if [ -z "$gate3" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 12 grep gate 3 not empty:" >&2
  echo "$gate3" >&2
  fail=$((fail + 1))
fi
# Plant, gate red, restore.
plant="$SKILL/flows/bug.md"
cp "$plant" "$TMP/bug.md.bak"
restore_plant() { mv "$TMP/bug.md.bak" "$plant"; }
trap 'restore_plant; rm -rf "$TMP"' EXIT
printf '\nbuild/workflows/feature.md\n' >> "$plant"
gate3p=$(cd "$SKILL/../.." && rg -n 'build/workflows|test/workflows|review/workflows' skills/clankshop \
  --glob '!**/scripts/tests/**' --glob '!**/2026-08-21-clankshop-glue-foreman-spec.md' || true)
if [ -n "$gate3p" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 12 planted leftover did not go red" >&2
  fail=$((fail + 1))
fi
restore_plant
trap 'rm -rf "$TMP"' EXIT
gate3r=$(cd "$SKILL/../.." && rg -n 'build/workflows|test/workflows|review/workflows' skills/clankshop \
  --glob '!**/scripts/tests/**' --glob '!**/2026-08-21-clankshop-glue-foreman-spec.md' || true)
if [ -z "$gate3r" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 12 restore left leftovers:" >&2
  echo "$gate3r" >&2
  fail=$((fail + 1))
fi

# grep gate 9: context.sh must not name shopbook
if grep -q shopbook "$SKILL/seed/scripts/context.sh"; then
  echo "FAIL: gate 9 context.sh names shopbook" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "flows-copy-test"
