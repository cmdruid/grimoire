# skill-builder specs

Portable format/authoring contracts that every skills library
installing `skill-builder` must honor. `check`, `new`, and
writer rule 5 read these. Doctrine
(`docs/DOCTRINE.md`) stays philosophy and points here; it does
not restate enums that can drift.

## Belongs

Format/authoring contracts (records front-matter; later contracts
of the same class).

## Does not belong

A host library’s feature specs. Pack-format
(`docs/spec/pack-format.md` at the host library root — this
change does not move it). Doctrine essays
(`docs/DOCTRINE.md`). Project-deployed kind templates.

## Index

| spec | what |
|---|---|
| `records-front-matter.md` | Record `status` / `stage`, filters, in-package contract |
