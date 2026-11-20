# 0005: Build idea-to-plan before plan-to-issues, and repo-governance after ci-setup

Date: 2026-11-20
Status: accepted

## Context

The first roadmap put `plan-to-issues` before `idea-to-plan`, so the consumer of a plan would be built before its producer, and put `repo-governance` before `ci-setup`. Building and using `repo-bootstrap` (decision 0001) showed two problems:

- The plan format is already specified in conventions §5, so building the consumer first teaches little. And `plan-to-issues` needs a real plan to run on, but this repository only has the bootstrap stub. Writing it by hand would mean doing `idea-to-plan`'s job without the skill.
- Required checks can only name stages the pipeline has produced, and those come from `ci-setup`. Governance run before the pipeline exists could only set part of its rules.

We considered merging `repo-bootstrap` and `repo-governance` into one setup skill. We kept them separate because they differ in risk (writing files vs. changing access and protection), in timing (first vs. after `ci-setup`) and in lifespan (bootstrap runs once; governance is re-run when collaborators, visibility or review rules change).

## Decision

Follow the idea-to-release flow and use each skill on this repository once it works:

1. `idea-to-plan`
2. `plan-to-issues`
3. `work-issue`
4. `ci-setup`
5. `repo-governance`
6. `release`

Keep `repo-bootstrap` and `repo-governance` as separate skills.

## Consequences

- `idea-to-plan` produces this repository's real plan, including the work done so far, as decision 0001 requires.
- `plan-to-issues` is built against a real plan.
- Until `repo-governance` runs, the default branch is protected by procedure only, not by forge rules.
