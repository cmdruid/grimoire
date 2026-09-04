# shellcheck shell=bash
# gcloud-session-lib.sh — sourced by gcloud-session.sh. Not an entrypoint.
# Facts and local session mechanics only. Never eval. Never persist secrets.

GCLOUD_SESSION_MAGIC='gcloud-operator-session-1'
GCLOUD_SESSION_DEFAULT_PERSIST=720
GCLOUD_SESSION_MIN_PERSIST=60
GCLOUD_SESSION_MAX_PERSIST=3600
GCLOUD_SESSION_PREFIX='gcloud-operator-sess.'
MFA_CODE_MAX_BYTES=128

die() {
  echo "gcloud-session: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage:
  gcloud-session.sh doctor --project PROJECT --zone ZONE --vm VM
      [--impersonate-service-account SA]
  gcloud-session.sh open   --project PROJECT --zone ZONE --vm VM
      --mfa-method security-code|authenticator
      [--mfa-code-file PATH] [--control-persist SECONDS] [--tmux]
  gcloud-session.sh run        -- HANDLE [--] COMMAND [ARG...]
  gcloud-session.sh copy-to    -- HANDLE LOCAL_PATH REMOTE_PATH [--overwrite]
  gcloud-session.sh copy-from  -- HANDLE REMOTE_PATH LOCAL_PATH [--overwrite]
  gcloud-session.sh status     -- HANDLE
  gcloud-session.sh close      -- HANDLE
  gcloud-session.sh troubleshoot --project PROJECT --zone ZONE --vm VM
      --authorize-mutations

One stable entrypoint for IAP/OS Login operator sessions. See SKILL.md.
EOF
  exit 2
}

now_epoch() {
  if [ -n "${GCLOUD_SESSION_NOW:-}" ]; then
    printf '%s\n' "$GCLOUD_SESSION_NOW"
  else
    date +%s
  fi
}

tool_gcloud() { printf '%s\n' "${GCLOUD_SESSION_GCLOUD:-gcloud}"; }
tool_ssh() { printf '%s\n' "${GCLOUD_SESSION_SSH:-ssh}"; }
tool_scp() { printf '%s\n' "${GCLOUD_SESSION_SCP:-scp}"; }
tool_python() { printf '%s\n' "${GCLOUD_SESSION_PYTHON:-python3}"; }

session_tmpdir() {
  printf '%s\n' "${GCLOUD_SESSION_TMPDIR:-${TMPDIR:-/tmp}}"
}

current_uid() {
  if [ -n "${GCLOUD_SESSION_UID:-}" ]; then
    printf '%s\n' "$GCLOUD_SESSION_UID"
  else
    id -u
  fi
}

# POSIX single-quote. Safe for remote sh -c exec.
posix_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

quote_remote_argv() {
  local out="" a
  for a in "$@"; do
    if [ -n "$out" ]; then
      out="$out $(posix_quote "$a")"
    else
      out="$(posix_quote "$a")"
    fi
  done
  printf '%s\n' "$out"
}

require_ident() {
  local name="$1" value="$2"
  [ -n "$value" ] || die "missing --$name"
  case "$value" in
    *[!a-zA-Z0-9._-]*) die "invalid --$name: refused metacharacters" ;;
    .*|*..*) die "invalid --$name: refused glob or relative form" ;;
  esac
}

valid_vm_name() {
  case "$1" in
    [a-z][a-z0-9-]*[a-z0-9]|[a-z]) return 0 ;;
    *) return 1 ;;
  esac
}

require_vm() {
  require_ident vm "$1"
  valid_vm_name "$1" || die "invalid --vm: must be a Compute Engine instance name"
}

require_method() {
  case "$1" in
    security-code|authenticator) return 0 ;;
    *) die "--mfa-method must be security-code or authenticator (never inferred from digit count)" ;;
  esac
}

require_persist() {
  local n="$1"
  case "$n" in *[!0-9]*|'') die "--control-persist must be an integer" ;; esac
  [ "$n" -ge "$GCLOUD_SESSION_MIN_PERSIST" ] && [ "$n" -le "$GCLOUD_SESSION_MAX_PERSIST" ] \
    || die "--control-persist must be ${GCLOUD_SESSION_MIN_PERSIST}-${GCLOUD_SESSION_MAX_PERSIST} seconds"
}

