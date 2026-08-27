# `tune <tracker>` — curate a tracker batch

Resolve `<agent-trackers>`. Require the provider's executable `tracker-api.sh` and confirm its exact
`describe` schema is `tracker@1`. Invoke the installed provider directly, then request one bounded
open page using stable consumer key `foreman/tune`. Missing provider state degrades to an equivalent
bounded batch supplied directly by the caller; do not require setup or create an adapter.

Reason over the page as a whole. Cluster related evidence, compare incumbent operations, and propose
the smallest useful procedures, workflows, doctrine changes, or dismissals. The tracker is raw
evidence, not a process graph. Many rows may support one operation and one page may yield several.

Preview the proposed dispositions and use Foreman's existing acceptance boundaries. After explicit acceptance,
call `consume` only for rows the accepted result or dismissal resolves, with a concrete
resolution and optional shared result reference. Call `observe` for insufficient candidates that
were considered but remain open. Do not consume rejected proposals or invent a positional cursor;
the stable consumer key makes later `--unobserved` paging sufficient, while an all-open page supports
reconsideration.

Done when the bounded batch has an accepted disposition, resolved rows are consumed, deferred rows
are observed, and every operation or workflow remains authoritative in its ordinary Foreman home.
