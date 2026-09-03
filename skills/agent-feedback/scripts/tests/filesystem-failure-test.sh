#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-filesystem.XXXXXX")"
trap 'rm -rf "$T"' EXIT

H="$T/home"; new_home "$H"; HOME="$H" "$PROVIDER" init >/dev/null
F="$(store_for "$H")"

expect_exact_failure() {
  local label="$1" expected="$2"
  shift 2
  if "$@" >"$T/$label.out" 2>"$T/$label.err"; then
    fail "$label unexpectedly succeeded"
  else
    pass
  fi
  printf '%s\n' "$expected" >"$T/$label.expected"
  same "$T/$label.err" "$T/$label.expected"
  if [ ! -s "$T/$label.out" ]; then pass; else fail "$label emitted success output"; fi
}

# Query temporaries use a caller-selected temporary root, but a failure there
# still has the provider's single-line diagnostic contract.
cp "$F" "$T/query.before"
expect_exact_failure query-temp 'reason=write-failed action=retry' \
  env HOME="$H" TMPDIR="$T/missing-temp-root" "$PROVIDER" query
same "$F" "$T/query.before"

fake_bin="$T/fake-bin"; mkdir "$fake_bin"
real_cp="$(command -v cp)"; real_chmod="$(command -v chmod)"; real_mv="$(command -v mv)"
for operation in cp chmod mv; do
  case "$operation" in
    cp) real="$real_cp" ;;
    chmod) real="$real_chmod" ;;
    mv) real="$real_mv" ;;
  esac
  # The quoted program is written for the generated wrapper, not expanded here.
  # shellcheck disable=SC2016
  printf '%s\n' '#!/usr/bin/env bash' 'set -u' \
    'for arg in "$@"; do if [ "${AF_FAIL_OPERATION:-}" = "'"$operation"'" ] && [[ "$arg" == *".agent-feedback.tsv.tmp."* ]]; then exit 91; fi; done' \
    'exec "'"$real"'" "$@"' >"$fake_bin/$operation"
  chmod +x "$fake_bin/$operation"
done

capture_args=(capture --origin agent --subject-type skill --subject architect --subject-ref unknown
  --invocation x --kind gap --summary x --statement x --incident x --consequence x
  --suggestion x --redacted no)
for operation in chmod cp mv; do
  cp "$F" "$T/$operation.before"
  expect_exact_failure "$operation-failure" 'reason=write-failed action=retry' \
    env HOME="$H" PATH="$fake_bin:$PATH" AF_FAIL_OPERATION="$operation" "$PROVIDER" "${capture_args[@]}"
  same "$F" "$T/$operation.before"
  if [ ! -e "$F.lock" ]; then pass; else fail "$operation failure left a lock"; fi
  if [ "$(find "$(dirname "$F")" -name '.agent-feedback.tsv.tmp.*' | wc -l | tr -d '[:space:]')" = 0 ]; then
    pass
  else
    fail "$operation failure left a temporary"
  fi
done

# A real signal during the pre-rename seam is normalized and leaves the
# incumbent byte-identical with no operation-owned debris.
signal_hook="$T/signal-before-rename.sh"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'kill -TERM "$PPID"' >"$signal_hook"
chmod +x "$signal_hook"
cp "$F" "$T/signal.before"
expect_exact_failure signal 'reason=interrupted action=retry' \
  env HOME="$H" AGENT_FEEDBACK_TEST_BEFORE_RENAME="$signal_hook" "$PROVIDER" "${capture_args[@]}"
same "$F" "$T/signal.before"
if [ ! -e "$F.lock" ]; then pass; else fail 'signal left a lock'; fi
if [ "$(find "$(dirname "$F")" -name '.agent-feedback.tsv.tmp.*' | wc -l | tr -d '[:space:]')" = 0 ]; then
  pass
else
  fail 'signal left a temporary'
fi

# A signal delivered by mv only after a successful rename reports the committed
# result instead of instructing the caller to duplicate the mutation.
post_rename_bin="$T/post-rename-bin"; mkdir "$post_rename_bin"
post_rename_mv="$post_rename_bin/mv"
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
  '"$AF_REAL_MV" "$@"' \
  'for arg in "$@"; do if [[ "$arg" == *".agent-feedback.tsv.tmp."* ]]; then kill -TERM "$PPID"; break; fi; done' \
  >"$post_rename_mv"
chmod +x "$post_rename_mv"
random_source="$T/post-rename-random.sh"
printf '%s\n' '#!/bin/sh' 'printf feedface' >"$random_source"; chmod +x "$random_source"

P="$T/post-rename-home"; new_home "$P"; HOME="$P" "$PROVIDER" init >/dev/null
PF="$(store_for "$P")"
if env HOME="$P" PATH="$post_rename_bin:$PATH" AF_REAL_MV="$real_mv" \
  AGENT_FEEDBACK_TEST_UTC_NOW=2026-09-03T12:00:00Z \
  AGENT_FEEDBACK_TEST_RANDOM_SOURCE="$random_source" "$PROVIDER" "${capture_args[@]}" \
  >"$T/post-rename-capture.out" 2>"$T/post-rename-capture.err"; then
  pass
else
  fail 'post-rename capture signal did not report success'
fi
printf '%s\n' 'captured=AF-20260903T120000Z-feedface' 'count=1' 'redacted=no' \
  >"$T/post-rename-capture.expected"
same "$T/post-rename-capture.out" "$T/post-rename-capture.expected"
if [ ! -s "$T/post-rename-capture.err" ]; then pass; else fail 'post-rename capture emitted a diagnostic'; fi
if [ "$(awk 'END{print NR-1}' "$PF")" = 1 ]; then pass; else fail 'post-rename capture was not committed once'; fi
if [ ! -e "$PF.lock" ]; then pass; else fail 'post-rename capture left a lock'; fi

close_id='AF-20260903T120000Z-feedface'
if env HOME="$P" PATH="$post_rename_bin:$PATH" AF_REAL_MV="$real_mv" \
  AGENT_FEEDBACK_TEST_UTC_NOW=2026-09-03T13:00:00Z "$PROVIDER" close \
  --id "$close_id" --as stale --reason 'Post-rename close.' \
  >"$T/post-rename-close.out" 2>"$T/post-rename-close.err"; then
  pass
else
  fail 'post-rename close signal did not report success'
fi
printf 'closed=%s\ncount=1\n' "$close_id" >"$T/post-rename-close.expected"
same "$T/post-rename-close.out" "$T/post-rename-close.expected"
if [ ! -s "$T/post-rename-close.err" ]; then pass; else fail 'post-rename close emitted a diagnostic'; fi
if [ "$(awk -F '\t' -v id="$close_id" '$1==id{print $17":"$18}' "$PF")" = 'closed:stale' ]; then
  pass
else
  fail 'post-rename close was not committed'
fi
if [ ! -e "$PF.lock" ]; then pass; else fail 'post-rename close left a lock'; fi

finish filesystem-failure-test
