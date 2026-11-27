# Conventions

Shared rules for the idea-to-release skill set. Every skill reads this file before acting. Skills describe *what* to do in the neutral terms defined here; adapters translate those terms into commands for a specific forge, tracker or release target.

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

**Dates.** Every date in these conventions is a UTC date, written `YYYY-MM-DD` (`YYYYMMDD` in a branch name). That covers `Dropped <date>` lines, decision record `Date:` lines and release dates. Take a forge timestamp's date after converting it to UTC (GitHub's timestamps already are). Take today's date with `date -u +%Y-%m-%d`, not the local date, so that runs in different timezones, and CI, agree.

## 2. Neutral verbs

These are the only operations skills may ask an adapter to perform. An adapter must define each one or declare a fallback (section 14).

- **Repository:** `repo.create`, `repo.configure` (visibility, merge methods, features), `repo.describe`
- **Access:** `access.grant`, `access.list`, `rule.protect-branch`, `rule.require-review`, `rule.require-checks`
- **Tracker:** `label.ensure`, `milestone.ensure`, `issue.create`, `issue.update`, `issue.link` (blocks / blocked-by / parent), `issue.close`, `issue.list`
- **Changes:** `cr.open`, `cr.update`, `cr.status`, `cr.list` (merged change requests: number, title, merge commit and date, issues closed), `cr.merge`
- **Pipeline:** `pipeline.render` (write CI files from the neutral pipeline description), `pipeline.status`
- **Release:** `tag.create`, `release.draft`, `release.publish`
- **Target:** `package.build` (the release artifacts, from a clean copy of the tagged commit), `package.verify` (install them somewhere clean and smoke-test them), `package.publish` (push them to the target's channel, if it has one), `install.describe` (the install instructions, for the README and the release notes), `usage.describe` (how to use what's installed, from real output, for the release README)

Tracker verbs are defined by tracker adapters (`adapters/tracker/`), Target verbs by target adapters (`adapters/target/`), and all others by forge adapters (`adapters/forge/`). The target is what a project ships: a command-line tool, an app, a package, a set of agent skills (decision 0013).

Verbs ending in `ensure` are idempotent: create if missing, leave alone if present, report a difference if present but different.

## 3. Repository layout

```
.project/
  config.yml        # forge, tracker, and project choices (section 4)
docs/
  plan/PLAN.md      # the plan (section 5)
  decisions/        # decision records (section 7)
  tutorial.md       # optional: a worked example, written by write-tutorial from real runs (decision 0020)
CHANGELOG.md
README.md
LICENSE
.gitignore
```

**Where the skill set's own files are.** `conventions.md`, `adapters/` and the check scripts (`scripts/check-*.sh`) belong to the skill set, not to the project. A skill finds them relative to its own folder:

- **The Claude Code plugin `i2r`:** at the plugin's root, which is the repository's root copied as it is. That's `${CLAUDE_PLUGIN_ROOT}`, and two levels up from the skill folder (decision 0019).
- **In a clone of the idea-to-release repository:** at the repository root, two levels up from the skill folder.
- **Installed by `install.sh`:** in `idea-to-release/`, a sibling of the skill folders (for example `.claude/skills/idea-to-release/conventions.md` next to `.claude/skills/work-issue/`). The folder has no `SKILL.md`, so agents don't load it as a skill.

See decisions 0014 and 0019.

## 4. Project config

`.project/config.yml` is written once, by idea-to-plan, when it saves a plan in a repository that has none, and read by every other skill. The exceptions are the `pipeline` block and `target`, which idea-to-plan keeps in step with the plan's verification strategy and release target (section 5). A skill that finds no config infers the forge from the git remote URL, tells the user what it inferred, and offers to write the file.

