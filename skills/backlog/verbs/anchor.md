# `anchor [--debrief|--remove]` — manage the project debrief route

Manage one Backlog-owned route block in repository-root `AGENTS.md`. The route asks the custodial
main agent to run one bounded debrief after substantive work only when unresolved project-owned
follow-ups remain. It also points to the local tracker guide.

1. Resolve `<root>` as the exact Git top level that owns `.trackers/`. For standalone custody, run
   `git status --porcelain=v1 -- AGENTS.md` from `<root>` before preview; any output stops with
   `reason=commit-custody-required detail=AGENTS.md` so the anchor cannot commit pre-existing
   front-door work. Inside an announced configuration sweep, proceed only when `AGENTS.md` is
   already an approved destination and return the complete resulting diff to that sweep's custody.
2. For install or refresh, run `scripts/trackers-anchor.sh preview --root <root>`. It requires an
   attached branch, current initialized tracker@2 layer, exact executable provider, current managed
   README block, and safe front door. Removal runs the same preview with `--remove` and deliberately
   skips tracker health so a stale route can always be withdrawn. Every preview reports `action`,
   `status`, `path`, `base-sha256`, `candidate-sha256`, and the complete unified diff when changed.
3. Inspect prose outside the owned block for another behavioral route for project follow-ups. Quote
   any competing instruction and require an explicit human cutover decision. `--debrief` isn't
   authorization for that semantic decision and must refuse instead of overriding it. Structural
   marker ambiguity always refuses without a choice.
4. Bare anchor shows the complete candidate before asking. With no block, offer install or cancel.
   With a block and healthy trackers, show both refresh and removal candidates before offering
   refresh, remove, or cancel. With an unhealthy tracker layer, offer only the valid removal
   candidate. `--debrief` selects canonical install or refresh; `--remove` selects removal. Flags
   skip the choice, not preview, identity, concurrency, or semantic-competition gates. Exact legacy
   `## Project trackers` package output migrates within a confirmed install candidate; customized
   prose remains byte-identical.
5. Apply exactly the displayed candidate with
   `scripts/trackers-anchor.sh apply --root <root> [--remove] --confirmed --base-sha256 <base>
   --candidate-sha256 <candidate>`. Apply repeats preflight and rendering, then revalidates both
   identities immediately before one same-directory atomic rename while preserving incumbent mode.
6. On `wrote=AGENTS.md` or `removed=AGENTS.md`, resolve commit custody using Backlog's shared branch
   rules and make one path-scoped commit over `AGENTS.md` with an install, refresh, or removal subject.
   Never stage another path. Inside an announced configuration sweep, return `AGENTS.md` to that
   sweep's custody instead. A no-op makes no commit. Commit failure leaves the front-door change
   separate and never affects tracker-layer state.

When first-time setup delegates a consented route operation here, it does so only after the tracker transaction
has committed or returned its complete path set. Run this same preview/apply and
front-door custody procedure without folding `.trackers` paths into the anchor commit. Anchor
refusal or commit failure is a separate reported outcome and cannot roll back successful setup.

## Done when

The displayed digest-bound candidate was applied or was a no-op; install, refresh, exact legacy
migration, and removal changed only Backlog's managed span; all surrounding bytes and tracker state
survived; and standalone custody produced one commit containing only `AGENTS.md`.
