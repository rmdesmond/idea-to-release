---
name: accept-the-plan
description: Accept a project's plan and ready its repository for work, following the idea-to-release conventions - the standard setup (settings, labels, licence, changelog, templates, decision records), the CI pipeline with a passing placeholder for every stage a task will set up, the milestones and dependency-linked issues, and branch rules that require the core checks - in one dry run and one confirmation, ending in a change request that marks the plan accepted. Use after idea-to-plan has saved a plan in a repository, and again after every plan revision or change to the pipeline, the rules, visibility or access. Re-runnable; a run with nothing changed reports no changes.
---

# accept-the-plan

The second of three gates (decision 0021). idea-to-plan saved a plan in a repository, as a draft. Running this skill is the user accepting that plan, and it readies the repository so that no task is worked before the checks and the rules exist:

- the standard setup: settings, labels, standard files and decision records (`setup.md`)
- the pipeline: every core stage, each enabled, or a passing placeholder (`pipeline.md`)
- the milestones and issues, one issue per task (`issues.md`)
- the branch rules, visibility and access (`rules.md`)
- the plan's `Status: accepted <date>`, through a change request: the first one the branch rules apply to

Then the plan is worked with **work-the-plan**, which works only an accepted plan (decision 0022).

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit. `setup.md`, `pipeline.md`, `issues.md` and `rules.md` are in this skill's own folder.

Before doing anything, read `conventions.md`, especially §4 (config), §5 (plan), §6 (traceability), §8 (labels), §9 (issues), §10 (change requests), §11 (pipeline stages), §13 (safety) and §14 (fallbacks).

**Verbs used:** `repo.describe`, `repo.configure`, `access.list`, `access.grant`, `rule.protect-branch`, `rule.require-review`, `rule.require-checks`, `pipeline.render`, `pipeline.status`, `cr.open`, `cr.update`, `cr.status` (forge); `label.ensure`, `milestone.ensure`, `issue.list`, `issue.create`, `issue.update`, `issue.link`, `issue.close` (tracker). Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `licence`, `holder`, `gitignore`, `description` | see `setup.md` | The standard setup's inputs |
| `visibility` | the config's `visibility` | `private` \| `public` \| `internal`. A value different from the config is a request to change it (`rules.md`) |
| `grant` | none | `<login>:<role>`, repeatable. Role: `read`, `triage`, `write`, `maintain` or `admin` |
| `issue` | none | Issue number for the acceptance change request's branch, commit footer and closing reference |
| `non-interactive` | off | Don't ask questions; use arguments, then defaults. Stop at any conflict |
| `confirm` | off | Only with `non-interactive`: the caller confirms the dry run in advance. Without it, a non-interactive run stops after the dry run. It never covers a visibility change or an invitation |

## Procedure

### 1. Read and check

- `.project/config.yml`, and the adapters it names. If a verb above is `not yet implemented`, stop and say which one. **No config:** stop. The plan isn't saved in a repository yet, so run idea-to-plan first.
- `repo.describe`. If the repository doesn't exist on the forge, stop, and say to run idea-to-plan.
- Make sure the working tree is clean, and the default branch is up to date (`git switch <default>`, `git pull --ff-only`). Never stash or discard someone's changes.
- `docs/plan/PLAN.md` must pass `scripts/check-plan.sh`. A plan that fails can't be accepted: list the problems, and say to fix them with idea-to-plan.
- **Show the plan being accepted:** its status, its milestones with task counts and releases, the release target, the verification strategy and the assumptions. Accepting it is the point of this skill, so the user sees what they're accepting before anything else.
- **Proposed decision records.** An assumption made without the user has a decision record with `Status: proposed` (idea-to-plan, step 8). Accepting the plan doesn't accept them. For each one, show what it decides and ask, one record at a time: accept it as written, or leave it proposed (to change it, revise the plan with idea-to-plan). Only the user's own answer counts, and a `non-interactive` run, even with `confirm`, leaves them proposed. Each one accepted is set to `Status: accepted` in the acceptance change request (step 6). A task that depends on one still proposed waits for it: work-the-plan won't take it.
- Read the branch rules on the default branch (the read step in `rules.md`). **None yet** means a new repository: the setup can go straight to the default branch (conventions §10). **Some** means every file change goes through the acceptance change request.

### 2. Work out every difference

Change nothing yet. Follow each supporting file in turn:

1. `setup.md`: gather its inputs, then compare the settings, labels, files and decision records with what the repository has.
2. `pipeline.md`: check the config's `pipeline` block, render it and compare, and run the enabled stages' commands locally.
3. `issues.md`: find each task's issue, and work out the milestones, issues, links and closures. Stop at any conflict it lists.
4. `rules.md`: read the forge, and work out the branch rules, visibility and access.
5. **The plan's status:** `Status: accepted <today's UTC date>` if it says `draft`. If it already says `accepted`, and nothing else differs, there's nothing to accept.

### 3. Dry run and confirmation

Show one summary of everything, grouped by tier, in the order it will be applied. It includes the CI mode (`pipeline.ci`, conventions §11), and with `on-demand`, which issues get `ci:full` (`issues.md`):

```
Plan:        rot13 (draft), 1 milestone, 2 tasks, release v0.1.0, target shell-cli; assumptions: none
Repository:  you/rot13 (private), no branch rules yet

