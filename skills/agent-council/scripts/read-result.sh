#!/usr/bin/env bash
# read-result.sh <RESULT.md>
# Extract live ranked opinions from a council RESULT.md. Facts only.
# Prints:
#   n=<count>
#   claim=<text>   (one line per ranked opinion)
# ## Rescinded is not a live finding.
set -u

file="${1:-}"
if [ -z "$file" ] || [ ! -f "$file" ]; then
  printf 'n=0\n'
  exit 0
fi

claims="$(awk '
  /^## Ranked opinions[[:space:]]*$/ { inr=1; next }
  /^## / { inr=0 }
  inr && /^### [0-9]+\. / {
    line = $0
    sub(/^### [0-9]+\. \[[^]]+\] [a-z]+ — /, "", line)
    print line
  }
' "$file")"

if [ -z "$claims" ]; then
  printf 'n=0\n'
  exit 0
fi

n="$(printf '%s\n' "$claims" | grep -c .)"
printf 'n=%s\n' "$n"
printf '%s\n' "$claims" | sed 's/^/claim=/'
exit 0
