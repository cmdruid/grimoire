#!/usr/bin/env bash
# Safe writer for Architect's living drafts and completed spike records.
set -euo pipefail

die() { echo "architect-artifacts.sh: $*" >&2; exit 2; }
usage() {
  die "usage: architect-artifacts.sh draft-save --root <root> --slug <slug> --title <title> --body <file> | spike-publish --root <root> --title <title> --body <file>"
}

active_tmp=""
cleanup_tmp() {
  [ -z "$active_tmp" ] || rm -f "$active_tmp"
}
trap cleanup_tmp EXIT

valid_rel() {
  local value="$1" allow_dot="$2" part old_ifs="$IFS"
  [ -n "$value" ] || return 1
  case "$value" in /*) return 1 ;; esac
  if [ "$value" = . ]; then [ "$allow_dot" = yes ]; return; fi
  IFS=/
  for part in $value; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS="$old_ifs"; return 1; }
  done
  IFS="$old_ifs"
}

check_parents() {
  local rel="$1" cur="$root" part old_ifs="$IFS" missing=no
  valid_rel "$rel" yes || die "unsafe relative path: $rel"
  [ "$rel" = . ] && return 0
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue
    cur="$cur/$part"
    [ "$missing" = no ] || continue
    [ ! -L "$cur" ] || { IFS="$old_ifs"; die "symlinked path component: $cur"; }
    if [ -e "$cur" ]; then
      [ -d "$cur" ] || { IFS="$old_ifs"; die "path component is not a directory: $cur"; }
    else
      missing=yes
    fi
  done
  IFS="$old_ifs"
}

ensure_dir() {
  local rel="$1" cur="$root" part old_ifs="$IFS"
  [ "$rel" = . ] && return 0
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue
    cur="$cur/$part"
    [ ! -L "$cur" ] || { IFS="$old_ifs"; die "symlinked path component: $cur"; }
    if [ -e "$cur" ]; then
      [ -d "$cur" ] || { IFS="$old_ifs"; die "path component is not a directory: $cur"; }
    else
      mkdir "$cur"
    fi
  done
  IFS="$old_ifs"
}

regular_body() {
  [ -f "$body" ] && [ ! -L "$body" ] || die "body is not a regular file: $body"
  [ "$(head -n 1 "$body")" = "# $title" ] || die "body title does not match: $title"
}

exact_heading() {
  [ "$(grep -Fxc -- "$1" "$body" || true)" -eq 1 ] || die "body requires exactly one heading: $1"
}

nonempty_section() {
  awk -v heading="$1" '
    $0 == heading { inside=1; next }
    inside && /^##[[:space:]]+[^[:space:]]/ { exit }
    inside && /[^[:space:]]/ { found=1 }
    END { exit found ? 0 : 1 }
  ' "$body" || die "spike section must contain evidence: $1"
}

validate_draft_body() {
  local disposition_count disposition_lines
  regular_body
  disposition_count="$(grep -Ec '^Disposition: (active|parked|promoted)$' "$body" || true)"
  disposition_lines="$(grep -Ec '^Disposition:' "$body" || true)"
  [ "$disposition_count" -eq 1 ] && [ "$disposition_lines" -eq 1 ] \
    || die "draft requires exactly one valid Disposition"
  exact_heading '## Problem or question'
  exact_heading '## Constraints and candidate approaches'
  exact_heading '## Decisions and evidence'
  exact_heading '## Open questions and next step'
  exact_heading '## Spike notes'
  exact_heading '## Related records'
  [ "$(grep -Ec '^##[[:space:]]+[^[:space:]]' "$body" || true)" -eq 6 ] \
    || die "draft body has an unexpected H2"
}

validate_spike_body() {
  regular_body
  exact_heading '## Question and decision relevance'
  exact_heading '## Executor, baseline, and environment'
  exact_heading '## Hypothesis, success criterion, and budget'
  exact_heading '## Method, reproduction commands, and observations'
  exact_heading '## Conclusion, limitations, and remaining uncertainty'
  [ "$(grep -Ec '^##[[:space:]]+[^[:space:]]' "$body" || true)" -eq 5 ] \
    || die "spike body has an unexpected H2"
  nonempty_section '## Question and decision relevance'
  nonempty_section '## Executor, baseline, and environment'
  nonempty_section '## Hypothesis, success criterion, and budget'
  nonempty_section '## Method, reproduction commands, and observations'
  nonempty_section '## Conclusion, limitations, and remaining uncertainty'
}

fm_exact_count() {
  awk -v wanted="$2" '
    NR == 1 { if ($0 != "---") { bad=1; exit }; fm=1; next }
    fm && $0 == "---" { closed=1; exit }
    fm && $0 == wanted { count++ }
    END { if (bad || !closed) print -1; else print count+0 }
  ' "$1"
}

validate_spike_record_meta() {
  local path="$1" status="$2"
  [ "$(fm_exact_count "$path" 'doctype: spikes')" -eq 1 ] \
    && [ "$(fm_exact_count "$path" "status: $status")" -eq 1 ] \
    && [ "$(fm_exact_count "$path" 'schema: architect/spike@1')" -eq 1 ] \
    && [ "$(fm_exact_count "$path" 'tags: [spike, feasibility]')" -eq 1 ] \
    || die "spike record has invalid metadata: $path"
}

secure_temp_for() {
  local destination="$1" dir name tmp
  dir="${destination%/*}"
  name="${destination##*/}"
  [ -d "$dir" ] && [ ! -L "$dir" ] || die "unsafe temporary-file directory: $dir"
  tmp="$(mktemp "$dir/.${name}.tmp.XXXXXX")" || die "cannot create temporary file for: $destination"
  [ -f "$tmp" ] && [ ! -L "$tmp" ] || die "unsafe temporary file: $tmp"
  printf '%s\n' "$tmp"
}

