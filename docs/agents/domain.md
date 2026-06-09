# Domain Docs

How engineering skills should consume this repo's domain documentation.

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- ADRs in `docs/adr/` that touch the area being changed.

If these files are missing for a given area, proceed silently.

## Layout

This repository is **single-context**:

- Root glossary: `CONTEXT.md`
- Root architecture decisions: `docs/adr/`

There is no `CONTEXT-MAP.md` multi-context split in this repo.

## Vocabulary rule

Use domain terms exactly as defined in `CONTEXT.md`. Avoid synonyms explicitly listed as "Avoid" in the glossary.

## ADR conflict rule

If a proposed change conflicts with an ADR, call out the conflict explicitly rather than silently overriding prior decisions.