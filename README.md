# idea-to-release

Agent skills that take a software project from a rough idea to an official release, and keep a record of how it got there.

The skills cover planning, repository setup, access and branch rules, ticket creation, day-to-day issue work, CI, and releases. They share one set of conventions, so each step links to the one before it: plan → issues → change requests → release notes.

> **Status: first release.** [v0.1.0](https://github.com/rmdesmond/idea-to-release/releases/tag/v0.1.0) has all seven skills, the GitHub adapters and the `agent-skills` and `shell-cli` targets. It's early: expect the conventions to change between minor versions until 1.0.

## Why

Plenty of individual skills exist for creating a repo, turning a plan into issues, or cutting a release. They don't share conventions, so nothing ties the plan to the tickets to the release. This set is built around that chain:

- **Fast:** an agent can do the routine work of setup, ticketing and releasing, with a person confirming the steps that matter.
- **Traceable:** every task has a permanent ID that follows it from the plan to the release that shipped it.
- **Portable:** the history lives in the repository as plain files, so it survives a change of forge or tracker.

## How it fits together

```
idea ──► plan ──► repository ──► issues ──► change requests ──► release
          │           │             │              │               │
          └───────────┴─────────────┴──── ledger ──┴───────────────┘
                         decision records along the way
```

| Stage | Skill | What it does |
|---|---|---|
| Idea → plan | `idea-to-plan` | Turns an idea into a plan with milestones, tasks and a verification strategy |
| Plan → repository | `repo-bootstrap` | Creates or adopts the repository: settings, standard labels and standard files (README, licence, `.gitignore`, templates, project config) |
| Plan → issues | `plan-to-issues` | Creates milestones and dependency-ordered issues from the plan |
| Issues → changes | `work-issue` | Takes a ready issue through branch, commits, tests and change request |
| Checks | `ci-setup` | Renders the pipeline: lint, build, unit and integration stages, plus any extras |
| Repository rules | `repo-governance` | Sets visibility, access, branch rules, required checks and review requirements. Runs after `ci-setup`, so required checks can name real pipeline stages |
| Changes → release | `cut-release` | Derives the version, writes the changelog and release notes, tags and publishes |

## Design principles

- **Forge-agnostic.** Skills are written in neutral terms ("open a change request", "protect the default branch"). Adapters translate those into commands for a specific forge or tracker. GitHub is the first adapter; others can be added without touching the skills.
- **One set of conventions.** Labels, branch names, commit style, the plan format and the ledger are defined once in [`conventions.md`](conventions.md), and every skill follows it.
- **The repository is the record.** The plan, decision records and a ledger mapping tasks to issues, change requests and releases are files in the repo.
- **Same pipeline shape everywhere.** Every project has the same four core stages. A stage a project doesn't need stays in place as a no-op that states why, so it can be switched on later without changing branch rules.
- **Tests are part of the task.** A task's tests ship in the same change request as the work.
- **People confirm what can't be undone.** Reads run freely, writes are announced, and admin actions (creating a repo, changing access, merging, publishing) show a dry run and wait for confirmation.

## Repository layout

```
skills/              # one folder per skill, each with a SKILL.md
adapters/
  forge/             # one file per forge (github.md first)
  tracker/           # one file per tracker
  target/            # one file per release target: how a project's releases are packaged and installed
conventions.md       # shared rules every skill reads first
docs/
  plan/PLAN.md       # the plan for this project
  decisions/         # decision records
.project/
  config.yml         # this project's forge, tracker and pipeline choices
  ledger.yml         # task → issue → change request → release
CHANGELOG.md
```

This repository is built with its own skills and follows its own conventions, so it doubles as a worked example.

## Installing

The skills use the open [Agent Skills](https://agentskills.io) format, so any agent that reads `SKILL.md` folders can load them. They're developed and tested with Claude Code. Each [release](https://github.com/rmdesmond/idea-to-release/releases) has an archive, `idea-to-release-<version>.tar.gz`, with an install script:

```sh
tar -xzf idea-to-release-<version>.tar.gz
cd idea-to-release-<version>
./install.sh --agent claude --project /path/to/your/project   # or --user, for every project
```

| Agent | `--agent` | Project folder | Personal folder (`--user`) |
|---|---|---|---|
| Claude Code | `claude` | `.claude/skills` | `~/.claude/skills` |
| OpenAI Codex | `codex` | `.agents/skills` | `~/.agents/skills` |
| GitHub Copilot | `copilot` | `.github/skills` | `~/.copilot/skills` |
| Gemini CLI | `gemini` | `.gemini/skills` | `~/.gemini/skills` |
| Any other | `--dest DIR` | the folder it reads skills from | |

**What's installed.** Each skill goes in its own folder: `idea-to-plan`, `repo-bootstrap`, `plan-to-issues`, `work-issue`, `ci-setup`, `repo-governance` and `cut-release`. Beside them, `idea-to-release/` holds the files they share: `conventions.md`, the adapters and the check scripts. It has no `SKILL.md`, so it isn't loaded as a skill ([decision 0014](docs/decisions/0014-installed-shared-files.md)). Running the script again replaces an earlier install.

**Name clashes.** An agent loads only one skill of a given name, without a warning. In Claude Code, a personal skill wins over a project skill. So `install.sh` never replaces a folder it didn't install, and it stops if one of your personal skills has the same name as one of these. `--force` installs anyway, with a warning ([decision 0015](docs/decisions/0015-skill-name-clashes.md)).

**From a clone,** before the first release or to try unreleased changes, build the archive yourself:

```sh
git clone https://github.com/rmdesmond/idea-to-release.git && cd idea-to-release
adapters/target/agent-skills/build.sh v0.0.0 /tmp/idea-to-release   # prints the archive's path
```

**Requirements**

- An agent that reads Agent Skills
- bash 3.2 or later, `tar`, `git`: the macOS and Linux defaults
- For the GitHub adapters: the `gh` CLI 2.40 or later, signed in with the `repo` scope (and `workflow` for `ci-setup`)

Start with `idea-to-plan` for a new idea, or with `repo-bootstrap` to adopt an existing repository.

**A note on permissions.** These skills run commands with your credentials and can change repository settings, access and releases. Read a skill and its adapter before running it, and review the dry run before confirming any admin action.

## Roadmap

1. `conventions.md`: done
2. GitHub forge and tracker adapters: done, every verb implemented except `cr.merge`, which is left to the maintainer
3. `repo-bootstrap`: done, and used on this repository
4. `idea-to-plan`: done, and used to write this repository's plan
5. `plan-to-issues`: done, and used for this repository's issues
6. `work-issue`: done, and used for this repository's tasks
7. `ci-setup`: done, and used for this repository's pipeline
8. `repo-governance`: done, and used on this repository (branch rules kept by procedure while it's private)
9. Target adapters and `cut-release`: done, with the `agent-skills` and `shell-cli` targets
10. First tagged release of the skill set: done, [v0.1.0](https://github.com/rmdesmond/idea-to-release/releases/tag/v0.1.0), cut with `cut-release`
11. Making the repository public, with branch rules enforced: next

The order follows the idea-to-release flow, and each skill is used on this repository once it works. It may change as building the early skills exposes gaps; [decision 0005](docs/decisions/0005-roadmap-order.md) explains the current order. Progress is tracked in this repository's issues and milestones.

## Contributing

Contributions are welcome once the first release is out. Until then, issues with ideas, gaps or corrections are the most useful input.

Changes follow [`conventions.md`](conventions.md): one issue per change request, Conventional Commits, and tests included with the change. A new forge or tracker adapter must define every neutral verb or state its fallback.

### How `main` is protected

While this repository is private on a free GitHub account, GitHub can't enforce branch rules, so they're kept by procedure ([decision 0012](docs/decisions/0012-branch-rules-fallback.md)):

- Nobody pushes to `main`. Every change arrives through a pull request.
- The pipeline runs `lint`, `build`, `unit` and `integration` on every pull request, plus an advisory `shellcheck`. A pull request is merged only when the four core checks pass.
- Only the maintainer merges. Agents open pull requests but never approve, merge or override a check.

Once the repository is public, `repo-governance` turns these into enforced rules: protected `main`, required checks, and the review rule from [decision 0011](docs/decisions/0011-review-rule-single-maintainer.md).

## Licence

MIT. See [`LICENSE`](LICENSE). The choice is recorded in [`docs/decisions/0002-licence-mit.md`](docs/decisions/0002-licence-mit.md).
