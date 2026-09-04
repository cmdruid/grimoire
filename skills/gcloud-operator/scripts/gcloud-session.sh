#!/usr/bin/env bash
# gcloud-session.sh — ephemeral IAP/OS Login operator session.
# One stable entrypoint so a prefix-matching approval policy can permit it.
# Local transport only. Does not authorize GCP or guest mutations.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=gcloud-session-lib.sh
. "$HERE/gcloud-session-lib.sh"

MFA_HELPER="${GCLOUD_SESSION_MFA:-$HERE/gcloud-session-mfa.py}"

ssh_check() {
  local sock="$1"
  "$(tool_ssh)" -o ControlPath="$sock" -o ControlMaster=no -O check dummy 2>/dev/null
}

ssh_exit_master() {
  local sock="$1"
  "$(tool_ssh)" -o ControlPath="$sock" -o ControlMaster=no -O exit dummy 2>/dev/null || true
}

collect_account() {
  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  if ! gcloud_run "$out" "$err" auth list --filter=status:ACTIVE --format='value(account)'; then
    rm -f "$out" "$err"
    return 1
  fi
  tr -d '\r' <"$out" | head -n 1
  rm -f "$out" "$err"
}

collect_instance() {
  local out err parsed py
  out="$(mktemp)"
  err="$(mktemp)"
  parsed="$(mktemp)"
  if ! gcloud_run "$out" "$err" compute instances describe "$VM" \
      --project="$PROJECT" --zone="$ZONE" --format=json; then
    CLASS="$(classify_gcloud_error "$(cat "$err")")"
    rm -f "$out" "$err" "$parsed"
    return 1
  fi
  py="$(tool_python)"
  "$py" -c '
import json,sys
d=json.load(open(sys.argv[1]))
nics=d.get("networkInterfaces") or []
nat=""; net=""; ip=""
if nics:
    net=nics[0].get("network") or ""
    ip=nics[0].get("networkIP") or ""
    acs=nics[0].get("accessConfigs") or []
    if acs:
        nat=acs[0].get("natIP") or ""
md={i.get("key"): i.get("value") for i in (d.get("metadata") or {}).get("items") or []}
sas=d.get("serviceAccounts") or []
sa=sas[0].get("email") if sas else ""
def emit(k,v):
    v=(v or "").replace("\n"," ").replace("\r","")
    sys.stdout.write("%s=%s\n" % (k, v))
emit("INSTANCE_ID", str(d.get("id") or ""))
emit("INSTANCE_STATUS", d.get("status") or "")
emit("INSTANCE_NAME", d.get("name") or "")
emit("EXTERNAL_IP", nat)
emit("INTERNAL_IP", ip)
emit("NETWORK", net)
emit("OSLOGIN_INSTANCE", md.get("enable-oslogin") or "")
emit("OSLOGIN_2FA_INSTANCE", md.get("enable-oslogin-2fa") or "")
emit("ATTACHED_SA", sa)
' "$out" >"$parsed"
  INSTANCE_ID="$(state_get "$parsed" INSTANCE_ID || true)"
  INSTANCE_STATUS="$(state_get "$parsed" INSTANCE_STATUS || true)"
  EXTERNAL_IP="$(state_get "$parsed" EXTERNAL_IP || true)"
  INTERNAL_IP="$(state_get "$parsed" INTERNAL_IP || true)"
  NETWORK="$(state_get "$parsed" NETWORK || true)"
  OSLOGIN_INSTANCE="$(state_get "$parsed" OSLOGIN_INSTANCE || true)"
  OSLOGIN_2FA_INSTANCE="$(state_get "$parsed" OSLOGIN_2FA_INSTANCE || true)"
  ATTACHED_SA="$(state_get "$parsed" ATTACHED_SA || true)"
  rm -f "$out" "$err" "$parsed"
}