```yaml
forge: github            # adapter name under adapters/forge/
tracker: github          # adapter name under adapters/tracker/
target: shell-cli        # adapter name under adapters/target/: what the project ships
owner: example-org
repo: example-project
default_branch: main
visibility: private      # private | public | internal
merge_method: squash     # squash | merge | rebase
release:
  versioning: semver
  strategy: trunk        # trunk | release-branches
  tag_prefix: v
  version_files: []      # "<path>:<marker>" for each file that holds the version, see section 12
review:
  required_approvals: 1
  code_owners: false
pipeline:
  ci: always             # always | on-demand: when the forge runs the pipeline, see section 11
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
- **Status.** Directly under its title, a plan has one `Status:` line: `Status: draft`, or `Status: accepted <date>` with a UTC date (`2026-11-22`). idea-to-plan writes `draft`, in every new plan and every revision. A plan is accepted explicitly, and only an accepted plan is worked (decision 0022). A stub with no milestones needs no status.
- **Releases.** A milestone that ends in a release has one `Release: vX.Y.Z` line under its heading, before its first task. The version is the one that milestone's release gets.
- Task IDs are numbered across the whole plan, are never reused, and never change, even if a task moves to another milestone or is dropped. A dropped task is marked `(dropped)` and kept.
- Each task states: a one-line title, what done looks like (acceptance criteria as a checklist), and any tasks it depends on.
- A task should be small enough for one change request. If it needs more than one, split it in the plan first.
- **Tests for a task are part of that task.** Its "done when" list names the tests that prove it, and they land in the same change request. "Write tests for X" is never a separate task.
- **Test infrastructure is a task.** Choosing a framework and wiring up the harness is one-time work and gets its own early task.
- **Tests that span tasks get their own tasks.** Integration and system-level tests are planned explicitly, usually one or more per milestone.
- The plan opens with a **Verification strategy** section stating which test levels apply to this project, which pipeline stages are enabled, any extra stages, and why. It also says when CI runs, in one line, `CI: always` or `CI: on-demand` (section 11). A plan without the line means `always`. The config's `pipeline` block mirrors it.
- An optional **Release target** section says what the project ships, and how people install it, in one line: ``Target: `shell-cli` - a `slug` command, installed into a `bin` folder``, or `Target: none` for releases without packaged artifacts. The name is a target adapter (`adapters/target/<name>.md`, decision 0013), and the config's `target` mirrors it.

```markdown
## M1: Walking skeleton

Release: v0.1.0

### T-001: Command-line entry point
Depends on: none
Done when:
- [ ] `tool --version` prints the version
- [ ] Unit test covers argument parsing
```

- **Work that already has an issue.** A task may carry an `Issue: #N` line after `Depends on:`. It names an issue that already exists for the task, typically work done before the plan was written. accept-the-plan adopts that issue instead of creating one. Work that is already done has every box in its *Done when* list ticked (`- [x]`). The plan records what was agreed; whether a task is merged and released is read from the tracker and forge (section 6).
- `scripts/check-plan.sh` checks a plan against this section.

Changes to the plan after issues exist go through a change request like any other change, so the plan's git history shows how scope moved. Ticking a task's boxes when it's done is part of that task's own change request (section 10).

## 6. Traceability

Each plan task can be followed to the release that shipped it. Nothing stores this trail. It's read from the tracker, the forge and git when it's needed (decision 0018):

| Link | Where it's read from |
|---|---|
| task → issue | the issue whose body ends with `Plan-Task: <ID>` (section 9). The `<ID>: ` title prefix is a cross-check, and the plan's `Issue:` line names an issue to adopt (section 5) |
| issue → change requests | the merged change requests whose `closes` includes the issue (`cr.list`) |
| change request → release | the release tag range that holds its merge commit: after the previous `<tag_prefix>X.Y.Z` tag, up to and including the release's tag |

Rules:

- **No skill writes a ledger file.** A leftover `.project/ledger.yml` from an earlier version is ignored, and can be deleted.
- **Idempotency:** before creating an issue for a task, look for it: the plan's `Issue:` line, then an issue carrying the task's `Plan-Task:` line. If one exists, update it instead of creating another.
- **A task closed with no change request** (work done before the tracker was used, or closed by hand as completed) is delivered by the first release after its issue was closed, unless the task was already done in the plan at the previous release's tag. Then it shipped earlier, and its issue was only created and closed later, for example when accept-the-plan first runs on a project that has already released.

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
| Pipeline | `ci:full` | Zero or one. Only in on-demand CI (section 11) |

`ready` means the issue is fully specified and nothing blocks it; work-issue only picks up `ready` issues.

**Who changes state labels:** accept-the-plan sets them, refreshes them as dependencies finish, and removes them from closed issues. work-issue changes one, and only on the issue it's about to take: `blocked` → `ready`, when every blocker is closed and the user has confirmed taking it. No other skill changes them. Open, closed and in-progress are tracked by the issue's own state and its linked change request, not by labels.

