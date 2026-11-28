# accept-the-plan: the repository setup

Supporting file for `SKILL.md`, step 2. It works out the standard setup every other skill expects: settings, labels, standard files and decision records. Nothing is changed here. Every difference goes into the one dry run (`SKILL.md`, step 4).

**With the `local` forge,** read *On the local forge* in `SKILL.md` alongside this file: it says what applies there, and what doesn't.

**Verbs:** `repo.describe`, `access.list` (forge); `label.ensure`'s check (tracker). Also the forge adapter's sources for licence text, `.gitignore` templates, template paths and the owner's display name.

## Inputs

For each one not given as an argument, ask, showing the default. A `non-interactive` run takes every default, and says which.

| Input | Default | Notes |
|---|---|---|
| `licence` | ask; `mit` if non-interactive | An SPDX key (`mit`, `apache-2.0`, ...) or `none` |
| `holder` | the owner's display name (forge adapter) | Copyright holder in the licence |
| `gitignore` | ask, proposing one from the plan's constraints; none if non-interactive | A language template name (`Python`, `Node`, ...) |
| `description` | the repository's description | One line. Never invented: if there's none and nobody gives one, leave it empty |

The config's `merge_method` and `review.required_approvals` are already set (idea-to-plan writes them). The config wins over defaults. An argument that contradicts it is a conflict: stop and ask (conventions §13).

**Review rule.** GitHub never counts an author's own approval, and agents open change requests with the maintainer's login, so with one person who can write, a required approval would block every merge. If the config says 1 or more, `access.list` and count the people with `write`, `maintain` or `admin`. With only one, say so in the dry run, and propose 0: the core checks gate merges, and the maintainer's merge is the review. It becomes 1 when a second maintainer joins, through a plan change.

## Repository settings

Compare with `repo.describe`:

- **Merge methods:** exactly the config's `merge_method`.
- **Delete branch on merge:** on.
- **Issues:** on, because the tracker needs them.
- **Wiki and projects:**
  - **In a repository idea-to-plan just created** (it holds only the plan's commit): off. The plan and the decisions live as files in the repository, and a wiki or a board would be a second place for planning to drift. The forge may turn them on when it creates a repository, so set them explicitly.
  - **In an older repository:** leave them as they are. If either is on, say so in the dry run, because the owner may be using it. Turn it off only if the user asks.
- **Description:** only if one was given and it differs.

## Labels

The set from conventions §8, checked with `label.ensure`:

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

With `pipeline.ci: on-demand` in the config (conventions §11), add one more. With `always`, it isn't created, and an existing one is left alone:

| Name | Colour | Description |
|---|---|---|
| `ci:full` | `5319e7` | Run the full pipeline on this change request |

A label that exists with a different colour or description is listed separately, and each needs its own yes before it's changed.

## Files

Each is written only if missing. An existing file is never overwritten. If it differs from what this skill would write, report that and leave it.

| File | Content |
|---|---|
| `CHANGELOG.md` | Keep a Changelog header and an empty `## [Unreleased]` section |
| `LICENSE` | Licence text from the forge adapter, with the year and holder filled in. Skipped if `licence=none` |
| `.gitignore` | The language template (if any), plus the OS and editor block from the forge adapter |
| `README.md` | `# <repo>`, the description, and a "Status: early development" line |
| Change request template | At the adapter's path: sections *What changed*, *How it was verified*, *Issue* (`Closes #`) |
| Issue template | At the adapter's path, one template named "Task", with the title pre-filled as `T-___: `: *Context*, *Done when* checklist, *Depends on*, footer `Plan-Task: T-___` |

`.project/config.yml` and `docs/plan/PLAN.md` already exist: idea-to-plan wrote them.

## Decision records

Four records (conventions §7), each with a fixed filename slug so that a re-run can find it:

| Subject | Filename |
|---|---|
| Licence | `NNNN-licence-<key>.md` (e.g. `-licence-mit`, `-licence-none`) |
| Visibility | `NNNN-visibility-<value>.md` |
| Merge method and release strategy | `NNNN-merge-strategy.md` |
| Review rule | `NNNN-review-rule.md`: how many approvals, why (who can write), and what changes when a second maintainer joins |

Write only what this run knows. In particular, don't say what the owner's plan allows on a private repository (branch rules, draft change requests). That depends on the account, and the branch rules step checks it and records any gap.

Before writing a record, look for `docs/decisions/*-licence-*.md` (or `*-visibility-*.md`, `*-merge-strategy.md`, `*-review-rule*.md`) with `Status: accepted`. If one exists, skip that record. If it records a different choice from the current inputs, that's a conflict: stop and ask (conventions §13). Number new records from the next free four-digit number, after idea-to-plan's.
