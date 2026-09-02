#!/usr/bin/env bash
# records-layer-status.sh setup|repair|runtime --root <absolute-root>
# Read-only facts for Journal's fixed public records layer.
set -euo pipefail

die() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
fact() { printf '%s=%s\n' "$1" "$2"; }

mode="${1:-}"
[ -n "$mode" ] || die usage
shift
case "$mode" in setup|repair|runtime) ;; *) die usage ;; esac

root=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || die usage; root="$2"; shift 2 ;;
    *) die usage "$1" ;;
  esac
done
case "$root" in /*) ;; *) die unsafe-root ;; esac
[ -d "$root" ] && [ ! -L "$root" ] || die unsafe-root
root="$(CDPATH='' cd -P "$root" && pwd)"

skill="$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)"
source_provider="$skill/scripts/records.sh"
readme_status_helper="$skill/scripts/records-readme-status.sh"
readme_template="$skill/templates/records-readme-block.md"
[ -f "$source_provider" ] && [ ! -L "$source_provider" ] || die package-provider
[ -x "$readme_status_helper" ] || die package-readme-helper
[ -f "$readme_template" ] && [ ! -L "$readme_template" ] || die package-readme-template

layer="$root/.records"
provider="$layer/records.sh"
ledger="$layer/history.tsv"
readme="$layer/README.md"

git_state=none
ledger_head=unavailable
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$git_root" ]; then
  git_root="$(CDPATH='' cd -P "$git_root" && pwd)"
  [ "$git_root" = "$root" ] || die root-not-git-top-level "$git_root"
  if git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
    git_state="head"
    ledger_head=absent
    if git -C "$root" ls-tree -r --name-only HEAD -- .records/history.tsv |
      grep -qxF '.records/history.tsv'; then
      ledger_head=tracked
    fi
  else
    git_state=unborn
    ledger_head=absent
  fi
fi

layer_status=absent
provider_status=absent
ledger_status=absent
readme_status=absent
archived_witness=absent

if [ -L "$layer" ] || { [ -e "$layer" ] && [ ! -d "$layer" ]; }; then
  layer_status=unsafe
elif [ -d "$layer" ]; then
  layer_status=current

  if [ -L "$ledger" ] || { [ -e "$ledger" ] && [ ! -f "$ledger" ]; }; then
    ledger_status=unsafe
  elif [ -f "$ledger" ]; then
    if [ -r "$ledger" ]; then ledger_status=regular; else ledger_status=unsafe; fi
  fi

  if [ -L "$provider" ] || { [ -e "$provider" ] && [ ! -f "$provider" ]; }; then
    provider_status=unsafe
  elif [ -f "$provider" ]; then
    if [ ! -r "$provider" ]; then
      provider_status=unsafe
    elif [ ! -x "$provider" ]; then
      provider_status=non-executable
    elif ! cmp -s "$source_provider" "$provider"; then
      provider_status=drifted
    else
      provider_usage="$("$provider" 2>&1)" && provider_rc=0 || provider_rc=$?
      provider_status=current
      [ "$provider_rc" -eq 1 ] || provider_status=usage-incomplete
      if [ "$provider_status" = current ]; then
        [ "$(printf '%s\n' "$provider_usage" | sed -n '1p')" = \
          'usage: .records/records.sh <command> [args]' ] || provider_status=usage-incomplete
      fi
      if [ "$provider_status" = current ]; then
        for command in list grep show new touch "done" history prune-candidates check relocate; do
          printf '%s\n' "$provider_usage" |
            awk -v command="$command" '$1 == command { found = 1 } END { exit !found }' || {
              provider_status=usage-incomplete
              break
            }
        done
      fi
    fi
  fi

  if readme_facts="$("$readme_status_helper" "$readme_template" "$readme" 2>/dev/null)"; then
    readme_status="$(printf '%s\n' "$readme_facts" | sed -n 's/^readme_status=//p' | head -n 1)"
    [ -n "$readme_status" ] || readme_status=unsafe
  else
    readme_status=unsafe
  fi

  if [ "$ledger_status" = absent ]; then
    while IFS= read -r -d '' candidate; do
      if awk '
        NR == 1 { if ($0 != "---") exit 1; in_front = 1; next }
        in_front && $0 == "---" { closed = 1; exit }
        in_front && /^doctype:[[:space:]]*[^[:space:]]/ { doctype = 1 }
        in_front && /^status:[[:space:]]*archived[[:space:]]*$/ { archived = 1 }
        END { exit !(closed && doctype && archived) }
      ' "$candidate"; then
        archived_witness=present
        break
      fi
    done < <(find "$layer" -type f \
      -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md' -print0)
  fi
fi

recovery_state=uninitialized
if [ "$layer_status" = unsafe ] || [ "$ledger_status" = unsafe ] ||
  [ "$readme_status" = unsafe ] || [ "$readme_status" = malformed ]; then
  recovery_state=unsafe
elif [ "$ledger_status" = regular ]; then
  recovery_state=initialized
elif [ "$ledger_head" = tracked ]; then
  recovery_state=git-restore
elif [ "$readme_status" = current ] || [ "$readme_status" = drifted ] ||
  [ "$archived_witness" = present ]; then
  recovery_state=human-review
fi

fact mode "$mode"
fact root "$root"
fact git_state "$git_state"
fact layer_status "$layer_status"
fact ledger_status "$ledger_status"
fact ledger_head "$ledger_head"
fact provider_status "$provider_status"
fact readme_status "$readme_status"
fact archived_witness "$archived_witness"
fact recovery_state "$recovery_state"
fact provider_path "$provider"
