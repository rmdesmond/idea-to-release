# Plan: idea-to-release

idea-to-release is a set of agent skills that take a software project from a rough idea to a tagged release, with a person confirming the steps that matter. Each task keeps a permanent ID from the plan through its issue and change request to the release that shipped it, and that history lives in the repository as plain files so it survives a change of forge. It's for developers working with a coding agent (built and tested with Claude Code).

## Scope

In (first release, v0.1.0):
- The seven skills: `idea-to-plan`, `repo-bootstrap`, `plan-to-issues`, `work-issue`, `ci-setup`, `repo-governance`, `cut-release`
- `conventions.md`, and the GitHub forge and tracker adapters with every verb the skills use implemented
- Target adapters, which package and install what a project ships: `agent-skills` (this repository) and `shell-cli` (decision 0013)
- This repository's own checks: `scripts/check-adapters.sh`, `scripts/check-plan.sh` and `tests/run.sh`
- Installation instructions, and an install script that puts the skills where each Agent Skills tool looks for them
- This repository built and released with its own skills, ending in tag `v0.1.0`

Out (first release):
- Adapters for other forges or trackers (GitLab, Jira, Linear). The design allows them; none are built yet
- Testing on agents other than Claude Code (the install script knows their skill folders, but only Claude Code is tested)
- Targets other than `agent-skills` and `shell-cli` (macOS apps, Homebrew, packages, plugins): the design allows them; none are built yet
- Projects spread across several repositories
- Anything outside the agent: no separate CLI, app or hosted service

See decisions 0007 and 0013.

## Constraints

- Skills are Markdown (`SKILL.md` in the Agent Skills format) with no runtime code of their own.
- Scripts use bash and standard tools only (`awk`, `sed`, `grep`), and work with both the BSD (macOS) and GNU (Linux) versions. No Python or Node dependency.
- Requires `git`, and `gh` 2.40 or later signed in with the `repo` scope. `ci-setup` also needs the `workflow` scope.
- This repository is private on a free personal account, where GitHub doesn't enforce branch rules (decision 0003). `repo-governance` is tested on a public scratch repository, and this repository uses the "enforced by procedure" fallback until it goes public.
- There is one maintainer. A required review can't be satisfied by the author, so the review rule is settled in T-018 before governance is applied.
- No deadline.

## Assumptions

None. Every choice above was confirmed during planning.

## Release target

Target: `agent-skills` - an archive of the skills, conventions and adapters, with an `install.sh` that puts them where each agent looks (decisions 0013 and 0014)

## Verification strategy

Test levels:
- Format checks on the conventions' artefacts (adapters, plan, ledger)
- Fixture tests for each check script: valid files must pass, and invalid files must fail with a stated message
- End-to-end runs of the skills on scratch repositories, one at the end of each milestone from M2. These need GitHub credentials and a person to confirm admin steps, so they're plan tasks, not pipeline stages.

| Stage | Enabled | Reason |
|---|---|---|
| lint | yes | `scripts/check-adapters.sh`, `scripts/check-plan.sh`, and the ledger check from T-008 |
| build | no | Markdown and shell scripts; nothing to compile |
| unit | yes | `tests/run.sh`: fixture tests for the check scripts |
| integration | no | End-to-end runs need GitHub credentials and a person to confirm admin steps; they're plan tasks (T-010, T-014, T-021, T-026), not automated |

Extra stages:

| Stage | Runs on | Mode | What it does |
|---|---|---|---|
| shellcheck | change_request | advisory | `shellcheck` on `scripts/`, `tests/` and the adapters' helper scripts |

## M1: Foundations

The conventions, `repo-bootstrap` and `idea-to-plan` exist, and this plan was written with `idea-to-plan`.

### T-001: Draft the shared conventions and README
Depends on: none
Done when:
- [x] `conventions.md` defines the vocabulary, neutral verbs, repository layout, config, plan, ledger, decision records, labels, issues, branches and commits, pipeline stages, releases, safety tiers and fallbacks
- [x] `README.md` describes the skill set, its design principles and the roadmap

### T-002: Add repo-bootstrap and its GitHub adapter verbs
Depends on: T-001
Issue: #1
Done when:
- [x] The forge and tracker adapters have a section for every verb, with `repo.describe`, `repo.create`, `repo.configure`, `cr.open` and `label.ensure` implemented
- [x] `skills/repo-bootstrap/SKILL.md` supports create and adopt modes, a dry run before admin actions, and re-runs that report no changes
- [x] `scripts/check-adapters.sh` checks verb coverage, and fails on a missing, empty or unknown verb section
- [x] Tested on a scratch repository (create mode and a re-run), then run on this repository in adopt mode
- [x] Decision record 0001 explains building the skills by hand before they can run on themselves

