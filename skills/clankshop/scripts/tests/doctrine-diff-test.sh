#!/bin/sh
# doctrine-diff-test.sh -- committed fixture harness for doctrine-diff.sh (plan Task 1.6).
# Fixture INSTANCES are built in a temp dir and destroyed; only this harness is committed
# (patient-zero: nothing is exercised against the library's own tree). Covers: the six
# states (one micro-fixture each), prior-version retrieval (the base comes from BASES.md,
# not the live doctrine), fresh-seed *unchanged* for every entry shape (INV line, heading
# entry, lane file, testing file -- proving the canonical normalization incl. parameter
# fill), the unrelated-bump case, and the removed-base corruption case (missing-base via
# the bump record, never a silent live fallback).
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
DIFF=$DIR/../doctrine-diff.sh
TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-diff-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
expect() {  # <label> <needle> <haystack-file>
  if grep -qF "$2" "$3"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL: $1 -- missing: $2"
  fi
}
expect_absent() {  # <label> <needle> <haystack-file>
  if grep -qF "$2" "$3"; then
    fail=$((fail + 1)); echo "FAIL: $1 -- unexpected: $2"
  else
    pass=$((pass + 1))
  fi
}

# ---------- the fixture doctrine (source id: testdoc, version 2) ----------
D=$TMP/doctrine
mkdir -p "$D/rules" "$D/workflows" "$D/testing"
cat > "$D/README.md" <<'EOF'
# fixture doctrine
<!-- spine-index v1
doctrine: testdoc
doctrine-version: 2
docs: rules/INVARIANTS.md rules/GOTCHAS.md workflows/patch.md testing/GATE.md
-->
EOF
cat > "$D/rules/INVARIANTS.md" <<'EOF'
# INVARIANTS
<!-- spine-doc v1
kind: invariants
entry: ^(INV-[0-9]+):
ids: INV
doctrine: testdoc
doctrine-version: 2
-->
INV-1: Run <gate> green before any commit, v2 wording.
INV-2: Stable rule that never changed.
EOF
cat > "$D/rules/GOTCHAS.md" <<'EOF'
# GOTCHAS
<!-- spine-doc v1
kind: gotchas
entry: ^## (G-[0-9]+):
ids: G
doctrine: testdoc
doctrine-version: 2
-->
## G-1: The trap heading
Body line one of the trap.
Body line two.
EOF
cat > "$D/workflows/patch.md" <<'EOF'
# patch lane
<!-- spine-doc v1
kind: workflow
doctrine: testdoc
doctrine-version: 2
-->
Land the fix directly on <trunk>, no ceremony.
EOF
cat > "$D/testing/GATE.md" <<'EOF'
# GATE
<!-- spine-doc v1
kind: testing
doctrine: testdoc
doctrine-version: 2
-->
The one gate command is <gate>.
EOF
cat > "$D/BASES.md" <<'EOF'
# BASES
<!-- bases begin below this line -->
<!-- base testdoc:INV-1 @v1 -->
INV-1: Run <gate> green, the old v1 wording.
<!-- /base -->
<!-- bump v2: testdoc:INV-1 -->
EOF

# deploy_all <root>: a complete fresh v2 seed, slots filled (gate="make test", trunk=main).
deploy_all() {
  r=$1
  mkdir -p "$r/.handbook/rules" "$r/.handbook/workflows" "$r/.handbook/testing"
  cat > "$r/.handbook/rules/INVARIANTS.md" <<'EOF'
# INVARIANTS
<!-- spine-doc v1
kind: invariants
entry: ^(INV-[0-9]+):
ids: INV
-->
INV-1: Run make test green before any commit, v2 wording. ⟨testdoc:INV-1 @v2⟩
INV-2: Stable rule that never changed. ⟨testdoc:INV-2 @v2⟩
EOF
  cat > "$r/.handbook/rules/GOTCHAS.md" <<'EOF'
# GOTCHAS
<!-- spine-doc v1
kind: gotchas
entry: ^## (G-[0-9]+):
ids: G
-->
## G-1: The trap heading
origin: testdoc:G-1
origin-version: 2
Body line one of the trap.
Body line two.
EOF
  cat > "$r/.handbook/workflows/patch.md" <<'EOF'
# patch lane
<!-- spine-doc v1
kind: workflow
origin: testdoc:workflows/patch
origin-version: 2
-->
Land the fix directly on main, no ceremony.
EOF
  cat > "$r/.handbook/testing/GATE.md" <<'EOF'
# GATE
<!-- spine-doc v1
kind: testing
origin: testdoc:testing/GATE
origin-version: 2
-->
The one gate command is make test.
EOF
}

run_diff() {  # <root> [<doctrine>] -> $TMP/out
  bash "$DIFF" "$1" -d "${2:-$D}" gate="make test" trunk=main > "$TMP/out" 2>&1 || {
    echo "FAIL: differ exited non-zero"; cat "$TMP/out"; exit 1; }
}