collect_project_metadata() {
  local out err parsed py
  out="$(mktemp)"
  err="$(mktemp)"
  parsed="$(mktemp)"
  OSLOGIN_PROJECT=""
  OSLOGIN_2FA_PROJECT=""
  if ! gcloud_run "$out" "$err" compute project-info describe --project="$PROJECT" --format=json; then
    rm -f "$out" "$err" "$parsed"
    return 1
  fi
  py="$(tool_python)"
  "$py" -c '
import json,sys
d=json.load(open(sys.argv[1]))
md={i.get("key"): i.get("value") for i in (d.get("commonInstanceMetadata") or {}).get("items") or []}
def emit(k,v):
    v=(v or "").replace("\n"," ").replace("\r","")
    sys.stdout.write("%s=%s\n" % (k, v))
emit("OSLOGIN_PROJECT", md.get("enable-oslogin") or "")
emit("OSLOGIN_2FA_PROJECT", md.get("enable-oslogin-2fa") or "")
' "$out" >"$parsed"
  OSLOGIN_PROJECT="$(state_get "$parsed" OSLOGIN_PROJECT || true)"
  OSLOGIN_2FA_PROJECT="$(state_get "$parsed" OSLOGIN_2FA_PROJECT || true)"
  rm -f "$out" "$err" "$parsed"
}

meta_true() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    TRUE|YES|1) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_oslogin_effective() {
  if [ -n "${OSLOGIN_INSTANCE:-}" ]; then
    OSLOGIN="$OSLOGIN_INSTANCE"
    OSLOGIN_SOURCE="instance"
  elif [ -n "${OSLOGIN_PROJECT:-}" ]; then
    OSLOGIN="$OSLOGIN_PROJECT"
    OSLOGIN_SOURCE="project"
  else
    OSLOGIN=""
    OSLOGIN_SOURCE="unset"
  fi
  if [ -n "${OSLOGIN_2FA_INSTANCE:-}" ]; then
    OSLOGIN_2FA="$OSLOGIN_2FA_INSTANCE"
    OSLOGIN_2FA_SOURCE="instance"
  elif [ -n "${OSLOGIN_2FA_PROJECT:-}" ]; then
    OSLOGIN_2FA="$OSLOGIN_2FA_PROJECT"
    OSLOGIN_2FA_SOURCE="project"
  else
    OSLOGIN_2FA=""
    OSLOGIN_2FA_SOURCE="unset"
  fi
}

require_effective_oslogin_2fa() {
  if meta_true "${OSLOGIN:-}" && meta_true "${OSLOGIN_2FA:-}"; then
    return 0
  fi
  die "effective OS Login 2FA is not enabled (oslogin=${OSLOGIN:-} source=${OSLOGIN_SOURCE:-unset}; oslogin_2fa=${OSLOGIN_2FA:-} source=${OSLOGIN_2FA_SOURCE:-unset})"
}

oslogin_user() {
  local out err user
  out="$(mktemp)"
  err="$(mktemp)"
  if gcloud_run "$out" "$err" compute os-login describe-profile --format='value(posixAccounts[0].username)'; then
    user="$(tr -d '\r' <"$out" | head -n 1)"
    rm -f "$out" "$err"
    printf '%s\n' "$user"
    return 0
  fi
  rm -f "$out" "$err"
  printf '\n'
}

print_identity_banner() {
  cat <<EOF
account=${ACCOUNT:-}
project=$PROJECT
zone=$ZONE
vm=$VM
instance_id=${INSTANCE_ID:-}
instance_status=${INSTANCE_STATUS:-}
internal_ip=${INTERNAL_IP:-}
external_ip=${EXTERNAL_IP:-none}
network=${NETWORK:-}
oslogin=${OSLOGIN:-}
oslogin_source=${OSLOGIN_SOURCE:-unset}
oslogin_2fa=${OSLOGIN_2FA:-}
oslogin_2fa_source=${OSLOGIN_2FA_SOURCE:-unset}
oslogin_user=${OSLOGIN_USER:-}
attached_sa=${ATTACHED_SA:-}
planned_network_path=iap-tcp
transport=${TRANSPORT_STATUS:-unverified}
EOF
}

