# `close` — manage one observation's lifecycle

Use for `/agent-feedback close <id> --as <disposition> --reason <text> [--result-ref <ref>]`.
Translate the positional ID to provider `--id` and pass exactly one each of `--as` and `--reason`.
Allowed dispositions are `addressed`, `preserved`, `declined`, `stale`, and `duplicate`.

`--result-ref` is required for `addressed`, `preserved`, and `duplicate`, and optional for
`declined` and `stale`. It must be a privacy-safe commit, repository-relative path, non-local URL, or
another feedback ID. It never contains a parent traversal segment or uses a POSIX-absolute,
Windows-drive, UNC/backslash-rooted, tilde-rooted, or local `file:` URI form. Invoke package-local
`scripts/feedback.sh close` exactly
once. Do not inspect or edit the TSV and do not invoke a remediation capability.

Return `closed=<id>` or the exact-repeat result `unchanged=<id>`, followed by `count=1`. A missing ID,
conflicting re-close, invalid disposition, or malformed reference is an atomic refusal.

Done when one lifecycle transition or exact idempotent repeat was reported without changing any
non-lifecycle field or performing the work described by the feedback.
