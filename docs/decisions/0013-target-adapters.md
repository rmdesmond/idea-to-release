# 0013: Target adapters package and install what a project ships

Date: 2026-11-21
Status: accepted

## Context

The skills describe a release in neutral terms: a version, a changelog, release notes, a tag and a forge release (conventions §12). That records a release, but it doesn't say what's shipped or how people install it, and those differ by project. A macOS app, a Linux command-line tool, a package and a set of agent skills are each built, checked and installed in a different way.

Forges and trackers already vary like this, and adapters handle it (conventions §2): skills use neutral verbs, and an adapter translates them for GitHub, GitLab and so on. What a project ships is a third, independent axis. The same GitHub project could ship a CLI or an app.

This repository ships agent skills. `SKILL.md` folders are an open standard, Agent Skills (December 2025), read by Claude Code, Codex, GitHub Copilot, Gemini CLI and others. Each tool looks in its own folder, so a plugin for one tool would be the wrong channel. An install script that knows the folders fits better.

## Decision

- Add a **Target** group of neutral verbs: `package.build`, `package.verify`, `package.publish` and `install.describe`.
- A project names its target in `.project/config.yml` (`target: <name>`), and the verbs are defined in `adapters/target/<name>.md`, as forge and tracker adapters are.
- The `release` skill stays neutral. It builds and verifies the package through the target adapter, attaches the artifacts to the draft release, and puts the install instructions in the notes.
- `idea-to-plan` asks what a project ships. A missing target adapter is a gap, and writing it becomes a plan task (decision 0001).
- The first release includes two targets: `agent-skills` for this repository, and `shell-cli` for the end-to-end test. Two targets show that the abstraction holds.

## Consequences

- Supporting a new kind of project means adding one target adapter. No skill changes.
- `scripts/check-adapters.sh` checks each adapter kind against its own verb group.
- Until a project's target adapter exists, its releases have notes and a tag but no packaged artifacts.
- A Claude Code plugin, or a marketplace entry for another tool, can be added later as `package.publish` channels of the `agent-skills` target.
