---
name: repo-bootstrap
description: Create a repository, or adopt an existing one, and give it the idea-to-release standard setup - repo settings, standard labels, project config, licence, changelog, .gitignore, templates and decision records. Use when starting a new project, or bringing an existing repository under the idea-to-release conventions. Re-runnable; a second run reports what is already in place.
---

# repo-bootstrap

Takes a project from "no repository" or "a bare repository" to the standard starting point every other idea-to-release skill expects.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. When installed, they're in `../idea-to-release/`, next to this skill's folder. In a clone of the idea-to-release repository, they're at its root, `../../` from this skill's folder (conventions §3).

Before doing anything, read `conventions.md`. Every rule there applies, especially §13 (safety). This skill uses only neutral verbs. Look up each verb in the adapters named by the project config, or, without a config, in the adapter inferred in step 1.

**Verbs used:** `repo.describe`, `repo.create`, `repo.configure`, `access.list`, `cr.open` (forge); `label.ensure` (tracker). Also the forge adapter's sources for licence text, `.gitignore` templates and template paths.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `owner`, `repo` | from config or git remote | Required in create mode if neither exists |
| `visibility` | `private` | `private` \| `public` \| `internal`. Used only when creating; changing it later is repo-governance's job |
| `description` | existing description; else ask; empty if non-interactive | One line. Never invented: if nobody gave one, leave it empty |
| `licence` | ask; `mit` if non-interactive | An SPDX key (`mit`, `apache-2.0`, ...) or `none` |
| `holder` | owner's display name, from the forge adapter's "Owner display name" source | Copyright holder in the licence |
| `merge_method` | `squash` | `squash` \| `merge` \| `rebase` |
| `required_approvals` | 0 if the owner is the only person who can write, else 1 | Reviews needed before a change request can merge. Ask if interactive, showing the default and why (step 3) |
| `target` | the plan's `Target:` line, if there's a plan; else none | A target adapter name (conventions §5, decision 0013). With none, the config has no `target` line, and idea-to-plan adds it later |
| `gitignore` | ask; none if non-interactive | A language template name (`Python`, `Node`, ...) |
| `issue` | none | Issue number for the adopt-mode branch and change request |
| `non-interactive` | off | Don't ask questions; use arguments, then defaults |
| `confirm` | off | Only with `non-interactive`: the caller confirms the dry run in advance. Without it, a non-interactive run stops after the dry run |

**Interactive** (the default): for each argument not given, ask, showing the default. **Non-interactive:** take every default without asking, and say which defaults were used.

## Procedure

### 1. Find the forge and the repository

1. If `.project/config.yml` exists, read `forge`, `tracker`, `owner` and `repo` from it.
2. Otherwise infer the forge from `git remote get-url origin` (`github.com` → `github`), and tell the user what was inferred. With no remote, use the `owner` and `repo` arguments, asking for them if interactive. The forge defaults to `github`.
3. Read `adapters/forge/<forge>.md` and `adapters/tracker/<tracker>.md`. If a verb this skill uses is marked `not yet implemented`, stop and say which one.

### 2. Detect the mode

Run `repo.describe`.

- **create:** the repository does not exist.
- **adopt:** it exists. If it is non-empty, check out its default branch locally and pull it.

Also check whether the working directory is a git repository with that remote. In create mode, `git init -b main` if needed.

### 3. Gather inputs

Collect the arguments above. Also ask, unless non-interactive, which core pipeline stages (conventions §11) apply. Every disabled stage needs a `reason`. Every stage the user enables needs a `run` command (conventions §11). Ask for it, proposing one from the `gitignore` language if there is one (for example `Node` → `npm test`). If the user has none yet, leave the stage disabled with a reason, so work-issue never meets an enabled stage it can't run. Non-interactive default: all four disabled with `reason: "Not configured yet; set by idea-to-plan or ci-setup"`, and no `run` commands, so placeholders run until someone decides.

**Review rule.** GitHub never counts an author's own approval, and agents open change requests with the maintainer's login. So with one person who can write, requiring an approval would block every merge. Work out the default from who can write:

- **Create mode:** only the owner can write, so the default is 0.
- **Adopt mode:** `access.list`, counting people with `write`, `maintain` or `admin`. The default is 0 for one such person, and 1 for two or more.

When asking, explain the choice: with 0, the core checks gate merges and the maintainer's merge is the review. It becomes 1 when a second maintainer joins, through a plan change and a repo-governance run.

If `.project/config.yml` already exists, its values win over defaults. An argument that contradicts the config is a conflict: stop and ask (conventions §13).

### 4. Work out the difference

Compare what is wanted with what is there. Nothing is changed in this step.

**Repository settings** (via `repo.describe`):
- merge methods: exactly `merge_method`
- delete branch on merge: on
- features (the optional repo tabs: issues, wiki, projects):
  - issues: on in both modes, because the tracker needs it
  - wiki and projects, **create mode:** off. The plan and decisions live as files in the repository, and a wiki or board would be a second place for planning to drift. The forge may turn them on by default when it creates a repo, so set them explicitly.
  - wiki and projects, **adopt mode:** leave them as they are. If either is on, say so in the dry run, because the owner may be using it. Turn it off only if the user asks.
- description: only if one was given and it differs

