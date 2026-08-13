#!/bin/sh
# seed.sh — project the template handbook (seed/) into a target project (the mechanical half
# of `clankshop setup`; judgment — the interview, the door — stays with the verb).
#
#   seed.sh <target-root> [--gate <cmd>] [--trunk <branch>]
#
# Copies seed/ to <target-root>/.handbook, fills the `<gate>`/`<trunk>` slots when given,
# and writes the one install stamp (version from PACK.md, date from the system clock).
# Refuses to overwrite an existing .handbook (safe-by-default; upgrades are a judgment-
# assisted diff, not a re-seed). Exit codes: 0 ok · 1 usage · 2 refused/failed.
set -eu

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$SKILL/seed"

usage() { echo "usage: seed.sh <target-root> [--gate <cmd>] [--trunk <branch>]" >&2; exit 1; }

[ $# -ge 1 ] || usage
root="$1"; shift
gate=""; trunk=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gate)  [ $# -ge 2 ] || usage; gate="$2";  shift 2 ;;
    --trunk) [ $# -ge 2 ] || usage; trunk="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -d "$root" ] || { echo "no such directory: $root" >&2; exit 2; }
[ -d "$SEED" ] || { echo "seed missing beside this script: $SEED" >&2; exit 2; }
hb="$root/.handbook"
[ -e "$hb" ] && { echo "refusing: $hb already exists (upgrade is a diff, not a re-seed)" >&2; exit 2; }

cp -R "$SEED" "$hb"
chmod +x "$hb/scripts/context.sh"

# Literal slot substitution (no regex — a gate command may carry any punctuation).
subst() { # subst <needle> <replacement> — applied to every .md under the new handbook
  find "$hb" -name '*.md' -type f | while IFS= read -r f; do
    NEEDLE="$1" REPL="$2" awk '{
      out = ""; line = $0
      while ((i = index(line, ENVIRON["NEEDLE"])) > 0) {
        out = out substr(line, 1, i - 1) ENVIRON["REPL"]
        line = substr(line, i + length(ENVIRON["NEEDLE"]))
      }
      print out line
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
}

[ -n "$gate" ]  && subst '<gate>'  "$gate"
[ -n "$trunk" ] && subst '<trunk>' "$trunk"

version="$(awk '/^---$/{n++; next} n==1 && /^version:/{sub(/^version:[[:space:]]*/, ""); print; exit}' "$SKILL/PACK.md")"
[ -n "$version" ] || version="unknown"
subst '<version>' "$version"
subst '<date>' "$(date +%Y-%m-%d)"

echo "seeded: $hb (clankshop v$version)"
"$hb/scripts/context.sh" --check
