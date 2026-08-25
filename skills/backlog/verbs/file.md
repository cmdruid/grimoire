# `file` — append one follow-up

1. Resolve roots and require the staged engine.
2. Invoke `list`; the named `<stem>` must exist. Missing or ambiguous stem → ask and write nothing.
3. Obtain one nonempty, single-line text value; add an optional repo-relative `--link` when a
   relevant artifact exists. Invoke `add --tracker <stem> --text <text> [--link <rel>]`.
4. Standalone → one scoped commit over the reported tracker path. Inside debrief → write-only.

Done when exactly one new open row exists and the correct commit custody was used.