cmd_doctor() {
  parse_target_flags "$@"
  forbidden_flag "$@"
  require_target
  if [ -n "$IMPERSONATE" ]; then
    export GCLOUD_SESSION_IMPERSONATE="$IMPERSONATE"
  fi

  local gc py class="ok" sandbox="false"
  gc="$(tool_gcloud)"
  py="$(tool_python)"
  command -v "$gc" >/dev/null 2>&1 || die "gcloud not found on PATH"
  command -v "$py" >/dev/null 2>&1 || die "python3 is required to parse gcloud --dry-run and JSON"
  command -v "$(tool_ssh)" >/dev/null 2>&1 || die "ssh not found on PATH"

  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  if ! gcloud_run "$out" "$err" info --format='value(config.paths.global_config_dir)'; then
    class="$(classify_gcloud_error "$(cat "$err")")"
    if [ "$class" = sandbox_denied ]; then
      sandbox="true"
    fi
  fi
  CONFIG_DIR="$(tr -d '\r' <"$out" | head -n 1 || true)"
  rm -f "$out" "$err"
  if [ -n "$CONFIG_DIR" ] && [ -d "$CONFIG_DIR" ] && [ ! -w "$CONFIG_DIR" ]; then
    sandbox="true"
  fi

  ACCOUNT="$(collect_account || true)"
  if [ -z "$ACCOUNT" ] && [ "$class" = ok ]; then
    class="auth_expired"
  fi

  INSTANCE_ID=""
  INSTANCE_STATUS=""
  EXTERNAL_IP=""
  INTERNAL_IP=""
  NETWORK=""
  OSLOGIN=""
  OSLOGIN_2FA=""
  OSLOGIN_SOURCE="unset"
  OSLOGIN_2FA_SOURCE="unset"
  OSLOGIN_INSTANCE=""
  OSLOGIN_2FA_INSTANCE=""
  OSLOGIN_PROJECT=""
  OSLOGIN_2FA_PROJECT=""
  ATTACHED_SA=""
  OSLOGIN_USER=""
  TRANSPORT_STATUS="unverified"
  if [ "$class" = ok ] || [ "$class" = auth_expired ]; then
    if collect_instance; then
      collect_project_metadata || true
      resolve_oslogin_effective
      OSLOGIN_USER="$(oslogin_user)"
    else
      [ "$class" = ok ] && class="${CLASS:-unknown}"
    fi
  fi

  if [ -n "${EXTERNAL_IP:-}" ]; then
    echo "warning=vm has an external IP; this helper still uses IAP and will not open public TCP 22" >&2
  fi

  echo "ok=$([ "$class" = ok ] && echo true || echo false)"
  echo "class=$class"
  echo "sandbox=$sandbox"
  echo "config_dir=${CONFIG_DIR:-}"
  print_identity_banner
  echo "impersonate=${IMPERSONATE:-}"
  echo "troubleshoot=refused-by-default"
  if [ "$sandbox" = true ] || [ "$class" = sandbox_denied ]; then
    echo "remediation=escalate this helper as one prefix; do not copy ~/.config/gcloud"
  fi
  [ "$class" = ok ]
}

