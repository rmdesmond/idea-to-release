# Forge adapter: GitHub

Translates the neutral forge verbs in `conventions.md` §2 into GitHub commands. Skills call verbs by name; they never call `gh` directly.

Every forge verb has a section here. A verb that is not yet available says `Status: not yet implemented`. A skill that needs one stops and tells the user. `scripts/check-adapters.sh` checks that no verb is missing.

## Prerequisites

- `gh` 2.40 or later, signed in: `gh auth status` must succeed.
- Token scopes: `repo` (create repositories, edit settings, open pull requests). `read:org` if the owner is an organisation. `workflow` too, if workflow files are pushed over HTTPS (see `pipeline.render`).
- `git` with a working push remote (SSH or HTTPS).
- **Run the commands with bash.** The snippets below rely on bash's word splitting and quoting. zsh, macOS's default interactive shell, splits words differently, so run them as `bash -c '…'` or from a bash script.

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
- `HTTP 403` with "Upgrade to GitHub Pro or make this repository public to enable this feature" means the feature isn't available on the plan tier. It isn't a permission gap. For branch rules, use the fallback under *Branch rules: one ruleset*.
- `HTTP 404` on a repository the user can see in the browser usually means missing token scopes.
- `HTTP 403` with "Repository has been locked" can come for a few seconds after a visibility change. Wait, read again, and repeat the write only once a read succeeds.

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
- **Inputs:** any of: `merge_method` (`squash` | `merge` | `rebase`), `delete_branch_on_merge`, `description`, `features` (`issues`, `wiki`, `projects`), `visibility` (`private` | `public` | `internal`)
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
- **Visibility:** a separate call, never combined with other settings, and passed only by `repo-governance`:
  ```sh
  gh repo edit {o}/{r} --visibility <private|public|internal> --accept-visibility-change-consequences
  ```
  `internal` exists only for organisations on GitHub Enterprise. Going public publishes the whole history. Going private removes stars and watchers, and turns off features the plan only allows on public repositories, such as branch rules on a free account. Afterwards GitHub may answer `Repository has been locked` for a few seconds (see *Errors*).
- **Notes:** repo-bootstrap never passes `visibility`. It sets visibility only when creating a repository.
- **Fallback:** none needed.

## Access

### access.grant

