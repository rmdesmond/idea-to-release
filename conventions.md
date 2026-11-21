# Conventions

Shared rules for the idea-to-release skill set. Every skill reads this file before acting. Skills describe *what* to do in the neutral terms defined here; adapters translate those terms into commands for a specific forge or tracker.

If a skill and this file disagree, this file wins. If this file and the project's `.project/config.yml` disagree, the config wins, because it records choices the project owner made.

## 1. Vocabulary

Skills use only these neutral terms. Adapters map them to forge-specific names.

| Neutral term | Meaning | GitHub | GitLab |
|---|---|---|---|
| forge | Service hosting the remote repository | GitHub | GitLab |
| tracker | Service holding tickets (may be the forge) | Issues | Issues |
| issue | One trackable unit of work | issue | issue |
| change request (CR) | Proposed merge of a branch into another | pull request | merge request |
| milestone | Named group of issues with a shared goal | milestone | milestone |
| branch rule | Protection applied to a branch | ruleset / branch protection | protected branch |
| pipeline | Automated checks run on a commit or CR | Actions workflow | CI pipeline |
| stage | One named step of the pipeline (lint, build, ...) | job | job / stage |
| gate | A stage that must pass before a merge or release | required status check | required pipeline job |
| release | Published, tagged version with notes | release | release |

## 2. Neutral verbs

These are the only operations skills may ask an adapter to perform. An adapter must define each one or declare a fallback (section 14).

- **Repository:** `repo.create`, `repo.configure` (visibility, merge methods, features), `repo.describe`
- **Access:** `access.grant`, `access.list`, `rule.protect-branch`, `rule.require-review`, `rule.require-checks`
- **Tracker:** `label.ensure`, `milestone.ensure`, `issue.create`, `issue.update`, `issue.link` (blocks / blocked-by / parent), `issue.close`, `issue.list`
- **Changes:** `cr.open`, `cr.update`, `cr.status`, `cr.merge`
- **Pipeline:** `pipeline.render` (write CI files from the neutral pipeline description), `pipeline.status`
- **Release:** `tag.create`, `release.draft`, `release.publish`

Verbs ending in `ensure` are idempotent: create if missing, leave alone if present, report a difference if present but different.

## 3. Repository layout

```
.project/
  config.yml        # forge, tracker, and project choices (section 4)
  ledger.yml        # traceability record (section 6)
docs/
  plan/PLAN.md      # the plan (section 5)
  decisions/        # decision records (section 7)
CHANGELOG.md
README.md
LICENSE
.gitignore
```

## 4. Project config

`.project/config.yml` is written once by repo-bootstrap and read by every other skill. The one exception is the `pipeline` block, which idea-to-plan keeps in step with the plan's verification strategy (section 5). A skill that finds no config infers the forge from the git remote URL, tells the user what it inferred, and offers to write the file.

```yaml
forge: github            # adapter name under adapters/forge/
tracker: github          # adapter name under adapters/tracker/
owner: example-org
repo: example-project
default_branch: main
visibility: private      # private | public | internal
merge_method: squash     # squash | merge | rebase
release:
  versioning: semver
  strategy: trunk        # trunk | release-branches
  tag_prefix: v
review:
  required_approvals: 1
  code_owners: false
pipeline:
  stages:                # see section 11
    lint:
      enabled: true
      run: "npm run lint"   # command that runs the stage, see section 11
    build:
      enabled: false
      reason: "Markdown-only project; nothing to compile"
    unit:
      enabled: true
      coverage_min: null # optional floor, as a percentage
      run: "npm test"
    integration:
      enabled: false
      reason: "No external interfaces yet"
  extra_stages: []       # project-defined stages, see section 11
```

## 5. Plan format

The plan lives at `docs/plan/PLAN.md`. It is the origin of every issue.

- A plan has **milestones** (`M1`, `M2`, ...) and each milestone has **tasks** (`T-001`, `T-002`, ...).
- Task IDs are numbered across the whole plan, are never reused, and never change, even if a task moves to another milestone or is dropped. A dropped task is marked `(dropped)` and kept.
- Each task states: a one-line title, what done looks like (acceptance criteria as a checklist), and any tasks it depends on.
- A task should be small enough for one change request. If it needs more than one, split it in the plan first.
- **Tests for a task are part of that task.** Its "done when" list names the tests that prove it, and they land in the same change request. "Write tests for X" is never a separate task.
- **Test infrastructure is a task.** Choosing a framework and wiring up the harness is one-time work and gets its own early task.
- **Tests that span tasks get their own tasks.** Integration and system-level tests are planned explicitly, usually one or more per milestone.
- The plan opens with a **Verification strategy** section stating which test levels apply to this project, which pipeline stages are enabled, any extra stages, and why. The config's `pipeline` block mirrors it.

