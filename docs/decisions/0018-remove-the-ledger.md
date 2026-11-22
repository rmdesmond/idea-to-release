# 0018: Remove the ledger

Date: 2026-11-21
Status: accepted

## Context

`.project/ledger.yml` maps each task to its issue, change requests and release. Two skills write it: plan-to-issues adds entries through a `chore(ledger):` change request, and cut-release fills in the release fields.

Almost every field can be worked out from somewhere else:
- the title and milestone from the plan
- the issue from its `T-NNN:` title and `Plan-Task:` footer
- the change requests from their closing references, which squash merges also copy into git as `Closes #N`
- the release from the tag range that holds the merge commit (`git tag --contains`)

cut-release already works the values out that way, then writes them down.

The ledger had a real cost. It added change requests of its own and needed a second writer kept in step, with a check script and fixtures. It also caused #93: a ledger change request built on a stale branch of the same name, which would have reverted most of `main`. Issue #97 asked for safeguards around it. The maintainer doesn't read the ledger, and doesn't expect anyone else to.

## Decision

Remove the ledger (T-034). `.project/ledger.yml`, `scripts/check-ledger.sh` and their tests are deleted, and no skill reads or writes a ledger. Conventions §6 becomes "Traceability", which says where each link is read from when it's needed:

- task → issue: the issue's `Plan-Task:` footer, then the `T-NNN:` title prefix
- issue → change requests: the change requests whose `closes` includes it
- change request → release: its merge commit in `<previous tag>..<tag>`

cut-release builds the release notes' "Plan tasks delivered" from those links. A task whose issue was closed as completed with no change request since the last tag is listed too.

## Consequences

- Fewer change requests, one writer fewer, and no ledger branches, so #97 no longer applies.
- The trail is read from the forge at release time, so it's only as portable as the forge's data and git history. The squash commits keep `Closes #N` and the tags, which is enough to rebuild it.
- Decision 0006's `Issue:` line stays. Its mentions of the ledger no longer apply: plan-to-issues adopts the named issue directly.
- A project that still has a `.project/ledger.yml` can delete it; the skills ignore it.
