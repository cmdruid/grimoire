#!/bin/sh
# seed.sh — project the template doctrine (seed/) into a target project (the mechanical half
# of `clankshop setup`; judgment — the interview, the door — stays with the verb).
#
#   seed.sh <target-root> [--workspace <rel>] [--gate <cmd>] [--trunk <branch>]
#
# Copies seed/ to <target-root>/<workspace>/doctrine, fills the `<gate>`/`<trunk>` slots when
# given, and writes the one install stamp (version from PACK.md, date from the system clock).
#
# `--workspace` takes the ALREADY-RESOLVED repo-relative agent-workspace path (default `.dev`).
# Front-door doctrine: a write script never scans AGENTS.md / CLAUDE.md — the verb resolves the
# home and passes it in.
#
# Refuses to overwrite an existing doctrine home, and equally refuses when a legacy `.handbook/`
# is present: seeding beside a live pre-relocation workshop would stand up a second doctrine
# tree, which is the exact pathology the relocation exists to remove. Upgrades are a judgment-
# assisted diff, not a re-seed. Exit codes: 0 ok · 1 usage · 2 refused/failed.
set -eu

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$SKILL/seed"

usage() {
  echo "usage: seed.sh <target-root> [--workspace <rel>] [--gate <cmd>] [--trunk <branch>]" >&2
  exit 1
}

[ $# -ge 1 ] || usage
root="$1"; shift
gate=""; trunk=""; ws=".dev"
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) [ $# -ge 2 ] || usage; ws="$2";    shift 2 ;;
    --gate)      [ $# -ge 2 ] || usage; gate="$2";  shift 2 ;;
    --trunk)     [ $# -ge 2 ] || usage; trunk="$2"; shift 2 ;;
    *) usage ;;
  esac
done

# Argument validation, not a front-door guard: check 16 owns the *declaration* guards, but a
# lint cannot protect this invocation. `.` would seed into `./doctrine`, colliding with a real
# project directory; an absolute path escapes the target root entirely.
case "$ws" in
  .|"") echo "refusing: --workspace '.' would place doctrine at ./doctrine" >&2; exit 2 ;;
  /*)   echo "refusing: --workspace must be repo-relative, got: $ws" >&2; exit 2 ;;
esac

[ -d "$root" ] || { echo "no such directory: $root" >&2; exit 2; }
[ -d "$SEED" ] || { echo "seed missing beside this script: $SEED" >&2; exit 2; }
hb="$root/$ws/doctrine"
[ -e "$hb" ] && { echo "refusing: $hb already exists (upgrade is a diff, not a re-seed)" >&2; exit 2; }
[ -e "$root/.handbook" ] && {
  echo "refusing: $root/.handbook exists — a pre-relocation workshop is live here." >&2
  echo "  Seeding now would build a second doctrine tree beside it. Move it instead:" >&2
  echo "  git mv .handbook $ws/doctrine" >&2
  exit 2
}

mkdir -p "$root/$ws"
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
[ "$ws" = ".dev" ] || echo "note: declare \`agent-workspace: $ws\` in the door — this is not the default"
"$hb/scripts/context.sh" --check
