#!/usr/bin/env bash
# probe-seats.sh — print which council CLIs exist. Facts only; never a verdict.
# Usage: scripts/probe-seats.sh
# Prints three lines, always, in this order:
#   claude=<path-or-empty>
#   grok=<path-or-empty>
#   codex=<path-or-empty>
set -u
for name in claude grok codex; do
  path="$(command -v "$name" || true)"
  printf '%s=%s\n' "$name" "$path"
done
