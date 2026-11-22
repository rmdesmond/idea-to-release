# Plan: idea-to-release

idea-to-release is a set of agent skills that take a software project from a rough idea to a tagged release, with a person confirming the steps that matter. Each task keeps a permanent ID from the plan through its issue and change request to the notes of the release that shipped it. It's for developers working with a coding agent (built and tested with Claude Code).

## Scope

In (first release, v0.1.0):
- The seven skills: `idea-to-plan`, `repo-bootstrap`, `plan-to-issues`, `work-issue`, `ci-setup`, `repo-governance`, `cut-release`
- `conventions.md`, and the GitHub forge and tracker adapters with every verb the skills use implemented
- Target adapters, which package and install what a project ships: `agent-skills` (this repository) and `shell-cli` (decision 0013)
- This repository's own checks: `scripts/check-adapters.sh`, `scripts/check-plan.sh` and `tests/run.sh`
- Installation instructions, and an install script that puts the skills where each Agent Skills tool looks for them
- This repository built and released with its own skills, ending in tag `v0.1.0`

In (v0.2.0, M6):
- The skills as a Claude Code plugin, `i2r`, installed from this repository (decision 0019)
- No stored ledger: the trail from task to release is read from the plan, the issues, the change requests and the tags (decision 0018)
- The fix for the stale `blocked` labels found end to end
- An eighth skill, `write-tutorial`: an optional tutorial for a project, from real runs, shipped with its releases (decision 0020)

Out (first release):
- Adapters for other forges or trackers (GitLab, Jira, Linear). The design allows them; none are built yet
- Testing on agents other than Claude Code (the install script knows their skill folders, but only Claude Code is tested)
- Targets other than `agent-skills` and `shell-cli` (macOS apps, Homebrew, packages, plugins): the design allows them; none are built yet
- Projects spread across several repositories
- Anything outside the agent: no separate CLI, app or hosted service

Out (v0.2.0):
- The Agent Plugins package for Cursor, Copilot and Codex: a later release, tracked in its own issue
- Packaging projects other than this one with the `agent-skills` target. It packages this repository only, and won't be generalised

See decisions 0007, 0013, 0018 and 0019.

## Constraints

- Skills are Markdown (`SKILL.md` in the Agent Skills format) with no runtime code of their own.
- Scripts use bash and standard tools only (`awk`, `sed`, `grep`), and work with both the BSD (macOS) and GNU (Linux) versions. No Python or Node dependency.
- Requires `git`, and `gh` 2.40 or later signed in with the `repo` scope. `ci-setup` also needs the `workflow` scope.
- This repository stays private (decision 0016). Since 2026-11-21 its account is on GitHub Pro, which enforces branch rules on private repositories. Before that, `repo-governance` was tested on a public scratch repository, and this repository uses the "enforced by procedure" fallback (decision 0012) until T-030 applies the rules.
- There is one maintainer. A required review can't be satisfied by the author, so the review rule is settled in T-018 before governance is applied.
- No deadline.

## Assumptions

None. Every choice above was confirmed during planning.

## Release target

Target: `agent-skills` - an archive of the skills, conventions and adapters, with an `install.sh` that puts them where each agent looks (decisions 0013 and 0014)

## Verification strategy

Test levels:
- Format checks on the conventions' artefacts (adapters, plan)
- Fixture tests for each check script: valid files must pass, and invalid files must fail with a stated message
- End-to-end runs of the skills on scratch repositories, one at the end of each milestone from M2. These need GitHub credentials and a person to confirm admin steps, so they're plan tasks, not pipeline stages.

| Stage | Enabled | Reason |
|---|---|---|
| lint | yes | `scripts/check-adapters.sh` and `scripts/check-plan.sh` (the ledger check from T-008 was removed in T-034) |
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
- [x] `docs/plan/PLAN.md` covers the roadmap to v0.1.0, with completed work linked to its issues
- [x] `scripts/check-plan.sh` passes on it
- [x] The pipeline block of `.project/config.yml` matches the verification strategy
- [x] Decision record 0007 records the first release's scope

## M2: Plan to issues

`plan-to-issues` has turned this plan into GitHub milestones and issues, adopted the existing issues, and filled the ledger.