commit_temp() {
  local destination="$1"
  if ! mv "$active_tmp" "$destination"; then
    cleanup_tmp
    die "cannot install completed file: $destination"
  fi
  active_tmp=""
}

write_front_matter_and_body() {
  local path="$1" status="$2"
  active_tmp="$(secure_temp_for "$path")"
  if ! {
    printf '%s\n' '---'
    printf 'doctype: spikes\n'
    printf 'status: %s\n' "$status"
    printf 'schema: architect/spike@1\n'
    printf 'tags: [spike, feasibility]\n'
    printf '%s\n\n' '---'
    cat "$body"
  } > "$active_tmp"; then
    cleanup_tmp
    die "cannot stage spike record: $path"
  fi
  commit_temp "$path"
}

replace_record_body() {
  local path="$1"
  active_tmp="$(secure_temp_for "$path")"
  if ! {
    awk '
      NR == 1 && $0 == "---" { fm=1; print; next }
      fm && $0 == "---" { print; exit }
      fm { print }
    ' "$path"
    printf '\n'
    cat "$body"
  } > "$active_tmp"; then
    cleanup_tmp
    die "cannot stage spike body: $path"
  fi
  commit_temp "$path"
}

stamp_published() {
  local path="$1"
  active_tmp="$(secure_temp_for "$path")"
  if ! awk '
      NR == 1 && $0 == "---" { fm=1; print; next }
      fm && $0 == "---" { fm=0; print; next }
      fm && /^status:/ { print "status: published"; next }
      { print }
    ' "$path" > "$active_tmp"; then
    cleanup_tmp
    die "cannot stage published status: $path"
  fi
  commit_temp "$path"
}

repo_relative() {
  case "$1" in "$root"/*) printf '%s\n' "${1#"$root"/}" ;; *) die "path escaped root: $1" ;; esac
}

mode="${1:-}"
[ -n "$mode" ] || usage
shift
root=""; workspace=.spaces; records_root=.records; slug=""; title=""; body=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --slug) [ "$#" -ge 2 ] || usage; slug="$2"; shift 2 ;;
    --title) [ "$#" -ge 2 ] || usage; title="$2"; shift 2 ;;
    --body) [ "$#" -ge 2 ] || usage; body="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -d "$root" ] || die "root is not a directory: $root"
root="$(CDPATH='' cd -P "$root" && pwd)"
records_tool="$root/.records/records.sh"
[ -n "$title" ] && [ -n "$body" ] || usage
case "$title" in *$'\n'*|*$'\r'*) die "title must be one line" ;; esac

case "$mode" in
  draft-save)
    [ -n "$slug" ] || usage
    printf '%s\n' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || die "unsafe draft slug: $slug"
    validate_draft_body
    draft_dir="$workspace/architect/drafts"
    check_parents "$draft_dir"
    ensure_dir "$draft_dir"
    destination="$root/$draft_dir/$slug.md"
    [ ! -L "$destination" ] || die "draft destination is a symlink: $destination"
    if [ -e "$destination" ]; then
      [ -f "$destination" ] || die "draft destination is not a regular file: $destination"
      [ "$(head -n 1 "$destination")" = "# $title" ] || die "draft slug belongs to a different title: $slug"
    fi
    active_tmp="$(secure_temp_for "$destination")"
    if ! cp "$body" "$active_tmp"; then
      cleanup_tmp
      die "cannot stage draft: $destination"
    fi
    commit_temp "$destination"
    printf 'path=%s\n' "$draft_dir/$slug.md"
    ;;
  spike-publish)
    [ -z "$slug" ] || usage
    validate_spike_body
    spike_dir="${records_root%/}/spikes"
    [ "$records_root" = . ] && spike_dir=spikes
    check_parents "$spike_dir"
    if [ -x "$records_tool" ] && [ ! -L "$records_tool" ]; then
      created="$("$records_tool" new spikes --schema architect/spike@1 --title "$title" --tag spike --tag feasibility)"
      [ -f "$created" ] && [ ! -L "$created" ] || die "records tool returned no regular record: $created"
      created="$(CDPATH='' cd -P "$(dirname "$created")" && pwd)/$(basename "$created")"
      expected_prefix="$root/$spike_dir/"
      case "$created" in "$expected_prefix"*) ;; *) die "records tool returned a path outside the spike store: $created" ;; esac
      validate_spike_record_meta "$created" draft
      replace_record_body "$created"
      rel_to_records="${created#"$root/.records"/}"
      "$records_tool" touch "$rel_to_records" --status published >/dev/null
      validate_spike_record_meta "$created" published
    else
      ensure_dir "$spike_dir"
      normalized="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//')"
      [ -n "$normalized" ] || die "title yields an empty slug: $title"
      base="$root/$spike_dir/$(date +%Y-%m-%d)-$normalized"
      created="$base.md"; suffix=2
      while [ -e "$created" ] || [ -L "$created" ]; do created="$base-$suffix.md"; suffix=$((suffix + 1)); done
      write_front_matter_and_body "$created" draft
      validate_spike_record_meta "$created" draft
      stamp_published "$created"
      validate_spike_record_meta "$created" published
    fi
    printf 'path=%s\n' "$(repo_relative "$created")"
    ;;
  *) usage ;;
esac
