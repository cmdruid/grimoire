#!/usr/bin/env bash
# Compile, validate, and publish immutable Foreman goal records.
# shellcheck disable=SC2016 # Markdown backticks and sed programs are intentionally single-quoted.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  goal-compile.sh render --root <root> --operation <owner/stem> --objective <one-line> --output <file>
  goal-compile.sh render-provisional --root <root> --operation <identity> --candidate <file> --objective <one-line> --record-path <goals/date-stem.md> --output <file>
  goal-compile.sh check --root <root> --input <goal-record>
  goal-compile.sh publish --root <root> --input <file> [--record-path <goals/date-stem.md>]
EOF
  exit 2
}
die() { echo "status=refused"; echo "reason=$1"; exit 1; }
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die sha256-tool-missing
  fi
}
valid_records_rel() {
  [ -n "$1" ] && [ "$1" != . ] || return 1
  case "$1" in /*|*//*|*/./*|./*|*/.|*/../*|../*|*/..) return 1 ;; esac
}
valid_goal_record_rel() {
  valid_records_rel "$1" && printf '%s\n' "$1" |
    grep -Eq '^goals/[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*\.md$'
}
check_safe_dir() {
  local rel="$1" cur="$root" part oldifs="$IFS" missing=no
  valid_records_rel "$rel" || die unsafe-records-root
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue
    cur="$cur/$part"
    [ "$missing" = no ] || continue
    [ ! -L "$cur" ] || { IFS="$oldifs"; die symlink-records-root; }
    if [ -e "$cur" ]; then
      [ -d "$cur" ] || { IFS="$oldifs"; die non-directory-records-root; }
    else
      missing=yes
    fi
  done
  IFS="$oldifs"
}
ensure_safe_dir() {
  local rel="$1" cur="$root" part oldifs="$IFS"
  valid_records_rel "$rel" || die unsafe-records-root
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue
    cur="$cur/$part"
    [ ! -L "$cur" ] || { IFS="$oldifs"; die symlink-records-root; }
    if [ -e "$cur" ]; then
      [ -d "$cur" ] || { IFS="$oldifs"; die non-directory-records-root; }
    else
      mkdir "$cur"
    fi
  done
  IFS="$oldifs"
}
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
    sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//'
}
fm_get() {
  awk -v key="$2" '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---" {exit}
    fm && index($0,key ":")==1 {
      v=substr($0,length(key)+2); sub(/^[ \t]*/,"",v); sub(/[ \t]*$/,"",v); print v; exit
    }
  ' "$1"
}
section_body() {
  awk -v h="## $2" '$0==h{emit=1;next} emit&&/^## /{exit} emit{print}' "$1" |
    awk 'NF{for(i=1;i<=blanks;i++)print "";blanks=0;print;next}{blanks++}'
}
fact_from() { sed -n "s/^$2=//p" "$1" | tail -n 1; }

mode="${1:-}"; [ -n "$mode" ] || usage; shift
root=""; records_root=.records; operation=""; objective=""; output=""; input=""; candidate=""; record_path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --operation) [ "$#" -ge 2 ] || usage; operation="$2"; shift 2 ;;
    --objective) [ "$#" -ge 2 ] || usage; objective="$2"; shift 2 ;;
    --output) [ "$#" -ge 2 ] || usage; output="$2"; shift 2 ;;
    --input) [ "$#" -ge 2 ] || usage; input="$2"; shift 2 ;;
    --candidate) [ "$#" -ge 2 ] || usage; candidate="$2"; shift 2 ;;
    --record-path) [ "$#" -ge 2 ] || usage; record_path="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$root" ] || usage
[ -d "$root" ] || usage
root="$(CDPATH='' cd -P "$root" && pwd)"
script_dir="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
checker="$script_dir/operation-check.sh"
template="$script_dir/../templates/goal.md"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-goal.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

run_operation_check() {
  local identity="$1" facts="$2"
  if [ -n "$candidate" ]; then
    "$checker" --root "$root" --operation "$identity" --candidate "$operation=$candidate" >"$facts"
  else
    "$checker" --root "$root" --operation "$identity" >"$facts"
  fi
}