### T-007: Implement the tracker verbs for plan-to-issues
Depends on: T-002
Done when:
- [x] `milestone.ensure`, `issue.create`, `issue.update` and `issue.link` (blocks, blocked by, parent) are implemented in the tracker adapter, each with its check of existing state
- [x] `issue.link` uses GitHub's issue dependencies and sub-issues where available, and documents the fallback from conventions §14 where not
- [x] Each verb has been run against a scratch repository, including a second run that changes nothing
- [x] `scripts/check-adapters.sh` passes

### T-008: Add a ledger format check
Depends on: T-005
Done when:
- [x] `scripts/check-ledger.sh` validates `.project/ledger.yml` against conventions §6: known keys only, task IDs that exist in the plan, issue and change request numbers that are integers, versions in tag format, and ISO dates
- [x] `tests/run.sh` runs valid and invalid ledger fixtures, and every invalid one fails with its stated message
- [x] Works on BSD and GNU tools, with no YAML library

### T-009: Add the plan-to-issues skill
Depends on: T-007, T-008
Done when:
- [x] `skills/plan-to-issues/SKILL.md` creates milestones named `M<n>: <title>` and one issue per live task, following conventions §9 (title, body with *Done when* and `Plan-Task:` footer, type and priority labels)
- [x] It adopts the issue named by a task's `Issue:` line instead of creating one, and never creates a second issue for a task already in the ledger
- [x] It records dependencies with `issue.link`, and labels each issue `ready` or `blocked`
- [x] It writes ledger entries through a `chore(ledger): ...` change request, and the ledger passes `scripts/check-ledger.sh`
- [x] It shows a dry run before creating anything, and a re-run with no plan changes reports no changes
- [x] It stops and asks when the forge contradicts the ledger or the plan

### T-010: End-to-end test through plan-to-issues
Depends on: T-009
Done when:
- [x] On a new scratch repository: `repo-bootstrap` (create mode), `idea-to-plan`, then `plan-to-issues`
- [x] Every live task has exactly one issue in the right milestone, with the right labels and links, and the ledger matches
- [x] A second `plan-to-issues` run reports no changes
- [x] Problems found are fixed in the skills, or filed as issues

### T-011: Run plan-to-issues on this repository
Depends on: T-006, T-010
Done when:
- [x] Issues #1, #4, #6, #8 and #10 are adopted for T-002 to T-006, and the remaining tasks have new issues
- [x] T-018 is labelled `needs-decision`
- [x] The ledger covers every task and passes `scripts/check-ledger.sh`

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

The `cut-release` skill exists and packages releases through a target adapter, the skills can be installed with the install script, and v0.1.0 of this repository was cut with the skill itself, then its branch rules were enforced on the private repository.

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
- [x] Every release gate passes on the default branch
- [x] The `cut-release` skill drafts v0.1.0 with the `agent-skills` archive attached and `package.verify` passing, and it's published after confirmation
- [x] The README status and roadmap say the first release is out

### T-030: Enforce the branch rules on the private repository
Depends on: T-027
Done when:
- [x] `repo-governance` is run after its own confirmation and applies the branch rules to `main`, with a decision record superseding 0012
- [x] A direct push and a force push to `main` are rejected, and a change request with a failing core check can't be merged
- [x] The README's "How `main` is protected" section and roadmap describe the enforced rules

## M6: Plugin release

The ledger is gone, the skills install as the Claude Code plugin `i2r`, `work-issue` refreshes stale `blocked` labels, a tutorial shows how to use the skills, a `write-tutorial` skill writes one for any project and releases ship it, two small defects in the plan and the changelog rules are fixed, and v0.2.0 is released with the plugin.

### T-034: Remove the ledger
Depends on: none
Done when:
- [x] No skill, adapter or script reads or writes `.project/ledger.yml`; the file, `scripts/check-ledger.sh` and its tests are deleted, and the lint stage no longer runs the check
- [x] Conventions §6 becomes "Traceability": task → issue by the `Plan-Task:` footer, issue → change requests by `closes`, change request → release by its merge commit in the tag range
- [x] `cut-release` builds "Plan tasks delivered" from the change requests in the release, their issues and the plan, and lists tasks closed as completed with no change request
- [x] A `cut-release` dry run on this repository's history gives the same "Plan tasks delivered" as v0.1.0's notes
- [x] Decision 0018 records the removal, and #97 is closed as resolved

### T-035: Refresh a stale blocked label in work-issue
Depends on: none
Issue: #88
Done when:
- [x] When no issue is `ready`, `work-issue` proposes the first `blocked` issue, in plan order, whose blockers are all closed, and says its label is stale
- [x] On confirmation it moves that issue from `blocked` to `ready` before starting, and reports it
- [x] Conventions §8 says which skills may change state labels

