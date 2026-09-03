#!/usr/bin/env bash
# Every primary-target mutation requires one clean, coherent, leased endpoint.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-primary.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT

prepare_stream() { # root stream
  local root="$1" stream="$2"
  init_repo "$root"
  printf 'base\n' >"$root/file"; git -C "$root" add file; git -C "$root" commit -qm initial
  "$HELPER" "$root" runtime-init "$stream" main "$stream" >"$OUT"
  "$HELPER" "$root" unit-begin "$stream" unit unit >"$OUT"
  printf 'unit\n' >>"$root/.streams/$stream/file"
  git -C "$root/.streams/$stream" add file; git -C "$root/.streams/$stream" commit -qm unit
  "$HELPER" "$root" unit-complete "$stream" >"$OUT"
  "$HELPER" "$root" ship-prepare "$stream" >"$OUT"
  "$HELPER" "$root" gate-run "$stream" --class full --label gate -- true >"$OUT"
}

snapshot_primary() { # root stream label
  local root="$1" stream="$2" label="$3"
  git -C "$root" show-ref >"$TMP/$label.refs"
  git -C "$root" write-tree >"$TMP/$label.index"
  git -C "$root" status --porcelain --untracked-files=all >"$TMP/$label.status"
  git -C "$root" branch --show-current >"$TMP/$label.branch"
  cp "$root/.streams/$stream/workstream.tsv" "$TMP/$label.tracker"
}

expect_refusal_unchanged() { # root stream label diagnostic
  local root="$1" stream="$2" label="$3" diagnostic="$4"
  snapshot_primary "$root" "$stream" "$label"
  if "$HELPER" "$root" land-advance "$stream" --authority confirmed >"$OUT" 2>"$ERR"; then
    fail=$((fail + 1)); echo "FAIL: $label primary state was accepted" >&2
  else
    pass=$((pass + 1))
  fi
  expect "$label refusal is explicit" "$diagnostic" "$ERR"
  if cmp -s "$TMP/$label.refs" <(git -C "$root" show-ref); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label refusal changed refs" >&2; fi
  expect_eq "$label refusal preserves the index" "$(cat "$TMP/$label.index")" "$(git -C "$root" write-tree)"
  if cmp -s "$TMP/$label.status" <(git -C "$root" status --porcelain --untracked-files=all); then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label refusal changed the worktree" >&2; fi
  expect_eq "$label refusal preserves the branch" "$(cat "$TMP/$label.branch")" "$(git -C "$root" branch --show-current)"
  if cmp -s "$TMP/$label.tracker" "$root/.streams/$stream/workstream.tsv"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label refusal changed receipts" >&2; fi
}

# Worktree-local lifecycle operations remain available while the primary is dirty.
SAFE="$TMP/safe"; init_repo "$SAFE"
printf 'base\n' >"$SAFE/file"; git -C "$SAFE" add file; git -C "$SAFE" commit -qm initial
printf 'primary wip\n' >"$SAFE/primary-wip"
"$HELPER" "$SAFE" runtime-init safe main safe >"$OUT"; expect 'create proceeds beside primary dirt' 'status=created' "$OUT"
"$HELPER" "$SAFE" read safe >"$OUT"; expect 'load projection proceeds beside primary dirt' 'schema=workstream-read@1' "$OUT"
"$HELPER" "$SAFE" operator-note safe 'keep going' >"$OUT"; expect 'save proceeds beside primary dirt' 'status=saved' "$OUT"
"$HELPER" "$SAFE" unit-begin safe unit unit >"$OUT"
printf 'unit\n' >>"$SAFE/.streams/safe/file"; git -C "$SAFE/.streams/safe" add file; git -C "$SAFE/.streams/safe" commit -qm unit
"$HELPER" "$SAFE" unit-complete safe >"$OUT"; expect 'unit completion proceeds beside primary dirt' 'status=unit-complete' "$OUT"
"$HELPER" "$SAFE" sync safe >"$OUT"; expect 'sync proceeds beside primary dirt' 'status=current' "$OUT"
"$HELPER" "$SAFE" ship-prepare safe >"$OUT"; expect 'prepare proceeds beside primary dirt' 'status=gate-required' "$OUT"
"$HELPER" "$SAFE" gate-run safe --class full --label gate -- true >"$OUT"
expect_refusal_unchanged "$SAFE" safe safe-untracked 'primary checkout is not completely clean'

