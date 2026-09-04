#!/usr/bin/env bash
# Adversarial but valid filenames and remote argv quoting.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
GS="$SKILL/scripts/gcloud-session.sh"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/gcloud-operator-quote.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"; BIN="$TMP/bin"
write_stubs "$BIN"
mkdir -p "$TMP/home/.config/gcloud" "$TMP/remote" "$TMP/sessroot"
chmod 700 "$TMP/home/.config/gcloud"

export PATH="$BIN:/usr/bin:/bin" HOME="$TMP/home"
export FAKE_CONFIG_DIR="$HOME/.config/gcloud"
export FAKE_ACCOUNT="operator@example.com"
export FAKE_PROJECT="demo-project" FAKE_ZONE="us-central1-a" FAKE_VM="test-vm"
export FAKE_OSLOGIN_USER="operator_example_com"
export FAKE_INSTANCE_JSON="$DIR/fixtures/instance.json"
export FAKE_SSH="$BIN/ssh" FAKE_REMOTE="$TMP/remote"
export GCLOUD_LOG="$TMP/gcloud.log" SSH_LOG="$TMP/ssh.log" SCP_LOG="$TMP/scp.log"
export AUTH_COUNT="$TMP/auth.count" CMD_COUNT="$TMP/cmd.count" XFER_COUNT="$TMP/xfer.count"
export GCLOUD_SESSION_GCLOUD="$BIN/gcloud" GCLOUD_SESSION_SSH="$BIN/ssh" GCLOUD_SESSION_SCP="$BIN/scp"
export GCLOUD_SESSION_TMPDIR="$TMP/sessroot" GCLOUD_SESSION_SKIP_MFA=1 GCLOUD_SESSION_NOW=1
: >"$GCLOUD_LOG"
: >"$SSH_LOG"
: >"$SCP_LOG"
echo 0 >"$AUTH_COUNT"; echo 0 >"$CMD_COUNT"; echo 0 >"$XFER_COUNT"

printf 'x' >"$TMP/code"
"$GS" open --project "$FAKE_PROJECT" --zone "$FAKE_ZONE" --vm "$FAKE_VM" \
  --mfa-method security-code --mfa-code-file "$TMP/code" >"$OUT"
HANDLE="$(sed -n 's/^handle=//p' "$OUT" | head -n 1)"

# Spaces, quotes, and shell metacharacters are data, not operators.
"$GS" run -- "$HANDLE" -- touch "file with spaces" >"$OUT" 2>"$ERR"
if [ -e "$FAKE_REMOTE/file with spaces" ]; then pass=$((pass + 1)); else echo "FAIL: space name" >&2; fail=$((fail + 1)); fi

"$GS" run -- "$HANDLE" -- touch "file; echo pwned" >"$OUT" 2>"$ERR"
if [ -e "$FAKE_REMOTE/file; echo pwned" ]; then pass=$((pass + 1)); else echo "FAIL: semicolon name" >&2; fail=$((fail + 1)); fi
if [ -e "$FAKE_REMOTE/pwned" ]; then echo "FAIL: semicolon was executed" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi

"$GS" run -- "$HANDLE" -- touch "a'b" >"$OUT" 2>"$ERR"
if [ -e "$FAKE_REMOTE/a'b" ]; then pass=$((pass + 1)); else echo "FAIL: quote name" >&2; fail=$((fail + 1)); fi

printf 'payload' >"$TMP/local file.txt"
"$GS" copy-to -- "$HANDLE" "$TMP/local file.txt" "incoming/local file.txt" >"$OUT" 2>"$ERR"
expect_eq "quoted copy contents" "payload" "$(cat "$FAKE_REMOTE/incoming/local file.txt")"

# Newlines in paths are refused.
if "$GS" copy-to -- "$HANDLE" "$TMP/local file.txt" $'bad\npath' >"$OUT" 2>"$ERR"; then
  echo "FAIL: newline path accepted" >&2
  fail=$((fail + 1))
else
  expect "newline path refused" "newlines" "$ERR"
fi

"$GS" close -- "$HANDLE" >/dev/null
report "quoting-test"
