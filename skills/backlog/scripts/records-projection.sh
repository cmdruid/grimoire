#!/usr/bin/env bash
# records-projection.sh <root> <doctrine-dir> [gate=<value>] [trunk=<value>]
#
# Project the doctrine's canonical record schema (rules/RECORDS.md) into the
# deployed handbook: `<root>/.handbook/rules/RECORDS.md`, stamped
# `built-against: clankshop-doctrine@<doctrine-version>` (the declaration's
# `doctrine-version:` key is the input). THE AUTHORITY CHAIN (pack rule): the
# doctrine states the schema once; backlog executes it; this script writes the
# deployed projection -- backlog is the SOLE schema-facing writer, and every
# other writer (the pack onramps included) routes its RECORDS.md step through
# this script. Drift between the stamp and the doctrine version is a clankshop
# check fact.
#
# The doctrine-side `doctrine:`/`doctrine-version:` keys are dropped from the
# deployed declaration (they describe the source, not the projection); `<gate>`
# and `<trunk>` parameter slots are filled when values are given. RECORDS is
# complete as seeded -- formats are not project-variable -- so the projection
# is a deterministic rewrite, safe to re-run (it overwrites in place).
set -euo pipefail

root="${1:?usage: records-projection.sh <root> <doctrine-dir> [gate=<v>] [trunk=<v>]}"
doc="${2:?doctrine dir required}"
shift 2
gate=""; trunk=""
for a in "$@"; do
  case "$a" in
    gate=*)  gate="${a#gate=}" ;;
    trunk=*) trunk="${a#trunk=}" ;;
    *) echo "FAIL: unknown arg $a" >&2; exit 2 ;;
  esac
done

src="$doc/rules/RECORDS.md"
[ -f "$src" ] || { echo "FAIL: no doctrine RECORDS at $src" >&2; exit 2; }
dv="$(awk '/^doctrine-version: /{print $2; exit}' "$src")"
[ -n "$dv" ] || { echo "FAIL: doctrine RECORDS declares no doctrine-version" >&2; exit 2; }

mkdir -p "$root/.handbook/rules"
awk -v dv="$dv" -v gate="$gate" -v trunk="$trunk" '
  /^<!-- spine-doc v[0-9]+$/ { decl = 1 }
  decl && /^doctrine(-version)?: / { next }
  decl && /^-->$/ { decl = 0; print "built-against: clankshop-doctrine@" dv; print; next }
  {
    if (gate != "")  while ((p = index($0, "<gate>")) > 0)  $0 = substr($0, 1, p - 1) gate substr($0, p + 6)
    if (trunk != "") while ((p = index($0, "<trunk>")) > 0) $0 = substr($0, 1, p - 1) trunk substr($0, p + 7)
    print
  }
' "$src" > "$root/.handbook/rules/RECORDS.md"

echo "written=.handbook/rules/RECORDS.md stamp=clankshop-doctrine@$dv"
