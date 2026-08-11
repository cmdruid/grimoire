# `/bootstrap grill` — interrogate the idea until the design is settled

Run a relentless design-tree interview that settles everything the five founding documents need, and
nothing else. **This verb writes nothing to disk.** Its entire output is a settled design held in
conversation context, consumed by `land`.

## When to use

- The user runs `/bootstrap grill`, or `/bootstrap` bare (which runs this, then `land`).
- The user wants to stress-test a project idea before committing to it — even with no intent to land.

**Do NOT use** to interrogate a change to an *existing* project. This verb assumes nothing exists yet
and its seeded branches ask founding questions (what is this, who is it for, what is it called) that
are settled facts on a live project.

## The protocol

Model the design as a **tree**: every decision branches into the decisions that hang off it. Work the
tree in **rounds**.

The **frontier** is every decision whose prerequisites are already settled — the questions answerable
*now* without guessing at answers not yet heard. Ask the whole frontier in one round; wait for
answers before computing the next.

Each question is formatted:

```
❓ **Q1** - **<question title>**: <body — may be several paragraphs, may offer lettered choices>

➡️ <your recommended answer, with the reasoning that makes it a recommendation>
```

**Always recommend.** A question posed without a recommendation makes the user do the work the
interview exists to do for them. The recommendation must carry its *reason* — a bare preference is
noise.

Each round's answers reshape the tree: settled decisions push the frontier outward and unblock
questions that depended on them. A question whose answer depends on another question still open in
*this* round belongs to a **later** round, not this one. Recompute and ask again.

**Finding facts is your job, never the user's.** When a question needs something the environment can
answer (what a tool does, whether a library exists, what a convention is), go find it. Only
*decisions* go to the user.

**Report reshapes honestly.** When an answer retracts something earlier rounds settled, say so plainly
and state what it costs before continuing. Silent reshaping produces a design the user did not
knowingly approve.

## Seeded root branches

Unlike a general-purpose interview, this tree's roots are **seeded** — a greenfield grill has a known
shape. Five branches, each feeding a document:

| branch | settles | feeds |
|---|---|---|
| Problem & users | what hurts, for whom, why now | `README.md` |
| Scope & non-goals | what it is, what it explicitly is not | `README.md`, `<project>/docs/ROADMAP.md` |
| Architecture & alternatives | components, boundaries, interfaces, what was rejected and why | `<project>/docs/ARCHITECTURE.md` |
| Sequencing & phases | phase order, goal / scope / definition-of-done / risks per phase | `<project>/docs/ROADMAP.md` |
| Working conventions | **the project's name**, location, language/runtime, the intended verification command | `<project>/docs/RUNBOOK.md`, `AGENTS.md` |

**Seeded roots are not scripted questions.** The five branches are given; everything below them is
discovered from the user's answers. A pre-written question list is a questionnaire, not a grill.

**Termination:** the frontier is empty when all five documents have what they need. This is the
verb's stopping condition and it is checkable — walk the five documents and name any section you
could not yet write.

**Scope control falls out of the seeding:** a branch that feeds no document is out of scope by
construction. Market sizing, licence choice, hiring, pricing — if it does not land in one of the five
documents, it is not this interview's business. Say so and move on.

## Prior material

`grill <path-or-prompt>` accepts existing material — notes, a spec, a README sketch, a napkin
paragraph.

- Read anything given as **facts**, not as questions. Branches it already settles are marked settled
  and **not asked**. Asking the user something their own notes answer is the fastest way to make a
  grill feel like a form.
- Confirm what you took from it in one short block before the first round, so a misreading surfaces
  immediately.
- **Never auto-detect.** Do not scan the working directory for candidate notes — that is guesswork
  about a directory this skill does not own, and it will read the wrong file.

## Closing the grill

When the frontier is empty, present the settled design for confirmation before anything happens:

1. **The name and location** — stated first, since they are what `land` acts on.
2. **A section-by-section summary** of what each of the five documents will say.
3. **Deferred branches**, if any — decisions consciously postponed, distinct from decisions missed.

Do not proceed to `land` until the user confirms shared understanding. If the user stops here, the
grill still delivered value and cost nothing on disk.

## Done when

Every one of the five documents could be written from the settled design; the name and location are
decided; deferred branches are named as deferred; the user has confirmed. Nothing has been written to
disk.
