#!/usr/bin/env bash
# register-route.sh <front-door> <skill-name> [<built-against>]
#   the block body (the inner lines: route + edge echo) on stdin
#
# Idempotently project a skill's route block into the always-loaded front-door
# doc's `## Skill routes (self-registered)` section, per the self-init model
# (docs/design/2026-07-18-skill-self-init-model.md §3). This is the mechanism
# behind "visibility by construction" -- the skill registers its own route where
# the harness already loads it, so it surfaces with no composer present.
#
# Ownership split (§3.4): the skill owns ONLY the bytes between its own
#   <!-- skill:<name> BEGIN built-against:<ba> -->  ...  <!-- skill:<name> END -->
# delimiters; everything outside (the section header, block ordering, any
# composer-derived seam annotations) is preserved VERBATIM.
#
# Idempotent write:
#   absent    (0 delimiters) -> append a fresh block, creating the section if needed
#   present   (1 BEGIN + 1 END) -> replace ONLY the bytes between the delimiters
#   malformed (any other count) -> report + touch NOTHING (safe-by-default;
#                                  never clobber hand-edited/broken content)
# Re-running with the same <built-against> converges byte-identically.
#
# DOCTRINE: a mutating mechanical helper (sibling of scoped-commit.sh) -- exact,
# atomic, scoped to one skill's delimited region. The verb prose decides WHAT to
# register and against WHICH front-door (never grimoire's real AGENTS.md -- §3.2).
set -euo pipefail

front="${1:?usage: register-route.sh <front-door> <skill-name> [<built-against>]}"
name="${2:?skill name required}"
ba="${3:-unknown}"
section="## Skill routes (self-registered)"
begin="<!-- skill:${name} BEGIN"          # prefix (the built-against stamp follows)
end="<!-- skill:${name} END -->"

[ -f "$front" ] || { echo "FAIL: front-door $front does not exist (create it first)" >&2; exit 2; }

body="$(cat)"
[ -n "$body" ] || { echo "FAIL: empty block body on stdin" >&2; exit 2; }

bc=$(grep -cF "$begin" "$front" || true)
ec=$(grep -cF "$end" "$front" || true)

block="$(printf '<!-- skill:%s BEGIN built-against:%s -->\n%s\n<!-- skill:%s END -->' \
          "$name" "$ba" "$body" "$name")"

tmp="$(mktemp "${TMPDIR:-/tmp}/register-route.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [ "$bc" = 1 ] && [ "$ec" = 1 ]; then
  # ---- replace: swap the begin..end span (inclusive) for the fresh block ----
  # (block passed via env, not -v: BSD awk rejects newlines in a -v value.)
  BLK="$block" awk -v bpat="$begin" -v epat="$end" '
    st==0 && index($0,bpat){ print ENVIRON["BLK"]; st=1; next }
    st==1 && index($0,epat){ st=2; next }
    st==1 { next }
    { print }
  ' "$front" > "$tmp"
  mode="replaced"
elif [ "$bc" = 0 ] && [ "$ec" = 0 ]; then
  if grep -qF "$section" "$front"; then
    # ---- append inside the existing section (before the next `## ` / EOF) ----
    BLK="$block" awk -v sec="$section" '
      { line[NR]=$0 }
      $0==sec { secline=NR }
      END{
        # find the next top-level header after the section, else EOF
        ins=NR+1
        if (secline>0){
          for(i=secline+1;i<=NR;i++){ if(line[i] ~ /^## /){ ins=i; break } }
        }
        for(i=1;i<=NR;i++){
          if(i==ins){ print ENVIRON["BLK"]; print "" }
          print line[i]
        }
        if(ins==NR+1){ print ""; print ENVIRON["BLK"] }
      }
    ' "$front" > "$tmp"
  else
    # ---- section absent: append header + block at EOF -----------------------
    cp "$front" "$tmp"
    printf '\n%s\n\n%s\n' "$section" "$block" >> "$tmp"
  fi
  mode="appended"
else
  echo "FAIL: $name block in $front is malformed (BEGIN=$bc, END=$ec); leaving file untouched" >&2
  echo "  repair the delimiters by hand, then re-run (safe-by-default: never clobbered)" >&2
  exit 3
fi

cat "$tmp" > "$front"
echo "front-door=$front skill=$name built-against=$ba result=$mode"
