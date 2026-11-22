---
name: work-issue
description: Take a ready issue from the tracker to an open change request - branch, commits, tests, plan ticks and a change request that closes the issue - following the idea-to-release conventions. Also resumes an issue whose change request is open, to address review or failing checks. Use to work the next task, or a named issue. Never approves or merges its own change request.
---

# work-issue

Takes one `ready` issue to an open change request that does what its *Done when* list says, with the evidence to show it.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit.

Before doing anything, read `conventions.md`, especially §8 (labels), §9 (issues), §10 (branches, commits and change requests), §11 (pipeline stages and `run` commands) and §13 (safety).

**Verbs used:** `issue.list`, `issue.update` (tracker); `cr.open`, `cr.update`, `cr.status`, `pipeline.render` (forge). Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `issue` | propose the next one | Issue number to work |
| `decision` | none | For a `needs-decision` issue: the user's decision, in their words (step 2) |

## Procedure

### 1. Read the project

Read `.project/config.yml`, the adapters it names, and `docs/plan/PLAN.md`. If a verb above is `not yet implemented`, stop and say which one. Make sure the working tree is clean. If it isn't, stop and say what's uncommitted; never stash or discard someone's changes.

### 2. Choose the issue

Run `issue.list` once with `state=open`.

**With `issue` given,** check it:

- **Closed:** refuse. There's nothing to do.
- **`blocked`:** if any of its blockers is still open, refuse, and name them. If every blocker is closed, the label is stale: say so, and offer to take it as below.
- **`needs-decision`:** refuse, and say what the issue asks to decide, unless the user states the decision when invoking the skill. In that case, go ahead and say so. The task's work is then to record that decision, as a decision record (conventions §7) for a "Decide ..." task, and to make the changes that follow from it. The change request quotes the decision as the user gave it. Only the user's own words count: never go ahead on the agent's own proposal, or in a non-interactive run. The label stays as it is; closing the issue on merge ends it.
- **No state label:** ask before going on. It may not be fully specified (conventions §8).
- **It already has an open change request** (`cr.status` on the branch `<type>/<n>-*`, or a pull request that closes it): switch to **resume mode** (step 9).

**With no `issue`,** propose one:

- from the open issues labelled `ready`, take the earliest milestone in plan order (M2 before M10, not by title), then the highest priority, then the lowest task ID
- skip any with an open change request
- show the choice and the next two candidates, and wait for the user to confirm or pick another
- if no issue is `ready` (or every one already has an open change request), look for a **stale `blocked` label**: the first `blocked` issue, in the same order, whose blockers are all closed. Propose it, and say its label is stale and which blockers closed it
- if there's no such issue either, say so, list the open `blocked` and `needs-decision` issues with what each is waiting on, and stop

**An issue's blockers** are the issues it's linked to as `blocked-by` (the check in `issue.link`). For a plan task with no links, use the issues of the tasks on its `Depends on:` line.

**Taking an issue with a stale `blocked` label:** when the user confirms it, first `issue.update` it from `blocked` to `ready` (the change accept-the-plan would make, conventions §8), and report the change. Then carry on as for any `ready` issue. Change only that one issue's label. Other stale labels are listed, and left for accept-the-plan.

### 3. Read the task

- Read the issue body.
- If it has a `Plan-Task: T-NNN` footer, also read that task in the plan. The plan's *Done when* list is the definition of done.
- If the issue and the plan disagree, stop and ask which one is right (conventions §13).
- Read the task's dependencies, and any decision records it mentions, before starting.

Make a checklist from the *Done when* items. Each item will need evidence (step 6).

### 4. Create the branch

- Update the default branch (`git switch <default>` then `git pull --ff-only`).
- Create `<type>/<n>-<slug>` from it (conventions §10). The type comes from the issue's type label: `type:feature` → `feat`, `type:bug` → `fix`, `type:chore` → `chore`, `type:docs` → `docs`. The slug is three or four words from the title, without the task ID.
- If the branch already exists locally or on the remote with commits, don't overwrite it: ask whether to continue on it.

### 5. Do the work

Make the changes the task needs, and only those. Work discovered along the way that isn't part of this task gets its own issue (conventions §9); mention it to the user rather than folding it in.

