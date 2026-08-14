# Pack Format Specification

**Format revision:** 1 · **Status:** draft 5 for review (2026-08-08; drafts 1–2 revised against
two independent implementer reviews, drafts 4–5 against owner review — see
`docs/design/2026-08-08-pack-format-design.md`) ·
**Design record:** `docs/design/2026-08-08-pack-format-design.md`

A **pack** binds agent skills into an installable, versioned system. This spec defines the pack
manifest (`PACK.md`), the pack lock (`grimoire.lock`), install/remove/check semantics, and the
conduct requirements for pack-based skills. It is an **overlay** on the open agent-skills
ecosystem (the Vercel `skills` CLI format): every pack repo is a plain skills repo first, and
the mechanisms here degrade gracefully for tools that have never heard of packs (§8, including
the limits of that guarantee).

Keywords MUST / SHOULD / MAY read per RFC 2119. "Tool" means pack-aware software (the grimoire
TUI, `install.sh`, any future implementation). "Plain CLI" means pack-unaware skills tooling
(`npx skills`, qntx `skills-cli`, and compatible). "Discovery" means the ecosystem's de facto
skill-discovery procedure, summarized normatively in Appendix B.

## 1. Identity & layout

Two pack shapes exist:

- **Faced pack (the normal shape): a skill directory that also contains a `PACK.md`.** The
  directory's `SKILL.md` is the pack's **face**: its agent-facing front door, discovered and
  installable by plain CLIs as an ordinary skill. The face and the pack directory are one
  artifact — one install unit, one lock entry (§3). A faced pack directory MUST NOT contain
  further `SKILL.md` or `PACK.md` files below it (packs do not nest), and its members live
  *outside* it, elsewhere in the repository.
- **Faceless pack (pack-as-repo only): a `PACK.md` at a repository root with no sibling
  `SKILL.md`.** This is a **manifest-only** pack: the repository root is *not* a skill
  directory, no pack-directory artifact installs, and the pack's members are the repository's
  discovered skills named in the manifest (which necessarily live beneath the root — the
  no-nesting rule applies to faced pack directories, not to a manifest-only root). A faceless
  `PACK.md` anywhere other than a repository root is invalid (it would be undiscoverable).

Rules common to both shapes:

- `name:` in `PACK.md` frontmatter is **authoritative** for pack identity. A face `SKILL.md`'s
  `name:` MUST equal the manifest's (validators MUST error otherwise).
- Two manifests in one repository declaring the same `name:` are invalid. A faceless pack MUST
  NOT list a member whose name equals its own `name:` value.
- **Pack enumeration is a full-depth operation:** tools enumerate packs by scanning the
  repository's skill directories at full depth (Appendix B) for `PACK.md` siblings, plus the
  repository root. Ordinary (non-full-depth) discovery governs only what plain CLIs see.

## 2. The manifest: `PACK.md`

YAML frontmatter is the machine surface; the Markdown body is the pack's runbook — author
territory that tools MUST ignore and SHOULD never rewrite. A tool that must rewrite a manifest
MUST preserve the body byte-for-byte and MUST preserve unknown frontmatter keys (semantic
preservation; formatting of the frontmatter block MAY normalize).

```yaml
---
name: clankshop                 # required. Pack identity. [a-z0-9-]+
version: 1.0.0                  # required. Semver 2.0.0 of this pack release.
description: "One-line summary" # required.
required: journal               # required members — bare skill names, comma-separated.
optional: bug, task, scheduler  # optional members — default-installed, removable without trace.
---
```

**Grammar.** `required:` and `optional:` are single YAML string scalars. After YAML decoding,
the scalar is split on commas; each token is trimmed of ASCII whitespace and MUST be a skill
name matching `[a-z0-9-]+` (empty tokens are invalid). `required:` MUST name at least one
member. A name appearing twice anywhere across the two lists is invalid. `version:` MUST parse
as semver 2.0.0. Duplicate YAML keys are invalid.

