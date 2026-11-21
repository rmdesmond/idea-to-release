# 0016: Stay private after the first release, with branch rules enforced

Date: 2026-11-21
Status: accepted

## Context

Decision 0003 kept the repository private until the first release. v0.1.0 is now out. The plan's last M5 task (T-030) was to make the repository public, mainly because GitHub's free plan doesn't enforce branch rules on private repositories (decision 0012).

On 2026-11-21 the maintainer moved the account to GitHub Pro, which does. On a private scratch repository, `repo-governance` then applied the ruleset: a direct push and a force push to `main` were rejected, and a pull request with a failing check couldn't be merged.

## Decision

The repository stays private. T-030 becomes "Enforce the branch rules on the private repository". Going public is no longer planned; it would be its own plan change and decision record.

## Consequences

- The branch rules are enforced without making the code public.
- Releases, issues and the install instructions stay visible only to people with access. Sharing the skill set means adding collaborators, until a later decision says otherwise.
- The account must stay on a plan that enforces rules on private repositories. If it doesn't, `repo-governance` falls back to the procedure in decision 0012 again.