### T-003: Update the README licence section
Depends on: T-002
Issue: #4
Done when:
- [x] The README Licence section says MIT and links to `LICENSE` and decision 0002

### T-004: Reorder the roadmap
Depends on: T-001
Issue: #6
Done when:
- [x] The README roadmap puts `idea-to-plan` before `plan-to-issues`, and `repo-governance` after `ci-setup`
- [x] The README stage table matches, and says that labels come from `repo-bootstrap`
- [x] Decision record 0005 gives the reasons

### T-005: Add idea-to-plan and the plan format check
Depends on: T-001
Issue: #8
Done when:
- [x] `skills/idea-to-plan/SKILL.md` supports new and revise modes, never renumbers or reuses IDs, and records assumptions instead of inventing them
- [x] `scripts/check-plan.sh` validates a plan against conventions §5
- [x] `tests/run.sh` runs valid and invalid plan fixtures, and every invalid one fails with its stated message
- [x] Conventions §5 allows `Issue: #N` on a task (decision 0006), and the tracker adapter implements `issue.list`
- [x] Tested on a scratch project: a new plan, then a revision that drops one task and adds another

### T-006: Write the project plan with idea-to-plan
Depends on: T-005
Issue: #10
Done when:
- [ ] `docs/plan/PLAN.md` covers the roadmap to v0.1.0, with completed work linked to its issues
- [ ] `scripts/check-plan.sh` passes on it
- [ ] The pipeline block of `.project/config.yml` matches the verification strategy
- [ ] Decision record 0007 records the first release's scope

## M2: Plan to issues

`plan-to-issues` has turned this plan into GitHub milestones and issues, adopted the existing issues, and filled the ledger.

### T-007: Implement the tracker verbs for plan-to-issues
Depends on: T-002
Done when:
- [ ] `milestone.ensure`, `issue.create`, `issue.update` and `issue.link` (blocks, blocked by, parent) are implemented in the tracker adapter, each with its check of existing state
- [ ] `issue.link` uses GitHub's issue dependencies and sub-issues where available, and documents the fallback from conventions §14 where not
- [ ] Each verb has been run against a scratch repository, including a second run that changes nothing
- [ ] `scripts/check-adapters.sh` passes

### T-008: Add a ledger format check
Depends on: T-005
Done when:
- [ ] `scripts/check-ledger.sh` validates `.project/ledger.yml` against conventions §6: known keys only, task IDs that exist in the plan, issue and change request numbers that are integers, versions in tag format, and ISO dates
- [ ] `tests/run.sh` runs valid and invalid ledger fixtures, and every invalid one fails with its stated message
- [ ] Works on BSD and GNU tools, with no YAML library

### T-009: Add the plan-to-issues skill
Depends on: T-007, T-008
Done when:
- [ ] `skills/plan-to-issues/SKILL.md` creates milestones named `M<n>: <title>` and one issue per live task, following conventions §9 (title, body with *Done when* and `Plan-Task:` footer, type and priority labels)
- [ ] It adopts the issue named by a task's `Issue:` line instead of creating one, and never creates a second issue for a task already in the ledger
- [ ] It records dependencies with `issue.link`, and labels each issue `ready` or `blocked`
- [ ] It writes ledger entries through a `chore(ledger): ...` change request, and the ledger passes `scripts/check-ledger.sh`
- [ ] It shows a dry run before creating anything, and a re-run with no plan changes reports no changes
- [ ] It stops and asks when the forge contradicts the ledger or the plan

### T-010: End-to-end test through plan-to-issues
Depends on: T-009
Done when:
- [ ] On a new scratch repository: `repo-bootstrap` (create mode), `idea-to-plan`, then `plan-to-issues`
- [ ] Every live task has exactly one issue in the right milestone, with the right labels and links, and the ledger matches
- [ ] A second `plan-to-issues` run reports no changes
- [ ] Problems found are fixed in the skills, or filed as issues

### T-011: Run plan-to-issues on this repository
Depends on: T-006, T-010
Done when:
- [ ] Issues #1, #4, #6, #8 and #10 are adopted for T-002 to T-006, and the remaining tasks have new issues
- [ ] T-018 is labelled `needs-decision`
- [ ] The ledger covers every task and passes `scripts/check-ledger.sh`

