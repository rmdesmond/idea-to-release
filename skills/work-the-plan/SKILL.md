---
name: work-the-plan
description: Work an accepted plan to completion, following the idea-to-release conventions - take its tasks one at a time in plan order through work-issue, stop at each change request for the user's merge, and at the end of each milestone with a Release line offer write-tutorial and run cut-release. Refuses a plan that isn't accepted. Use after accept-the-plan, and again after each merge; each run picks up where the last one stopped.
---

# work-the-plan

The third of three gates (decision 0021). idea-to-plan wrote the plan, accept-the-plan readied the repository and marked the plan accepted, and this skill works it: task by task, in plan order, to its releases.

It decides **what's next**, and hands the work itself to the skills that do it:

- a task: **work-issue**
- a release: **write-tutorial** (optional), then **cut-release**

One task at a time: it stops at each change request, and the user merges it (conventions §10). Run this skill again after the merge, and it carries on from there.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit. work-issue, write-tutorial and cut-release are sibling skills: read their `SKILL.md` and follow it when this skill hands over to them.

Before doing anything, read `conventions.md`, especially §5 (plan, status and releases), §6 (traceability), §8 (labels), §10 (change requests), §12 (releases) and §13 (safety).

**Verbs used:** `issue.list` (tracker); `cr.status` (forge). The skills it hands over to use their own. Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `tutorial` | ask | `yes` or `no`: whether to run write-tutorial before each release, without asking |

There is no non-interactive mode. Every step it hands over asks for the user's yes in its own way, and the skill stops at each change request for the user's merge.

## Procedure

### 1. Read and check

- `.project/config.yml`, and the adapters it names.
- Make sure the working tree is clean and the default branch is up to date (`git switch <default>`, `git pull --ff-only`, `git fetch --tags`). Never stash or discard someone's changes.
- `docs/plan/PLAN.md` on the default branch must pass `scripts/check-plan.sh`.
- **The plan must be accepted.** Its `Status:` line must say `accepted <date>` (decision 0022). If it says `draft`, refuse:
  - with an open acceptance change request (a `docs/*accept-plan` branch): say it's waiting for the user's merge
  - otherwise: say the plan is a draft, and to run **accept-the-plan** to accept it

  Work never starts on a draft, so the plan and the issues never disagree while work goes on.
- `issue.list` with `state=all`, once. Match each task to its issue by its `Plan-Task:` line, as accept-the-plan does. **A live task with no issue** means the tracker isn't in step with the plan: stop, and say to run accept-the-plan.

### 2. Is a change request waiting?

For each open plan-task issue, look for an open change request, as work-issue does (its step 2: `cr.status` on the branch `<type>/<n>-*`, or a change request that closes the issue). Also look for an open release change request (`chore/release-*`, conventions §12).

**One is open:** this skill works one task at a time, so it doesn't start another. Report the change request, its checks and its reviews (`cr.status`), and stop:

- **Checks pass, and no changes are requested:** it's waiting for the user's merge. Say so, and that running this skill again after the merge carries on.
- **A required check fails, or a reviewer asked for changes:** offer to resume it with **work-issue** (`issue=<n>`, its resume mode). On a yes, follow work-issue from there.
- **A release change request:** offer to continue **cut-release**, which picks up where it stopped.

### 3. Is a release due?

Go through the milestones with a `Release: vX.Y.Z` line, in plan order. A release is **due** when:

- every live task in that milestone is done (its issue is closed as completed), and
- no tag `vX.Y.Z` exists yet (`git tag -l`). A tag with no published release also counts: cut-release finishes it.

If a release is due, it comes before any later task. Releases ship in plan order:

1. **The tutorial,** if wanted. Ask, unless `tutorial` was given. Propose yes if `docs/tutorial.md` exists, since cut-release warns when it's older than the changes it ships. On a yes, follow **write-tutorial**. It ends at its own change request: stop there, and run this skill again after the merge. The next run sees the tutorial merged and goes on with the release.
2. **The release:** follow **cut-release** with `version=vX.Y.Z`. If the milestone has a live task whose title starts with "Release" (for example "Release v0.3.0"), that task is the release itself: pass `issue=<its issue>` too, and don't hand it to work-issue. cut-release keeps all of its own confirmations: the tag and the publish each need the user's yes.

### 4. Take the next task

Propose the next task in plan order: the earliest milestone, then the order of the tasks in the plan. Take the first one whose issue is open, and either:

- `ready`, or
- `blocked`, with every blocker closed: a stale label. Say so (work-issue moves it to `ready` once the user confirms).

Skip `needs-decision` issues: they wait for the user's decision. Also skip a task whose plan text (its *Done when* list, or the assumption it depends on) names a decision record whose own `Status:` line still says `proposed` (read the record, not the plan's wording): it waits until the record is accepted, which accept-the-plan asks about, or superseded through idea-to-plan. Say which record it's waiting on. Show the task, its *Done when* list, and the next two candidates, then wait for a yes, or for the user to pick another.

On a yes, follow **work-issue** with `issue=<n>`. It ends with the change request open: stop there. Say that running this skill again after the merge carries on.

**Nothing to take:** if no task is ready, list the open tasks with what each is waiting on (its open blockers, the decision it needs, or a proposed decision record), and stop.

### 5. Plan complete

When every live task is done and every `Release:` line has its tag, report the plan complete: the milestones, the releases with their tags, and the tasks done.

What comes next is the user's call. A new milestone starts with **idea-to-plan** (revise mode), then **accept-the-plan**.

## Re-running

The skill keeps no state of its own. Every run reads the plan, the issues, the open change requests and the tags, and works out where things stand. So it's safe to run any time, and running it again after each merge is how a plan is worked.

## Out of scope

- Writing or changing the plan: **idea-to-plan**. Accepting it, issues and labels: **accept-the-plan**
- The work of each task: **work-issue**. Releases: **cut-release**. The tutorial: **write-tutorial**
- Working several tasks at once, or merging: **the user**