classify_gcloud_error() {
  local err="$1"
  case "$err" in
    *'Operation not permitted'*|*'Read-only file system'*|*'Permission denied'*'.config/gcloud'*|*'sandbox'*)
      printf '%s\n' sandbox_denied ;;
    *'Reauthentication required'*|*'invalid_grant'*|*'problem refreshing'*|*'Not authenticated'*|*'no active account'*)
      printf '%s\n' auth_expired ;;
    *'PERMISSION_DENIED'*|*'Access denied'*|*'IAM permission'*)
      printf '%s\n' iam_missing ;;
    *'Failed to authenticate with Google 2FA'*|*'oslogin'*2fa*|*'keyboard-interactive'*)
      printf '%s\n' oslogin_2fa ;;
    *'IAP'*|*'iap tunnel'*|*'start-iap-tunnel'*|*'Error while connecting [403]'*)
      printf '%s\n' iap_failure ;;
    *'Permission denied (publickey'*|*'Connection refused'*|*'sshd'*)
      printf '%s\n' guest_ssh ;;
    *'Address already in use'*|*'port is already allocated'*)
      printf '%s\n' port_occupied ;;
    *)
      printf '%s\n' unknown ;;
  esac
}

# Redact secrets from a text blob on stdout. Never a substitute for not writing them.
redact_text() {
  local py
  py="$(tool_python)"
  "$py" -c '
import re, sys
s = sys.stdin.read()
s = re.sub(r"ya29\\.[A-Za-z0-9._\\-]+", "ya29.[REDACTED]", s)
s = re.sub(r"(?im)^(Authorization:).*", r"\\1 [REDACTED]", s)
s = re.sub(r"(?i)(--mfa-code(=|\\s+)\\S+)", "--mfa-code [REDACTED]", s)
s = re.sub(r"(?i)(-i\\s+)\\S+", r"\\1[KEYPATH]", s)
sys.stdout.write(s)
'
}

gcloud_run() {
  local out_file="$1" err_file="$2"
  shift 2
  local gc
  gc="$(tool_gcloud)"
  if [ -n "${GCLOUD_SESSION_IMPERSONATE:-}" ]; then
    set -- --impersonate-service-account "$GCLOUD_SESSION_IMPERSONATE" "$@"
  fi
  # Never copy the credential store. Never pass --troubleshoot here.
  if "$gc" "$@" >"$out_file" 2>"$err_file"; then
    return 0
  fi
  return 1
}

state_get() {
  local file="$1" key="$2"
  # shellcheck disable=SC2162
  while IFS='=' read k v; do
    [ "$k" = "$key" ] && { printf '%s\n' "$v"; return 0; }
  done <"$file"
  return 1
}

state_write() {
  local file="$1"
  shift
  : >"$file"
  chmod 600 "$file"
  local kv
  for kv in "$@"; do
    printf '%s\n' "$kv" >>"$file"
  done
}

session_state_path() {
  printf '%s/state\n' "$1"
}

session_control_path() {
  printf '%s/control.sock\n' "$1"
}

session_log_path() {
  printf '%s/debug.log\n' "$1"
}

