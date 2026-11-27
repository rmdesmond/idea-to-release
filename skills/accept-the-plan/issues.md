# accept-the-plan: the milestones and issues

Supporting file for `SKILL.md`, steps 2 and 6. It makes the tracker match the plan: one milestone per plan milestone, one issue per task, and dependencies as links. Each issue carries its task's `Plan-Task:` line, which is how the task is found again (conventions §6).

**Verbs:** `milestone.ensure`, `issue.list`, `issue.create`, `issue.update`, `issue.link`, `issue.close` (tracker).

## Read the plan and the tracker

1. Read the plan. For each milestone, note its title (`M<n>: <title>`) and its one-sentence summary (the first paragraph under the heading, after its `Release:` line if it has one). For each task, note:
   - ID, title and milestone
   - `Depends on:` and `Issue:`
   - the *Done when* checklist
   - whether it's **dropped** (the heading ends in `(dropped)`), and the reason on its `Dropped` line
   - whether it's **done** (every *Done when* box ticked)
2. Run `issue.list` with `state=all` once, and keep the result. Every later lookup uses it instead of calling the forge again.

The labels from conventions §8 come from the setup (`setup.md`), which is applied first.

## Find each task's issue

For each task, look in this order and stop at the first match:

1. the plan's `Issue:` line
2. an issue whose body has the line `Plan-Task: <ID>` (the check in `issue.create`)

Then check that the sources agree. **Stop and ask** (conventions §13) if:

- the `Issue:` line names an issue that doesn't exist on the forge, or one whose `Plan-Task:` line names another task
- more than one issue carries the same `Plan-Task:` line
- an issue's `Plan-Task:` line names a different task than the one the plan links it to, or its title starts with a different task ID
- a live task's issue is closed as `not planned` (the plan says the work is wanted; the tracker says it was abandoned)

Each task ends up **linked** (it has an issue) or **unlinked** (it needs one).

## Work out the desired state

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
  - a test task → `type:chore`: the title starts with "Integration test", "End-to-end test" or "Test", or it starts with Add and names tests or a test harness ("Add integration tests for --separator", "Add the test harness and lint script")
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
  - the `<ID>: ` prefix on the title, if absent. Keep the rest of the title as it is: only the prefix is added. If the title starts with a different task ID, that is a conflict (above).
  - a type or priority label, if the issue has none (using the inference above)
- **Correct, as a stated change in the dry run:**
  - a milestone that doesn't match the plan
  - the state label of an open issue (`ready` ↔ `blocked`), as dependencies finish or change. `needs-decision` is left alone once set.
  - any state label (`ready`, `blocked` or `needs-decision`) on a closed issue: remove it. Issues are usually closed by merging a change request, which leaves their labels behind, and state labels only describe open work (conventions §8).
- **Report, but don't change:** a title (compared without its `<ID>: ` prefix) or *Done when* list that differs from the plan. Someone may have edited the issue on purpose. Ask, and apply only what the user accepts.

**Links.** For each dependency, the dependent task's issue is `blocked-by` the dependency's issue (`issue.link`). Record each link from the dependent side only. A link present on the forge but no longer in the plan is reported, and removed only if the user agrees.

**The `ci:full` label** (conventions §8 and §11), only with `pipeline.ci: on-demand` in the config. For each milestone with a `Release:` line, find its last live task in plan order. Skip a task whose title starts with "Release": that's the release itself, and the release change request runs CI anyway. A new issue gets it in `issue.create`'s labels. An existing open issue without it gets it with `issue.update`. Either way, the change request that finishes the milestone runs CI before the release. A run after a plan revision labels a new last task in the same way. Never remove `ci:full` from an issue: the maintainer may have added it by hand. With `always`, add none.

**Closing:**

- **Done task, newly created issue:** close it as `completed` straight after creating it, with the comment "Completed before the plan was turned into issues."
- **Done task, existing open issue:** this is a contradiction (the plan says done, the tracker says open). Report it and ask. Never close it on the plan's word alone.
- **Dropped task with an open issue:** close it as `not planned`, with the plan's `Dropped` line as the comment.
- **Dropped task with no issue:** create nothing.
- **Whenever an issue is closed,** remove its state label (`ready`, `blocked` or `needs-decision`) in the same step. State labels only describe open work (conventions §8).
- **Closed issues outside the plan** (no `Plan-Task:` line: fixes, follow-ups, chores) get the same clean-up. Remove any state label from them too. That's the only change this skill makes to an issue outside the plan. It never adds, relabels, links or closes one.

## For the dry run

```
milestone.ensure  create M1: Walking skeleton, M2: Options
issue.create      "T-001: Add the rot13 command"     type:feature priority:normal ready
                  "T-002: Add the test harness"      type:chore   priority:normal blocked
issue.update      #1 (T-002): set milestone M1; append Plan-Task: T-002; title prefix "T-002: "
issue.link        T-002 blocked-by T-001   (+ 3 more)
ci:full           T-002 (last task of M1, release v0.1.0)   (on-demand only)
issue.close       none
labels            remove ready from closed #39, #44 (outside the plan)
Reported, not changed:
  #12 (T-007): title differs from the plan
```

Issues that don't exist yet have no number, so refer to them by task ID: list their links as `T-003 blocked-by T-001, T-002`. The dry run must account for every write the apply step will make. Never write "after it is created" in place of the actual links. Stop at any conflict before the dry run, in a `non-interactive` run too.

## Apply

In this order, stopping at the first failure:

1. `milestone.ensure` for every milestone
2. `issue.create` for every new issue, in plan order, with `ci:full` among the labels where it belongs
3. `issue.update` for existing issues, adding `ci:full` where it belongs
4. `issue.link` for every dependency. All issue numbers are known by now.
5. `issue.close` for done and dropped tasks, as above

If a run stops partway, running it again is safe. Issues already created are found by their `Plan-Task:` line, and every other verb checks before it acts. After the plan changes (tasks added, dropped, moved, or with new dependencies), a later run makes only those changes. It also moves `blocked` issues to `ready` once their dependencies finish.