- **Member references** are bare skill names resolving against the **same repository's**
  discovered skills (Appendix B). Cross-repo references are not part of format 1. A manifest
  naming an unresolvable member is **invalid**.
- The face skill is implicitly a member and MUST NOT be listed.
- **Unknown frontmatter keys** MUST be ignored (and preserved per above). Future format
  revisions claim them.
- **`format:` is optional; absent means format 1** — format-1 manifests SHOULD simply omit it.
  When present it MUST be a positive integer naming the pack-format revision the manifest
  targets; it bumps only on breaking change, and a future breaking revision will require
  declaring it. A tool encountering a `format:` value it does not implement MUST NOT install,
  upgrade, or otherwise act on that manifest; it MAY still enumerate and display the pack.
  (Removing an *already-installed* pack is governed by the lock, not the manifest, and remains
  permitted.)

## 3. The lock: `grimoire.lock`

Pack state lives in a **sidecar lock owned by this spec** — never inside the ecosystem's
per-skill lock files (`skills-lock.json`, `~/.agents/.skill-lock.json`), which remain the
untouched per-skill authority (their schemas are closed: foreign keys are dropped on rewrite).
The lock is named for the format, not the payload — any spec-conforming tool writes the same
file (the `Cargo.lock`/`flake.lock` convention). Content is JSON.

**Scopes.** Two lock scopes exist, mirroring the ecosystem's:

- **Project:** `<project-root>/grimoire.lock`, where the project root is the directory the tool
  is operating on (the same root the ecosystem's `skills-lock.json` would live in).
- **Global:** `~/.agents/grimoire.lock`.

Every pack operation (install/remove/check) targets **exactly one scope**: the operation's
member installs, collision checks, reference counting, and lock writes all happen within that
scope's skill locations (project-scope skill dirs, or the global/user ones — the same split the
ecosystem's tooling uses). Reads that answer "is pack X present?" consult the target scope
first and MAY fall through per pack name to the other scope for display purposes. For
pack-based skills' reads, project shadows global per pack name.

```json
{
  "version": 1,
  "packs": {
    "clankshop": {
      "version": "1.0.0",
      "source": "github:cmdruid/grimoire",
      "ref": "a1b2c3d",
      "installedAt": "2026-08-08T00:00:00Z",
      "skills": {
        "clankshop": { "hash": "sha256:…", "required": true },
        "journal":   { "hash": "sha256:…", "required": true },
        "task":      { "hash": "sha256:…", "required": false }
      }
    }
  }
}
```

- `source` is the canonical origin. GitHub origins (shorthand, HTTPS, SSH) normalize to
  `github:<owner>/<repo>`; other git URLs and absolute local paths are recorded verbatim.
  `ref` (optional) records the commit or tag actually installed, when known. The pair is what
  update flows resolve against; local-path sources update from disk.
- `skills` records **what is installed**, one entry per installed member, keyed by skill name.
  For a faced pack, the pack directory (face + `PACK.md` + support files) appears under the
  pack's own name. For a faceless pack there is no pack-directory entry — and the tool MUST
  cache the manifest's machine surface into the lock entry (a `manifest` object holding the
  decoded frontmatter) so `check` never depends on the remote source.
- `hash` is the member's content hash at install time (Appendix A).
- The member `required` flag records the member's classification **at install time** and is
  authoritative for installed state; a later manifest edit reclassifies nothing until the pack
  is upgraded (§5).
- **A pack's lock state is one bit: entry present, or no entry.** The install transaction (§5)
  guarantees an entry is written only for a fully installed pack; there are no partial or
  pending sub-states in the lock. Whether the pack's *system* has been set up is not lock
  state — setup is the face's business (§6) and its marker is pack-defined (§7).
- The lock records **content facts only**. Per-agent placement (which agent directories a
  skill was linked into) is the ecosystem locks' domain, not this file's.