render_goal() {
  local provisional="$1" sources source_material runbook verify recovery seen
  local source_digest title resume rendered_body marker_digest
  sources="$tmp/sources"; source_material="$tmp/source-material"; runbook="$tmp/runbook"
  verify="$tmp/verify"; recovery="$tmp/recovery"; seen="$tmp/seen"
  : >"$sources"; : >"$source_material"; : >"$runbook"; : >"$verify"; : >"$recovery"; : >"$seen"

  walk() {
    local identity="$1" stack="$2" facts path shown_path shape digest ref imported_digest root_node=no
    facts="$tmp/facts.$(printf '%s' "$identity" | tr '/' '_')"
    case "$stack" in *"|$identity|"*) die cyclic-closure ;; esac
    [ "$stack" != '|' ] || root_node=yes
    run_operation_check "$identity" "$facts" || die invalid-closure
    if [ "$provisional" = yes ] && [ "$root_node" = yes ]; then
      [ "$(fact_from "$facts" status)" = draft ] || die provisional-root-not-draft
      [ "$(fact_from "$facts" verification)" = missing ] || die provisional-root-verified
      [ "$(fact_from "$facts" source_current)" = true ] || die provisional-source-drift
    else
      [ "$(fact_from "$facts" goal_eligible)" = true ] || die ineligible-operation
    fi
    path="$(fact_from "$facts" path)"; shape="$(fact_from "$facts" shape)"; digest="$(fact_from "$facts" digest)"
    shown_path="${path#"$root"/}"
    if [ "$provisional" = yes ] && [ "$root_node" = yes ]; then
      shown_path=".agents/skilldata/${identity%%/*}/operations/${identity#*/}.md"
    fi
    if ! grep -qxF "$identity" "$seen"; then
      printf '%s\n' "$identity" >>"$seen"
      printf -- '- `%s` — `%s` — `%s`\n' "$identity" "$digest" "$shown_path" >>"$sources"
      printf 'operation=%s\ndigest=%s\n' "$identity" "$digest" >>"$source_material"
      imported_digest="$(fm_get "$path" source-digest)"
      [ -z "$imported_digest" ] || printf 'import=%s\n' "$imported_digest" >>"$source_material"
    fi
    if [ "$shape" = procedure ]; then
      {
        printf '\n### `%s`\n\nSource: `%s`\n\n' "$identity" "$shown_path"
        section_body "$path" Preconditions; printf '\n\n'
        section_body "$path" Procedure; printf '\n'
      } >>"$runbook"
      { printf '\n### `%s`\n\n' "$identity"; section_body "$path" Verification; printf '\n'; } >>"$verify"
      { printf '\n### `%s`\n\n' "$identity"; section_body "$path" Recovery; printf '\n'; } >>"$recovery"
    else
      while IFS= read -r ref; do
        [ -n "$ref" ] && walk "$ref" "$stack|$identity|"
      done <<EOF
$(section_body "$path" Steps | sed -n -E 's/^[0-9]+\. `([^`]*)`.*/\1/p')
EOF
    fi
  }

  walk "$operation" '|'
  if [ "$provisional" = yes ]; then
    marker_digest="$(sed -n '1s/^- `[^`]*` — `\([^`]*\)`.*/\1/p' "$sources")"
    printf 'Provisional root: `%s@%s`\n' "$operation" "$marker_digest" >>"$sources"
  fi
  source_digest="sha256:$(sha256_file "$source_material")"
  title="# Goal: $objective"
  resume="/foreman goal resume $record_path"
  rendered_body="$tmp/body"
  while IFS= read -r line; do
    case "$line" in
      '{{TITLE}}') printf '%s\n' "$title" ;;
      '{{OBJECTIVE}}') printf '%s\n' "$objective" ;;
      '{{SOURCES}}') cat "$sources" ;;
      'Source digest: `{{SOURCE_DIGEST}}`') printf 'Source digest: `%s`\n' "$source_digest" ;;
      '{{RUNBOOK}}') cat "$runbook" ;;
      '{{VERIFICATION}}') cat "$verify" ;;
      '{{RECOVERY}}') cat "$recovery" ;;
      'Run `{{RESUME}}` from the state owner'"'"'s current context.')
        printf 'Run `%s` from the state owner'"'"'s current context.\n' "$resume" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$template" >"$rendered_body"
  {
    printf '%s\n' '---' 'doctype: goals' 'status: draft' 'schema: foreman/goal@1' 'tags: [foreman, goal]' '---' ''
    cat "$rendered_body"
  } >"$output"
  echo "status=rendered"
  echo "record_path=$record_path"
  echo "source_digest=$source_digest"
  echo "operations=$(wc -l <"$seen" | tr -d ' ')"
  echo "provisional=$provisional"
}

