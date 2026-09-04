#!/usr/bin/env bash
# Deterministic gcloud-session tests. No GCP credentials or network.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
GS="$SKILL/scripts/gcloud-session.sh"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/gcloud-operator-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"
BIN="$TMP/bin"
write_stubs "$BIN"

export PATH="$BIN:/usr/bin:/bin"
export HOME="$TMP/home"
mkdir -p "$HOME/.config/gcloud" "$TMP/remote" "$TMP/sessroot"
chmod 700 "$HOME/.config/gcloud"

export FAKE_CONFIG_DIR="$HOME/.config/gcloud"
export FAKE_ACCOUNT="operator@example.com"
export FAKE_PROJECT="demo-project"
export FAKE_ZONE="us-central1-a"
export FAKE_VM="test-vm"
export FAKE_OSLOGIN_USER="operator_example_com"
export FAKE_INSTANCE_JSON="$DIR/fixtures/instance.json"
export FAKE_SSH="$BIN/ssh"
export FAKE_REMOTE="$TMP/remote"
export GCLOUD_LOG="$TMP/gcloud.log"
export SSH_LOG="$TMP/ssh.log"
export SCP_LOG="$TMP/scp.log"
export AUTH_COUNT="$TMP/auth.count"
export CMD_COUNT="$TMP/cmd.count"
export XFER_COUNT="$TMP/xfer.count"
export GCLOUD_SESSION_GCLOUD="$BIN/gcloud"
export GCLOUD_SESSION_SSH="$BIN/ssh"
export GCLOUD_SESSION_SCP="$BIN/scp"
export GCLOUD_SESSION_TMPDIR="$TMP/sessroot"
export GCLOUD_SESSION_SKIP_MFA=1
export GCLOUD_SESSION_NOW=1000000
: >"$GCLOUD_LOG"
: >"$SSH_LOG"
: >"$SCP_LOG"
echo 0 >"$AUTH_COUNT"
echo 0 >"$CMD_COUNT"
echo 0 >"$XFER_COUNT"

refuse() {
  local lbl="$1" frag="$2"
  shift 2
  if "$GS" "$@" >"$OUT" 2>"$ERR"; then
    echo "FAIL: $lbl — expected refusal" >&2
    fail=$((fail + 1))
  else
    expect "$lbl" "$frag" "$ERR"
  fi
}

# --- doctor: exact project/zone/vm binding and IAP-only facts -----------------
"$GS" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" >"$OUT"
expect "doctor ok" "ok=true" "$OUT"
expect "doctor account" "account=operator@example.com" "$OUT"
expect "doctor project" "project=demo-project" "$OUT"
expect "doctor zone" "zone=us-central1-a" "$OUT"
expect "doctor vm" "vm=test-vm" "$OUT"
expect "doctor instance id" "instance_id=1234567890" "$OUT"
expect "doctor no external IP" "external_ip=none" "$OUT"
expect "doctor planned IAP path" "planned_network_path=iap-tcp" "$OUT"
expect "doctor transport unverified" "transport=unverified" "$OUT"
if grep -qx 'network_path=iap-tcp' "$OUT"; then
  echo "FAIL: doctor still prints unverified network_path=iap-tcp" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect "doctor oslogin 2fa" "oslogin_2fa=TRUE" "$OUT"
expect "doctor oslogin source instance" "oslogin_source=instance" "$OUT"
expect "doctor 2fa source instance" "oslogin_2fa_source=instance" "$OUT"
expect "doctor refuses troubleshoot by default" "troubleshoot=refused-by-default" "$OUT"
expect_absent "doctor did not call troubleshoot" "--troubleshoot" "$GCLOUD_LOG"

refuse "missing project" "missing --project" doctor --zone "$FAKE_ZONE" --vm "$FAKE_VM"
refuse "wildcard vm" "invalid --vm" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm 'vm*'
refuse "doctor troubleshoot flag" "refusing --troubleshoot" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" --troubleshoot

# --- effective OS Login from instance vs project ------------------------------
export FAKE_INSTANCE_JSON="$DIR/fixtures/instance-no-oslogin.json"
export FAKE_PROJECT_JSON="$DIR/fixtures/project-oslogin.json"
"$GS" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" >"$OUT"
expect "project oslogin fallback" "oslogin=TRUE" "$OUT"
expect "project oslogin source" "oslogin_source=project" "$OUT"
expect "project 2fa source" "oslogin_2fa_source=project" "$OUT"
printf 'x' >"$TMP/code-proj"
chmod 600 "$TMP/code-proj"
"$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$TMP/code-proj" >"$OUT"
expect "open allows project-effective 2FA" "transport=verified" "$OUT"
HANDLE_PROJ="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"
"$GS" close -- "$HANDLE_PROJ" >/dev/null
echo 0 >"$AUTH_COUNT"
echo 0 >"$CMD_COUNT"

