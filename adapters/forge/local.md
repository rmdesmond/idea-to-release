# Forge adapter: local

Remote: none

The repository is plain git on one machine, with no hosting service and no remote (decision 0027). Change requests and releases are records in the `local` tracker's store, and the maintainer merges with the adapter's `merge.sh`. It pairs with the `local` tracker. Mixing it with a hosted tracker isn't supported.

`Remote: none` means skills skip every push and fetch step, and work from the local default branch wherever they would use `origin/<default>` (conventions §2).

Every forge verb has a section here. A verb that is not yet available says `Status: not yet implemented`. A skill that needs one stops and tells the user. The commands live in `adapters/forge/local/`. `scripts/check-adapters.sh` checks that no verb is missing.

## Prerequisites

- `git` 2.28 or later, with `user.name` and `user.email` set.
- bash 3.2 or later, and the standard tools (`awk`, `sed`, `grep`, BSD or GNU). No `gh` and no network.
- Run the commands from the project's root, or pass `-C <project>` first. Below, `forge.sh` means `<skill set>/adapters/forge/local/forge.sh`.

## Resolving the repository

The repository is the git repository the commands run in: `git rev-parse --show-toplevel`. There's no owner and no remote, so the config's `owner` and `visibility` are optional (conventions §4). The tracker store is found as in [`../tracker/local.md`](../tracker/local.md).

## Settings

What a hosted forge keeps as repository settings, the local forge keeps in the repository's own git config, under `i2r.*`. They're never committed, and they belong to this one clone:

| Setting | Key | Set by |
|---|---|---|
| merge method | `i2r.mergemethod` (only `squash`) | `repo.configure` |
| delete branch on merge | `i2r.deletebranchonmerge` | `repo.configure` |
| required approvals | `i2r.requiredapprovals` (only `0`) | `rule.require-review` |
| required checks | `i2r.requiredchecks` (stage names) | `rule.require-checks` |

The description is git's own `.git/description`.

## Errors

- A non-zero exit is a failure: report the message (`error: ...` on stderr) and stop. Don't retry writes or admin actions automatically.
- A verb that doesn't apply locally (visibility, features, access grants, code owners) says so. `repo.configure` reports and ignores it, and `access.grant` refuses it.

---

## Repository

### repo.describe