case "$mode" in
  render|render-provisional)
    [ -n "$operation" ] && [ -n "$objective" ] && [ -n "$output" ] || usage
    case "$objective" in *$'\n'*|*$'\r'*) die multiline-objective ;; esac
    [ -n "$(slugify "$objective")" ] || die empty-objective-slug
    [ ! -e "$output" ] && [ ! -L "$output" ] || die output-exists
    if [ "$mode" = render-provisional ]; then
      [ -n "$candidate" ] && [ -n "$record_path" ] || usage
      [ "${operation%%/*}" = foreman ] || die foreign-provisional-root
      [ -f "$candidate" ] && [ ! -L "$candidate" ] || die bad-candidate
      valid_goal_record_rel "$record_path" || die bad-record-path
      render_goal yes
    else
      [ -z "$candidate$record_path" ] || usage
      record_path="goals/$(date +%Y-%m-%d)-$(slugify "$objective").md"
      render_goal no
    fi
    ;;
  check)
    [ -n "$input" ] && [ -z "$operation$objective$output$candidate$record_path" ] || usage
    [ -f "$input" ] && [ ! -L "$input" ] || die bad-input
    [ "$(fm_get "$input" doctype)" = goals ] && [ "$(fm_get "$input" schema)" = foreman/goal@1 ] || die bad-goal-record
    goal_status="$(fm_get "$input" status)"
    case "$goal_status" in draft|published) ;; *) die bad-goal-status ;; esac
    [ "$(grep -cFx '## Sources' "$input" || true)" -eq 1 ] || die bad-sources-section
    source_section="$tmp/source-section"
    section_body "$input" Sources >"$source_section"
    rows="$tmp/rows"
    sed -n -E 's/^- `([^`]*)` — `(sha256:[0-9a-f]{64})` — `([^`]*)`$/\1\t\2\t\3/p' "$source_section" >"$rows"
    source_rows="$(grep -c '^- `' "$source_section" || true)"
    [ "$source_rows" -gt 0 ] && [ "$(wc -l <"$rows" | tr -d ' ')" -eq "$source_rows" ] || die malformed-source-row

    marker_mentions="$(grep -cF 'Provisional root:' "$input" || true)"
    [ "$marker_mentions" -le 1 ] || die duplicate-provisional-marker
    marker=""
    if [ "$marker_mentions" -eq 1 ]; then
      marker="$(sed -n -E 's/^Provisional root: `([^`]+)@(sha256:[0-9a-f]{64})`$/\1\t\2/p' "$input")"
      [ -n "$marker" ] || die malformed-provisional-marker
      [ "$(grep -c '^Provisional root:' "$source_section" || true)" -eq 1 ] || die misplaced-provisional-marker
      marker_line="$(grep -n '^Provisional root:' "$source_section" | cut -d: -f1)"
      last_source_line="$(grep -n '^- `' "$source_section" | tail -n 1 | cut -d: -f1)"
      [ "$marker_line" -gt "$last_source_line" ] || die misplaced-provisional-marker
    fi

    source_material="$tmp/source-material"; actual_ids="$tmp/actual-ids"; expected_ids="$tmp/expected-ids"
    : >"$source_material"; : >"$actual_ids"; : >"$expected_ids"
    first_identity=""; index=0
    while IFS="$(printf '\t')" read -r row_identity row_digest row_path extra; do
      [ -n "$row_identity$row_digest$row_path" ] && [ -z "$extra" ] || die malformed-source-row
      index=$((index + 1))
      [ "$row_path" = ".agents/skilldata/${row_identity%%/*}/operations/${row_identity#*/}.md" ] || die source-path-mismatch
      facts="$tmp/check.$index"
      "$checker" --root "$root" --operation "$row_identity" >"$facts" || die invalid-closure
      [ "$(fact_from "$facts" digest)" = "$row_digest" ] || die source-drift
      [ "$(fact_from "$facts" source_current)" = true ] || die source-drift
      if [ "$index" -eq 1 ]; then first_identity="$row_identity"; fi
      if [ -n "$marker" ] && [ "$index" -eq 1 ]; then
        marker_identity="${marker%%	*}"; marker_digest="${marker#*	}"
        [ "${marker_identity%%/*}" = foreman ] || die foreign-provisional-root
        [ "$marker_identity" = "$row_identity" ] && [ "$marker_digest" = "$row_digest" ] || die provisional-marker-mismatch
        case "$(fact_from "$facts" status)" in
          draft) [ "$(fact_from "$facts" verification)" = missing ] || die provisional-root-verified ;;
          active)
            [ "$goal_status" = published ] || die provisional-marker-on-proven-goal
            [ "$(fact_from "$facts" goal_eligible)" = true ] || die ineligible-operation
            ;;
          *) die provisional-root-status ;;
        esac
      else
        [ "$(fact_from "$facts" goal_eligible)" = true ] || die ineligible-operation
      fi
      printf '%s\n' "$row_identity" >>"$actual_ids"
      printf 'operation=%s\ndigest=%s\n' "$row_identity" "$row_digest" >>"$source_material"
      imported_digest="$(fm_get "$(fact_from "$facts" path)" source-digest)"
      [ -z "$imported_digest" ] || printf 'import=%s\n' "$imported_digest" >>"$source_material"
    done <"$rows"
    [ -n "$first_identity" ] || die missing-root-source

    enumerate() {
      local identity="$1" stack="$2" facts path shape ref
      case "$stack" in *"|$identity|"*) die cyclic-closure ;; esac
      grep -qxF "$identity" "$expected_ids" && return 0
      printf '%s\n' "$identity" >>"$expected_ids"
      facts="$tmp/enumerate.$(printf '%s' "$identity" | tr '/' '_')"
      "$checker" --root "$root" --operation "$identity" >"$facts" || die invalid-closure
      path="$(fact_from "$facts" path)"; shape="$(fact_from "$facts" shape)"
      if [ "$shape" = workflow ]; then
        while IFS= read -r ref; do
          [ -n "$ref" ] && enumerate "$ref" "$stack|$identity|"
        done <<EOF