export FAKE_INSTANCE_JSON="$DIR/fixtures/instance-oslogin-false.json"
export FAKE_PROJECT_JSON="$DIR/fixtures/project-oslogin.json"
"$GS" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" >"$OUT"
expect "instance FALSE overrides project" "oslogin=FALSE" "$OUT"
expect "instance override source" "oslogin_source=instance" "$OUT"
printf 'x' >"$TMP/code-off"
chmod 600 "$TMP/code-off"
if "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$TMP/code-off" >"$OUT" 2>"$ERR"; then
  echo "FAIL: open succeeded with OS Login 2FA disabled on the instance" >&2
  fail=$((fail + 1))
else
  expect "open refuses disabled 2FA" "effective OS Login 2FA is not enabled" "$ERR"
fi
expect_file_absent "disabled-2FA open unlinks code" "$TMP/code-off"

export FAKE_INSTANCE_JSON="$DIR/fixtures/instance.json"
unset FAKE_PROJECT_JSON

# --- sandbox vs expired auth classification ----------------------------------
if GCLOUD_STUB_MODE=sandbox "$GS" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" >"$OUT" 2>"$ERR"; then
  echo "FAIL: sandbox doctor succeeded" >&2
  fail=$((fail + 1))
else
  expect "sandbox class" "class=sandbox_denied" "$OUT"
  expect "sandbox remediation" "do not copy" "$OUT"
fi
if GCLOUD_STUB_MODE=auth_expired "$GS" doctor --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" >"$OUT" 2>"$ERR"; then
  echo "FAIL: auth_expired doctor succeeded" >&2
  fail=$((fail + 1))
else
  expect "auth expired class" "class=auth_expired" "$OUT"
fi
unset GCLOUD_STUB_MODE

# --- open + reuse: one master, multiple commands, one transfer ----------------
CODE="$TMP/code.txt"
printf 'SECRETCODE99' >"$CODE"
chmod 600 "$CODE"
"$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT"
expect "open handle" "handle=" "$OUT"
expect "open mfa method" "mfa_method=security-code" "$OUT"
expect "open completed" "mfa_completed=true" "$OUT"
expect "open transport verified" "transport=verified" "$OUT"
expect "open still names planned path" "planned_network_path=iap-tcp" "$OUT"
HANDLE="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"
[ -n "$HANDLE" ] || { echo "FAIL: no handle" >&2; fail=$((fail + 1)); HANDLE="$TMP/missing"; }
expect_file_absent "code file consumed" "$CODE"
if grep -R "SECRETCODE99" "$HANDLE" >/dev/null 2>&1; then
  echo "FAIL: MFA code persisted in session state or logs" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "one master authentication" "1" "$(cat "$AUTH_COUNT")"

"$GS" run -- "$HANDLE" -- true >"$OUT" 2>"$ERR"
"$GS" run -- "$HANDLE" -- uname -a >"$OUT" 2>"$ERR"
expect_eq "commands reused master" "1" "$(cat "$AUTH_COUNT")"
expect_eq "two remote commands" "2" "$(cat "$CMD_COUNT")"

printf 'hello' >"$TMP/local.txt"
"$GS" copy-to -- "$HANDLE" "$TMP/local.txt" incoming/note.txt >"$OUT" 2>"$ERR"
expect_eq "copy did not open a second master" "1" "$(cat "$AUTH_COUNT")"
expect_eq "one file transfer" "1" "$(cat "$XFER_COUNT")"
expect_eq "remote file contents" "hello" "$(cat "$FAKE_REMOTE/incoming/note.txt")"

"$GS" copy-from -- "$HANDLE" incoming/note.txt "$TMP/roundtrip.txt"
expect_eq "round-trip contents" "hello" "$(cat "$TMP/roundtrip.txt")"
expect_eq "still one master" "1" "$(cat "$AUTH_COUNT")"

# overwrite refused
if "$GS" copy-to -- "$HANDLE" "$TMP/local.txt" incoming/note.txt >"$OUT" 2>"$ERR"; then
  echo "FAIL: overwrite without flag succeeded" >&2
  fail=$((fail + 1))
else
  expect "overwrite refused" "refusing to overwrite existing remote path" "$ERR"
fi
"$GS" copy-to -- "$HANDLE" "$TMP/local.txt" incoming/note.txt --overwrite >"$OUT" 2>"$ERR"
expect_eq "explicit overwrite allowed" "hello" "$(cat "$FAKE_REMOTE/incoming/note.txt")"

if "$GS" copy-from -- "$HANDLE" incoming/note.txt "$TMP/roundtrip.txt" >"$OUT" 2>"$ERR"; then
  echo "FAIL: local overwrite without flag succeeded" >&2
  fail=$((fail + 1))
else
  expect "local overwrite refused" "refusing to overwrite existing local path" "$ERR"
fi

# identity mismatch
FAKE_ACCOUNT="other@example.com"
if "$GS" run -- "$HANDLE" -- true >"$OUT" 2>"$ERR"; then
  echo "FAIL: identity mismatch was reused" >&2
  fail=$((fail + 1))
