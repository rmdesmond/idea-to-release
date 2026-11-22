---
name: idea-to-plan
description: Turn a project idea into a plan (docs/plan/PLAN.md) with a verification strategy, milestones and dependency-ordered tasks, following the idea-to-release conventions, or revise an existing plan without renumbering it. Ends with the plan saved in a repository: a new private one it creates, or a change request in an existing one. Also keeps the project config's pipeline stages in step with the plan. Use when starting a project, when scope changes, or when work done outside the plan needs recording.
---

# idea-to-plan

Turns an idea into `docs/plan/PLAN.md`: the document every issue comes from (conventions §5). It's the first of three gates (decision 0021). The plan is the check that what was asked for is what was understood, so the skill ends with the plan saved where anyone can review it: in a new private repository it creates, or in a change request to an existing one.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit.

Before doing anything, read `conventions.md`, especially §5 (plan format), §7 (decision records), §11 (pipeline stages) and §13 (safety). It uses the neutral verbs `issue.list` (tracker), and `repo.describe`, `repo.create` and `cr.open` (forge). Look them up in the adapters named in `.project/config.yml`, or, for a new repository, in the forge adapter chosen in step 1.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `idea` | ask | Text, or a path to a file describing the idea |
| `issue` | none | Issue number for the branch and change request |
| `owner`, `repo` | from config or git remote; else ask | Only for a new repository (step 10). The repo name is proposed from the project's name |
| `description` | ask, proposing one from the goal | Only for a new repository: its one-line description |
| `non-interactive` | off | Don't ask. Work from the idea and the repository alone, and record every assumption (see "Assumptions") |

## Procedure

### 1. Read what exists

- `docs/plan/PLAN.md`:
  - **new mode** if it's missing, or is only a stub with no milestones
  - **revise mode** otherwise
