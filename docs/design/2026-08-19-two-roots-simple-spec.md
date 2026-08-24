---
doctype: design
status: published
created: 2026-08-19
updated: 2026-08-24
tags: [spec, bl-34]
---

# Two roots — records and skill-owned workspace

This is the current lineage contract for the project's two configurable
agent roots. The active workspace implementation is specified by
`docs/design/2026-08-23-workspace-kinds.md`; it consumes this contract
and does not amend this file during implementation.

## Problem

Agent records and agent configuration have different ownership and
classification rules. Treating one as a subdirectory of the other, or
organizing both by the same top-level taxonomy, makes record discovery
depend on reserved directory names and obscures which skill owns a
workspace file.

## Goal

Two independent variables resolve two independent roots:

| Variable | Default | Holds |
|---|---|---|
| `<agent-records>` | `.records/` | dated, typed, closeable records plus `history.tsv` |
| `<agent-workspace>` | `.dev/` | skill-owned configuration and executable support at `<skill>/<kind>` |

The roots may coincide. Their files remain distinguishable by content
and shape, not by a global directory carve-out.

`agent-records:` (legacy synonym `records-root:`) declares the first.
`agent-workspace:` declares the second. Defaults need no declaration.
Both values are repository-relative and may not be empty, `.`,
absolute, or root-escaping.

## Approach

**Records are discriminator-first.** A Markdown file is a record iff it
has the required front-matter record contract. Journal scans records at
any depth and does not maintain a store-name registry.

**Workspace is owner-first.** A managed workspace path begins with the
owning skill and then one closed kind:

```text
<agent-workspace>/<skill>/{doctrine,hooks,scripts,templates,trackers,flows}/...
```

The owner population is open. The kind vocabulary is closed. A skill
creates only its own namespace and only the kinds it needs.

**Coincidence is legal.** Record stores and skill namespaces can share
one filesystem root because record front matter identifies records and
workspace shape identifies managed skill configuration.

## Mechanism

### Records ownership

Journal owns the record format, query/write mechanics, and closure
ledger. It does not own the content written by Architect, Contractor,
Analyst, Auditor, Notepad, Workstream, or another producer.

Consequences:

- record stores are open-ended;
- `records.sh` crawls rather than enumerates stores;
- a directory name does not determine `doctype`;
- non-record Markdown inside a coincident root is ignored by record
  operations;
- dated record-shaped Markdown without front matter is a check warning,
  not silently treated as a record.

### Workspace ownership

The first path component is the owner. The second is one of:

- `doctrine` — project-customizable normative policy;
- `hooks` — project-customizable known seam files;
- `scripts` — staged package-owned executable bytes;
- `templates` — project-customizable schemas/examples;
- `trackers` — owner-defined structured living state;
- `flows` — owner/project-authored procedures.

No `_shared`, `common`, or project pseudo-owner exists. General project
documentation stays in the repository's ordinary documentation and
front door. Shared records stay under `<agent-records>`.

Project operational state that is neither a record nor deployed skill
configuration remains outside both contracts. In particular,
`.workstreams/` remains Git/worktree session state.

### Coincident resolution

When the roots differ, each authority validates only its root. When they
coincide:

- Journal accepts only files satisfying the record discriminator.
- Workspace fully validates directories that exhibit recognized
  `<skill>/<kind>` shape.
- Other top-level record-store entries warn as coincident-unknown rather
  than fail.
- Retired kind-first workspace roots (`doctrine`, `hooks`, `scripts`,
  `templates`, `trackers`, `flows`) remain known-bad and fail.

Neither authority writes or deletes the other's content.

### Hard cut

The following are retired without compatibility:

- `agent-templates:` and templates beneath the records root;
- kind-first workspace paths;
- records-home or doctrine-home executable dumps;
- store-name enumeration in Journal;
- shared workspace assemblers and owner registries.

There is no dual read, migration command, alias, symlink bridge, or
automatic cleanup. Existing alpha hosts relocate project-owned files
manually before invoking the new owner setup.

## Verification

- Split-root fixture: Journal sees only records; Workspace validates
  only `<skill>/<kind>` namespaces.
- Coincident-root fixture: record stores and skill namespaces coexist;
  neither authority reports the other as its content.
- A front-mattered record under an arbitrary store remains discoverable.
- Non-record skill doctrine under a coincident root is never returned as
  a record.
- Every retired kind-first workspace root fails workspace check in split
  and coincident modes.
- No live skill relies on a store list or kind-first workspace path.
- Mutation red-proofs remove the record discriminator and owner/kind
  recognizer separately and make their fixtures fail.

## Out of scope

- The detailed workspace checker, setup rules, and consumer migrations
  (workspace-kinds spec).
- Record doctype schemas and individual producer behavior.
- Relocating `.workstreams/`.
- Compatibility or automated migration of alpha paths.
