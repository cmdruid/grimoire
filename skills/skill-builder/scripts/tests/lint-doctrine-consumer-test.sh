#!/usr/bin/env bash
# lint-doctrine-consumer-test.sh — prove checks 14 and 15 by breaking them
# (doctrine: a check is not trusted until it FAILs on deliberately-broken
# input). Beyond red/green, two proofs this suite exists to carry:
#
#   * ANCHORING — a skill must not satisfy check 14 by merely quoting the
#     literal inside a fenced or indented example.
#   * NORMALIZATION — a conforming skill whose phrase literal happens to wrap
#     across a line must still PASS. This is the false-positive that a naive
#     line-based grep produces, and it is live in the real tree today.
#   * UNCONDITIONAL — check 15 must fire on a skill that declares no edge at
#     all, since that is exactly the hole check 14's edge-gating leaves open.
#
# Fixtures live in a mktemp dir; nothing touches the library's own tree.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="$(cd "$DIR/.." && pwd)/skills-lint.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-doctrine.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

lib="$TMP/lib"

write_skill() { # write_skill <skill-name> <edges-consumes> <body>
  sk="$lib/skills/$1"
  mkdir -p "$sk"
  cat > "$sk/SKILL.md" <<EOF
---
name: $1
description: "A throwaway fixture skill for doctrine-home lint proofs."
---

# $1

$3

## Edges

<!-- edges:$1 -->
- produces: — (none declared)
- handoff: — (none declared)
- consumes: $2
<!-- /edges:$1 -->
EOF
}

run_lint() { rm -rf "$lib"; mkdir -p "$lib/skills"; }
lint() { bash "$LINT" "$lib" >"$OUT" 2>"$ERR" || true; }

c14='declares a doctrine edge but carries no sanctioned agent-doctrine resolution literal'
c15='off-home doctrine literal'

# --- check 14: red — edge declared, no literal --------------------------------
run_lint
write_skill widget 'doctrine — the diagnostics playbook' 'Consult the playbook when it exists.'
lint
if grep -q "FAIL: widget: $c14" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: doctrine edge with no literal did not FAIL check 14" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- check 14: green — angle-bracket member -----------------------------------
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'The playbook lives at `<agent-doctrine>/test/workflows/diagnostics.md`.'
lint
if grep -q "$c14" "$OUT"; then
  echo "FAIL: angle-bracket literal still matched check 14 (must stay green)" >&2
  grep "$c14" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 14: green — phrase member WRAPPED across a line (normalization) ----
# This is the live false-positive shape: "the" ends one line, the rest begins
# the next. A line-based matcher fails a conforming skill here.
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'The report is written under the
agent-doctrine home, resolved per the front-door doctrine.'
lint
if grep -q "$c14" "$OUT"; then
  echo "FAIL: wrapped phrase literal matched check 14 (normalization is broken)" >&2
  grep "$c14" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 14: red — literal ONLY inside a fenced block (anchoring) -----------
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'Other skills resolve it like so:

```
the agent-doctrine home
```

but this skill just reads a fixed path.'
lint
if grep -q "FAIL: widget: $c14" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: fenced-only literal satisfied check 14 (anchoring is broken)" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- check 14: red — literal ONLY in an indented block (anchoring) ------------
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'Example only:

    <agent-doctrine>/test/workflows/diagnostics.md

but this skill just reads a fixed path.'
lint
if grep -q "FAIL: widget: $c14" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: indented-only literal satisfied check 14 (anchoring is broken)" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- check 14: negative scope — no doctrine edge, no literal ------------------
run_lint
write_skill widget 'note — a captured fact' 'This skill touches no doctrine at all.'
lint
if grep -q "$c14" "$OUT"; then
  echo "FAIL: check 14 fired on a skill with no doctrine edge (must be edge-gated)" >&2
  grep "$c14" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 15: red, and UNCONDITIONAL — off-home literal, no edge declared ----
# The whole point: check 14 could never see this skill.
run_lint
write_skill widget 'note — a captured fact' \
  'The rubric lives at `docs/audit/GUIDE.md` on a standalone host.'
lint
if grep -q "FAIL: widget: .*$c15" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: off-home literal with no edge did not FAIL check 15 (hole is open)" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- check 15: red — a .handbook/-rooted station path -------------------------
run_lint
write_skill widget 'note — a captured fact' \
  'Consult `.handbook/test/workflows/diagnostics.md` when that file exists.'
lint
if grep -q "FAIL: widget: .*$c15" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: .handbook/-rooted literal did not FAIL check 15" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- check 15: green — a burn-down-exempt skill still carries it --------------
run_lint
write_skill auditor 'note — a captured fact' \
  'The rubric lives at `docs/audit/GUIDE.md` on a standalone host.'
lint
if grep -q "$c15" "$OUT"; then
  echo "FAIL: exempt skill matched check 15 (burn-down table not honored)" >&2
  grep "$c15" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 15: green — the canonical DEFAULT path is conforming usage ---------
# Skill prose is required to name default paths literally; only OFF-home
# literals are decidable. This must never fire.
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'Doctrine lives under `<agent-doctrine>`, by default `.records/doctrine/`.'
lint
if grep -q "$c15" "$OUT"; then
  echo "FAIL: canonical default path matched check 15 (must stay green)" >&2
  grep "$c15" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

report "lint-doctrine-consumer-test"
