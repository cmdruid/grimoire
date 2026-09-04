# shellcheck shell=bash
# Shared assertions and stub environment for gcloud-operator tests.
pass=0
fail=0

expect() {
  if grep -qF -- "$2" "$3"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected to find: $2" >&2
    echo "      in: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent() {
  if grep -qF -- "$2" "$3"; then
    echo "FAIL: $1 — expected NOT to find: $2" >&2
    echo "      in: $3" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

expect_eq() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_file_absent() {
  if [ -e "$2" ]; then
    echo "FAIL: $1 — path still exists: $2" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

report() {
  echo "$1: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

write_stubs() {
  local bin="$1"
  mkdir -p "$bin"
  cat >"$bin/gcloud" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >> "$GCLOUD_LOG"
for a in "$@"; do
  if [ "$a" = "--troubleshoot" ] && [ "${GCLOUD_ALLOW_TROUBLESHOOT:-}" != 1 ]; then
    echo "unexpected --troubleshoot" >&2
    exit 2
  fi
  if [ "$a" = "enable" ] && [ "${GCLOUD_ALLOW_ENABLE:-}" != 1 ]; then
    echo "unexpected services enable" >&2
    exit 2
  fi
  if [ "$a" = "firewall-rules" ]; then
    echo "unexpected firewall mutation" >&2
    exit 2
  fi
  if [ "$a" = "add-access-config" ]; then
    echo "unexpected external IP mutation" >&2
    exit 2
  fi
  if [ "$a" = "keys" ]; then
    echo "unexpected service-account key mutation" >&2
    exit 2
  fi
done
if [ "${GCLOUD_STUB_MODE:-}" = sandbox ]; then
  echo "ERROR: [Errno 1] Operation not permitted: '$HOME/.config/gcloud/credentials.db'" >&2
  exit 1
fi
if [ "${GCLOUD_STUB_MODE:-}" = auth_expired ]; then
  echo "There was a problem refreshing your current auth tokens: invalid_grant" >&2
  exit 1
fi
cmd=""
prev=""
for a in "$@"; do
  case "$a" in
    compute|auth|info|services|network-management|os-login|instances|ssh|describe|list|describe-profile|project-info) cmd="$cmd $a" ;;
  esac
done
case "$cmd" in
  *" project-info"*)
    if [ -n "${FAKE_PROJECT_JSON:-}" ]; then cat "$FAKE_PROJECT_JSON"
    else printf '%s\n' '{"commonInstanceMetadata":{"items":[]}}'
    fi
    ;;
  *" info"*) printf '%s\n' "$FAKE_CONFIG_DIR" ;;
  *" auth list"*) printf '%s\n' "$FAKE_ACCOUNT" ;;
  *" instances describe"*) cat "$FAKE_INSTANCE_JSON" ;;
  *" os-login describe-profile"*) printf '%s\n' "$FAKE_OSLOGIN_USER" ;;
  *" compute ssh"*)
    if printf '%s\n' "$@" | grep -qx -- '--dry-run'; then
      if [ "${GCLOUD_STUB_MODE:-}" = port_occupied ]; then
        echo "Address already in use" >&2
        exit 1
      fi
      printf '%s -o ProxyCommand=%s %s@%s\n' \
        "$FAKE_SSH" "'gcloud compute start-iap-tunnel $FAKE_VM 22 --listen-on-stdin --project=$FAKE_PROJECT --zone=$FAKE_ZONE'" \
        "$FAKE_OSLOGIN_USER" "$FAKE_VM"
    elif printf '%s\n' "$@" | grep -qx -- '--troubleshoot'; then
      echo "troubleshoot-ran"
    else
      echo "unexpected live gcloud compute ssh" >&2
      exit 2
    fi
    ;;
  *" services list"*) printf '%s\n' "compute.googleapis.com" ;;
  *" connectivity-tests list"*) printf '%s\n' "${FAKE_CONN_TESTS:-}" ;;
  *) echo "unhandled gcloud:$cmd" >&2; exit 1 ;;
esac
EOF
  cat >"$bin/ssh" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >> "$SSH_LOG"
ctl=""
master=""
action=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      case "$2" in
        ControlPath=*) ctl="${2#ControlPath=}" ;;
        ControlMaster=*) master="${2#ControlMaster=}" ;;
      esac
      shift 2
      ;;
    -S) ctl="$2"; shift 2 ;;
    -O) action="$2"; shift 2 ;;
    -f|-N|-t|-T|-n|-q) shift ;;
    -i) shift 2 ;;
    --) shift; break ;;
    -*) shift ;;
    *) break ;;
  esac
done
dest="${1:-}"
[ $# -gt 0 ] && shift
case "$action" in
  check)
    if [ -n "$ctl" ] && [ -e "$ctl" ] && grep -q master "$ctl" 2>/dev/null; then
      exit 0
    fi
    exit 255
    ;;
  exit)
    rm -f "$ctl"
    exit 0
    ;;
esac
if [ "$master" = "yes" ]; then
  mkdir -p "$(dirname "$ctl")"
  echo master > "$ctl"
  chmod 600 "$ctl"
  echo $(( $(cat "$AUTH_COUNT" 2>/dev/null || echo 0) + 1 )) > "$AUTH_COUNT"
  exit 0
fi
if [ -z "$ctl" ] || [ ! -e "$ctl" ] || ! grep -q master "$ctl"; then
  echo "no master" >&2
  exit 255
fi
echo $(( $(cat "$CMD_COUNT" 2>/dev/null || echo 0) + 1 )) > "$CMD_COUNT"
if [ $# -gt 0 ]; then
  mkdir -p "$FAKE_REMOTE"
  (cd "$FAKE_REMOTE" && sh -c "$1")
  exit $?
fi
exit 0
EOF
  cat >"$bin/scp" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >> "$SCP_LOG"
ctl=""
master=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      case "$2" in
        ControlPath=*) ctl="${2#ControlPath=}" ;;
        ControlMaster=*) master="${2#ControlMaster=}" ;;
      esac
      shift 2
      ;;
    --) shift; break ;;
    -*) shift ;;
    *) break ;;
  esac
done
if [ "$master" = "yes" ]; then
  echo "scp opened a new master" >&2
  exit 2
fi
if [ -z "$ctl" ] || [ ! -e "$ctl" ]; then
  echo "scp without master" >&2
  exit 255
fi
echo $(( $(cat "$XFER_COUNT" 2>/dev/null || echo 0) + 1 )) > "$XFER_COUNT"
src="$1"
dst="$2"
case "$dst" in
  *:*)
    remote="${dst#*:}"
    mkdir -p "$(dirname "$FAKE_REMOTE/$remote")"
    cp "$src" "$FAKE_REMOTE/$remote"
    ;;
  *)
    remote="${src#*:}"
    mkdir -p "$(dirname "$dst")"
    cp "$FAKE_REMOTE/$remote" "$dst"
    ;;
esac
EOF
  chmod +x "$bin/gcloud" "$bin/ssh" "$bin/scp"
}