- `README.md`, `docs/decisions/*.md`, `.project/config.yml`
- **Work already done:**
  - `git log --oneline` on the default branch
  - `issue.list` with `state=all`

  Any issue or merged change that isn't covered by a task in the plan is a candidate for a completed task (step 4).

  If `issue.list` fails (for example, the repository isn't on the forge yet), say so and continue with git history only.

**Where the plan will be saved.** Find the repository: from `.project/config.yml`, else from `git remote get-url origin` (conventions §4: say what was inferred). Then `repo.describe`.

- **An existing repository:** the plan goes in a change request (step 9).
- **No repository yet** (no config and no remote, or a repository that doesn't exist on the forge): the plan goes in a new repository, which step 10 creates. The forge defaults to `github`. The tracker is the forge's own.

### 2. Understand the idea

Work through these topics **one at a time**, in this order. For each, propose an answer drawn from the idea and the repository, then ask the user to confirm or change it. Don't move on until the topic is settled.

1. **Goal:** what the project is for and who uses it, in two or three sentences
2. **Scope:** what is in, and what is explicitly out (non-goals)
3. **Constraints:** language, platform, hosting, dependencies, deadlines, anything fixed
4. **Release target:** what a release ships, and how people install it (step 3)
5. **Milestones:** each one a usable step, not a phase like "design" or "testing". The first is usually a walking skeleton. Also ask which milestones end in a release, and with which version: each of those gets a `Release: vX.Y.Z` line (step 6)
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
- **Run commands:** every enabled stage, core or extra, needs a `run` command (conventions §11): one shell command, run from the repository root, that exits 0 when the stage passes. Propose one from the constraints and the test infrastructure task, for example `npm test`, `go test ./...`, `cargo clippy` or `tests/run.sh`, and confirm it with the user as part of the verification strategy topic. Every enabled stage must pass from the pipeline's first run, before any task is done, and on every change request after it. So:
  - **A command that a task will create** (a test runner, say) makes the stage **pending** (conventions §11): disabled in the config with `reason: "not set up yet: T-NNN adds it"`, naming that task. The task's *Done when* list gets an item: ``Enable the `<stage>` stage with `run: <command>`, and render the pipeline again``. In the verification strategy table, write `from T-NNN` in the *Enabled* column, and the command in the last.
  - **A command that works on an empty repository** is enabled now. Don't name files that later tasks create, and make sure the command passes when there's nothing to check yet: `shellcheck bin/tool tests/*.sh` fails until `bin/tool` exists, and `shellcheck $(git ls-files '*.sh')` fails with no files at all, while `git ls-files -z 'bin/*' '*.sh' | xargs -0 -r shellcheck` lints whatever is there, including nothing.
  - Never enable a stage without a command, because work-issue stops on it.

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

Status: draft

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

Release: v0.1.0

<One sentence: what is usable at the end of this milestone.>

### T-001: <title>
Depends on: none
Done when:
- [ ] ...
```

- **`Status:`** goes directly under the title (conventions §5). This skill always writes `Status: draft`: in new mode, and in revise mode too, even when the plan was `accepted <date>`. A changed plan has to be accepted again before it's worked (decision 0022). Ticking a task's boxes isn't a revision, and leaves the status alone.
- **`Release: vX.Y.Z`** goes under the heading of a milestone that ends in a release, before its summary. Leave it out for the other milestones. Pre-1.0, a release usually bumps the minor version (conventions §12).

Then run `scripts/check-plan.sh docs/plan/PLAN.md`. The script belongs to the idea-to-release skill set, next to `conventions.md`, not to the project. Fix every problem it reports before going on.

### 7. Keep the config in step

Compare the verification strategy with the `pipeline` block of `.project/config.yml`, and the release target with its `target`. Work out the changes needed to make them match: `enabled`, `run`, `reason`, `extra_stages` and `target` (removed for `Target: none`). Leave everything else in the config untouched (conventions §4).

**A new repository has no config yet.** Write `.project/config.yml` in the conventions §4 shape:
- `forge` and `tracker`, `owner` and `repo` (step 10), `default_branch: main` and `visibility: private`
- `target`, and the `pipeline` block, from the plan
- the defaults for the rest: `merge_method: squash`, `release: {versioning: semver, strategy: trunk, tag_prefix: v, version_files: []}`, and `review: {required_approvals: 0, code_owners: false}`. Only the owner can write to a new repository, and a required approval would block every merge, since nobody can approve their own change request

- **Enabling** a stage: include `enabled: true` and its confirmed `run` command. Changing a `run` command or a reason: include it in the change.
- **A pending stage:** `enabled: false` with `reason: "not set up yet: T-NNN adds it"`. Its command is in the plan, and its task enables it.
- **Disabling a stage that is currently enabled:** conventions §11 requires a decision record. Ask first. If the user agrees, write the record. If not, keep the stage enabled and update the plan to match.

### 8. Decision records

Write a record (conventions §7) for each project-level choice made during the conversation that would be hard to reconstruct later. Examples: a language or platform, a scope cut, a stage disabled after being enabled. Don't write records for ordinary task breakdown.

A choice the user made or confirmed gets `Status: accepted`. A choice listed under *Assumptions* gets `Status: proposed`, and the record says it must be accepted or superseded before the first task that depends on it starts. The plan's assumption names the record.

### 9. Review and publish

Show the user, in both cases:

- a summary of the plan: milestones with task counts, which tasks are already done, and the assumptions
- in revise mode, the difference from the previous plan: tasks added, dropped, moved, or with changed dependencies
- the config changes
- the decision records to be written

**In a new repository,** go on to step 10.

**In an existing repository,** say what will happen, which is a write-tier action (§13):

- create branch `docs/<issue>-plan` (or `docs/plan` with no issue) from the default branch
- commit with `docs(plan): <summary>`, plus a `Refs: #<issue>` footer if there is an issue
- push, then `cr.open`

The change request body lists the summary above and says it was checked with `scripts/check-plan.sh`. Don't merge it: plan changes go through review like any other change (§5).

After the change request merges, the plan is a draft again: run **accept-the-plan** to accept it.

### 10. Save the plan in a new repository

Only when step 1 found no repository.

1. **Owner, name and description.** Use the arguments, or ask: propose the repository name from the project's name (lower case, words joined by `-`), and a one-line description from the goal. Never invent a description the user didn't confirm. If `repo.describe` now finds the repository, stop and say so: it already exists, so run again to save the plan in a change request.
2. **Dry run.** Creating a repository is an admin action (§13). Show what will happen, and wait for a yes:

   ```
   Repository: you/titlecase   create, private
   Commit:     docs(plan): plan titlecase   → main, the repository's first commit
               docs/plan/PLAN.md (Status: draft), docs/decisions/0001-…, .project/config.yml
   Next:       review the plan, then accept-the-plan
   ```

   The repository is always created **private**. That isn't a question: the plan is a draft, and going public later is a separate, deliberate change (accept-the-plan with `visibility=public`). A `non-interactive` run stops after the dry run.
3. **Apply,** stopping at the first failure:
   1. `git init -b main` if the folder isn't a git repository yet. Existing local commits are kept, and pushed with the plan.
   2. `repo.create` with `visibility: private`, which also sets the `origin` remote.
   3. Commit the plan, the decision records and the config on `main`: `docs(plan): <summary>`. This is one of the two commits made straight to the default branch, before any branch rules exist (conventions §10).
   4. Push `main`.
4. **Report** the repository's address, and what comes next: review the plan, change it with this skill if it's not right, and when it is, run **accept-the-plan**. That's the user accepting the plan, and it readies the repository for work.

## Re-running

If nothing changed (same plan, same config, no new completed work), report "Plan up to date; no changes" and stop. Before opening a change request, `cr.open` checks for an open one on the same branch.

## Out of scope

- Accepting the plan, and the rest of the repository's setup (labels, settings, standard files, the pipeline): **accept-the-plan**
- Creating issues and milestones, and writing CI files: **accept-the-plan**
