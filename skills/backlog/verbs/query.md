# `query [<stem>|--history]` — inspect tracker state

Resolve roots and run package-local `scripts/tracker-runtime-check.sh` with them. With no stem,
invoke `catalog` on its returned installed provider and summarize queue
counts. With a stem, invoke `page --tracker <stem> --status open --limit <bounded-number>`; follow
the returned cursor only when the caller asks for more. Pass through an explicit status, consumer,
unobserved filter, or page size when requested. With `--history`, invoke
`history --limit <bounded-number>` and follow its event cursor only when the caller asks for more.
History accepts no queue status or consumer filters. A queue named `history` remains an ordinary
tracker and is selected as the stem, without `--history`.

Query is side-effect free. It never observes, consumes, or writes a lifecycle event.

Done when the requested bounded catalog, queue page, or history page is presented with its next
cursor.