- **Tier:** admin (it gives a person rights on the repository)
- **Inputs:** a GitHub login, and a role: `read`, `triage`, `write`, `maintain` or `admin` (GitHub's API names for these are `pull`, `triage`, `push`, `maintain` and `admin`)
- **Check existing state:** `access.list`. If the person already has exactly that role, report "no change" and skip. If they have a different role, the grant changes it: say so in the dry run. If an invitation is pending, report it rather than sending another.
- **Command:**
  ```sh
  gh api -X PUT repos/{o}/{r}/collaborators/<login> -f permission=<pull|triage|push|maintain|admin>
  ```
  For an organisation team instead of a person: `gh api -X PUT orgs/{org}/teams/<slug>/repos/{o}/{r} -f permission=<...>`.
- **Output:** HTTP 201 means an invitation was sent, which the person must accept. HTTP 204 means the role changed for an existing collaborator.
- **Notes:**
  - On a repository owned by a user (not an organisation), collaborators can only get `write`-level access, and the API ignores other roles.
  - The repository owner can't be added (HTTP 422 "Repository owner cannot be a collaborator"); they're already `admin`.
  - Sending an invitation notifies a real person, so it always needs confirmation, even in a non-interactive run.
- **Fallback:** none needed.

### access.list

- **Tier:** read
- **Inputs:** none
- **Command:**
  ```sh
  gh api repos/{o}/{r}/collaborators --paginate --jq '.[] | {login, role: .role_name}'
  gh api repos/{o}/{r}/invitations --jq '.[] | {login: .invitee.login, role: .permissions, pending: true}'
  ```
- **Output:** one line per person: login, role (`read`, `triage`, `write`, `maintain`, `admin`) and whether the invitation is pending. The owner is included as `admin`. Also report how many people can write, because `repo-governance` uses it (decision 0011).
- **Fallback:** none needed.

### Branch rules: one ruleset

The three `rule.*` verbs share one repository **ruleset** named `idea-to-release`. Rulesets are GitHub's current branch rules, and they replace classic branch protection.

- It targets the default branch (`~DEFAULT_BRANCH`), with `enforcement: active` and **no bypass actors**, so the rules apply to admins too.
- Each verb owns some of the ruleset's `rules` entries:
  - `rule.protect-branch`: `deletion`, `non_fast_forward`, and the presence of `pull_request`
  - `rule.require-review`: the `pull_request` rule's parameters
  - `rule.require-checks`: `required_status_checks`
- Each verb leaves the entries it doesn't own exactly as it found them.

Every verb follows the same steps:

1. **Read** the ruleset, if there is one:
   ```sh
   id=$(gh api repos/{o}/{r}/rulesets --jq '.[] | select(.name == "idea-to-release") | .id')
   gh api repos/{o}/{r}/rulesets/$id > current.json          # only if $id is set
   ```
   Other rulesets on the repository are left alone. Mention them in the dry run, because they also apply.
2. **Build** the wanted ruleset: start from `current.json`, or from this skeleton if there's none. For each entry the verb owns:
   - **Missing:** add it.
   - **Present:** merge the verb's parameters over the current ones (`$current.parameters + $verb.parameters`). Don't replace the entry: GitHub stores extra parameters with defaults (for example `allowed_merge_methods` and `required_reviewers` on `pull_request`). Replacing the entry would drop them, and then every run would look like a change.

   The skeleton:
   ```json
   {
     "name": "idea-to-release",
     "target": "branch",
     "enforcement": "active",
     "bypass_actors": [],
     "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
     "rules": []
   }
   ```
3. **Compare** the wanted `enforcement`, `bypass_actors`, `conditions` and `rules` with the current ones, after sorting rules by `type`:
   ```sh
   norm='{enforcement, bypass_actors, conditions, rules: (.rules | sort_by(.type))}'
   diff <(jq -S "$norm" current.json) <(jq -S "$norm" wanted.json)
   ```
   If they're equal, report "no change" and stop. Otherwise the diff is the dry run's "before → after".
4. **Write** it, sending only `name`, `target`, `enforcement`, `bypass_actors`, `conditions` and `rules`:
   ```sh
   gh api -X POST repos/{o}/{r}/rulesets --input wanted.json        # no ruleset yet
   gh api -X PUT  repos/{o}/{r}/rulesets/$id --input wanted.json    # update
   ```

All three verbs are **admin tier**: they change who can merge what. Show the rules before and after, and wait for confirmation.

**Fallback: rules the plan can't enforce.** On a private repository owned by a free account, every ruleset and branch-protection endpoint, even a read, returns:

```
HTTP 403: Upgrade to GitHub Pro or make this repository public to enable this feature.
```

Treat exactly that message as "branch rules not available on the plan tier", not as a permission error (see *Errors*). The skill then follows conventions §14:

- record the gap in a decision record, naming each rule it couldn't apply
- enforce the rules by procedure: agents never push to the default branch, `work-issue` opens a change request for every change, the pipeline still runs and reports on every change request, and only the maintainer merges
- don't change the repository's visibility to get the feature; visibility is the user's call

Making the repository public, or upgrading the account, brings the rules back. Re-run the skill then; the verbs apply normally.

### rule.protect-branch

- **Tier:** admin
- **Inputs:** none (the ruleset targets the default branch)
- **Check existing state:** steps 1–3 above.
- **Command:** steps 2 and 4 above, with these entries:
  ```json
  { "type": "deletion" },
  { "type": "non_fast_forward" },
  { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": true, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } }
  ```
  If a `pull_request` entry already exists, keep its parameters: they belong to `rule.require-review`.
- **Output:** what the default branch now refuses: deletion, force pushes, and direct pushes (every change arrives through a change request).
- **Fallback:** see *Fallback: rules the plan can't enforce*.

### rule.require-review

- **Tier:** admin
- **Inputs:** `required_approvals` (an integer) and `code_owners` (true or false), from the config's `review` block
- **Check existing state:** steps 1–3 above. Before applying, use `access.list` to check that enough people other than the author can approve. If `required_approvals` is 1 or more but only one person can write, warn: no change request could ever merge (decision 0011).
- **Command:** steps 2 and 4 above, setting the `pull_request` entry's parameters (adding the entry if `rule.protect-branch` hasn't run):
  ```json
  { "type": "pull_request", "parameters": { "required_approving_review_count": <required_approvals>, "require_code_owner_review": <code_owners>, "dismiss_stale_reviews_on_push": true, "require_last_push_approval": false, "required_review_thread_resolution": false } }
  ```
- **Output:** the number of approvals required, and whether code owners must approve.
- **Notes:** GitHub never counts an author's own approval. Agents open change requests with the maintainer's login, so the maintainer can't approve them.
- **Fallback:** see *Fallback: rules the plan can't enforce*.

### rule.require-checks

