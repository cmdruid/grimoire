# `anchor` — opt into global post-work routing

Use for `/agent-feedback anchor` and `/agent-feedback anchor --remove`. This verb alone may inspect
or mutate `~/.agents/AGENTS.md`; it never reads or changes the feedback TSV.

First explain that the route works only in harnesses that always load `~/.agents/AGENTS.md`. A missing
or inapplicable route never impairs explicit capture.

## Install or update

1. Run `scripts/feedback-anchor.sh preview` and retain its `base-sha256` value.
2. Inspect the complete diff. Also scan prose outside the owned block for a competing route for
   feedback.
   If one exists, quote it and ask the human to approve the cutover; do not apply while unresolved.
3. Describe the proposed global change and ask for explicit confirmation.
4. Only after confirmation, run
   `scripts/feedback-anchor.sh apply --confirmed --base-sha256 <preview-value>`.
5. Report the helper's result. A stale preview, unsafe path, malformed block, or changed file is a
   refusal; do not repair or overwrite it automatically.

The route is advisory and cold-start readable. It captures at most once after qualifying work, stays
silent for ordinary success, and suppresses automatic feedback about `agent-feedback` itself.

## Remove

Preview with `scripts/feedback-anchor.sh preview --remove`, show the complete diff, ask for explicit
confirmation, then apply that exact base with
`scripts/feedback-anchor.sh apply --remove --confirmed --base-sha256 <preview-value>`.
Removal deletes only this package's well-formed owned block and preserves every surrounding byte. It
never deletes feedback data or touches predecessor files or markers.

## Done when

Preview preceded mutation, confirmation covered the exact base digest, and the helper returned
`wrote=AGENTS.md`, `removed=AGENTS.md`, or `status=noop`.
