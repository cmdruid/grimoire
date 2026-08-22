#!/usr/bin/env bash
# flows-upkeep-test.sh — red-proofs 16, 19 (upkeep half). Patient-zero: mktemp only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

UPK="$SKILL/scripts/flows-upkeep.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

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

# Missing $DST → no-op 0
pmiss="$TMP/miss"
mkdir -p "$pmiss"
rc=0; "$UPK" check --root "$pmiss" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing dst check rc" "0" "$rc"
expect_eq "missing dst flows_dir" "missing" "$(fact flows_dir "$OUT")"
rc=0; "$UPK" apply --root "$pmiss" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing dst apply rc" "0" "$rc"
[ ! -e "$pmiss/.dev" ] && pass=$((pass + 1)) \
  || { echo "FAIL: upkeep apply created .dev" >&2; fail=$((fail + 1)); }

# --- 16. Fill missing keys only ---------------------------------------------
p16="$TMP/p16"
mkdir -p "$p16/.dev/flows"

# File with body and no FM → insert title from H1 and use-when from stem.
printf '%s\n' '# Hello host' '' 'keep this body' > "$p16/.dev/flows/hello-host.md"
body_after=$(awk 'BEGIN{p=0} /^# /{p=1} p{print}' "$p16/.dev/flows/hello-host.md")
rc=0; "$UPK" apply --root "$p16" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "16 no-fm apply rc" "0" "$rc"
expect_eq "16 no-fm title from H1" "Hello host" "$(fm_get title "$p16/.dev/flows/hello-host.md")"
expect_eq "16 no-fm use-when stem" "hello-host" "$(fm_get use-when "$p16/.dev/flows/hello-host.md")"
after=$(awk 'BEGIN{p=0} $0=="---"{c++; if(c==2){p=1; next}} p{print}' "$p16/.dev/flows/hello-host.md")
expect_eq "16 body after FM unchanged" "$body_after" "$after"

# File with title present and use-when missing → only use-when added.
cat > "$p16/.dev/flows/half.md" <<'EOF'
---
title: "Half title"
---

# Half title
body-half
EOF
title_before=$(fm_get title "$p16/.dev/flows/half.md")
rc=0; "$UPK" apply --root "$p16" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "16 half apply rc" "0" "$rc"
expect_eq "16 half title unchanged" "$title_before" "$(fm_get title "$p16/.dev/flows/half.md")"
expect_eq "16 half use-when added" "half" "$(fm_get use-when "$p16/.dev/flows/half.md")"
expect "16 half body kept" "body-half" "$p16/.dev/flows/half.md"

# File with both keys → checksum unchanged.
cat > "$p16/.dev/flows/full.md" <<'EOF'
---
title: "Full one"
use-when: "full"
---

# Full one
EOF
sum_full=$(hash_of "$p16/.dev/flows/full.md")
rc=0; "$UPK" apply --root "$p16" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "16 full apply rc" "0" "$rc"
expect_eq "16 full checksum" "$sum_full" "$(hash_of "$p16/.dev/flows/full.md")"

# Malformed FM → skipped; checksum unchanged.
printf '%s\n' '---' 'title: broken' 'no-close' > "$p16/.dev/flows/broken.md"
sum_broken=$(hash_of "$p16/.dev/flows/broken.md")
rc=0; "$UPK" apply --root "$p16" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "16 malformed apply rc" "0" "$rc"
expect "16 malformed listed" "broken" "$OUT"
expect_eq "16 malformed checksum" "$sum_broken" "$(hash_of "$p16/.dev/flows/broken.md")"

rc=0; "$UPK" check --root "$p16" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "16 check still red (malformed)" "1" "$rc"
expect "16 check malformed=" "malformed=broken" "$OUT"

# --- 19. upkeep H1 Cut: "v1" → quoted title fm=ok -----------------------------
p19="$TMP/p19"
mkdir -p "$p19/.dev/flows"
printf '%s\n' '# Cut: "v1"' '' 'walk' > "$p19/.dev/flows/cut-v1.md"
rc=0; "$UPK" apply --root "$p19" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 upkeep H1 rc" "0" "$rc"
expect_eq "19 upkeep parsed title" 'Cut: "v1"' "$(fm_get title "$p19/.dev/flows/cut-v1.md")"
expect "19 upkeep quoted on disk" 'title: "Cut: \"v1\""' "$p19/.dev/flows/cut-v1.md"
rc=0; "$UPK" check --root "$p19" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 upkeep check green" "0" "$rc"
expect_eq "19 upkeep fm ok" "ok" "$(fact file.cut-v1.fm "$OUT")"

# H1 containing --- → skip, do not insert.
p19s="$TMP/p19s"
mkdir -p "$p19s/.dev/flows"
printf '%s\n' '# Fence --- inside' 'body' > "$p19s/.dev/flows/fence.md"
sum_fence=$(hash_of "$p19s/.dev/flows/fence.md")
rc=0; "$UPK" apply --root "$p19s" --workspace .dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "19 h1-fence apply rc" "0" "$rc"
expect_eq "19 h1-fence checksum" "$sum_fence" "$(hash_of "$p19s/.dev/flows/fence.md")"

report "flows-upkeep-test"
