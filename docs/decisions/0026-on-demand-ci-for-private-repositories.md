# 0026: On-demand CI for private repositories

Date: 2026-11-26
Status: accepted

## Context

GitHub gives private repositories a monthly allowance of Actions minutes (on GitHub Pro, 3,000), and public repositories unlimited minutes on standard runners. The pipeline that `accept-the-plan` renders runs on every change request, every push to a change request and every merge to the default branch. A private project worked task by task through `work-the-plan` uses up its allowance quickly. Most of those runs repeat checks that `work-issue` has already run locally with the same `run` commands (conventions §11).

GitHub counts a required check that an `if:` condition skipped as passing, and a skipped job uses no runner minutes. So the pipeline can skip its jobs without changing the branch rules and without blocking merges.

## Decision

- The config gets `pipeline.ci`, either `always` (the default and the current behaviour) or `on-demand`.
- In `on-demand`, the pipeline runs on a change request only when it carries the `ci:full` label, or when it's a release change request. Release tags always run it, merges to the default branch never do, and a manual run is always possible. Tags are permanent, so the release change request and the tag both run CI before and after tagging.
- `accept-the-plan` puts `ci:full` on the last task of each release milestone. `work-issue` copies it to the change request. The maintainer can add it to anything else.
- `work-issue` runs every enabled stage locally before each push, and records the results in the change request. For a change request that CI skipped, those local runs are the check.
- On-demand is for private repositories only. `idea-to-plan` asks whether the repository will stay private, and asks about the CI mode only if it will. A repository that goes public uses `always`.
- This repository is public (decision 0025), so it keeps `always`.

## Consequences

- A private project uses Actions minutes only for labelled change requests and for each release, not for every push.
- Between labelled runs, CI never checks the default branch. A difference between local and CI environments (tools, shell, operating system) can go unnoticed until the next labelled run or release. `cut-release` checks the head locally before preparing a release, and the release change request runs CI before anything is tagged.
- An unlabelled change request shows its required checks as passing (skipped). Its body, not its checks, is the record of what was run.
- Only the GitHub adapter renders the mode. Other forge adapters must refuse `on-demand` until they support it.
