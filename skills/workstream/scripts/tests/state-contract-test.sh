#!/usr/bin/env bash
# Tracker grammar, mutation guards, and helper-authority admission tests.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-state.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"
OUT="$TMP/out"
ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT

git init -q -b main "$ROOT"
git -C "$ROOT" config user.name 'Workstream Test'
git -C "$ROOT" config user.email 'workstream@example.invalid'
printf 'fixture\n' >"$ROOT/file.txt"
git -C "$ROOT" add file.txt
git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init guarded main guarded >"$OUT"
TRACKER="$ROOT/.streams/guarded/workstream.tsv"

"$HELPER" "$ROOT" validate-tracker "$TRACKER" >"$OUT"
expect 'fresh tracker validates' 'status=valid' "$OUT"

reject_tracker() {
  local label="$1" candidate="$2"
  if "$HELPER" "$ROOT" validate-tracker "$candidate" >"$OUT" 2>"$ERR"; then
    fail=$((fail + 1))
    echo "FAIL: $label was accepted" >&2
  else
    pass=$((pass + 1))
  fi
}

cp "$TRACKER" "$TMP/duplicate.tsv"
sed -n '2p' "$TRACKER" >>"$TMP/duplicate.tsv"
reject_tracker 'duplicate key' "$TMP/duplicate.tsv"

{
  sed -n '1p' "$TRACKER"
  sed -n '3p' "$TRACKER"
  sed -n '2p' "$TRACKER"
  sed -n '4,$p' "$TRACKER"
} >"$TMP/reordered.tsv"
reject_tracker 'noncanonical row order' "$TMP/reordered.tsv"

cp "$TRACKER" "$TMP/unknown.tsv"
printf 'unknown\t-\tfield\tvalue\n' >>"$TMP/unknown.tsv"
reject_tracker 'unknown record family' "$TMP/unknown.tsv"

awk -F '\t' 'BEGIN{OFS="\t"} $1=="queue"&&$3=="state"{$4="surprising"} {print}' "$TRACKER" >"$TMP/bad-enum.tsv"
reject_tracker 'unknown enum' "$TMP/bad-enum.tsv"

awk -F '\t' 'BEGIN{OFS="\t"} !($1=="phase"&&$3=="next-action") {print}' "$TRACKER" >"$TMP/missing.tsv"
reject_tracker 'missing required field' "$TMP/missing.tsv"

cp "$TRACKER" "$TMP/oversized.tsv"
long=''
index=0
while [ "$index" -lt 4097 ]; do long="${long}x"; index=$((index + 1)); done
awk -F '\t' -v long="$long" 'BEGIN{OFS="\t"} $1=="queue"&&$3=="cursor"{$4=long} {print}' "$TRACKER" >"$TMP/oversized.tsv"
reject_tracker 'oversized value' "$TMP/oversized.tsv"

ln -s "$TRACKER" "$TMP/tracker-link.tsv"
reject_tracker 'symlinked tracker' "$TMP/tracker-link.tsv"

for family in meta queue phase unit unit-subject hook shipment shipment-unit friction gate gitlink delivery; do
  if grep -q "r==\"$family\"\|r=\"$family\"" "$HELPER"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: validator omits $family" >&2
  fi
done

cp "$TRACKER" "$TMP/incumbent.tsv"
cat >"$TMP/race.sh" <<'EOF'
#!/usr/bin/env bash
printf '\n' >>"$1"
EOF
chmod +x "$TMP/race.sh"
if WORKSTREAM_TEST_BEFORE_REPLACE="$TMP/race.sh" "$HELPER" "$ROOT" unit-begin guarded race 'Race guard' >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: concurrently changed tracker was replaced' >&2
else
  pass=$((pass + 1))
fi
expect_absent 'concurrent mutation does not install unit' $'unit\t1\t' "$TRACKER"
cp "$TMP/incumbent.tsv" "$TRACKER"
expect_eq 'fixture restores byte-identically' "$(shasum -a 256 "$TMP/incumbent.tsv" | awk '{print $1}')" "$(shasum -a 256 "$TRACKER" | awk '{print $1}')"

cp "$TRACKER" "$TMP/tracker-save.tsv"
mv "$TRACKER" "$TMP/tracker-regular.tsv"
ln -s "$TMP/tracker-regular.tsv" "$TRACKER"
if "$HELPER" "$ROOT" state guarded >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
rm "$TRACKER"
mv "$TMP/tracker-regular.tsv" "$TRACKER"

cp "$ROOT/.streams/guarded/WORKSTREAM.md" "$TMP/runbook-save.md"
awk 'BEGIN{OFS="\t"} index($0,"landing\t")==1{$2="push"} {print}' "$ROOT/.streams/guarded/WORKSTREAM.md" >"$TMP/runbook-corrupt.md"
cp "$TMP/runbook-corrupt.md" "$ROOT/.streams/guarded/WORKSTREAM.md"
if "$HELPER" "$ROOT" state guarded >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
cp "$TMP/runbook-save.md" "$ROOT/.streams/guarded/WORKSTREAM.md"

if "$HELPER" "$ROOT/.streams/guarded" state guarded >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if "$HELPER" "$ROOT/../project" state guarded >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

cp "$HELPER" "$ROOT/.streams/workstream.sh"
chmod +x "$ROOT/.streams/workstream.sh"
if "$HELPER" "$ROOT" state guarded >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: package helper bypassed installed authority' >&2
else
  pass=$((pass + 1))
fi
"$ROOT/.streams/workstream.sh" "$ROOT" state guarded >"$OUT"
expect 'installed authority works' 'schema=workstream-state@1' "$OUT"
mkdir -p "$ROOT/.streams/guarded/.streams"
cp "$HELPER" "$ROOT/.streams/guarded/.streams/workstream.sh"
chmod +x "$ROOT/.streams/guarded/.streams/workstream.sh"
if "$ROOT/.streams/guarded/.streams/workstream.sh" "$ROOT" state guarded >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: linked-checkout twin acquired authority' >&2
else
  pass=$((pass + 1))
fi

report 'workstream state contract'
