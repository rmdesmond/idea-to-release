# 0022: A plan is accepted explicitly, and only an accepted plan is worked

Date: 2026-11-22
Status: accepted

## Context

The plan is the check that what was asked for is what was understood (decision 0021). That check means something only if there's a moment when the user says the plan is right, and if work waits for it. Plans also change while they're being worked, so acceptance has to be given again after a revision.

## Decision

- **The plan has a `Status:` line** under its title: `draft`, or `accepted <date>` (conventions §5). `scripts/check-plan.sh` checks it.
- **`idea-to-plan` writes `draft`,** and sets it back to `draft` in every revision.
- **`accept-the-plan` sets `accepted <date>`** once the forge is ready, through a change request.
- **`work-the-plan` refuses a draft plan,** and says to run `accept-the-plan`.
- **A milestone may carry a `Release: vX.Y.Z` line.** When its last task is merged, `work-the-plan` runs `cut-release` with that version.

## Consequences

- Revising a plan in progress pauses `work-the-plan` until the revision is accepted. That's the point: the issues and the plan never disagree while work goes on.
- The history of acceptances is in the git log of `docs/plan/PLAN.md`.
