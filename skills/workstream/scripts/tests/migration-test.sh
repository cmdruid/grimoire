#!/usr/bin/env bash
# Attended hard-cut migration moves registered worktrees, not customization archives.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
MIGRATOR="$(cd "$DIR/.." && pwd)/workstream-migrate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-migration.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
mkdir -p "$ROOT/.records/plans"; printf 'base\n' >"$ROOT/file"; printf '# Legacy plan\n' >"$ROOT/.records/plans/legacy.md"
git -C "$ROOT" add file .records/plans/legacy.md; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.workstreams"
if "$HELPER" "$ROOT" migrate inventory >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'ordinary runtime does not dispatch migration' 'unknown operation: migrate' "$ERR"
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
printf 'preserved work\n' >>"$ROOT/.workstreams/legacy-two/file"
git -C "$ROOT/.workstreams/legacy-two" add file
git -C "$ROOT/.workstreams/legacy-two" commit -qm 'preserved legacy unit'
i=2
while [ "$i" -le 12 ]; do
  git -C "$ROOT/.workstreams/legacy-two" commit --allow-empty -qm "preserved legacy unit $i"
  i=$((i + 1))
done
"$MIGRATOR" "$ROOT" inventory >"$OUT"
expect 'migration inventories stream' 'stream=legacy' "$OUT"
expect 'migration inventories second stream' 'stream=legacy-two' "$OUT"
expect 'inventory reports both streams' 'streams=2' "$OUT"
if [ -d "$ROOT/.workstreams/legacy" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
"$MIGRATOR" "$ROOT" apply >"$OUT"
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
expect 'migration preserves committed active work' $'unit\t1\tstate\tcomplete' "$ROOT/.streams/legacy-two/workstream.tsv"
expect 'migration preserves legacy commit subject' $'subject\tpreserved legacy unit' "$ROOT/.streams/legacy-two/workstream.tsv"
expect 'Git registry follows move' "worktree $ROOT/.streams/legacy" <(git -C "$ROOT" worktree list --porcelain)
"$HELPER" "$ROOT" read legacy >"$OUT"; expect 'migrated stream admits' 'schema=workstream-read@1' "$OUT"
expect 'aligned migrated stream keeps queue action' 'next_action=define-unit' "$OUT"
"$HELPER" "$ROOT" read legacy-two >"$OUT"; expect 'second migrated stream admits' 'schema=workstream-read@1' "$OUT"
expect 'ahead migrated stream keeps queue action' 'next_action=accumulate' "$OUT"

SPACE_ROOT="$TMP/project with space"; init_repo "$SPACE_ROOT"
printf 'base\n' >"$SPACE_ROOT/file"; git -C "$SPACE_ROOT" add file; git -C "$SPACE_ROOT" commit -qm initial
mkdir -p "$SPACE_ROOT/.workstreams"
git -C "$SPACE_ROOT" worktree add -q -b stream/spaced "$SPACE_ROOT/.workstreams/spaced" main
printf '# spaced legacy handoff\n' >"$SPACE_ROOT/.workstreams/spaced/WORKSTREAM.md"
"$MIGRATOR" "$SPACE_ROOT" inventory >"$OUT"
expect 'migration inventories a worktree below a root containing spaces' 'stream=spaced' "$OUT"
"$MIGRATOR" "$SPACE_ROOT" apply >"$OUT"
expect 'migration below a root containing spaces applies' 'status=migrated' "$OUT"
if [ -d "$SPACE_ROOT/.streams/spaced" ] && [ ! -e "$SPACE_ROOT/.workstreams" ] &&
   git -C "$SPACE_ROOT" worktree list --porcelain | grep -qFx "worktree $SPACE_ROOT/.streams/spaced"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo 'FAIL: migration did not preserve the spaced-root worktree registry' >&2
fi

mkdir -p "$ROOT/.workstreams"; git -C "$ROOT" worktree add -q -b stream/nested "$ROOT/.workstreams/nested" main
mkdir -p "$ROOT/.workstreams/nested/.streams/copied"
if "$MIGRATOR" "$ROOT" inventory >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if "$MIGRATOR" "$ROOT" apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ -d "$ROOT/.workstreams/nested" ] && [ ! -e "$ROOT/.streams/nested" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT2="$TMP/resume"; init_repo "$ROOT2"
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial; mkdir -p "$ROOT2/.workstreams"
git -C "$ROOT2" worktree add -q -b stream/resume "$ROOT2/.workstreams/resume" main; printf '# resume handoff\n' >"$ROOT2/.workstreams/resume/WORKSTREAM.md"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
"$MIGRATOR" "$ROOT2" inventory >"$OUT"
if WORKSTREAM_TEST_AFTER_MIGRATION_MOVE="$TMP/interrupt.sh" "$MIGRATOR" "$ROOT2" apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'interrupted migration records moved stage' $'resume\t'"$ROOT2/.workstreams/resume"$'\t'"$ROOT2/.streams/resume"$'\tworktree\tstream/resume\tmain\tmoved\t' "$ROOT2/.streams/.migration.tsv"
instance="$(awk -F '\t' '$1=="resume"{print $8}' "$ROOT2/.streams/.migration.tsv")"
if [ -d "$ROOT2/.streams/resume" ] && [ ! -e "$ROOT2/.workstreams/resume" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
"$MIGRATOR" "$ROOT2" apply >"$OUT"; expect 'migration resumes after durable move' 'status=migrated' "$OUT"
expect 'resumed migration preserves manifest instance' $'instance-id\t'"$instance" "$ROOT2/.streams/resume/WORKSTREAM.md"
if [ ! -e "$ROOT2/.streams/.migration.tsv" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

ROOT3="$TMP/inplace"; init_repo "$ROOT3"
printf 'base\n' >"$ROOT3/file"; git -C "$ROOT3" add file; git -C "$ROOT3" commit -qm initial; git -C "$ROOT3" switch -qc stream/old
mkdir -p "$ROOT3/.workstreams/old"
cat >"$ROOT3/.workstreams/old/WORKSTREAM.md" <<'EOF'
# Legacy in-place purpose
- branch: stream/old
- integration-target: main
- isolation: in-place
EOF
mkdir -p "$ROOT3/.workstreams/other"
cat >"$ROOT3/.workstreams/other/WORKSTREAM.md" <<'EOF'
# Second legacy in-place purpose
- branch: stream/other
- integration-target: main
- isolation: in-place
EOF
git -C "$ROOT3" worktree add -q -b stream/linked "$ROOT3/.workstreams/linked" main
printf '# linked legacy handoff\n' >"$ROOT3/.workstreams/linked/WORKSTREAM.md"
git -C "$ROOT3" show-ref >"$TMP/inplace-refs"; git -C "$ROOT3" worktree list --porcelain >"$TMP/inplace-registry"
if "$MIGRATOR" "$ROOT3" inventory >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'mixed migration lists the first in-place stream' 'old: in-place stream must be finished' "$ERR"
expect 'mixed migration lists the second in-place stream' 'other: in-place stream must be finished' "$ERR"
if [ -d "$ROOT3/.workstreams/old" ] && [ -d "$ROOT3/.workstreams/other" ] && [ -d "$ROOT3/.workstreams/linked" ] && [ ! -e "$ROOT3/.streams" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
if cmp -s "$TMP/inplace-refs" <(git -C "$ROOT3" show-ref); then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: mixed refusal changed refs' >&2; fi
if cmp -s "$TMP/inplace-registry" <(git -C "$ROOT3" worktree list --porcelain); then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: mixed refusal changed worktree registry' >&2; fi
expect_eq 'in-place refusal does not switch the primary branch' stream/old "$(git -C "$ROOT3" branch --show-current)"

ROOT4="$TMP/bound"; init_repo "$ROOT4"
printf 'base\n' >"$ROOT4/file"; git -C "$ROOT4" add file; git -C "$ROOT4" commit -qm initial; mkdir -p "$ROOT4/.workstreams"
git -C "$ROOT4" worktree add -q -b stream/approved "$ROOT4/.workstreams/approved" main; printf '# approved handoff\n' >"$ROOT4/.workstreams/approved/WORKSTREAM.md"
"$MIGRATOR" "$ROOT4" inventory >"$OUT"
git -C "$ROOT4" worktree add -q -b stream/unapproved "$ROOT4/.workstreams/unapproved" main; printf '# unapproved handoff\n' >"$ROOT4/.workstreams/unapproved/WORKSTREAM.md"
if "$MIGRATOR" "$ROOT4" apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'apply refuses an unapproved stream' 'legacy stream set changed after inventory' "$ERR"
if [ -d "$ROOT4/.workstreams/approved" ] && [ ! -e "$ROOT4/.streams/approved" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
"$MIGRATOR" "$ROOT4" inventory >"$OUT"; "$MIGRATOR" "$ROOT4" apply >"$OUT"
expect 'refreshed inventory migrates exact approved set' 'streams=2' "$OUT"

ROOT5="$TMP/artifact-resume"; init_repo "$ROOT5"
printf 'base\n' >"$ROOT5/file"; git -C "$ROOT5" add file; git -C "$ROOT5" commit -qm initial; mkdir -p "$ROOT5/.workstreams"
git -C "$ROOT5" worktree add -q -b stream/artifact "$ROOT5/.workstreams/artifact" main; printf '# artifact handoff\n' >"$ROOT5/.workstreams/artifact/WORKSTREAM.md"
"$MIGRATOR" "$ROOT5" inventory >"$OUT"
if WORKSTREAM_TEST_AFTER_MIGRATION_TRACKER="$TMP/interrupt.sh" "$MIGRATOR" "$ROOT5" apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'artifact interruption leaves durable moved stage' $'artifact\t'"$ROOT5/.workstreams/artifact"$'\t'"$ROOT5/.streams/artifact"$'\tworktree\tstream/artifact\tmain\tmoved\t' "$ROOT5/.streams/.migration.tsv"
expect_absent 'legacy runbook remains until tracker is durable' '<!-- workstream:identity@1 -->' "$ROOT5/.streams/artifact/WORKSTREAM.md"
"$MIGRATOR" "$ROOT5" apply >"$OUT"
expect 'artifact transaction resumes' 'status=migrated' "$OUT"
"$HELPER" "$ROOT5" read artifact >"$OUT"; expect 'resumed artifacts bind' 'schema=workstream-read@1' "$OUT"

prepare_invalid() { # root stream
  local root="$1" stream="$2"
  init_repo "$root"; printf 'base\n' >"$root/file"; git -C "$root" add file; git -C "$root" commit -qm initial
  mkdir -p "$root/.workstreams"; git -C "$root" worktree add -q -b "stream/$stream" "$root/.workstreams/$stream" main
  printf '# invalid legacy handoff\n' >"$root/.workstreams/$stream/WORKSTREAM.md"
}

expect_inventory_refusal() { # root label diagnostic
  local root="$1" label="$2" diagnostic="$3"
  git -C "$root" show-ref >"$TMP/$label.refs"; git -C "$root" worktree list --porcelain >"$TMP/$label.registry"
  git -C "$root" status --porcelain --untracked-files=all >"$TMP/$label.status"
  find "$root/.workstreams" -mindepth 1 -maxdepth 3 -print | LC_ALL=C sort >"$TMP/$label.paths"
  if "$MIGRATOR" "$root" inventory >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
  expect "$label inventory refusal is explicit" "$diagnostic" "$ERR"
  if cmp -s "$TMP/$label.refs" <(git -C "$root" show-ref); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label inventory changed refs" >&2; fi
  if cmp -s "$TMP/$label.registry" <(git -C "$root" worktree list --porcelain); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label inventory changed registry" >&2; fi
  if cmp -s "$TMP/$label.status" <(git -C "$root" status --porcelain --untracked-files=all); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label inventory changed primary state" >&2; fi
  if cmp -s "$TMP/$label.paths" <(find "$root/.workstreams" -mindepth 1 -maxdepth 3 -print | LC_ALL=C sort); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label inventory changed legacy paths" >&2; fi
  if [ ! -e "$root/.streams/.migration.tsv" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label inventory created a manifest" >&2; fi
}

INVALID_DIRT="$TMP/invalid-dirt"; prepare_invalid "$INVALID_DIRT" dirt
printf 'wip\n' >>"$INVALID_DIRT/.workstreams/dirt/file"
expect_inventory_refusal "$INVALID_DIRT" dirt 'tracked path blocks migration: file'

INVALID_INTERRUPTED="$TMP/invalid-interrupted"; prepare_invalid "$INVALID_INTERRUPTED" interrupted
admin_path="$(git -C "$INVALID_INTERRUPTED/.workstreams/interrupted" rev-parse --git-path CHERRY_PICK_HEAD)"; case "$admin_path" in /*) ;; *) admin_path="$INVALID_INTERRUPTED/.workstreams/interrupted/$admin_path" ;; esac
printf '%s\n' "$(git -C "$INVALID_INTERRUPTED/.workstreams/interrupted" rev-parse HEAD)" >"$admin_path"
expect_inventory_refusal "$INVALID_INTERRUPTED" interrupted 'interrupted Git administration'

INVALID_DIVERGED="$TMP/invalid-diverged"; prepare_invalid "$INVALID_DIVERGED" diverged
printf 'target\n' >"$INVALID_DIVERGED/target"; git -C "$INVALID_DIVERGED" add target; git -C "$INVALID_DIVERGED" commit -qm target
"$MIGRATOR" "$INVALID_DIVERGED" inventory >"$OUT" 2>"$ERR"
expect 'behind-only inventory is not a refusal' 'relation=behind' "$OUT"
expect 'behind-only inventory reports the gap' 'behind=' "$OUT"

INVALID_SYMLINK="$TMP/invalid-symlink"; prepare_invalid "$INVALID_SYMLINK" linked; mkdir "$TMP/outside-legacy"; ln -s "$TMP/outside-legacy" "$INVALID_SYMLINK/.workstreams/alias"
expect_inventory_refusal "$INVALID_SYMLINK" symlink 'unknown child'

INVALID_UNREGISTERED="$TMP/invalid-unregistered"; prepare_invalid "$INVALID_UNREGISTERED" linked
mkdir "$INVALID_UNREGISTERED/.workstreams/orphan"; printf '# orphan\n' >"$INVALID_UNREGISTERED/.workstreams/orphan/WORKSTREAM.md"
expect_inventory_refusal "$INVALID_UNREGISTERED" unregistered 'unregistered or ambiguous'

INVALID_NESTED="$TMP/invalid-nested"; prepare_invalid "$INVALID_NESTED" nested; mkdir -p "$INVALID_NESTED/.workstreams/nested/.streams/copied"
expect_inventory_refusal "$INVALID_NESTED" nested 'contains nested stream state'

INVALID_COLLISION="$TMP/invalid-collision"; prepare_invalid "$INVALID_COLLISION" collision; mkdir -p "$INVALID_COLLISION/.streams/collision"
expect_inventory_refusal "$INVALID_COLLISION" collision 'destination already exists'

INVALID_AMBIGUOUS="$TMP/invalid-ambiguous"; prepare_invalid "$INVALID_AMBIGUOUS" ambiguous
printf '%s\n' '- target: main' '- integration-target: main' >>"$INVALID_AMBIGUOUS/.workstreams/ambiguous/WORKSTREAM.md"
expect_inventory_refusal "$INVALID_AMBIGUOUS" ambiguous 'legacy target is ambiguous'

INVALID_TICK="$TMP/invalid-tick"; prepare_invalid "$INVALID_TICK" tick
printf '%s\n' "- integration-target: \`not a branch!!\`" >>"$INVALID_TICK/.workstreams/tick/WORKSTREAM.md"
expect_inventory_refusal "$INVALID_TICK" tick 'normalized integration target is invalid'

expect_apply_refusal() { # root stream label diagnostic
  local root="$1" stream="$2" label="$3" diagnostic="$4"
  cp "$root/.streams/.migration.tsv" "$TMP/$label.manifest"
  git -C "$root" show-ref >"$TMP/$label.refs"; git -C "$root" worktree list --porcelain >"$TMP/$label.registry"
  git -C "$root" status --porcelain --untracked-files=all >"$TMP/$label.status"
  find "$root/.workstreams" "$root/.streams" -mindepth 0 -maxdepth 3 -print | LC_ALL=C sort >"$TMP/$label.paths"
  if "$MIGRATOR" "$root" apply >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
  expect "$label apply refusal is explicit" "$diagnostic" "$ERR"
  if cmp -s "$TMP/$label.manifest" "$root/.streams/.migration.tsv"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label apply changed the manifest" >&2; fi
  if cmp -s "$TMP/$label.refs" <(git -C "$root" show-ref); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label apply changed refs" >&2; fi
  if cmp -s "$TMP/$label.registry" <(git -C "$root" worktree list --porcelain); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label apply changed registry" >&2; fi
  if cmp -s "$TMP/$label.status" <(git -C "$root" status --porcelain --untracked-files=all); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label apply changed primary state" >&2; fi
  if cmp -s "$TMP/$label.paths" <(find "$root/.workstreams" "$root/.streams" -mindepth 0 -maxdepth 3 -print | LC_ALL=C sort); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label apply changed paths" >&2; fi
  if [ -d "$root/.workstreams/$stream" ] && git -C "$root" worktree list --porcelain | grep -qFx "worktree $root/.workstreams/$stream"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label apply moved a worktree" >&2; fi
}

APPLY_HANDOFF="$TMP/apply-handoff"; prepare_invalid "$APPLY_HANDOFF" handoff; "$MIGRATOR" "$APPLY_HANDOFF" inventory >"$OUT"
printf 'changed\n' >>"$APPLY_HANDOFF/.workstreams/handoff/WORKSTREAM.md"
expect_apply_refusal "$APPLY_HANDOFF" handoff handoff 'legacy handoff changed after inventory'

APPLY_TIP="$TMP/apply-tip"; prepare_invalid "$APPLY_TIP" tip; "$MIGRATOR" "$APPLY_TIP" inventory >"$OUT"
printf 'tip\n' >"$APPLY_TIP/.workstreams/tip/tip"; git -C "$APPLY_TIP/.workstreams/tip" add tip; git -C "$APPLY_TIP/.workstreams/tip" commit -qm tip
expect_apply_refusal "$APPLY_TIP" tip tip 'legacy branch moved after inventory'

APPLY_TARGET="$TMP/apply-target"; prepare_invalid "$APPLY_TARGET" target; "$MIGRATOR" "$APPLY_TARGET" inventory >"$OUT"
printf 'target moved\n' >"$APPLY_TARGET/target"; git -C "$APPLY_TARGET" add target; git -C "$APPLY_TARGET" commit -qm 'target moved'
expect_apply_refusal "$APPLY_TARGET" target target 'legacy target boundary moved after inventory'

APPLY_DESTINATION="$TMP/apply-destination"; prepare_invalid "$APPLY_DESTINATION" destination; "$MIGRATOR" "$APPLY_DESTINATION" inventory >"$OUT"
mkdir "$APPLY_DESTINATION/.streams/destination"
expect_apply_refusal "$APPLY_DESTINATION" destination destination 'destination already exists'

APPLY_SET="$TMP/apply-set"; prepare_invalid "$APPLY_SET" set; "$MIGRATOR" "$APPLY_SET" inventory >"$OUT"
mkdir "$TMP/apply-set-outside"; ln -s "$TMP/apply-set-outside" "$APPLY_SET/.workstreams/alias"
expect_apply_refusal "$APPLY_SET" set set 'legacy stream set changed after inventory'

assert_preserved_tips() { # root stream label before-stream before-target
  local root="$1" stream="$2" label="$3" before_stream="$4" before_target="$5" after_stream after_target
  after_stream="$(git -C "$root/.streams/$stream" rev-parse HEAD)"
  after_target="$(git -C "$root" rev-parse main)"
  expect_eq "$label preserves stream tip" "$before_stream" "$after_stream"
  expect_eq "$label preserves target tip" "$before_target" "$after_target"
}

BEHIND="$TMP/behind"; prepare_invalid "$BEHIND" stale
before_stream="$(git -C "$BEHIND/.workstreams/stale" rev-parse HEAD)"
i=1; while [ "$i" -le 8 ]; do
  printf 'target-%s\n' "$i" >"$BEHIND/target"
  git -C "$BEHIND" add target
  git -C "$BEHIND" commit -qm "target $i"
  i=$((i + 1))
done
before_target="$(git -C "$BEHIND" rev-parse main)"
"$MIGRATOR" "$BEHIND" inventory >"$OUT" 2>"$ERR"
expect 'behind inventory classifies behind' 'relation=behind' "$OUT"
"$MIGRATOR" "$BEHIND" apply >"$OUT"
expect 'behind apply migrates' 'status=migrated' "$OUT"
assert_preserved_tips "$BEHIND" stale behind "$before_stream" "$before_target"
if [ -d "$BEHIND/.streams/stale" ] && [ ! -e "$BEHIND/.workstreams" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: behind stream was not relocated' >&2; fi
"$HELPER" "$BEHIND" read stale >"$OUT"
expect 'behind read asks for sync' 'next_action=sync' "$OUT"

DIVERGED="$TMP/diverged"; prepare_invalid "$DIVERGED" split
printf 'stream-only\n' >"$DIVERGED/.workstreams/split/stream-only"
git -C "$DIVERGED/.workstreams/split" add stream-only
git -C "$DIVERGED/.workstreams/split" commit -qm 'stream unique work'
before_stream="$(git -C "$DIVERGED/.workstreams/split" rev-parse HEAD)"
printf 'target-only\n' >"$DIVERGED/target-only"
git -C "$DIVERGED" add target-only
git -C "$DIVERGED" commit -qm 'target unique work'
before_target="$(git -C "$DIVERGED" rev-parse main)"
"$MIGRATOR" "$DIVERGED" inventory >"$OUT"
expect 'diverged inventory classifies diverged' 'relation=diverged' "$OUT"
"$MIGRATOR" "$DIVERGED" apply >"$OUT"
expect 'diverged apply migrates' 'status=migrated' "$OUT"
assert_preserved_tips "$DIVERGED" split diverged "$before_stream" "$before_target"
"$HELPER" "$DIVERGED" read split >"$OUT"
expect 'diverged read asks for sync' 'next_action=sync' "$OUT"
expect 'diverged unique commits stay a migrated unit' $'unit\t1\tstate\tcomplete' "$DIVERGED/.streams/split/workstream.tsv"
expect 'diverged preserves the unique subject' $'subject\tstream unique work' "$DIVERGED/.streams/split/workstream.tsv"
merge_base="$(git -C "$DIVERGED/.streams/split" merge-base HEAD main)"
expect 'diverged unit boundary is the merge base' $'unit\t1\tboundary\t'"$merge_base" "$DIVERGED/.streams/split/workstream.tsv"

MARKDOWN="$TMP/markdown"; prepare_invalid "$MARKDOWN" wrapped
printf '%s\n' "- integration-target: \`main\`" >>"$MARKDOWN/.workstreams/wrapped/WORKSTREAM.md"
"$MIGRATOR" "$MARKDOWN" inventory >"$OUT" 2>"$ERR"
expect 'markdown-wrapped target inventories' 'target=main' "$OUT"
"$MIGRATOR" "$MARKDOWN" apply >"$OUT"
expect 'markdown-wrapped target migrates' 'status=migrated' "$OUT"

DSSTORE="$TMP/dsstore"; prepare_invalid "$DSSTORE" finder
printf 'finder\n' >"$DSSTORE/.workstreams/.DS_Store"
"$MIGRATOR" "$DSSTORE" inventory >"$OUT" 2>"$ERR"
expect 'Finder metadata is a warning' 'ignored Finder metadata' "$ERR"
expect 'Finder metadata does not block inventory' 'status=inventory' "$OUT"
"$MIGRATOR" "$DSSTORE" apply >"$OUT"
expect 'Finder metadata still migrates' 'status=migrated' "$OUT"
if [ ! -e "$DSSTORE/.workstreams" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: .workstreams remained after ignoring .DS_Store' >&2; fi

UNTRACKED="$TMP/untracked"; prepare_invalid "$UNTRACKED" notes
printf 'keep me\n' >"$UNTRACKED/.workstreams/notes/scratch.md"
"$MIGRATOR" "$UNTRACKED" inventory >"$OUT" 2>"$ERR"
expect 'untracked inventory reports dirt' 'dirt=untracked:1' "$OUT"
expect 'untracked inventory names the path' 'untracked path will move with the worktree: scratch.md' "$ERR"
"$MIGRATOR" "$UNTRACKED" apply >"$OUT"
expect 'untracked apply migrates' 'status=migrated' "$OUT"
if [ -f "$UNTRACKED/.streams/notes/scratch.md" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: untracked file was not carried' >&2; fi

GITLINK="$TMP/gitlink"; SUB="$TMP/sub"
prepare_invalid "$GITLINK" vendor
init_repo "$SUB"
printf 'sub\n' >"$SUB/sub"; git -C "$SUB" add sub; git -C "$SUB" commit -qm sub
object="$(git -C "$SUB" rev-parse HEAD)"
git -C "$GITLINK/.workstreams/vendor" config advice.addEmbeddedRepo false
git clone -q "$SUB" "$GITLINK/.workstreams/vendor/vendor"
git -C "$GITLINK/.workstreams/vendor" add vendor
git -C "$GITLINK/.workstreams/vendor" commit -qm 'add vendor gitlink'
before_stream="$(git -C "$GITLINK/.workstreams/vendor" rev-parse HEAD)"
before_link="$(git -C "$GITLINK/.workstreams/vendor" ls-files -s vendor | awk '{print $2}')"
"$MIGRATOR" "$GITLINK" inventory >"$OUT"
"$MIGRATOR" "$GITLINK" apply >"$OUT"
expect 'gitlink apply migrates' 'status=migrated' "$OUT"
after_link="$(git -C "$GITLINK/.streams/vendor" ls-files -s vendor | awk '{print $2}')"
expect_eq 'gitlink object is unchanged' "$before_link" "$after_link"
expect_eq 'gitlink object matches the submodule commit' "$object" "$after_link"
expect_eq 'gitlink stream tip is unchanged' "$before_stream" "$(git -C "$GITLINK/.streams/vendor" rev-parse HEAD)"

AGGREGATE="$TMP/aggregate"; prepare_invalid "$AGGREGATE" first
printf 'dirty\n' >>"$AGGREGATE/.workstreams/first/file"
git -C "$AGGREGATE" worktree add -q -b stream/second "$AGGREGATE/.workstreams/second" main
printf '# second\n' >"$AGGREGATE/.workstreams/second/WORKSTREAM.md"
mkdir -p "$AGGREGATE/.streams/second"
if "$MIGRATOR" "$AGGREGATE" inventory >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'aggregate reports tracked dirt' 'first: tracked path blocks migration: file' "$ERR"
expect 'aggregate reports destination collision' 'second: destination already exists:' "$ERR"
if [ ! -e "$AGGREGATE/.streams/.migration.tsv" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: aggregate inventory wrote a manifest' >&2; fi

UNKNOWN="$TMP/unknown"; prepare_invalid "$UNKNOWN" keep
printf 'finder\n' >"$UNKNOWN/.workstreams/.DS_Store"
printf 'nope\n' >"$UNKNOWN/.workstreams/notes.txt"
if "$MIGRATOR" "$UNKNOWN" inventory >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'unknown child names the path' 'notes.txt: unknown child' "$ERR"
expect 'Finder metadata is still warned when a sibling blocks' 'ignored Finder metadata' "$ERR"

report 'workstream migration'
