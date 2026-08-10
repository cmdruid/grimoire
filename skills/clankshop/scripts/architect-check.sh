#!/usr/bin/env bash
# architect-check.sh <design-dir> [repo-root]
#
# Read-only fact-computing validator for a project's design/ seed (see
# ../docs/DOCTRINE.md). Emits clean `key=value` facts -- no verdicts, no
# spaces in any value -- for the /clankshop design health verb (verbs/design/health.md) to
# judge. This script catches STRUCTURAL rot only (missing spine, missing
# contract, stale/dangling pointers, placeholder acceptance, MAP gaps); it
# cannot judge whether a spec that passes is actually SUFFICIENT to rebuild
# from -- that is the fresh-agent read-test, not a thing a script can check.
#
# bash-3.2 safe (macOS default); read-only, never mutates.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: architect-check.sh <design-dir> [repo-root]

  <design-dir>   a design/ directory (spine root files + src/<system>.md)
  <repo-root>    root for resolving src/...:NN pointers (default: <design-dir>/..)

Emits key=value facts:
  spine_complete=true|false          spine_missing=<csv, only when false>
  contract:<sys>=true|false          refarch:<sys>=true|false
  baseline_adr:<sys>=<none|NNNN>     baseline_date:<sys>=<none|date>
  acceptance_placeholder:<sys>=true  (only when still a placeholder)
  drift:<sys>=<src/...:NN>           (only when the pointer fails to resolve)
  map_orphan=<sys>                   map_dangling=<name>

Exit 1 iff spine_complete=false or any contract:<sys>=false; else 0.
Remaining facts are advisory -- they don't affect the exit code.
EOF
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || { usage; exit 2; }

DESIGN_DIR="$1"
REPO_ROOT="${2:-$1/..}"

[ -d "$DESIGN_DIR" ] || { echo "architect-check.sh: no such directory: $DESIGN_DIR" >&2; exit 1; }

fail=0

# trim <str> -- strip leading/trailing whitespace.
trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# --- spine: VISION/PHILOSOPHY/GLOSSARY/MAP.md must all exist --------------
missing=""
for f in VISION PHILOSOPHY GLOSSARY MAP; do
  [ -f "$DESIGN_DIR/$f.md" ] || missing="${missing:+$missing,}$f.md"
done
if [ -z "$missing" ]; then
  echo "spine_complete=true"
else
  echo "spine_complete=false"
  echo "spine_missing=$missing"
  fail=1
fi

# --- per-system specs (design/src/<system>.md) -----------------------------
systems=" "   # space-padded list of system basenames seen, for MAP parity

if [ -d "$DESIGN_DIR/src" ]; then
  for spec in "$DESIGN_DIR"/src/*.md; do
    [ -e "$spec" ] || continue
    sys="$(basename "$spec" .md)"
    systems="$systems$sys "

    # Frontmatter (distilled_through_adr/_commit/_date) -- a system-spec
    # starts with a `---` block, NOT an H1 (Task 2 note); only parse it as
    # frontmatter when line 1 is literally `---`, else the keys are absent.
    adr=""; date=""
    if [ "$(head -1 "$spec")" = "---" ]; then
      fm="$(sed -n '2,/^---$/p' "$spec")"
      adr="$(printf '%s\n' "$fm" | grep '^distilled_through_adr:' | head -1 | sed -E 's/^distilled_through_adr:[[:space:]]*//')"
      date="$(printf '%s\n' "$fm" | grep '^distilled_through_date:' | head -1 | sed -E 's/^distilled_through_date:[[:space:]]*//')"
    fi
    adr="$(trim "$adr")"; date="$(trim "$date")"
    [ -n "$adr" ] || adr="none"
    [ -n "$date" ] || date="none"
    # Single token, no spaces (belt-and-braces even though the templates
    # already constrain these to one word).
    adr="${adr%% *}"; date="${date%% *}"
    echo "baseline_adr:$sys=$adr"
    echo "baseline_date:$sys=$date"

    # Contract / Reference-Architecture headings.
    if grep -qE '^## Contract' "$spec"; then
      echo "contract:$sys=true"
    else
      echo "contract:$sys=false"
      fail=1
    fi
    if grep -qE '^## Reference Arch' "$spec"; then
      echo "refarch:$sys=true"
    else
      echo "refarch:$sys=false"
    fi

    # Acceptance bullet still a placeholder (<...>, TBD, TODO).
    acc_line="$(grep -i 'Acceptance:' "$spec" | head -1 || true)"
    if [ -n "$acc_line" ]; then
      case "$acc_line" in
        *'<'*|*TBD*|*TODO*) echo "acceptance_placeholder:$sys=true" ;;
      esac
    fi

    # Reference-arch pointers (src/...:NN) -- drift if the path is missing
    # under <repo-root> or has fewer than NN lines.
    pointers="$(grep -oE 'src/[A-Za-z0-9_./-]+:[0-9]+' "$spec" || true)"
    if [ -n "$pointers" ]; then
      while IFS= read -r ptr; do
        [ -z "$ptr" ] && continue
        path="${ptr%%:*}"
        want="${ptr##*:}"
        target="$REPO_ROOT/$path"
        if [ ! -f "$target" ]; then
          echo "drift:$sys=$ptr"
        else
          have="$(wc -l < "$target" | tr -d ' ')"
          [ "$have" -lt "$want" ] && echo "drift:$sys=$ptr"
        fi
      done <<PTRS
$pointers
PTRS
    fi
  done
fi

# --- MAP parity: system index rows vs. actual design/src/*.md -------------
map_file="$DESIGN_DIR/MAP.md"
map_names=" "

if [ -f "$map_file" ]; then
  # Data rows only: markdown-table lines starting with '|', skipping the
  # header row and the `|---|---|` separator (the first two such lines).
  # Portable over any column naming/ordering -- only relies on the standard
  # header+separator+data table shape the MAP.md template uses.
  rows="$(grep -E '^\|' "$map_file" | tail -n +3 || true)"
  if [ -n "$rows" ]; then
    while IFS= read -r row; do
      [ -z "$row" ] && continue
      name="$(printf '%s' "$row" | awk -F'|' '{print $2}')"
      spec="$(printf '%s' "$row" | awk -F'|' '{print $3}')"
      name="$(trim "$name")"
      spec="$(trim "$(printf '%s' "$spec" | tr -d '`')")"
      [ -z "$name" ] && continue
      map_names="$map_names$name "
      if [ -n "$spec" ] && [ ! -f "$DESIGN_DIR/$spec" ]; then
        echo "map_dangling=$name"
      fi
    done <<ROWS
$rows
ROWS
  fi
fi

for sys in $systems; do
  case "$map_names" in
    *" $sys "*) ;;
    *) echo "map_orphan=$sys" ;;
  esac
done

[ "$fail" -eq 0 ] && exit 0 || exit 1
