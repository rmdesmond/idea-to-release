# 0024: No Agent Plugins package

Date: 2026-11-26
Status: accepted

## Context

Decision 0019 left packaging for other agents' plugin formats (Agent Plugins, for Cursor, Copilot and Codex) for a later release. The plan carried it as out of scope in v0.2.0 and v0.3.0, "tracked in its own issue" (#102), but no such issue exists, and no milestone plans it.

## Decision

- The Agent Plugins package isn't planned. It's removed from the plan's scope, and from the `agent-skills` target's notes.
- This supersedes only 0019's line leaving it for a later release. The rest of 0019 stands.
- Other agents keep `install.sh`, which puts the skills where each agent looks (decision 0014).

## Consequences

- Claude Code users install the plugin `i2r`, and everyone else uses the release archive and `install.sh`.
- Picking it up later takes a new plan revision and a decision record that supersedes this one.
