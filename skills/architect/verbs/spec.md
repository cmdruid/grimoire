# `spec [doc]` — synthesize, grill the gaps, argue the result

Produce the **argued specification** — concrete enough that a gap between
design and code is detectable, and measurable once found. Start from a
`brainstorm` draft, an existing doc, or the conversation itself.

If `[doc]` is named, classify it **before** the steps below. Resolve `.agents/skilldata` through
SKILL.md *Project homes*. A regular non-symlink Markdown file beneath the canonical
`.agents/skilldata/architect/drafts/` home whose body follows
`templates/draft.md` is a workspace draft. Otherwise apply SKILL.md *Founding-shaped* exactly:
founding-shaped → synthesize into the six map H2s on that same file; run `grill` on those sections;
do not write Problem / Goal / Approach as H2s; skip the records mint, `templates/specs.md` rewrite,
and status promotion. Refuse the otherwise-case. Never scan cwd.

Feature `spec` mints or rewrites a `specs/` record (SKILL.md destination).
Founding-shaped stays on the named file.

## Procedure

1. **Synthesize first** — assemble everything already decided (conversation,
   draft, prior ADRs) into the spec's shape before asking anything. From a workspace draft, carry
   forward settled decisions and links to completed spike records that the design actually relies
   on. Do not copy raw spike notes, transient experiment code, or exploratory chatter.
2. **Resolve material gaps** — use `grill` only for choices that change scope,
   mechanism, safety, compatibility, or acceptance. Keep non-blocking uncertainty
   labeled instead of forcing a premature answer.
3. **Write the spec** per `templates/specs.md` (skip this reshape when the
   named file is founding-shaped): **Problem** (root need, not a
   surface knob), **Goal**, **Approach** (include rejected alternatives only
   when a real fork informed the choice), **Mechanism** (concrete enough to
   detect design drift), and **Verification** (how we'll know it works). Create
   an ADR only when the caller wants an independently durable decision or the
   decision has a lifecycle distinct from this spec. When a numeric target is
   load-bearing and its metric population is ambiguous, sample the population
   and name the mechanism or class being measured.
4. **Self-review** — run this package's `scripts/ground-check.sh`
   `<root> <doc>` (`<root>` is `git rev-parse --show-toplevel` of the
   checkout that holds the doc; resolve the script from this skill's own
   base directory). Unresolved refs are facts, not a refuse: re-read or
   rewrite those paths. A resolving reference can still point at the wrong
   code — re-read the load-bearing signatures the claims rest on. Then
   placeholders, internal contradictions, scope, and material ambiguity. When
   the mechanism works around a questionable legacy constraint, check whether
   deleting that constraint would be simpler; do not run this inquiry when no
   such constraint is shaping the design.
5. **Promote a workspace draft after the spec exists.** First create or update the
   `architect/spec@1` record and verify its dated path. Only then change the source draft's body
   disposition to `promoted`, add the returned `→ specs/<file>.md` link under Related records, and
   save it through `scripts/architect-artifacts.sh draft-save`. If spec creation fails, leave the
   draft active. Existing draft spec records remain ordinary spec inputs and are never converted
   into workspace drafts.
6. **Return the spec.** Give the human its path and name any material
   uncertainty. Independent review is useful when the caller requests it, a
   consequential uncertainty remains, or the design crosses a high-risk
   boundary. Otherwise the caller may accept it directly. The artifact stays
   `status: draft` until the caller chooses to publish it (the superseded spec,
   if any, closes `--as superseded` naming its successor).

Output: the argued spec. Tell the human where it is, then stop.
Implementation sequencing is a different job.

## Done when

The argued spec is on disk at `status: draft` (founding-shaped: the named
file, still `draft`, still founding-shaped). A workspace source draft, when used, was marked
`promoted` and linked only after that spec path existed. Ground-check ran on the spec.
The human was told the path and any material uncertainty. No `published` write. No
successor skill invoked.
