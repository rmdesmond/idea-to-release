# Forge adapter: GitHub

Translates the neutral forge verbs in `conventions.md` §2 into GitHub commands. Skills call verbs by name; they never call `gh` directly.

Every forge verb has a section here. A verb that is not yet available says `Status: not yet implemented`. A skill that needs one stops and tells the user. `scripts/check-adapters.sh` checks that no verb is missing.

## Prerequisites

- `gh` 2.40 or later, signed in: `gh auth status` must succeed.
- Token scopes: `repo` (create repositories, edit settings, open pull requests). `read:org` if the owner is an organisation. `workflow` too, if workflow files are pushed over HTTPS (see `pipeline.render`).
- `git` with a working push remote (SSH or HTTPS).

## Resolving the repository

1. If `.project/config.yml` exists, use `owner` and `repo` from it.
2. Otherwise parse `git remote get-url origin`:
   - `git@github.com:OWNER/REPO.git`
   - `https://github.com/OWNER/REPO(.git)`
3. Otherwise there is no repository yet. Only `repo.create` can run.

Below, `{o}/{r}` means the resolved `OWNER/REPO`. Always pass it explicitly (`--repo {o}/{r}`, or as an argument) rather than relying on `gh`'s directory detection.

## Errors

- A non-zero exit from `gh` is a failure. Report the command and its stderr, then stop. Don't retry writes or admin actions automatically.
- `HTTP 403` with "Resource not accessible" or "Must have admin rights" means the token or the user lacks permission. Report it as a permission gap, not a bug.
- `HTTP 404` on a repository the user can see in the browser usually means missing token scopes.

---

## Repository

### repo.describe

- **Tier:** read
- **Inputs:** `{o}/{r}`
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  gh repo view {o}/{r} --json name,owner,description,visibility,isEmpty,defaultBranchRef,\
  hasIssuesEnabled,hasWikiEnabled,hasProjectsEnabled,\
  squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,deleteBranchOnMerge,licenseInfo
  ```
  `gh repo view` doesn't expose the squash commit message setting, so read it from the REST API as well:
  ```sh
  gh api repos/{o}/{r} --jq '{squash_merge_commit_title, squash_merge_commit_message}'
  ```
- **Output:** neutral fields:

  | Neutral | GitHub JSON |
  |---|---|
  | `exists` | exit code 0 |
  | `empty` | `isEmpty` |
  | `visibility` | `visibility`, lower-cased |
  | `default_branch` | `defaultBranchRef.name` |
  | `description` | `description` |
  | `merge_methods` | the set of `squash`, `merge`, `rebase` whose `*Allowed` is true |
  | `squash_message` | `pr-title-description` when the REST fields are `PR_TITLE` and `PR_BODY`; otherwise `other` |
  | `delete_branch_on_merge` | `deleteBranchOnMerge` |
  | `features.issues` / `.wiki` / `.projects` | `has*Enabled` |
  | `licence` | `licenseInfo.key`, or none |

- **Not found:** exit code 1 with `Could not resolve to a Repository`. Report `exists: false`. Any other error is a failure.
- **Fallback:** none needed.

### repo.create

- **Tier:** admin
- **Inputs:** owner, name, visibility (`private` | `public` | `internal`), description
- **Check existing state:** run `repo.describe`. If the repository exists, do not create it; the skill switches to adopt mode.
- **Command:**
  ```sh
  gh repo create {o}/{r} --private --description "<description>"
  ```
  Use `--public` or `--internal` instead of `--private` to match the visibility. `--internal` only works for organisation owners on GitHub Enterprise.
  Create the repository empty: no `--add-readme`, `--license` or `--gitignore`. The skill writes those files itself, so create and adopt modes produce the same files.
- **Output:** the repository URL. Then set the local remote if there isn't one: `git remote add origin git@github.com:{o}/{r}.git`.
- **Fallback:** none. If creation fails, stop.

### repo.configure

- **Tier:** admin
- **Inputs:** any of: `merge_method` (`squash` | `merge` | `rebase`), `delete_branch_on_merge`, `description`, `features` (`issues`, `wiki`, `projects`)
- **Check existing state:** run `repo.describe` and compare. Pass only the settings that differ. If none differ, report "no changes" and skip the command.
- **Command:** one `gh repo edit` call carrying every differing setting:
  ```sh
  gh repo edit {o}/{r} \
    --enable-squash-merge=true --enable-merge-commit=false --enable-rebase-merge=false \
    --squash-merge-commit-message pr-title-description \
    --delete-branch-on-merge=true \
    --description "<description>" \
    --enable-issues=true --enable-wiki=false --enable-projects=false
  ```
  The example shows every flag. A real call includes only the settings that differ, with one exception below. `merge_method` maps to exactly one of the three `--enable-*-merge` flags set to `true`, with the other two `false`. For `squash`, `--squash-merge-commit-message pr-title-description` makes the PR title the commit subject (conventions §10). It's wanted whenever `squash_message` isn't already `pr-title-description`. A new repository starts with GitHub's default.

  **Exception:** `gh` rejects `--squash-merge-commit-message` unless `--enable-squash-merge=true` is in the same call. Whenever the message setting is passed, pass `--enable-squash-merge=true` too, even if squash merging is already allowed.
- **Output:** settings changed, as `name: old → new`.
- **Notes:** visibility is not changed here. Changing it is `repo-governance`'s job and needs `--accept-visibility-change-consequences`.
- **Fallback:** none needed.

## Access

### access.grant

Status: not yet implemented

### access.list

Status: not yet implemented

### rule.protect-branch

Status: not yet implemented

### rule.require-review

Status: not yet implemented

### rule.require-checks

Status: not yet implemented

## Changes

### cr.open

- **Tier:** write
- **Inputs:** head branch, base branch (default branch), title (Conventional Commit format), body
- **Check existing state:** see whether an open pull request already exists for this head:
  ```sh
  gh pr list --repo {o}/{r} --head <branch> --state open --json number,url,title
  ```
  If one exists, report it and use `cr.update` instead of opening another.
- **Command:** the branch must already be pushed (`git push -u origin <branch>`).
  ```sh
  gh pr create --repo {o}/{r} --base <base> --head <branch> --title "<title>" --body-file <file>
  ```
  Write the body to a temporary file so it isn't mangled by shell quoting.
- **Output:** pull request number and URL.
- **Closing reference:** put `Closes #<issue>` in the body. GitHub treats any of these words, in any case, followed by an issue reference as an instruction to close that issue on merge: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`. A colon between them counts too (`Fixes: #12`). It applies anywhere in the body, so write other mentions without the keyword ("the label on #24 (done)", not "closed #24"). `cr.status`'s `closes` field shows what GitHub actually parsed.
- **Fallback:** none needed.

