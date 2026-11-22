---
name: accept-the-plan
description: Accept a project's plan and ready its repository for work, following the idea-to-release conventions - the standard setup (settings, labels, licence, changelog, templates, decision records) and the CI pipeline, with a passing placeholder for every core stage whose command a task will create - in one dry run and one confirmation, then wait for the first pipeline run to pass. Use after idea-to-plan has saved a plan in a repository, and again whenever the plan, the pipeline or the setup changes. Re-runnable; a run with nothing changed reports no changes.
---

# accept-the-plan

The second of three gates (decision 0021). idea-to-plan saved a plan in a repository. Running this skill is the user accepting that plan, and it readies the repository so that no task is worked before the checks exist:

- the standard setup: settings, labels, standard files and decision records (`setup.md` in this folder)
- the pipeline: every core stage, each enabled, or a passing placeholder (`pipeline.md` in this folder)

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit. `setup.md` and `pipeline.md` are in this skill's own folder.

Before doing anything, read `conventions.md`, especially §4 (config), §8 (labels), §10 (change requests), §11 (pipeline stages) and §13 (safety).

**Verbs used:** `repo.describe`, `repo.configure`, `access.list`, `pipeline.render`, `pipeline.status`, `cr.open`, `cr.update`, `cr.status` (forge); `label.ensure` (tracker). The read step of the forge adapter's branch rules tells whether the default branch has any yet. Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `licence`, `holder`, `gitignore`, `description` | see `setup.md` | The standard setup's inputs |
| `issue` | none | Issue number for the branch, commit footer and closing reference, when the setup goes through a change request |
| `non-interactive` | off | Don't ask questions; use arguments, then defaults |
| `confirm` | off | Only with `non-interactive`: the caller confirms the dry run in advance. Without it, a non-interactive run stops after the dry run |

## Procedure

### 1. Read and check

- `.project/config.yml`, and the adapters it names. If a verb above is `not yet implemented`, stop and say which one. **No config:** stop. The plan isn't saved in a repository yet, so run idea-to-plan first.
- `repo.describe`. If the repository doesn't exist on the forge, stop, and say to run idea-to-plan.
- Make sure the working tree is clean, and the default branch is up to date (`git switch <default>`, `git pull --ff-only`). Never stash or discard someone's changes.
- `docs/plan/PLAN.md` must pass `scripts/check-plan.sh`. A plan that fails can't be accepted: list the problems, and say to fix them with idea-to-plan.
- **Show the plan being accepted:** its milestones with task counts, the release target, the verification strategy and the assumptions. Accepting it is the point of this skill, so the user sees what they're accepting before anything else. Assumptions with `Status: proposed` decision records are listed, since accepting the plan doesn't accept them.
- Read the branch rules on the default branch (the forge adapter's read step). **None yet** means a new repository: the setup can go straight to the default branch (conventions §10). **Some** means the setup goes through a change request.

### 2. Work out the setup

Follow `setup.md`: gather its inputs, then compare the settings, labels, files and decision records with what the repository has. Change nothing yet.

### 3. Work out the pipeline

Follow `pipeline.md`: check the config's `pipeline` block, render it and compare, and run the enabled stages' commands locally. Change nothing yet.

### 4. Dry run and confirmation

Show one summary of everything, grouped by tier:

```
Plan:        titlecase, 2 milestones, 7 tasks, target shell-cli; assumptions: none
Repository:  you/titlecase (private), no branch rules yet

Admin (needs your confirmation):
  repo.configure  merge methods: merge, squash, rebase → squash
                  delete branch on merge: off → on; wiki: on → off; projects: on → off
Write:
  label.ensure    create 10 labels; 0 already present; 0 differ
  files           create CHANGELOG.md, LICENSE (MIT), .gitignore, README.md, templates
  decisions       create 0002-licence-mit.md, 0003-visibility-private.md, 0004-merge-strategy.md, 0005-review-rule.md
  pipeline        4 core stages (1 enabled, 1 pending, 2 not needed)
                    lint         run: git ls-files -z '*.sh' | xargs -0 -r shellcheck
                    build        placeholder: Shell scripts; nothing to compile
                    unit         pending: not set up yet: T-002 adds it
                    integration  placeholder: No external interfaces
                  create .github/workflows/pipeline.yml; local run: lint pass
  commit          chore: set up the repository → main (no branch rules yet)
Then:
  wait for the pipeline on main to pass
No change:
  issues enabled, description
```

If nothing differs anywhere, say "Repository ready; no changes" and stop.

Then wait for explicit confirmation (conventions §13). A non-interactive run proceeds only with `confirm`. Labels that differ need their own yes each.

### 5. Apply

In this order, stopping at the first failure and reporting what was done:

1. `repo.configure` with only the settings that differ
2. `label.ensure` with the label set
3. Write the files, the decision records and the rendered pipeline
4. Commit and publish:
   - **No branch rules yet:** commit on the default branch, `chore: set up the repository`, and push. This is the setup commit conventions §10 allows before any branch rules exist.
   - **Branch rules exist:** create branch `chore/<issue>-accept-plan` (or `chore/accept-plan` with no issue) from the default branch, commit `chore: set up the repository` with a `Refs: #<issue>` footer if there's an issue, push, then `cr.open`. The body lists what was added and the local run results, and the closing reference if there's an issue. `cr.status`: `closes` must be exactly that issue, or empty. Don't merge it: the user merges, then runs this skill again.
5. Wait for the pipeline on that commit (or change request), and check it as `pipeline.md` says under "After the commit".

### 6. Report

List what was created, changed, skipped (and why), and anything that differs but was left alone, with the pipeline's result. Leave the plan's `Status:` line alone: the plan is marked accepted only once the branch rules and the issues exist too, so that an accepted plan is always ready to work (decision 0022). Then what comes next: **repo-governance** applies the branch rules, now that the core checks exist, and **plan-to-issues** creates the milestones and issues. No task is worked before both have run.

## Re-running

The skill is safe to run again. Every step checks first: settings by comparison, labels by `label.ensure`, files by existence, decision records by subject, the pipeline by rendering and comparing, and change requests by `cr.open`'s check for an open one on the same branch. Run it again after a plan revision or a pipeline change in the config. A run with nothing changed reports "Repository ready; no changes".

## Out of scope

- Writing or changing the plan, the pipeline block or the target: **idea-to-plan**
- Working tasks: **work-issue**
