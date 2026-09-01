---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, grimoire]
---

# Grimoire symlink package manager — Spec

This is a hard-cut replacement for Grimoire's alpha product and format specifications. It is
grounded at `stream/app` commit `2de727c`, but deliberately specifies the product we want rather
than preserving the constraints of the current implementation.

## Problem

Agent skills are ordinary directories that become active when an agent harness can see them in a
skills directory. Today, installing those directories is mostly ad hoc: users clone repositories,
create links by hand, lose track of provenance, and cannot reliably reproduce which skills or pack
members a project intended to enable. A source update can silently change every link that points
into a live clone. Packs add another dependency layer, but the current `PACK.md`, lock, and app
models mix distribution with the idea of a pack "face," assume a local library, and do not provide
a safe remote-source workflow.

Remote skills are active content. Their instructions can influence an agent, and their bundled
scripts or binaries may later be run by an agent or user. Merely cloning a source must therefore
not grant it installation authority. Users and reviewing agents need a factual, machine-readable
way to inspect a source snapshot and its capabilities before granting trust. Trust must not turn a
moving branch into an automatic downstream update.

The root need is a small package manager with unusually legible state: it declares which skills
and packs a scope wants, pins every non-live source to one immutable snapshot, creates only owned
symlinks, reports missing pack dependencies, and requires explicit trust and explicit updates.

## Goal

Grimoire manages the desired and installed set of skills at project and global scope through a
familiar command line and a basic tree TUI. A committed project manifest plus lock reproduces the
same pinned source snapshots and skill selection on another machine; installed links point to
immutable local snapshots and do not move when a remote branch or local checkout changes. Explicit
live sources are the labeled, non-reproducible exception.

Adding, fetching, and inspecting a source never activates it. A user may approve one exact
snapshot or deliberately trust all future snapshots from one canonical source identity. Even
under that latter policy, changing an installed source snapshot remains a separately planned,
explicit update.

## Approach

Build one declarative planner/executor with two adapters:

- the CLI provides npm-like commands for automation and exact operations;
- bare `grimoire` opens a tree TUI that stages edits and applies one plan;
- both adapters consume the same domain plans and never perform filesystem choreography;
- `grimoire.toml` is human-authored desired state;
- `grimoire.lock` is deterministic generated JSON and is committed for projects;
- `${GRIMOIRE_HOME:-~/.grimoire}` holds all user-local source data, immutable snapshots,
  transaction journals, global state, and trust;
- project and global installs link only into `.agents/skills`;
- `PACK.md` is a pure bundle of skill names from one source snapshot.

The source repository itself needs no Grimoire-specific repository manifest. Grimoire discovers
valid `SKILL.md` and `PACK.md` files recursively using fixed rules. An optional source-level
manifest, registry, aliases for installed skill names, and nested/cross-source packs are deferred.

This approach rejects four alternatives:

- **Live links by default.** They are convenient but let a `git pull` mutate downstream projects
  without a Grimoire plan. Live mode remains an explicit local-only escape hatch.
- **One pin per skill.** Source repositories need not use one-skill-one-commit; pretending they do
  creates revisions that Git cannot reproduce. One source snapshot is the version unit.
- **A source manifest requirement.** It would make existing skill repositories ineligible for no
  v1 capability benefit. `SKILL.md` and `PACK.md` already identify the installable units.
- **Automatic script sandboxing or execution.** Grimoire never executes source content. A sandbox
  would not neutralize instruction-level risk and would imply a safety guarantee the app cannot
  make. Factual inspection plus explicit trust is the honest boundary.

## Mechanism

### Product boundary

Grimoire v1 owns:

- project and global desired state;
- local-path, local-Git, remote-Git, and GitHub-shorthand sources;
- recursive skill and pack discovery;
- immutable source snapshots and a local Git cache;
- exact-snapshot and all-snapshots trust policies;
- pack dependency resolution, including unavailable optional members;
- deterministic locks, owned symlinks, drift checks, updates, and safe pruning;
- a CLI and a tree TUI over the same plans.

It does not own:

