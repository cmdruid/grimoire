#!/usr/bin/env bash
# records-runtime-check.sh --root <absolute-root>
# Print the staged provider path only when Journal's public runtime boundary is healthy.
set -euo pipefail

die() { echo "reason=$1${2:+ action=$2}" >&2; exit 2; }

root=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || die usage; root="$2"; shift 2 ;;
    *) die usage ;;
  esac
done
[ -n "$root" ] || die usage

skill="$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)"
status_helper="$skill/scripts/records-layer-status.sh"
[ -x "$status_helper" ] || die package-status-helper
facts="$($status_helper runtime --root "$root")" || exit $?

value() { printf '%s\n' "$facts" | sed -n "s/^$1=//p" | head -n 1; }
ledger_status="$(value ledger_status)"
provider_status="$(value provider_status)"
provider_path="$(value provider_path)"

[ "$ledger_status" = regular ] || die setup-required /journal\ setup
[ "$provider_status" = current ] || die repair-required /journal\ repair
printf '%s\n' "$provider_path"
