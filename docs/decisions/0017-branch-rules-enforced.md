# 0017: Branch rules are enforced on `main`

Date: 2026-11-21
Status: accepted

## Context

Decision 0012 kept this repository's branch rules by procedure, because GitHub doesn't enforce them on a private repository on the free plan. The account moved to GitHub Pro on 2026-11-21, and the repository stays private (decision 0016). `repo-governance` (T-030, #78) found the rules available, where they used to return HTTP 403.

## Decision

`main` is protected by the ruleset `idea-to-release`, enforcement active, with no bypass actors:

- deletion and force pushes are blocked, and every change arrives through a pull request
- required approvals: 0, code owners off, stale approvals dismissed (decision 0011)
- required checks: `lint`, `build`, `unit` and `integration` from GitHub Actions. `shellcheck` stays advisory

Checked by trying to break each rule: a direct push and a force push to `main` were rejected with GH013, and pull request #95, with a failing `unit`, couldn't be merged ("the base branch policy prohibits the merge").

## Consequences

- Nobody can push to `main`, the maintainer included. A mistake can't skip the pipeline.
- The rules depend on the plan. If the account leaves Pro while the repository is private, GitHub stops enforcing them, and a `repo-governance` run falls back to the procedure in 0012 again.
- With 0 approvals required, the maintainer's merge is the review. A second maintainer raises it to 1 through a plan change and a `repo-governance` run.
