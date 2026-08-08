# `/clankshop setup` — the greenfield bootstrap

Stand a fresh project up on the clankshop pack: **facts by script, decisions by interview,
projection by doctrine** — then stamp. Greenfield only: a root already carrying content of any
shape (docs, trackers, prior agent scaffolding) belongs to the brownfield onramp (`migrate`, which
classifies what exists instead of assuming nothing does), and a stamped root is already an
installation (`check` validates it; the improvement loop edits it). Whole-system assembly is this
verb and `migrate` alone — roles never bootstrap the system (the pre-stamp dispatch table,
`doctrine/README.md`).

Patient-zero note: in the grimoire library itself this verb is exercised only against throwaway
temp-dir fixtures — never against the library's own front door.

## Preconditions

1. **Resolve the root**: `scripts/install-block.sh resolve <session-path>`. Expected: `unmanaged`,
   or an unstamped repo root. A stamped root → refuse and point at `check` — re-setup is never the
   fix. A resolved *enclosing* installation → this project is already inside one; stop and surface
   that.
2. **Greenfield check**: the root has no substantive pre-existing process content (tracker-like
   files, record stores, agent scaffolding of any convention). Anything of the kind → stop and
   route to `migrate`; setup never classifies existing content.
3. **A git repo.** No repo → offer `git init` first; the seeded rules are trunk-anchored and the
   stamp lives in a committed door.

## Step 1 — facts by script

`scripts/interrogate.sh <root>`: gate-command candidates from package manifests, trunk name,
remote + issue-system presence, the `.gitmodules` inventory, doc landmarks. Facts only — nothing
here decides anything.

## Step 2 — interview (only genuine decisions)

One question at a time; never ask what a fact already answered. The genuine decisions:

- **The gate** — the one command that must be green before any commit. Confirm from the
  candidates; several candidates (or none) is exactly the judgment the human owns.
- **Lanes** — the four seeded lanes (patch, bug, feature, spike) deploy by default; the decision
  is any lane the project genuinely lacks or adds, and the entry point where facts leave a choice.
- **Submodule opt-ins** — per `.gitmodules` entry: managed under this installation (joins the
  submodule index and coverage) or independent (its own future installation)?
- **Mirror on/off** — asked only when an issue system exists: mirror tickets to it? Record the
  choice as a standing judgment (a POL entry with its rationale). No remote or no issue system →
  no question, no mirror, no behavior change.

## Step 3 — project the doctrine through the facts

Source: this skill's `doctrine/` at its current `doctrine-version` (declaration blocks carry it).
**Minimal-seed filtering** — universal content deploys, everything else stays upstream: INVARIANTS
seeds only its universal parameterized rules; GOTCHAS and POLICY deploy as declared-empty formats;
RECORDS deploys complete (formats are not project-variable) — **via the records instrument's
projection writer**, `skills/backlog/scripts/records-projection.sh <root> <doctrine-dir>
gate=… trunk=…`, which stamps it `built-against: clankshop-doctrine@<doctrine-version>` (the
authority chain: the doctrine states the schema, backlog executes it, the stamped projection is
its writing — setup never writes the file by hand); ROUTING deploys whole; the opted-in
lane files and the three testing skeletons deploy with their parameter slots (`<gate>`, `<trunk>`)
filled from steps 1–2. No generic prose ships.

**Every seeded entry is provenance-stamped** (the projection protocol — frozen as Appendix J of
the rollout plan; grammar and retrieval in `doctrine/BASES.md`):

- a one-line entry (INV) appends its marker: `⟨clankshop:INV-4 @v1⟩`;
- a heading-led entry (G/POL — none seed today, the encoding stands) carries `origin:` +
  `origin-version:` lines under the heading;
- a whole-file asset (each lane and testing file) carries `origin:` + `origin-version:` keys in
  its declaration block (path-qualified origin: `clankshop:workflows/patch`).

Targets:

| target | gets |
|---|---|
| `.handbook/rules/` | ROUTING, GOTCHAS, INVARIANTS, POLICY, RECORDS |
| `.handbook/workflows/` | the opted-in lanes (seed: patch, bug, feature, spike) |
| `.handbook/testing/` | GATE (names the confirmed gate), PIPELINE, DIAGNOSTICS |
| `.handbook/design/` | created empty — content is the design role's, never seeded |
| `.records/trackers/` | `tasks.md`, `issues.md`, `feedback.md`, `bugs/`, `notes/` — empty stores in wire format |
| `.records/tickets/`, `.records/done/log.md` | the escalation store and the done log, empty |

Other record stores (plans, adr, design, audit, reports, archive) are created by their owning
members on first use — setup seeds only what the doctrine and the records schema define.

## Step 4 — the door, the maps, the registrations

- **`AGENTS.md`** (create, or extend a bare existing door): the **compiled tier-0 table** from the
  door profile (`doctrine/README.md`) — keep only rows whose owning member is installed — with the
  **one shared fallback line** beneath it. The table is a stamped projection of the deployed
  `.handbook/rules/ROUTING.md`; lane paths stay in ROUTING's dispatch rows, never duplicated into
  the door.
- **Each installed member's door registration block**: body copied **verbatim** from the door
  profile's frozen bodies, between that member's own `<!-- skill:<name> -->` delimiters, stamped
  `built-against: clankshop@<pack-version>`. Created-or-adopted, never edited inside another
  writer's delimiters. Without these blocks, `check`'s `unregistered` fact can never be empty on a
  fresh setup. Core bodies carry no `Edges:` lines; helpers register under their own independence
  protocol; an optional proxy registers only when installed.
- **The two-region stewardship maps**: `.handbook/README.md` + `.records/README.md` — a short
  authoritative preamble (one stewardship line per chapter, never reading order) plus one
  delimited steward block per producer, each stamped `built-against:` its input (a core member's
  block: `clankshop@<pack-version>`).
- **The submodule index** (only when `.gitmodules` exists): the composer's own delimited block in
  the door, opted-in rows only, stamped against `.gitmodules` + the gitlink SHAs.

## Step 5 — stamp

Last, after everything above is on disk:
`scripts/install-block.sh write <root> 1 clankshop <pack-version>` — `layout: 1`, the pack
version read from the manifest (this pack's `PACK.md` frontmatter `version:`). The stamp is the
commit point: an
unstamped root is unmigrated, and framework verbs refuse until the block exists — stamping first
would license every verb against a half-built installation.

## Verify

Run the assembly validation (`check`) — a fresh setup must come back green: no `unregistered`
members, every stamped projection matching its named input, chapter presence per the registry,
empty stores in wire format. The projection walk itself is proven mechanically by the pack's
onramp fixture harness; this verb's judgment (interview, filtering) is exactly what the fixture
does not automate.

## Done when

The root is stamped (`layout: 1`, `pack: clankshop`, `pack-version:` current); `AGENTS.md` carries
the compiled table + fallback line, every installed member's registration block, and the submodule
index when applicable; `.handbook/` holds the four chapters with every seeded entry
provenance-stamped; `.records/` holds the tracker skeleton, tickets store, and done log; the
stewardship maps stand in both roots; and `check` is green.