### T-028: Put task IDs in issue titles
Depends on: T-009
Issue: #41
Done when:
- [x] Conventions §9: issue titles for plan tasks are `T-NNN: <title>`, recorded in a decision record
- [x] plan-to-issues writes new titles with the prefix, and adds a missing prefix to existing issues as a stated change, keeping their wording
- [x] Every plan issue on this repository has its task ID in its title, and a re-run reports no changes

### T-029: Put task titles in the ledger
Depends on: T-008, T-009
Issue: #50
Done when:
- [x] Conventions §6: every ledger entry has a quoted `title` copied from the plan, written and refreshed only by plan-to-issues
- [x] `scripts/check-ledger.sh` requires a quoted title and warns, without failing, when it differs from the plan; fixture tests cover both
- [x] plan-to-issues adds and refreshes titles, and this repository's ledger has a title on every entry

## M3: Issue to change request

`work-issue` takes a `ready` issue to an open change request that includes its tests, and this repository's tasks are worked with it from then on.

### T-012: Implement the change verbs for work-issue
Depends on: T-002
Done when:
- [x] `cr.update` and `cr.status` (checks, reviews, mergeability) are implemented in the forge adapter
- [x] Each has been run against a scratch repository's pull request
- [x] `scripts/check-adapters.sh` passes

### T-013: Add the work-issue skill
Depends on: T-009, T-012
Done when:
- [x] `skills/work-issue/SKILL.md` only picks up `ready` issues, and uses the branch name and commit format from conventions §10
- [x] It doesn't open a change request until the tests named in the task's *Done when* list exist and pass
- [x] It opens the change request with what changed, how it was verified and the closing reference, and never approves or merges its own change request
- [x] It doesn't touch the ledger
- [x] `CLAUDE.md` says to work this repository's tasks with `work-issue`

### T-014: End-to-end test through work-issue
Depends on: T-013
Done when:
- [x] On a new scratch repository: bootstrap, plan, issues, then `work-issue` on one `ready` issue
- [x] The change request has the right branch, title, body, tests and closing reference
- [x] `work-issue` refuses an issue labelled `blocked`
- [x] Problems found are fixed in the skills, or filed as issues

## M4: Pipeline and governance

`ci-setup` has generated this repository's pipeline, the review rule for a single maintainer is settled, and `repo-governance` works, proven on a public scratch repository and applied here with the fallback.

### T-015: Implement the pipeline verbs for GitHub Actions
Depends on: T-002
Done when:
- [x] `pipeline.render` writes workflow files from the config: the four core stages as jobs named exactly `lint`, `build`, `unit` and `integration`, and extra stages with their `runs_on` and `mode`
- [x] A disabled stage is rendered as a placeholder that carries its reason as a comment, prints `skipped: <reason>` and succeeds (conventions §11)
- [x] `pipeline.status` reports each stage's result for a commit or change request
- [x] `scripts/check-adapters.sh` passes

### T-016: Add the ci-setup skill
Depends on: T-015
Done when:
- [x] `skills/ci-setup/SKILL.md` renders the pipeline from `.project/config.yml` and opens a change request with the workflow files
- [x] On a scratch repository, the change request shows all four core checks, and the placeholders pass with their skip message
- [x] A re-run with an unchanged config reports no changes

### T-017: Run ci-setup on this repository
Depends on: T-008, T-016
Done when:
- [x] `lint` runs `scripts/check-adapters.sh`, `scripts/check-plan.sh` and `scripts/check-ledger.sh`, and `unit` runs `tests/run.sh`
- [x] `build` and `integration` are placeholders that give their reasons
- [x] The advisory `shellcheck` stage runs on change requests and doesn't block merges
- [x] A test branch with a broken plan fails `lint`

### T-018: Decide the review rule for a single maintainer
Depends on: none
Done when:
- [x] A decision record states how changes are reviewed while there's one maintainer, and what changes when a second one joins
- [x] `review.required_approvals` in `.project/config.yml` matches the decision

### T-019: Implement the access and rule verbs
Depends on: T-002
Done when:
- [x] `access.grant`, `access.list`, `rule.protect-branch`, `rule.require-review` and `rule.require-checks` are implemented in the forge adapter, using rulesets where available
- [x] The adapter documents the fallback for private repositories on free accounts (conventions §14)
- [x] `scripts/check-adapters.sh` passes

### T-020: Add the repo-governance skill
Depends on: T-016, T-018, T-019
Done when:
- [x] `skills/repo-governance/SKILL.md` protects the default branch, requires the core checks and the configured reviews, and manages visibility and access, with a dry run before every change
- [x] When the forge can't enforce a rule, it writes a decision record for the fallback instead of failing
- [x] A re-run with an unchanged config reports no changes

