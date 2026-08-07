#!/bin/sh
# spine-parse.sh <file> -- parse the file's declaration block / spine-index per the frozen
# grammar (pack plan Appendix A): the block is the FIRST HTML comment in the file, opening
# line exactly `<!-- spine-doc v<integer>` (or `<!-- spine-index v<integer>`), followed by
# `key: value` lines (value = raw text to end-of-line; no quoting/escaping -- `#` is data),
# closed by `-->` alone on a line.
# Facts only, never a guess:
#   block=none            the first HTML comment is not a spine block, or no HTML comment
#                         at all -- the file is not a spine doc (never an error)
#   doc=<type>            spine-doc | spine-index
#   version=<int>         block version (emitted only when this parser knows it)
#   <key>=<value>         known keys, in file order
#   unknown-key=<name>    key ignored, name reported -- forward-compatible, never an error
#   missing-key=<name>    a key the grammar requires for this doc/kind is absent
#   unknown-version=<n>   block version this parser does not know -- keys are not guessed at
#   malformed=<reason>    duplicate key / second block / bad line / unclosed block
# Shared parser (pack section 4.6): chiropractor consumes these facts too.
# Exit 0 on every parse outcome above; exit 2 on usage error only.
set -eu
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: spine-parse.sh <file>" >&2
  exit 2
fi

awk '
  BEGIN {
    state = "scan"
    # Known keys, Appendix A: structural + provenance/projection. One shared vocabulary --
    # which keys a given kind REQUIRES is the missing-key logic below; which keys to honour
    # is left to each consumer (facts, not verdicts).
    known = " kind entry ids budget refs exclude paused" \
            " doctrine doctrine-version origin origin-version origin-parent" \
            " built-against docs "
  }
  state == "scan" {
    if (index($0, "<!--") == 0) next
    # First HTML comment found. It is the declaration block only if it opens exactly.
    if ($0 ~ /^<!-- spine-doc v[0-9]+$/)        doc = "spine-doc"
    else if ($0 ~ /^<!-- spine-index v[0-9]+$/) doc = "spine-index"
    if (doc == "") { state = "none"; next }
    version = $0; sub(/^.* v/, "", version)
    state = "block"; next
  }
  state == "block" {
    if ($0 == "-->") { state = "closed"; next }
    if (match($0, /^[A-Za-z0-9-]+:/)) {
      key = substr($0, 1, RLENGTH - 1)
      val = substr($0, RLENGTH + 1); sub(/^ /, "", val)
      if (key in kv) { bad = "duplicate-key " key; state = "dead"; next }
      kv[key] = val; order[++nk] = key
      next
    }
    bad = "bad-line " FNR; state = "dead"; next
  }
  state == "closed" {
    if ($0 ~ /^<!-- spine-(doc|index) v[0-9]+$/) { bad = "second-block"; state = "dead" }
    next
  }
  { next }
  END {
    if (state == "scan" || state == "none") { print "block=none"; exit }
    if (state == "block") bad = "unclosed"
    print "doc=" doc
    if (version + 0 != 1) { print "unknown-version=" version; exit }
    print "version=" version
    if (bad != "") { print "malformed=" bad; exit }
    for (i = 1; i <= nk; i++) {
      k = order[i]
      if (index(known, " " k " ")) print k "=" kv[k]
      else print "unknown-key=" k
    }
    if (doc == "spine-doc") {
      if (!("kind" in kv)) print "missing-key=kind"
      else if (kv["kind"] != "workflow" && kv["kind"] != "testing") {
        # ID-store kinds define entries + citation matchers; whole-file kinds
        # (workflow, testing) are path-addressed and carry neither.
        if (!("entry" in kv)) print "missing-key=entry"
        if (!("ids" in kv))   print "missing-key=ids"
      }
    } else {
      if (!("docs" in kv)) print "missing-key=docs"
    }
  }
' "$1"
