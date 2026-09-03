# anchor — opt into global post-skill routing

Use for `/skill-feedback anchor` and `/skill-feedback anchor --remove`. This verb alone may inspect
or mutate `~/.agents/AGENTS.md`; it never reads or changes the feedback TSV.

First explain that the route is effective only in harnesses that always load
`~/.agents/AGENTS.md`. A missing or harness-inapplicable route never impairs manual capture.

## Install or update

1. Run `scripts/feedback-anchor.sh preview` and retain its `base-sha256` value.
2. Inspect the complete diff. Also scan prose outside the owned block for a competing route that
   sends reusable-skill feedback to another command or store. If one exists, quote the competing
   route and ask the human to approve the cutover. Do not apply while that decision is unresolved.
3. Describe the proposed global routing change and ask for explicit confirmation.
4. Only after confirmation, run
   `scripts/feedback-anchor.sh apply --confirmed --base-sha256 <preview-value>`.
5. Report the helper's single result line. A stale preview, unsafe path, malformed block, or changed
   file is a refusal; do not repair or overwrite it automatically.

The route is advisory and cold-start readable. It captures at most once after a qualifying named
skill, stays silent for ordinary success, and excludes feedback about `skill-feedback` itself.

## Remove

1. Run `scripts/feedback-anchor.sh preview --remove` and inspect the complete diff.
2. Describe the removal and ask for explicit confirmation.
3. Only after confirmation, run
   `scripts/feedback-anchor.sh apply --remove --confirmed --base-sha256 <preview-value>`.

Removal deletes only the well-formed owned block. It preserves the reserved heading and every
surrounding byte, even when the heading becomes empty. It never deletes feedback data and never
touches legacy `~/.agents/FEEDBACK.md`.

## Done when

Preview was shown before any mutation, confirmation covered that exact base digest, and the helper
returned `wrote=AGENTS.md`, `removed=AGENTS.md`, or `status=noop`.