$(section_body "$path" Steps | sed -n -E 's/^[0-9]+\. `([^`]*)`.*/\1/p')
EOF
      fi
    }
    enumerate "$first_identity" '|'
    cmp -s "$expected_ids" "$actual_ids" || die closure-source-mismatch
    declared_source_digest="$(sed -n -E 's/^Source digest: `(sha256:[0-9a-f]{64})`$/\1/p' "$input")"
    [ "$(grep -c '^Source digest:' "$input" || true)" -eq 1 ] && [ -n "$declared_source_digest" ] || die malformed-source-digest
    computed_source_digest="sha256:$(sha256_file "$source_material")"
    [ "$declared_source_digest" = "$computed_source_digest" ] || die closure-digest-mismatch
    echo "status=valid"
    echo "root=$first_identity"
    echo "source_digest=$computed_source_digest"
    if [ -n "$marker" ]; then echo "provisional=true"; else echo "provisional=false"; fi
    echo "operations=$index"
    ;;
  publish)
    [ -n "$input" ] && [ -z "$operation$objective$output$candidate" ] || usage
    [ -f "$input" ] && [ ! -L "$input" ] || die bad-input
    [ "$(fm_get "$input" doctype)" = goals ] && [ "$(fm_get "$input" status)" = draft ] &&
      [ "$(fm_get "$input" schema)" = foreman/goal@1 ] || die bad-goal-record
    "$script_dir/goal-compile.sh" check --root "$root" --input "$input" >"$tmp/check-goal" || die invalid-goal
    title="$(awk '/^# Goal: /{print substr($0,9);exit}' "$input")"
    [ -n "$title" ] || die missing-goal-title
    if [ -n "$record_path" ]; then
      valid_goal_record_rel "$record_path" || die bad-record-path
      rel="$record_path"
    else
      rel="goals/$(date +%Y-%m-%d)-$(slugify "$title").md"
    fi
    dest="$root/$records_root/$rel"
    check_safe_dir "$records_root/goals"
    published="$tmp/published"
    awk 'NR==1&&$0=="---"{fm=1} fm&&/^status:/{print "status: published";next}{print}' "$input" >"$published"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      [ -f "$dest" ] && [ ! -L "$dest" ] || die goal-conflict
      if cmp -s "$published" "$dest"; then
        echo "status=preserved"; echo "path=$rel"; echo "mode=existing"; echo "writes=0"; exit 0
      fi
      die goal-conflict
    fi
    engine="$root/$records_root/records.sh"
    engine_path="goals/$(date +%Y-%m-%d)-$(slugify "$title").md"
    use_records=no
    if [ -x "$engine" ]; then
      [ -z "$record_path" ] || [ "$record_path" = "$engine_path" ] || die records-path-mismatch
      use_records=yes
    fi
    if [ "$use_records" = yes ]; then
      ensure_safe_dir "$records_root"
      body="$tmp/body"
      awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next} !fm{if(!started&&$0=="")next;started=1;print}' "$input" >"$body"
      path="$("$engine" new goals --schema foreman/goal@1 --template "$body" --title "$title" --tag foreman --tag goal)"
      [ "$path" = "$dest" ] || die staged-path-mismatch
      "$engine" touch "$rel" --status published >/dev/null
      cmp -s "$published" "$dest" || die published-projection-mismatch
      publish_mode=records
    else
      ensure_safe_dir "$records_root/goals"
      replacement="$(mktemp "${dest%/*}/.foreman-goal.XXXXXX")"
      cp "$published" "$replacement"; chmod 644 "$replacement"; mv "$replacement" "$dest"
      if [ -n "$record_path" ]; then publish_mode=exact-file; else publish_mode="file"; fi
    fi
    echo "status=published"; echo "path=$rel"; echo "mode=$publish_mode"; echo "writes=1"
    ;;
  *) usage ;;
esac
