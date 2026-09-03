#!/usr/bin/env bash
# checkpoint-file.sh — single-root Checkpoint identity and mutation helper.
#
# token
# admit <root> <stable-handle>                 guarded Recovery read
# inspect <root>                               explicit Resume read
# match <root> <stable-handle>                 body-free ownership check
# occupancy <root>                             body/token-free foreign-file probe
# save <root> <new|expected-token>             complete document on stdin
# overwrite <root> <expected-fingerprint>      guarded foreign-file replacement
# claim <root> <expected-token> <fingerprint>  confirmed Resume token rotation
# delete <root> <expected-token>               owned lifecycle close
set -euo pipefail

BASE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
LOCK_OWNED=false
TEMP_OWNED=false
ROOT=""
TARGET=""
TEMP=""
LOCK=""
IS_GIT=false

usage() {
  echo "usage: checkpoint-file.sh token | admit <root> <handle> | inspect <root> | match <root> <handle> | occupancy <root> | save <root> <new|token> | overwrite <root> <fingerprint> | claim <root> <token> <fingerprint> | delete <root> <token>" >&2
  exit 2
}

fail() { echo "$*" >&2; exit 1; }
valid_token() { printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{32}$'; }
valid_fingerprint() { printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{64}$'; }

new_token() {
  value="$(LC_ALL=C od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  valid_token "$value" || fail "failed to generate checkpoint token"
  printf '%s\n' "$value"
}

cleanup() {
  if [ "$TEMP_OWNED" = true ] && [ -n "$TEMP" ]; then rm -f -- "$TEMP"; fi
  if [ "$LOCK_OWNED" = true ] && [ -n "$LOCK" ]; then rmdir -- "$LOCK" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

init_root() {
  candidate="$1"
  case "$candidate" in /*) ;; *) return 1 ;; esac
  [ -d "$candidate" ] && [ ! -L "$candidate" ] || return 1
  canonical="$(CDPATH='' cd -P "$candidate" && pwd)" || return 1
  [ "$canonical" = "$candidate" ] || return 1
  ROOT="$canonical"
  TARGET="$ROOT/CHECKPOINT.md"
  TEMP="$ROOT/CHECKPOINT.md.tmp"

  if top="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)"; then
    top="$(CDPATH='' cd -P "$top" && pwd)"
    [ "$top" = "$ROOT" ] || return 1
    IS_GIT=true
    git_dir="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
    LOCK="$git_dir/checkpoint.lock"
  else
    IS_GIT=false
    LOCK="$ROOT/.CHECKPOINT.lock"
  fi
}

fact() { printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1; }

guard_stream() {
  guard="$("$BASE/save-guard.sh" "$ROOT")" || return 1
  [ "$(fact "$guard" worktree_stream)" != true ] || return 1
}

acquire_lock() {
  if ! mkdir "$LOCK" 2>/dev/null; then
    echo "checkpoint mutation locked: $LOCK" >&2
    return 1
  fi
  LOCK_OWNED=true
}

git_tracked() { git -C "$ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
git_ignored() { git -C "$ROOT" check-ignore -q -- "$1" >/dev/null 2>&1; }

exclude_file() {
  common="$(git -C "$ROOT" rev-parse --git-common-dir)" || return 1
  case "$common" in /*) common_abs="$common" ;; *) common_abs="$ROOT/$common" ;; esac
  common_abs="$(CDPATH='' cd -P "$common_abs" && pwd)" || return 1
  printf '%s/info/exclude\n' "$common_abs"
}

ensure_ignore() { # repo-relative path, anchored rule
  rel="$1"; rule="$2"
  git_ignored "$rel" && return 0
  exclude="$(exclude_file)" || return 1
  if [ ! -e "$exclude" ] && [ ! -L "$exclude" ]; then
    (umask 077; set -C; : > "$exclude") 2>/dev/null || return 1
  fi
  [ -f "$exclude" ] && [ ! -L "$exclude" ] && [ -w "$exclude" ] || return 1
  if grep -Fxq -- "$rule" "$exclude"; then return 1; fi
  printf '%s\n' "$rule" >> "$exclude" || return 1
  git_ignored "$rel"
}

check_git_read_guards() {
  [ "$IS_GIT" = true ] || return 0
  ! git_tracked CHECKPOINT.md && git_ignored CHECKPOINT.md
}

ensure_git_mutation_guards() {
  [ "$IS_GIT" = true ] || return 0
  ! git_tracked CHECKPOINT.md || return 1
  ! git_tracked CHECKPOINT.md.tmp || return 1
  ensure_ignore CHECKPOINT.md /CHECKPOINT.md || return 1
  ensure_ignore CHECKPOINT.md.tmp /CHECKPOINT.md.tmp
}

validate_target_shape() { [ -f "$TARGET" ] && [ ! -L "$TARGET" ] && [ -r "$TARGET" ]; }

validate_file() { # file [expected-token]
  local file expected line1 line2 stored
  file="$1"; expected="${2:-}"
  [ -f "$file" ] && [ ! -L "$file" ] && [ -r "$file" ] || return 1
  line1=""; line2=""
  {
    IFS= read -r line1 || return 1
    IFS= read -r line2 || return 1
  } < "$file"
  [ "$line1" = "# CHECKPOINT — file: $TARGET" ] || return 1
  case "$line2" in "checkpoint-token: "*) stored="${line2#checkpoint-token: }" ;; *) return 1 ;; esac
  valid_token "$stored" || return 1
  [ -z "$expected" ] || [ "$stored" = "$expected" ] || return 1
  STORED_TOKEN="$stored"
}

parse_handle() {
  handle="$1"; prefix='CHECKPOINT — file: '; delimiter=' — token: '
  case "$handle" in "$prefix"*"$delimiter"*) ;; *) return 1 ;; esac
  payload="${handle#"$prefix"}"
  HANDLE_TOKEN="${payload##*"$delimiter"}"
  HANDLE_PATH="${payload%"$delimiter"*}"
  valid_token "$HANDLE_TOKEN" || return 1
  [ "$HANDLE_PATH" = "$TARGET" ] || return 1
  [ "$handle" = "${prefix}${HANDLE_PATH}${delimiter}${HANDLE_TOKEN}" ]
}

fingerprint_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

deny_token() { echo "token_match=false"; exit 1; }
deny_checkpoint() { echo "checkpoint_valid=false"; exit 1; }
deny_occupancy() { echo "checkpoint_occupancy=invalid"; exit 1; }

[ "$#" -ge 1 ] || usage
command_name="$1"

case "$command_name" in
  token)
    [ "$#" -eq 1 ] || usage
    new_token
    ;;

  admit)
    [ "$#" -eq 3 ] || usage
    init_root "$2" >/dev/null 2>&1 || deny_token
    guard_stream >/dev/null 2>&1 || deny_token
    parse_handle "$3" || deny_token
    check_git_read_guards || deny_token
    acquire_lock >/dev/null 2>&1 || deny_token
    validate_target_shape || deny_token
    awk -v token="$HANDLE_TOKEN" -v path="$TARGET" '
      { lines[NR] = $0 }
      END {
        if (NR < 2 || lines[1] != "# CHECKPOINT — file: " path ||
            lines[2] != "checkpoint-token: " token) {
          print "token_match=false"; exit 1
        }
        print "token_match=true"
        for (i = 1; i <= NR; i++) print lines[i]
      }
    ' "$TARGET"
    ;;

  inspect)
    [ "$#" -eq 2 ] || usage
    init_root "$2" >/dev/null 2>&1 || deny_checkpoint
    guard_stream >/dev/null 2>&1 || deny_checkpoint
    check_git_read_guards || deny_checkpoint
    acquire_lock >/dev/null 2>&1 || deny_checkpoint
    validate_target_shape && validate_file "$TARGET" || deny_checkpoint
    fingerprint="$(fingerprint_file "$TARGET")" || deny_checkpoint
    valid_fingerprint "$fingerprint" || deny_checkpoint
    echo "checkpoint_valid=true"
    echo "checkpoint_token=$STORED_TOKEN"
    echo "checkpoint_fingerprint=$fingerprint"
    cat -- "$TARGET"
    ;;

  match)
    [ "$#" -eq 3 ] || usage
    init_root "$2" >/dev/null 2>&1 || deny_token
    guard_stream >/dev/null 2>&1 || deny_token
    parse_handle "$3" || deny_token
    check_git_read_guards || deny_token
    acquire_lock >/dev/null 2>&1 || deny_token
    validate_target_shape && validate_file "$TARGET" "$HANDLE_TOKEN" || deny_token
    echo "token_match=true"
    ;;

  occupancy)
    [ "$#" -eq 2 ] || usage
    init_root "$2" >/dev/null 2>&1 || deny_occupancy
    guard_stream >/dev/null 2>&1 || deny_occupancy
    check_git_read_guards || deny_occupancy
    acquire_lock >/dev/null 2>&1 || deny_occupancy
    validate_target_shape && validate_file "$TARGET" || deny_occupancy
    fingerprint="$(fingerprint_file "$TARGET")" || deny_occupancy
    valid_fingerprint "$fingerprint" || deny_occupancy
    echo "checkpoint_occupancy=valid"
    echo "checkpoint_fingerprint=$fingerprint"
    ;;

  save)
    [ "$#" -eq 3 ] || usage
    init_root "$2" || fail "invalid project root"
    expected="$3"
    [ "$expected" = new ] || valid_token "$expected" || usage
    guard_stream || fail "workstream owns this checkout"
    acquire_lock || exit 1
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    [ ! -e "$TEMP" ] && [ ! -L "$TEMP" ] || fail "checkpoint temporary path already exists"
    target_fingerprint=""
    if [ "$expected" = new ]; then
      [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ] || fail "root checkpoint already exists"
    else
      validate_target_shape && validate_file "$TARGET" "$expected" || fail "checkpoint ownership mismatch"
      target_fingerprint="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
      valid_fingerprint "$target_fingerprint" || fail "cannot fingerprint checkpoint"
    fi
    umask 077
    TEMP_OWNED=true
    cat > "$TEMP"
    [ -f "$TEMP" ] && [ ! -L "$TEMP" ] || fail "invalid checkpoint temporary file"
    if [ "$expected" = new ]; then validate_file "$TEMP" || fail "invalid checkpoint document"
    else validate_file "$TEMP" "$expected" || fail "invalid checkpoint document"; fi
    token="$STORED_TOKEN"
    if [ "$expected" = new ]; then
      ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
      ln "$TEMP" "$TARGET" 2>/dev/null || fail "root checkpoint appeared during save"
      rm -f -- "$TEMP"; TEMP_OWNED=false
    else
      ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
      validate_target_shape && validate_file "$TARGET" "$expected" || fail "checkpoint ownership mismatch"
      current="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
      [ "$current" = "$target_fingerprint" ] || fail "checkpoint changed during save"
      mv -f -- "$TEMP" "$TARGET"; TEMP_OWNED=false
    fi
    echo "checkpoint_path=$TARGET"
    echo "checkpoint_token=$token"
    echo "CHECKPOINT — file: $TARGET — token: $token"
    ;;

  overwrite)
    [ "$#" -eq 3 ] || usage
    init_root "$2" || fail "invalid project root"
    fingerprint="$3"; valid_fingerprint "$fingerprint" || usage
    guard_stream || fail "workstream owns this checkout"
    acquire_lock || exit 1
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    [ ! -e "$TEMP" ] && [ ! -L "$TEMP" ] || fail "checkpoint temporary path already exists"
    validate_target_shape && validate_file "$TARGET" || fail "invalid checkpoint occupancy"
    incumbent_token="$STORED_TOKEN"
    current="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
    [ "$current" = "$fingerprint" ] || fail "checkpoint changed after occupancy probe"
    umask 077
    TEMP_OWNED=true
    cat > "$TEMP"
    [ -f "$TEMP" ] && [ ! -L "$TEMP" ] || fail "invalid checkpoint temporary file"
    validate_file "$TEMP" || fail "invalid checkpoint document"
    token="$STORED_TOKEN"
    [ "$token" != "$incumbent_token" ] || fail "replacement checkpoint must use a fresh token"
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    validate_target_shape && validate_file "$TARGET" "$incumbent_token" || fail "invalid checkpoint occupancy"
    current="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
    [ "$current" = "$fingerprint" ] || fail "checkpoint changed during overwrite"
    mv -f -- "$TEMP" "$TARGET"; TEMP_OWNED=false
    echo "checkpoint_path=$TARGET"
    echo "checkpoint_token=$token"
    echo "CHECKPOINT — file: $TARGET — token: $token"
    ;;

  claim)
    [ "$#" -eq 4 ] || usage
    init_root "$2" || fail "invalid project root"
    expected="$3"; fingerprint="$4"
    valid_token "$expected" && valid_fingerprint "$fingerprint" || usage
    guard_stream || fail "workstream owns this checkout"
    acquire_lock || exit 1
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    [ ! -e "$TEMP" ] && [ ! -L "$TEMP" ] || fail "checkpoint temporary path already exists"
    validate_target_shape && validate_file "$TARGET" "$expected" || fail "checkpoint ownership mismatch"
    current="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
    [ "$current" = "$fingerprint" ] || fail "checkpoint changed after Resume read"
    new="$(new_token)"; while [ "$new" = "$expected" ]; do new="$(new_token)"; done
    umask 077; TEMP_OWNED=true
    {
      IFS= read -r first_line || fail "invalid claimed checkpoint"
      IFS= read -r || fail "invalid claimed checkpoint"
      printf '%s\n' "$first_line"
      printf 'checkpoint-token: %s\n' "$new"
      cat
    } < "$TARGET" > "$TEMP"
    validate_file "$TEMP" "$new" || fail "invalid claimed checkpoint"
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    validate_target_shape && validate_file "$TARGET" "$expected" || fail "checkpoint ownership mismatch"
    current="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
    [ "$current" = "$fingerprint" ] || fail "checkpoint changed after Resume read"
    mv -f -- "$TEMP" "$TARGET"; TEMP_OWNED=false
    echo "checkpoint_path=$TARGET"
    echo "checkpoint_token=$new"
    echo "CHECKPOINT — file: $TARGET — token: $new"
    ;;

  delete)
    [ "$#" -eq 3 ] || usage
    init_root "$2" || fail "invalid project root"
    expected="$3"; valid_token "$expected" || usage
    guard_stream || fail "workstream owns this checkout"
    acquire_lock || exit 1
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    validate_target_shape && validate_file "$TARGET" "$expected" || fail "checkpoint ownership mismatch"
    fingerprint="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
    ensure_git_mutation_guards || fail "checkpoint paths must be untracked and ignored"
    validate_target_shape && validate_file "$TARGET" "$expected" || fail "checkpoint ownership mismatch"
    current="$(fingerprint_file "$TARGET")" || fail "cannot fingerprint checkpoint"
    [ "$current" = "$fingerprint" ] || fail "checkpoint changed during delete"
    rm -f -- "$TARGET"
    echo "checkpoint_deleted=$TARGET"
    ;;

  *) usage ;;
esac
