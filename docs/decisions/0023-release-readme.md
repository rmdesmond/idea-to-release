# 0023: Every release archive has its own README

Date: 2026-11-22
Status: accepted

## Context

Release archives shipped the repository's README. That README is written for people working on the project: its status, layout, roadmap and contribution rules. Someone who downloads a release wants to know what version they have, what it does, how to install it and how to start using it.

## Decision

- **`cut-release` writes a README for each release,** and `package.build` puts it at the top of the archive in place of the repository's README. It has four sections:
  - **Version:** the version and its date
  - **About:** from the plan's summary
  - **Install:** from the target's `install.describe`
  - **Usage:** from a new target verb, `usage.describe`, using real output (`--help` for `shell-cli`, each skill and how to invoke it for `agent-skills`)
- **`package.verify` fails** when the README is missing, or lacks a section.

## Consequences

- Every target adapter implements `usage.describe`, so there are 30 verbs.
- The repository's README no longer has to serve someone installing a release, and can be written for the repository.
