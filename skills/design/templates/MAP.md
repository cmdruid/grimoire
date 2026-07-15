# Map

The system index and seam graph — the input `/design prep` and `/design plan` read to scope work.
Every system with a standing spec belongs in the index below; every coupling between systems
belongs in the seam graph.

## System index

| system | spec | code unit | depends on |
|---|---|---|---|
| <system name> | `src/<system>.md` | <path/module the spec compiles to> | <systems this one depends on, or none> |

## Seam graph

<Who couples to whom, and through what. This is the binding-seam summary at a glance — the
per-system detail (the actual contract of each seam) lives in each system's
`src/<system>.md` → Contract → Interfaces/seams. Keep this section short: a list or a small
diagram of couplings, not a restatement of every contract.>

- <system A> → <system B>: <what crosses the seam, one line>
