# `/backlog ticket` — capture-plus-escalation in one motion (a direct ticket)

Open a **direct ticket**: something needs the human *and* it isn't already a tracker entry —
capture and escalation in one motion. A ticket is an **escalation wrapper over a capture kind**,
never a sixth kind: the schema (the installation's `.handbook/rules/RECORDS.md` → *Tickets*) is
the contract this verb executes — frontmatter, body sections, lifecycle, and the promotion bar are
stated there once, not restated here.

**Direct means `origin:` absent by rule.** Wrapping an *existing* entry is `/backlog promote`
(which stamps `origin:` and pauses the entry). If the thing is already filed, promote it; don't
mint a duplicate direct ticket.

## When to use

- A decision, sign-off, ambiguity, or access need surfaces that has **no existing tracker entry**
  and meets the promotion bar (the schema's HITL litmus — promote/ticket exactly when resolving
  would require standing in for the human).
- The user says: "/backlog ticket", "escalate this to me", "open a ticket for the human", "this
  needs my sign-off and it isn't filed anywhere".

**Do NOT use** for anything resolvable without the human (capture it with the ordinary verbs and
keep moving — the default path stays fast; nothing routes through tickets by default), for an
existing entry (`/backlog promote <id>`), or to answer/resolve a ticket (`/backlog close`). On an
**unstamped root** this verb refuses: report `unstamped` and point at the clankshop onramps.

## File + ID (derived, never renamed)

`<root>/.records/tickets/<YYYY-MM-DD>-<slug>.md`, from this skill's `templates/ticket.md`; the ID
is derived by prefixing: `TK-<YYYY-MM-DD>-<slug>`, stated in frontmatter for grep-ability.
**Same-day slug collision:** if the target filename already exists, suffix the slug
deterministically (`-2`, `-3`, …) **before first publication** — file and derived ID together;
never rename after. `TK-` IDs are the only ID legal in cross-installation citations.

## Procedure

1. **Resolve root + date** (`date +%Y-%m-%d`). Confirm the root is stamped (else refuse, above).
2. **Confirm the bar and the kind.** The promotion bar (schema): a *decision*, *sign-off*,
   *ambiguity*, or *access* trigger — multi-session scope alone is not one; tie-breaker favors
   motion. Pick the required `subject_kind` (one of the five capture kinds). If an existing entry
   already covers it, switch to `/backlog promote`.
3. **Write the ticket** from `templates/ticket.md`: frontmatter (`type`/`id`/`status: open`/
   `subject_kind`/`updated`; **no `origin:` line**), then `## Context`, `## Decision needed` (with
   your recommended answer — never a bare question), empty `## Comments`, empty `## Resolution`.
4. **Commit (trunk-side, pathspec-atomic).** Ticket creation writes shared state:
   `scripts/scoped-commit.sh <root> "Ticket <TK-id>: <subject>" .records/tickets/<file>`. A work
   branch cites the `TK-` ID; the ticket itself always lands on the trunk.
5. **Report** the ticket ID, the path, and the decision needed. If the installation mirrors
   tickets, the next mirror-bearing verb (`promote`, `close`, `sync`) pushes it — sync is
   verb-time only, never a daemon.

## Relationship to neighboring verbs

- **`/backlog promote <id>`** — the wrapping sibling: graduates an existing entry, stamps
  `origin:`, pauses the entry. Direct tickets skip all of that by having no origin.
- **`/backlog close <TK-id>`** — the only way a ticket leaves `open`/`answered`: resolve, wontfix,
  or demote, with the writebacks and the done-log line.
- **`/backlog sync`** — pushes/pulls the ticket mirror where one is configured.

## Done when

The ticket file exists with valid frontmatter (no `origin:`), a recommended answer in *Decision
needed*, a derived ID matching its filename (collision-suffixed if needed), landed as a trunk-side
scoped commit — and the chat names the ID, path, and question.
