# `query [<stem>]` — inspect tracker state

Resolve roots and require the installed API. With no stem, invoke `catalog` and summarize queue
counts. With a stem, invoke `page --tracker <stem> --status open --limit <bounded-number>`; follow
the returned cursor only when the caller asks for more. Pass through an explicit status, consumer,
unobserved filter, or page size when requested. `receipts` may be paged only with `--status all` and
never with queue-only consumer filters.

Query is side-effect free. It never observes, consumes, or writes a receipt.

Done when the requested bounded catalog/page is presented with its next cursor.
