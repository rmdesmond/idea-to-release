---
name: idea-to-plan
description: Turn a project idea into a plan (docs/plan/PLAN.md) with a verification strategy, milestones and dependency-ordered tasks, following the idea-to-release conventions, or revise an existing plan without renumbering it. Also keeps the project config's pipeline stages in step with the plan. Use when starting a project, when scope changes, or when work done outside the plan needs recording.
---

# idea-to-plan

Turns an idea into `docs/plan/PLAN.md`: the document every issue comes from (conventions §5).

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. When installed, they're in `../idea-to-release/`, next to this skill's folder. In a clone of the idea-to-release repository, they're at its root, `../../` from this skill's folder (conventions §3).

Before doing anything, read `conventions.md`, especially §5 (plan format), §7 (decision records), §11 (pipeline stages) and §13 (safety). This skill only writes files. It uses the neutral verbs `issue.list` (tracker) and `cr.open` (forge). Look them up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `idea` | ask | Text, or a path to a file describing the idea |
| `issue` | none | Issue number for the branch and change request |
| `non-interactive` | off | Don't ask. Work from the idea and the repository alone, and record every assumption (see "Assumptions") |

## Procedure

### 1. Read what exists

- `docs/plan/PLAN.md`:
  - **new mode** if it's missing, or is only the repo-bootstrap stub (no milestones)
  - **revise mode** otherwise
