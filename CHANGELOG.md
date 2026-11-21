# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-21

### Added

- Add repo-bootstrap skill and GitHub adapter verbs (#2)
- Add idea-to-plan skill and plan format check (#9)
- Implement GitHub tracker verbs for plan-to-issues (#16)
- Add plan-to-issues skill (#17)
- Put task IDs in issue titles (#42)
- Implement cr.update and cr.status for GitHub (#43)
- Add work-issue skill (#45)
- Put task titles in the ledger (#51)
- Propose run commands when enabling pipeline stages (#56)
- Implement pipeline.render and pipeline.status for GitHub (#61)
- Add the ci-setup skill (#62)
- Implement the access and branch rule verbs for GitHub (#65)
- Add the repo-governance skill (#66)
- Implement the tag and release verbs for GitHub (#74)
- Add the target verbs and the agent-skills target (#80)
- Add the release skill (#81)
- Ask for the release target when planning (#85)
- Add the shell-cli target (#86)

### Fixed

- Pass enable-squash-merge with the squash message flag (#19)
- Remove state labels from closed issues in plan-to-issues (#40)
- Close gaps in work-issue found end to end (#49)
- Check that a change request closes only its own issue (#54)
- Let work-issue take a decided needs-decision issue (#59)
- Have work-issue wait for CI, found end to end (#68)
- Default the review rule to 0 approvals for a single maintainer (#70)
- Remove state labels from every closed issue in plan-to-issues (#71)
- Update version files in the release change request, found end to end (#89)

[0.1.0]: https://github.com/rmdesmond/idea-to-release/releases/tag/v0.1.0
