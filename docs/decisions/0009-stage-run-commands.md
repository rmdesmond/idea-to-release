# 0009: Each pipeline stage has a run command in the config

Date: 2026-11-20
Status: accepted

## Context

work-issue must not open a change request until the task's tests pass (conventions §10), so it has to know how to run them. The config named the pipeline stages but not their commands. ci-setup, which will write the CI files, comes later (M4). If the commands lived only in the CI files, local runs and CI could drift apart.

## Decision

Every enabled stage, core or extra, has a `run` command in `.project/config.yml`: one shell command, run from the repository root, that exits 0 on success. work-issue runs it locally before opening a change request. ci-setup will render the same command into the pipeline. Disabled stages keep a `reason` instead.

## Consequences

- One definition of each stage, used both locally and in CI.
- idea-to-plan and repo-bootstrap should ask for or propose `run` commands when they enable a stage. That's a follow-up for those skills; until then, `run` is added by hand.
- A stage whose command needs a tool that isn't installed locally (here, `shellcheck`) can only be advisory locally, which is how this repository's `shellcheck` stage is already defined.
