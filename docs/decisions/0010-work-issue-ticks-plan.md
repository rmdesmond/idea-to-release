# 0010: A task's change request ticks its boxes in the plan

Date: 2026-11-20
Status: accepted

## Context

Ticked *Done when* boxes mark completed work in the plan (conventions §5, decision 0006), but nothing ticked them. After a task merged, the plan still showed it as not done. plan-to-issues then saw "plan says not done, issue closed", and whoever read the plan got a stale picture.

## Decision

The change request for a plan task ticks that task's boxes in `docs/plan/PLAN.md`. work-issue does it as part of preparing the change request, and checks the plan with `scripts/check-plan.sh`. Merging then closes the issue and marks the task done in one step.

## Consequences

- The plan, the tracker and the ledger agree as soon as a change request merges.
- Several change requests touch `PLAN.md` at once, but each changes only its own task's lines, so conflicts should be rare.
- A box is ticked only when its item is verified. A change request can't tick a box for work that happens after merge; such an item belongs in a later task.