preflight_or_die() {
  local facts
  facts="$(cmd_doctor "$@" || true)"
  printf '%s\n' "$facts"
  echo "$facts" | grep -q '^ok=true$' || die "preflight failed; refuse to prompt for MFA"
  ACCOUNT="$(printf '%s\n' "$facts" | sed -n 's/^account=//p' | head -n 1)"
  INSTANCE_ID="$(printf '%s\n' "$facts" | sed -n 's/^instance_id=//p' | head -n 1)"
  INSTANCE_STATUS="$(printf '%s\n' "$facts" | sed -n 's/^instance_status=//p' | head -n 1)"
  EXTERNAL_IP="$(printf '%s\n' "$facts" | sed -n 's/^external_ip=//p' | head -n 1)"
  INTERNAL_IP="$(printf '%s\n' "$facts" | sed -n 's/^internal_ip=//p' | head -n 1)"
  NETWORK="$(printf '%s\n' "$facts" | sed -n 's/^network=//p' | head -n 1)"
  OSLOGIN="$(printf '%s\n' "$facts" | sed -n 's/^oslogin=//p' | head -n 1)"
  OSLOGIN_SOURCE="$(printf '%s\n' "$facts" | sed -n 's/^oslogin_source=//p' | head -n 1)"
  OSLOGIN_2FA="$(printf '%s\n' "$facts" | sed -n 's/^oslogin_2fa=//p' | head -n 1)"
  OSLOGIN_2FA_SOURCE="$(printf '%s\n' "$facts" | sed -n 's/^oslogin_2fa_source=//p' | head -n 1)"
  OSLOGIN_USER="$(printf '%s\n' "$facts" | sed -n 's/^oslogin_user=//p' | head -n 1)"
  ATTACHED_SA="$(printf '%s\n' "$facts" | sed -n 's/^attached_sa=//p' | head -n 1)"
  require_effective_oslogin_2fa
}

build_master_argv() {
  local dry="$1" sock="$2" persist="$3"
  local py
  py="$(tool_python)"
  printf '%s' "$dry" | "$py" -c '
import shlex, sys
raw = sys.stdin.read()
lines = [ln.strip() for ln in raw.splitlines() if ln.strip()]
if not lines:
    sys.exit(3)
cmd = lines[-1]
for ln in reversed(lines):
    first = ln.split()[0] if ln.split() else ""
    if first.endswith("ssh") or first.endswith("/ssh") or first == "ssh":
        cmd = ln
        break
args = shlex.split(cmd)
if not args:
    sys.exit(3)
skip_next = False
out = []
i = 0
# Replace argv0 with the configured ssh tool.
out.append(sys.argv[1])
i = 1
while i < len(args):
    a = args[i]
    if a in ("-t", "-T", "-f", "-N"):
        i += 1
        continue
    if a == "-o" and i + 1 < len(args):
        key = args[i+1].split("=",1)[0]
        if key in ("ControlMaster","ControlPath","ControlPersist","ServerAliveInterval","ServerAliveCountMax","ExitOnForwardFailure","BatchMode"):
            i += 2
            continue
        out.extend([a, args[i+1]])
        i += 2
        continue
    if a.startswith("-o") and "=" in a:
        key = a[2:].split("=",1)[0]
        if key in ("ControlMaster","ControlPath","ControlPersist","ServerAliveInterval","ServerAliveCountMax","ExitOnForwardFailure","BatchMode"):
            i += 1
            continue
    out.append(a)
    i += 1
extra = [
    "-o","ControlMaster=yes",
    "-o","ControlPath="+sys.argv[2],
    "-o","ControlPersist="+sys.argv[3],
    "-o","ServerAliveInterval=30",
    "-o","ServerAliveCountMax=3",
    "-o","ExitOnForwardFailure=yes",
    "-o","BatchMode=no",
    "-f","-N",
]
# Insert extra before destination (last arg).
dest = out[-1]
body = out[:-1] + extra + [dest]
for a in body:
    sys.stdout.write(a + "\0")
' "$(tool_ssh)" "$sock" "$persist"
}

read_nul_args() {
  SSH_ARGV=()
  while IFS= read -r -d '' a; do
    SSH_ARGV+=("$a")
  done
}