for kind in modified staged untracked wrong-branch moved-target; do
  root="$TMP/$kind"; prepare_stream "$root" "$kind"
  diagnostic='primary checkout is not completely clean'
  case "$kind" in
    modified) printf 'modified\n' >>"$root/file" ;;
    staged) printf 'staged\n' >"$root/staged"; git -C "$root" add staged ;;
    untracked) printf 'untracked\n' >"$root/untracked" ;;
    wrong-branch) git -C "$root" switch -qc side; diagnostic='primary checkout is not on the target branch' ;;
    moved-target) printf 'target moved\n' >"$root/moved"; git -C "$root" add moved; git -C "$root" commit -qm moved; diagnostic='primary target moved after preparation' ;;
  esac
  expect_refusal_unchanged "$root" "$kind" "$kind" "$diagnostic"
done

for interrupted in merge:MERGE_HEAD rebase-merge:rebase-merge rebase-apply:rebase-apply \
                   cherry-pick:CHERRY_PICK_HEAD revert:REVERT_HEAD sequencer:sequencer bisect:BISECT_START; do
  label="${interrupted%%:*}"; admin="${interrupted#*:}"; root="$TMP/interrupted-$label"
  prepare_stream "$root" "interrupted-$label"
  admin_path="$(git -C "$root" rev-parse --git-path "$admin")"
  case "$admin_path" in /*) ;; *) admin_path="$root/$admin_path" ;; esac
  case "$admin" in rebase-merge|rebase-apply|sequencer) mkdir -p "$admin_path" ;; *) mkdir -p "$(dirname "$admin_path")"; printf '%s\n' "$(git -C "$root" rev-parse HEAD)" >"$admin_path" ;; esac
  diagnostic="$label"; case "$label" in rebase-merge|rebase-apply) diagnostic=rebase ;; esac
  expect_refusal_unchanged "$root" "interrupted-$label" "interrupted-$label" "interrupted $diagnostic administration"
done

# A deterministic target race between admission and mutation is detected and never reported landed.
RACE="$TMP/race"; prepare_stream "$RACE" race
cat >"$TMP/move-target.sh" <<'EOF'
#!/usr/bin/env bash
root="$1"; target="$2"; old="$(git -C "$root" rev-parse "$target")"; tree="$(git -C "$root" rev-parse "$old^{tree}")"
new="$(printf 'racing target\n' | git -C "$root" commit-tree "$tree" -p "$old")"
git -C "$root" update-ref "refs/heads/$target" "$new" "$old"
EOF
chmod +x "$TMP/move-target.sh"
cp "$RACE/.streams/race/workstream.tsv" "$TMP/race-before.tracker"
candidate="$(git -C "$RACE/.streams/race" rev-parse HEAD)"
if WORKSTREAM_TEST_AFTER_PRIMARY_ADMISSION="$TMP/move-target.sh" \
  "$HELPER" "$RACE" land-advance race --authority confirmed >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1)); echo 'FAIL: target race was reported as successful' >&2
else
  pass=$((pass + 1))
fi
expect_absent 'target race never reports a landed result' 'status=landed' "$OUT"
if cmp -s "$TMP/race-before.tracker" "$RACE/.streams/race/workstream.tsv"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: target race changed receipts' >&2; fi
if [ "$(git -C "$RACE" rev-parse main)" != "$candidate" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: target race falsely landed the candidate' >&2; fi

report 'workstream primary checkout contract'
