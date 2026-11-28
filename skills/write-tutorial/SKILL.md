---
name: write-tutorial
description: Write or update a project's tutorial (docs/tutorial.md) - a small worked example from installing it through its main uses, where every command and output comes from a real run, never from memory - and propose it as a change request, following the idea-to-release conventions. Use before a release when the project should ship a tutorial, or after features change. Optional; re-runnable, and a run with nothing changed reports no changes.
---

# write-tutorial

Writes `docs/tutorial.md`: one small example that takes a new user from installing the project through its main uses, showing for each step what they type and what comes back. A tutorial is optional. When a project has one, cut-release ships it with the release (decision 0020).

The rule that shapes everything here: **every command and output in the tutorial comes from a real run.** Shell steps are run in a clean copy of the default branch. Steps that aren't shell commands (prompts to an agent, say) are quoted from a recorded run. Nothing is written from memory, so the tutorial never shows a command that doesn't work or an output the project doesn't print.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit.

Before doing anything, read `conventions.md`, especially §3 (layout), §5 (plan), §10 (change requests) and §13 (safety).

**Verbs used:** `cr.open`, `cr.update`, `cr.status` (forge); `package.build`, `install.describe` (target). Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `issue` | none | Issue number for the branch, commit footer and closing reference |
| `run` | none | A recorded run to quote steps from that can't be run from a shell: a folder or file of prompts and replies, such as saved agent sessions |

## Procedure

### 1. Read the project

- Read `.project/config.yml`, the adapters it names, the plan (its goal, scope and done tasks), the README, and `docs/tutorial.md` if it exists. If a verb above is `not yet implemented`, stop and say which one.
- Make sure the working tree is clean and the default branch is up to date (`git switch <default>`, `git pull --ff-only`). Never stash or discard someone's changes. With a forge that declares `Remote: none` (the `local` forge), skip the pull.
- **The mode:**
  - **Write:** there's no tutorial yet.
  - **Update:** there is one. Keep its example and its steps where they still hold, and change only what the project's changes call for.

### 2. Outline the tutorial

Pick **one small example** that a new user would recognise, from the plan's goal. Then list the steps, in the order a user meets them:

1. **Before you start:** what's needed, from the README and the target adapter.
2. **Install:** the target's `install.describe` for the current version.
3. **The main uses:** one step per feature a user would reach for first, taken from the done tasks in the plan and from the README. Not every option. A tutorial teaches the common path, and the README and `--help` cover the rest.
4. **When something goes wrong:** the errors a user is likely to hit (a wrong option, a missing input), with what the project prints and what to do.

Mark each step's **kind**:

- **Shell:** commands this skill can run in a clean copy, in a temporary folder.
- **Recorded:** anything else, such as prompts to an agent, a GUI, or a step that needs an account or a network service. These come from the `run` argument.

**Stop and ask** if:

- a step is recorded and no `run` was given. Say which steps need one, and what the run must contain (the prompts, and the full replies).
- a shell step would change anything outside the temporary folder: the user's home directory, global config, a forge, a network service. Make it recorded instead, or leave it out.

**In update mode,** compare the outline with the existing tutorial, and mark each step as kept, changed, added or removed, with the reason (a new feature, a renamed option, a dropped task).

### 3. Dry run and confirmation

Show the outline. Writing the tutorial is write tier (conventions §13), so state it and wait for a yes:

```
Tutorial: docs/tutorial.md (write)   Example: "turn a book title into title case"
Source:   shell steps run on main at 7d06340, in a temporary folder; recorded steps: none
Steps:    Before you start
          Install                      shell  (install.describe, v0.1.0)
          Title-case arguments          shell  titlecase the lord of the rings
          Title-case stdin              shell  echo 'a tale OF two cities' | titlecase
          Keep mixed-case words         shell  titlecase iPhone sales at NASA
          When something goes wrong     shell  titlecase --bogus
Change request: branch docs/12-tutorial → main, "docs: write the tutorial"
```

### 4. Run the steps

- **A clean copy:** `git worktree add` (or `git archive`) of the default branch's head, in a temporary folder. Note the commit.
- **Install** as the tutorial will tell users to:
  - `package.build` on the clean copy, then follow the `install.describe` text into a temporary prefix.
  - Set `HOME` to a temporary folder, so nothing touches the real one.
  - For a project with no target, use the README's install instructions.
- **Each shell step:** run its commands exactly as the tutorial will show them, with the installed project first on `PATH`. Keep each command's output (stdout and stderr) and exit status.
- **Recorded steps:** find each prompt and its reply in the `run`.
  - The run must be of this project, and must use the skills, commands and options as they are now. A reply that names something that has since changed doesn't count.
  - Note the run's date.
- **A step fails** (an unexpected exit status, an error a user wouldn't expect, a recorded reply that doesn't match the project any more): **stop and report.** Show the command and its output. The fix is in the project, or in the step, and never in the tutorial's text.
- **Afterwards:** remove the worktree, the temporary folders and the installed copy, whether the run passed or stopped.

### 5. Write `docs/tutorial.md`

- **Shape:**
  - A title and one paragraph on what the reader will do.
  - Then *Before you start*, the steps in outline order, *When something goes wrong*, and *See also* (the README and other docs).
  - Each step says in a sentence what it's for. Then it shows what the user types, and what comes back.
- **Outputs are quoted, not rewritten.** Only these changes are allowed:
  - **Shortening:** cut long output, and mark each cut with `…`.
  - **Placeholders:** replace temporary paths, user names and account names with neutral ones (`~/.local/bin`, `you/project`), consistently. Say so near the top.
  - Never change an output's content otherwise. If an output reads badly, that's a finding for the project.
- **Recorded replies:** say near the top that an agent's replies vary in wording from run to run.
- **The last line** says where the outputs come from: `Outputs from a run of <commit> (<date>)`, where `<commit>` is the default branch's commit the shell steps ran on, plus `and a recorded run from <date>` if there was one. With no shell steps, it's `Outputs from a recorded run from <date>`. Never name a commit that isn't on the default branch.
- **In update mode,** change only the steps marked as changed, added or removed.
- **If the result is identical** to the existing tutorial, apart from its last line, report "Tutorial matches the project; no changes" and stop.
- **If the README** doesn't link to the tutorial, add one line under its usage or install section.

### 6. Apply

1. Create branch `docs/<issue>-tutorial` (or `docs/tutorial` with no issue) from the default branch.
2. Commit `docs: write the tutorial` (or `docs: update the tutorial`), with a `Refs: #<issue>` footer if there's an issue.
3. Push, then `cr.open`. With the `local` forge, don't push: `cr.open` names the local branch, and the maintainer merges with `merge.sh <n>`.
   - **What changed:** the outline, marked as in step 2.
   - **How it was verified:** the commit the steps ran on, each step's result, and the recorded run used, if any.
   - **Issue:** the closing reference if there's an issue.
4. `cr.status`: `closes` must be exactly that issue, or empty.

**Stop there.** Don't merge. The user merges, and the next cut-release ships the tutorial.

## Re-running

Every run starts from a fresh clean copy, so a re-run checks the whole tutorial against the project as it is now. If nothing changed, it reports "no changes" at step 5 and writes nothing. If a change request from an earlier run is still open on the same branch, push to it and `cr.update` its body instead of opening another.

## Out of scope

- Reference documentation (every option, every error): the README and `--help`
- Shipping the tutorial in a release: **cut-release**
- Fixing a step that fails: a change request through **work-issue**
