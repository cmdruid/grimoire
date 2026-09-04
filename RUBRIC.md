# Lean skill audit rubric

Audit the skill against one ordinary bounded task and one genuinely high-risk task. Follow its
instructions literally.

Assess each dimension as:

- **Good:** Proportional and helpful.
- **Needs work:** Adds friction without clear value.
- **Harmful:** Expands scope, duplicates authority, or obstructs the task.

## Scope fidelity

- Does the skill establish the requested outcome, affected surface, non-goals, and acceptance
  evidence?
- Can a finding or downstream step silently widen that boundary?
- Does adding an unnamed subsystem require direct causal evidence?

**Harmful:** Adjacent cleanup becomes required work.

## Default-path weight

- What is the shortest path through the skill?
- Is ordinary bounded work treated as ordinary?
- Is exhaustive analysis reserved for explicit `deep` or `formal` use?

**Harmful:** The default behaves like the highest-risk case.

## Approval economy

- Does each approval correspond to a real user decision?
- Does the original request already authorize the expected action?
- Does metadata record authorization rather than manufacture another approval?

**Harmful:** The user must repeatedly approve the same scope.

## Artifact economy

- Does every file or record have a durable purpose?
- Could conversation or an existing artifact carry the same information?
- Is lifecycle metadata required only when lifecycle management is genuinely useful?

**Harmful:** Work cannot proceed until ceremonial records are minted or promoted.

## Proportional verification

- Does verification target realistic failure modes?
- Are mutation tests, exhaustive sweeps, independent review, and full regrounding conditional on
  risk?
- Can a small change use focused checks?

**Harmful:** Every negative assertion, plan item, or edit demands maximum-strength proof.

## Discovery handling

Classify discoveries consistently:

- Necessary for the requested outcome → include.
- Useful but independent → report once as a follow-up.
- Speculative or unsupported → omit.

**Harmful:** Discovery automatically enlarges the active artifact or workflow.

## Continuation and composition

- Does each continuation preserve the original scope?
- Can a review round discover new in-scope defects without reopening architecture?
- Are successor skills optional rather than an implicit pipeline?

**Harmful:** One skill's output automatically triggers more artifacts, reviews, or workflow stages.

## Instruction complexity

For each instruction, ask:

- Is it essential domain behavior?
- Is it a safety boundary?
- Is it conditional rigor currently written as a universal rule?
- Is it an incident-specific lesson that belongs in an example or narrow check?
- Is it duplicated elsewhere?

Remove duplication. Demote conditional rigor. Delete historical scars that no longer earn their
surface cost.

## Automatic remediation triggers

Remediate regardless of the overall assessment when a skill:

- Expands scope without causal necessity.
- Requires duplicate authorization.
- Forces an artifact solely because its template expects one.
- Treats adjacent improvements as blockers.
- Activates formal rigor implicitly.
- Makes a downstream skill stricter than the accepted upstream scope.
- Encodes one past incident as a universal workflow.

## Audit output

Keep the result short:

```markdown
## Skill audit: <name>

Default path:
<What happens for an ordinary bounded request?>

Keep:
- <Behavior worth preserving>

Remove or demote:
- <Ceremony or universalized special case>

Scope risks:
- <Ways the skill can enlarge the request>

Smallest remediation:
- <Exact files and behavioral changes>

Regression scenarios:
- Bounded task: <must remain lean>
- High-risk task: <must retain justified rigor>
```

Avoid an aggregate numeric score. Any harmful behavior deserves attention, while **Needs work**
items should be fixed only when their cost is observable. The rubric must not become another
ceremony machine.