cmd_open() {
  parse_target_flags "$@"
  forbidden_flag "$@"
  require_target
  [ -z "$IMPERSONATE" ] || die "refusing --impersonate-service-account on open: impersonation is control-plane only and must not bypass OS Login 2FA"
  require_method "$MFA_METHOD"
  require_persist "$CONTROL_PERSIST"
  # parse_target_flags mutates globals; snapshot before doctor re-parses.
  local saved_project="$PROJECT" saved_zone="$ZONE" saved_vm="$VM"
  local saved_method="$MFA_METHOD" saved_code="$MFA_CODE_FILE"
  local saved_persist="$CONTROL_PERSIST" saved_tmux="$WANT_TMUX"

  PROJECT="$saved_project"
  ZONE="$saved_zone"
  VM="$saved_vm"
  MFA_METHOD="$saved_method"
  MFA_CODE_FILE="$saved_code"
  CONTROL_PERSIST="$saved_persist"
  WANT_TMUX="$saved_tmux"

  if [ "${GCLOUD_SESSION_SKIP_MFA:-}" != 1 ]; then
    if [ -z "$MFA_CODE_FILE" ]; then
      if [ -t 0 ]; then
        echo "gcloud-session: enter a fresh $MFA_METHOD code (input hidden). It is not echoed, stored, or logged." >&2
        # Harness secret-input is preferred; a TTY read -s is hidden from the screen, not from process observers.
        MFA_CODE_FILE="$(mktemp "$(session_tmpdir)/gcloud-operator-code.XXXXXX")"
        chmod 600 "$MFA_CODE_FILE"
        # shellcheck disable=SC2162
        read -r -s code
        printf '%s' "$code" >"$MFA_CODE_FILE"
        unset code
        echo >&2
      else
        die "interactive MFA required: pass --mfa-code-file PATH after collecting a fresh $MFA_METHOD code. Ordinary PTY writes are not secret."
      fi
    fi
    require_mfa_code_file "$MFA_CODE_FILE"
    trap unlink_mfa_code_file EXIT
  elif [ -n "$MFA_CODE_FILE" ]; then
    trap unlink_mfa_code_file EXIT
  fi
  saved_code="$MFA_CODE_FILE"

  preflight_or_die --project "$saved_project" --zone "$saved_zone" --vm "$saved_vm"
  PROJECT="$saved_project"
  ZONE="$saved_zone"
  VM="$saved_vm"
  MFA_METHOD="$saved_method"
  MFA_CODE_FILE="$saved_code"
  CONTROL_PERSIST="$saved_persist"
  WANT_TMUX="$saved_tmux"

  local parent sess sock persist created expires identity dest
  parent="$(session_tmpdir)"
  mkdir -p "$parent"
  sess="$(mktemp -d "$parent/${GCLOUD_SESSION_PREFIX}XXXXXX")"
  chmod 700 "$sess"
  sock="$(session_control_path "$sess")"
  persist="$CONTROL_PERSIST"
  created="$(now_epoch)"
  expires=$((created + persist))
  : >"$(session_log_path "$sess")"
  chmod 600 "$(session_log_path "$sess")"

  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  if ! gcloud_run "$out" "$err" compute ssh "$VM" \
      --project="$PROJECT" --zone="$ZONE" \
      --tunnel-through-iap --dry-run --quiet; then
    local cls
    cls="$(classify_gcloud_error "$(cat "$err")")"
    append_log "$sess" "dry-run failed class=$cls"
    append_log "$sess" "$(redact_text <"$err")"
    rm -rf "$sess" "$out" "$err"
    unlink_mfa_code_file
    die "gcloud compute ssh --dry-run failed ($cls)"
  fi
  local dry
  dry="$(cat "$out")"
  append_log "$sess" "dry-run captured"
  rm -f "$out" "$err"

  read_nul_args < <(build_master_argv "$dry" "$sock" "$persist")
  if [ "${#SSH_ARGV[@]}" -lt 2 ]; then
    rm -rf "$sess"
    unlink_mfa_code_file
    die "failed to parse gcloud --dry-run ssh argv"
  fi
  dest="${SSH_ARGV[${#SSH_ARGV[@]}-1]}"

  identity="$(identity_line "$ACCOUNT" "$PROJECT" "$ZONE" "$VM" "$INSTANCE_ID" "$OSLOGIN_USER")"
  state_write "$(session_state_path "$sess")" \
    "magic=$GCLOUD_SESSION_MAGIC" \
    "handle=$sess" \
    "project=$PROJECT" \
    "zone=$ZONE" \
    "vm=$VM" \
    "instance_id=$INSTANCE_ID" \
    "account=$ACCOUNT" \
    "ssh_destination=$dest" \
    "control_path=$sock" \
    "control_persist=$persist" \
    "created_at=$created" \
    "expires_at=$expires" \
    "mfa_method=$MFA_METHOD" \
    "oslogin_user=$OSLOGIN_USER" \
    "identity=$identity" \
    "uid=$(current_uid)" \
    "tmux=$WANT_TMUX"

  if [ "${GCLOUD_SESSION_SKIP_MFA:-}" = 1 ]; then
    unlink_mfa_code_file
    if ! "${SSH_ARGV[@]}"; then
      rm -rf "$sess"
      die "failed to start SSH master"
    fi
  else
    local py mfa_rc=0
    py="$(tool_python)"
    "$py" "$MFA_HELPER" \
        --method "$MFA_METHOD" \
        --code-file "$MFA_CODE_FILE" \
        --timeout "${GCLOUD_SESSION_MFA_TIMEOUT:-90}" \
        --log "$(session_log_path "$sess")" \
        -- "${SSH_ARGV[@]}" || mfa_rc=$?
    unlink_mfa_code_file
    if [ "$mfa_rc" -ne 0 ]; then
      case "$mfa_rc" in
        10) rm -rf "$sess"; die "MFA prompt expired before a code could be submitted; request a fresh code" ;;
        11) rm -rf "$sess"; die "MFA method was rejected; choose security-code or authenticator explicitly and request a fresh code" ;;
        12) rm -rf "$sess"; die "authentication outcome is ambiguous after a broken connection; request a fresh code and do not reuse the previous one" ;;
        15) rm -rf "$sess"; die "SSH succeeded without an observed OS Login 2FA challenge; refusing to report MFA completion" ;;
        *) rm -rf "$sess"; die "failed to establish SSH master (mfa helper exit $mfa_rc)" ;;
      esac
    fi
  fi

  if ! ssh_check "$sock"; then
    rm -rf "$sess"
    die "master socket is not alive after open"
  fi
  TRANSPORT_STATUS="verified"

  if [ "$WANT_TMUX" -eq 1 ]; then
    if "$(tool_ssh)" -o ControlPath="$sock" -o ControlMaster=no -- "$dest" "command -v tmux >/dev/null 2>&1"; then
      "$(tool_ssh)" -o ControlPath="$sock" -o ControlMaster=no -- "$dest" \
        "tmux has-session -t gcloud-operator 2>/dev/null || tmux new-session -d -s gcloud-operator" || true
      echo "tmux=ready"
    else
      echo "tmux=unavailable"
    fi
  fi

  echo "handle=$sess"
  echo "control_path=$sock"
  echo "expires_at=$expires"
  echo "mfa_method=$MFA_METHOD"
  echo "mfa_completed=true"
  echo "ssh_destination=$dest"
  print_identity_banner
}

