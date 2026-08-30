#!/usr/bin/env bash
# migrate-records-root.sh preview|apply --root <root> [--source <repo-relative>] [--confirmed]
#
# One narrow brownfield move: a clean, fully tracked, dedicated records root to
# fixed .records. Git is the recovery surface; this script creates no manifest.
set -euo pipefail

die() { echo "migrate-records-root.sh: $*" >&2; exit 2; }
refuse() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
usage() {
  echo "usage: migrate-records-root.sh preview|apply --root <root> [--source <repo-relative>] [--confirmed]" >&2
  exit 2
}

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in .|/*|*'
'*) return 1 ;; esac
  case "/$1/" in */../*|*/./*|*//*) return 1 ;; esac
}

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
[ -n "$root" ] || usage
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

declarations=()
declaration_files=()
for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
  [ -f "$fd" ] || continue
  [ ! -L "$fd" ] || refuse symlink-front-door "${fd#"$root"/}"
  while IFS=$'\t' read -r line_no value; do
    [ -n "$line_no" ] || continue
    valid_rel "$value" || refuse invalid-records-declaration "${fd#"$root"/}:$line_no"
    declarations+=("$value")
    declaration_files+=("$fd")
  done < <(awk '
    /^(agent-records|records-root):[[:space:]]*/ {
      value = $0; sub(/^[^:]+:[[:space:]]*/, "", value); sub(/[[:space:]]*$/, "", value)
      printf "%d\t%s\n", NR, value
    }
  ' "$fd")
done

declared=""
for value in ${declarations[@]+"${declarations[@]}"}; do
  if [ -z "$declared" ]; then declared="$value"
  elif [ "$declared" != "$value" ]; then refuse conflicting-records-declarations "$declared,$value"
  fi
done

if [ -n "$source_arg" ]; then
  valid_rel "$source_arg" || refuse invalid-source "$source_arg"
  source="$source_arg"
  [ -z "$declared" ] || [ "$declared" = "$source" ] || refuse source-declaration-mismatch "$declared"
else
  [ -n "$declared" ] || refuse source-required
  source="$declared"
fi
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

  ignored="$(git -C "$root" ls-files --others --ignored --exclude-standard -- "$source" || true)"
  if [ -n "$ignored" ]; then
    while IFS= read -r ignored_path; do [ -z "$ignored_path" ] || echo "foreign=$ignored_path" >&2; done <<<"$ignored"
    refuse ignored-source-entry
  fi

  tracked=(); foreign=()
  while IFS= read -r -d '' rel; do
    tracked+=("$rel")
    case "$rel" in *$'\n'*) foreign+=("$rel"); continue ;; esac
    path="$root/$rel"
    [ -f "$path" ] && [ ! -L "$path" ] || { foreign+=("$rel"); continue; }
    inside="${rel#"$source"/}"
    case "$inside" in
      history.tsv|README.md|records.sh) continue ;;
    esac
    base="${inside##*/}"
    if is_record_name "$base" && has_doctype "$path"; then continue; fi
    foreign+=("$rel")
  done < <(git -C "$root" ls-files -z -- "$source")
  [ "${#tracked[@]}" -gt 0 ] || refuse source-has-no-tracked-files "$source"
  if [ "${#foreign[@]}" -gt 0 ]; then
    for foreign_path in "${foreign[@]}"; do echo "foreign=$foreign_path" >&2; done
    refuse mixed-source
  fi
}

preflight
echo "mode=$mode"
echo "source=$source"
echo "destination=.records"
for tracked_path in "${tracked[@]}"; do echo "path=$tracked_path"; done
echo "paths=${#tracked[@]}"
[ "$mode" = apply ] || { echo "ready=yes"; exit 0; }

# Apply repeats the complete read-only gate immediately before the first write.
preflight
migration_started=yes
git -C "$root" mv -- "$source" .records

changed_fronts=()
seen_fronts=" "
for fd in ${declaration_files[@]+"${declaration_files[@]}"}; do
  case "$seen_fronts" in *" $fd "*) continue ;; esac
  seen_fronts="$seen_fronts$fd "
  parent="${fd%/*}"
  candidate="$(mktemp "$parent/.journal-migrate-front.XXXXXX")"
  tmp_files+=("$candidate")
  final_nl=no
  if [ -s "$fd" ] && [ "$(tail -c 1 "$fd" | od -An -tuC | tr -d '[:space:]')" = 10 ]; then
    final_nl=yes
  fi
  awk -v source="$source" -v final_nl="$final_nl" '
    function emit_current(is_final) {
      if (!have || drop) return
      printf "%s", current
      if (!is_final || final_nl == "yes") printf "\n"
    }
    {
      emit_current(0)
      current = $0; have = 1; drop = 0
      if (current ~ /^(agent-records|records-root):[[:space:]]*/) {
        value = current
        sub(/^[^:]+:[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        if (value == source) drop = 1
      }
    }
    END { emit_current(1) }
  ' "$fd" >"$candidate"
  if ! cmp -s "$fd" "$candidate"; then
    mode_bits="$(stat -f '%Lp' "$fd" 2>/dev/null || stat -c '%a' "$fd")"
    chmod "$mode_bits" "$candidate"
    mv "$candidate" "$fd"
    changed_fronts+=("${fd#"$root"/}")
  fi
done

standup_out="$(mktemp "${TMPDIR:-/tmp}/journal-migrate-standup.XXXXXX")"
standup_err="$(mktemp "${TMPDIR:-/tmp}/journal-migrate-standup-err.XXXXXX")"
tmp_files+=("$standup_out" "$standup_err")
if ! "$STANDUP" setup "$root" >"$standup_out" 2>"$standup_err"; then
  cat "$standup_out"; cat "$standup_err" >&2
  die "Journal standup failed after the Git move"
fi
cat "$standup_out"
if ! "$root/.records/records.sh" check; then
  die "records check failed after the Git move"
fi

pathspecs=("$source" .records)
for front in ${changed_fronts[@]+"${changed_fronts[@]}"}; do pathspecs+=("$front"); done
while IFS= read -r wrote; do [ -z "$wrote" ] || pathspecs+=("$wrote"); done \
  < <(sed -n 's/^wrote: //p' "$standup_out")
# `git mv` stages the rename immediately. Restore only its two endpoint
# pathspecs to HEAD so the shared helper can stage and commit the complete
# change through the same explicit union as every other Journal write.
git -C "$root" reset -q HEAD -- "$source" .records
"$SCOPED" "$root" "Journal: migrate records root to .records" "${pathspecs[@]}"
if [ -f "$root/.spaces/journal/setup.intent" ]; then "$STANDUP" finalize "$root"; fi
[ -z "$(git -C "$root" status --porcelain --untracked-files=all)" ] || die "migration commit left a dirty worktree"
echo "committed=$(git -C "$root" rev-parse HEAD)"
migration_started=no