Admin (needs your confirmation):
  repo.configure  merge methods: merge, squash, rebase → squash
                  delete branch on merge: off → on; wiki: on → off; projects: on → off
  branch rules    once every required check has reported on the acceptance change request:
                    protect: deletion, force push, direct push → blocked
                    reviews: required approvals → 0 (0005-review-rule.md)
                    checks:  required → lint, build, unit, integration
Write:
  label.ensure    create 10 labels; 0 already present; 0 differ
  files           create CHANGELOG.md, LICENSE (MIT), .gitignore, README.md, templates
  decisions       create 0002-licence-mit.md, 0003-visibility-private.md, 0004-merge-strategy.md, 0005-review-rule.md
  pipeline        CI: on-demand (only change requests with ci:full, release change requests and tags)
                  4 core stages (1 enabled, 1 pending, 2 not needed)
                    lint         run: git ls-files -z 'bin/*' '*.sh' | xargs -0 -r shellcheck
                    build        placeholder: Shell scripts; nothing to compile
                    unit         pending: not set up yet: T-002 adds it
                    integration  placeholder: No external interfaces
                  create .github/workflows/pipeline.yml; local run: lint pass
  commit          chore: set up the repository → main (no branch rules yet); then wait for its pipeline
  issues          create M1: Walking skeleton; create T-001 (ready), T-002 (blocked, ci:full); link T-002 blocked-by T-001
  acceptance      Status: draft → accepted 2026-11-22; 0004-word-handling.md: proposed → accepted (your yes)
                  change request docs/accept-plan → main, "docs(plan): accept the plan"
No change:
  issues enabled, description, visibility private, access (you admin)
```

If nothing differs anywhere, say "Plan accepted and repository ready; no changes" and stop.

Then wait for explicit confirmation (conventions §13). A non-interactive run proceeds only with `confirm`. Labels that differ need their own yes each. **A visibility change and each invitation** get their own confirmation too (`rules.md`).

### 4. Set up the repository

In this order, stopping at the first failure and reporting what was done:

1. `repo.configure` with only the settings that differ (not visibility: that's step 7)
2. `label.ensure` with the label set
3. Write the files, the decision records and the rendered pipeline
4. **The first setup, with no branch rules yet:** commit them on the default branch, `chore: set up the repository`, and push. This is the one setup commit conventions §10 allows before any branch rules exist. Then wait for the pipeline on that commit, and check it as `pipeline.md` says under "After the commit".

   **Otherwise** (branch rules exist, or the setup commit is already there from an earlier run): don't commit yet. These files go in the acceptance change request (step 6).

### 5. Create the issues

Apply `issues.md`: milestones, new issues, updates, links and closures, in its order.

### 6. Open the acceptance change request

1. Create branch `docs/<issue>-accept-plan` (or `docs/accept-plan` with no issue) from the default branch.
2. Set the plan's `Status: accepted <date>`, and `Status: accepted` on each proposed decision record the user accepted (step 1). In the plan's *Assumptions* section, change that assumption's note from proposed to accepted by the user, with the date, so the plan and the record agree. With branch rules already in place, add the files from step 4 too.
3. Commit `docs(plan): accept the plan`, with a `Refs: #<issue>` footer if there's an issue. Push, then `cr.open`:
   - **What changed:** the plan accepted (milestones, task counts, releases), and the setup, pipeline and issues this run applied, with numbers.
   - **How it was verified:** `check-plan.sh`, the local run of the enabled stages, and the setup commit's pipeline result.
   - **Issue:** the closing reference if there's an issue.
4. `cr.status`: `closes` must be exactly that issue, or empty.
5. Wait for the change request's checks. Every required check must report and pass, `lint` included: in a new repository, this is the first place it runs (conventions §11).

### 7. Apply the branch rules

Once the acceptance change request's checks have passed, apply `rules.md`: visibility (if confirmed on its own), access, then the branch rules. On the fallback path, write the fallback record and push it to the acceptance change request, then `cr.update` its body to say so.

The acceptance change request is now the first change request the branch rules apply to. **Stop there.** Don't merge it. When the user merges it, the plan is accepted.

### 8. Report

List what was created, changed, skipped (and why), and anything that differs but was left alone: settings, labels, files, the pipeline's results, the issues with their numbers, the branch rules (or the fallback record), and the acceptance change request's link. Then what comes next: merge the acceptance change request, then run **work-the-plan**.

## Re-running

Run it again after every plan revision (idea-to-plan sets the plan back to `draft`), and after a change to the pipeline block, the review rule, visibility or access. Every step checks first:

- settings by comparison, labels by `label.ensure`, files by existence, decision records by subject
- the pipeline by rendering and comparing
- issues by their `Plan-Task:` line, and links and labels by comparison
- branch rules by each rule verb's check
- change requests by `cr.open`'s check for an open one on the same branch: if the acceptance change request from an earlier run is still open, push to it and `cr.update` its body instead of opening another

A run with nothing changed reports "Plan accepted and repository ready; no changes".

## Out of scope

- Writing or changing the plan, the pipeline block or the target: **idea-to-plan**
- Working tasks: **work-the-plan**, or **work-issue** for a single issue
- Removing people's access, deleting rulesets other than `idea-to-release`, or merging: **the user**