### T-036: Offer the skills as the Claude Code plugin i2r
Depends on: T-034
Issue: #82
Done when:
- [x] The repository root is the plugin `i2r` and its own marketplace (`.claude-plugin/plugin.json` and `marketplace.json`), and `claude plugin validate --strict` passes
- [x] Installed from the marketplace, the seven skills load as `/i2r:<skill>` and find their shared files in the installed copy
- [x] The plugin's version follows releases: `cut-release` bumps it through `release.version_files`
- [x] The `agent-skills` target's `package.publish` and `install.describe`, and the README's Installing section, describe the plugin; `install.sh` stays for other agents
- [x] Decision 0019 records the name and the layout

### T-037: End-to-end test through the plugin
Depends on: T-035, T-036
Done when:
- [x] On a scratch repository, the plugin's skills take a small task through `work-issue` and cut a release with `cut-release`
- [x] The release's archive installs from its notes, and no ledger file is written
- [x] Problems found are fixed in the skills, or filed as issues

### T-038: Release v0.2.0
Depends on: T-037, T-039, T-040, T-041, T-042, T-043
Done when:
- [x] The `cut-release` skill drafts v0.2.0 with the `agent-skills` archive attached and `package.verify` passing, and it's published after confirmation
- [x] The plugin's manifests say 0.2.0, and a fresh `claude plugin install i2r@i2r` gets v0.2.0
- [x] The README roadmap says v0.2.0 is out

### T-039: Write a tutorial for the skills
Depends on: T-037
Done when:
- [x] `docs/tutorial.md` takes a new user through a small example project from idea to its first release: installing the plugin, then `idea-to-plan`, `repo-bootstrap`, `plan-to-issues`, `work-issue`, `ci-setup`, `repo-governance` and `cut-release`, in the order they're used
- [x] For each skill it shows how to start it, what it asks, the dry run it shows and what the user confirms, and what it changes in the repository and on the tracker
- [x] Its commands and outputs come from the end-to-end run in T-037, not from memory, and it says what to do when a step stops (a failing check, a blocked issue, a private repository's branch rules)
- [x] The README links to it from "Installing"

### T-040: Fix the unticked boxes of tasks done before work-issue ticked them
Depends on: none
Done when:
- [x] Every *Done when* box of T-006 to T-011 is ticked, and the change request lists the evidence for each task: its issue closed as completed and the change request that closed it
- [x] No other task's issue is closed as completed while the task has unticked boxes, checked across the whole plan

### T-041: Fix the changelog group for a breaking removal
Depends on: none
Done when:
- [x] Conventions §12 says that a breaking change whose summary starts with "remove" or "drop" goes under **Removed**, marked **Breaking:**, and not under **Changed**
- [x] `cut-release`'s changelog step says the same, and its dry-run example shows such an entry

### T-042: Add the write-tutorial skill
Depends on: T-039
Done when:
- [x] `skills/write-tutorial/SKILL.md` writes or updates `docs/tutorial.md` for the project: a small example that goes from installing it through its main uses, each step with what the user types and what comes back
- [x] Every command and output in the tutorial comes from a real run, never from memory. Shell steps are run in a clean copy of the default branch. Steps that aren't shell commands (an agent's skills, say) are quoted from a recorded run the user points to. If a step fails or no run exists, the skill stops and says so
- [x] It shows the outline before writing, and delivers the tutorial through a change request; it never merges it, and running it again only updates what changed
- [x] Conventions say where the tutorial lives and that it's optional, and the README, the plugin and the archive list eight skills
- [x] This repository's `docs/tutorial.md` is rewritten by the skill from T-039's recorded run
- [x] Decision 0020 records why tutorials come from real runs and are optional

### T-043: Ship the tutorial with releases
Depends on: T-042
Done when:
- [x] When `docs/tutorial.md` exists, the `shell-cli` and `agent-skills` archives include it, and their `package.verify` checks it's there
- [x] `cut-release`'s notes link to the tutorial at the release's tag, and its dry run warns when the tutorial was last changed before change requests in the release. It never requires a tutorial
- [x] On a scratch repository, `write-tutorial` writes a tutorial through a change request, and the next `cut-release` ships it in the archive and links it from the notes
