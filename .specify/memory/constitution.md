<!--
SYNC IMPACT REPORT
==================
Version change: [template] → 1.0.0 (initial ratification)

Modified principles:
  - N/A (first population from template)

Added sections:
  - I. Correctness First
  - II. Quality Standards
  - III. Safety & Guardrails
  - IV. Evidence-Driven Development
  - V. Ergonomic Design
  - Code Review Process
  - Governance

Removed sections:
  - N/A (template placeholders replaced)

Templates requiring updates:
  ✅ plan-template.md — Constitution Check gates align with principles I–V
  ✅ spec-template.md — Acceptance Scenarios and Success Criteria align with Evidence principle
  ✅ tasks-template.md — Phase structure supports Safety (review checkpoints) and Quality gates
  ✅ checklist-template.md — No structural changes needed; principle references are generic

Follow-up TODOs:
  - TODO(RATIFICATION_DATE): Confirm original adoption date; marked 2026-05-20 (today) as
    first-time population date. Update if project predates this session.
-->

# se-llama Constitution

## Core Principles

### I. Correctness First

All code MUST be provably correct before it is considered complete. "Works on my machine"
is not evidence of correctness. Correctness is established through:

- Automated tests that cover the specified behavior (unit, integration, contract).
- Explicit handling of error paths and boundary conditions — happy-path-only code is
  incomplete code.
- Static analysis and type checking passing without suppressions unless each suppression
  is individually justified in a code comment.
- Deterministic behavior: the same input MUST produce the same output unless randomness
  is an explicit, documented design choice.

**Rationale**: LLM-assisted support engineering amplifies both productivity and subtle
incorrectness. Every shortcut in verification compounds downstream. Correctness gates
are the primary defense.

### II. Quality Standards

Code quality is not optional and MUST NOT be deferred to "a later cleanup pass."

- Every public interface (function, class, endpoint, CLI command) MUST have a docstring
  or equivalent structured documentation before the PR is merged.
- Cyclomatic complexity MUST be kept low; functions doing more than one logical thing
  MUST be split unless splitting would produce obscure indirection with no benefit.
- Linting and formatting tools MUST pass with zero warnings in CI.
- Dependencies MUST be pinned or range-constrained; unpinned dependencies are a quality
  regression.
- Dead code MUST be removed, not commented out.

**Rationale**: Quality is the cost of correctness over time. Low-quality code
accumulates correctness debt faster than it accumulates features.

### III. Safety & Guardrails

No change reaches production without passing defined safety gates.

- All features MUST have at least one automated acceptance test derived directly from a
  user story acceptance scenario before implementation begins (test-first).
- Destructive operations (deletes, overwrites, irreversible mutations) MUST require
  explicit confirmation or a dry-run mode.
- Security-sensitive code (auth, secrets, external I/O) MUST be reviewed by at least one
  additional reviewer beyond the author.
- Changes that affect public contracts (APIs, CLIs, file formats, schemas) MUST be
  documented and versioned; breaking changes require a migration path.
- AI-generated code MUST receive the same review scrutiny as human-authored code — it
  is not pre-approved by virtue of being generated.

**Rationale**: Guardrails are cheapest at design time. A safety culture is only real
when it is enforced, not aspirational.

### IV. Evidence-Driven Development

Confidence is not evidence. Claims about behavior MUST be backed by observable proof.

- Implementation MUST NOT be marked complete until tests pass in CI (not just locally).
- Performance claims MUST be accompanied by benchmark results, not estimates.
- Bug fixes MUST include a regression test that would have caught the original bug.
- Design decisions of non-trivial consequence MUST be recorded with the rationale,
  alternatives considered, and why they were rejected (ADR or inline in plan.md).
- "It should work" and "it looks right" are insufficient — show the evidence.

**Rationale**: LLM-assisted support engineering produces plausible-sounding but sometimes
incorrect results. Requiring evidence over confidence is the primary check on this.

### V. Ergonomic Design

Follow the principle: make easy things easy and hard things possible.

- Common operations MUST require minimal ceremony (sensible defaults, zero-config happy
  path where feasible).
- Advanced operations MUST be possible without hacks or workarounds — escape hatches are
  a first-class concern, not an afterthought.
- Error messages MUST be actionable: state what went wrong, why, and how to fix it.
- Public APIs MUST be designed from the caller's perspective first; internal convenience
  MUST NOT leak into the interface.
- Complexity MUST be justified in the plan's Complexity Tracking table; unexplained
  complexity is a constitution violation.

**Rationale**: Usability and correctness are not in tension. Poor ergonomics leads to
workarounds that bypass safety guardrails. Good ergonomics is a safety property.

## Code Review Process

Every PR MUST satisfy all of the following before merge:

1. **Constitution Check** — reviewer explicitly confirms each principle (I–V) is
   satisfied or documents a justified exception.
2. **Test Evidence** — CI green, test coverage does not regress, new behavior has new
   tests.
3. **Documentation** — all new public interfaces are documented; breaking changes are
   noted in CHANGELOG or equivalent.
4. **Security Scan** — any change touching auth, secrets, or external I/O has a
   designated security reviewer sign-off.
5. **Complexity Justification** — any increase in cyclomatic complexity or architectural
   scope is explained in the PR description.

Self-approval is not permitted. PRs authored by AI agents require human review.

## Development Workflow

- **Specification before implementation**: No code is written without an approved spec
  (`spec.md`) that contains user stories with acceptance scenarios.
- **Plan before tasks**: No tasks are generated without an approved implementation plan
  (`plan.md`) that passes the Constitution Check gate.
- **Test before implement**: Tests derived from acceptance scenarios MUST exist and FAIL
  before the corresponding implementation is written (Red phase required).
- **Checkpoint validation**: Each phase checkpoint in `tasks.md` MUST be validated
  (tests passing, behavior demonstrated) before the next phase begins.
- **Incremental delivery**: Features are delivered story-by-story, each independently
  testable and demonstrable.

## Governance

This constitution supersedes all other project practices. Any practice that conflicts
with this document MUST either be brought into compliance or explicitly documented as an
exception with written justification stored in `.specify/memory/exceptions.md`.

**Amendment procedure**:
1. Propose the amendment as a PR modifying this file with a rationale section.
2. Obtain approval from at least one additional contributor (or project lead if solo).
3. Update `CONSTITUTION_VERSION` and `LAST_AMENDED_DATE` following semantic versioning:
   - MAJOR: Principle removed, redefined, or governance structure changed.
   - MINOR: New principle or section added; materially expanded guidance.
   - PATCH: Clarification, wording, or non-semantic refinement.
4. Propagate changes to all dependent templates per the Sync Impact Report convention.

**Compliance**: All PRs and reviews MUST verify compliance with this constitution.
Reviewers who approve a non-compliant PR share accountability for the violation.

**Runtime guidance**: See `AGENTS.md` for agent-specific development guidance in this
repository.

**Version**: 1.0.0 | **Ratified**: 2026-05-20 | **Last Amended**: 2026-05-20
