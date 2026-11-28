# 0027: A local forge and tracker

Date: 2026-11-28
Status: accepted

## Context

Every forge and tracker adapter so far is GitHub. A project that lives only on one machine, with no hosting service, can't use the skills: there is nowhere to keep issues, nothing to open a change request on, and no service to run the pipeline or enforce branch rules. The repository itself is still git, so most of what the skills need is already there. The tracker is the missing part, and it shouldn't live in the repository, where every issue change would need a change request of its own.

## Decision

- A `local` forge adapter and a `local` tracker adapter, used together. Mixing either with a hosted adapter is out of scope.
- **The tracker store** is a folder outside the repository, linked through `tracker_path` in `.project/config.yml`, relative to the repository root, and `../<repo>-tracker` by default. It's checked in, so the link is explicit, and it works on any machine with the same folder layout.
- **The store is a git repository of its own.** Every tracker write is one commit, so the store has history, can be undone and can be backed up.
- **Change requests are records** in the store (`crs/NNNN.md`), numbered alongside issues. The maintainer merges with the adapter's `merge.sh <N>`, which runs the required stages, squash-merges the change as `<title> (#N)` and closes the issues it names. No skill merges, as before.
- **No remote, ever.** The local forge declares `Remote: none`, and skills skip push and fetch steps.
- **Branch rules are git hooks:** a `pre-commit` hook refuses commits on the default branch except from `merge.sh`. Hooks can be bypassed (`--no-verify`), so they are guard-rails, backed by procedure (decision 0012).
- **Forge-specific sources come from the skill set:** licence texts for MIT, Apache-2.0, BSD-3-Clause, GPL-3.0 and MPL-2.0 are bundled; any other licence is asked for.

## Consequences

- A project can go from idea to release with only `git` and the standard tools: no `gh`, no account and no network.
- There is no CI. work-issue's local runs are the check on every change request, and `pipeline.ci` doesn't apply.
- Nothing protects the work from the loss of the machine except backups. The store can be copied or pushed anywhere by hand, but the forge has no remote.
- The store is for one person on one machine. Two people writing to it would need it shared and merged, which isn't designed.
