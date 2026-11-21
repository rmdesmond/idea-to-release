---
name: release
description: Cut a release of a project that follows the idea-to-release conventions - derive the version from the change requests merged since the last tag, update CHANGELOG.md and the ledger through a release change request, then tag, package through the target adapter, draft the release with notes listing the plan tasks it delivers, and publish only after the user confirms and every release gate passes. Re-runnable; it picks up wherever an earlier run stopped. Use when the default branch has changes worth releasing.
---

# release

Turns what has been merged since the last release into a published, tagged version, with a changelog entry, notes that say which plan tasks shipped, the packaged artifacts, and a complete ledger.

**Where the skill set's files are.** `conventions.md`, `adapters/` and `scripts/check-*.sh` belong to the idea-to-release skill set, not to the project. When installed, they're in `../idea-to-release/`, next to this skill's folder. In a clone of the idea-to-release repository, they're at its root, `../../` from this skill's folder (conventions §3).

Before doing anything, read `conventions.md`, especially §6 (ledger), §11 (gates), §12 (versions and releases), §13 (safety: tagging and publishing are **admin tier**) and §14 (fallbacks).

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

- Read `.project/config.yml`: the `release` block (`tag_prefix`, `strategy`), `target`, and the pipeline stages.
  - `strategy: release-branches` isn't supported yet. Stop and say so.
  - If a verb above is `not yet implemented`, stop and say which one.
  - **No target, or no adapter for it:** carry on without artifacts (decision 0013), and say so in the dry run.
- Run `scripts/check-plan.sh` and `scripts/check-ledger.sh` on the project's plan and ledger. If either fails, stop: they're fixed through a change request first.
- `git fetch --tags origin`. Work from the remote default branch (`origin/<default>`), never from a local working tree.

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
- **Changelog section:** group the titles as §12 says. Leave out a group that has no entries. The heading is `## [<X.Y.Z>] - <release date>`. Add the link reference at the end of the file, from the forge adapter's *Release and changelog links*. Keep `## [Unreleased]` at the top, emptied.
- **Ledger:** reconcile every entry against `cr.list` and `issue.list state=all`. Change only these fields, never `title`, `milestone`, `issue` or `created`:
  - `change_requests`: every merged change request whose `closes` includes the task's issue, sorted. Fill it in for any entry that lacks it, including tasks from earlier releases.
  - `merged`: the latest of their `merged` dates.
  - `released_in` and `released`, for each task delivered by this release:
    - **It has a change request in this release,** and no `released_in` yet.
    - **Or its issue is closed as completed with no change request,** and no `released_in` yet. That's work done before the tracker was used, and it ships in the first release that includes it. List these in the dry run so the user can check them.
  - Tasks already released keep their `released_in`.
- **The release commit's files:** `CHANGELOG.md` and `.project/ledger.yml`. Run `scripts/check-ledger.sh` on the new ledger. It must pass.

### 4. Prepare: dry run, then the release change request

Show:

```
Repository: owner/repo   Last release: v0.1.0 (or none)   Target: agent-skills
Version:      v0.2.0 (derived: feat in #85, #88)
Gates now:    build pass, unit pass, integration pass (placeholder)
Included:     7 change requests (#82, #83, ...); not listed in the changelog: 3 (docs, chore)
CHANGELOG.md  ## [0.2.0] - 2026-11-24: Added 2, Fixed 3
Ledger:       released_in v0.2.0 for T-024, T-025 (2 tasks); change_requests filled in for 21 entries
              closed without a change request: T-001 (#20) → released in v0.2.0
Change request: branch chore/release-v0.2.0, "chore(release): v0.2.0"
Then (later runs): tag v0.2.0 on the merged commit → release gates → package → draft → publish (each confirmed)
```

This step only writes a branch and opens a change request, so it's write tier: say what will happen, then do it. Commit `chore(release): <version>` on `chore/release-<version>`, then `cr.open` with the changelog section, the ledger summary and, if `issue` was given, `Closes #<issue>`. Run `cr.status`: `closes` must be exactly that issue, or empty.

**Stop there.** The user reviews and merges the release change request. Then run release again.

### 5. Tag

- **The release commit:** the default branch's head, which must be the release change request's merge commit. If something else was merged after it, stop and ask. The changelog would then miss those changes, so the choice is between re-preparing and tagging the release commit itself.
- **Gates:** `pipeline.status` on that commit. Every required stage must pass.
- **Dry run:** `tag.create <tag> <sha>`, which runs the release stages. Wait for **explicit confirmation** (admin tier).
- **After the push:** `pipeline.status` for the tag, waiting until nothing is pending. Every stage that gates a release must pass: the core stages and any extra stage that runs on `release` in `required` mode.
  - **If one fails:** stop and report. Don't draft. The tag stays, since tags are never moved (conventions §12). The fix is a new change request, then a patch release.

### 6. Package and draft

- **Package:** take a clean copy of the tag and run `package.build` on it, then `package.verify` on the artifacts. If `verify` fails, it's a failed release gate: stop and report.
- **Notes:** write them from the ledger and the changelog, not from memory:

  ```markdown
  <one line: the milestone goals this release completes, from the plan, if any>

  ## Plan tasks delivered

  ### M1: <milestone title>
  - T-002: <title> (issue #1, change request #3)

  ## Changes

  <the changelog section's groups, as written>

  ## Install

  <install.describe for this version>
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