load_session() {
  local handle="$1"
  require_handle "$handle"
  HANDLE="$handle"
  STATE="$(session_state_path "$handle")"
  SOCK="$(state_get "$STATE" control_path)"
  DEST="$(state_get "$STATE" ssh_destination)"
  PROJECT="$(state_get "$STATE" project)"
  ZONE="$(state_get "$STATE" zone)"
  VM="$(state_get "$STATE" vm)"
  ACCOUNT="$(state_get "$STATE" account)"
  INSTANCE_ID="$(state_get "$STATE" instance_id)"
  OSLOGIN_USER="$(state_get "$STATE" oslogin_user)"
  IDENTITY="$(state_get "$STATE" identity)"
  EXPIRES="$(state_get "$STATE" expires_at)"
  MFA_METHOD="$(state_get "$STATE" mfa_method)"
}

live_identity_ok() {
  local live_acct live_id live_user live
  live_acct="$(collect_account || true)"
  OSLOGIN_USER_LIVE="$(oslogin_user)"
  if ! collect_instance; then
    echo "class=identity_probe_failed"
    return 1
  fi
  live_id="$INSTANCE_ID"
  live_user="$OSLOGIN_USER_LIVE"
  live="$(identity_line "$live_acct" "$PROJECT" "$ZONE" "$VM" "$live_id" "$live_user")"
  if [ "$live" != "$IDENTITY" ]; then
    echo "class=identity_mismatch"
    echo "recorded_identity=$IDENTITY"
    echo "live_identity=$live"
    return 1
  fi
  return 0
}

