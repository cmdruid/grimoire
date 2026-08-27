# `file` — create one follow-up

1. Resolve roots and require the installed API.
2. Invoke `catalog`; the named configurable `<stem>` must exist. Missing or ambiguous stem → ask and
   write nothing.
3. Obtain one nonempty, single-line text value and optional single-line evidence reference. Invoke
   `create --tracker <stem> --text <text> [--evidence <artifact-ref>]`.
4. Prefix the API's tracker-relative `wrote=` path with `<agent-trackers>`. Standalone → one scoped
   commit over that path. Inside debrief → write-only.

Done when exactly one new open row exists and the correct commit custody was used.