else
  expect "identity mismatch refused" "identity does not match" "$ERR"
fi
FAKE_ACCOUNT="operator@example.com"

# remote command failure with healthy master
if "$GS" run -- "$HANDLE" -- sh -c 'exit 7' >"$OUT" 2>"$ERR"; then
  echo "FAIL: remote failure succeeded" >&2
  fail=$((fail + 1))
else
  expect "remote failure class" "class=remote_command_failed" "$ERR"
  expect "master still alive" "master_alive=true" "$ERR"
fi

# status + close
"$GS" status -- "$HANDLE" >"$OUT"
expect "status ok" "class=ok" "$OUT"
expect "status persist visible" "expires_at=1000720" "$OUT"
expect "status transport verified" "transport=verified" "$OUT"
"$GS" close -- "$HANDLE" >"$OUT"
expect "close true" "closed=true" "$OUT"
expect_file_absent "session dir removed" "$HANDLE"
"$GS" close -- "$HANDLE" >"$OUT"
expect "close idempotent" "closed=already" "$OUT"

# close refuses broad paths
refuse "close /tmp" "broad path" close -- /tmp
refuse "close home" "broad path" close -- "$HOME"

# --- MFA method is explicit ---------------------------------------------------
CODE="$TMP/code2.txt"
printf '123456' >"$CODE"
"$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method authenticator --mfa-code-file "$CODE" >"$OUT"
HANDLE2="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"
expect "authenticator recorded" "mfa_method=authenticator" "$OUT"
expect_absent "digit count not used as method" "inferred" "$OUT"
"$GS" close -- "$HANDLE2" >/dev/null

refuse "missing mfa method" "mfa-method must be" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM"
refuse "impersonation on open" "control-plane only" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --impersonate-service-account sa@x.iam.gserviceaccount.com

# --- occupied port / stale socket / master death ------------------------------
CODE="$TMP/code3.txt"
printf 'x' >"$CODE"
if GCLOUD_STUB_MODE=port_occupied "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT" 2>"$ERR"; then
  echo "FAIL: occupied port open succeeded" >&2
  fail=$((fail + 1))
else
  expect "occupied port classified" "port_occupied" "$ERR"
fi

CODE="$TMP/code4.txt"
printf 'x' >"$CODE"
"$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT"
HANDLE3="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"
# stale socket: file exists without master marker
sock="$(sed -n 's/^control_path=//p' "$OUT" | head -n 1)"
echo dead >"$sock"
if "$GS" run -- "$HANDLE3" -- true >"$OUT" 2>"$ERR"; then
  echo "FAIL: stale socket reused" >&2
  fail=$((fail + 1))
else
  expect "stale socket refused" "stale_socket" "$ERR"
fi
"$GS" close -- "$HANDLE3" >/dev/null

CODE="$TMP/code5.txt"
printf 'x' >"$CODE"
"$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT"
HANDLE4="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"
sock="$(sed -n 's/^control_path=//p' "$OUT" | head -n 1)"
rm -f "$sock"
if "$GS" run -- "$HANDLE4" -- true >"$OUT" 2>"$ERR"; then
  echo "FAIL: dead master reused" >&2
  fail=$((fail + 1))
else
  expect "dead master refused" "master_dead" "$ERR"
fi
"$GS" close -- "$HANDLE4" >/dev/null

# --- troubleshoot requires authorization and previews mutations ---------------
if "$GS" troubleshoot --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" >"$OUT" 2>"$ERR"; then
  echo "FAIL: troubleshoot without authorize succeeded" >&2
  fail=$((fail + 1))
else
  expect "troubleshoot refused" "refusing gcloud compute ssh --troubleshoot" "$ERR"
  expect "mentions Network Management API" "Network Management API" "$ERR"
fi
if GCLOUD_ALLOW_TROUBLESHOOT=1 "$GS" troubleshoot --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --authorize-mutations >"$OUT" 2>"$ERR"; then
  expect "preview API enablement" "may enable networkmanagement.googleapis.com" "$OUT"
  expect "preview connectivity tests" "may create network-management connectivity-tests" "$OUT"
  expect "inventory services" "inventory_services_begin" "$OUT"
  expect "cleanup named" "connectivity-tests delete" "$OUT"
  expect "authorized troubleshoot ran" "troubleshoot-ran" "$OUT"
else
  echo "FAIL: authorized troubleshoot refused" >&2
  cat "$ERR" >&2
  fail=$((fail + 1))
fi

# doctor/open never enable APIs or expose SSH
if grep -E 'services enable|firewall-rules create|add-access-config|iam service-accounts keys' "$SKILL/scripts/gcloud-session.sh" "$SKILL/scripts/gcloud-session-lib.sh" >/dev/null; then
  echo "FAIL: helper contains forbidden mutation commands" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "session-test"
