# `roadmap` · the multi-phase decision map

For work too large for one plan: phases with **gates** and **declared blocking
edges**, written once against the approved spec. It sequences execution; it does
not redesign. A design gap found here is an open decision branch — send it back
to a grill on the spec, not a rewrite of the map.

A roadmap is **never executable**. Each phase requires its own `plan` before
that phase can be built. The roadmap never carries task-level detail.

## Procedure

1. **Resolve the spec.** The user names a spec with `status:
   published`. Missing → ask. Founding-shaped files stay `draft`
   and are not this input. `status:` missing / not `published` →
   refuse. An explicit human waive: the caller writes
   `published` on that spec (opportunistic
   `records.sh touch --status published`, else file-mode), notes
   the waive, **then** maps. It does not map against a `draft`.
   Open decision branches → stop; those belong in a grill on the
   spec.
2. **Summon context** per SKILL.md *One environment probe* (build station on a
   workshop host).
3. **Write the map** per `templates/roadmap.md`:
   - **Phases** — each a coherent, independently-valuable slice with: goal,
     scope (in/out), a **gate** (exit criteria that make "done" checkable), and
     risks.
   - **Blocking edges, declared** — which phases require which
     (`requires: phase N`), and which are parallel-eligible. The edges are the
     map's load-bearing content — sequencing follows from them, not from prose
     order.
   - **No task-level detail.** No file lists, no commands, no slice code. If a
     phase needs that, it needs a `plan`.
4. **Land it** per SKILL.md *Shared discipline*. Resolve `plans.md` via the
   project-templates rule, then mint `records.sh new plans --template <resolved>
   --title "<Track> — Roadmap"` when the tool exists; else file-mode from that
   same resolved path into `<agent-records>/plans/`, naming the file
   `YYYY-MM-DD-<slug>.md` (the record shape). Either way set
   `tags: [roadmap]` and replace the body with the roadmap scaffold filled in
   from the resolved `roadmap.md`. Land as `status: draft`. The caller
   writes `published` after a passing host's review they accept.

Output: the roadmap. Terminal step: `plan` the first unblocked phase.
