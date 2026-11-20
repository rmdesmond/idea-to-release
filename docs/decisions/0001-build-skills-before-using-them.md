# 0001: Build skills by hand before they can run on themselves

Date: 2026-11-20
Status: accepted

## Context

This repository is meant to be built with its own skills, but none of them exist yet. The conventions assume issues, labels, a ledger and branch rules that the skills create. Something has to come first.

## Decision

Build the skills in the order of the idea-to-release flow and use each one on this repository as soon as it works. Start with `repo-bootstrap` and only the GitHub adapter verbs it needs. Until a skill exists, follow the conventions by hand where it is cheap:

- Work is tracked in an issue, created manually without the standard labels until bootstrap creates them.
- Branches, Conventional Commits and change requests follow conventions §10.
- Work done before `docs/plan/PLAN.md` exists has no `Plan-Task` ID. When the plan is written, this work is recorded there as completed tasks, and the ledger is backfilled.

## Consequences

- Early history is less tidy than the conventions require: issue #1 predates labels and the plan.
- Each skill is tested on a scratch repository before it runs on this one.
- Adapters are partial for now. Verbs not yet needed are marked `Status: not yet implemented`, so gaps are visible and checkable.
