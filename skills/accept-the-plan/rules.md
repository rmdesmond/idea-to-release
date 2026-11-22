# accept-the-plan: the branch rules, visibility and access

Supporting file for `SKILL.md`, steps 2 and 6. It makes the repository enforce what the conventions promise: nobody pushes straight to the default branch, every change request passes the core checks and gets the configured reviews, and visibility and access are what the project says they are. Every change here is **admin tier** (conventions §13).

**Verbs:** `repo.describe`, `repo.configure`, `access.list`, `access.grant`, `rule.protect-branch`, `rule.require-review`, `rule.require-checks`, `pipeline.status` (forge).

Also read the decision records about review and visibility, and any branch-rules fallback (`*-branch-rules-fallback.md`), in `docs/decisions/`.

## Read the forge

All reads, so run them freely:

- `repo.describe`: current visibility, default branch
- `access.list`: who can do what, and how many people can write
- the current branch rules, through the rule verbs' *check existing state* step. If the adapter reports that branch rules aren't available on the plan tier, note it: that's the fallback path (below)
- `pipeline.status` on the default branch's latest commit, and on the latest change request: which core checks actually report

## Work out what's wanted

- **Branch rules:** the default branch is protected (no deletion, no force push, changes only through change requests). The required checks are the four core stages, plus any extra stage with `mode: required` that runs on `change_request`. Reviews come from the config's `review` block.
- **Visibility:** the config's `visibility`.
  - If the forge's visibility differs from the config and no `visibility` argument was given, the two contradict each other: stop and ask which is right (conventions §13).
  - If a `visibility` argument differs from the config, that's a request to change it. The change also updates the config, and writes a decision record that supersedes the current visibility record. Both go in the acceptance change request. Making a repository public publishes all of its history: say so plainly.
- **Access:** each `grant` argument. Access is never removed by this skill. If `access.list` shows someone who shouldn't be there, report it and leave the removal to the user.

## For the dry run

```
Branch rules (ruleset "idea-to-release" on main), once every required check has reported:
  protect      deletion: allowed → blocked; force push: allowed → blocked; direct push: allowed → blocked
  reviews      required approvals: none → 0; code owners: off (review rule record)
  checks       required: none → lint, build, unit, integration
Visibility:    private (no change)
Access:        you admin; 1 person can write; grants: none
```

**A visibility change, and each invitation, get their own confirmation,** separate from the rest, and `confirm` never covers them.

## Check before applying

These checks guard against rules that would lock the repository. On the fallback path, report them as notes for the day the rules become available. Otherwise, stop and report rather than apply the rules when:

- **A required check has never reported.** Every merge would block. In a new repository, the acceptance change request is where `lint` reports first, since it runs only on change requests (conventions §11). Wait for its checks.
- **A required check fails** on the acceptance change request. Fix the cause first: rules over a red pipeline block every merge.
- **Reviews are required but there aren't enough reviewers.** `required_approvals` is 1 or more, but fewer people than that, other than the author, can write. No change request could merge (decision 0011 in the idea-to-release repository explains why). Ask whether to lower the number in the config, or to grant access first.

## Apply

In this order, stopping at the first failure:

1. **Visibility**, if it changes and was confirmed on its own, with `repo.configure`. The forge may lock the repository for a few seconds afterwards (see the adapter). Wait until a read succeeds.
2. **Access:** `access.grant` for each confirmed grant.
3. **Branch rules:** `rule.protect-branch`, then `rule.require-review`, then `rule.require-checks`. Each one changes only what differs.

## When the forge can't enforce the rules

If the adapter reports that branch rules aren't available on the plan tier, don't fail. Follow conventions §14:

- Write a decision record, `NNNN-branch-rules-fallback.md` (next free number), with `Status: accepted`, and push it to the acceptance change request. It covers:
  - **Context:** which rules couldn't be applied, and why (quote the forge's message, for example "private repository on a free plan")
  - **Decision:** how each rule is kept by procedure instead:
    - nobody pushes to the default branch, and agents never do
    - every change arrives through a change request opened by work-issue (or by hand, following conventions §10)
    - the pipeline runs on every change request
    - only the maintainer merges, and only when the core checks pass
  - **Consequences:** nothing technical stops a mistaken push, and that's a known gap. What would restore the rules: making the repository public, or a paid plan. A later run of accept-the-plan then applies them.
- If an accepted fallback record already exists and still describes the situation, don't write another one.
- Do the same for a single rule the forge can't enforce while others work, naming just that rule.

If the forge later allows the rules (the repository went public, or the plan changed), the next run applies them, and supersedes the fallback record: a new record saying the rules are now enforced, with the old one's status set to `superseded by NNNN`.
