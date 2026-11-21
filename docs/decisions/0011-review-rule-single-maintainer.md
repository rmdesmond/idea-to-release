# 0011: Review rule while there's a single maintainer

Date: 2026-11-21
Status: accepted

## Context

This repository has one maintainer. Agents open every change request with the maintainer's own GitHub login, so GitHub counts the maintainer as the author, and an author can't approve their own pull request. With `review.required_approvals: 1`, the value repo-bootstrap writes by default, a branch rule requiring one approval would make every change request unmergeable without an admin bypass, which defeats the rule.

The maintainer's decision (T-018, #28), in their words: "0 approvals; merge is review".

## Decision

While there's one maintainer:

- `review.required_approvals` is `0`, and `code_owners` stays `false`.
- The required checks (`lint`, `build`, `unit`, `integration`, conventions §11) are the gate on every change request.
- Only the maintainer merges. Reading a change request and choosing to merge it is the review. Agents never approve or merge (conventions §10, `work-issue`).

When a second maintainer joins:

- `review.required_approvals` becomes `1`, so each change request needs an approval from someone other than its author. That's a plan change (`idea-to-plan` revise mode) followed by a `repo-governance` run.
- If agents still open change requests under one maintainer's login, the other maintainer approves them.

## Consequences

- Branch rules can require pull requests and checks without blocking every merge.
- Nothing enforces a second pair of eyes, so the review depends on the maintainer actually reading each change request. The PR body's *How it was verified* section, with evidence for each item, is there to make that practical.
- repo-bootstrap still defaults to `required_approvals: 1`. That's right for most teams, but repo-governance (T-020) should warn when it's set to 1 or more and only one person has write access, because merges would be blocked.
