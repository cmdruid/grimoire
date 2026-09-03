#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error=%s\n' "$1" >&2
  exit 1
}

usage() {
  die 'usage: feedback-anchor.sh preview [--remove] | apply [--remove] --confirmed --base-sha256 <digest-or-absent>'
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    die 'sha256-unavailable'
  fi
}

HERE="$(CDPATH='' cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(CDPATH='' cd -P "$HERE/.." && pwd)"
TEMPLATE="$SKILL_DIR/templates/agents-route.md"
HEADING='## Skill routes (self-registered)'
BEGIN_PREFIX='<!-- skill:agent-feedback BEGIN built-against:'
END_MARK='<!-- skill:agent-feedback END -->'

[ -f "$TEMPLATE" ] && [ ! -L "$TEMPLATE" ] || die 'template-unavailable'
template_begin="$(head -n 1 "$TEMPLATE")"
template_end="$(tail -n 1 "$TEMPLATE")"
[ "$template_begin" = '<!-- skill:agent-feedback BEGIN built-against:__BUILT_AGAINST__ -->' ] ||
  die 'malformed-template'
[ "$template_end" = "$END_MARK" ] || die 'malformed-template'
[ "$(grep -cF '__BUILT_AGAINST__' "$TEMPLATE")" -eq 1 ] || die 'malformed-template'
[ "$(grep -cF '<!-- skill:agent-feedback BEGIN' "$TEMPLATE")" -eq 1 ] || die 'malformed-template'
[ "$(grep -cFx "$END_MARK" "$TEMPLATE")" -eq 1 ] || die 'malformed-template'

command_name="${1:-}"
[ "$#" -gt 0 ] || usage
shift
remove=no
confirmed=no
base_arg=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --remove)
      [ "$remove" = no ] || usage
      remove=yes
      shift
      ;;
    --confirmed)
      [ "$command_name" = apply ] && [ "$confirmed" = no ] || usage
      confirmed=yes
      shift
      ;;
    --base-sha256)
      [ "$command_name" = apply ] && [ -z "$base_arg" ] && [ "$#" -ge 2 ] || usage
      base_arg="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

case "$command_name" in
  preview)
    [ "$confirmed" = no ] && [ -z "$base_arg" ] || usage
    ;;
  apply)
    [ "$confirmed" = yes ] && [ -n "$base_arg" ] || usage
    case "$base_arg" in
      absent) ;;
      *[!0-9a-f]*|'') usage ;;
      *) [ "${#base_arg}" -eq 64 ] || usage ;;
    esac
    ;;
  *) usage ;;
esac

case "${HOME:-}" in /*) ;; *) die 'unsafe-home' ;; esac
[ -d "$HOME" ] || die 'unsafe-home'
HOME_PHYS="$(CDPATH='' cd -P "$HOME" 2>/dev/null && pwd -P)" || die 'unsafe-home'
case "$HOME_PHYS" in
  /) die 'unsafe-home' ;;
esac
AGENTS_DIR="$HOME_PHYS/.agents"
AGENTS_FILE="$AGENTS_DIR/AGENTS.md"

validate_paths() {
  if [ -e "$AGENTS_DIR" ] || [ -L "$AGENTS_DIR" ]; then
    [ -d "$AGENTS_DIR" ] && [ ! -L "$AGENTS_DIR" ] || die 'unsafe-agents-directory'
    [ "$(CDPATH='' cd -P "$AGENTS_DIR" && pwd)" = "$AGENTS_DIR" ] || die 'unsafe-agents-directory'
  fi
  if [ -e "$AGENTS_FILE" ] || [ -L "$AGENTS_FILE" ]; then
    [ -f "$AGENTS_FILE" ] && [ ! -L "$AGENTS_FILE" ] || die 'unsafe-agents-file'
    [ -r "$AGENTS_FILE" ] || die 'unreadable-agents-file'
  fi
}

current_identity() {
  if [ -f "$AGENTS_FILE" ]; then
    sha256_file "$AGENTS_FILE"
  else
    printf 'absent\n'
  fi
}

stamp="$(git -C "$SKILL_DIR" log -1 --format=%h -- . 2>/dev/null || true)"
if [ -z "$stamp" ]; then
  stamp="$(sed -n 's/^version:[[:space:]]*//p' "$SKILL_DIR/SKILL.md" | head -n 1 | tr -d "'\"")"
