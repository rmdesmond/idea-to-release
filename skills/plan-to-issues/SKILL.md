---
name: plan-to-issues
description: Turn the project plan (docs/plan/PLAN.md) into tracker milestones and dependency-linked issues, adopt issues that already exist for plan tasks, close issues for dropped tasks, and record everything in the ledger (.project/ledger.yml). Use after writing or revising the plan, or to bring issue labels and links back in step with it. Re-runnable; a second run with no plan changes reports no changes.
---

# plan-to-issues

Makes the tracker match the plan: one milestone per plan milestone, one issue per task, dependencies as links, and a ledger entry for each task.

Before doing anything, read `conventions.md`, especially §5 (plan), §6 (ledger), §8 (labels), §9 (issues) and §13 (safety).

**Verbs used:** `milestone.ensure`, `issue.list`, `issue.create`, `issue.update`, `issue.link`, `issue.close` (tracker); `cr.open` (forge). Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `issue` | none | Issue number for the ledger change request's branch and footer |
| `non-interactive` | off | Don't ask. Use the inferred labels, and stop at any conflict |
| `confirm` | off | Only with `non-interactive`: the caller confirms the dry run in advance. Without it, a non-interactive run stops after the dry run |

## Procedure

### 1. Read and check the inputs

1. Read `.project/config.yml` and the adapters it names. If a verb above is `not yet implemented`, stop and say which one.
2. Run `scripts/check-plan.sh` and `scripts/check-ledger.sh` on the project's plan and ledger. The scripts belong to the idea-to-release skill set, next to `conventions.md`, not to the project. If either check fails, stop and show the problems. The plan or ledger must be fixed first, through a change request. One exception: failures that are only `missing title` mean a ledger written before titles existed. Carry on, and add the titles in the ledger step.
3. Check that the labels from conventions §8 exist on the tracker. If any are missing, stop and suggest running repo-bootstrap, which creates them.
4. Read the plan. For each milestone, note its title (`M<n>: <title>`) and its one-sentence summary (the first paragraph under the heading). For each task, note:
   - ID, title and milestone
   - `Depends on:` and `Issue:`
   - the *Done when* checklist
   - whether it's **dropped** (the heading ends in `(dropped)`), and the reason on its `Dropped` line
   - whether it's **done** (every *Done when* box ticked)
5. Read the ledger.
6. Run `issue.list` with `state=all` once, and keep the result. Every later lookup uses it instead of calling the forge again.

### 2. Find each task's issue

For each task, look in this order and stop at the first match:

1. the ledger's `issue`
2. the plan's `Issue:` line
3. an issue whose body has the line `Plan-Task: <ID>` (the check in `issue.create`)

Then check that the sources agree. **Stop and ask** (conventions §13) if:

- the ledger and the `Issue:` line name different issues
- an issue named by the ledger or an `Issue:` line doesn't exist on the forge
- more than one issue carries the same `Plan-Task:` line
- an issue's `Plan-Task:` line names a different task than the one the ledger or plan links it to, or its title starts with a different task ID
- a live task's issue is closed as `not planned` (the plan says the work is wanted; the tracker says it was abandoned)

Each task ends up **linked** (it has an issue) or **unlinked** (it needs one).

### 3. Work out the desired state

**Milestones.** One per plan milestone. The title is `M<n>: <title>`, and the description is the milestone's summary.

**New issues**, one for each unlinked task that isn't dropped:

- **Title:** `<ID>: <task title>`, for example `T-012: Implement the change verbs for work-issue` (conventions §9)
- **Body:**
  ```markdown
  ## Context

  <milestone summary> Plan task <ID> in `docs/plan/PLAN.md`.

  ## Done when

  <the task's checklist, copied exactly>

  ## Depends on

  <"none", or one line per dependency: "- <ID> (#<issue>)">

  Plan-Task: <ID>
  ```
- **Milestone:** the task's milestone
- **Type label**, inferred from the title. Most plan tasks add capability, so `type:feature` is the default:
  - first word Fix → `type:bug`
  - first word Write, Document, Draft or Explain → `type:docs`
  - a test task (title starts with "Integration test", "End-to-end test" or "Test") → `type:chore`
  - first word Set up, Configure, Update, Upgrade, Remove, Refactor, Rename, Reorder, Clean, Bump, Decide, Run or Release → `type:chore`
  - anything else → `type:feature`
- **Priority:** `priority:normal`
- **State label:**
  - `needs-decision` if the title starts with "Decide"
  - otherwise `blocked` if any dependency is unfinished
  - otherwise `ready`

  A dependency is **finished** when its task is done in the plan, or its issue is closed as completed. Done tasks get no state label.

The inferred labels are shown in the dry run, where the user can change any of them.

**Existing issues**, one for each linked task:

- **Add anything missing:**
  - the milestone, if it's not set
  - the `Plan-Task: <ID>` line, appended to the body if absent
  - the `<ID>: ` prefix on the title, if absent. Keep the rest of the title as it is: only the prefix is added. If the title starts with a different task ID, that is a conflict (step 2).
  - a type or priority label, if the issue has none (using the inference above)
