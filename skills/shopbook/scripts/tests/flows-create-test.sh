#!/usr/bin/env bash
# flows-create-test.sh — red-proofs 17, 19. Patient-zero: mktemp only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

CRT="$SKILL/scripts/flows-create.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

# Parse a quoted-or-unquoted crawl key from a stub.
fm_get() {
  awk -v k="$1" '
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---" { exit }
    infm {
      prefix = k ": "
      if (index($0, prefix) == 1) {
        val = substr($0, length(prefix) + 1)
        if (val ~ /^".*"$/) {
          val = substr(val, 2, length(val) - 2)
          gsub(/\\\\/, "\001", val)
          gsub(/\\"/, "\"", val)
          gsub(/\001/, "\\", val)
        }
        print val
        exit
      }
    }
  ' "$2"
}

# --- 17. Mint a host stub only ----------------------------------------------
p17="$TMP/p17"
mkdir -p "$p17"
rc=0; "$CRT" --root "$p17" --workspace .dev --stem publish-release >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 create rc" "0" "$rc"
expect_eq "17 created true" "true" "$(fact created "$OUT")"
expect_eq "17 reason ok" "ok" "$(fact reason "$OUT")"
stub="$p17/.dev/flows/publish-release.md"
[ -f "$stub" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 17 stub missing" >&2; fail=$((fail + 1)); }
expect_eq "17 default title" "publish release" "$(fm_get title "$stub")"
expect_eq "17 default use-when" "publish-release" "$(fm_get use-when "$stub")"
expect "17 H1" "# publish release" "$stub"
# Body after H1 is empty (no invented walk).
after=$(awk 'found { print } /^# / { found = 1 }' "$stub")
after=$(printf '%s' "$after" | tr -d ' \t\n')
expect_eq "17 body after H1 empty" "" "$after"
[ ! -e "$p17/.dev/doctrine" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 17 created doctrine/" >&2; fail=$((fail + 1)); }

sum17=$(hash_of "$stub")
rc=0; "$CRT" --root "$p17" --workspace .dev --stem publish-release >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 rerun rc" "1" "$rc"
expect_eq "17 rerun created false" "false" "$(fact created "$OUT")"
expect_eq "17 rerun incumbent" "incumbent" "$(fact reason "$OUT")"
expect_eq "17 rerun checksum" "$sum17" "$(hash_of "$stub")"

rc=0; "$CRT" --root "$p17" --workspace .dev --stem Bug >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 Bug rc" "1" "$rc"
expect_eq "17 Bug reason" "bad-stem" "$(fact reason "$OUT")"
[ ! -e "$p17/.dev/flows/Bug.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 17 Bug.md was written" >&2; fail=$((fail + 1)); }

rc=0; "$CRT" --root "$p17" --workspace .dev --stem '../x' >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 ../x rc" "1" "$rc"
expect_eq "17 ../x reason" "bad-stem" "$(fact reason "$OUT")"

pnh="$TMP/nohome"
mkdir -p "$pnh"
rc=0; "$CRT" --root "$pnh" --workspace workspace --stem host-stub >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 no-home rc" "1" "$rc"
expect_eq "17 no-home reason" "no-home" "$(fact reason "$OUT")"
[ ! -e "$pnh/workspace" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 17 created declared-absent workspace/" >&2; fail=$((fail + 1)); }

# Default .dev absent → mkdir .dev/flows/ only.
pdev="$TMP/pdev"
mkdir -p "$pdev"
rc=0; "$CRT" --root "$pdev" --workspace .dev --stem boot >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 .dev mkdir rc" "0" "$rc"
[ -f "$pdev/.dev/flows/boot.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 17 .dev/flows/boot.md missing" >&2; fail=$((fail + 1)); }
[ ! -e "$pdev/.dev/doctrine" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 17 mkdir created doctrine/" >&2; fail=$((fail + 1)); }

# Disable incumbent refuse; confirm overwrite; restore.
awk '
  /if \[ -e "\$path" \]; then/ {
    print "if false; then"
    next
  }
  { print }
' "$CRT" > "$TMP/crt-no-inc.sh"
chmod +x "$TMP/crt-no-inc.sh"
printf 'ORIGINAL\n' > "$stub"
rc=0; bash "$TMP/crt-no-inc.sh" --root "$p17" --workspace .dev --stem publish-release >"$OUT" 2>"$ERR" || rc=$?
expect_eq "17 disabled-incumbent rc" "0" "$rc"
expect_eq "17 disabled-incumbent created" "true" "$(fact created "$OUT")"
expect_absent "17 disabled-incumbent overwrote" "ORIGINAL" "$stub"

# --- 19. YAML quote ----------------------------------------------------------
p19="$TMP/p19"
mkdir -p "$p19/.dev"
rc=0; "$CRT" --root "$p19" --workspace .dev --stem cut-release \
  --title 'Cut: "v1" release' >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 quoted title rc" "0" "$rc"
stub19="$p19/.dev/flows/cut-release.md"
expect_eq "19 parsed title" 'Cut: "v1" release' "$(fm_get title "$stub19")"
expect "19 quoted scalar on disk" 'title: "Cut: \"v1\" release"' "$stub19"

# newline in title → bad-value, no file
p19b="$TMP/p19b"
mkdir -p "$p19b/.dev"
nl_title=$(printf 'a\nb')
rc=0; "$CRT" --root "$p19b" --workspace .dev --stem bad-nl --title "$nl_title" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 newline rc" "1" "$rc"
expect_eq "19 newline reason" "bad-value" "$(fact reason "$OUT")"
[ ! -e "$p19b/.dev/flows/bad-nl.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 19 newline minted a file" >&2; fail=$((fail + 1)); }

rc=0; "$CRT" --root "$p19b" --workspace .dev --stem bad-fence --title 'a --- b' \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 --- rc" "1" "$rc"
expect_eq "19 --- reason" "bad-value" "$(fact reason "$OUT")"
[ ! -e "$p19b/.dev/flows/bad-fence.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 19 --- minted a file" >&2; fail=$((fail + 1)); }

rc=0; "$CRT" --root "$p19b" --workspace .dev --stem bad-ws --title '   ' \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 whitespace rc" "1" "$rc"
expect_eq "19 whitespace reason" "bad-value" "$(fact reason "$OUT")"

rc=0; "$CRT" --root "$p19b" --workspace .dev --stem bad-empty --title '' \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 empty rc" "1" "$rc"
expect_eq "19 empty reason" "bad-value" "$(fact reason "$OUT")"

report "flows-create-test"