### cr.update

- **Tier:** write
- **Inputs:** the change request (number, or head branch), and any of: `title`, `body`, `labels_add`, `labels_remove`
- **Check existing state:** find the open pull request, then read what can change:
  ```sh
  gh pr list --repo {o}/{r} --head <branch> --state open --json number   # if given a branch
  gh pr view <n> --repo {o}/{r} --json state,title,body,labels
  ```
  No open pull request for the branch is a failure: use `cr.open` instead. Compare, and pass only what differs. Compare bodies after trimming trailing whitespace. If nothing differs, report "no changes" and skip the command.
- **Command:** one call carrying every difference:
  ```sh
  gh pr edit <n> --repo {o}/{r} --title "<title>" --body-file <file> \
    --add-label "<label>" --remove-label "<label>"
  ```
- **Output:** fields changed, as `name: old → new` (for the body, just "body changed").
- **Notes:** new commits aren't an update. They reach the pull request by pushing the head branch (`git push`). A pull request that is closed or merged isn't updated; report it and stop.
- **Fallback:** none needed.

### cr.status

- **Tier:** read
- **Inputs:** the change request (number, or head branch)
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  gh pr view <n> --repo {o}/{r} --json state,isDraft,mergeable,mergeStateStatus,\
  reviewDecision,latestReviews,statusCheckRollup,closingIssuesReferences,url
  ```
- **Output:** neutral fields:

  | Neutral | GitHub JSON |
  |---|---|
  | `state` | `state`, lower-cased: `open`, `closed` or `merged`; plus `draft` from `isDraft` |
  | `checks` | one entry per item in `statusCheckRollup`, which mixes two kinds (see `__typename`). **CheckRun** (GitHub Actions jobs): `name`; `conclusion` SUCCESS → `pass`; FAILURE, CANCELLED, TIMED_OUT, ACTION_REQUIRED, STARTUP_FAILURE → `fail`; SKIPPED or NEUTRAL → `skipped`; no conclusion yet (`status` not COMPLETED) → `pending`. **StatusContext** (commit statuses): `context`; `state` SUCCESS → `pass`; FAILURE or ERROR → `fail`; PENDING or EXPECTED → `pending`. An empty list → "no checks reported" |
  | `review` | `reviewDecision`: APPROVED → `approved`, CHANGES_REQUESTED → `changes requested`, REVIEW_REQUIRED → `review required`, empty → `no review required` |
  | `reviews` | each of `latestReviews`: author login and state |
  | `mergeable` | `mergeable`: MERGEABLE → `yes`, CONFLICTING → `conflicts`, UNKNOWN → `unknown`; plus `mergeStateStatus` as the reason (e.g. BLOCKED, BEHIND, DIRTY, CLEAN) |
  | `closes` | the issue numbers in `closingIssuesReferences` |

- **Notes:** GitHub computes mergeability in the background, so straight after a push `mergeable` can be `unknown`. Read again after a few seconds before reporting it. `closes` is empty if the body's closing reference is missing or malformed, which is worth flagging: the issue won't close on merge.
- **Fallback:** none needed.

### cr.merge

Status: not yet implemented

Merging is an admin action (conventions §13). In this project the maintainer merges every change request themselves, so no skill needs this verb yet. `release` may need it later.

## Pipeline

### pipeline.render

- **Tier:** write (it writes a file; publishing it is a change request)
- **Inputs:** the project's `.project/config.yml`
- **Check existing state:** compare the rendered output with `.github/workflows/pipeline.yml` as committed. If they're identical, report "no changes". If the committed file differs, show the diff: the file may have been edited by hand.
- **Command:** the renderer that ships with this adapter, run from the project root:
  ```sh
  <skill set>/adapters/forge/github/render-pipeline.sh .project/config.yml > .github/workflows/pipeline.yml
  ```
  It's deterministic (the same config always gives the same bytes), and it fails, writing nothing, if the config can't be rendered: an enabled stage with no `run`, a disabled stage with no `reason`, a missing core stage, or an unknown `runs_on` or `mode`.
- **What it renders:** one workflow, `pipeline`, at `.github/workflows/pipeline.yml`, headed "generated, don't edit by hand".
  - **Triggers:** `pull_request`; `push` to the default branch; `push` of tags matching `<tag_prefix>*`; and `schedule` if any extra stage runs on it (cron from the first such stage's `cron`, else `0 6 * * 1`).
  - **Core stages:** one job each, with job ID and name exactly `lint`, `build`, `unit` and `integration`, on `ubuntu-latest`.
    - When they run (conventions §11): `lint` on change requests; the other three on change requests, merges and release tags. A job outside its triggers is skipped, and GitHub counts a skipped required check as passing.
    - **Enabled:** checks out the repository and runs the stage's `run` with bash.
    - **Disabled:** a placeholder with the reason as a comment, which prints `skipped: <reason>` and succeeds.
  - **Extra stages:** one job each, named after the stage. Its `runs_on` becomes an `if:` condition (`change_request` → pull requests, `merge` → pushes to the default branch, `release` → tag pushes, `schedule` → scheduled runs). `advisory` adds `continue-on-error: true`, so the job's failure doesn't fail the workflow.
  - **Runner:** always `ubuntu-latest`. Projects held to macOS tools still run every stage locally through work-issue.
- **Output:** the path written, and whether it changed.
- **Notes:**
  - Pushing a file under `.github/workflows/` over HTTPS needs the token's `workflow` scope (`gh auth refresh -s workflow`). Pushing over SSH doesn't.
  - `coverage_min` isn't rendered. A stage that enforces it does so in its own `run` command.
- **Fallback:** none needed.

### pipeline.status

- **Tier:** read
- **Inputs:** a commit SHA, or a change request (number or branch)
- **Check existing state:** not applicable (this is the read).
- **Command:**
  - for a change request: `cr.status`'s `checks` (`gh pr view <n> --json statusCheckRollup`)
  - for a commit:
    ```sh
    gh api repos/{o}/{r}/commits/<sha>/check-runs --jq '.check_runs[] | {name, status, conclusion}'
    ```
- **Output:** one line per stage of the config, core and extra, in config order:
  - **Result:** `pass`, `fail`, `pending`, `skipped` or `missing`. Map `status` and `conclusion` as for `cr.status` check runs. A stage with no check run is `missing`: the workflow may not have been pushed yet, or hasn't started.
  - **Placeholder:** for a disabled stage, a `pass` is reported as `pass (placeholder)`.
  - **Advisory:** for an advisory stage, a `fail` is reported as `fail (advisory)`. GitHub still marks the job failed, but it doesn't fail the workflow and never blocks a merge.
  - Finally, an overall result: `pass` if every required stage passed or was skipped, `fail` if any required stage failed, otherwise `pending`.
- **Notes:** check runs appear a few seconds after a push. Read again before reporting `missing`.
- **Fallback:** none needed.

## Release

### tag.create

Status: not yet implemented

### release.draft

Status: not yet implemented

### release.publish

Status: not yet implemented

---

## Forge-specific sources

These aren't verbs. Skills ask the adapter for them when they write standard files.

### Licence text

```sh
gh api licenses/<key> --jq .body
```

Keys are SPDX identifiers in lower case: `mit`, `apache-2.0`, `gpl-3.0`, `bsd-3-clause`, `mpl-2.0`, and so on. List them with `gh api licenses --jq '.[].key'`. Replace `[year]` and `[fullname]` in the body with the current year and the copyright holder.

### Owner display name

```sh
gh api users/{o} --jq '.name // .login'
```

Works for both user and organisation owners. Falls back to the login when no display name is set. Use the repository owner, not the signed-in user (`gh api user`), who may be someone else.

### .gitignore templates

```sh
gh api repos/github/gitignore/contents/<Name>.gitignore --jq .content | base64 --decode
```

`<Name>` is a language such as `Python`, `Node` or `Go`. Always append an OS and editor block (`.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/`, `*.swp`). With no language, use only that block.

### Templates for issues and change requests

| Neutral | Path on GitHub |
|---|---|
| Change request template | `.github/pull_request_template.md` |
| Issue templates | `.github/ISSUE_TEMPLATE/<name>.md`, with YAML front matter `name`, `about`, `labels` |
| Issue template config | `.github/ISSUE_TEMPLATE/config.yml` |
