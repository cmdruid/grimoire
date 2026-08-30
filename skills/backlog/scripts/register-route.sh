#!/usr/bin/env bash
# register-route.sh — reconcile only Backlog's bounded route in root AGENTS.md.
set -euo pipefail

die() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }

cmd="${1:-}"
shift || true
ROOT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    *) die usage ;;
  esac
done

case "$cmd" in preflight|ensure|remove) ;; *) die usage ;; esac
case "$ROOT" in /*) ;; *) die unsafe-root "$ROOT" ;; esac
[ -d "$ROOT" ] && [ ! -L "$ROOT" ] || die unsafe-root "$ROOT"
ROOT="$(CDPATH='' cd -P "$ROOT" && pwd)"

BASE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
STATUS="$BASE/route-status.sh"
TEMPLATE="$BASE/../templates/debrief-anchor.md"
DOOR="$ROOT/AGENTS.md"
TEMP="$DOOR.tmp.$$"
SNAPSHOT="$DOOR.route-snapshot.$$"
TEMP_OWNED=false
SNAPSHOT_OWNED=false

cleanup() {
  [ "$TEMP_OWNED" = false ] || rm -f -- "$TEMP"
  [ "$SNAPSHOT_OWNED" = false ] || rm -f -- "$SNAPSHOT"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

check_door() {
  [ ! -L "$DOOR" ] || die symlink "$DOOR"
  [ ! -e "$DOOR" ] || [ -f "$DOOR" ] || die incompatible-entry "$DOOR"
}

fresh_path() {
  [ ! -L "$1" ] || die symlink "$1"
  [ ! -e "$1" ] || die incompatible-entry "$1"
}

fact() { printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -n 1; }

classify() {
  if output="$($STATUS "$TEMPLATE" "$DOOR")"; then
    printf '%s\n' "$output"
  else
    rc=$?
    printf '%s\n' "$output"
    exit "$rc"
  fi
}

run_hook() {
  hook_name="$1"
  case "$hook_name" in
    BACKLOG_ROUTE_TEST_BEFORE_REPLACE) hook_path="${BACKLOG_ROUTE_TEST_BEFORE_REPLACE:-}" ;;
    BACKLOG_ROUTE_TEST_BEFORE_RENAME) hook_path="${BACKLOG_ROUTE_TEST_BEFORE_RENAME:-}" ;;
    *) die test-hook "$hook_name" ;;
  esac
  [ -z "$hook_path" ] && return 0
  [ -x "$hook_path" ] || die test-hook "$hook_name"
  "$hook_path" "$ROOT" "$DOOR"
}

snapshot_target() {
  fresh_path "$SNAPSHOT"
  if [ -f "$DOOR" ]; then
    cp "$DOOR" "$SNAPSHOT"
    SNAPSHOT_OWNED=true
    snapshot_missing=false
  else
    snapshot_missing=true
  fi
}

target_unchanged() {
  check_door
  if [ "$snapshot_missing" = true ]; then
    [ ! -e "$DOOR" ] && [ ! -L "$DOOR" ]
  else
    [ -f "$DOOR" ] && cmp -s "$SNAPSHOT" "$DOOR"
  fi
}

prepare_temp() {
  fresh_path "$TEMP"
  TEMP_OWNED=true
}

append_current() {
  prepare_temp
  if [ ! -f "$DOOR" ]; then
    {
      printf '# Agent instructions\n\n## Skill routes (self-registered)\n\n'
      cat "$TEMPLATE"
    } > "$TEMP"
    return
  fi

  cp "$DOOR" "$TEMP"
  if [ -s "$DOOR" ] && [ "$(tail -c 1 "$DOOR" | wc -l | tr -d ' ')" -eq 0 ]; then
    printf '\n' >> "$TEMP"
  fi
  if ! grep -Fxq '## Skill routes (self-registered)' "$DOOR"; then
    printf '\n## Skill routes (self-registered)\n' >> "$TEMP"
  fi
  printf '\n' >> "$TEMP"
  cat "$TEMPLATE" >> "$TEMP"
}

replace_extent() {
  begin_line="$1"
  end_line="$2"
  prepare_temp
  if [ "$begin_line" -gt 1 ]; then head -n "$((begin_line - 1))" "$DOOR" > "$TEMP"
  else : > "$TEMP"; fi
  cat "$TEMPLATE" >> "$TEMP"
  tail -n "+$((end_line + 1))" "$DOOR" >> "$TEMP"
}

remove_extent() {
  begin_line="$1"
  end_line="$2"
  prepare_temp
  if [ "$begin_line" -gt 1 ]; then head -n "$((begin_line - 1))" "$DOOR" > "$TEMP"
  else : > "$TEMP"; fi
  tail -n "+$((end_line + 1))" "$DOOR" >> "$TEMP"
}

commit_temp() {
  # Classify again and compare byte-for-byte immediately before rename, so a
  # same-shape destination race cannot be silently overwritten.
  classify >/dev/null
  target_unchanged || die route-raced
  run_hook BACKLOG_ROUTE_TEST_BEFORE_RENAME
  classify >/dev/null
  target_unchanged || die route-raced
  mv "$TEMP" "$DOOR"
  TEMP_OWNED=false
  echo 'wrote=AGENTS.md'
}

check_door
initial="$(classify)"
if [ "$cmd" = preflight ]; then
  printf '%s\n' "$initial"
  exit 0
fi

status="$(fact "$initial" route_status)"
begin_line="$(fact "$initial" route_begin_line)"
end_line="$(fact "$initial" route_end_line)"
if [ "$cmd" = ensure ] && [ "$status" = current ]; then exit 0; fi
if [ "$cmd" = remove ] && [ "$status" = absent ]; then exit 0; fi

snapshot_target
run_hook BACKLOG_ROUTE_TEST_BEFORE_REPLACE
target_unchanged || die route-raced

if [ "$cmd" = ensure ]; then
  case "$status" in
    absent) append_current ;;
    drifted-current|replaceable-managed) replace_extent "$begin_line" "$end_line" ;;
    *) die invalid-route-state "$status" ;;
  esac
else
  case "$status" in
    current|drifted-current|replaceable-managed) remove_extent "$begin_line" "$end_line" ;;
    *) die invalid-route-state "$status" ;;
  esac
fi

if [ -f "$DOOR" ] && cmp -s "$DOOR" "$TEMP"; then exit 0; fi
commit_temp
