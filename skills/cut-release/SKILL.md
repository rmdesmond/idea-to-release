---
name: cut-release
description: Cut a release of a project that follows the idea-to-release conventions - derive the version from the change requests merged since the last tag, update CHANGELOG.md through a release change request, then tag, package through the target adapter, draft the release with notes listing the plan tasks it delivers, and publish only after the user confirms and every release gate passes. Re-runnable; it picks up wherever an earlier run stopped. Use when the default branch has changes worth releasing.
---

# cut-release

Turns what has been merged since the last release into a published, tagged version, with a changelog entry, notes that say which plan tasks shipped, and the packaged artifacts.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. In the Claude Code plugin `i2r`, and in a clone of the idea-to-release repository, they're at its root: `${CLAUDE_PLUGIN_ROOT}` in the plugin, and `../../` from this skill's folder in both. When installed by `install.sh`, they're in `../idea-to-release/`, next to this skill's folder (conventions §3). Run the check scripts with `bash <path>`, in case an installed copy lost their executable bit.

Before doing anything, read `conventions.md`, especially §6 (traceability), §11 (gates), §12 (versions and releases), §13 (safety: tagging and publishing are **admin tier**) and §14 (fallbacks).

**Verbs used:** `cr.list`, `cr.open`, `cr.status`, `pipeline.status`, `tag.create`, `release.draft`, `release.publish` (forge); `issue.list` (tracker); `package.build`, `package.verify`, `package.publish`, `install.describe` (target). Look each one up in the adapters named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `version` | derived (conventions §12) | e.g. `0.2.0` or `v0.2.0`. Must be valid and higher than the last tag. If it differs from the derived version, say so in the dry run |
| `issue` | none | An issue this release completes, such as a plan task "Release v0.1.0". The release change request closes it |

There is no non-interactive mode. Creating the tag and publishing always need a person's yes.

## Procedure

Every run starts with steps 1 and 2, then carries on from the stage the release has reached.

### 1. Read

- Read `.project/config.yml`: the `release` block (`tag_prefix`, `strategy`, `version_files`), `target`, and the pipeline stages.
  - **Each version file** (conventions §12) must exist, with its marker on exactly one line and an `X.Y.Z` after it. If not, stop and say which entry is wrong.
  - **No `version_files`,** but a file on the default branch that looks like it holds the version (a `--version` string, a `"version":` field, a test that compares the version with the changelog): say so in the dry run, and suggest adding the entry. Don't edit the file without one.
  - `strategy: release-branches` isn't supported yet. Stop and say so.
  - If a verb above is `not yet implemented`, stop and say which one.
  - **No target, or no adapter for it:** carry on without artifacts (decision 0013), and say so in the dry run.
- Run `scripts/check-plan.sh` on the project's plan. If it fails, stop: it's fixed through a change request first.
- `git fetch --tags origin`. Work from the remote default branch (`origin/<default>`), never from a local working tree. If you make a temporary worktree or copy (for the release branch, or the clean copy of the tag), remove it before the run stops, including when it stops to wait for a merge or a confirmation.

### 2. Find the stage

Look for the version's traces, in this order, and go to the first stage that's not done:

| What's found | Stage |
|---|---|
| A published release for the version (`release.publish`'s check) | Done: report it and stop |
| The tag exists | 6. Package and draft |
| `CHANGELOG.md` on the default branch has a section for the version | 5. Tag |
| An open change request on `chore/release-<version>` | Report it (`cr.status`) and stop. The user merges it |
| None of these | 3. Prepare |

On a fresh run, the version isn't known until step 3 works it out. Check first for a section in `CHANGELOG.md` that has no tag yet, and for an open `chore/release-*` change request. If either exists, that's the version in progress.

### 3. Prepare: work out the release

- **Last tag:** the highest `<tag_prefix>X.Y.Z` tag reachable from the default branch. With no tag, this is the first release.
- **Gates now:** `pipeline.status` on the default branch's head. Every required stage must pass. Don't prepare a release from a red branch.
- **Included change requests:** `cr.list`, keeping those whose `merge_commit` lies in `<last-tag>..origin/<default>` (or all of the default branch's history, for the first release). Leave out any earlier `chore(release):` change request.
- **Version:** apply conventions §12 to their titles. If nothing bumps, report "nothing to release" and stop. Use the `version` argument if given, after checking it's valid and higher.
- **Changelog section:** put each title in the first group that matches, in §12's order (Removed, Changed, Fixed, Added). A breaking removal goes under Removed, marked **Breaking:**. List the groups as Added, Changed, Fixed, Removed, and leave out a group that has no entries. The heading is `## [<X.Y.Z>] - <release date>`. Add the link reference at the end of the file, from the forge adapter's *Release and changelog links*. Keep `## [Unreleased]` at the top, emptied.
- **Tasks delivered** (conventions §6), from the included change requests and one `issue.list state=all`:
  - **With a change request:** each issue in an included change request's `closes` whose body has a `Plan-Task: <ID>` line. Its change requests are the included ones that close it.
  - **With none:** each issue with a `Plan-Task:` line that was closed as completed after the last tag was created (any time, for the first release), and that no merged change request closes. That's work done outside a change request. Leave out a task whose *Done when* boxes were all ticked in the plan at the last tag: it shipped in an earlier release, and its issue was only created and closed afterwards, for example by plan-to-issues adopting a project that had already released. List both kinds in the dry run so the user can check them.
  - Take each task's title and milestone from the plan. If the plan has no such task, or its issue's title starts with a different ID, stop and ask (conventions §13).
- **Tutorial** (optional, decision 0020): if `docs/tutorial.md` exists on the default branch, find the last commit that changed it (`git log -1 --format=%H origin/<default> -- docs/tutorial.md`). The included `feat` and `fix` change requests, and any breaking one, whose merge commit isn't an ancestor of that commit (`git merge-base --is-ancestor`) were merged after the tutorial last changed, so it may not show them. If there are any, warn in the dry run, list them, and suggest running write-tutorial first. Never stop for it: a tutorial is never required. With no tutorial, just say so in the dry run.
- **Version files:** in each `release.version_files` entry, replace the first `X.Y.Z` after the marker on its line with the new version. Everything around it (quotes, a `v` prefix) stays as it is.
- **The release commit's files:** `CHANGELOG.md` and the version files. Then run the project's enabled stages locally (their `run` commands), so a release change request never arrives red.

### 4. Prepare: dry run, then the release change request

Show:

```
Repository: owner/repo   Last release: v0.1.0 (or none)   Target: agent-skills
Version:      v0.2.0 (derived: feat in #85, #88)
Gates now:    build pass, unit pass, integration pass (placeholder)
Included:     7 change requests (#82, #83, ...); not listed in the changelog: 3 (docs, chore)
CHANGELOG.md  ## [0.2.0] - 2026-11-24: Added 2, Fixed 3, Removed 1
                Removed: - **Breaking:** Remove the ledger (#104)
Version files: bin/slug  SLUG_VERSION=0.1.0 → 0.2.0
Tasks:        T-024 (#34, CR #81), T-025 (#35, CR #83) (2 tasks, M5)
Tutorial:     docs/tutorial.md, last changed by #80; merged after it: #85, #88 (feat). Consider write-tutorial first
              closed without a change request: T-001 (#20)
              left out, done in the plan at v0.1.0: T-002 to T-009 (#21 to #28)
Change request: branch chore/release-v0.2.0, "chore(release): v0.2.0"
Then (later runs): tag v0.2.0 on the merged commit → release gates → package → draft → publish (each confirmed)
```

This step only writes a branch and opens a change request, so it's write tier: say what will happen, then do it. Commit `chore(release): <version>` on `chore/release-<version>`, then `cr.open` with the changelog section, the tasks delivered and, if `issue` was given, `Closes #<issue>`. Run `cr.status`: `closes` must be exactly that issue, or empty.

**Stop there.** The user reviews and merges the release change request. Then run release again.

### 5. Tag

- **The release commit:** the default branch's head, which must be the release change request's merge commit. If something else was merged after it, stop and ask. The changelog would then miss those changes, so the choice is between re-preparing and tagging the release commit itself.
- **Gates:** `pipeline.status` on that commit. Every required stage must pass.
- **Dry run:** `tag.create <tag> <sha>`, which runs the release stages. Wait for **explicit confirmation** (admin tier).
- **After the push:** `pipeline.status` for the tag, waiting until nothing is pending. Every stage that gates a release must pass: the core stages and any extra stage that runs on `release` in `required` mode.
  - **If one fails:** stop and report. Don't draft. The tag stays, since tags are never moved (conventions §12). The fix is a new change request, then a patch release.

### 6. Package and draft

- **Package:** take a clean copy of the tag and run `package.build` on it, then `package.verify` on the artifacts. If `verify` fails, it's a failed release gate: stop and report.
- **Notes:** work out the tasks delivered again, as in step 3, for `<last-tag>..<tag>`, and write the notes from them and the changelog, not from memory:

  ```markdown
  <one line: the milestone goals this release completes, from the plan, if any>

  ## Plan tasks delivered

  ### M1: <milestone title>
  - T-002: <title> (issue #1, change request #3)

  ## Changes

  <the changelog section's groups, as written>

  ## Install

  <install.describe for this version>

  ## Tutorial

  <only if docs/tutorial.md exists at the tag: one line linking to it at the tag (the forge adapter's file-at-a-release link)>
  ```

- **`release.draft`** with the title `<tag>`, the notes, and the artifacts. Show its URL, the asset names and sizes, and the notes.

### 7. Publish

- **Dry run:** the draft's URL, its assets, and the gates on the tag (all pass). Then wait for **explicit confirmation** (admin tier). Without a yes, stop: the draft stays as it is, and a later run picks it up here.
- **Then** `package.publish`, then `release.publish`.

### 8. Report

Report:
- the version and the release URL
- the assets
- the tasks delivered
- anything the user should look at, such as tasks closed without a change request, or a `release.publish` result where the release isn't marked latest

## Re-running

Each stage checks before it acts:
- A prepared change request is reported, not opened again.
- An existing tag at the release commit is left alone.
- A draft is updated only where it differs.
- A published release is reported as done.

So a run can stop at any confirmation and be resumed later.

## Out of scope

- Merging the release change request: **the user**
- Fixing a failed gate: a change request through **work-issue**, then a new release
- Creating the issues or plan tasks a release delivers: **plan-to-issues**, **idea-to-plan**
- Writing a target adapter for a new kind of project: a plan task (decision 0013)