- **Correct, as a stated change in the dry run:**
  - a milestone that doesn't match the plan
  - the state label of an open issue (`ready` ↔ `blocked`), as dependencies finish or change. `needs-decision` is left alone once set.
  - any state label (`ready`, `blocked` or `needs-decision`) on a closed issue: remove it. Issues are usually closed by merging a change request, which leaves their labels behind, and state labels only describe open work (conventions §8).
- **Report, but don't change:** a title (compared without its `<ID>: ` prefix) or *Done when* list that differs from the plan. Someone may have edited the issue on purpose. Ask, and apply only what the user accepts.

**Links.** For each dependency, the dependent task's issue is `blocked-by` the dependency's issue (`issue.link`). Record each link from the dependent side only. A link present on the forge but no longer in the plan is reported, and removed only if the user agrees.

**Closing:**

- **Done task, newly created issue:** close it as `completed` straight after creating it, with the comment "Completed before the plan was turned into issues."
- **Done task, existing open issue:** this is a contradiction (the plan says done, the tracker says open). Report it and ask. Never close it on the plan's word alone.
- **Dropped task with an open issue:** close it as `not planned`, with the plan's `Dropped` line as the comment.
- **Dropped task with no issue:** create nothing.
- **Whenever an issue is closed,** remove its state label (`ready`, `blocked` or `needs-decision`) in the same step. State labels only describe open work (conventions §8).

**Ledger.** For every task with an issue (created or adopted), the entry has:

- `milestone`: from the plan
- `issue`: the number
- `created`: the issue's creation date (`YYYY-MM-DD`)

Leave `change_requests`, `merged`, `released_in` and `released` alone; the release skill fills those in. Update `milestone` if the task moved. Dropped tasks keep their entries.

### 4. Dry run and confirmation

Show one summary. List every write, and every difference reported but not changed:

```
Repository: owner/repo   Plan: 5 milestones, 27 tasks (5 done, 0 dropped)

milestone.ensure  create M2: Plan to issues, M3: ..., M4: ..., M5: ...; M1 unchanged
issue.create      "T-007: Implement the tracker verbs ..."   type:feature priority:normal ready    M2
                  "T-018: Decide the review rule ..."        type:chore   priority:normal needs-decision M4
                  "T-001: Draft the shared conventions ..."  → then close as completed
issue.update      #1 (T-002): set milestone M1; append Plan-Task: T-002; title prefix "T-002: "
issue.link        #14 blocked-by #12, #13   (+ 31 more)
issue.close       none
ledger            add 27 entries; refresh titles 0 → branch chore/11-ledger, change request "chore(ledger): record issues for the plan"

Reported, not changed:
  #12 (T-007): title differs from the plan
```

Issues that don't exist yet have no number, so refer to them by task ID: list their links as `T-003 blocked-by T-001, T-002`, and count their ledger entries. A dry run must account for every write the apply step will make. Never write "after it is created" in place of the actual links.

If nothing would change, say "Issues match the plan; no changes" and stop.

Wait for explicit confirmation (conventions §13). Non-interactive runs proceed only with `confirm`, and only if there are no conflicts.

### 5. Apply

In this order, stopping at the first failure and reporting what was done:

1. `milestone.ensure` for every milestone
2. `issue.create` for every new issue, in plan order
3. `issue.update` for existing issues
4. `issue.link` for every dependency. All issue numbers are known by now.
5. `issue.close` for done and dropped tasks, as above
6. **Ledger:**
   - write `.project/ledger.yml` in the shape from conventions §6, with tasks in ID order
   - every entry's `title` is the plan's task title (without ` (dropped)`), double-quoted with `\"` and `\\` escapes. Add it to entries that lack it, and refresh it where the plan's title has changed. Keep every other field as it is: release owns those.
   - run `scripts/check-ledger.sh`. It must pass with no warnings
   - commit on branch `chore/<issue>-ledger`, or `chore/ledger-<YYYYMMDD>` with no issue, with the message `chore(ledger): record issues for the plan` and a `Refs: #<issue>` footer if there is an issue
   - push, then `cr.open`. The body lists the tasks added or changed. Don't merge it.

If a run stops partway, running it again is safe. Issues already created are found by their `Plan-Task:` line, and every other verb checks before it acts.

### 6. Report

List the milestones created, issues created or adopted (with numbers), links added, issues closed, differences left for the user, and the ledger change request link.

## Re-running

Every step checks first, so a second run with no plan changes reports "Issues match the plan; no changes". After the plan changes (tasks added, dropped, moved, or with new dependencies), a re-run makes only those changes. It also moves `blocked` issues to `ready` once their dependencies finish.

## Out of scope

- Writing or changing the plan: **idea-to-plan**
- Working an issue: **work-issue**
- Recording change requests, merges and releases in the ledger: **release**
