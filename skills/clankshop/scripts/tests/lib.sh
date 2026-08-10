#!/bin/sh
# lib.sh -- shared fixture plumbing for the onramp tests (plan Task 1.8). Sourced, not
# executed. Provides the assert helpers and project_doctrine: the SCRIPTABLE CORE of the
# setup verb's projection (doctrine -> handbook copy with provenance stamps, the records
# skeleton, the door table + registration blocks from the door profile, the stewardship
# maps, the installation block last). The verb's judgment (interview, opt-outs) is
# exactly what this does NOT automate -- fixtures exercise the mechanical walk.
# shellcheck disable=SC2034  # pass/fail are consumed by the sourcing harness

pass=0; fail=0
expect() {  # <label> <needle> <haystack-file>
  if grep -qF "$2" "$3"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL: $1 -- missing: $2"
  fi
}
expect_absent() {  # <label> <needle> <haystack-file>
  if grep -qF "$2" "$3"; then
    fail=$((fail + 1)); echo "FAIL: $1 -- unexpected: $2"
  else
    pass=$((pass + 1))
  fi
}
expect_eq() {  # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL: $1 -- expected '$2' got '$3'"
  fi
}

# fill_slots <gate> <trunk>: stdin -> stdout with <gate>/<trunk> slots filled.
fill_slots() {
  awk -v gate="$1" -v trunk="$2" '
    {
      while ((p = index($0, "<gate>")) > 0)  $0 = substr($0, 1, p - 1) gate substr($0, p + 6)
      while ((p = index($0, "<trunk>")) > 0) $0 = substr($0, 1, p - 1) trunk substr($0, p + 7)
      print
    }'
}

# extract_door_body <doctrine-README> <name>: the frozen registration-block body for one
# member, from the door profile's fenced blocks (the single source every writer copies).
extract_door_body() {
  awk -v name="$2" '
    /^```markdown$/ { infence = 1; buf = ""; first = 1; keep = 0; next }
    infence && /^```$/ { infence = 0; if (keep) printf "%s", buf; next }
    infence {
      if (first) { first = 0; if (index($0, "### /" name " ") == 1) keep = 1 }
      buf = buf $0 "\n"
    }
  ' "$1"
}