fi
[ -n "$stamp" ] || stamp='v0-2026-09-02'

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-feedback-anchor.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
BLOCK="$WORK_DIR/block"
CURRENT="$WORK_DIR/current"
CANDIDATE="$WORK_DIR/candidate"
ANALYSIS="$WORK_DIR/analysis"
sed "s/__BUILT_AGAINST__/$stamp/g" "$TEMPLATE" >"$BLOCK"
if [ -f "$AGENTS_FILE" ]; then
  cp "$AGENTS_FILE" "$CURRENT"
else
  : >"$CURRENT"
fi

validate_paths

awk -v heading="$HEADING" -v begin_prefix="$BEGIN_PREFIX" -v end_mark="$END_MARK" '
  function fence_candidate(s,    spaces,c,n,rest) {
    spaces=0
    while(spaces<3 && substr(s,spaces+1,1)==" ") spaces++
    s=substr(s,spaces+1)
    c=substr(s,1,1)
    if(c!="`" && c!="~") return 0
    n=0
    while(substr(s,n+1,1)==c) n++
    if(n<3) return 0
    candidate_char=c
    candidate_len=n
    candidate_rest=substr(s,n+1)
    return 1
  }
  BEGIN { fence=0; fence_char=""; fence_len=0; headings=0; begins=0; ends=0; invalid=0; heading_line=0; begin_line=0; end_line=0; next_h2=0 }
  {
    line=$0
    scan=line
    sub(/\r$/, "", scan)
    if(fence_candidate(scan)) {
      if(!fence) {
        if(candidate_char=="~" || index(candidate_rest,"`")==0) {
          fence=1; fence_char=candidate_char; fence_len=candidate_len; next
        }
      } else if(candidate_char==fence_char && candidate_len>=fence_len && candidate_rest ~ /^[ \t]*$/) {
        fence=0; fence_char=""; fence_len=0; next
      }
    }
    if(fence) next
    if (scan == heading) { headings++; heading_line=NR; next }
    if (index(scan, "<!-- skill:agent-feedback BEGIN") > 0) {
      if (index(scan, begin_prefix) == 1 && scan ~ / -->$/) { begins++; begin_line=NR } else invalid++
      next
    }
    if (index(scan, "<!-- skill:agent-feedback END") > 0) {
      if (scan == end_mark) { ends++; end_line=NR } else invalid++
      next
    }
    if (heading_line > 0 && next_h2 == 0 && NR > heading_line && scan ~ /^##[[:space:]]/) next_h2=NR
  }
  END {
    printf "headings=%d\nheading_line=%d\nbegins=%d\nbegin_line=%d\nends=%d\nend_line=%d\nnext_h2=%d\ninvalid=%d\n", headings, heading_line, begins, begin_line, ends, end_line, next_h2, invalid
  }
' "$CURRENT" >"$ANALYSIS"

value_of() { sed -n "s/^$1=//p" "$ANALYSIS"; }
headings="$(value_of headings)"
heading_line="$(value_of heading_line)"
begins="$(value_of begins)"
begin_line="$(value_of begin_line)"
ends="$(value_of ends)"
end_line="$(value_of end_line)"
next_h2="$(value_of next_h2)"
invalid="$(value_of invalid)"

[ "$headings" -le 1 ] || die 'duplicate-reserved-heading'
if [ "$invalid" -ne 0 ] || [ "$begins" -ne "$ends" ] || [ "$begins" -gt 1 ]; then
  die 'malformed-owned-block'
fi
if [ "$begins" -eq 1 ] && [ "$begin_line" -ge "$end_line" ]; then
  die 'malformed-owned-block'
fi
if [ "$begins" -eq 1 ]; then
  [ "$headings" -eq 1 ] && [ "$heading_line" -lt "$begin_line" ] || die 'owned-block-outside-reserved-section'
  if [ "$next_h2" -gt 0 ] && [ "$end_line" -ge "$next_h2" ]; then
    die 'owned-block-outside-reserved-section'
  fi
fi

find_competing_route() {
  awk -v heading="$HEADING" -v begin_prefix="$BEGIN_PREFIX" -v end_mark="$END_MARK" '
    function fence_candidate(s,    spaces,c,n) {
      spaces=0
      while(spaces<3 && substr(s,spaces+1,1)==" ") spaces++
      s=substr(s,spaces+1)
      c=substr(s,1,1)
      if(c!="`" && c!="~") return 0
      n=0
      while(substr(s,n+1,1)==c) n++
      if(n<3) return 0
      candidate_char=c; candidate_len=n; candidate_rest=substr(s,n+1)
      return 1
    }
    BEGIN { fence=0; section=0; owned=0 }
    {
      scan=$0
      sub(/\r$/, "", scan)
      if(fence_candidate(scan)) {
        if(!fence) {
          if(candidate_char=="~" || index(candidate_rest,"`")==0) {
            fence=1; fence_char=candidate_char; fence_len=candidate_len; next
          }
        } else if(candidate_char==fence_char && candidate_len>=fence_len && candidate_rest ~ /^[ \t]*$/) {
          fence=0; fence_char=""; fence_len=0; next
        }
      }
      if(fence) next
      if(scan==heading) { section=1; next }
      if(section && scan ~ /^##[ \t]+/) { section=0; owned=0 }
      if(!section) next
      if(index(scan,begin_prefix)==1) { owned=1; next }
      if(scan==end_mark) { owned=0; next }
      if(owned || scan !~ /^###[ \t]+\//) next
      slug=scan
      sub(/^###[ \t]+\//, "", slug)
      sub(/[ \t].*$/, "", slug)
      if(slug !~ /^[a-z0-9][a-z0-9-]*$/) next
      count=split(slug, parts, "-")
      for(i=1;i<=count;i++) {
        if(parts[i]=="feedback") { print scan; exit }
      }
    }
  ' "$CURRENT"
}

if [ "$remove" = no ]; then
  competing_route="$(find_competing_route)"
  if [ -n "$competing_route" ]; then
    printf 'reason=competing-feedback-route action=resolve-route conflict=%s\n' "$competing_route" >&2
    exit 2
  fi
fi

emit_replacement() {
  head -n "$((begin_line - 1))" "$CURRENT" >"$CANDIDATE"
  cat "$BLOCK" >>"$CANDIDATE"
  tail -n "+$((end_line + 1))" "$CURRENT" >>"$CANDIDATE"
}

emit_in_section() {
  if [ "$next_h2" -gt 0 ]; then
    head -n "$((next_h2 - 1))" "$CURRENT" >"$CANDIDATE"
    cat "$BLOCK" >>"$CANDIDATE"
    printf '\n' >>"$CANDIDATE"
    tail -n "+$next_h2" "$CURRENT" >>"$CANDIDATE"
  else
    cp "$CURRENT" "$CANDIDATE"
    [ ! -s "$CANDIDATE" ] || printf '\n' >>"$CANDIDATE"
    cat "$BLOCK" >>"$CANDIDATE"
  fi
}

if [ "$remove" = yes ]; then
  if [ "$begins" -eq 0 ]; then
    cp "$CURRENT" "$CANDIDATE"
  else
    head -n "$((begin_line - 1))" "$CURRENT" >"$CANDIDATE"
    tail -n "+$((end_line + 1))" "$CURRENT" >>"$CANDIDATE"
  fi
elif [ "$begins" -eq 1 ]; then
  emit_replacement
elif [ "$headings" -eq 1 ]; then
  emit_in_section
else
  cp "$CURRENT" "$CANDIDATE"
  if [ -s "$CANDIDATE" ]; then
    printf '\n\n' >>"$CANDIDATE"
  fi
  printf '%s\n\n' "$HEADING" >>"$CANDIDATE"
  cat "$BLOCK" >>"$CANDIDATE"
fi

base_now="$(current_identity)"
if cmp -s "$CURRENT" "$CANDIDATE"; then
  status=noop
else
  status=change
fi

if [ "$command_name" = preview ]; then
  printf 'status=%s\n' "$status"
  printf 'base-sha256=%s\n' "$base_now"
  if [ "$status" = change ]; then
    diff -u --label 'AGENTS.md:current' --label 'AGENTS.md:proposed' "$CURRENT" "$CANDIDATE" || true
  fi
  exit 0
fi

validate_paths
[ "$(current_identity)" = "$base_arg" ] || die 'base-changed'
if [ "$status" = noop ]; then
  printf 'status=noop\n'
  exit 0
fi

if [ ! -d "$AGENTS_DIR" ]; then
  mkdir -m 700 "$AGENTS_DIR" || die 'cannot-create-agents-directory'
fi
validate_paths
[ "$(current_identity)" = "$base_arg" ] || die 'base-changed'
DEST_TMP="$(mktemp "$AGENTS_DIR/.AGENTS.md.agent-feedback.XXXXXX")"
chmod 600 "$DEST_TMP"
cp "$CANDIDATE" "$DEST_TMP"
chmod 600 "$DEST_TMP"
[ "$(current_identity)" = "$base_arg" ] || {
  rm -f "$DEST_TMP"
  die 'base-changed'
}
mv "$DEST_TMP" "$AGENTS_FILE"
chmod 600 "$AGENTS_FILE"
if [ "$remove" = yes ]; then
  printf 'removed=AGENTS.md\n'
else
  printf 'wrote=AGENTS.md\n'
fi
