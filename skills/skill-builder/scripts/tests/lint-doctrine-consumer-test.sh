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

c14='declares a doctrine edge but carries no sanctioned doctrine-home resolution literal'
c15='off-home doctrine literal'
c15b='retired doctrine path'
c16='retired project-home surface'

write_front_door() { # write_front_door <declaration-line>  (empty = no declaration)
  {
    echo '# fixture front door'
    echo
    if [ -n "$1" ]; then echo "$1"; fi
  } > "$lib/AGENTS.md"
}

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
  'The playbook lives at `.spaces/widget/doctrine/core/POLICY.md`.'
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
  'The report is written under `.spaces/widget/
doctrine`, the fixed owner-local path.'
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
the agent-workspace home
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

    .spaces/widget/doctrine/core/POLICY.md

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
  'Follow the lane at `.handbook/build/workflows/feature.md` when it exists.'
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

# --- check 15: red — the retired Auditor-specific doctrine home ---------------
run_lint
write_skill widget 'note — a captured fact' \
  'Read the rubric at `docs/audit/GUIDE.md`.'
lint
if grep -q "FAIL: widget: .*$c15" "$OUT"; then
  pass=$((pass + 1))
else
  echo "FAIL: retired docs/audit literal did not FAIL check 15" >&2
  cat "$OUT" >&2
  fail=$((fail + 1))
fi

# --- check 15: the CANONICAL default path is still conforming usage -----------
# Unchanged rule, owner-first default. The widget doctrine kind defaults under `.spaces/widget/`,
# and prose is required to name defaults literally -- so this must never fire.
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'Doctrine lives under `.spaces/widget/doctrine`, by default `.spaces/widget/doctrine/`.'
lint
if grep -q "$c15" "$OUT"; then
  echo "FAIL: canonical default path matched check 15 (must stay green)" >&2
  grep "$c15" "$OUT" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

# --- check 15: FAIL — `.records/doctrine/` is newly decidable ------------------
# This literal used to be excluded as "a home's canonical default". Once doctrine
# resolves through .spaces/widget/doctrine it is nobody's default, so it
# becomes decidable -- the strongest guard the retirement buys. It shipped WARN
# while the consumers were being flipped and is now FAIL.
# RED-PROOF: the fixture carrying it must FAIL.
run_lint
write_skill widget 'note — a captured fact' \
  'The rubric sits at `.records/doctrine/test/workflows/audit/GUIDE.md`.'
lint
expect "check 15 FAILs on the stale doctrine default" "FAIL: widget: " "$OUT"
expect "check 15 names the stale default" "$c15b" "$OUT"

# green control: remove the literal -> silent.
run_lint
write_skill widget 'note — a captured fact' \
  'The rubric sits at `.spaces/widget/doctrine/test/workflows/audit/GUIDE.md`.'
lint
expect_absent "check 15 is silent once the stale default is gone" "$c15b" "$OUT"

# --- check 14: green — the NEW literal family satisfies it ---------------------
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'The playbook lives at `.spaces/widget/doctrine/core/POLICY.md`.'
lint
expect_absent "check 14 accepts the agent-workspace angle-bracket member" "$c14" "$OUT"

# --- check 14: NARROWED — the retired family no longer satisfies it -----------
# RED-PROOF for the narrowing. This exact fixture PASSED check 14 transitionally,
# while the consumers were being flipped. It must not any more: otherwise a skill
# could satisfy check 14 with the very literal check 16 bans.
run_lint
write_skill widget 'doctrine — the diagnostics playbook' \
  'The playbook lives at `<agent-doctrine>/test/workflows/diagnostics.md`.'
lint
expect "check 14 rejects the retired angle-bracket member" "FAIL: widget: $c14" "$OUT"
expect "…and check 16 independently FAILs the same fixture" "$c16" "$OUT"

# --- check 16a: FAIL — the retired literal anywhere under a skill -------------
# THE RETIREMENT PROOF. It shipped WARN while the twelve carriers were flipped and
# is now promoted, so a reintroduction is a hard gate failure rather than noise.
# RED-PROOF: reintroduce the retired literal into a fixture skill -> lint FAILs.
# Note this fixture declares NO doctrine edge: check 16 is unconditional in
# scope, so unlike check 14 it still sees the skill.
run_lint
write_skill widget 'note — a captured fact' \
  'Resolve `agent-doctrine:` from the front door before reading the playbook.'
lint
expect "check 16 FAILs on the retired literal in a .md" \
  "FAIL: skills/widget/SKILL.md: $c16" "$OUT"

# green control: no retired literal -> silent.
run_lint
write_skill widget 'note — a captured fact' \
  'Resolve `.spaces/widget/doctrine` before reading the playbook.'
lint
expect_absent "check 16 is silent on a fixed-path skill" "$c16" "$OUT"

run_lint
write_skill widget 'note — a captured fact' \
  'Resolve `agent-templates:` from the front door, else `.records/templates`.'
lint
expect "check 16 FAILs on the retired templates literal" "$c16" "$OUT"

run_lint
write_skill widget 'note — a captured fact' \
  'Resolve `.spaces/widget/templates` before copying a lock-in.'
lint
expect_absent "check 16 is silent on a fixed templates path" "$c16" "$OUT"

# --- check 16a: it reads .sh, and it counts COMMENTS --------------------------
# The two journal carriers are comment-only occurrences inside a shell script.
# A textual absence guard cannot tell a comment from code, and must not try: if
# it skipped them the retirement could never be proven complete.
run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal in the prose here.'
mkdir -p "$lib/skills/widget/scripts"
printf '#!/bin/sh\n# The agent-doctrine home defaults to .records/doctrine\nexit 0\n' \
  > "$lib/skills/widget/scripts/tool.sh"
lint
expect "check 16 reads .sh files" "FAIL: skills/widget/scripts/tool.sh: $c16" "$OUT"

# --- check 16: no live skill or colocated-bundle exemption -------------------
run_lint
write_skill skill-builder 'note — a captured fact' \
  'This doctrine documents `agent-doctrine` in order to ban it elsewhere.'
lint
expect "check 16 gates skill-builder prose" "$c16" "$OUT"

run_lint
write_skill bundle-owner 'note — a captured fact' \
  'This skill still names `agent-doctrine` beside a pure bundle.'
printf '# pure bundle\n' > "$lib/skills/bundle-owner/PACK.md"
lint
expect "check 16 gates colocated-bundle prose" "$c16" "$OUT"

# --- check 16: every retired front-door declaration is forbidden --------------
run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal here.'
write_front_door 'agent-workspace: .'
lint
expect 'check 16 FAILs a dot-valued workspace declaration' \
  "FAIL: AGENTS.md: $c16" "$OUT"

# Alternate and default-valued declarations fail identically; none is a selector.
run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal here.'
write_front_door 'agent-workspace: dev'
lint
expect "check 16 rejects an alternate workspace declaration" "$c16" "$OUT"

run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal here.'
write_front_door 'agent-workspace: .dev'
lint
expect "check 16 rejects a dot-prefixed workspace declaration" "$c16" "$OUT"

# The former default restatement is also invalid configuration.
run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal here.'
write_front_door 'agent-workspace: .spaces'
lint
expect "check 16 fails a default-valued declaration" "FAIL: AGENTS.md: $c16" "$OUT"

# Root-selection flags are forbidden in live shell as well.
run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal here.'
mkdir -p "$lib/skills/widget/scripts"
printf '%s\n' '#!/bin/sh' 'tool --records-root custom' >"$lib/skills/widget/scripts/tool.sh"
lint
expect "check 16 rejects a records selector" "FAIL: skills/widget/scripts/tool.sh: $c16" "$OUT"

# Journal's migration exception is line-local and records-declaration-only. It
# must not hide a workspace or tracker selector elsewhere in the same file.
run_lint
write_skill journal 'record — migrated records' 'Move one dedicated records directory.'
mkdir -p "$lib/skills/journal/scripts"
printf '%s\n' '#!/bin/sh' \
  "awk '/^(agent-records|records-root):[[:space:]]*/ { print }' input; tool --workspace-root alternate # lint: allow retired-records-declaration" \
  >"$lib/skills/journal/scripts/migrate-records-root.sh"
lint
expect "check 16 still gates non-records selectors in Journal migration" \
  "FAIL: skills/journal/scripts/migrate-records-root.sh: $c16" "$OUT"

# The marked declaration parser itself remains the one bounded exception.
run_lint
write_skill journal 'record — migrated records' 'Move one dedicated records directory.'
mkdir -p "$lib/skills/journal/scripts"
printf '%s\n' '#!/bin/sh' \
  "awk '/^(agent-records|records-root):[[:space:]]*/ { print }' input # lint: allow retired-records-declaration" \
  >"$lib/skills/journal/scripts/migrate-records-root.sh"
lint
expect_absent "check 16 permits only the marked records-declaration parser" "$c16" "$OUT"

# --- check 16b/c: negative scope — no declaration at all ----------------------
# The library itself is patient-zero: it never declares front-door variables in
# its own door, so neither arm may fire when nothing is declared.
run_lint
write_skill widget 'note — a captured fact' 'Nothing doctrinal here.'
write_front_door ''
lint
expect_absent "check 16 silent with no declaration" "$c16" "$OUT"

report "lint-doctrine-consumer-test"