**Labels** (via `label.ensure`'s check), the set from conventions §8:

| Name | Colour | Description |
|---|---|---|
| `type:feature` | `1d76db` | New capability |
| `type:bug` | `d73a4a` | Something isn't working |
| `type:chore` | `c5def5` | Maintenance, tooling, housekeeping |
| `type:docs` | `0075ca` | Documentation only |
| `priority:high` | `b60205` | Do first |
| `priority:normal` | `fbca04` | Default priority |
| `priority:low` | `c2e0c6` | When there is time |
| `ready` | `0e8a16` | Fully specified and unblocked |
| `blocked` | `000000` | Waiting on another issue |
| `needs-decision` | `d876e3` | Needs a decision before work can start |

**Files.** Each is written only if missing. An existing file is never overwritten; if it differs from what this skill would write, report that and leave it.

| File | Content |
|---|---|
| `.project/config.yml` | Conventions §4 shape, filled from the inputs. `target: <name>` if known (else left out), `release: {versioning: semver, strategy: trunk, tag_prefix: v, version_files: []}`, `review: {required_approvals: <from inputs>, code_owners: false}`, `extra_stages: []` |
| `CHANGELOG.md` | Keep a Changelog header and an empty `## [Unreleased]` section |
| `LICENSE` | Licence text from the forge adapter, with year and holder filled in. Skipped if `licence=none` |
| `.gitignore` | Language template (if any) plus the OS and editor block from the forge adapter |
| `README.md` | Only if missing: `# <repo>`, the description, and a "Status: early development" line |
| `docs/plan/PLAN.md` | Only if missing: a heading, an empty `## Verification strategy` section, and a note that idea-to-plan fills it |
| Change request template | At the adapter's path: sections *What changed*, *How it was verified*, *Issue* (`Closes #`) |
| Issue template | At the adapter's path, one template named "Task", with the title pre-filled as `T-___: `: *Context*, *Done when* checklist, *Depends on*, footer `Plan-Task: T-___` |

**Decision records** (conventions §7). Four records, each with a fixed filename slug so a re-run can find it:

| Subject | Filename |
|---|---|
| Licence | `NNNN-licence-<key>.md` (e.g. `-licence-mit`, `-licence-none`) |
| Visibility | `NNNN-visibility-<value>.md` |
| Merge method and release strategy | `NNNN-merge-strategy.md` |
| Review rule | `NNNN-review-rule.md`: how many approvals, why (who can write), and what changes when a second maintainer joins |

Before writing a record, look for `docs/decisions/*-licence-*.md` (or `*-visibility-*.md`, `*-merge-strategy.md`, `*-review-rule*.md`) with `Status: accepted`. If one exists, skip that record. If it records a different choice from the current inputs, that's a conflict: stop and ask (conventions §13). Number new records from the next free four-digit number.

### 5. Dry run and confirmation

Show one summary, grouped by tier:

```
Mode: adopt   Repository: owner/repo (private)

Admin (needs your confirmation):
  repo.configure  merge methods: squash, merge, rebase → squash
                  delete branch on merge: off → on
Write:
  label.ensure    create 10 labels; 0 already present; 0 differ
  files           create .project/config.yml, CHANGELOG.md, LICENSE (MIT), ...
                  keep README.md (exists)
  decisions       create 0002-licence-mit.md, 0003-visibility-private.md, 0004-merge-strategy.md, 0005-review-rule.md
  change request  branch chore/1-bootstrap → main
No change:
  description, issues enabled
Left as is (adopt mode):
  projects: on   (say if you want it off)
```

If nothing differs anywhere, say "Already bootstrapped; no changes" and stop.

Then wait for explicit confirmation (conventions §13). Non-interactive runs proceed only with `confirm`. Labels that differ are listed separately, and each one needs its own yes before `gh label edit`-style updates.

### 6. Apply

In this order, stopping at the first failure and reporting what was done:

1. `repo.create` (create mode only)
2. `repo.configure` with only the differing settings
3. `label.ensure` with the label set
4. Write the files and decision records
5. Commit and publish:
   - **create mode:** the repository has no history, so the bootstrap commit goes on the default branch: `chore: bootstrap repository`. This is the only time this skill commits to the default branch directly.
   - **adopt mode:** create branch `chore/<issue>-bootstrap` (or `chore/bootstrap` with no issue) from the default branch. Commit `chore: bootstrap repository` with a `Refs: #<issue>` footer when there is an issue. Push it, then `cr.open` with the same title and a body listing what was added, how it was checked (this skill's dry run), and `Closes #<issue>` if the issue covers only the bootstrap. Don't merge it: merging is the user's call.

### 7. Report

List what was created, changed, skipped (and why), and anything that differs but was left alone. Give the change request link in adopt mode.

## Re-running

The skill is safe to run again. Every step checks first: the repository by `repo.describe`, settings by comparison, labels by `label.ensure`, files by existence, decision records by subject, and change requests by `cr.open`'s check for an open request on the same branch. A second run with nothing changed reports "Already bootstrapped; no changes".

## Out of scope

- Changing visibility after creation, access, branch rules and required reviews: **repo-governance**
- CI files: **ci-setup**
- Filling in the plan: **idea-to-plan**
- Issues and milestones: **plan-to-issues**