**`ci:full`** means "run the full pipeline on this change request". It is used only when the config says `pipeline.ci: on-demand`. accept-the-plan puts it on the issue of the last task of each milestone with a `Release:` line. work-issue copies it from the issue to the change request it opens, cut-release puts it on the release change request, and the maintainer may add it by hand to any other issue or change request.

## 9. Issues

- **Title:** the plan task ID, a colon, then the task title in the imperative. Example: `T-001: Add command-line entry point`. The ID makes a task findable from the issue list without opening issues. Issues for work outside the plan (the last point below) have no ID prefix.
- **Body:** context, acceptance criteria copied from the plan as a checklist, dependencies, then a footer line `Plan-Task: T-001` linking back to the plan.
- **Milestone:** the plan milestone, named `M1: Walking skeleton`.
- **Dependencies:** recorded with `issue.link`. If a task depends on an unfinished task, its issue gets `blocked` instead of `ready`.
- Work discovered mid-flight that is not in the plan still gets an issue. If it is more than a small fix, add a task to the plan first.

## 10. Branches, commits and change requests

**Branches:** `<type>/<issue-id>-<short-slug>`, with type one of `feat`, `fix`, `chore`, `docs`. Example: `feat/12-cli-entry-point`. One exception: `chore/release-<version>` (section 12). The default branch always stays releasable. Nobody, human or agent, pushes directly to it, with two exceptions, both in a new repository before its branch rules exist: idea-to-plan's first commit, which saves the plan (decision 0021), and the setup commit that readies the repository for work.

**Commits:** Conventional Commits. `<type>(<optional scope>): <summary>`, imperative, 72 characters or fewer. Breaking changes use `!` after the type and a `BREAKING CHANGE:` footer. Each commit references its issue in a footer: `Refs: #12`.

**Change requests:**

- One issue per CR, one CR per issue where possible.
- Title follows the commit format, since with squash merges it becomes the commit on the default branch and feeds the changelog.
- Body: what changed, how it was verified, and the adapter's closing reference to the issue (on GitHub, `Closes #12`).
- A CR includes the tests named in its task's "done when" list. work-issue does not open a CR without them.
- A CR for a plan task also ticks that task's *Done when* boxes in `docs/plan/PLAN.md`. Merging the CR then closes the issue and marks the task done together, and the plan and the tracker stay in step.
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

**Pending stages.** A stage whose command a task will create (a test runner, say) is disabled until that task, with `reason: "not set up yet: T-NNN adds it"`. So the pipeline passes from its first run, and every core check exists before the branch rules require it. The task's *Done when* list includes enabling the stage: its change request sets `enabled: true` and the `run` command, and renders the pipeline again, so it's the first change request the real check runs on.

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
- accept-the-plan renders the same command into the pipeline, so local and CI results can't drift apart.

A disabled stage has a `reason` instead of a `run`.

**When CI runs.** The config's `pipeline.ci` says when the forge runs the pipeline. A config without it means `always` (decision 0026):

| Event | `always` | `on-demand` |
|---|---|---|
| Change request | Every push | Only if it carries the `ci:full` label (section 8), or is a release change request (`chore/release-*`, section 12) |
| Merge to the default branch | Runs | Runs nothing |
| Release tag | Runs | Runs |
| Manual run | Not offered | Possible, and runs every stage |

In `on-demand`, the pipeline still has every stage, and a change request that doesn't run CI reports its jobs as skipped. A skipped job counts as passing, so the branch rules are the same in both modes, and nothing waits for a check that never reports. For such a change request, work-issue's local runs of the stages are the check, and its body records them.

`on-demand` is for private repositories, where the forge limits CI minutes. A public repository uses `always`.

**Thresholds.** There is no default coverage floor. A project that wants one sets `coverage_min` on the `unit` stage, and the stage fails below it.

**Waivers.** Merging or releasing past a failing gate is an admin action (section 13): it needs explicit confirmation from the user and a decision record naming the gate, the reason, and the follow-up issue. Agents never waive a gate on their own.

## 12. Versions and releases

