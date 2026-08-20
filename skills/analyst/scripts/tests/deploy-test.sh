#!/usr/bin/env bash
# deploy-test.sh — exercise analyst-deploy.sh's lazy, never-overwriting deploy.
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

mkdir -p "$FIX/.records/plans" "$FIX/.dev"

# --- first deploy ------------------------------------------------------------

"$DEPLOY" "$FIX" > "$OUT" 2>&1
expect "first deploy: workspace seen"       "workspace=present"               "$OUT"
expect "first deploy: lands the catalog"    "deployed=briefing.md"            "$OUT"
expect "first deploy: lands the lock-in"    "deployed=reports.md"             "$OUT"
expect "first deploy: nothing kept back"    "kept_count=0"                    "$OUT"
expect_eq "first deploy: five catalog kinds plus reports.md" "6" \
  "$(find "$FIX/.dev/templates/analyst" -name '*.md' | wc -l | tr -d ' ')"

# --- customization survives a re-run -----------------------------------------

MARKER="PROJECT CUSTOMIZATION — must survive every redeploy"
echo "$MARKER" >> "$FIX/.dev/templates/analyst/briefing.md"

"$DEPLOY" "$FIX" > "$OUT" 2>&1
expect "re-run: keeps the customized file"  "kept=briefing.md"                "$OUT"
expect "re-run: deploys nothing new"        "deployed_count=0"                "$OUT"
expect "re-run: marker survived"            "$MARKER" \
  "$FIX/.dev/templates/analyst/briefing.md"

# BREAK: prove the marker assertion can fail — simulate a clobbering deploy by
# copying the bundled template over the customized one, exactly what the script
# must never do. If the assertion below did NOT fail here, it would be a rubber
# stamp on every future run.
cp "$HERE/../../templates/briefing.md" "$FIX/.dev/templates/analyst/briefing.md"
if grep -qF -- "$MARKER" "$FIX/.dev/templates/analyst/briefing.md"; then
  echo "FAIL: BREAK-proof — a clobbering copy left the marker; the check cannot detect an overwrite" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))   # the check is real: clobbering is detectable
fi

# --- host-added templates are left alone -------------------------------------

cat > "$FIX/.dev/templates/analyst/house-style.md" <<'EOF'
---
template: house-style
use-when: "A project-local report kind."
inputs: records
---
EOF
"$DEPLOY" "$FIX" > "$OUT" 2>&1
expect "re-run: host-added template untouched" "template: house-style" \
  "$FIX/.dev/templates/analyst/house-style.md"

# --- workspace present, no records dir (records is not a deploy gate) ---------

WS_ONLY="$(mktemp -d)"
trap 'rm -rf "$FIX" "$BARE" "$WS_ONLY"' EXIT
mkdir -p "$WS_ONLY/.dev"
"$DEPLOY" "$WS_ONLY" > "$OUT" 2>&1
expect "workspace-only: deploys without a records dir" "workspace=present" "$OUT"
expect "workspace-only: lands the catalog"             "deployed=briefing.md" "$OUT"
expect_eq "workspace-only: creates no records dir" "0" \
  "$(find "$WS_ONLY" -maxdepth 1 -name '.records' | wc -l | tr -d ' ')"

# --- standalone degrade -------------------------------------------------------

rc=0
"$DEPLOY" "$BARE" > "$OUT" 2>&1 || rc=$?
expect_eq "degrade: exits 0, never refuses" "0" "$rc"
expect "degrade: reports the absent workspace" "workspace=absent" "$OUT"
expect "degrade: deploys nothing"           "deployed=0"           "$OUT"
expect_eq "degrade: creates no workspace dir" "0" \
  "$(find "$BARE" -maxdepth 1 -name '.dev' | wc -l | tr -d ' ')"
expect_eq "degrade: creates no records dir" "0" \
  "$(find "$BARE" -maxdepth 1 -name '.records' | wc -l | tr -d ' ')"

report "analyst deploy"
