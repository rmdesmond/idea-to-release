---
name: repo-governance
description: Apply a repository's rules from .project/config.yml - protect the default branch, require the core pipeline checks and the configured reviews, and manage visibility and access - with a dry run and confirmation before every change, following the idea-to-release conventions. When the forge can't enforce a rule (for example a private repository on a free plan), it records the fallback in a decision record instead of failing. Use after ci-setup, or whenever the review rule, visibility or access should change. Re-runnable; an unchanged config reports no changes.
---

# repo-governance

Makes the repository enforce what the conventions promise: nobody pushes straight to the default branch, every change request passes the core checks and gets the configured reviews, and visibility and access are what the project says they are.

Before doing anything, read `conventions.md`, especially §4 (config), §7 (decision records), §10 (merging), §11 (gates), §13 (safety: every action here is **admin tier**) and §14 (fallbacks). Also read decision records about review and visibility in `docs/decisions/`.

**Verbs used:** `repo.describe`, `repo.configure`, `access.list`, `access.grant`, `rule.protect-branch`, `rule.require-review`, `rule.require-checks`, `pipeline.status`, `cr.open` (forge). Look each one up in the forge adapter named in `.project/config.yml`.

## Arguments

All optional. Pass them as `key=value`.

| Argument | Default | Notes |
|---|---|---|
| `visibility` | the config's `visibility` | `private` \| `public` \| `internal`. A value different from the config is a request to change it (step 3) |
| `grant` | none | `<login>:<role>`, repeatable. Role: `read`, `triage`, `write`, `maintain` or `admin` |
| `issue` | none | Issue number for the branch, commits and closing reference of any change request this run opens |
| `non-interactive` | off | Don't ask questions. Admin changes still need `confirm` |
| `confirm` | off | Only with `non-interactive`: the caller confirms the dry run in advance. It never covers a visibility change or an invitation, which always need a person's yes |

## Procedure

### 1. Read the project

- Read `.project/config.yml` and the forge adapter. If a verb above is `not yet implemented`, stop and say which one.
- Read the decision records. Note any accepted record about visibility, the review rule, or a branch-rules fallback (`*-branch-rules-fallback.md`).

### 2. Read the forge

All reads, so run them freely:

- `repo.describe`: current visibility, merge methods, default branch
- `access.list`: who can do what, and how many people can write
- the current branch rules, through the rule verbs' *check existing state* step. If the adapter reports that branch rules aren't available on the plan tier, note it: that's the fallback path (step 6).
- `pipeline.status` on the default branch's latest commit, and on a recent change request if there is one: which core checks actually report

### 3. Work out what's wanted

- **Branch rules:** the default branch is protected (no deletion, no force push, changes only through change requests). The required checks are the four core stages, plus any extra stage with `mode: required` that runs on `change_request`. Reviews come from the config's `review` block.
- **Visibility:** the config's `visibility`.
  - If the forge's visibility differs from the config and no `visibility` argument was given, the two contradict each other: stop and ask which is right (conventions §13).
  - If a `visibility` argument differs from the config, that's a request to change it. The change also updates the config and writes a decision record that supersedes the current visibility record. Making a repository public publishes all of its history: say so plainly.
- **Access:** each `grant` argument. Access is never removed by this skill. If `access.list` shows someone who shouldn't be there, report it and leave the removal to the user.

### 4. Check before changing anything

These checks guard against rules that would lock the repository, so they matter only where the rules can be applied. On the fallback path, report them as notes for the day the rules become available. Otherwise, stop and report, rather than apply the rules, when:

- **A required check has never reported.** Every merge would block. Suggest running ci-setup first, or wait for the pipeline to run.
- **Reviews are required but there aren't enough reviewers.** `required_approvals` is 1 or more, but fewer people than that, other than the author, can write. No change request could merge (decision 0011). Ask whether to lower the number in the config, or to grant access first.

### 5. Dry run and confirmation

Show every difference, before → after, grouped by what changes:

```
Repository: owner/repo (private)   Default branch: main
Visibility:    private (no change)
Access:        rmdesmond admin; 1 person can write; grants: none
Branch rules (ruleset "idea-to-release" on main):
  protect      deletion: allowed → blocked; force push: allowed → blocked; direct push: allowed → blocked
  reviews      required approvals: none → 0; code owners: off (decision 0011)
  checks       required: none → lint, build, unit, integration (all four have reported)
Fallback:      none needed
```

If nothing differs anywhere, say "Repository rules match the config; no changes" and stop.

Then wait for explicit confirmation (admin tier). **A visibility change and each invitation get their own confirmation**, separate from the rest, and `confirm` doesn't cover them.

### 6. Apply

In this order, stopping at the first failure and reporting what was done:

1. **Visibility**, if it changes, with `repo.configure`. The forge may lock the repository for a few seconds afterwards (see the adapter). Wait until a read succeeds.
2. **Access:** `access.grant` for each confirmed grant.
3. **Branch rules:** `rule.protect-branch`, then `rule.require-review`, then `rule.require-checks`. Each one changes only what differs.

**When the forge can't enforce the rules.** If the adapter reports that branch rules aren't available on the plan tier, don't fail. Follow conventions §14:

- Write a decision record, `NNNN-branch-rules-fallback.md` (next free number), with `Status: accepted`. It should cover:
  - **Context:** which rules couldn't be applied, and why (quote the forge's message, for example "private repository on a free plan")
  - **Decision:** how each rule is kept by procedure instead:
    - nobody pushes to the default branch, and agents never do
    - every change arrives through a change request opened by work-issue (or by hand, following conventions §10)
    - the pipeline runs on every change request
    - only the maintainer merges, and only when the core checks pass
  - **Consequences:** nothing technical stops a mistaken push, and that's a known gap. What would restore the rules: making the repository public, or a paid plan. A re-run of repo-governance then applies them.
- If an accepted fallback record already exists and still describes the situation, don't write another one.
- Do the same for a single rule the forge can't enforce while others work, naming just that rule.

Files this skill writes (the fallback record, the config and the visibility record) go through a change request: branch `docs/<issue>-governance` (or `docs/governance`), commit `docs(decisions): record how branch rules are enforced` (or a summary of what changed), then `cr.open`. Don't merge it.

### 7. Report

List what changed, what was already in place, any fallback recorded (with the change request link), and any warnings left for the user, such as people with access the config doesn't explain.

## Re-running

Every step checks before it acts, so a run with an unchanged config and unchanged forge state reports "Repository rules match the config; no changes" and changes nothing. On the fallback path, an existing accepted fallback record counts as in place.

If the forge later allows the rules (the repository went public, or the plan changed), the next run applies them. It then supersedes the fallback record: a new record saying the rules are now enforced, with the old one's status set to `superseded by NNNN`.

## Out of scope

- Writing the pipeline that the required checks come from: **ci-setup**
- Changing the review rule's reasoning or the plan: **idea-to-plan**, with a decision record
- Removing people's access, deleting rulesets other than `idea-to-release`, or merging: **the user**
