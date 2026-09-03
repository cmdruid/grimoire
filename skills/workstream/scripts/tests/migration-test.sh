#!/usr/bin/env bash
# Attended hard-cut migration moves registered worktrees, not customization archives.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-migration.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
mkdir -p "$ROOT/.records/plans"; printf 'base\n' >"$ROOT/file"; printf '# Legacy plan\n' >"$ROOT/.records/plans/legacy.md"
git -C "$ROOT" add file .records/plans/legacy.md; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.workstreams"
git -C "$ROOT" worktree add -q -b stream/legacy "$ROOT/.workstreams/legacy" main
printf '# legacy handoff\n' >"$ROOT/.workstreams/legacy/WORKSTREAM.md"
git -C "$ROOT" worktree add -q -b stream/legacy-two "$ROOT/.workstreams/legacy-two" main
cat >"$ROOT/.workstreams/legacy-two/WORKSTREAM.md" <<'EOF'
# legacy two — workstream hand-off

## Coordinates
- source: .records/plans/legacy.md#phase-two
- source-kind: roadmap
- mode: manual
- isolation: worktree
- landing: local
- ship-cadence: per-stage

## Hooks (compiled)
feature-completion:
Run the preserved legacy feature hook.

after-eventful-ship:
Discard this retired hook.
EOF
"$HELPER" "$ROOT" migrate inventory >"$OUT"
expect 'migration inventories stream' 'stream=legacy' "$OUT"
expect 'migration inventories second stream' 'stream=legacy-two' "$OUT"
expect 'inventory reports both streams' 'streams=2' "$OUT"
if [ -d "$ROOT/.workstreams/legacy" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
"$HELPER" "$ROOT" migrate apply >"$OUT"
expect 'migration applies' 'status=migrated' "$OUT"
if [ -d "$ROOT/.streams/legacy" ] && [ ! -e "$ROOT/.workstreams/legacy" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
if [ -d "$ROOT/.streams/legacy-two" ] && [ ! -e "$ROOT/.workstreams/legacy-two" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
expect 'new tracker created' $'schema\tworkstream@1' "$ROOT/.streams/legacy/workstream.tsv"
expect 'new runbook preserves legacy purpose' $'purpose\tlegacy' "$ROOT/.streams/legacy/WORKSTREAM.md"
expect 'migration preserves legacy mode' $'mode\tmanual\texplicit' "$ROOT/.streams/legacy-two/WORKSTREAM.md"
expect 'migration preserves legacy cadence' $'ship-cadence\tper-stage\texplicit' "$ROOT/.streams/legacy-two/WORKSTREAM.md"
expect 'migration preserves feature hook body' 'Run the preserved legacy feature hook.' "$ROOT/.streams/legacy-two/WORKSTREAM.md"
expect_absent 'migration drops retired event hook' 'Discard this retired hook.' "$ROOT/.streams/legacy-two/WORKSTREAM.md"
expect 'migration preserves roadmap source' $'queue\t-\tsource-kind\troadmap' "$ROOT/.streams/legacy-two/workstream.tsv"
expect 'migration preserves roadmap cursor' $'queue\t-\tcursor\t.records/plans/legacy.md#phase-two' "$ROOT/.streams/legacy-two/workstream.tsv"
expect 'Git registry follows move' "worktree $ROOT/.streams/legacy" <(git -C "$ROOT" worktree list --porcelain)
"$HELPER" "$ROOT" read legacy >"$OUT"; expect 'migrated stream admits' 'schema=workstream-read@1' "$OUT"
"$HELPER" "$ROOT" read legacy-two >"$OUT"; expect 'second migrated stream admits' 'schema=workstream-read@1' "$OUT"

mkdir -p "$ROOT/.workstreams"; git -C "$ROOT" worktree add -q -b stream/nested "$ROOT/.workstreams/nested" main
mkdir -p "$ROOT/.workstreams/nested/.streams/copied"
if "$HELPER" "$ROOT" migrate apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ -d "$ROOT/.workstreams/nested" ] && [ ! -e "$ROOT/.streams/nested" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT2="$TMP/resume"; git init -q -b main "$ROOT2"; git -C "$ROOT2" config user.name test; git -C "$ROOT2" config user.email test@example.invalid
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial; mkdir -p "$ROOT2/.workstreams"
git -C "$ROOT2" worktree add -q -b stream/resume "$ROOT2/.workstreams/resume" main; printf '# resume handoff\n' >"$ROOT2/.workstreams/resume/WORKSTREAM.md"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_MIGRATION_MOVE="$TMP/interrupt.sh" "$HELPER" "$ROOT2" migrate apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'interrupted migration records moved stage' $'resume\t'"$ROOT2/.workstreams/resume"$'\t'"$ROOT2/.streams/resume"$'\tworktree\tstream/resume\tmain\tmoved\t' "$ROOT2/.streams/.migration.tsv"
instance="$(awk -F '\t' '$1=="resume"{print $8}' "$ROOT2/.streams/.migration.tsv")"
if [ -d "$ROOT2/.streams/resume" ] && [ ! -e "$ROOT2/.workstreams/resume" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
"$HELPER" "$ROOT2" migrate apply >"$OUT"; expect 'migration resumes after durable move' 'status=migrated' "$OUT"
expect 'resumed migration preserves manifest instance' $'instance-id\t'"$instance" "$ROOT2/.streams/resume/WORKSTREAM.md"
if [ ! -e "$ROOT2/.streams/.migration.tsv" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT3="$TMP/inplace"; git init -q -b main "$ROOT3"; git -C "$ROOT3" config user.name test; git -C "$ROOT3" config user.email test@example.invalid
printf 'base\n' >"$ROOT3/file"; git -C "$ROOT3" add file; git -C "$ROOT3" commit -qm initial; git -C "$ROOT3" switch -qc stream/old
mkdir -p "$ROOT3/.workstreams/old"
cat >"$ROOT3/.workstreams/old/WORKSTREAM.md" <<'EOF'
# Legacy in-place purpose
- branch: stream/old
- integration-target: main
- isolation: in-place
EOF
"$HELPER" "$ROOT3" migrate apply >"$OUT"; expect 'in-place migration applies' 'status=migrated' "$OUT"
expect 'in-place migration records root coordinate' $'worktree\t'"$ROOT3" "$ROOT3/.streams/old/WORKSTREAM.md"
"$HELPER" "$ROOT3" read old >"$OUT"; expect 'migrated in-place stream admits' 'schema=workstream-read@1' "$OUT"
report 'workstream migration'
