# 0004: Squash merges and trunk-based releases

Date: 2026-11-20
Status: accepted

## Context
The merge method decides what history the default branch keeps, and the changelog is built from it.

## Decision
Allow only squash merges, with the change request title and description as the commit message. Delete head branches after merge. Release from the default branch (trunk) with tags v<major>.<minor>.<patch>.

## Consequences
Each change request becomes one Conventional Commit on the default branch, which the release skill uses to derive versions and the changelog.