- authoring or editing skills;
- running `SKILL.md`, `PACK.md` bodies, scripts, hooks, setup, or lifecycle commands;
- configuring a consuming project beyond links and Grimoire's two project state files;
- dependency declarations inside `SKILL.md` (pack membership is v1's only dependency graph);
- registries, marketplace search, ratings, publishing, archive/HTTP sources, or Git submodules;
- Windows junctions or copies. v1 supports macOS and Linux symbolic links only.

The repository's former faced/faceless distinction is deleted. A pack is always a pure bundle and
never itself a skill. Installing pack `clankshop` never creates a `clankshop` link, even when a
same-named skill exists.

### Scope and paths

There are exactly two independent scopes.

| Scope | Manifest | Lock | Installed links |
|---|---|---|---|
| project | `<project>/grimoire.toml` | `<project>/grimoire.lock` | `<project>/.agents/skills/<name>` |
| global | `<grimoire-home>/grimoire.toml` | `<grimoire-home>/grimoire.lock` | `~/.agents/skills/<name>` |

`<grimoire-home>` is `${GRIMOIRE_HOME}` when set to a non-empty absolute path, otherwise
`~/.grimoire`. The app resolves `~` once at its environment boundary. Core APIs receive resolved
paths and never read `HOME`, `GRIMOIRE_HOME`, the current directory, or process arguments.

The complete user-local layout is:

```text
~/.grimoire/
  grimoire.toml
  grimoire.lock
  trust.json
  projects.json
  store/checkouts/<source-key>/<snapshot-key>/
  cache/git/<source-key>.git/
  cache/review/<source-key>/<review-key>/
  cache/tmp/
  candidates/<scope-key>/<alias>.json
  locks/store.lock
  locks/trust.lock
  locks/projects.lock
  transactions/<scope-key>/
  transactions/store-repair/<snapshot-key>.json
```

Project discovery walks from the resolved current directory toward the filesystem root and selects
the nearest directory containing `grimoire.toml`. Nested projects are valid. `--project <path>`
selects that exact, existing directory and does not walk upward. `--global` and `--project` are
mutually exclusive. Without either flag, scope-aware commands use the nearest project; if none
exists they fail and suggest `grimoire init` or `--global`. Bare TUI invocation may still open on
the Global tab when no project exists.

`grimoire init` creates an absent project manifest and empty lock in the current directory.
`grimoire init --project <path>` does so at an explicit existing directory.
`grimoire init --global` initializes the global files. No other command silently initializes a
scope, and init never replaces a non-empty or unrecognized file.

Project and global dependency graphs are independent. A project skill may shadow a same-named
global skill because harness lookup precedence is outside Grimoire's control; the TUI labels that
fact. A project cannot mask, disable, rewrite, or remove a global install. Global entries shown on
the Project tab are inherited, read-only context.

### Manifest

`grimoire.toml` is UTF-8 TOML, human-authored, comment-preserving, and uses the following v1 shape:

```toml
schema = "grimoire/manifest@1"

[sources.grimoire]
url = "github:cmdruid/grimoire"
ref = "main"

[sources.private]
url = "ssh://git@github.com/example/private-skills.git"
ref = "release"

[sources.sibling]
path = "../skill-library"

[sources.scratch]
path = "../experimental-skills"
live = true

[skills]
developer-writing = { source = "grimoire" }

[packs]
clankshop = { source = "grimoire", exclude = ["scheduler"] }
```

Normative rules:

- `schema` is required and must equal `grimoire/manifest@1`.
- Source aliases, skill names, and pack names are lowercase kebab-case slugs matching
  `[a-z0-9]+(?:-[a-z0-9]+)*` and are unique within their respective tables.
- A source contains exactly one of `url` or `path`. `ref` is optional and defaults to the remote
  default branch for URLs or `HEAD` for pinned local Git. `live` defaults false, is valid only for
  `path`, and cannot be combined with `ref`.
- Relative source paths resolve against the directory containing the manifest. They remain
  relative in the committed lock; absolute materialization paths never enter it.
- Every `[skills]` or `[packs]` entry names an existing source alias. A pack's `exclude` list is
  sorted on generated writes, contains only optional members, and represents optional skills that
  are disabled. All other available optional members are enabled by default.
- A skill may be both directly requested and requested by one or more packs. It is installed once
  and remains while at least one request root owns it.
- Unknown top-level keys, source fields, and skill/pack entry fields are rejected in v1.
  Comment-preserving edits use a document model; Grimoire does not serialize a parsed value back
  over the whole file.

The source tables are first-class project declarations, not aliases into a hidden user catalog.
The same alias may mean something different in another scope. Trust, however, is keyed to canonical
source identity rather than alias.

### Lock

`grimoire.lock` is committed for project scope. It is generated JSON because humans should review
semantic changes while the app owns formatting. Output is UTF-8, two-space indented, key-sorted at
every object level, and ends with one newline. A representative lock is:

```json
{
  "schema": "grimoire/lock@1",
  "sources": {
    "grimoire": {
      "declared": "github:cmdruid/grimoire",
      "kind": "git",
      "ref": "main",
      "commit": "0123456789abcdef0123456789abcdef01234567",
      "tree": "89abcdef0123456789abcdef0123456789abcdef"
    }
  },
  "packs": {
    "clankshop": {
      "source": "grimoire",
      "required": ["journal"],
      "optional": ["architect", "scheduler"],
      "enabled": ["architect"],
      "unavailable": []
    }
  },
  "skills": {
    "architect": {
      "source": "grimoire",
      "path": "skills/architect",
      "content": "sha256:...",
      "requested_by": ["pack:clankshop"]
    },
    "developer-writing": {
      "source": "grimoire",
      "path": "skills/developer-writing",
      "content": "sha256:...",
      "requested_by": ["skill:developer-writing"]
    }
  }
}
```

Source, pack, and skill object keys sort lexically. Member lists and `requested_by` sort lexically.
For Git snapshots, `commit` and `tree` are the full Git object IDs returned by that repository's
object format. Each skill `content` is Grimoire's canonical `sha256:` content digest, so drift and
review do not depend on Git's hash algorithm. `declared` preserves the portable manifest value;
canonical absolute local paths, cache paths, store paths, timestamps, trust, and last-fetch state
are forbidden from the lock.

For a live source the source entry instead records `kind: "live"`, its portable declared path, and
the current canonical skill hashes. A live lock is intentionally non-reproducible and
`--frozen` refuses it.

The lock is a complete resolution of the manifest, not an append-only install log. A pack records
the roster observed in its locked source snapshot; a skill records every direct or pack request
root. A source snapshot therefore may update several skills together without pretending each
skill came from a different commit. `sources` contains only aliases that contribute a requested
skill or pack; merely adding an untrusted source changes the manifest and candidate cache, not the
lock.

For a pack, `required` and `optional` reproduce the locked `PACK.md` roster. `enabled` contains
every optional member selected by desired state, including a selected member absent from the
snapshot. `unavailable` is the sorted subset of `enabled` that is absent; those names have no skill
entry. An excluded optional member appears in `optional` but in neither `enabled` nor
`unavailable`. A successful lock never has an unavailable required member.

Only `grimoire/lock@1` is accepted. The alpha lock format has no compatibility reader or migration.
Encountering another schema produces a concise hard-cut error telling the user to delete the old
lock and run a non-frozen install. Grimoire never silently deletes user state. During the product
refactor, superseded alpha format documents, fixtures, implementation code paths, and `install.sh`
are deleted rather than retained as parallel contracts.

An initialized empty lock contains the schema and empty `sources`, `packs`, and `skills` objects.
`<source-key>` is the lowercase hexadecimal SHA-256 of the canonical source identity.
`<snapshot-key>` is the lowercase hexadecimal SHA-256 of the source kind, commit, repository tree,
and inventory digest separated by NUL bytes. `<review-key>` uses the same encoding with empty
commit/tree fields when they are null. It equals the snapshot key for pinned sources and remains
defined for live sources, which have no store snapshot key.

### Source identities, fetching, and snapshots

Accepted source locations are:

- `github:<owner>/<repo>` shorthand, expanded to an HTTPS Git URL;
- an `https://` Git URL without embedded credentials;
- an `ssh://` Git URL or SCP-style `<user>@<host>:<path>` SSH location;
- a local path to a Git worktree for pinned mode;
- any readable local directory for explicit live mode.

GitHub shorthand is canonicalized to `https://github.com/<owner>/<repo>.git`. For other remotes,
canonical identity lowercases only URI scheme and host and otherwise preserves the URI path
byte-for-byte, including case, trailing slash, and `.git` suffix. SCP syntax is not converted to an
SSH URI: its path is relative to the remote user's home, whereas an `ssh://` path beginning with
`/` is absolute. Its canonical identity is
`ssh-scp:<user>@<lowercase-host>:<path>`, with username and path preserved byte-for-byte, and Git is
given the original declared SCP location rather than that identity string. Query strings,
fragments, embedded passwords, `file://`, `git://`, `ext::`, custom remote helpers, and unknown
schemes are rejected rather than normalized. SCP, SSH-URI, SSH, and HTTPS identities remain
distinct; Grimoire does not guess that two transports are the same authority. Local canonical
identity is the symlink-resolved absolute source root. Trust uses canonical identity; committed
state does not. The same canonical identity may appear under only one alias in a scope, preventing
two revisions of one source from entering the same resolution under different names.

Pinned local sources must be Git worktrees with a clean index and worktree. Grimoire resolves the
declared ref, copies the exact commit into the immutable store, and thereafter links to the stored
snapshot. Editing or pulling the original checkout cannot alter an installed skill. A dirty pinned
source is a blocker, not an implicit live source.

Live sources require a readable directory and explicit `live = true`. Their installed links point
directly into that directory, dirty contents are allowed, and changes take effect immediately.
They are local-only, require an all-snapshots trust policy, and are refused by `--frozen`. The TUI
labels them continuously as non-reproducible. A URL can never be live.

Grimoire uses the user's `git` executable and existing SSH and HTTPS credential mechanisms. It
stores no credentials. Git may invoke the user's configured SSH client or HTTPS credential helper;
that user-owned transport behavior is not source content. Grimoire never invokes a remote helper
selected by an unrecognized URL scheme. Fetch uses a bare mirror under `cache/git`, disables hooks
and recursive submodules, and materializes from Git objects without running filters, LFS smudge
processes, checkout hooks, build scripts, or any file from the source.

An installable snapshot is written into a new temporary directory, verified against its canonical
inventory, and renamed once to its immutable store key. Directories and non-executable files become
read-only; executable files retain execute bits but lose write bits. Before creating or repairing a
link, Grimoire re-verifies every referenced skill digest. `check` distinguishes corrupt store
content from link-target drift. An existing corrupt store entry is never reused or repaired in
place. When its source objects are available, an online operation may rematerialize it through a
new verified temporary directory and the journaled quarantine swap defined under Transactions and
recovery. Offline frozen operation fails.

Materialization rejects absolute paths, `..` traversal, NUL names, device/FIFO/socket entries,
case-folded path collisions, and symlinks whose lexical target escapes the snapshot. Internal
symlinks may be materialized but discovery never follows them. Submodule entries are reported by
`source info` and left unmaterialized; a pack member present only in a submodule is missing.

Inspection uses a distinct content-addressed export under `cache/review`. Its
`grimoire/review-index@1` `index.json` lists every source entry in raw Git path-byte order. Each
record contains the raw path as base64, the UTF-8 path when representable, kind, normalized mode,
and either a regular-file object digest, raw symlink-target bytes and safety classification, or a
submodule commit. Regular file bytes live under read-only `objects/<sha256>` paths with write and
execute bits cleared. A best-effort `tree/` view may additionally expose regular files at their
source-relative paths only when every component is valid UTF-8, representable on the host, free of
case-fold collisions, and safe to materialize. That view is convenience, never the canonical
index.

The export never creates symlinks or submodule directories. It can therefore be produced even
when an escaping symlink, invalid UTF-8 name, case-fold collision, or host-unrepresentable path
makes the installable snapshot invalid. `source info` points `review_path` at the export root.
Grimoire never executes review content and clears its executable mode bits, but the export is not a
sandbox or safety boundary and trust never turns it into an install target.

`source fetch` updates the local mirror and one scope-and-alias-specific candidate record only. It
never changes a manifest request, lock, installed link, trust baseline, or immutable snapshot
already in use. Candidate records use schema `grimoire/candidate@1` and bind the source declaration
byte hash, canonical identity, nullable commit and repository tree, and inventory digest. Requested
ref comes from the matching manifest declaration. Snapshot key, review key, and review-export path
are derived from their normative formulas and resolved Grimoire home rather than duplicated in the
record. Candidate records are local state and never enter a project lock or manifest.

Fetch and inspection occur in per-source temporary locations without a scope lock. Before
publishing the result, Grimoire acquires applicable shared-state locks in the global order and then
the scope lock, revalidates the manifest declaration byte hash and canonical identity, and
atomically replaces `candidates/<scope-key>/<alias>.json`. A changed or removed declaration makes
the result stale and leaves the prior candidate intact. Consequently, scopes and aliases may track
different refs for the same canonical source without rebinding one another. A successful offline
frozen install requires every locked snapshot to exist in the store and performs no network
operation.

Store entries have no automatic eviction. `store prune` removes only snapshots that are not
referenced by the global lock, a known project lock, an active transaction journal, or current
candidate metadata. Whenever Grimoire successfully loads a project scope, `projects.json` records
its canonical path, lock SHA-256, sorted snapshot keys, and last-observed timestamp. Prune refreshes
every readable recorded project before planning. A missing or unreadable project protects its
last-observed snapshot keys and is reported; it is never treated as an empty project. Users may
pass additional `--project <path>` occurrences to register and protect locks not already indexed.
A snapshot whose reachability cannot be proven is retained, and `--yes` does not weaken that rule.

### Discovery and names

Every source is scanned without a repository manifest. Traversal is deterministic, lexical by raw
source-relative path bytes, does not follow filesystem symlinks, and stops descending once it finds
a skill directory. It ignores directories named `.git`, `.hg`, `.svn`, `.grimoire`, `node_modules`, or
`target` at any depth. It also ignores `.cache`, `.tmp`, `.worktrees`, `.workstreams`, `build`,
`dist`, `vendor`, and `fixtures`, which are conventional generated, vendored, or test-fixture
boundaries rather than source inventory. It does not ignore `skills`, `.agents/skills`,
`.claude/skills`, `.codex/skills`, `tests`, or `examples`. It also does not enter a nested Git
checkout (a child directory containing a `.git` file or directory). A source scan is bounded to 32
directory levels and 100,000 directory entries; crossing either limit is a source validation error,
never a partial successful inventory.

All installable relative paths must be valid UTF-8 and use `/` in canonical records. Canonical
skill content hashing visits every non-directory entry below the skill root in sorted relative-path
order without following links. For each entry it feeds SHA-256 an unambiguous length-prefixed tuple
of relative path, kind (`file` or `symlink`), normalized mode (`100644`, `100755`, or `120000`),
and exact file bytes or symlink-target bytes. Empty directories do not contribute; line endings and
file bytes are not normalized. The source inventory digest hashes the sorted tuples of discovered
skill name/path/content digest and pack name/path/exact `PACK.md` SHA-256, plus validation findings.

The enclosing byte grammar is versioned `grimoire/source-inventory@1`. It begins with that ASCII
schema string followed by NUL, then feeds each sorted record as a one-byte record kind followed by
each field encoded as an unsigned 64-bit big-endian byte length and exact bytes. Skill records
contain name, path, and content digest. Pack records contain name, path, and `PACK.md` digest.
Finding records contain stable code, raw source-relative path bytes (empty when the finding has no
path), severity, then an unsigned 64-bit big-endian detail count followed by detail pairs sorted by
key. Detail keys and values are UTF-8 strings, each encoded with the same unsigned 64-bit big-endian
byte length and exact bytes; schema 1 admits no numeric, boolean, null, list, or object detail
values. Human JSON may still expose those pairs as an object and uses the nullable-path/base64 rule
defined under Source info. Human display messages, absolute paths, timestamps, trust, and discovery
order never contribute.

A skill is a real directory containing a regular `SKILL.md`. Its YAML frontmatter must contain a
valid `name` slug. Directory basename fallback is removed. A `PACK.md` is considered at any scanned
directory that is not inside an ignored tree or a discovered skill directory. The directory
holding a pack has no install semantics.

Frontmatter is parsed before trust and is therefore bounded data. The opening through closing YAML
fence may contain at most 64 KiB, 4,096 parsed nodes, and 16 levels of mapping/sequence nesting.
Parsers reject duplicate keys, aliases, anchors, explicit tags, merge keys, non-string mapping
keys, and scalar values outside the ordinary null, boolean, finite-number, and string forms.
`SKILL.md` must have a top-level mapping whose `name` is a scalar string containing a valid slug;
Grimoire ignores other safely parsed fields and does not claim or restrict their schema. `PACK.md`
uses only the exact fields and value shapes defined below. File bodies may be larger and are
streamed for hashing and capability reporting; they are never loaded through the YAML parser.

Two skills with the same name in one snapshot are a source error. Two packs with the same name are
a source error. Pack and skill namespaces are separate, but CLI pack operations require `--pack`
so an ambiguous bare name cannot select the wrong kind. Within one install scope, one
source/snapshot owns a skill name. A request that would resolve the same name from another source
or revision blocks even when content hashes match. v1 has no aliases or content-based adoption.

Inventory findings have stable codes and paths. Duplicate identities, unsafe entries, traversal
limits, malformed `SKILL.md`, and malformed `PACK.md` are validation errors; missing optional pack
members are availability warnings. `source add` may register a fetched source with validation
errors and `source info` still emits all available facts with exit 1, allowing review and upstream
repair. Trust may also be recorded because it grants no activation by itself. Any install or update
that would resolve from a source with a validation error is refused as malformed input (exit 2).

### `PACK.md`

The complete v1 machine surface is YAML frontmatter:

```markdown
---
schema: grimoire/pack@1
name: clankshop
description: Project-development helper and utility skills.
required:
  - journal
optional:
  - architect
  - scheduler
---

Optional human-readable documentation follows.
```

Rules:

- `schema`, `name`, `description`, `required`, and `optional` are the only accepted keys.
- `schema` equals `grimoire/pack@1`; `name` is a slug; `description` is a non-empty string.
- `required` and `optional` are both required YAML sequences of unique skill-name slugs. Either may
  be empty. Comma-separated scalar forms are invalid. A name cannot appear in both, and at least
  one total member is required.
- A pack contains skills only. It cannot name another pack, select a source, or reference a member
  from another source snapshot.
- Required members are always enabled. A missing required member blocks installing or reconciling
  that pack. Optional members are enabled by default; a missing optional member is reported as
  unavailable but does not invalidate the other selected members.
- The Markdown body is display documentation only. Grimoire may render it as text but never parses
  it into actions or executes it.
- Unknown keys, the old `format: 1` key, a `version` field, and face semantics are hard errors. A
  pack has no independent version: its source commit/tree is its version.

Removing a pack removes its root request. A member remains installed if directly requested or
requested by another installed pack. Shared members are linked once and expose all request roots in
the plan, lock, CLI, and TUI.

### Trust and capability review

Source registration and trust are two separate ceremonies. A source's presence in a committed
manifest proves intent to locate it, not local approval to activate it. All pinned and live sources
must satisfy the local trust store before any plan can create or repoint links to their content.

`~/.grimoire/trust.json` is local, never committed, created with user-only permissions, and has
schema `grimoire/trust@1`. Trust records are keyed by canonical source identity and contain:

- zero or more exact receipts binding full commit, repository tree object ID, and Grimoire source
  inventory digest;
- an optional `all_snapshots: true` policy;
- the last snapshot explicitly reviewed or actually accepted by install/update, used as the diff
  baseline.

`grimoire source trust <alias>` approves only the currently fetched candidate snapshot and writes
an exact receipt. The receipt persists, so the same bits do not require repeated approval, but a
different commit or tree is untrusted. `grimoire source trust <alias> --all` records the prominent,
revocable all-snapshots policy. For a pinned candidate it also records an exact receipt; for a live
source it records the current inventory as the review baseline but no exact receipt.
`grimoire source trust <alias> --revoke` removes exact receipts and the all-snapshots policy for
that canonical identity. Because trust is identity-wide, the command previews every known scope
that uses it. Removing a source alias does not silently revoke identity trust; revocation remains
an explicit trust operation. Scope-independent `grimoire trust list` shows every canonical identity,
its source key, policy, receipts, baseline, and known aliases. `grimoire trust revoke <source-key>`
provides the same preview and revocation when no alias remains.

Exact receipts apply only to pinned snapshots. `source trust` without `--all` refuses a live
source, because no stable snapshot exists to approve; live sources require the all-snapshots
ceremony. Granting exact trust makes that candidate the reviewed diff baseline. Fetch alone never
advances the baseline. Under trust-all, a future pinned snapshot becomes the baseline only when an
update actually applies it. Live content changes immediately by definition, so its baseline remains
the inventory observed at the most recent explicit `--all` approval and `source diff` reports later
changes against it.

`source add ... --trust` is shorthand for registering/fetching the source and approving that exact
candidate. `--trust-all` records the all-snapshots policy. The flags are mutually exclusive. A URL
or path identity change never inherits trust from the old identity. `--yes` can confirm a plan but
can never grant or broaden trust.

An all-snapshots policy means future candidate snapshots pass the trust gate; it does not install
them, update the lock, or repoint links. `source fetch` remains inert. `update` still shows the full
source and downstream diff and follows destructive confirmation rules. When an all-trusted
snapshot is actually applied, it becomes the new accepted diff baseline.

Revoking trust does not silently uninstall already active content. `check` reports those installed
sources as untrusted; operations that create or repoint their links block until trust is restored.
Removing an installed request remains allowed so a user can deactivate untrusted content.

`grimoire source info <alias>` and `--json` work on untrusted candidates and report facts, never a
"safe" verdict. JSON uses this normative `grimoire/source-info@1` shape:

```json
{
  "schema": "grimoire/source-info@1",
  "alias": "grimoire",
  "source": {
    "declared": "github:cmdruid/grimoire",
    "canonical": "https://github.com/cmdruid/grimoire.git",
    "kind": "git",
    "requested_ref": "main"
  },
  "snapshot": {
    "commit": "0123456789abcdef0123456789abcdef01234567",
    "tree": "89abcdef0123456789abcdef0123456789abcdef",
    "inventory": "sha256:...",
    "review_path": "/home/user/.grimoire/cache/review/..."
  },
  "trust": {
    "mode": "snapshot",
    "baseline": {
      "commit": "0123456789abcdef0123456789abcdef01234567",
      "tree": "89abcdef0123456789abcdef0123456789abcdef",
      "inventory": "sha256:..."
    }
  },
  "skills": [
    {
      "name": "architect",
      "path": "skills/architect",
      "content": "sha256:...",
      "files": [
        {
          "path": "scripts/check.sh",
          "kind": "file",
          "size": 320,
          "mode": "100755",
          "sha256": "sha256:...",
          "binary": false,
          "executable": true,
          "shebang": "#!/bin/sh"
        },
        {
          "path": "docs/current.md",
          "kind": "symlink",
          "mode": "120000",
          "target": "../outside.md",
          "safety": "escaping"
        }
      ]
    }
  ],
  "packs": [
    {
      "name": "clankshop",
      "path": "PACK.md",
      "digest": "sha256:...",
      "description": "Project-development helper and utility skills.",
      "required": ["journal"],
      "optional": ["architect"],
      "missing_required": [],
      "missing_optional": []
    }
  ],
  "findings": [
    {
      "code": "escaping-symlink",
      "severity": "error",
      "path": "skills/architect/docs/current.md",
      "details": { "target": "../outside.md" },
      "message": "symlink target escapes the source snapshot"
    }
  ]
}
```

All shown top-level and nested fields are required unless this paragraph says otherwise. For live
sources, `source.kind` is `live`; `source.requested_ref`, `snapshot.commit`, and `snapshot.tree` are
JSON null. `trust.mode` is `untrusted`, `snapshot`, or `all`; `trust.baseline` is null when none
exists, otherwise it has the snapshot fields shown with nullable commit/tree for live content.
`review_path` is an absolute local path to the content-addressed review export root after successful
inspection. Skill file paths are skill-root-relative; skill, pack, and finding paths are
source-root-relative. All use `/` separators. File entries are tagged variants: `file` has every
field shown above. Its `shebang` is null when absent or not valid UTF-8; the latter case additionally
has `shebang_bytes_base64`. `symlink` has `mode`, `target`, and `safety` (`internal` or `escaping`);
`target` is null for non-UTF-8 bytes and that case additionally has `target_bytes_base64`.
`submodule` has `commit`. Variant-inapplicable and unnecessary base64 fallback fields are absent
rather than null. A finding for a path that is not valid UTF-8 uses `path: null` and includes a
`path_bytes_base64` string in `details`; this is the only nullable path case. All base64 uses the
standard RFC 4648 alphabet with padding. Skills, packs, files, member names, findings, and detail
keys sort lexically by their identifying field or, for a null finding path, by its decoded raw path
bytes. `message` is display-only; consumers branch on `code`, `severity`, and `details`.

`executable` is true exactly when normalized mode is `100755`. Binary is the factual presence of
NUL in the first 8 KiB, not a malware judgment. A shebang is present only when the file begins with
`#!`; its first line is captured as at most the first 512 bytes and reported through the UTF-8 or
base64 form above. Path, byte size, mode, executable, shebang, binary, and digest are facts. The
stable schema does not guess whether a path is a script or whether a file is large; human renderers
may highlight those facts without adding policy to the JSON contract.

The JSON field names and enum strings are stable within schema 1; object ordering is irrelevant.
Additive fields may be introduced, but existing fields do not change meaning. Agents may review
the non-executable-by-mode materialized content as data and then invoke the trust command. Neither
that review nor Grimoire's inventory proves safety, and another program may still interpret a file
explicitly.

`grimoire source diff <alias>` compares the candidate to the most recent explicitly trusted
snapshot or subsequently applied trust-all snapshot for that canonical identity (or an empty
baseline if none) and reports changed commits, skills,
packs, files, hashes, size/executable/shebang/binary facts, symlinks, submodules, validation
findings, and the installed/requested skills that an update would affect.

### Command surface

The canonical v1 grammar is:

```text
grimoire
grimoire init [--global | --project <path>]

grimoire source add <alias> <location> [--ref <ref>] [--live]
                    [--trust | --trust-all] [scope]
grimoire source list [scope]
grimoire source remove <alias> [--yes] [scope]
grimoire source fetch [<alias>] [scope]
grimoire source info <alias> [--json] [scope]
grimoire source diff <alias> [scope]
grimoire source trust <alias> [scope]
grimoire source trust <alias> --all [scope]
grimoire source trust <alias> --revoke [--yes] [scope]

grimoire trust list
grimoire trust revoke <source-key> [--yes]

grimoire install [--dry-run] [--frozen] [--yes] [scope]
grimoire install <skill> --source <alias> [--dry-run] [--yes] [scope]
grimoire install <pack> --pack --source <alias> [--dry-run] [--yes] [scope]
grimoire uninstall <skill> [--dry-run] [--yes] [scope]
grimoire uninstall <pack> --pack [--dry-run] [--yes] [scope]
grimoire update [<source>] [--dry-run] [--yes] [scope]
grimoire list [scope]
grimoire check [scope]
grimoire store prune [--project <path>]... [--dry-run] [--yes]

scope := --global | --project <path>
```

`remove` is accepted as an alias for `uninstall`, but help and documentation use `uninstall`.
Global flags `--help` and `--version`, plus contextual `<command> --help`, exit before resolving
paths or sources. Parsing belongs to the app adapter; the core receives typed values.

Command semantics are:

- `source add` validates an alias/location, records the source, fetches or snapshots a candidate,
  and optionally performs the explicit trust shortcut. It may register a source that currently has
  no skills or packs so the TUI can browse later changes. A live source may likewise be registered
  untrusted for inspection; `--trust` is invalid with `--live`, while `--trust-all` is the shortcut.
  Installation from that live source remains blocked until its all-snapshots policy exists.
- `source list` shows declared sources, candidate/locked snapshots, live state, and trust status.
- `source remove` is blocked while any skill or pack request references the alias. It does not
  delete shared cache/store content or identity trust, but atomically removes that alias's local
  candidate record with the manifest declaration.
- `source fetch [alias]` refreshes candidates for one or all sources and changes no desired or
  installed state.
- `source info`, `source diff`, and `source trust` implement the review ceremony above. `info` is
  the canonical replacement for the earlier term `inventory`/`peek`.
- `trust list` and `trust revoke` operate on the user-local identity trust store without resolving
  a project scope. Revocation by source key exists so removing the final manifest alias cannot
  strand an all-snapshots policy. It uses the same identity-wide preview and destructive
  confirmation as alias-based revocation.
- `install` with no operand reconciles the existing manifest. With a skill or `--pack` operand, it
  adds that direct request to the manifest and reconciles. The source must already be registered.
- `uninstall` removes one direct request. It is an error to uninstall a merely transitive pack
  member as a direct skill; the output names its remaining request roots.
- `update [source]` performs no fetch. It proposes advancing one source or every non-live source
  from each selected source's current cached candidate, resolves all affected requests against
  exactly that candidate, and applies the whole scope atomically. A selected source without
  candidate metadata, or whose candidate declaration hash or canonical identity no longer matches
  the manifest, blocks with an instruction to run `source fetch`; candidate identity and candidate
  record bytes are apply preconditions, so a concurrent fetch yields `StalePlan` rather than
  substituting a newer commit. Naming a live source is an input error because its links already
  expose current content. There is no `update <skill>` because that would imply a false per-skill
  revision.
- `list` shows desired roots, resolved skills, request roots, source/snapshot, installed/drift
  state, unavailable optional members, inherited global skills in project scope, and shadowing.
- `check` performs no fetch and reports manifest/lock resolution mismatch, missing store entries,
  trust state, missing/changed/foreign links, invalid source metadata, and recoverable transactions.
- `store prune` is the only store deletion command and follows the reachability rule above.

Optional pack members may be enabled/disabled by editing `exclude` in the manifest or toggling them
in the TUI. v1 deliberately does not add a second CLI grammar for that uncommon edit; the next
operand-free `install` reconciles a hand edit.

### Plans, confirmation, and frozen mode

Every mutating command first builds and prints a complete plan. A plan lists manifest edits, lock
edits, candidate and previous source snapshots, snapshot fetch/materialization, links created,
repointed, retained, or removed, unavailable members, blockers, and trust requirements.

An additive-only, unblocked plan may apply without a second prompt. A plan is destructive when it
removes or repoints a link, advances a locked source, removes desired state, revokes trust, or
prunes a snapshot. In a TTY it asks `Apply? [y/N]`. Outside a TTY it refuses unless `--yes` is
present. Declining is a successful cancelled outcome and changes nothing.

`--dry-run` performs discovery, resolution, trust checks, and planning, then exits without mutation.
`--yes` answers only the destructive confirmation. It never bypasses untrusted content, name
collisions, missing required members, malformed state, frozen mismatch, stale preconditions,
foreign occupancy, or ownership checks.

`--frozen` compares the manifest schema, source declarations, direct skill/pack request roots, and
pack exclusions to the resolution recorded in the existing lock. It does not resolve a declared
branch or ask whether its remote head still equals the locked commit; the lock is authoritative for
that moving-ref question. Frozen mode requires every exact pinned snapshot in the store, performs
no fetch, accepts no live source, and does not rewrite manifest or lock bytes. It may repair missing
owned links after verifying store content. Any declaration/request mismatch, corrupt or absent
snapshot, or trust failure is a blocker.

### Ownership and collisions

Grimoire mutates only paths proven owned by the active scope lock and still pointing to the target
that lock implies.

- An absent destination may be created.
- An existing symlink to the exact expected target is already correct.
- A different symlink, regular file, or directory is foreign and blocks install/repoint.
- Removal unlinks only a symlink whose current target equals the lock-derived owned target.
- If an owned link was altered after installation, Grimoire reports drift and leaves it untouched.

There is no `--force`, adopt, replace, or content-equality shortcut in v1. A project operation never
uses its lock to claim a global link, or vice versa.

### Planner/executor API

The Rust workspace keeps its three current responsibility layers but hard-cuts their APIs:

- `grimoire-pack` owns strict `SKILL.md` identity parsing, `PACK.md` schema 1, deterministic source
  discovery, canonical content hashing, and capability facts. It knows no home or installed scope.
- `grimoire-core` owns manifests, locks, source identities/backends, store, trust, resolution,
  checking, plans, transactions, and recovery. It performs no presentation or ambient environment
  access.
- `skill-grimoire` owns `clap` parsing, environment/path resolution, plain/JSON rendering, TTY
  confirmation, and Ratatui state. It never creates/removes links or writes state directly.

The core's public conceptual API is:

```rust
pub struct Paths { pub grimoire_home: PathBuf, pub scope: ScopePaths }
pub enum ScopePaths { Project { root: PathBuf }, Global { user_home: PathBuf } }
pub struct Manifest;
pub struct Lockfile;
pub struct SourceSpec;
pub struct SnapshotId;
pub struct SourceInfo;
pub struct TrustStore;
pub struct WorldState;
pub struct Plan {
    pub actions: Vec<Action>,
    pub blockers: Vec<Blocker>,
    pub preconditions: Preconditions,
}
pub struct ApplyOutcome;

pub fn discover_project(start: &Path) -> Result<Option<PathBuf>>;
pub fn load_world(paths: &Paths) -> Result<WorldState>;
pub fn fetch_source(world: &WorldState, alias: &str) -> Result<SourceInfo>;
pub fn inspect_source(world: &WorldState, alias: &str) -> Result<SourceInfo>;
pub fn plan(world: &WorldState, request: Request) -> Result<Plan>;
pub fn apply(paths: &Paths, plan: Plan, approval: Approval) -> Result<ApplyOutcome>;
pub fn check(world: &WorldState) -> Result<CheckReport>;
pub fn recover(paths: &Paths) -> Result<RecoveryOutcome>;
```

These names may be split into modules, but the contracts are normative:

- `WorldState` is an immutable observation containing the bytes/hashes and symlink targets used to
  plan. It never refreshes itself.
- `Request` represents every CLI/TUI intent, including desired-state edits, reconcile, update,
  trust, and prune. Frontends cannot smuggle an unplanned filesystem action into `apply`.
- `Plan` is a serializable domain value. Every action identifies its scope and before/after state;
  every blocker has a stable code and human detail. Presentation does not infer destructiveness.
- `Preconditions` include manifest and lock byte hashes, relevant directory/link observations,
  source candidate identity, snapshot existence, and trust-store revision.
- `apply` accepts only an unblocked plan, reacquires the exclusive scope lock, revalidates all
  preconditions, and returns `StalePlan` instead of replanning invisibly.
- Core receives a command runner abstraction for Git and filesystem/time abstractions where needed,
  so tests use inert fakes and temporary roots. Production construction occurs once in the app.

`source info --json` serializes the `SourceInfo` domain value directly through its schema adapter.
The TUI and human CLI render the same facts and plan actions rather than rebuilding their own
dependency or capability models.

### Transactions and recovery

Only one mutating operation may hold a scope at a time. The lock and crash journal live under
`<grimoire-home>/transactions/<scope-key>/`; the project scope key is a hash of its canonical root,
and global has a fixed key. Three user-home locks protect state shared across scopes:

- `store.lock` is shared while an apply relies on snapshots and exclusive for prune or the final
  rename of a newly materialized snapshot;
- `trust.lock` is exclusive for a trust-store write and shared while an apply revalidates trust;
- `projects.lock` is exclusive while refreshing the project index or planning/applying prune.

When several are needed, acquisition order is `store`, `trust`, `projects`, then scope. A command
never waits for an earlier lock while holding a later one. Non-trust project and global applies may
run concurrently because they take shared store/trust locks and distinct scope locks; a project
apply also takes the project-index lock before its scope lock. Trust mutations take the exclusive
trust lock. Fetches may run concurrently through per-source temporary directories, taking the
exclusive store lock only for store/index changes and immutable final rename, then their scope lock
for candidate publication. Prune holds exclusive store and project locks through precondition
revalidation and deletion, so it cannot race a new lock or candidate reference.

Corrupt snapshot replacement uses a separate journal at
`transactions/store-repair/<snapshot-key>.json`. Grimoire first materializes and verifies a complete
replacement in a temporary directory. Under the exclusive store lock it re-verifies that the fixed
store path is corrupt, writes and fsyncs a journal naming the fixed, quarantine, and replacement
paths, renames the corrupt directory to a transaction-private quarantine path, and renames the
replacement to the fixed snapshot key. If the second rename fails normally, it restores the
quarantine immediately. After a crash, recovery keeps the fixed path when it verifies as the
expected snapshot and removes the quarantine; otherwise it restores the quarantined directory and
discards the incomplete replacement. Recovery is idempotent and fsyncs the store parent before
removing the journal. Links may be briefly unavailable across the two renames, but they never
resolve to mixed old and new content.

Apply proceeds as follows:

1. Materialize any absent immutable snapshots, and complete any permitted corrupt-snapshot repair,
   before the state transaction. Update never fetches here. Failure leaves at most an unreferenced
   verified store entry or a recoverable store-repair journal.
2. Acquire every applicable shared-state lock in the order above, then acquire the scope operation
   lock and recover or refuse any prior journal.
3. Re-observe every plan precondition. Abort stale without mutation.
4. Write a journal containing the complete before/after manifest, lock, and applicable candidate
   hashes/bytes, link targets, any trust-store mutation, and ordered action state; fsync it before
   the first mutation.
5. Write new manifest, lock, and applicable candidate bytes to sibling temporary files and fsync
   them.
6. Create replacement symlinks under temporary sibling names. Record prior owned targets for
   removals/repoints; foreign paths have already blocked the plan.
7. Atomically rename links into place or unlink proven-owned removals, marking each journal action.
8. Atomically rename the state files into place and fsync their parent directories. Source add and
   removal commit the manifest before their candidate creation or removal. A combined
   `source add --trust` or `--trust-all` renames the manifest first, candidate second, and atomically
   staged trust file last. Its crash-visible intermediates are therefore at worst a registered
   source without its candidate or a registered but untrusted source, never trust for a source
   registration that did not commit; journal recovery completes or rolls back those intermediates.
   Standalone trust writes use the same staged rename.
9. Mark committed, atomically refresh `projects.json` when applicable, and remove temporary links
   and the journal.

On an ordinary error, rollback restores prior owned symlink targets and original state bytes. On a
crash, the next mutating command calls `recover`: an uncommitted journal rolls back; a journal whose
state files reached their recorded committed hashes rolls forward cleanup. Recovery is idempotent.
`check` reports a pending/recoverable journal but remains read-only.

### TUI

Bare `grimoire` opens the basic TUI. It has Project and Global tabs; Project also shows inherited
global skills read-only. The primary tree is:

```text
source
├── packs
│   └── pack
│       ├── required skill (locked on)
│       └── optional skill (toggle)
└── skills
    └── loose skill (toggle)
```

Pack selection is tri-state: off, partially selected because optional members are excluded or
unavailable, or fully selected. Required members cannot be toggled independently. A skill requested
by several roots shows every root. Missing members, source/name collisions, untrusted candidates,
live sources, drift, project/global shadowing, and read-only inherited entries appear inline.

Toggles modify only an in-memory staged manifest. A plan pane shows exact manifest, lock, source,
trust blocker, fetch, link, and removal effects. Apply submits one transaction through the core;
cancel or quit discards staged edits. Source fetch and update are explicit actions and never run in
the background. Trust-all requires a dedicated confirmation view and cannot share the ordinary
apply shortcut.

### Output and exit classes

Human output is concise text. Plans and primary results go to stdout; diagnostics go to stderr.
Only `source info --json` is a stable machine format in v1. Commands use these exit classes:

| Code | Meaning |
|---|---|
| 0 | success, valid no-op, dry-run with an applicable plan, or user-cancelled prompt |
| 1 | read-only findings (`check`, degraded `list/info`) without an operational failure |
| 2 | command usage, missing scope/init, malformed manifest/lock/pack, or invalid requested name |
| 3 | safety/policy blocker: trust, collision, missing required member, frozen mismatch, stale plan, ownership, or destructive non-TTY confirmation |
| 4 | source transport, authentication, offline miss, or Git failure |
| 5 | local I/O, transaction, recovery, or invariant failure |

When several failures exist, the highest-safety applicable class wins in the order 5, 4, 3, 2, 1.
A cancelled destructive prompt explicitly prints `Cancelled; no changes applied.`

## Verification

The hard cut is complete only when the old and new models cannot coexist accidentally.

### Format and discovery

- Golden tests accept only `grimoire/pack@1`, sequence-valued members, pure-bundle semantics, and
  valid slugs; they reject every former format/face/version shape and unknown key.
- Fixture repositories prove deterministic recursive discovery, ignored directories, nested
  checkout and symlink boundaries, duplicate failures, depth/entry caps, and packs located away
  from skills.
- Parser fixtures prove the 64-KiB, 4,096-node, and depth-16 frontmatter ceilings; rejection of
  duplicate keys, aliases, anchors, tags, merge keys, non-string mapping keys, and invalid owned
  fields before trust; and acceptance-but-ignoring of bounded ordinary unknown `SKILL.md` fields.
- Pack resolution proves missing-required blocks, missing-optional degrades, exclusions affect only
  optional members, shared requests refcount, and cross-source/nested-pack references fail.
- Canonical hashing is stable across traversal order and catches content, mode, and internal-link
  changes.

### Sources, store, and trust

- Local bare remotes prove fetch alone never changes locks or links, while one source update can
  explicitly change several downstream skills in one plan.
- Pinned local tests modify the origin after install and prove installed bytes/targets do not move.
  Dirty pinned sources fail; live sources move immediately, require trust-all, and fail frozen mode.
  Repeated unchanged live inspection reuses its review export; changed content produces a new
  review key without creating an immutable store snapshot.
- Offline frozen tests pass with a populated store and fail without the exact snapshot without
  attempting network access.
- Malicious Git-tree fixtures prove traversal, special entries, case collisions, escaping symlinks,
  filters, hooks, LFS, and submodules cannot execute or escape materialization. Review-export
  fixtures prove invalid UTF-8 names, case collisions, and host-unrepresentable paths still produce
  a lossless index and content objects without creating unsafe paths. Transport tests reject
  `ext::`, `file://`, custom helpers, embedded passwords, and unknown schemes before the Git runner
  receives a command, and prove SCP home-relative identities remain distinct from absolute SSH-URI
  identities.
- Trust tests prove registration is not approval; an exact receipt survives reuse of the same
  snapshot but not a changed commit/tree; trust-all admits a future candidate but does not update
  it; URL identity changes lose trust; `--yes` grants none; revoke affects every alias sharing the
  identity. Candidate tests move a branch after exact trust and prove `update` applies the reviewed
  cached candidate without fetching; a concurrent explicit fetch instead makes the plan stale.
  Separate scope/alias candidate fixtures track different refs for one identity, reject declaration
  hash mismatches, derive snapshot/review keys and review paths from the minimal record, and prove
  stale fetch publication cannot overwrite a newer declaration.
  Live trust-all tests prove no exact receipt is written and later content is diffed against the
  explicit approval baseline. Removing the final alias leaves trust listable and revocable by
  source key.
- `source-info@1` JSON goldens cover executable bits, UTF-8 and raw-byte shebangs and symlink
  targets, sizes, binaries,
  internal/escaping symlinks, submodules, hashes, packs, missing members, validation, invalid-path
  base64 details, source-root versus skill-root path bases, review-index locations, and all trust
  states without safety verdict language. Inventory goldens include invalid UTF-8 paths and prove
  their raw bytes contribute deterministically to receipts.
- Review-export tests prove executable bits are cleared and symlinks/submodules are represented only
  as indexed facts. Store-integrity tests mutate a stored skill and prove both apply and `check`
  reject its digest before linking or reporting a healthy install. Fault injection between each
  quarantine-swap step proves corrupt replacement restores or completes without exposing mixed
  content.

### State, plans, and transactions

- Manifest round trips preserve comments and unknown whitespace while making the smallest targeted
  edit. Lock goldens are byte-for-byte deterministic and contain no machine-specific store path.
- Lock goldens distinguish excluded, enabled-and-available, and enabled-but-unavailable optional
  members; inventory-digest goldens pin the exact `source-inventory@1` byte grammar and prove human
  finding-message changes do not affect receipts.
- An old alpha lock at the active path fails with the hard-cut deletion instruction; no migration
  or fallback reader is linked into the production binary.
- Project discovery tests nearest-parent, nested projects, explicit project paths, no-project
  errors, and independent global/project shadowing.
- Planner parity tests feed the same `Request` and `WorldState` through CLI and TUI adapters and
  assert identical actions, blockers, and destructiveness.
- Ownership tests cover absent, exact, foreign symlink, regular file, directory, altered owned link,
  and project/global isolation. No test path invokes force/adopt behavior because none exists.
- Fault injection at every journal step proves rollback before commit, roll-forward cleanup after
  commit, idempotent recovery, stale-plan refusal, candidate create/remove recovery, and independent
  project/global concurrency.
- Prune fixtures retain every uncertain or referenced snapshot and delete only a fully proven
  unreachable snapshot after destructive confirmation. Missing-project fixtures protect their
  last-observed snapshot keys, and concurrent apply/prune tests prove the exclusive store lease
  prevents deletion before a new lock reference commits.

### CLI and TUI

- CLI integration tests cover every grammar production, scope flag conflict, help-before-environment
  behavior, exit class, TTY/non-TTY confirmation, cancellation, dry-run, frozen, and `--yes` limits.
  They reject `--frozen` on operand installs, uninstall, and update, and reject `--yes` on trust
  grants.
- End-to-end temp-home tests initialize a project, add/fetch/info/trust a remote, install a skill and
  pack, toggle a pack exclusion through the TUI state machine, reproduce from the committed lock
  offline, then explicitly fetch, inspect/diff, trust, and update one cached multi-skill source
  snapshot without an update-time fetch; they also uninstall roots with shared-member retention,
  detect drift, and prune.
- Ratatui `TestBackend` tests render Project/Global tabs, the source/pack/skill tree, tri-state packs,
  locked required members, inherited globals, collisions, missing dependencies, untrusted/live
  labels, and the exact plan pane. A human terminal pass verifies navigation, staging, apply,
  cancellation, resizing, and terminal restoration.
- The full workspace test suite and clippy run from the worktree, followed by source-discovery and
  dogfood tests against the root checkout so a nested worktree cannot hide repository-layout bugs.

Every negative security or absence guard above has a red-proof. Tests use injected Git/network
recorders and controlled filesystem canaries; once per guard, the test harness disables the URL,
trust, traversal, ownership, frozen-network, or legacy-schema check and demonstrates that the
corresponding test fails. Boundary tests that assert an obsolete parser or ambient read is absent
must likewise introduce that forbidden dependency in a controlled breaking run. The test record
names the failing arm rather than merely recording a green negative assertion.

The greenfield check is intentional: current agent-specific targets, faced packs, alpha lock
compatibility, local-library configuration, and `install.sh` parity are debts to delete, not
constraints to design around.
