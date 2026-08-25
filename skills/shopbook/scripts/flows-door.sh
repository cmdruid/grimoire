#!/usr/bin/env bash
# flows-door.sh check|apply --root <abs> --workspace <rel>
#
# Bundled copy of the face pointer script (golden-byte identity on the
# functional body, comments stripped). Does not open CLAUDE.md.
# Does not create AGENTS.md. Writer owns only the bytes between the delimiters.
set -euo pipefail

BEGIN='<!-- flows BEGIN -->'
END='<!-- flows END -->'

usage() {
  cat >&2 <<'EOF'
usage: flows-door.sh check|apply --root <abs> --workspace <rel>
EOF
  exit 2
}

is_abs() {
  case "$1" in /*) return 0 ;; *) return 1 ;; esac
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

root=""
ws=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      [ $# -ge 2 ] || usage; root="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || usage; ws="$2";   shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$root" ] && [ -n "$ws" ] || usage
is_abs "$root" || usage
case "$ws" in
  .|"") echo "refusing: --workspace '.' " >&2; exit 2 ;;
  /*)   echo "refusing: --workspace must be repo-relative" >&2; exit 2 ;;
esac

door="$root/AGENTS.md"
flows_dir="$root/$ws/*/flows"
pointer_line="Project procedures live under \`$ws/*/flows/\` and are not loaded until one is selected."
# Match the full backticked owner-first glob so a different workspace cannot satisfy it.
path_lit="\`$ws/*/flows/\`"

if [ -f "$door" ]; then
  door_class=agents
elif [ -f "$root/CLAUDE.md" ]; then
  door_class=claude-only
else
  door_class=absent
fi

# Classify the flows span in AGENTS.md (missing if the file is absent).
block=missing
begin_n=0
end_n=0
begin_line=0
end_line=0
if [ -f "$door" ]; then
  begin_n=$(grep -cF -- "$BEGIN" "$door" || true)
  end_n=$(grep -cF -- "$END" "$door" || true)
  if [ "$begin_n" -eq 0 ] && [ "$end_n" -eq 0 ]; then
    block=missing
  elif [ "$begin_n" -eq 1 ] && [ "$end_n" -eq 1 ]; then
    begin_line=$(grep -nF -- "$BEGIN" "$door" | head -n 1 | cut -d: -f1)
    end_line=$(grep -nF -- "$END" "$door" | head -n 1 | cut -d: -f1)
    if [ "$begin_line" -lt "$end_line" ]; then
      block=ok
    else
      block=malformed
    fi
  else
    block=malformed
  fi
fi

body=""
if [ "$block" = ok ]; then
  body=$(awk -v b="$begin_line" -v e="$end_line" 'NR>b && NR<e {print}' "$door")
fi

drift=false
case "$block" in
  missing|malformed) drift=true ;;
  ok)
    case "$body" in
      *"$path_lit"*) drift=false ;;
      *) drift=true ;;
    esac
    ;;
esac

emit_facts() {
  echo "workspace=$ws"
  echo "flows_dir=$flows_dir"
  echo "door=$door"
  echo "door_class=$door_class"
  echo "block=$block"
  echo "drift=$drift"
}

ensure_nl() {
  # Append a trailing newline if the file is non-empty and does not end in one.
  # od-check 0a: $(tail -c 1) strips a trailing newline when captured.
  [ -s "$1" ] || return 0
  local last
  last=$(tail -c 1 "$1" | od -An -tx1 | tr -d ' \n')
  [ "$last" = "0a" ] || printf '\n' >> "$1"
}

span() {
  printf '%s\n%s\n%s\n' "$BEGIN" "$pointer_line" "$END"
}

do_check() {
  emit_facts
  if [ "$door_class" != agents ]; then
    exit 1
  fi
  if [ "$block" != ok ] || [ "$drift" = true ]; then
    exit 1
  fi
  exit 0
}

do_apply() {
  emit_facts
  if [ "$door_class" != agents ]; then
    exit 0
  fi
  if [ "$block" = malformed ]; then
    echo "status=stop" >&2
    exit 0
  fi
  local tmp
  tmp=$(mktemp)
  if [ "$block" = missing ]; then
    cat "$door" > "$tmp"
    ensure_nl "$tmp"
    span >> "$tmp"
    mv "$tmp" "$door"
    echo "status=appended"
    exit 0
  fi
  # present → replace only between the delimiters (inclusive).
  awk -v b="$begin_line" -v e="$end_line" -v begin="$BEGIN" -v line="$pointer_line" -v end="$END" '
    NR == b {
      print begin
      print line
      print end
      next
    }
    NR > b && NR <= e { next }
    { print }
  ' "$door" > "$tmp"
  mv "$tmp" "$door"
  echo "status=rewritten"
  exit 0
}

case "$cmd" in
  check) do_check ;;
  apply) do_apply ;;
  *) usage ;;
esac
