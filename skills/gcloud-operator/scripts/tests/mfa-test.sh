#!/usr/bin/env bash
# MFA helper: method distinction, no code in logs, expiry, wrong method, ambiguous auth.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
MFA="$SKILL/scripts/gcloud-session-mfa.py"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/gcloud-operator-mfa.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FAKE="$DIR/fixtures/fake-mfa-ssh.py"
chmod +x "$FAKE" "$MFA" 2>/dev/null || true

run_helper() {
  local method="$1" code="$2" mode="$3" expect_choice="$4"
  local codefile="$TMP/code" log="$TMP/debug.log" capture="$TMP/capture"
  printf '%s' "$code" >"$codefile"
  chmod 600 "$codefile"
  : >"$log"; : >"$capture"
  export MFA_CAPTURE="$capture"
  export FAKE_MFA_MODE="$mode"
  export FAKE_CONTROL_PATH="$TMP/control.sock"
  export MFA_EXPECT_CHOICE="$expect_choice"
  export MFA_EXPECT_CODE="$code"
  set +e
  python3 "$MFA" --method "$method" --code-file "$codefile" --timeout 2 --log "$log" -- \
    python3 "$FAKE" >"$TMP/mfa.out" 2>"$TMP/mfa.err"
  rc=$?
  set -e
  echo "$rc"
}

rc="$(run_helper security-code SECRETCODE99 ok 1)"
expect_eq "security-code succeeds" "0" "$rc"
expect "chose menu 1" "choice=1" "$TMP/capture"
expect_file_absent "code file unlinked after security-code" "$TMP/code"
if grep -q "SECRETCODE99" "$TMP/debug.log" "$TMP/mfa.out" "$TMP/mfa.err" 2>/dev/null; then
  echo "FAIL: security-code value leaked into logs" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

rc="$(run_helper authenticator 123456 ok 2)"
expect_eq "authenticator succeeds" "0" "$rc"
expect "chose menu 2" "choice=2" "$TMP/capture"
if grep -q "123456" "$TMP/debug.log" "$TMP/mfa.out" "$TMP/mfa.err" 2>/dev/null; then
  echo "FAIL: authenticator code leaked into logs" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# Digit count does not select the method: 6-digit security-code still sends 1.
rc="$(run_helper security-code 123456 ok 1)"
expect_eq "6-digit security-code still uses menu 1" "0" "$rc"
expect "6-digit still choice 1" "choice=1" "$TMP/capture"

export FAKE_MFA_SLEEP=3
rc="$(run_helper security-code waitcode expire 1)"
expect_eq "prompt expiry" "10" "$rc"

rc="$(run_helper security-code bad wrong-method 1)"
expect_eq "wrong method / 2FA reject" "11" "$rc"

rc="$(run_helper security-code maybe ambiguous 1)"
expect_eq "ambiguous after sending code" "12" "$rc"

rc="$(run_helper security-code SECRETCODE99 reordered 2)"
expect_eq "reordered menu uses g.co/sc label not ordinal 1" "0" "$rc"
expect "reordered chose 2" "choice=2" "$TMP/capture"

rc="$(run_helper security-code SECRETCODE99 unknown-menu 1)"
expect_eq "unknown menu refused" "11" "$rc"
expect_absent "did not guess unknown menu" "choice=1" "$TMP/capture"

rc="$(run_helper security-code SECRETCODE99 no-mfa 1)"
expect_eq "success without MFA challenge refused" "15" "$rc"

rc="$(run_helper security-code SECRETCODE99 password 1)"
expect_eq "ordinary password prompt is not a code prompt" "10" "$rc"
if grep -q "password_len=11" "$TMP/capture" 2>/dev/null; then
  echo "FAIL: submitted MFA code to a Password: prompt" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "mfa-test"
