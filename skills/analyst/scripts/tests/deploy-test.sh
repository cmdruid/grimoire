#!/usr/bin/env bash
# deploy-test.sh — exercise analyst-deploy.sh's explicit, never-overwriting deploy.
#
# The load-bearing guarantee is an ABSENCE: a customized template is never
# replaced. An absence assertion is worthless unless the fixture can actually
# exercise the failing arm, so the customization here is a planted marker that a
# clobbering deploy would provably erase.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$HERE/../analyst-deploy.sh"
# shellcheck source=/dev/null
. "$HERE/lib.sh"

FIX="$(mktemp -d)"
BARE="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE"' EXIT
OUT="$FIX/out.txt"

mkdir -p "$FIX/.records/plans" "$FIX/.agents/skilldata"

# --- first deploy ------------------------------------------------------------

"$DEPLOY" "$FIX" > "$OUT" 2>&1
expect "first deploy: skilldata seen"       "skilldata=present"               "$OUT"
expect "first deploy: lands the catalog"    "deployed=briefing.md"            "$OUT"
expect "first deploy: nothing kept back"    "kept_count=0"                    "$OUT"
expect_eq "first deploy: five active catalog kinds" "5" \
  "$(find "$FIX/.agents/skilldata/analyst/templates" -name '*.md' | wc -l | tr -d ' ')"
for file in briefing.md status.md subsystem.md diagnostics.md guide.md; do
  expect_eq "first deploy: lands $file" "1" "$([ -f "$FIX/.agents/skilldata/analyst/templates/$file" ] && echo 1 || echo 0)"
done

# --- customization survives a re-run -----------------------------------------

MARKER="PROJECT CUSTOMIZATION — must survive every redeploy"
echo "$MARKER" >> "$FIX/.agents/skilldata/analyst/templates/briefing.md"

"$DEPLOY" "$FIX" > "$OUT" 2>&1
expect "re-run: keeps the customized file"  "kept=briefing.md"                "$OUT"
expect "re-run: deploys nothing new"        "deployed_count=0"                "$OUT"
expect "re-run: marker survived"            "$MARKER" \
  "$FIX/.agents/skilldata/analyst/templates/briefing.md"

# BREAK: prove the marker assertion can fail — simulate a clobbering deploy by
# copying the bundled template over the customized one, exactly what the script
# must never do. If the assertion below did NOT fail here, it would be a rubber
# stamp on every future run.
cp "$HERE/../../templates/briefing.md" "$FIX/.agents/skilldata/analyst/templates/briefing.md"
if grep -qF -- "$MARKER" "$FIX/.agents/skilldata/analyst/templates/briefing.md"; then
  echo "FAIL: BREAK-proof — a clobbering copy left the marker; the check cannot detect an overwrite" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))   # the check is real: clobbering is detectable
fi

# --- host-added templates are left alone -------------------------------------

cat > "$FIX/.agents/skilldata/analyst/templates/house-style.md" <<'EOF'
---
template: house-style
use-when: "A project-local report kind."
inputs: records
---
EOF
"$DEPLOY" "$FIX" > "$OUT" 2>&1
expect "re-run: host-added template untouched" "template: house-style" \
  "$FIX/.agents/skilldata/analyst/templates/house-style.md"

# --- skilldata present, no records dir (records is not a deploy gate) ---------

WS_ONLY="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE" "$WS_ONLY"' EXIT
mkdir -p "$WS_ONLY/.agents/skilldata"
"$DEPLOY" "$WS_ONLY" > "$OUT" 2>&1
expect "skilldata-only: deploys without a records dir" "skilldata=present" "$OUT"
expect "skilldata-only: lands the catalog"             "deployed=briefing.md" "$OUT"
expect_eq "skilldata-only: creates no records dir" "0" \
  "$(find "$WS_ONLY" -maxdepth 1 -name '.records' | wc -l | tr -d ' ')"

# --- absent skilldata is created narrowly ------------------------------------

rc=0
"$DEPLOY" "$BARE" > "$OUT" 2>&1 || rc=$?
expect_eq "absent: deploy succeeds" "0" "$rc"
expect "absent: deploys catalog" "deployed=briefing.md" "$OUT"
expect_eq "absent: creates only owner template tree" "5" \
  "$(find "$BARE/.agents/skilldata/analyst/templates" -name '*.md' | wc -l | tr -d ' ')"
expect_eq "absent: creates no records dir" "0" \
  "$(find "$BARE" -maxdepth 1 -name '.records' | wc -l | tr -d ' ')"

# --- unsafe parents refuse before writes -------------------------------------

UNSAFE="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE" "$WS_ONLY" "$UNSAFE"' EXIT
mkdir "$UNSAFE/elsewhere"
mkdir -p "$UNSAFE/.agents"
ln -s "$UNSAFE/elsewhere" "$UNSAFE/.agents/skilldata"
if "$DEPLOY" "$UNSAFE" > "$OUT" 2>&1; then
  echo "FAIL: symlinked skilldata parent accepted" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect "symlink: refusal names the cause" "symlinked destination parent" "$OUT"
expect_eq "symlink: no template written through link" "0" \
  "$(find "$UNSAFE/elsewhere" -name '*.md' | wc -l | tr -d ' ')"

# Immediate recheck: exchange the owner parent after the whole-set preflight.
RACE="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE" "$WS_ONLY" "$UNSAFE" "$RACE"' EXIT
mkdir -p "$RACE/.agents/skilldata/analyst" "$RACE/elsewhere"
HOOK="$RACE/exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/analyst" "$1/held"' \
  'ln -s "$1/elsewhere" "$1/$2/analyst"' > "$HOOK"
chmod +x "$HOOK"
if ANALYST_SETUP_TEST_AFTER_PREFLIGHT="$HOOK" "$DEPLOY" "$RACE" > "$OUT" 2>&1; then
  echo "FAIL: post-preflight parent exchange accepted" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect "recheck: refusal names the cause" "symlinked destination parent" "$OUT"
expect_eq "recheck: no template written through link" "0" \
  "$(find "$RACE/elsewhere" -name '*.md' | wc -l | tr -d ' ')"

# An interruption after the first safe copy reports that copy; rerun preserves
# it and deterministically completes the catalog.
PARTIAL="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE" "$WS_ONLY" "$UNSAFE" "$RACE" "$PARTIAL"' EXIT
PHOOK="$PARTIAL/stop-after-first.sh"
printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0' > "$PHOOK"
chmod +x "$PHOOK"
if ANALYST_SETUP_TEST_AFTER_WRITE="$PHOOK" "$DEPLOY" "$PARTIAL" > "$OUT" 2>&1; then
  echo "FAIL: post-first-write interruption was not exercised" >&2; fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect "partial: completed path reported" "deployed=briefing.md" "$OUT"
expect_eq "partial: exactly one safe copy remains" "1" \
  "$(find "$PARTIAL/.agents/skilldata/analyst/templates" -type f | wc -l | tr -d ' ')"
"$DEPLOY" "$PARTIAL" > "$OUT" 2>&1
expect_eq "partial: rerun completes catalog" "5" \
  "$(find "$PARTIAL/.agents/skilldata/analyst/templates" -type f | wc -l | tr -d ' ')"

report "analyst deploy"