- `README.md`, `docs/decisions/*.md`, `.project/config.yml`, `.project/ledger.yml`
- **Work already done:**
  - `git log --oneline` on the default branch
  - `issue.list` with `state=all`
  - the ledger

  Any issue or merged change that isn't covered by a task in the plan is a candidate for a completed task (step 4).

  If `issue.list` fails (for example, the repository isn't on the forge yet), say so and continue with git history only.

If there's no `.project/config.yml`, say so and suggest running repo-bootstrap first. The skill can still write the plan, but it can't update the pipeline block or open a change request.

### 2. Understand the idea

Work through these topics **one at a time**, in this order. For each, propose an answer drawn from the idea and the repository, then ask the user to confirm or change it. Don't move on until the topic is settled.

1. **Goal:** what the project is for and who uses it, in two or three sentences
2. **Scope:** what is in, and what is explicitly out (non-goals)
3. **Constraints:** language, platform, hosting, dependencies, deadlines, anything fixed
4. **Release target:** what a release ships, and how people install it (step 3)
5. **Milestones:** each one a usable step, not a phase like "design" or "testing". The first is usually a walking skeleton
6. **Tasks:** per milestone (step 3)
7. **Verification strategy:** test levels and pipeline stages (step 3)

In revise mode, start from the existing plan: ask what changed, and go through only the topics the change touches.

**Assumptions.** Anything decided without the user, whether because the run is non-interactive or because the user said "your call", is written down in the plan's *Assumptions* section. A `run` command proposed without confirmation is one of these: write it to the config so the stage can run, and record it as an assumption to confirm before the first task that uses it. Never fill a gap silently.

### 3. Write tasks and the verification strategy

Follow conventions §5:

- **Task size:** each task fits in one change request. If it doesn't, split it now.
- **Task contents:** a one-line imperative title, `Depends on:` (`none` or task IDs), and a `Done when:` checklist.
- **Tests inside tasks:** the *Done when* list names the tests that prove the task. Never write a separate "write tests for X" task.
- **Test infrastructure:** choosing and wiring up the test framework is its own early task, which the first tested tasks depend on.
- **Integration and system tests:** these get their own tasks, usually one or more per milestone, at the end of the milestone and depending on the tasks they exercise.
- **Order:** within a milestone, list tasks so that dependencies come first where possible.
- **Verification strategy:** state the test levels that apply, and the four core stages (`lint`, `build`, `unit`, `integration`). Each stage is enabled, or disabled with a one-line reason. Also list any extra stages, with when they run and whether they're required or advisory (§11).
- **Release target:** propose what a release ships, from the goal and constraints (a command-line tool, an app, a package, a set of agent skills), and how people install it. Match it to a target adapter in the skill set's `adapters/target/` (conventions §2, decision 0013) and confirm the choice with the user:
  - **An adapter fits:** write ``Target: `<name>` - <what ships>``.
  - **None fits:** that's a gap. Say so, and offer two choices:
    - add a task, in the milestone before the first release, to write the adapter (`Add the <name> target`, decision 0001)
    - `Target: none`: releases with notes and a tag, but no packaged artifacts

    The user decides.
  - **Nothing is ever shipped** (a website deployed elsewhere, say): `Target: none - <why>`.
- **Version in the code:** if a task makes the code hold its own version number (`--version`, `package.json`, …), its *Done when* list adds the `release.version_files` entry for that file to `.project/config.yml` (conventions §12). Then cut-release updates it in every release.
- **Run commands:** every enabled stage, core or extra, needs a `run` command (conventions §11): one shell command, run from the repository root, that exits 0 when the stage passes. Propose one from the constraints and the test infrastructure task, for example `npm test`, `go test ./...`, `cargo clippy` or `tests/run.sh`, and confirm it with the user as part of the verification strategy topic. A command that a task will create (a test runner, say) is fine: name that task. Never enable a stage without a command, because work-issue stops on it.

### 4. Record work already done

For each candidate from step 1, ask whether it belongs in the plan. If it does, write it as a task like any other, but with:

- every *Done when* box ticked (`- [x]`)
- an `Issue: #N` line after `Depends on:` naming its existing issue (conventions §5)

Put completed work in the milestone it belongs to. That's often the first one.

### 5. Number tasks

- **new mode:** number tasks `T-001`, `T-002`, ... in plan order.
- **revise mode:**
  - Never change or reuse an existing ID, even if a task moves to another milestone.
  - New tasks take the next number after the highest ID in the plan, including dropped ones.
  - A dropped task keeps its section and gets ` (dropped)` at the end of its heading. Directly under the heading, add `Dropped <date>: <why>`, with today's UTC date (conventions §1).
  - A live task may not depend on a dropped one. For each task that did, update its `Depends on:` line. Also check its *Done when* list for anything the dropped task provided (a flag, a behaviour), and update those items too.

### 6. Write the plan

`docs/plan/PLAN.md`, in this layout:

```markdown
# Plan: <project name>

<One-paragraph summary of the goal.>

## Scope

In: ...
Out: ...

## Constraints

## Assumptions

<Each assumption, and who made it. "None" if there are none.>

## Release target

Target: `<adapter-name>` - <what ships, and how people install it>

## Verification strategy

Test levels: ...

| Stage | Enabled | Run command, or reason if disabled |
|---|---|---|
| lint | yes | `...` |
| build | no | ... |
| unit | ... | ... |
| integration | ... | ... |

Extra stages: none

## M1: <title>

<One sentence: what is usable at the end of this milestone.>

### T-001: <title>
Depends on: none
Done when:
- [ ] ...
```

Then run `scripts/check-plan.sh docs/plan/PLAN.md`. The script belongs to the idea-to-release skill set, next to `conventions.md`, not to the project. Fix every problem it reports before going on.

### 7. Keep the config in step

Compare the verification strategy with the `pipeline` block of `.project/config.yml`, and the release target with its `target`. Work out the changes needed to make them match: `enabled`, `run`, `reason`, `extra_stages` and `target` (removed for `Target: none`). Leave everything else in the config untouched (conventions §4).

- **Enabling** a stage: include `enabled: true` and its confirmed `run` command. Changing a `run` command or a reason: include it in the change.
- **Disabling a stage that is currently enabled:** conventions §11 requires a decision record. Ask first. If the user agrees, write the record. If not, keep the stage enabled and update the plan to match.

### 8. Decision records

Write a record (conventions §7) for each project-level choice made during the conversation that would be hard to reconstruct later. Examples: a language or platform, a scope cut, a stage disabled after being enabled. Don't write records for ordinary task breakdown.

A choice the user made or confirmed gets `Status: accepted`. A choice listed under *Assumptions* gets `Status: proposed`, and the record says it must be accepted or superseded before the first task that depends on it starts. The plan's assumption names the record.

### 9. Review and publish

Show the user:

- a summary of the plan: milestones with task counts, which tasks are already done, and the assumptions
- in revise mode, the difference from the previous plan: tasks added, dropped, moved, or with changed dependencies
- the config changes
- the decision records to be written

Say what will happen, which is a write-tier action (§13):

- create branch `docs/<issue>-plan` (or `docs/plan` with no issue) from the default branch
- commit with `docs(plan): <summary>`, plus a `Refs: #<issue>` footer if there is an issue
- push, then `cr.open`

The change request body lists the summary above and says it was checked with `scripts/check-plan.sh`. Don't merge it: plan changes go through review like any other change (§5).

## Re-running

If nothing changed (same plan, same config, no new completed work), report "Plan up to date; no changes" and stop. Before opening a change request, `cr.open` checks for an open one on the same branch.

## Out of scope

- Creating issues and milestones, and writing the ledger: **plan-to-issues**
- Writing CI files: **ci-setup**
