# Forge adapter: local

Remote: none

The repository is plain git on one machine, with no hosting service and no remote (decision 0027). Change requests, and later releases, are records in the `local` tracker's store, and the maintainer merges with the adapter's `merge.sh`. It pairs with the `local` tracker. Mixing it with a hosted tracker isn't supported.

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

### cr.open

Status: not yet implemented

T-064 adds change requests as records in the tracker store.

### cr.update

Status: not yet implemented

### cr.status

Status: not yet implemented

### cr.list

Status: not yet implemented

### cr.merge

Status: not yet implemented

## Pipeline

### pipeline.render

Status: not yet implemented

T-065: the local forge has no pipeline service, so it writes no CI files.

### pipeline.status

Status: not yet implemented

## Release

### tag.create

Status: not yet implemented

### release.draft

Status: not yet implemented

### release.publish

Status: not yet implemented

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

Not yet implemented (T-065).
