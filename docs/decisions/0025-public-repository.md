# 0025: Make the repository public

Date: 2026-11-26
Status: accepted

## Context

Decision 0016 kept the repository private after the first release, and said going public would take its own decision record. Every planned task is done, v0.4.0 is out, and the skills are meant for other people to install. While the repository was private, installing the plugin needed read access and git credentials for GitHub.

The maintainer made the repository public on 2026-11-26. Before that, its git history, issues, pull requests, review comments and releases were checked for secrets, local paths and personal details. Nothing was found other than the maintainer's name and email address, which the maintainer is content to publish.

## Decision

- The repository is public. This supersedes 0016.
- The config's `visibility` is `public`, so `accept-the-plan` agrees with the forge.
- These GitHub security features are on: secret scanning with push protection, private vulnerability reporting, Dependabot alerts and security updates. Workflows from pull requests by every outside contributor wait for the maintainer's approval before they run.

## Consequences

- Anyone can read the code, issues and releases, and install the plugin without credentials.
- The branch rules from decision 0017 stay as they are. GitHub enforces rules on public repositories on every plan, so they no longer depend on the account staying on GitHub Pro.
- Everything committed, and every issue and pull request, is public from now on.