- Tools are the lock's only writers. **Pack-based skills read it, never write it** (§7).
- Unknown keys: ignored and preserved, as §2.
- A tool encountering a lock `"version"` greater than it implements, or a lock it cannot
  parse, MUST treat the file as read-only, surface the fact, and refuse operations that would
  rewrite it.

## 4. Versioning

- **Packs** version by **semver** (`version:`). One release = one *published* content state of
  all members shipping in the repo.
- **Members are not individually versioned.** A pack pins members by **content hash** in the
  lock at install time.
- **Hashes are authoritative over version for installed content.** Adoption (§5) and re-pin
  can legitimately record bytes that differ from the published release; the lock's hashes are
  the truth about what is installed, and the `version` is the release the install *derives
  from*. There are no member version ranges in format 1.
- A hash mismatch against the lock means *moved since install* — a fact for `check`, not an
  error. **Re-pin** = accept the bytes currently on disk and update the target pack's lock
  entry (only that entry; other packs sharing the member keep their own expectations — §5).
  Restoring the recorded release instead is a reinstall against `source`+`ref`.

## 5. Install, remove, check

**Install is transactional** — a pack never half-installs:

1. **Preflight:** the manifest is valid (§2); every required member resolves. **Collision
   predicate:** an incoming member's name is already installed in the target scope with
   different content (hash inequality) — the prior source is irrelevant; byte-identical
   content is no collision. Preflight failure aborts by default. A tool MAY resolve a
   collision interactively — **adopt** (accept the existing on-disk skill as this member; its
   current bytes are hashed into the lock) or **replace** (swap in the pack's member) — but
   resolution MUST NOT be silent. The pack-directory member (face) is never adoptable: it MUST
   come from the pack's source.
2. **Install members** via ordinary skill-level machinery (which maintains the ecosystem's own
   locks per skill, as it would for any install). Replaced content is staged, not destroyed.
3. **Write the lock entry** (§3). The transaction commits here; staged content may now be
   discarded.
4. **Surface the face** (faced packs): after commit, the tool SHOULD point the user at the
   pack's face — the front door, and where any system setup lives (§6). Tools MUST NOT execute
   anything on the pack's behalf.

Any failure before step 3 completes → rollback: newly installed members are removed, staged
(replaced) content is restored, and both lock families return to their pre-transaction
observable state. After commit, replaced content is gone — a later removal does not resurrect
it. Tools SHOULD stage work so that a crash mid-transaction leaves either the prior state or a
state `check` reports as *broken* — never a silently plausible partial pack.

**Reinstall / upgrade.** Installing a pack whose name already has a lock entry in the target
scope is a transactional replace of the whole pack: members added by the new release install,
members no longer listed are removed (subject to the reference count below), and the user's
recorded optional selections carry over — an optional member absent from the lock stays
uninstalled. When the version moves backward or the source changes, the tool MUST surface that
fact — never silent.

**Remove:** delete members not referenced by another installed pack's lock entry **in the same
scope** (reference counting at pack altitude), then drop the lock entry. A member that was
`adopt`ed at install is owned by the pack thereafter and removes like any other. Removing
individual **optional** members leaves no trace: drop the member entry from the lock, remove
the skill if unreferenced (an uninstalled optional member MAY be reinstalled later from the
pack's source). A missing optional member is never drift. Removing a **required** member of an
installed pack (by hand or plain CLI) is not a tool operation this spec defines — it is a
state `check` reports as *broken*. When removing a pack, the tool MUST surface — **before**
deleting anything — that pack setup artifacts may persist in the project (setup is pack-side
and not machine-declared — §6), and SHOULD relay the face's teardown guidance while the face
still exists (markers are pack-defined — no tool can find them once the pack is gone; a
`teardown:` lifecycle key is reserved for a future revision).

**Shared members.** Two packs MAY both reference an installed skill; the refcount governs
removal. If their locks record different hashes for it, `check` reports the mismatch against
each lock's expectation; format 1 defines no resolution (last install won the bytes on disk).

**Check** compares the target scope's lock against that scope's installed skills, consulting
each pack's installed manifest (faced: the `PACK.md` in the installed pack directory;
faceless: the manifest cached in the lock — §3). It reports facts, not verdicts:

| Fact | Meaning |
|---|---|
| required member missing | *broken* — offer reinstall |
| member hash ≠ locked hash | *moved since install* — offer re-pin or reinstall (§4) |
| optional member absent | *fine* |
| faced pack's installed manifest missing (pack dir gone/mangled) | *orphaned* — offer removal or reinstall |

`check` needs neither network access nor the pack's source; every input above is local.
Deeper system validation (are the pack's own setup artifacts coherent?) is the pack's
business — packs MAY expose their own check verbs through the face; this spec's `check` does
not attempt it (markers are pack-defined and not machine-declared).

## 6. Lifecycle

- **Format 1 declares no lifecycle keys.** System setup is the pack's own business, carried by
  the **face**: a pack that needs setup puts it in its face `SKILL.md` — the front door every
  install path delivers, including a plain-CLI install of the face alone. Tools never run or
  track setup; they point at the face (§5) and nothing more.
- **Setup is pack-scoped and atomic.** The face's setup orchestrates whatever member wiring the
  composition needs — for **all** members, as one all-or-nothing act: a complete system or a
  clean refusal, never a partial projection. The spec defines no per-skill setup, and
  `SKILL.md` frontmatter is not this spec's surface to extend; how the face does it is the pack
  author's business.
- A **faceless** pack has no setup vehicle in format 1: it is a manifest-only skill bundle.
- Lifecycle keys in `PACK.md` (`setup:`, `teardown:`, `check:`, …) are **reserved** for future
  revisions; authors MUST NOT repurpose them.

## 7. Pack-based skills

A **pack-based skill** is a member written for its pack's system rather than for standalone
use. The format does NOT require members to be individually useful bare — the pack is the unit
of usefulness. §7 is **author-facing conduct**: nothing in the manifest machine-declares which
members are pack-based, so tools cannot enforce these clauses; validators MAY check them
heuristically (e.g. guard-clause presence).

- **Guard clause (the tripwire) — MUST.** A pack-based skill opens by cheaply detecting whether
  its pack's system is present in the current context, and on absence fails gracefully in one
  breath: state that it is part of pack `<name>` and point at the pack's face, where setup
  lives (§6) — or, for a faceless pack, name the pack. No partial execution against a system
  that isn't there.
- **The marker is pack-defined.** The guard checks the artifact the pack's own setup creates
  (e.g. a stamped installation block). It MUST NOT gate on `grimoire.lock` — the stamp survives
  every install path (including plain-CLI installs + hand-run setup); the lock only exists
  where a pack-aware tool acted.
- **Guard vs. self-healing.** The guard governs the *system marker*: marker absent → graceful
  refusal, full stop. Lazy use-time self-healing is legitimate only *inside* a stamped system —
  repairing or scaffolding sub-artifacts the marker's system implies. A skill MUST NOT
  self-heal its way past an absent marker.
- **Lock-aware — SHOULD.** When `grimoire.lock` is present (project scope shadowing global,
  §3), a pack-based skill SHOULD read it for pack facts — its pack's version and member
  set — rather than rediscovering them. It MUST tolerate the lock's absence, and MUST NOT
  write it.
- **No install-time self-setup — MUST.** Members do not bootstrap at install (§6).
- **Face exception.** The face skill MUST NOT carry the tripwire: "pack not installed" is its
  welcome case — it explains the pack and points at setup.
- A member shipped by multiple packs of one repository guards on the marker of whichever of
  its packs' systems it requires; authors owning such members define that choice.

Beyond these, member conduct is unspecified.

## 8. Graceful degradation & limits

Behavior of pack-unaware tooling:

| Action by a plain CLI | Result |
|---|---|
| Discover the repo | Sees all skills, including faces and pack-based members, as ordinary atoms |
| Install the face | Gets the pack's front door; `PACK.md` and support files ride along as the skill directory's payload; the face explains the rest |
| Install a pack-based member solo | Valid install; the member's guard clause fails gracefully at invocation |
| Rewrite its own locks | `grimoire.lock` is not touched (§3) |
| Read `PACK.md` | Ignores it (not a `SKILL.md`) |

The payload guarantee assumes the plain CLI installs skill directories whole (the de facto
behavior verified against the reference implementations). A CLI that filtered unrecognized
files would deliver a face without its manifest — the face still speaks, but that install is
degraded to a plain skill: pack-aware tools cannot enumerate or check it as a pack.

**Limits (format 1) — stated, not solved.** The sidecar being *untouched* is not the same as
*still true*: a plain CLI can add, update, or remove individual members underneath an installed
pack, producing states no pack release describes. The guard clause is a **bootstrap gate**, not
an integrity system — a stale or surviving marker (e.g. after removing members or a whole pack;
format 1 has no teardown key) can let pack-based skills run against a partial system. `check`
(§5) is the integrity instrument: it exists precisely to surface these states as facts. Skill
names are flat in the ecosystem; two sources can overwrite each other's same-named skills, and
the lock records that only as a hash mismatch — reference counting likewise cannot see
installs made outside any pack, so removal MAY delete a skill a plain-CLI user considered
theirs (adopt records no prior owner). Pack-aware tools MAY hint pack membership when a member
is installed or removed solo (membership is declared in the manifest); this is a courtesy, not
a mandate.

## Appendix A — member content hash (normative)

Byte-identical to the ecosystem's skill-folder hash (verified against the Rust and TypeScript
reference implementations):

1. Walk the skill directory recursively. Skip directories named `.git` or `node_modules`.
   Include regular files only (symlinks and other entry types are skipped, not followed).
2. For each file, form its path relative to the skill directory root, with `/` as separator on
   all platforms; pair it with the file's raw bytes. Path bytes are used as the platform
   provides them (no Unicode normalization).
3. Sort pairs by relative path (lexicographic byte order).
4. SHA-256 over the concatenation, per pair in order, of the path's UTF-8 bytes followed by the
   file's bytes. No delimiters, lengths, or terminators are added.
5. Render lowercase hex. The lock stores it prefixed `sha256:`.

Properties inherited from the ecosystem algorithm, accepted for compatibility: the encoding is
not collision-resistant against adversarial layouts (path/content boundaries are unframed) —
the hash is a drift detector, not a security boundary; and because symlinks are skipped, two
installs that materialize the same content differently (copied vs. linked) can hash alike
while a CLI that dereferences symlinks into real files changes nothing — but content delivered
*only* via symlinks is invisible to the hash.

## Appendix B — discovery (normative summary of the de facto ecosystem procedure)

A skill directory is a directory containing `SKILL.md`. Discovery over a repository:

1. If the repository root is itself a skill directory, it is the sole discovered skill —
   unless a full-depth scan is requested.
2. Otherwise scan the fixed priority directories one level deep — the root itself, `skills/`,
   and the per-agent skill directories recognized by the ecosystem's reference implementations
   (`.agents/skills`, `.claude/skills`, `.codex/skills`, `.cursor/…`, and peers) — collecting
   each child skill directory.
3. If nothing was found, or a full-depth scan is requested, fall back to a recursive scan
   (bounded as the reference implementations bound it).

Conforming tools MUST match the reference implementations' discovery behavior; where this
summary and their behavior diverge, the reference implementations govern. A skill's identity is
the `name:` in its `SKILL.md` frontmatter (directory name as fallback). First-seen wins on
duplicate names within one discovery pass. Pack member resolution (§2) resolves bare names
against a **full-depth** pass over the pack's own repository (§1); nested `SKILL.md`s below a
faced pack directory are invalid (§1) and not resolvable members.
