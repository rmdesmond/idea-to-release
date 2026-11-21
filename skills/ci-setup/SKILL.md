---
name: ci-setup
description: Generate the project's CI pipeline from the pipeline block of .project/config.yml - the four core stages (lint, build, unit, integration), placeholders for disabled ones and any extra stages - and open a change request with the files, following the idea-to-release conventions. Use after the plan's verification strategy is settled, or whenever the pipeline config changes. Re-runnable; an unchanged config reports no changes.
---

# ci-setup

Turns the `pipeline` block of `.project/config.yml` into the forge's CI files, and proposes them as a change request. The config is the single definition of each stage. The generated files are never edited by hand.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. When installed, they're in `../idea-to-release/`, next to this skill's folder. In a clone of the idea-to-release repository, they're at its root, `../../` from this skill's folder (conventions §3).

Before doing anything, read `conventions.md`, especially §4 (config), §10 (change requests), §11 (pipeline stages, run commands) and §13 (safety).

**Verbs used:** `pipeline.render`, `pipeline.status`, `cr.open`, `cr.update`, `cr.status` (forge). Look each one up in the forge adapter named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `issue` | none | Issue number for the branch, commit footer and closing reference |
| `non-interactive` | off | Don't ask questions |
| `confirm` | off | Only with `non-interactive`: the caller confirms the dry run in advance. Without it, a non-interactive run stops after the dry run |

## Procedure

### 1. Read the project

- Read `.project/config.yml` and the forge adapter. If a verb above is `not yet implemented`, stop and say which one.
- Make sure the working tree is clean, and the default branch is up to date (`git switch <default>`, `git pull --ff-only`). Never stash or discard someone's changes.

### 2. Check the pipeline block

Every core stage (`lint`, `build`, `unit`, `integration`) must be present. Each one is either enabled with a `run` command, or disabled with a `reason`. Every extra stage needs a `name`, `runs_on`, `mode` and `run` (conventions §11).

If anything is missing, stop and list it. The fix belongs in the config:

- through idea-to-plan, if the plan's verification strategy has to change
- by hand, if only a command or reason is missing

Don't invent a command or a reason.

### 3. Render and compare

Run `pipeline.render` into a temporary location, never straight over the committed files. Then compare with what the default branch has:

- **No CI files yet:** everything is new.
- **Identical:** report "Pipeline matches the config; no changes" and stop.
- **Different:** show the diff, and work out why.
  - **The config changed** since the CI files were last committed: an ordinary update. Compare commit order, not dates: take the last commit that touched each (`git log -1 --format=%H -- <path>`). The config changed later if the CI files' commit is an ancestor of the config's (`git merge-base --is-ancestor`).
  - **The config didn't change:** either someone edited a generated file by hand, or the adapter's renderer has changed. Say which you think it is and show the lines.
    - A hand edit means someone needed something. Ask whether to carry it into the config (or a stage's `run` script) first, or to replace it.
    - Non-interactive runs stop here.

### 4. Try the run commands locally

Run each enabled stage's `run` command from the repository root, as work-issue does. A pipeline that's red on its first run teaches people to ignore it.

- **A required stage fails:** stop and report. The change request would land red. The fix is in the project, or in the command.
- **An advisory stage fails, or its tool isn't installed locally:** note it, and go on.

Commands that depend on the CI environment can't pass locally (a service, a secret). If the user confirms that's the reason, go on, and say so in the change request.

### 5. Dry run and confirmation

Show what will happen. It's write tier (conventions §13), so state it and wait for a yes. A non-interactive run proceeds only with `confirm`.

```
Pipeline: 4 core stages (2 enabled, 2 placeholders), 1 extra stage (advisory)
  lint         run: scripts/check-plan.sh
  build        placeholder: Nothing to compile
  unit         run: tests/run.sh
  integration  placeholder: No external interfaces
  shellcheck   advisory, on change requests: shellcheck scripts/*.sh
Files:     create .github/workflows/pipeline.yml
Local run: lint pass, unit pass, shellcheck pass
Change request: branch chore/12-ci → main, "chore(ci): render the pipeline from the config"
```

### 6. Apply

1. Create branch `chore/<issue>-ci` (or `chore/ci` with no issue) from the default branch.
2. Write the rendered files to the paths the adapter gives.
3. Commit with `chore(ci): render the pipeline from the config`, adding the `Refs: #<issue>` footer if there's an issue.
4. Push, then `cr.open`:
   - **What changed:** the stages and what each runs, and the files.
   - **How it was verified:** the local run results.
   - **Issue:** the closing reference if there's an issue.
5. Wait for the pipeline to start on the change request, then report `pipeline.status`.
   - **Expect** every core stage as its own check, and each placeholder passing with its `skipped:` message.
   - **A stage that's missing or failing on CI but passed locally** usually means a difference in environment (tools, shell, operating system). Report it in the change request with `cr.update`; don't hide it.

**Stop there.** Don't merge. The user merges, and repo-governance makes the core checks required.

## Re-running

An unchanged config renders identical files, so the run reports "no changes" at step 3 and writes nothing. If a change request from an earlier run is still open on the same branch, push the new rendering to it and `cr.update` its body instead of opening another.

## Out of scope

- Changing which stages are enabled, or the verification strategy: **idea-to-plan**
- Making the core checks required for merging: **repo-governance**
- Running the stages before a change request: **work-issue**