require_live_master() {
  local sock="$1"
  if [ -S "$sock" ] || [ -e "$sock" ]; then
    if ssh_check "$sock"; then
      return 0
    fi
    die "class=stale_socket: control socket exists but the master is dead; close this handle and open a new session (fresh MFA)"
  fi
  die "class=master_dead: SSH master is not alive; close and reopen (fresh MFA). Do not run --troubleshoot."
}

cmd_status() {
  [ "${1:-}" = -- ] && shift
  local handle="${1:-}"
  load_session "$handle"
  local now alive="false" expired="false"
  now="$(now_epoch)"
  if ssh_check "$SOCK"; then alive="true"; fi
  [ "$now" -ge "$EXPIRES" ] && expired="true"
  echo "handle=$HANDLE"
  echo "alive=$alive"
  echo "expired=$expired"
  echo "expires_at=$EXPIRES"
  echo "project=$PROJECT"
  echo "zone=$ZONE"
  echo "vm=$VM"
  echo "account=$ACCOUNT"
  echo "mfa_method=$MFA_METHOD"
  echo "ssh_destination=$DEST"
  echo "control_path=$SOCK"
  echo "planned_network_path=iap-tcp"
  if [ "$alive" != true ]; then
    echo "transport=unverified"
    echo "class=master_dead"
    return 1
  fi
  echo "transport=verified"
  live_identity_ok || return 1
  echo "class=ok"
}

cmd_run() {
  [ "${1:-}" = -- ] && shift
  local handle="${1:-}"
  shift || die "missing handle"
  [ "${1:-}" = -- ] && shift
  [ $# -ge 1 ] || die "missing remote command"
  load_session "$handle"
  require_live_master "$SOCK"
  live_identity_ok || die "class=identity_mismatch: refusing to reuse a session whose identity does not match"
  local remote
  remote="exec $(quote_remote_argv "$@")"
  if "$(tool_ssh)" -o ControlPath="$SOCK" -o ControlMaster=no -o RequestTTY=no -- "$DEST" "$remote"; then
    return 0
  fi
  if ssh_check "$SOCK"; then
    echo "class=remote_command_failed" >&2
    echo "master_alive=true" >&2
  else
    echo "class=master_dead" >&2
    echo "master_alive=false" >&2
  fi
  return 1
}

copy_mode() {
  local direction="$1"
  shift
  [ "${1:-}" = -- ] && shift
  local handle="${1:-}"
  shift || die "missing handle"
  local src dst
  src="${1:-}"
  dst="${2:-}"
  shift 2 || die "missing copy paths"
  OVERWRITE=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --overwrite) OVERWRITE=1; shift ;;
      --) shift ;;
      *) die "unknown copy flag: $1" ;;
    esac
  done
  [ -n "$src" ] && [ -n "$dst" ] || die "missing copy paths"
  case "$src$dst" in
    *$'\n'*) die "refusing paths that contain newlines" ;;
  esac
  load_session "$handle"
  require_live_master "$SOCK"
  live_identity_ok || die "class=identity_mismatch: refusing to reuse a session whose identity does not match"

  local scp
  scp="$(tool_scp)"
  if [ "$direction" = to ]; then
    [ -e "$src" ] || die "local source does not exist: $src"
    if "$(tool_ssh)" -o ControlPath="$SOCK" -o ControlMaster=no -o RequestTTY=no -- "$DEST" \
        "exec $(quote_remote_argv test -e "$dst")"; then
      [ "$OVERWRITE" -eq 1 ] || die "refusing to overwrite existing remote path (pass --overwrite)"
    fi
    "$scp" -o ControlPath="$SOCK" -o ControlMaster=no -o ControlPersist=no -- "$src" "$DEST:$dst"
  else
    [ -e "$dst" ] && [ "$OVERWRITE" -ne 1 ] && die "refusing to overwrite existing local path (pass --overwrite)"
    "$scp" -o ControlPath="$SOCK" -o ControlMaster=no -o ControlPersist=no -- "$DEST:$src" "$dst"
  fi
}

