# 0021: Three gates: plan, accept, work

Date: 2026-11-22
Status: accepted

## Context

Through v0.2.0, a project used seven skills in an order the user had to know: `repo-bootstrap` or `idea-to-plan` first, then `plan-to-issues`, `ci-setup` and `repo-governance` in some order, then `work-issue` for each task and `cut-release`. Nothing marked a plan as agreed, so a half-agreed plan could turn straight into issues. Nothing stopped a task being worked before the pipeline and the branch rules were in place. A plan written before a repository existed stayed on one machine until `repo-bootstrap` ran.

## Decision

- **Three gates, each a skill:**
  1. **`idea-to-plan`** writes the plan and ends with it saved in a repository: a new one, always private at first, or a change request in an existing one. The plan is the check that what was asked for is what was understood.
  2. **`accept-the-plan`** is the user accepting it. It readies the forge in one dry run and one yes: the standard setup, the pipeline (every core stage, with a passing placeholder where a task will create the command), the branch rules once the pipeline passes, and the milestones and issues. Then it marks the plan accepted (decision 0022).
  3. **`work-the-plan`** works the accepted plan one task at a time through `work-issue`, stopping at each change request for the maintainer's merge, and runs `cut-release` at each release milestone.
- **`repo-bootstrap`, `ci-setup`, `repo-governance` and `plan-to-issues` are folded into `accept-the-plan`,** as supporting files in its folder. Six skills remain: `idea-to-plan`, `accept-the-plan`, `work-the-plan`, `work-issue`, `write-tutorial` and `cut-release`.
- **New repositories start private.** Going public is a later, deliberate change, through `accept-the-plan` again.
- **The task that creates a stage's command enables that stage,** and renders the pipeline again, in its own change request.
- **A usage record of each run was considered and dropped.** The plan gate does its job, and the plan, issues, change requests and tags already record the rest.

## Consequences

- No task is worked before the pipeline and the branch rules exist.
- A user needs to know three skills. `work-issue`, `write-tutorial` and `cut-release` can still be run alone, for a single issue, a tutorial or a release outside the plan.
- Changing the pipeline or the rules later means running `accept-the-plan` again, which changes only what differs.
- Only two kinds of commit go straight to the default branch: `idea-to-plan`'s first commit, and `accept-the-plan`'s setup before the branch rules exist (conventions §10).
- This repository's v0.3.0 removes four skills, a breaking change for anyone calling them by name.