**A task that enables a stage.** If the *Done when* list says to enable a pending stage (conventions §11), do it in this change request, once the work has created the stage's command: in `.project/config.yml`, set the stage's `enabled: true` and its `run` command, and remove its `reason`. Then render the pipeline with `pipeline.render` over the committed CI files. Step 6 runs the new command with the others.

Commit in small, coherent steps. Use Conventional Commits, `<type>(<scope>): <summary>`, 72 characters or fewer, with a `Refs: #<n>` footer (conventions §10).

### 6. Verify

**Evidence for every *Done when* item.** For each item, record one of:

- **automated:** the test or check that proves it, which exists in the branch and passes
- **manual:** what was done and what was observed, for items no automated test can cover, such as a run against a scratch repository. Be specific: commands, results, links.

An item with no evidence isn't done. If it can't be done in this change request, stop and tell the user. Don't open a change request that claims it.

**Run every enabled stage.** Run each enabled stage's `run` command from the config (conventions §11), core and extra stages alike, from the repository root.

- **A required stage fails:** fix the cause and run it again. If it can't be fixed within this task, stop and report. Never open a change request with a failing required stage.
- **An advisory stage fails:** keep going, and report it in the change request.
- **An advisory stage's tool is missing:** report it as skipped.
- **A stage has no `run` command:** stop and say which one. The command goes into the config in its own change request (it isn't this task's work). Once that merges, rebase this branch onto the default branch and verify again.

### 7. Tick the plan

For a plan task, tick its *Done when* boxes in `docs/plan/PLAN.md`: every item that has evidence, and only those (conventions §10). Run `scripts/check-plan.sh` on the plan. The script belongs to the idea-to-release skill set, next to `conventions.md`. Commit with `docs(plan): mark <ID> done` and the `Refs: #<n>` footer.

### 8. Open the change request

Say what will happen (write tier, §13): push the branch, then `cr.open`:

- **Title:** a Conventional Commit summary for the whole change (it becomes the squash commit on the default branch), without the task ID
- **Body:**
  ```markdown
  ## What changed

  <the changes, grouped by what they're for>

  ## How it was verified

  <one line per Done-when item, with its evidence>
  <each stage's result: pass, fail (advisory) or skipped, and why>

  ## Issue

  Closes #<n>
  ```

Before opening, look through the body for any other issue reference preceded by a closing keyword (the forge adapter's `cr.open` notes list them), and reword it. A merge would close that issue too.

Then run `cr.status`. Check that `closes` is **exactly** the issue being worked:

- **It's missing:** the closing reference is wrong.
- **It lists another issue:** a closing keyword sits in front of another reference.

In either case, fix the body with `cr.update` and read `cr.status` again. GitHub can take a few seconds to parse a new body, so read it again before deciding it's wrong.

**Wait for the pipeline.** If the project has CI (accept-the-plan has run), wait for the change request's checks to finish, and report `pipeline.status`:

- **A required check fails on CI** although it passed locally: the environments differ (tools, shell, operating system). Fix it on the branch as in resume mode (step 9), and wait again. Don't hand over a red change request without saying so.
- **The branch rules block merging** (`cr.status` mergeable reason `BLOCKED`) for any reason other than a pending review: report why.

**Stop there.** Report the change request link, its status, and anything the user needs to look at. Never approve, merge or close the change request. The person who reviews it isn't the agent that wrote it (conventions §10).

### 9. Resume mode

For an issue whose change request is already open:

1. Run `cr.status`, and read the review comments and failing checks.
2. Check out the branch, and pull it.
3. Address each point, with commits as in step 5, and verify again as in step 6.
4. Push, then `cr.update` the body so *How it was verified* matches what's in the branch now.
5. Report what changed, and stop. Merging is still the user's call.

## Re-running

Running again on an issue with an open change request resumes it (step 9); it never opens a second change request. Running with no `issue` never proposes an issue whose change request is already open.

## Out of scope

- Changing labels, milestones or links: **accept-the-plan**
- Changing the plan beyond ticking this task's boxes: **idea-to-plan**
- Rendering the pipeline, except for a task that enables a stage (step 5): **accept-the-plan**
- Merging: the user. Releasing: **cut-release**
