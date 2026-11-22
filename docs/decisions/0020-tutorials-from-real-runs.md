# 0020: Tutorials come from real runs, and are optional

Date: 2026-11-22
Status: accepted

## Context

T-039's tutorial was written by hand from a recorded run of the skills. The maintainer wants a skill that writes a tutorial for any project, and wants the tutorial shipped in the release when the project has one.

A tutorial written from memory drifts: its commands stop working, and its outputs stop matching what the tool prints. Not every project wants a tutorial, and a release shouldn't wait on documentation nobody asked for.

## Decision

- **A skill, `write-tutorial`,** writes or updates `docs/tutorial.md`.
- **Every command and output in the tutorial comes from a real run:**
  - **Shell steps** are run in a clean copy of the default branch.
  - **Other steps,** such as prompts to an agent, are quoted from a recorded run that the user points to.
  - **A failing step, or no run at all,** stops the skill.
- **The tutorial is merged through a change request,** like any other change.
- **It's optional.** If `docs/tutorial.md` exists, the release archive ships it and the release notes link to it. `cut-release` warns when the tutorial is older than changes in the release, but never requires one.

## Consequences

- There are eight skills. The archive, the plugin and the README list `write-tutorial`.
- A tutorial is only as current as its last run. The warning in `cut-release` is the reminder to run `write-tutorial` again.
- This repository's own tutorial is rewritten by the skill, from T-039's recorded run.
