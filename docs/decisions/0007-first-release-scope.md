# 0007: Scope of the first release

Date: 2026-11-20
Status: accepted

## Context

The skills are designed to work with any forge or tracker and any agent that supports the Agent Skills format. Proving all of that before a first release would multiply the work. Writing the plan (T-006) needed a clear line between what v0.1.0 must do and what can wait.

## Decision

v0.1.0 contains:

- the seven skills
- `conventions.md`, with the GitHub forge and tracker adapters implementing every verb the skills use
- this repository's check scripts and their tests
- installation instructions

It's released from this repository using the `release` skill itself.

Left out of v0.1.0:

- adapters for other forges or trackers
- testing on agents other than Claude Code
- projects that span several repositories
- any tooling outside the agent

Scripts stay in bash and standard tools that work with both BSD and GNU versions, with no Python or Node dependency.

## Consequences

- "Forge-agnostic" is a design property at v0.1.0, not a tested one. The first non-GitHub adapter will show where the neutral verbs leak, and may need changes to `conventions.md`.
- Any of the excluded items can become a milestone in a later revision of the plan.
- The bash-only rule keeps installation simple, but YAML handling (the ledger check, T-008) has to work without a YAML library.