### T-021: End-to-end test through repo-governance
Depends on: T-020
Done when:
- [x] On a new public scratch repository: bootstrap, plan, issues, `work-issue`, `ci-setup`, then `repo-governance`
- [x] A direct push to the default branch is rejected, and the change request can't merge until its required checks pass
- [x] Problems found are fixed in the skills, or filed as issues

### T-022: Run repo-governance on this repository
Depends on: T-017, T-021
Done when:
- [x] The rules are applied where GitHub allows, and the fallback for this private repository is recorded in a decision record
- [x] The README notes how the default branch is protected while the repository is private

## M5: First release

The `cut-release` skill exists and packages releases through a target adapter, the skills can be installed with the install script, and v0.1.0 of this repository was cut with the skill itself, then the repository went public.

### T-023: Implement the tag and release verbs
Depends on: T-002
Done when:
- [x] `tag.create`, `release.draft` and `release.publish` are implemented in the forge adapter
- [x] Each has been run against a scratch repository
- [x] `scripts/check-adapters.sh` passes

### T-031: Add the target verbs and the agent-skills target
Depends on: T-002
Done when:
- [x] Conventions §2 has a Target group (`package.build`, `package.verify`, `package.publish`, `install.describe`), and §4 a `target:` key naming `adapters/target/<name>.md`
- [x] `adapters/target/agent-skills.md` defines all four verbs, and `scripts/check-adapters.sh` checks target adapters against the Target group only
- [x] `package.build` and `package.verify` have been run on this repository: the archive installs into a temporary project, and the installed skills find the shared files
- [x] A decision record says where the shared files go once installed, and every skill finds them there

### T-024: Add the release skill
Depends on: T-008, T-023, T-031
Done when:
- [x] `skills/release/SKILL.md` derives the version bump from the commits since the last tag (conventions §12). With no earlier tag, the version is `v0.1.0` unless a `version` argument is given, and §12 says so
- [x] It updates `CHANGELOG.md` in the Keep a Changelog layout, from merged change request titles
- [x] It writes release notes listing each task with its issue and change request, from the ledger
- [x] It reconciles the ledger (`change_requests`, `merged`, `released_in`, `released`), filling in entries that have none from the merged change requests that closed their issues, and the result passes `scripts/check-ledger.sh`
- [x] It builds and verifies the package through the target adapter, attaches the artifacts to the draft, puts `install.describe` in the notes, and calls `package.publish` with `release.publish`
- [x] It drafts first, and publishes only after confirmation and only when every release gate passes

### T-025: Write installation instructions
Depends on: T-024
Done when:
- [x] The release archive has an `install.sh` that installs the skills, adapters, conventions and check scripts for a chosen agent (`claude`, `codex`, `copilot`, `gemini` or `generic`), into a project or the user's folder
- [x] The README explains how to install, what each part requires, and its roadmap is current
- [x] Following the instructions from a clean clone, in a new scratch project, gives working skills

### T-032: Ask for the release target when planning
Depends on: T-031
Done when:
- [x] `idea-to-plan` asks what the project ships and records it in a "Release target" plan section, reporting a missing target adapter as a gap to plan for
- [x] `repo-bootstrap` writes `target:` to `.project/config.yml`, and `scripts/check-plan.sh` accepts the new section

### T-033: Add the shell-cli target
Depends on: T-031
Done when:
- [x] `adapters/target/shell-cli.md` defines all four verbs: an archive of the project's commands with an `install.sh` that copies them to a `bin` folder
- [x] `scripts/check-adapters.sh` passes, and the verbs have been run on a scratch project

### T-026: End-to-end test from idea to release
Depends on: T-024, T-025, T-032, T-033
Done when:
- [x] On a new scratch repository with the skills installed from the instructions: every skill in order, through a published release
- [x] The project chose the `shell-cli` target in `idea-to-plan`, its release carries the archive, and installing from the release notes gives a working command
- [x] The release notes list the tasks that shipped, and the ledger is complete
- [x] Problems found are fixed in the skills, or filed as issues

### T-027: Release v0.1.0
Depends on: T-022, T-026
Done when:
- [ ] Every release gate passes on the default branch
- [ ] The `cut-release` skill drafts v0.1.0 with the `agent-skills` archive attached and `package.verify` passing, and it's published after confirmation
- [ ] The README status and roadmap say the first release is out

### T-030: Make the repository public
Depends on: T-027
Done when:
- [ ] `repo-governance visibility=public` is run after its own confirmation, with a decision record superseding 0003
- [ ] The branch rules are applied, a direct push to `main` is rejected, and a record supersedes 0012
- [ ] The README's "How `main` is protected" section describes the enforced rules