# project_doctrine <root> <doctrine-dir> <skills-root> <gate> <trunk> <pack-version>
# The mechanical greenfield assembly. Installed set = dirs under <skills-root>.
project_doctrine() {
  pr_root=$1; pr_doc=$2; pr_skills=$3; pr_gate=$4; pr_trunk=$5; pr_pv=$6
  pr_dv=$(awk '/^doctrine-version: /{print $2; exit}' "$pr_doc/README.md")
  mkdir -p "$pr_root/.handbook/rules" "$pr_root/.handbook/workflows" \
           "$pr_root/.handbook/design" "$pr_root/.handbook/testing" \
           "$pr_root/.records/trackers/bugs" "$pr_root/.records/trackers/notes" \
           "$pr_root/.records/tickets" "$pr_root/.records/done"

  # --- rules: INVARIANTS/GOTCHAS/POLICY/ROUTING copied clean (doctrine keys dropped),
  #     RECORDS (stamped projection below).
  for f in INVARIANTS GOTCHAS POLICY ROUTING; do
    awk '
      /^<!-- spine-doc v[0-9]+$/ { decl = 1 }
      decl && /^doctrine(-version)?: / { next }
      decl && /^-->$/ { decl = 0 }
      { print }
    ' "$pr_doc/rules/$f.md" | fill_slots "$pr_gate" "$pr_trunk" \
      > "$pr_root/.handbook/rules/$f.md"
  done
  # RECORDS is the records instrument's stamped projection -- the ONLY writer is
  # backlog's records-projection.sh; setup routes its RECORDS step through it.
  sh "$CLANKSHOP_SCRIPTS/../../backlog/scripts/records-projection.sh" \
    "$pr_root" "$pr_doc" "gate=$pr_gate" "trunk=$pr_trunk" > /dev/null

  # --- whole-file assets: lanes + testing, origin keys replace doctrine keys.
  for sub in workflows testing; do
    for f in "$pr_doc/$sub"/*.md; do
      [ -f "$f" ] || continue
      b=$(basename "$f" .md)
      awk -v o="clankshop:$sub/$b" -v dv="$pr_dv" '
        /^<!-- spine-doc v[0-9]+$/ { decl = 1 }
        decl && /^doctrine: /         { print "origin: " o; next }
        decl && /^doctrine-version: / { print "origin-version: " dv; next }
        decl && /^-->$/ { decl = 0 }
        { print }
      ' "$f" | fill_slots "$pr_gate" "$pr_trunk" > "$pr_root/.handbook/$sub/$b.md"
    done
  done

  # --- records skeleton (wire-format heads; content accrues project-side).
  printf '# Tasks\n'    > "$pr_root/.records/trackers/tasks.md"
  printf '# Issues\n'   > "$pr_root/.records/trackers/issues.md"
  printf '# Feedback\n' > "$pr_root/.records/trackers/feedback.md"
  printf '# Done log\n' > "$pr_root/.records/done/log.md"

  # --- stewardship maps: preamble lines + per-producer blocks, stamped.
  cat > "$pr_root/.handbook/README.md" <<EOF
# Handbook — stewardship map
One stewardship line per chapter: rules/ — the foreman hat; workflows/ — the
foreman hat; design/ — the architect hat; testing/ — the guardian hat;
rules/RECORDS.md — the records instrument's stamped projection.
<!-- steward:clankshop -->
chapters: rules workflows design testing
built-against: clankshop@$pr_pv
<!-- /steward:clankshop -->
EOF
  cat > "$pr_root/.records/README.md" <<EOF
# Records — stewardship map
trackers/, tickets/, done/ — the records instrument; plans/, adr/ — the planning
pipeline; other stores are created by their owning members on first use.
<!-- steward:backlog -->
stores: trackers tickets done
built-against: clankshop@$pr_pv
<!-- /steward:backlog -->
EOF

  # --- the door: tier-0 table (installed-owner rows only) + fallback + registrations.
  {
    echo "# Project front door"
    echo ""
    echo "| you're about to… | go |"
    echo "|---|---|"
    # Rows from the door profile whose FIRST token's owner is installed; the alias
    # parenthetical is kept only when the proxies are installed.
    awk '/^\| you.re about to/{on=1; getline; next} on && /^\|/{print} on && !/^\|/{exit}' \
      "$pr_doc/README.md" | while IFS= read -r row; do
      tok=$(printf '%s' "$row" | grep -oE '`/[a-z][a-z-]*' | head -1 | tr -d '`' | sed 's|^/||' || true)
      if [ -z "$tok" ]; then printf '%s\n' "$row"; continue; fi
      [ -d "$pr_skills/$tok" ] || continue
      ok=1
      for t in $(printf '%s' "$row" | grep -oE '`/[a-z][a-z-]*' | tr -d '`' | sed 's|^/||' | sort -u); do
        [ -d "$pr_skills/$t" ] || ok=0
      done
      if [ "$ok" = 1 ]; then
        printf '%s\n' "$row"
      else
        cleaned=$(printf '%s' "$row" | sed 's/ (aliases: [^)]*)//')
        ok2=1
        for t in $(printf '%s' "$cleaned" | grep -oE '`/[a-z][a-z-]*' | tr -d '`' | sed 's|^/||' | sort -u); do
          [ -d "$pr_skills/$t" ] || ok2=0
        done
        [ "$ok2" = 1 ] && printf '%s\n' "$cleaned"
      fi
    done
    echo ""
    echo "> No skill runner? Follow \`.handbook/rules/ROUTING.md\` by hand."
    echo ""
    echo "## Skill routes (self-registered)"
    echo ""
    for d in "$pr_skills"/*/; do
      [ -d "$d" ] || continue
      m=$(basename "$d")
      body=$(extract_door_body "$pr_doc/README.md" "$m")
      if [ -n "$body" ]; then
        printf '<!-- skill:%s BEGIN built-against:clankshop@%s -->\n%s\n<!-- skill:%s END -->\n' \
          "$m" "$pr_pv" "$body" "$m"
      else
        # helper (or other non-profile member): its own independence-protocol block.
        printf '<!-- skill:%s BEGIN built-against:v0-fixture -->\n### /%s\nRoute: helper plumbing.\n<!-- skill:%s END -->\n' \
          "$m" "$m" "$m"
      fi
    done
  } | fill_slots "$pr_gate" "$pr_trunk" > "$pr_root/AGENTS.md"

  # --- stamp LAST (the commit point).
  sh "$CLANKSHOP_SCRIPTS/install-block.sh" write "$pr_root" 1 clankshop "$pr_pv" > /dev/null
}