```markdown
## M1: Walking skeleton

### T-001: Command-line entry point
Depends on: none
Done when:
- [ ] `tool --version` prints the version
- [ ] Unit test covers argument parsing
```

- **Work that already has an issue.** A task may carry an `Issue: #N` line after `Depends on:`. It names an issue that already exists for the task, typically work done before the plan was written. plan-to-issues adopts that issue instead of creating one. Work that is already done has every box in its *Done when* list ticked (`- [x]`). The plan records what was agreed; whether a task is merged and released is the ledger's job (section 6).
- `scripts/check-plan.sh` checks a plan against this section.

Changes to the plan after issues exist go through a change request like any other change, so the plan's git history shows how scope moved. Ticking a task's boxes when it's done is part of that task's own change request (section 10).

## 6. Ledger

`.project/ledger.yml` connects each plan task to what happened to it. It is what makes the history portable: it survives a move to another forge.

```yaml
tasks:
  T-001:
    milestone: M1
    issue: 12                # tracker's issue identifier
    change_requests: [15]
    released_in: v0.1.0
    created: 2026-11-20
    merged: 2026-11-21
    released: 2026-11-24
```

Rules:

- **Only two skills write the ledger.** plan-to-issues adds entries when it creates issues. release fills in `change_requests`, `merged`, `released_in` and `released` by reconciling against the forge. work-issue does not touch it, which avoids merge conflicts between parallel branches.
- The ledger is the idempotency check: before creating an issue for a task, look the task up. If it already has an issue, update that issue instead of creating another.
- Ledger changes are committed on the default branch through a change request titled `chore(ledger): ...`. They often have no issue of their own. Then the branch is `chore/ledger-<YYYYMMDD>`, the one exception to the branch pattern in section 10.
- The ledger keeps exactly the shape shown above: two-space indent for task IDs, four for fields, one `key: value` per line, and lists written inline (`[15, 16]`). An empty ledger is `tasks: {}`. This lets `scripts/check-ledger.sh` check it without a YAML library. The check also confirms that every task exists in the plan, with the same milestone.

## 7. Decision records

Any choice that would be hard to reconstruct later gets a short record in `docs/decisions/NNNN-short-title.md` (four-digit sequence number).

```markdown
# 0003: Use squash merges

Date: 2026-11-20
Status: accepted        # proposed | accepted | superseded by NNNN

## Context
## Decision
## Consequences
```

Skills write a record when they make or are told a project-level choice: licence, visibility, branching and release strategy, review rules, CI design, anything that deviates from this file. Records are never edited after acceptance; a new record supersedes the old one.

## 8. Labels

A small fixed set. Skills create these with `label.ensure` and do not invent others without asking.

| Group | Labels | Rule |
|---|---|---|
| Type | `type:feature`, `type:bug`, `type:chore`, `type:docs` | Exactly one per issue |
| Priority | `priority:high`, `priority:normal`, `priority:low` | Exactly one per issue |
| State | `ready`, `blocked`, `needs-decision` | Zero or one |
| Area | `area:<name>` | Optional, project-defined |

`ready` means the issue is fully specified and nothing blocks it; work-issue only picks up `ready` issues. Open, closed and in-progress are tracked by the issue's own state and its linked change request, not by labels.

## 9. Issues

- **Title:** the plan task ID, a colon, then the task title in the imperative. Example: `T-001: Add command-line entry point`. The ID makes a task findable from the issue list without opening issues. Issues for work outside the plan (the last point below) have no ID prefix.
- **Body:** context, acceptance criteria copied from the plan as a checklist, dependencies, then a footer line `Plan-Task: T-001` linking back to the plan.
- **Milestone:** the plan milestone, named `M1: Walking skeleton`.
- **Dependencies:** recorded with `issue.link`. If a task depends on an unfinished task, its issue gets `blocked` instead of `ready`.
- Work discovered mid-flight that is not in the plan still gets an issue. If it is more than a small fix, add a task to the plan first.

## 10. Branches, commits and change requests

**Branches:** `<type>/<issue-id>-<short-slug>`, with type one of `feat`, `fix`, `chore`, `docs`. Example: `feat/12-cli-entry-point`. The default branch always stays releasable. Nobody, human or agent, pushes directly to it.

**Commits:** Conventional Commits. `<type>(<optional scope>): <summary>`, imperative, 72 characters or fewer. Breaking changes use `!` after the type and a `BREAKING CHANGE:` footer. Each commit references its issue in a footer: `Refs: #12`.

**Change requests:**