- **Tier:** read
- **Inputs:** none (the current repository)
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  forge.sh repo-describe
  ```
- **Output:** `key: value` lines:

  | Neutral | Local |
  |---|---|
  | `exists` | the folder is a git repository. Outside one, only `exists: false` |
  | `empty` | no commit yet |
  | `visibility` | `not applicable (local)` |
  | `default_branch` | the config's `default_branch`, else the current branch |
  | `description` | `.git/description`, unless it's git's placeholder |
  | `merge_methods` | `i2r.mergemethod` |
  | `delete_branch_on_merge` | `i2r.deletebranchonmerge` |
  | `features` | not applicable: issues are in the tracker store |
  | `licence` | `present (<first line>)` if `LICENSE` exists, else `none` |

  It also prints `path`, `tracker_store` (`exists`, `missing` or `not a tracker store`, with its path) and `remotes`, which should be `none`.
- **Fallback:** none needed.

### repo.create

- **Tier:** admin
- **Inputs:** default branch (default `main`), description. Visibility doesn't apply.
- **Check existing state:** if the folder is already a git repository, nothing is created, and the command says to adopt it.
- **Command:**
  ```sh
  forge.sh -C <folder> repo-create --default-branch main --description "<description>"
  ```
  It runs `git init`, points `HEAD` at the default branch, and writes the description. It adds no remote.
- **Output:** the repository's folder.
- **Fallback:** none. If it fails, stop.

### repo.configure

- **Tier:** admin
- **Inputs:** any of: `merge_method` (only `squash`), `delete_branch_on_merge`, `description`. `visibility` and `features` don't apply.
- **Check existing state:** built in. Only what differs is written, and nothing differing prints `no changes`.
- **Command:** one call carrying every setting:
  ```sh
  forge.sh repo-configure --merge-method squash --delete-branch-on-merge true --description "<description>"
  ```
  `--merge-method merge` or `rebase` is refused: `merge.sh` squash-merges (conventions §10). `--visibility` and `--features` are reported as not applicable, and ignored.
- **Output:** settings changed, as `name: old → new`.
- **Fallback:** none needed.

## Access

### access.list

- **Tier:** read
- **Inputs:** none
- **Command:**
  ```sh
  forge.sh access-list
  ```
- **Output:** one line, the git user (`user.name`) as `admin`, and `people who can write: 1`. With one person, required approvals can only be 0 (decision 0011).
- **Fallback:** none needed.

### access.grant

- **Tier:** admin
- **Inputs:** login, role
- **Command:** not applicable. The repository is on one machine, for one person, so there's no one to grant access to:
  ```sh
  forge.sh access-grant <login> <role>    # always refuses, and says why
  ```
- **Fallback:** none. A project with more than one person needs a hosted forge.

### Branch rules: hooks

The local forge has no server to enforce branch rules. It uses the fallback in conventions §14: git hooks in the repository as guard-rails, backed by the procedure of decision 0012. Each `rule.*` verb is admin tier, and has a `--check` form that only reports.

- `rule.protect-branch` installs two hooks in `$(git rev-parse --git-path hooks)`, each marked `# idea-to-release local forge: rule.protect-branch`:
  - **`pre-commit`** refuses a commit on the default branch, with a message that says to commit on a branch and merge it with `merge.sh`.
  - **`reference-transaction`** refuses any change to the default branch: a merge, a reset, a force update (`git branch -f`, `git update-ref`) or a deletion. Moving the branch from a loose file into `packed-refs` (`git pack-refs`, `git gc`) changes nothing, and is let through.
  
  Both let through a change made with `I2R_MERGE=1` in the environment, which only `merge.sh` sets.
- `rule.require-checks` and `rule.require-review` record what `merge.sh` enforces before it merges: the stages that must pass, and no approvals.

**Limits.** These are guard-rails, not enforcement. `git commit --no-verify` skips `pre-commit`, setting `I2R_MERGE=1` by hand skips both hooks, and anyone can delete the hooks. They stop mistakes, such as an agent or a person committing on the default branch by accident, not someone who means to get past them. They live in this one clone, and aren't committed. A refused fast-forward merge can leave the working tree updated although the branch didn't move: `git reset --hard` puts it back, and is allowed, because it doesn't move the branch.

### rule.protect-branch

