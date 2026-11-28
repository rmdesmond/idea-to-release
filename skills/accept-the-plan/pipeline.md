# accept-the-plan: the pipeline

Supporting file for `SKILL.md`, step 3. It turns the `pipeline` block of `.project/config.yml` into the forge's CI files. The config is the single definition of each stage, and the generated files are never edited by hand. Nothing is committed here. The result goes into the one dry run (`SKILL.md`, step 4).

**With the `local` forge,** read *On the local forge* in `SKILL.md` alongside this file: it says what applies there, and what doesn't.

**Verbs:** `pipeline.render`, `pipeline.status` (forge).

## 1. Check the pipeline block

Every core stage (`lint`, `build`, `unit`, `integration`) must be present, and each one is either:

- **enabled,** with a `run` command, or
- **disabled,** with a `reason`. Two kinds:
  - **not needed:** the reason says why (`"Markdown only; nothing to compile"`)
  - **pending:** a task will create its command. The reason is `"not set up yet: T-NNN adds it"`, naming a live task in the plan. That task's *Done when* enables the stage (conventions §11)

Every extra stage needs a `name`, `runs_on`, `mode` and `run` (conventions §11).

If anything is missing, or a pending stage names a task that isn't in the plan or is done, stop and list it. The fix belongs in the plan and config, through idea-to-plan. Don't invent a command or a reason.

## 2. Render and compare

Run `pipeline.render` into a temporary location, never straight over the committed files. Then compare with what the default branch has:

- **No CI files yet:** everything is new.
- **Identical:** the pipeline needs no change.
- **Different:** show the diff, and work out why.
  - **The config changed** since the CI files were last committed: an ordinary update. Compare commit order, not dates: take the last commit that touched each (`git log -1 --format=%H -- <path>`). The config changed later if the CI files' commit is an ancestor of the config's (`git merge-base --is-ancestor`).
  - **The config didn't change:** either the adapter's renderer has changed (a new skill-set version), or someone edited a generated file by hand. Say which you think it is and show the lines.
    - **The renderer changed** (the diff is in lines the renderer writes the same way for every project, such as the header): an ordinary update.
    - **A hand edit** means someone needed something: ask whether to carry it into the config (or a stage's `run` script) first, or to replace it. A `non-interactive` run stops here.

## 3. Try the run commands locally

Run each enabled stage's `run` command from the repository root, as work-issue does. A pipeline that's red on its first run teaches people to ignore it.

- **A required stage fails:** stop and report. Most often the command needs a file a task will create. Then the stage is pending, not enabled: the fix is in the plan and config (idea-to-plan), which mark it `not set up yet: T-NNN adds it`.
- **An advisory stage fails, or its tool isn't installed locally:** note it, and go on.

Commands that depend on the CI environment (a service, a secret) can't pass locally. If the user confirms that's the reason, go on, and say so in the report.

## 4. For the dry run

```
Pipeline: 4 core stages (1 enabled, 1 pending, 2 not needed), 1 extra stage (advisory)
CI:       on-demand: change requests with ci:full, release change requests and tags (conventions §11)
  lint         run: git ls-files -z '*.sh' | xargs -0 -r shellcheck
  build        placeholder: Shell scripts; nothing to compile
  unit         pending: not set up yet: T-002 adds it
  integration  placeholder: No external interfaces
  shellcheck   advisory, on change requests
Files:     create .github/workflows/pipeline.yml
Local run: lint pass
```

## After the commit

Wait for the pipeline to run on the commit (or the change request), then read `pipeline.status`: With `pipeline.ci: on-demand`, the setup commit on the default branch starts no pipeline, so there's nothing to wait for. Check the acceptance change request instead, which carries `ci:full` (`SKILL.md`, step 6):

- **Expect** every core stage as its own check, and each placeholder passing with its `skipped:` message.
- **A stage that's missing or failing on CI but passed locally** usually means a difference in environment (tools, shell, operating system). Stop and report it. The branch rules aren't applied over a red pipeline.