# ---------- fresh seed: every shape classifies unchanged ----------
R=$TMP/fresh; deploy_all "$R"; run_diff "$R"
expect "fresh INV line unchanged"      "state:testdoc:INV-1@v2=unchanged" "$TMP/out"
expect "fresh INV-2 unchanged"         "state:testdoc:INV-2@v2=unchanged" "$TMP/out"
expect "fresh heading unchanged"       "state:testdoc:G-1@v2=unchanged" "$TMP/out"
expect "fresh lane file unchanged"     "state:testdoc:workflows/patch@v2=unchanged" "$TMP/out"
expect "fresh testing file unchanged"  "state:testdoc:testing/GATE@v2=unchanged" "$TMP/out"
expect_absent "fresh has no deletions" "locally-deleted" "$TMP/out"
expect_absent "fresh has no missing bases" "missing-base" "$TMP/out"

# ---------- locally edited ----------
R=$TMP/edited; deploy_all "$R"
sed 's/Stable rule that never changed\./Stable rule, project-tuned./' \
  "$R/.handbook/rules/INVARIANTS.md" > "$R/.handbook/rules/INVARIANTS.md.n" \
  && mv "$R/.handbook/rules/INVARIANTS.md.n" "$R/.handbook/rules/INVARIANTS.md"
run_diff "$R"
expect "locally edited" "state:testdoc:INV-2@v2=locally-edited" "$TMP/out"

# ---------- upstream updated + prior-version retrieval (base from BASES, not live) ----------
R=$TMP/stale; deploy_all "$R"
sed 's/INV-1: Run make test green before any commit, v2 wording\. ⟨testdoc:INV-1 @v2⟩/INV-1: Run make test green, the old v1 wording. ⟨testdoc:INV-1 @v1⟩/' \
  "$R/.handbook/rules/INVARIANTS.md" > "$R/.handbook/rules/INVARIANTS.md.n" \
  && mv "$R/.handbook/rules/INVARIANTS.md.n" "$R/.handbook/rules/INVARIANTS.md"
run_diff "$R"
expect "upstream updated via archived base" "state:testdoc:INV-1@v1=upstream-updated" "$TMP/out"

# ---------- conflict (deployed differs from both base and current) ----------
R=$TMP/conflict; deploy_all "$R"
sed 's/INV-1: Run make test green before any commit, v2 wording\. ⟨testdoc:INV-1 @v2⟩/INV-1: A third, locally invented wording. ⟨testdoc:INV-1 @v1⟩/' \
  "$R/.handbook/rules/INVARIANTS.md" > "$R/.handbook/rules/INVARIANTS.md.n" \
  && mv "$R/.handbook/rules/INVARIANTS.md.n" "$R/.handbook/rules/INVARIANTS.md"
run_diff "$R"
expect "conflict" "state:testdoc:INV-1@v1=conflict" "$TMP/out"

# ---------- locally deleted (seedable lane missing from the deployment) ----------
R=$TMP/deleted; deploy_all "$R"
rm "$R/.handbook/workflows/patch.md"
run_diff "$R"
expect "locally deleted" "state:testdoc:workflows/patch=locally-deleted" "$TMP/out"

# ---------- upstream retired (deployed stamp, origin gone upstream) ----------
R=$TMP/retired; deploy_all "$R"
printf 'INV-9: A rule the doctrine no longer carries. ⟨testdoc:INV-9 @v1⟩\n' \
  >> "$R/.handbook/rules/INVARIANTS.md"
run_diff "$R"
expect "upstream retired" "state:testdoc:INV-9@v1=upstream-retired" "$TMP/out"

# ---------- unrelated bump: untouched v1 entry still retrieves its live base ----------
# INV-2 was seeded at v1 and never changed upstream (no bump names it); after the v2 bump
# (which changed only INV-1) its base is correctly the live body -> unchanged.
R=$TMP/unrelated; deploy_all "$R"
sed 's/⟨testdoc:INV-2 @v2⟩/⟨testdoc:INV-2 @v1⟩/' \
  "$R/.handbook/rules/INVARIANTS.md" > "$R/.handbook/rules/INVARIANTS.md.n" \
  && mv "$R/.handbook/rules/INVARIANTS.md.n" "$R/.handbook/rules/INVARIANTS.md"
run_diff "$R"
expect "unrelated bump stays unchanged" "state:testdoc:INV-2@v1=unchanged" "$TMP/out"
expect_absent "unrelated bump no missing-base" "missing-base=testdoc:INV-2@v1" "$TMP/out"

# ---------- corruption: bump record names the origin, body block removed ----------
DC=$TMP/doctrine-corrupt
cp -R "$D" "$DC"
cat > "$DC/BASES.md" <<'EOF'
# BASES
<!-- bases begin below this line -->
<!-- bump v2: testdoc:INV-1 -->
EOF
R=$TMP/corrupt; deploy_all "$R"
sed 's/⟨testdoc:INV-1 @v2⟩/⟨testdoc:INV-1 @v1⟩/' \
  "$R/.handbook/rules/INVARIANTS.md" > "$R/.handbook/rules/INVARIANTS.md.n" \
  && mv "$R/.handbook/rules/INVARIANTS.md.n" "$R/.handbook/rules/INVARIANTS.md"
run_diff "$R" "$DC"
expect "removed base fires missing-base" "missing-base=testdoc:INV-1@v1" "$TMP/out"
expect_absent "no silent live fallback" "state:testdoc:INV-1@v1=" "$TMP/out"

echo "doctrine-diff: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
