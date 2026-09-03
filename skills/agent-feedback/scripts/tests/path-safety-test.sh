#!/usr/bin/env bash
set -euo pipefail

HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-paths.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# HOME is resolved physically; only descendants are subject to the no-symlink
# storage rule.
real_home="$T/real-home"; linked_home="$T/linked-home"
new_home "$real_home"
ln -s "$real_home" "$linked_home"
HOME="$linked_home" "$PROVIDER" init >/dev/null
ok test -f "$real_home/.agents/skilldata/agent-feedback/feedback.tsv"

for path_case in agents-symlink skilldata-symlink owner-symlink file-symlink agents-file skilldata-file owner-file file-directory lock-symlink lock-file; do
  H="$T/$path_case"; new_home "$H"
  outside="$T/outside-$path_case"; mkdir -p "$outside"
  printf 'outside-canary\n' >"$outside/canary"
  case "$path_case" in
    agents-symlink)
      ln -s "$outside" "$H/.agents"
      ;;
    skilldata-symlink)
      mkdir "$H/.agents"; ln -s "$outside" "$H/.agents/skilldata"
      ;;
    owner-symlink)
      mkdir -p "$H/.agents/skilldata"; ln -s "$outside" "$H/.agents/skilldata/agent-feedback"
      ;;
    file-symlink)
      mkdir -p "$H/.agents/skilldata/agent-feedback"
      ln -s "$outside/canary" "$(store_for "$H")"
      ;;
    agents-file)
      printf 'not-a-directory\n' >"$H/.agents"
      ;;
    skilldata-file)
      mkdir "$H/.agents"; printf 'not-a-directory\n' >"$H/.agents/skilldata"
      ;;
    owner-file)
      mkdir -p "$H/.agents/skilldata"; printf 'not-a-directory\n' >"$H/.agents/skilldata/agent-feedback"
      ;;
    file-directory)
      mkdir -p "$(store_for "$H")"
      ;;
    lock-symlink)
      HOME="$H" "$PROVIDER" init >/dev/null
      ln -s "$outside" "$(store_for "$H").lock"
      ;;
    lock-file)
      HOME="$H" "$PROVIDER" init >/dev/null
      printf 'not-a-lock-directory\n' >"$(store_for "$H").lock"
      ;;
  esac
  no env HOME="$H" "$PROVIDER" init
  has "$outside/canary" 'outside-canary'
done

finish path-safety-test