- One issue per CR, one CR per issue where possible.
- Title follows the commit format, since with squash merges it becomes the commit on the default branch and feeds the changelog.
- Body: what changed, how it was verified, and the adapter's closing reference to the issue (on GitHub, `Closes #12`).
- A CR includes the tests named in its task's "done when" list. work-issue does not open a CR without them.
- A CR for a plan task also ticks that task's *Done when* boxes in `docs/plan/PLAN.md`. Merging the CR then closes the issue and marks the task done together, and the plan, the tracker and the ledger stay in step.
- Merge only when every gate passes (section 11) and required approvals are in. The agent that wrote a CR does not approve it.

## 11. Pipeline stages and gates

A **stage** is a named step of the pipeline. A **gate** is a stage that is required to pass; an **advisory** stage reports its result without blocking.

**Core stages.** Every project has these four, in this order, with these exact names, so branch rules can require the same checks everywhere:

| Stage | Purpose | On change request | On merge to default | On release |
|---|---|---|---|---|
| `lint` | Formatting and static checks | Required | | |
| `build` | Compile or package | Required | Required | Required |
| `unit` | Tests of single units in isolation | Required | Required | Required |
| `integration` | Tests across units or interfaces | Required | Required | Required |

**No-op stages.** A core stage the project does not need is disabled in the config with a `reason`, not removed. `pipeline.render` still emits it as a placeholder that:

- carries a comment giving the reason,
- prints `skipped: <reason>` when it runs, and
- reports success, so the gate stays satisfiable.

Enabling it later means filling in the stage, with no change to branch rules. Disabling a stage that was enabled needs a decision record.

**Extra stages.** A project may add stages under `pipeline.extra_stages`. Each declares a name, when it runs (`change_request`, `merge`, `release`, or `schedule`), and whether it is `required` or `advisory`:

```yaml
extra_stages:
  - name: dependency-audit
    runs_on: [change_request, schedule]
    mode: advisory
```

Typical candidates: security scanning, dependency audit, licence compliance, docs build, packaging or install smoke tests, performance benchmarks, and software-in-the-loop (SIL) or hardware-in-the-loop (HIL) tests. Slow or hardware-bound stages such as HIL usually run on `schedule` and gate only `release`, since they cannot reasonably gate every change request.

**Run commands.** Every enabled stage, core or extra, has a `run` command in the config: one shell command, run from the repository root, that exits 0 when the stage passes. It is the single definition of the stage:

- work-issue runs it locally before opening a change request. Required stages must pass; advisory stages are reported. If an advisory stage's tool isn't installed, it is reported as skipped.
- ci-setup renders the same command into the pipeline, so local and CI results can't drift apart.

A disabled stage has a `reason` instead of a `run`.

**Thresholds.** There is no default coverage floor. A project that wants one sets `coverage_min` on the `unit` stage, and the stage fails below it.

**Waivers.** Merging or releasing past a failing gate is an admin action (section 13): it needs explicit confirmation from the user and a decision record naming the gate, the reason, and the follow-up issue. Agents never waive a gate on their own.

## 12. Versions and releases

- Semantic Versioning. Tags are `v<major>.<minor>.<patch>`. Before `1.0.0`, breaking changes bump the minor version.
- The version bump is derived from the commit types merged since the last tag: `fix` → patch, `feat` → minor, breaking → major.
- `CHANGELOG.md` follows the Keep a Changelog layout, with entries generated from merged CR titles and grouped as Added, Changed, Fixed, Removed.
- Release notes list each included task with its issue and CR, taken from the ledger, so a release shows which parts of the plan it delivered.
- A release is drafted first and published only after the user confirms, and only when every release gate passes.

## 13. Safety

Every operation falls into one of three tiers.

| Tier | Examples | Rule |
|---|---|---|
| Read | list, describe, status | Run freely |
| Write | create issue, open CR, push a branch, add a label | Say what will happen, then run |
| Admin | create repo, change visibility, access, branch rules, merge, publish a release, create a tag, waive a gate | Show a dry run of the exact changes and wait for explicit confirmation |

Always:

- Never force-push to, delete, or rewrite the history of the default branch or a release tag.
- Never delete issues, branches with unmerged work, or releases. Close or supersede instead.
- Never write secrets or tokens into the repo, issues, or logs.
- Be re-runnable: check for existing state (ledger, then forge) before creating anything, so running a skill twice does not create duplicates.
- Stop and ask when the forge's state contradicts the ledger or the plan. Do not pick a side silently.

## 14. Fallbacks

When a forge or tracker lacks a feature, the adapter states the fallback, and the skill uses it and tells the user. Defaults:

| Missing feature | Fallback |
|---|---|
| Issue dependencies | `Depends on: #N` lines in the issue body, plus the `blocked` label |
| Parent / sub-issues | Task-list checklist in the parent issue |
| Milestones | `milestone:<name>` label |
| Required reviews or checks not available on the plan tier | Record the gap in a decision record; work-issue enforces the rule by procedure |
| Draft releases | Prepare notes in a CR against `CHANGELOG.md`; publish after merge |