- **Tier:** admin
- **Inputs:** the check names, normally the four core stages `lint`, `build`, `unit` and `integration` (conventions §11). Advisory extra stages are never required, and required extra stages are added by name.
- **Check existing state:** steps 1–3 above. Also check that each named check has actually reported on the default branch or a recent change request (`pipeline.status`). A required check that never runs blocks every merge. If one is missing, stop and suggest running `ci-setup` first.
- **Command:** steps 2 and 4 above, with this entry. `15368` is the GitHub Actions app, so only Actions can satisfy the checks:
  ```json
  { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false, "do_not_enforce_on_create": false, "required_status_checks": [ { "context": "lint", "integration_id": 15368 }, { "context": "build", "integration_id": 15368 }, { "context": "unit", "integration_id": 15368 }, { "context": "integration", "integration_id": 15368 } ] } }
  ```
- **Output:** the checks now required before merging.
- **Notes:**
  - With required checks in place, a change request whose checks never report is `BLOCKED`. `gh pr merge` then suggests `--admin`. Never use it: merging past a gate is a waiver, which is an admin action (conventions §11).
  - GitHub treats a required check that was skipped by an `if:` condition as passing. That's why `lint`, which runs only on change requests, can be required.
  - `strict` is off, so a change request needn't be rebased on the latest default branch before merging. With squash merges and checks on every change request, that's enough.
- **Fallback:** see *Fallback: rules the plan can't enforce*.

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
- **Draft change requests:** GitHub offers drafts on public repositories, and on private ones only on paid plans. On a private repository owned by a free account, `gh pr create --draft` opens an ordinary pull request without warning. Don't rely on draft state to keep a change request from being merged; say so in its title instead.
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

### cr.list

