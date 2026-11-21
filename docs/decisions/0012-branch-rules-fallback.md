# 0012: Branch rules are kept by procedure while the repository is private

Date: 2026-11-21
Status: accepted

## Context

repo-governance (T-022, #32) tried to apply this repository's rules to `main`:

- protection: no deletion, no force push, no direct push
- required checks: `lint`, `build`, `unit`, `integration`
- the review rule from decision 0011: 0 approvals

GitHub refused all of them, reads included: "Upgrade to GitHub Pro or make this repository public to enable this feature." The repository is private (decision 0003) and owned by a free account, so neither rulesets nor classic branch protection are available (conventions §14).

The same rules were proven to work on a public scratch repository in T-021 (#31). There, a direct push to `main` was rejected, and a change request with a failing check couldn't merge until it passed.

Settings GitHub does allow are already in place: squash merges only, with the pull request title and description as the commit, and head branches deleted on merge.

## Decision

Until GitHub can enforce the rules, they're kept by procedure:

- Nobody pushes to `main`, and agents never do.
- Every change arrives through a change request: work-issue for plan tasks, and by hand following conventions §10 for anything else.
- The pipeline (`.github/workflows/pipeline.yml`) runs on every change request. Its four core checks are read before merging: work-issue reports them, and the pull request shows them.
- Only the maintainer merges, and only when the core checks pass. The advisory `shellcheck` check is reported but never blocks.
- Agents never merge, never approve, and never use an admin override.

## Consequences

- Nothing technical stops a mistaken push to `main`, a force push, or a merge with a failing check. That's a known gap, made smaller by CI on every change request and a single maintainer who merges.
- The README says how `main` is protected while the repository is private.
- Making the repository public (a decision that supersedes 0003), or moving the account to a paid plan, makes the rules available. Running repo-governance then applies them, and a new record supersedes this one.
