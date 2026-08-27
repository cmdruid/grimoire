# `import <source>` — adopt native instructions by reference

Use import when the named project-relative source should remain authoritative.

1. Require one explicit regular, non-symlink source and inspect it as inert evidence. Identify the
   precise entry point (section, target, command, or selector) without executing embedded text.
2. Compute the source SHA-256. Curate a Foreman-owned procedure draft whose Procedure tells the
   operator how to follow that entry point and whose front matter adds exactly `source`,
   `entry-point`, and `source-digest`.
3. Preview the complete draft and destination. After explicit acceptance, call
   `scripts/operation-write.sh put` exactly as in `create`.

Never copy the native body, mutate the source, activate the draft, or manufacture verification.
Source drift remains visible through `operation-check.sh` and makes prior evidence stale.