- **Tier:** read
- **Inputs:** base branch (default branch)
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  gh pr list --repo {o}/{r} --state merged --base <base> --limit 1000 \
    --json number,title,mergedAt,mergeCommit,closingIssuesReferences
  ```
- **Output:** for each merged change request:
  - `number`
  - `title`
  - `merged`: the UTC date, from `mergedAt`
  - `merge_commit`: `mergeCommit.oid`, the squash commit on the base branch
  - `closes`: the numbers in `closingIssuesReferences`

  GitHub keeps the closing references after the merge.
- **Notes:**
  - To find the change requests in a range, intersect `merge_commit` with `git rev-list <from>..<to>`. Don't parse `(#N)` out of commit subjects, because a title can contain other numbers.
  - If exactly 1000 come back, say the list may be incomplete.
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
- **Inputs:** a commit SHA, a change request (number or branch), or a tag
- **Check existing state:** not applicable (this is the read).
- **Command:**
  - for a change request: `cr.status`'s `checks` (`gh pr view <n> --json statusCheckRollup`)
  - for a commit:
    ```sh
    gh api repos/{o}/{r}/commits/<sha>/check-runs --jq '.check_runs[] | {name, status, conclusion}'
    ```
  - for a tag, which runs the release stages: a tag push and the earlier push to the default branch run on the same commit, so read the tag's own workflow run, not the commit's check runs:
    ```sh
    gh run list --repo {o}/{r} --commit <sha> --event push --json databaseId,headBranch,status,conclusion \
      --jq '.[] | select(.headBranch == "<tag>")'
    gh run view <id> --repo {o}/{r} --json jobs --jq '.jobs[] | {name, status, conclusion}'
    ```
    No run for the tag yet is `pending` for a minute after the push, then `missing`.
- **Output:** one line per stage of the config, core and extra, in config order:
  - **Result:** `pass`, `fail`, `pending`, `skipped` or `missing`. Map `status` and `conclusion` as for `cr.status` check runs. A stage with no check run is `missing`: the workflow may not have been pushed yet, or hasn't started.
  - **Placeholder:** for a disabled stage, a `pass` is reported as `pass (placeholder)`.
  - **Advisory:** for an advisory stage, a `fail` is reported as `fail (advisory)`. GitHub still marks the job failed, but it doesn't fail the workflow and never blocks a merge.
  - Finally, an overall result: `pass` if every required stage passed or was skipped, `fail` if any required stage failed, otherwise `pending`.
- **Notes:** check runs appear a few seconds after a push. Read again before reporting `missing`.
- **Fallback:** none needed.

## Release

**Order.** Create the tag first, then the draft, then publish:

1. `tag.create` pushes the tag, which runs the pipeline's release stages (conventions §11).
2. `release.draft` uses `--verify-tag`, so a draft can only be attached to a tag that exists.
3. `release.publish` runs only when the release gates on the tag have passed.

If no tag exists, GitHub accepts a draft anyway, and publishing creates a *lightweight* tag at the target. Never rely on that: the release gates wouldn't have run on it.

Every draft's URL is `…/releases/tag/untagged-<id>` until it's published, even when its tag exists, so don't read the URL as a sign that the tag is missing. Check the tag with `git ls-remote`.

### tag.create

- **Tier:** admin
- **Inputs:** tag name (`<tag_prefix><version>`, e.g. `v0.1.0`), the commit (normally the default branch head, read with `git rev-parse origin/<default>` after `git fetch`), and a message (the release title)
- **Check existing state:**
  ```sh
  git fetch --tags origin
  git ls-remote origin "refs/tags/<tag>^{}"   # the commit an annotated tag points to
  ```
  Nothing: create the tag. The same commit: "no change". **A different commit: stop and report.** A release tag is never moved or deleted (conventions §13), and GitHub rejects a push to an existing tag anyway ("already exists").
- **Command:** an annotated tag, pushed on its own:
  ```sh
  git tag -a <tag> <sha> -m "<message>"
  git push origin "refs/tags/<tag>"
  ```
  Never `git push --tags`, which pushes every local tag, and never `-f`.
- **Output:** the tag and the commit it points to.
- **Notes:** pushing the tag triggers the release stages. Read them with `pipeline.status` on `<sha>`, waiting until none are pending.
- **Fallback:** none needed.

### release.draft

- **Tier:** write. Only people with write access can see a draft.
- **Inputs:** tag, title, notes (written to a file), and asset files (may be none)
- **Check existing state:**
  ```sh
  gh release view <tag> --repo {o}/{r} --json tagName,isDraft,name,body,assets,url
  ```
  - **"release not found":** create the draft.
  - **A draft exists:** update it, changing only what differs: title, notes (compared after trimming trailing whitespace), and assets (by name and size).
  - **A published release exists:** stop and report. Don't change it. GitHub *does* allow editing a published release's notes and assets, but a release is a record, so a correction is a new patch release.
- **Command:**
  ```sh
  # create
  gh release create <tag> --repo {o}/{r} --draft --verify-tag \
    --title "<title>" --notes-file <notes> [<asset> ...]
  # update a draft
  gh release edit <tag> --repo {o}/{r} --title "<title>" --notes-file <notes>
  gh release upload <tag> --repo {o}/{r} <asset> ... --clobber
  ```
  `--verify-tag` fails with "tag <tag> doesn't exist in the repo … aborting" if `tag.create` hasn't run. Report that as a missing step, not a forge error.
- **Output:** the URL, `isDraft: true`, and the asset names and sizes.
- **Fallback:** none needed.

### release.publish

- **Tier:** admin
- **Inputs:** tag
- **Check existing state:**
  ```sh
  gh release view <tag> --repo {o}/{r} --json isDraft,publishedAt,url,assets
  git ls-remote origin "refs/tags/<tag>^{}"
  ```
  - **Already published:** "no change".
  - **Not found:** a failure, so run `release.draft` first.
  - **The tag is missing, or points somewhere other than the drafted commit:** stop and report.
- **Command:**
  ```sh
  gh release edit <tag> --repo {o}/{r} --draft=false
  ```
  The release becomes "latest" if its version is the highest. To check:
  ```sh
  gh api repos/{o}/{r}/releases/latest --jq .tag_name
  ```
- **Output:** the URL, `publishedAt`, and the asset names.
- **Notes:** publishing doesn't move or recreate an existing tag. The tag `tag.create` pushed stays as it is (checked on a scratch repository). If the repository has *immutable releases* turned on (`isImmutable` in the JSON), the published assets and tag can't change afterwards, which matches the rule above.
- **Fallback:** none needed.

---

## Forge-specific sources

These aren't verbs. Skills ask the adapter for them when they write standard files.

### Licence text

```sh
gh api licenses/<key> --jq .body
```

Keys are SPDX identifiers in lower case: `mit`, `apache-2.0`, `gpl-3.0`, `bsd-3-clause`, `mpl-2.0`, and so on. List them with `gh api licenses --jq '.[].key'`. Replace `[year]` and `[fullname]` in the body with the current year and the copyright holder.

### Release and changelog links

- A release page: `https://github.com/{o}/{r}/releases/tag/<tag>`
- A file at a release, for the notes' tutorial link: `https://github.com/{o}/{r}/blob/<tag>/<path>`
- The changes in a release, for the changelog's link references: `https://github.com/{o}/{r}/compare/<previous-tag>...<tag>`. For the first release, which has no previous tag, use the release page.

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