- **Tier:** admin
- **Inputs:** none (the default branch)
- **Check existing state:**
  ```sh
  forge.sh rule-protect-branch --check
  ```
  For each hook: `present`, `missing → install`, `ours-different → install` (an older version of this adapter's hook), or `a different hook is installed`. A hook this adapter didn't write is never overwritten.
- **Command:**
  ```sh
  forge.sh rule-protect-branch
  ```
- **Output:** each hook's state, and what the default branch now refuses. If a different hook is in the way, it fails and says so: the user merges the two hooks by hand.
- **Fallback:** this is the fallback (conventions §14).

### rule.require-review

- **Tier:** admin
- **Inputs:** `required_approvals` and `code_owners`, from the config's `review` block
- **Check existing state:** `forge.sh rule-require-review <approvals> <code_owners> --check`
- **Command:**
  ```sh
  forge.sh rule-require-review 0 false
  ```
  Anything other than 0 approvals is refused: one person can't approve their own change (decision 0011). Code owners don't apply.
- **Output:** `required approvals: <old> → 0`, or `no change`.
- **Fallback:** none needed.

### rule.require-checks

- **Tier:** admin
- **Inputs:** the check names, normally the four core stages `lint`, `build`, `unit` and `integration`, plus any required extra stage
- **Check existing state:** `forge.sh rule-require-checks <stage>... --check`
- **Command:**
  ```sh
  forge.sh rule-require-checks lint build unit integration
  ```
- **Output:** `required checks: <old> → <new>`, or `no change`. `merge.sh` runs these stages' `run` commands from the config on the merge result, and refuses to merge if a required one fails. A disabled stage is a placeholder, and passes.
- **Fallback:** none needed.

## Changes

Change requests are records in the tracker store, `crs/NNNN.md`, in the same format as issues (see [`../tracker/local.md`](../tracker/local.md)): `Number`, `Title`, `State` (`open`, `closed` or `merged`), `Head`, `Base`, `Created`, `Labels`, `Merged`, `Merge-Commit` and `Closes`, then a blank line and the body. They're numbered from the store's shared counter, so a change request and an issue never share a number. Every write is one commit in the store.

There's no push: a change request names a local branch, and its commits are already there.

### cr.open

- **Tier:** write
- **Inputs:** head branch, base branch (default branch), title (Conventional Commit format), body, optional labels
- **Check existing state:** built in. If an open change request already exists for the head, the command prints `exists <n>` and opens nothing: use `cr.update` instead.
- **Command:** write the body to a temporary file, then:
  ```sh
  forge.sh cr-open --head <branch> --title "<title>" --body-file <file> [--base <base>] [--label "<label>"]
  ```
  The head must be a local branch with commits that aren't on the base. Every label must exist in the store (`label.ensure`).
- **Output:** `opened <n>`, and the issues its body closes. The record is `<store>/crs/<NNNN>.md`.
- **Closing reference:** put `Closes #<issue>` in the body. As on GitHub, any of `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves` or `resolved`, in any case, with an optional colon, followed by `#<n>`, closes that issue on merge, anywhere in the body. So write other mentions without the keyword. `cr.status`'s `closes` shows what will be closed: only numbers that are issues in the store count.
- **Fallback:** none needed.

### cr.update

- **Tier:** write
- **Inputs:** the change request (number, or head branch), and any of: `title`, `body`, `labels_add`, `labels_remove`
- **Check existing state:** built in. Only what differs is written, bodies compared after trimming trailing whitespace. Nothing differing prints `no changes`. A change request that isn't open is refused.
- **Command:**
  ```sh
  forge.sh cr-update <n|branch> --title "<title>" --body-file <file> --add-label "<label>" --remove-label "<label>"
  ```
- **Output:** fields changed, as `name: old → new` (for the body, just `body changed`).
- **Notes:** new commits aren't an update. They're on the head branch already.
- **Fallback:** none needed.

### cr.status

- **Tier:** read
- **Inputs:** the change request (number, or head branch: its open one, or else its latest)
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  forge.sh cr-status <n|branch>
  ```
- **Output:** `key: value` lines:

  | Neutral | Local |
  |---|---|
  | `state` | `open`, `closed` or `merged` |
  | `checks` | `no checks reported`: there's no pipeline service, so work-issue's local runs, recorded in the body, are the check (conventions §11). `merge.sh` runs the required stages again before merging |
  | `review` | `no review required` |
  | `mergeable` | `yes` or `conflicts`, from a trial merge (`git merge-tree --write-tree`, git 2.38 or later), or `merged` |
  | `closes` | the issues the body's closing references name. Once merged, the issues the merge closed |

  It also prints `number`, `title`, `head`, `base`, `labels` and the record's path, and once merged, `merged` and `merge_commit`.
- **Fallback:** none needed.

### cr.list

- **Tier:** read
- **Inputs:** base branch (default branch)
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  forge.sh cr-list [--base <base>]
  ```
  `--state open`, `closed` or `all` lists the others instead: `number`, `state`, `title` and `head`.
- **Output:** for each merged change request, one tab-separated line:
  - `number`
  - `title`
  - `merged`: the UTC date
  - `merge_commit`: the squash commit on the base branch
  - `closes`: the issues the merge closed
- **Notes:** to find the change requests in a range, intersect `merge_commit` with `git rev-list <from>..<to>`, as on any forge.
- **Fallback:** none needed.

### cr.merge

- **Tier:** admin. **The maintainer's command:** no skill runs it (conventions §10). work-issue ends by telling the maintainer to run it.
- **Inputs:** the change request's number
- **Check existing state:** built in. It refuses, changing nothing, a change request that isn't open, whose branches are missing, that has conflicts with the base, that changes nothing, or that fails a required stage. It also refuses if a worktree that has the base checked out has uncommitted changes.
- **Command:**
  ```sh
  <skill set>/adapters/forge/local/merge.sh <n>          # asks for a yes
  <skill set>/adapters/forge/local/merge.sh <n> --yes    # doesn't ask
  ```
  1. In a temporary worktree, it squash-merges the head into the base as one commit, `<title> (#<n>)`, with the body as the commit message's body, as on GitHub (conventions §10).
  2. It runs the required stages (`rule.require-checks`, else the four core stages) with their `run` commands from the merge result's config. A disabled stage is a placeholder, and passes. A failing stage leaves its log, and nothing is merged.
  3. After a yes, it moves the base to the merge commit with `I2R_MERGE=1`, so the hooks let it through. A clean worktree that has the base checked out is moved forward too.
  4. It records the merge (`State: merged`, `Merged`, `Merge-Commit` and `Closes`), closes each issue the body names with `issue.close` (`completed`, with a comment naming the change request), and deletes the head branch if `delete_branch_on_merge` is on and it isn't checked out.
- **Output:** each stage's result, the commit, the issues closed, and `merged #<n> as <short sha>`.
- **Fallback:** none needed.

## Pipeline

The local forge has no pipeline service (conventions §11). The config's `pipeline` block is still the single definition of each stage, and its `run` commands are run locally: by work-issue before each change request, by `merge.sh` before each merge, and by cut-release, through `pipeline.status`, on the release commit and the tag. `pipeline.ci` doesn't apply, and either value is accepted.

### pipeline.render

- **Tier:** write (but it writes nothing)
- **Inputs:** the project's `.project/config.yml`
- **Check existing state:** not applicable: there are no CI files to compare.
- **Command:**
  ```sh
  forge.sh pipeline-render [<config>]
  ```
  It checks the pipeline block as the GitHub renderer does, and fails, naming the problem, if every core stage isn't there, an enabled stage has no `run`, a disabled stage has no `reason`, or an extra stage lacks a valid `mode`, `runs_on` or `run`.
- **Output:** `no CI files written`, then each stage: its mode, when it runs and its command, or `placeholder: <reason>`.
- **Fallback:** this is the fallback for a forge with no pipeline service (conventions §11).

### pipeline.status

- **Tier:** read. It runs the stages' commands, in a temporary worktree, and changes nothing in the repository.
- **Inputs:** a commit, a branch, a tag, or a change request's number. The event that chooses which stages run is `change_request` for a change request (at its head) or a commit, and `release` for a tag. Give `--event change_request`, `merge` or `release` to choose another.
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  forge.sh pipeline-status <commit|branch|tag|cr-number> [--event change_request|merge|release]
  ```
  It makes a clean worktree of that commit, so uncommitted and untracked files don't count, and runs each stage whose `runs_on` includes the event, as conventions §11 says: `lint` on change requests only, the other core stages on all three, and each extra stage on its own `runs_on`. The worktree is removed afterwards.
- **Output:** the commit and event, then one line per stage in config order: `pass`, `pass (placeholder)` for a disabled stage, `fail (log: <path>)`, `fail (advisory; ...)` for an advisory stage, or `skipped (runs on ...)`. Finally `overall: pass` if every required stage that ran passed, else `overall: fail`. Nothing is ever `pending`: the result is there when the command ends.
- **Fallback:** none needed.

## Release

Releases are kept in the tracker store, one folder per tag:

```
<store>/releases/<tag>/
  release.md       "Key: value" header (Tag, Title, State: draft | published, Commit, Created, Published), a blank line, the notes
  assets/          the release's files: the archives package.build made
```

Every write is one commit in the store. The tag itself is an ordinary annotated git tag in the project. With no remote there's nothing to push, so creating it starts nothing: cut-release runs the release stages with `pipeline.status <tag>`.

**Order,** as on any forge: `tag.create`, then `release.draft`, then `release.publish`. A draft needs its tag, and publishing checks that the tag still points at the drafted commit.

### tag.create

- **Tier:** admin
- **Inputs:** tag name (`<tag_prefix><version>`), the commit (normally the local default branch's head), and a message (the release title)
- **Check existing state:** built in. No such tag: create it. The same commit: `no change`. **A different commit: it stops and reports.** A release tag is never moved or deleted (conventions §13).
- **Command:**
  ```sh
  forge.sh tag-create <tag> <commit> -m "<message>"
  ```
- **Output:** the tag and the commit it points to.
- **Notes:** there's no push, and no pipeline is triggered. Run `pipeline.status <tag>` for the release stages.
- **Fallback:** none needed.

### release.draft

- **Tier:** write
- **Inputs:** tag, title, notes (written to a file), and asset files (may be none)
- **Check existing state:** built in.
  - **No release for the tag:** create the draft.
  - **A draft exists:** update it, changing only what differs: title, notes (compared after trimming trailing whitespace), the commit, and assets (by name and content). Nothing differing prints `no changes`.
  - **A published release exists:** it stops and reports. A correction is a new patch release.
- **Command:**
  ```sh
  forge.sh release-draft <tag> --title "<title>" --notes-file <notes> --asset <file> [--asset <file> ...]
  ```
  It fails with "tag <tag> doesn't exist" if `tag.create` hasn't run. Report that as a missing step.
- **Output:** the record's path, what changed, and each asset's name and size. `forge.sh release-view <tag>` shows the record and its assets again.
- **Fallback:** none needed.

### release.publish

- **Tier:** admin
- **Inputs:** tag
- **Check existing state:** built in. **Already published:** `no change`. **No draft:** a failure, so run `release.draft` first. **The tag is missing, or points somewhere other than the drafted commit:** it stops and reports.
- **Command:**
  ```sh
  forge.sh release-publish <tag>
  ```
- **Output:** the record's path. It's marked `State: published`, with today's UTC date in `Published`. There's no "latest" marker: the highest published version is the latest.
- **Fallback:** none needed.

## Forge-specific sources

These aren't verbs. Skills ask the adapter for them when they write standard files. They all work offline.

### Licence text

```sh
forge.sh licence <key> "<holder>" <year>
```

Bundled texts, in `adapters/forge/local/licences/`: `mit`, `apache-2.0`, `bsd-3-clause`, `gpl-3.0` and `mpl-2.0` (SPDX keys, in any case). `[year]` and `[fullname]` are filled in. Any other licence: the command fails, and says to ask the user for the text.

### Owner display name

```sh
forge.sh owner-name
```

git's `user.name`. If it isn't set, ask the user.

### .gitignore templates

```sh
forge.sh gitignore [<language>]
```

There are no language templates offline. It prints only the OS and editor block (`.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/`, `*.swp`), and says so if a language was asked for. Add the language's own lines by hand, if wanted.

### Templates for issues and change requests

Not applicable: issues and change requests are records in the tracker store, written by the adapters, so there are no template files to write.

### Release and changelog links

```sh
forge.sh release-links <tag> [<path>]
```

There are no URLs, only paths:

- A release page: `<store>/releases/<tag>/release.md`. package.build puts it in the release README in place of a URL.
- A file at a release, for the notes' tutorial link: `<path>` at `<tag>`, which anyone with the repository can read with `git show <tag>:<path>`.
- The changes in a release, for the changelog's link references: none. cut-release writes the changelog section without a link reference.
