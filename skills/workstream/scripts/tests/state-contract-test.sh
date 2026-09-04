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

init_repo "$ROOT"
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

awk -F '\t' 'BEGIN{OFS="\t"} $1=="phase"&&$3=="name"{$4="plan"} $1=="phase"&&$3=="next-action"{$4="close"} {print}' "$TRACKER" >"$TMP/impossible-phase.tsv"
reject_tracker 'impossible phase and action pair' "$TMP/impossible-phase.tsv"

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

if WORKSTREAM_TEST_AFTER_TRACKER_SNAPSHOT="$TMP/race.sh" "$HELPER" "$ROOT" unit-begin guarded early-race 'Early race guard' >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: tracker changed after admission was replaced' >&2
else
  pass=$((pass + 1))
fi
expect_absent 'pre-derivation race does not install unit' $'unit\t1\t' "$TRACKER"
cp "$TMP/incumbent.tsv" "$TRACKER"

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

"$HELPER" "$ROOT/.streams/guarded" state guarded >"$OUT" 2>"$ERR"
expect 'linked checkout admits through the primary' 'schema=workstream-state@1' "$OUT"
if "$HELPER" "$ROOT/../project" state guarded >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

cp "$HELPER" "$ROOT/.streams/workstream.sh"
chmod +x "$ROOT/.streams/workstream.sh"
sed -n 'p' "$DIR/../../templates/streams-readme-block.md" >"$ROOT/.streams/README.md"
git -C "$ROOT" add -f .streams/workstream.sh .streams/README.md
git -C "$ROOT" commit -qm 'install workstream control helper'
"$HELPER" "$ROOT" state guarded >"$OUT" 2>"$ERR"
expect 'package helper re-execs installed authority' 'schema=workstream-state@1' "$OUT"
"$ROOT/.streams/workstream.sh" "$ROOT" state guarded >"$OUT"
expect 'installed authority works' 'schema=workstream-state@1' "$OUT"
mkdir -p "$ROOT/.streams/guarded/.streams"
cp "$HELPER" "$ROOT/.streams/guarded/.streams/workstream.sh"
chmod +x "$ROOT/.streams/guarded/.streams/workstream.sh"
"$ROOT/.streams/guarded/.streams/workstream.sh" "$ROOT" state guarded >"$OUT" 2>"$ERR"
expect 'non-installed copy re-execs installed authority' 'schema=workstream-state@1' "$OUT"

mkdir -p "$ROOT/.streams/guarded/.streams/copied"
cp "$ROOT/.streams/guarded/WORKSTREAM.md" "$ROOT/.streams/guarded/.streams/copied/WORKSTREAM.md"
cp "$ROOT/.streams/guarded/workstream.tsv" "$ROOT/.streams/guarded/.streams/copied/workstream.tsv"
if "$ROOT/.streams/workstream.sh" "$ROOT" state guarded >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1)); echo 'FAIL: ignored nested stream state was admitted' >&2
else
  pass=$((pass + 1)); expect 'nested runtime refusal is explicit' 'nested stream' "$ERR"
fi
rm -rf "$ROOT/.streams/guarded/.streams/copied"

printf '\n# unauthorized mutation\n' >>"$ROOT/.streams/workstream.sh"
if "$ROOT/.streams/workstream.sh" "$ROOT" list >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1)); echo 'FAIL: modified installed helper retained authority' >&2
else
  pass=$((pass + 1)); expect 'modified helper points to repair' 'installed helper differs' "$ERR"
fi
cp "$HELPER" "$ROOT/.streams/workstream.sh"

boundary="$(git -C "$ROOT/.streams/guarded" rev-parse HEAD)"
{
  awk -F '\t' 'BEGIN{OFS="\t"} $1=="meta"&&$3=="next-unit"{$4=3} {print}' "$TRACKER"
  printf 'unit\t1\tboundary\t%s\nunit\t1\tcommit-count\t0\nunit\t1\tslug\tone\nunit\t1\tstate\tactive\nunit\t1\tsummary\tone\n' "$boundary"
  printf 'unit\t2\tboundary\t%s\nunit\t2\tcommit-count\t0\nunit\t2\tslug\ttwo\nunit\t2\tstate\tactive\nunit\t2\tsummary\ttwo\n' "$boundary"
} >"$TMP/two-active.tsv"
if "$ROOT/.streams/workstream.sh" "$ROOT" validate-tracker "$TMP/two-active.tsv" >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1)); echo 'FAIL: two simultaneous active units were accepted' >&2
else
  pass=$((pass + 1))
fi

"$ROOT/.streams/workstream.sh" "$ROOT" runtime-init evidence main evidence >"$OUT"
"$ROOT/.streams/workstream.sh" "$ROOT" unit-begin evidence proof proof >"$OUT"
printf 'proof\n' >"$ROOT/.streams/evidence/proof"
git -C "$ROOT/.streams/evidence" add proof
git -C "$ROOT/.streams/evidence" commit -qm proof
"$ROOT/.streams/workstream.sh" "$ROOT" unit-complete evidence >"$OUT"
"$ROOT/.streams/workstream.sh" "$ROOT" ship-prepare evidence >"$OUT"
"$ROOT/.streams/workstream.sh" "$ROOT" gate-run evidence --class full --label proof -- true >"$OUT"
READY="$ROOT/.streams/evidence/workstream.tsv"
awk -F '\t' 'BEGIN{OFS="\t"} $1!="gate" {print}' "$READY" >"$TMP/no-gate.tsv"
reject_tracker 'ready shipment without passed gate evidence' "$TMP/no-gate.tsv"
awk -F '\t' 'BEGIN{OFS="\t"} !($1=="hook"&&$3=="name"&&$4=="ship-friction") {print}' "$READY" >"$TMP/partial-hook.tsv"
reject_tracker 'partial ship hook identity' "$TMP/partial-hook.tsv"
sed 's#/unit/1/feature-completion#/unit/99/feature-completion#' "$READY" >"$TMP/orphan-hook.tsv"
reject_tracker 'orphan feature hook identity' "$TMP/orphan-hook.tsv"
sed 's#/unit/1/feature-completion#/units/1/feature-completion#' "$READY" >"$TMP/malformed-hook.tsv"
reject_tracker 'malformed feature hook identity' "$TMP/malformed-hook.tsv"
sed 's#evidence/#other/#' "$READY" >"$TMP/wrong-stream-hook.tsv"
cp "$TMP/wrong-stream-hook.tsv" "$READY"
if "$ROOT/.streams/workstream.sh" "$ROOT" state evidence >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'admission binds hook identity to stream' 'another stream' "$ERR"

report 'workstream state contract'
