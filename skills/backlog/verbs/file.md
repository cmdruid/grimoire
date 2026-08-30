# `file` — create one follow-up

1. Resolve roots and run package-local `scripts/tracker-runtime-check.sh` with them. Invoke only the
   installed provider path it returns.
2. Invoke `catalog`; the named configurable `<stem>` must exist. Missing or ambiguous stem → ask and
   write nothing.
3. Obtain one nonempty, single-line text value and optional single-line evidence reference. Invoke
   `create --tracker <stem> --text <text> [--evidence <artifact-ref>]`.
4. Prefix the API's tracker-relative `wrote=` path with `.trackers`. Standalone → one scoped
   commit over that path. Inside debrief → write-only.

Done when exactly one new open row exists and the correct commit custody was used.
