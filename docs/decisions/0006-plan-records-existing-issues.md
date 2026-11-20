# 0006: Plans can name an existing issue for a task

Date: 2026-11-20
Status: accepted

## Context

Decision 0001 says work done before the plan existed is added to the plan as completed tasks. That work already has issues (#1, #4, #6, #8). Conventions §5 had no way to say so. plan-to-issues would create a second issue for each task, and the ledger couldn't link the task to the issue that really tracked it.

## Decision

Add an optional `Issue: #N` line to a task in the plan (conventions §5). plan-to-issues adopts the named issue instead of creating one, and records it in the ledger. Completed work is shown by ticking every box in the task's *Done when* list.

The line also covers issues opened outside the plan that a task is later written for (conventions §9, "work discovered mid-flight").

## Consequences

- Backfilling the ledger needs no special case: plan-to-issues treats an `Issue:` line like any other ledger lookup.
- The plan holds one forge-specific value (an issue number). The ledger stays the authority on issue, change request and release links; the `Issue:` line is only an input to plan-to-issues.
- `scripts/check-plan.sh` checks the line's format.
