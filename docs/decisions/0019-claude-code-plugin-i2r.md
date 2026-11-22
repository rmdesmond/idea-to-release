# 0019: The Claude Code plugin is called i2r

Date: 2026-11-21
Status: accepted

## Context

In Claude Code, a plugin's skills are namespaced: `/<plugin>:<skill>`. That avoids the name clashes decision 0015 deals with for `install.sh`, but the plugin name is typed every time. `/idea-to-release:idea-to-plan` is long. `/i2r:idea-to-plan` is short.

A search found no developer tool, plugin or agent skill called i2r. The name is valid for a plugin (kebab-case, no reserved prefix).

An installed plugin is a copy, and files outside the plugin directory aren't copied. The skills read shared files (`conventions.md`, `adapters/`, `scripts/`), so those must be inside the plugin.

## Decision

- The plugin, and its marketplace, are called `i2r`.
- The repository root is both. `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` sit at the root, so the skills and shared files are in the plugin as they are in a clone, and `../../` from a skill folder is the root in both.
- The plugin's version follows releases. The marketplace's entry is a `github` source for this repository with `"ref": "v<version>"`, and cut-release bumps it and `plugin.json`'s `version` through `release.version_files`. So users get the tagged release, not every commit on `main`. conventions §12's version-file rule allows the `v` before the number for this.
- The repository, the release archive (`idea-to-release-<version>.tar.gz`) and `install.sh`'s shared folder keep the full name. `install.sh` stays the route for other agents.
- Packaging for other agents' plugin formats (Agent Plugins for Cursor, Copilot and Codex) is left for a later release.

## Consequences

- Claude Code users install with `claude plugin marketplace add rmdesmond/idea-to-release` and `claude plugin install i2r@i2r`, and type `/i2r:<skill>`.
- The plugin copy includes the whole repository (docs, tests). Claude Code has no exclude list. It's small, and it doesn't affect the skills.
- While the repository is private, installing needs read access and git credentials (`gh auth setup-git`, or SSH).
- The skills refer to each other by their bare names, which work on every channel.
- The project's `CLAUDE.md` moves to `.claude/CLAUDE.md`. Claude Code reads it there for work on this repository, and a `CLAUDE.md` at a plugin's root would look like plugin context, which it isn't (`claude plugin validate --strict` warns).
- The first release with the manifests is v0.2.0. Until it's tagged, the marketplace's `ref` names v0.1.0, which has no plugin manifests, so installing the plugin works from v0.2.0 on.