- Semantic Versioning. Tags are `<tag_prefix><major>.<minor>.<patch>` (`v0.1.0`). Before `1.0.0`, breaking changes bump the minor version.
- **What's in a release:** the change requests merged to the default branch since the last release tag, found with `cr.list`, whose merge commits lie between that tag and the release commit.
- **The version bump** comes from their titles (Conventional Commits): a breaking change (`!` after the type, or a `BREAKING CHANGE:` footer) → major; `feat` → minor; `fix` → patch. Other types don't bump. If nothing bumps, there's nothing to release.
- **The first release,** with no earlier tag, is `0.1.0`, unless the user names another version. A named version must be valid and higher than the last tag.
- **The release date** is the UTC date the release change request is prepared. The changelog heading uses it.
- **`CHANGELOG.md`** follows the Keep a Changelog layout. Its entries are the change request titles, without the type prefix, followed by the change request reference (`- Add the release skill (#82)`). Each entry goes in the **first** group that matches, in this order:
  1. **Removed:** a title whose summary starts with "remove" or "drop", of any type except `fix`. A breaking one is marked **Breaking:** (`refactor!: remove the ledger` → Removed, **Breaking:**).
  2. **Changed:** any other breaking change, marked **Breaking:**; then `refactor` and `perf`.
  3. **Fixed:** `fix`, including one whose summary starts with "remove" (it removes a defect, not a feature).
  4. **Added:** `feat`.

  Other types (`docs`, `chore`, `test`, `ci`, `build`, `style`) aren't listed. The changelog lists the groups as Added, Changed, Fixed, Removed (Keep a Changelog's order), leaving out empty ones.
- **Release notes** list each included task with its issue and change requests, grouped by milestone and found through the links in section 6, so a release shows which parts of the plan it delivered. They also carry the changelog section, the install instructions from the target adapter (`install.describe`) and, if the project has `docs/tutorial.md`, a link to it at the tag. The archive ships the tutorial too (decision 0020).
- **The release README.** Every release archive has its own `README.md` at the top, in place of the project's: a title and four sections, `## Version`, `## About` (the plan's summary), `## Install` (`install.describe`) and `## Usage` (`usage.describe`, from real output). `package.build` writes it, and `package.verify` fails without it (decision 0023).
- **Version files.** If the code holds its own version number (a `--version` string, `package.json`, `Cargo.toml`), the config lists it under `release.version_files` as `"<path>:<marker>"`. For example, `"bin/slug:SLUG_VERSION="` means the line in `bin/slug` that contains `SLUG_VERSION=`. The version is the first `X.Y.Z` after the marker on that line, so quotes and a tag prefix around it stay as they are: `SLUG_VERSION=0.1.0`, `"version": "0.1.0"` and `"ref": "v0.1.0"` all work. The marker must be on exactly one line, with an `X.Y.Z` after it. The release change request replaces that `X.Y.Z` with the new version. The task that first puts a version in the code adds its entry.
- **The release change request** carries the changelog and version-file updates. Branch `chore/release-<version>` (the exception to section 10's pattern), title `chore(release): <version>`. The tag goes on its merge commit.
- **Order:** release change request merged → release gates pass on its commit → tag (`tag.create`) → release gates pass on the tag → package (`package.build`, `package.verify`) → draft (`release.draft`) → the user confirms → publish (`package.publish`, `release.publish`).
- **Confirmation:** a release is drafted first and published only after the user confirms, and only when every release gate passes. Creating the tag and publishing each need a person's explicit yes.
- **Tags are permanent.** A release found to be wrong after tagging is fixed with a new patch release, never by moving the tag.

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
- Be re-runnable: check for existing state (the plan, then the forge) before creating anything, so running a skill twice does not create duplicates.
- Stop and ask when the forge's state contradicts the plan. Do not pick a side silently.

## 14. Fallbacks

When a forge or tracker lacks a feature, the adapter states the fallback, and the skill uses it and tells the user. Defaults:

| Missing feature | Fallback |
|---|---|
| Issue dependencies | `Depends on: #N` lines in the issue body, plus the `blocked` label |
| Parent / sub-issues | Task-list checklist in the parent issue |
| Milestones | `milestone:<name>` label |
| Required reviews or checks not available on the plan tier | Record the gap in a decision record; work-issue enforces the rule by procedure |
| Draft releases | Prepare notes in a CR against `CHANGELOG.md`; publish after merge |