is_session_dir() {
  local dir="$1" st magic uid mode owner
  case "$dir" in
    /*) ;;
    *) return 1 ;;
  esac
  [ -d "$dir" ] || return 1
  st="$(session_state_path "$dir")"
  [ -f "$st" ] || return 1
  magic="$(state_get "$st" magic || true)"
  [ "$magic" = "$GCLOUD_SESSION_MAGIC" ] || return 1
  uid="$(current_uid)"
  owner="$(state_get "$st" uid || true)"
  [ "$owner" = "$uid" ] || return 1
  mode="$(stat -f '%Lp' "$dir" 2>/dev/null || stat -c '%a' "$dir")"
  case "$mode" in
    700|0700) ;;
    *) return 1 ;;
  esac
  owner="$(stat -f '%u' "$dir" 2>/dev/null || stat -c '%u' "$dir")"
  [ "$owner" = "$uid" ] || return 1
  return 0
}

require_handle() {
  local handle="$1"
  [ -n "$handle" ] || die "missing session handle"
  case "$handle" in
    /tmp|/var/tmp|"$HOME"|/|"$PWD") die "refusing to operate on a broad path: $handle" ;;
    *'*'*|*?' '*|*'..'*) die "refusing unsafe handle" ;;
  esac
  case "$(basename "$handle")" in
    ${GCLOUD_SESSION_PREFIX}*) ;;
    *) die "handle is not a gcloud-operator session directory" ;;
  esac
  is_session_dir "$handle" || die "invalid or foreign session handle"
}

append_log() {
  local dir="$1" text="$2" log
  log="$(session_log_path "$dir")"
  printf '%s\n' "$text" | redact_text >>"$log" 2>/dev/null || true
  chmod 600 "$log" 2>/dev/null || true
}

unlink_mfa_code_file() {
  if [ -n "${MFA_CODE_FILE:-}" ]; then
    rm -f "$MFA_CODE_FILE"
  fi
}

require_mfa_code_file() {
  local f="$1" owner mode_str bytes extra nl
  [ -n "$f" ] || die "mfa code file missing"
  [ -e "$f" ] || die "mfa code file missing"
  if [ -L "$f" ]; then
    die "mfa code file must be a regular file, not a symlink"
  fi
  [ -f "$f" ] || die "mfa code file must be a regular file"
  owner="$(stat -f '%u' "$f" 2>/dev/null || stat -c '%u' "$f")"
  [ "$owner" = "$(current_uid)" ] || die "mfa code file must be owned by the current user"
  mode_str="$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f")"
  case "$mode_str" in
    *[!0-9]*|'') die "mfa code file mode unreadable" ;;
  esac
  if [ $((8#$mode_str & 077)) -ne 0 ]; then
    die "mfa code file must have no group or other access"
  fi
  if [ $((8#$mode_str & 0400)) -eq 0 ]; then
    die "mfa code file must be readable by its owner"
  fi
  bytes="$(wc -c <"$f" | tr -d ' ')"
  [ "$bytes" -ge 1 ] || die "mfa code file empty"
  [ "$bytes" -le "$MFA_CODE_MAX_BYTES" ] || die "mfa code file too large"
  extra="$(tr -d '\n' <"$f" | wc -c | tr -d ' ')"
  nl=$((bytes - extra))
  [ "$nl" -le 1 ] || die "mfa code file must contain exactly one line"
  [ "$extra" -ge 1 ] || die "mfa code file empty"
}

consume_code_file() {
  local f="$1"
  [ -e "$f" ] || return 0
  : >"$f"
  rm -f "$f"
}

forbidden_flag() {
  local a
  for a in "$@"; do
    case "$a" in
      --troubleshoot|troubleshoot)
        die "refusing --troubleshoot on this command; see troubleshoot --authorize-mutations" ;;
    esac
  done
}

# Assignments are read by gcloud-session.sh after sourcing this file.
# shellcheck disable=SC2034
parse_target_flags() {
  PROJECT=""
  ZONE=""
  VM=""
  IMPERSONATE=""
  MFA_METHOD=""
  MFA_CODE_FILE=""
  CONTROL_PERSIST="$GCLOUD_SESSION_DEFAULT_PERSIST"
  WANT_TMUX=0
  AUTHORIZE_MUTATIONS=0
  OVERWRITE=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --project) PROJECT="${2:-}"; shift 2 ;;
      --zone) ZONE="${2:-}"; shift 2 ;;
      --vm) VM="${2:-}"; shift 2 ;;
      --impersonate-service-account) IMPERSONATE="${2:-}"; shift 2 ;;
      --mfa-method) MFA_METHOD="${2:-}"; shift 2 ;;
      --mfa-code-file) MFA_CODE_FILE="${2:-}"; shift 2 ;;
      --control-persist) CONTROL_PERSIST="${2:-}"; shift 2 ;;
      --tmux) WANT_TMUX=1; shift ;;
      --authorize-mutations) AUTHORIZE_MUTATIONS=1; shift ;;
      --overwrite) OVERWRITE=1; shift ;;
      --help|-h) usage ;;
      --) shift; return 0 ;;
      --troubleshoot) forbidden_flag "$1" ;;
      -*) die "unknown flag: $1" ;;
      *) die "unexpected argument: $1" ;;
    esac
  done
}

require_target() {
  require_ident project "$PROJECT"
  require_ident zone "$ZONE"
  require_vm "$VM"
}

identity_line() {
  printf '%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}
