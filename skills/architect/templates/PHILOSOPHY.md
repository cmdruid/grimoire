# Philosophy

The core ideals ("tenets") every system in `.agents/architect/` is expected to honor. A tenet is a durable
constraint, not a preference — it should be the kind of thing you'd cite as the *reason* a design
choice was rejected.

## Tenets

<Each tenet is one line: a short bold name, an em-dash, and the constraint it enforces. Example
shape (not this project's actual tenet): **Seeds are sacred** — worldgen is a pure function of
`(seed, position)`; no wall-clock, no thread-order dependence.>

- **<Tenet name>** — <one line: what it constrains, and why>
- **<Tenet name>** — <one line: what it constrains, and why>

## How a tenet gets added

Recurrence of the same constraint across **two or more systems** is a **candidate signal** —
reason to *propose* promoting it to a tenet here — not an automatic rule. Recurrence alone does
not prove durability: a pattern that shows up twice by coincidence, or that's really scoped to
one subsystem, is not yet a tenet. A human decides whether the candidate is actually a durable,
project-wide constraint before it's added to this list.