cmd_copy_to() { copy_mode to "$@"; }
cmd_copy_from() { copy_mode from "$@"; }

cmd_close() {
  [ "${1:-}" = -- ] && shift
  local handle="${1:-}"
  if [ -z "$handle" ]; then
    die "missing session handle"
  fi
  case "$handle" in
    /tmp|/var/tmp|"$HOME"|/|"$PWD") die "refusing to operate on a broad path: $handle" ;;
  esac
  if [ ! -e "$handle" ]; then
    echo "closed=already"
    echo "handle=$handle"
    return 0
  fi
  if ! is_session_dir "$handle"; then
    die "refusing to remove a directory that is not this session"
  fi
  local sock
  sock="$(session_control_path "$handle")"
  if [ -e "$sock" ]; then
    ssh_exit_master "$sock"
  fi
  rm -f "$sock"
  rm -rf "$handle"
  echo "closed=true"
  echo "handle=$handle"
}

cmd_troubleshoot() {
  parse_target_flags "$@"
  require_target
  if [ "$AUTHORIZE_MUTATIONS" -ne 1 ]; then
    cat >&2 <<'EOF'
gcloud-session: refusing gcloud compute ssh --troubleshoot.

That flag is not read-only. Observed mutations include enabling the
Network Management API and creating connectivity-test resources.

Pass --authorize-mutations only after the surrounding task authorizes
those exact mutations. This helper will then inventory prior state,
preview cleanup, and run the flag. It will not enable APIs or create
firewall rules, external IPs, or IAM bindings on its own.
EOF
    exit 1
  fi
  echo "preview=may enable networkmanagement.googleapis.com"
  echo "preview=may create network-management connectivity-tests"
  echo "preview=does not authorize firewall, external-IP, metadata, or IAM changes"
  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  echo "inventory_services_begin"
  gcloud_run "$out" "$err" services list --project="$PROJECT" --enabled --format='value(config.name)' || true
  cat "$out"
  echo "inventory_services_end"
  echo "inventory_conn_tests_begin"
  gcloud_run "$out" "$err" network-management connectivity-tests list --project="$PROJECT" --format='value(name)' || true
  cat "$out"
  echo "inventory_conn_tests_end"
  echo "cleanup=gcloud network-management connectivity-tests delete NAME --project=$PROJECT"
  echo "cleanup=do not disable APIs automatically; that is a separate authorized mutation"
  if ! gcloud_run "$out" "$err" compute ssh "$VM" --project="$PROJECT" --zone="$ZONE" --tunnel-through-iap --troubleshoot; then
    redact_text <"$err" >&2
    rm -f "$out" "$err"
    die "authorized troubleshoot command failed"
  fi
  cat "$out"
  rm -f "$out" "$err"
}

main() {
  local cmd="${1:-}"
  [ -n "$cmd" ] || usage
  shift || true
  case "$cmd" in
    doctor) cmd_doctor "$@" ;;
    open) cmd_open "$@" ;;
    run) cmd_run "$@" ;;
    copy-to) cmd_copy_to "$@" ;;
    copy-from) cmd_copy_from "$@" ;;
    status) cmd_status "$@" ;;
    close) cmd_close "$@" ;;
    troubleshoot) cmd_troubleshoot "$@" ;;
    -h|--help|help) usage ;;
    *) die "unknown command: $cmd" ;;
  esac
}

main "$@"
