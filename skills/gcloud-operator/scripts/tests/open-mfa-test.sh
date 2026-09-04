#!/usr/bin/env bash
# Wrapper-level MFA tests: real open -> Python helper, no GCLOUD_SESSION_SKIP_MFA.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
GS="$SKILL/scripts/gcloud-session.sh"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/gcloud-operator-open-mfa.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"
BIN="$TMP/bin"
write_stubs "$BIN"

cat >"$BIN/ssh" <<EOF
#!/bin/sh
exec python3 "$DIR/fixtures/fake-mfa-ssh.py" "\$@"
EOF
chmod +x "$BIN/ssh" "$DIR/fixtures/fake-mfa-ssh.py"

export PATH="$BIN:/usr/bin:/bin"
export HOME="$TMP/home"
mkdir -p "$HOME/.config/gcloud" "$TMP/sessroot"
chmod 700 "$HOME/.config/gcloud"

export FAKE_CONFIG_DIR="$HOME/.config/gcloud"
export FAKE_ACCOUNT="operator@example.com"
export FAKE_PROJECT="demo-project"
export FAKE_ZONE="us-central1-a"
export FAKE_VM="test-vm"
export FAKE_OSLOGIN_USER="operator_example_com"
export FAKE_INSTANCE_JSON="$DIR/fixtures/instance.json"
export FAKE_SSH="$BIN/ssh"
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
export GCLOUD_SESSION_NOW=1000000
export GCLOUD_SESSION_MFA_TIMEOUT=4
unset GCLOUD_SESSION_SKIP_MFA || true
: >"$GCLOUD_LOG"
: >"$SSH_LOG"
: >"$SCP_LOG"
echo 0 >"$AUTH_COUNT"
echo 0 >"$CMD_COUNT"
echo 0 >"$XFER_COUNT"

write_code() {
  local path="$1" value="${2:-SECRETCODE99}" mode="${3:-600}"
  printf '%s' "$value" >"$path"
  chmod "$mode" "$path"
}

open_with() {
  local mode="$1" method="${2:-security-code}" expect_choice="${3:-1}"
  local code="$TMP/code"
  write_code "$code" "SECRETCODE99" 600
  export FAKE_MFA_MODE="$mode"
  export MFA_CAPTURE="$TMP/capture"
  export MFA_EXPECT_CHOICE="$expect_choice"
  export MFA_EXPECT_CODE="SECRETCODE99"
  if [ "$mode" = expire ]; then
    export FAKE_MFA_SLEEP=8
  else
    unset FAKE_MFA_SLEEP || true
  fi
  : >"$TMP/capture"
  set +e
  "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
    --mfa-method "$method" --mfa-code-file "$code" >"$OUT" 2>"$ERR"
  rc=$?
  set -e
  echo "$rc"
}

# Successful submission through the real wrapper.
rc="$(open_with ok security-code 1)"
expect_eq "wrapper open succeeds after observed MFA" "0" "$rc"
expect "wrapper reports completion" "mfa_completed=true" "$OUT"
expect "wrapper chose menu 1" "choice=1" "$TMP/capture"
expect_file_absent "success unlinks code file" "$TMP/code"
HANDLE="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"
if [ -n "$HANDLE" ] && grep -R "SECRETCODE99" "$HANDLE" >/dev/null 2>&1; then
  echo "FAIL: MFA code persisted after wrapper success" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -q "SECRETCODE99" "$OUT" "$ERR" 2>/dev/null; then
  echo "FAIL: MFA code leaked into wrapper output" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if [ -n "$HANDLE" ]; then
  "$GS" close -- "$HANDLE" >/dev/null
fi

# Classified helper failures must keep their statuses (not collapse to 0).
rc="$(open_with expire security-code 1)"
expect_eq "wrapper maps expiry" "1" "$rc"
expect "wrapper expiry message" "MFA prompt expired" "$ERR"
expect_absent "expiry is not helper exit 0" "mfa helper exit 0" "$ERR"
expect_file_absent "expiry unlinks code file" "$TMP/code"

rc="$(open_with wrong-method security-code 1)"
expect_eq "wrapper maps rejected method" "1" "$rc"
expect "wrapper rejected-method message" "MFA method was rejected" "$ERR"
expect_absent "reject is not helper exit 0" "mfa helper exit 0" "$ERR"

rc="$(open_with ambiguous security-code 1)"
expect_eq "wrapper maps ambiguous auth" "1" "$rc"
expect "wrapper ambiguous message" "authentication outcome is ambiguous" "$ERR"
expect_absent "ambiguous is not helper exit 0" "mfa helper exit 0" "$ERR"

rc="$(open_with no-mfa security-code 1)"
expect_eq "wrapper maps missing challenge" "1" "$rc"
expect "wrapper missing-challenge message" "without an observed OS Login 2FA challenge" "$ERR"
expect_absent "false success not reported" "mfa_completed=true" "$OUT"

rc="$(open_with unknown-menu security-code 1)"
expect_eq "wrapper maps unknown menu" "1" "$rc"
expect "wrapper unknown menu uses method reject" "MFA method was rejected" "$ERR"
expect_absent "unknown menu not guessed as 1" "choice=1" "$TMP/capture"

rc="$(open_with password security-code 1)"
expect_eq "wrapper does not complete on Password:" "1" "$rc"
expect_absent "no completion on password prompt" "mfa_completed=true" "$OUT"

# Code-file contract.
CODE="$TMP/code"
write_code "$CODE" "SECRETCODE99" 644
if "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT" 2>"$ERR"; then
  echo "FAIL: permissive mode 644 was accepted" >&2
  fail=$((fail + 1))
else
  expect "644 refused" "no group or other access" "$ERR"
fi
[ -e "$CODE" ] && pass=$((pass + 1)) || { echo "FAIL: rejected 644 file was deleted" >&2; fail=$((fail + 1)); }

write_code "$CODE" "SECRETCODE99" 600
ln -sf "$CODE" "$TMP/code.link"
if "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$TMP/code.link" >"$OUT" 2>"$ERR"; then
  echo "FAIL: symlink code file was accepted" >&2
  fail=$((fail + 1))
else
  expect "symlink refused" "not a symlink" "$ERR"
fi

: >"$CODE"
chmod 600 "$CODE"
if "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT" 2>"$ERR"; then
  echo "FAIL: empty code file was accepted" >&2
  fail=$((fail + 1))
else
  expect "empty refused" "mfa code file empty" "$ERR"
fi

python3 -c 'import sys; sys.stdout.write("x"*200)' >"$CODE"
chmod 600 "$CODE"
if "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT" 2>"$ERR"; then
  echo "FAIL: oversized code file was accepted" >&2
  fail=$((fail + 1))
else
  expect "oversized refused" "too large" "$ERR"
fi

# Accepted file is unlinked when a later pre-MFA step fails.
write_code "$CODE" "SECRETCODE99" 600
if GCLOUD_STUB_MODE=port_occupied "$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$CODE" >"$OUT" 2>"$ERR"; then
  echo "FAIL: occupied-port open succeeded" >&2
  fail=$((fail + 1))
else
  expect "dry-run failure still classified" "port_occupied" "$ERR"
  expect_file_absent "dry-run failure unlinks accepted code file" "$CODE"
fi

report "open-mfa-test"
