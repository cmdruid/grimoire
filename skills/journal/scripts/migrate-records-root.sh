#!/usr/bin/env bash
# migrate-records-root.sh preview|apply --root <root> --source <repo-relative> [--confirmed]
#
# One narrow brownfield move: a clean, fully tracked, dedicated records root to
# fixed .records. Git is the recovery surface; this script creates no manifest.
set -euo pipefail

die() { echo "migrate-records-root.sh: $*" >&2; exit 2; }
refuse() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
usage() {
  echo "usage: migrate-records-root.sh preview|apply --root <root> --source <repo-relative> [--confirmed]" >&2
  exit 2
}

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in .|/*|*'
'*) return 1 ;; esac
  case "/$1/" in */../*|*/./*|*//*) return 1 ;; esac
}

literal_pathspec() { printf ':(literal)%s' "$1"; }

has_doctype() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { closed = 1; exit }
    fm && /^doctype:[[:space:]]*[^[:space:]]/ { found = 1 }
    END { if (!fm || !found || !closed) exit 1 }
  ' "$1"
}

is_record_name() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[A-Za-z0-9][A-Za-z0-9._-]*\.md$ ]]
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
case "$mode" in preview|apply) ;; *) usage ;; esac
root=""; source_arg=""; confirmed=no
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --source) [ "$#" -ge 2 ] || usage; source_arg="$2"; shift 2 ;;
    --confirmed) confirmed=yes; shift ;;
    *) usage ;;
  esac
done
[ -n "$root" ] && [ -n "$source_arg" ] || usage
[ "$mode" = apply ] || [ "$confirmed" = no ] || usage
[ "$mode" = preview ] || [ "$confirmed" = yes ] || refuse confirmation-required
[ -d "$root" ] || refuse invalid-root "$root"
root="$(CDPATH='' cd -P "$root" && pwd)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$git_root" ] || refuse git-required
git_root="$(CDPATH='' cd -P "$git_root" && pwd)"
[ "$git_root" = "$root" ] || refuse root-not-git-top-level "$git_root"
[ -n "$(git -C "$root" branch --show-current)" ] || refuse detached-head

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)"
STANDUP="$SKILL/scripts/standup.sh"
SCOPED="$SKILL/scripts/scoped-commit.sh"
[ -x "$STANDUP" ] && [ -x "$SCOPED" ] || die "Journal package helpers are unavailable"

tmp_files=()
migration_started=no
cleanup() {
  rc=$?
  trap - EXIT
  for tmp_file in ${tmp_files[@]+"${tmp_files[@]}"}; do [ -z "$tmp_file" ] || rm -f "$tmp_file"; done
  if [ "$rc" -ne 0 ] && [ "$migration_started" = yes ]; then
    echo "migration stopped after the Git move; inspect or revert this ordinary Git diff:" >&2
    git -C "$root" status --short >&2 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

valid_rel "$source_arg" || refuse invalid-source "$source_arg"
source="$source_arg"
[ "$source" != .records ] || refuse already-canonical

preflight() {
  [ -z "$(git -C "$root" status --porcelain --untracked-files=all)" ] || refuse dirty-worktree
  [ ! -e "$root/.records" ] && [ ! -L "$root/.records" ] || refuse destination-present .records

  source_abs="$root/$source"
  current="$root"
  old_ifs="$IFS"; IFS=/; read -r -a parts <<<"$source"; IFS="$old_ifs"
  for part in "${parts[@]}"; do
    current="$current/$part"
    [ ! -L "$current" ] || refuse symlink-source "${current#"$root"/}"
  done
  [ -d "$source_abs" ] || refuse source-not-directory "$source"
  [ -z "$(find "$source_abs" -type l -print -quit)" ] || refuse symlink-source "$source"

  source_pathspec="$(literal_pathspec "$source")"
  ignored="$(git -C "$root" ls-files --others --ignored --exclude-standard -- "$source_pathspec" || true)"
  if [ -n "$ignored" ]; then
    while IFS= read -r ignored_path; do [ -z "$ignored_path" ] || echo "foreign=$ignored_path" >&2; done <<<"$ignored"
    refuse ignored-source-entry
  fi

  inventory=(); foreign=(); tracked_count=0; empty_directory=no
  while IFS= read -r -d '' path; do
    inside="${path#"$source_abs"/}"
    rel="$source/$inside"
    inventory+=("$rel")
    case "$rel" in *$'\n'*) foreign+=("$rel"); continue ;; esac
    if [ -d "$path" ]; then
      if [ -z "$(find "$path" -mindepth 1 -print -quit)" ]; then
        foreign+=("$rel")
        empty_directory=yes
      fi
      continue
    fi
    [ -f "$path" ] && [ ! -L "$path" ] || { foreign+=("$rel"); continue; }
    if ! git -C "$root" ls-files --error-unmatch -- "$(literal_pathspec "$rel")" >/dev/null 2>&1; then
      foreign+=("$rel")
      continue
    fi
    tracked_count=$((tracked_count + 1))
    case "$inside" in
      history.tsv|README.md|records.sh) continue ;;
    esac
    base="${inside##*/}"
    if is_record_name "$base" && has_doctype "$path"; then continue; fi
    foreign+=("$rel")
  done < <(find "$source_abs" -mindepth 1 -print0)
  [ "$tracked_count" -gt 0 ] || refuse source-has-no-tracked-files "$source"
  if [ "${#foreign[@]}" -gt 0 ]; then
    for foreign_path in "${foreign[@]}"; do echo "foreign=$foreign_path" >&2; done
    [ "$empty_directory" = no ] || refuse untracked-source-directory
    refuse mixed-source
  fi
}

preflight
echo "mode=$mode"
echo "source=$source"
echo "destination=.records"
for inventory_path in "${inventory[@]}"; do echo "path=$inventory_path"; done
echo "paths=${#inventory[@]}"
[ "$mode" = apply ] || { echo "ready=yes"; exit 0; }

# Apply repeats the complete read-only gate immediately before the first write.
preflight
migration_started=yes
git -C "$root" mv -- "$source" .records

standup_out="$(mktemp "${TMPDIR:-/tmp}/journal-migrate-standup.XXXXXX")"
standup_err="$(mktemp "${TMPDIR:-/tmp}/journal-migrate-standup-err.XXXXXX")"
tmp_files+=("$standup_out" "$standup_err")
if ! "$STANDUP" setup "$root" --write-only >"$standup_out" 2>"$standup_err"; then
  cat "$standup_out"; cat "$standup_err" >&2
  die "Journal standup failed after the Git move"
fi
cat "$standup_out"
if ! "$root/.records/records.sh" check; then
  die "records check failed after the Git move"
fi

pathspecs=("$source" .records)
while IFS= read -r wrote; do [ -z "$wrote" ] || pathspecs+=("$wrote"); done \
  < <(sed -n 's/^wrote: //p' "$standup_out")
# `git mv` stages the rename immediately. Restore only its two endpoint
# pathspecs to HEAD so the shared helper can stage and commit the complete
# change through the same explicit union as every other Journal write.
git -C "$root" reset -q HEAD -- "$(literal_pathspec "$source")" "$(literal_pathspec .records)"
for pathspec_index in "${!pathspecs[@]}"; do
  pathspecs[pathspec_index]="$(literal_pathspec "${pathspecs[pathspec_index]}")"
done
"$SCOPED" "$root" "Journal: migrate records root to .records" "${pathspecs[@]}"
[ -z "$(git -C "$root" status --porcelain --untracked-files=all)" ] || die "migration commit left a dirty worktree"
echo "committed=$(git -C "$root" rev-parse HEAD)"
migration_started=no
