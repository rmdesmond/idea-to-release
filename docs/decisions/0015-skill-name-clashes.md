# 0015: Avoid and detect skill name clashes

Date: 2026-11-21
Status: accepted

## Context

Skills installed into a project's or a user's skills folder aren't namespaced. When two skills have the same `name`, an agent loads only one, and it doesn't warn.

In Claude Code, enterprise skills win over personal skills, and personal skills win over project skills. A skill can also replace a built-in command or bundled skill of the same name. Only plugin skills are namespaced (`/plugin:skill`). Source: the Claude Code skills documentation, "Resolve skills that share a name".

So someone with a personal skill called `release` would silently get theirs instead of this set's when installing into a project. A future built-in command of the same name would have the same effect. Other agents have their own rules.

The skill set's names: `idea-to-plan`, `repo-bootstrap`, `plan-to-issues`, `work-issue`, `ci-setup`, `repo-governance` and `release`. Only `release` is a generic word.

## Decision

- **Rename `release` to `cut-release`,** before the first release, while nothing depends on the name. The other names are specific enough to keep.
- **`install.sh` never replaces a folder it didn't install.** An earlier install is recognised by `idea-to-release/VERSION` beside it. `--force` doesn't change this.
- **For a project install, `install.sh` also checks the agent's personal skills folder.** If a same-named skill there would hide one of these, it stops and names it. `--force` installs anyway, with a warning.
- **A Claude Code plugin,** whose skills are namespaced, is a later install channel (#82).

## Consequences

- A clash is reported when installing, not discovered later when the wrong skill runs.
- `install.sh` can't see every place a skill might come from: enterprise settings, another tool's plugin, or a future built-in command. Those clashes remain possible, and the plugin channel is the complete fix for Claude Code.
- Decision records written before this one, and the plan task T-024, still call the skill `release`. They describe what was decided at the time.
