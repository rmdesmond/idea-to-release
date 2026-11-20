# idea-to-release

Agent skills that take a software project from a rough idea to an official release, and keep a record of how it got there.

The skills cover planning, repository setup, access and branch rules, ticket creation, day-to-day issue work, CI, and releases. They share one set of conventions, so each step links to the one before it: plan → issues → change requests → release notes.

> **Status: early development.** The conventions are drafted and the skills are being built in the order shown under [Roadmap](#roadmap). Nothing here is ready for production use yet.

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
| Plan → repository | `repo-bootstrap` | Creates the repository and its standard files (README, licence, `.gitignore`, templates, project config) |
| Repository rules | `repo-governance` | Sets visibility, access, branch rules and review requirements |
| Plan → issues | `plan-to-issues` | Creates labels, milestones and dependency-ordered issues from the plan |
| Issues → changes | `work-issue` | Takes a ready issue through branch, commits, tests and change request |
| Checks | `ci-setup` | Renders the pipeline: lint, build, unit and integration stages, plus any extras |
| Changes → release | `release` | Derives the version, writes the changelog and release notes, tags and publishes |

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

## Using the skills

Installation instructions will be added with the first release.

Until then, the skills can be tried by copying a skill folder, the `adapters/` folder and `conventions.md` into a project's `.claude/skills/` directory. Expect breaking changes.

**Requirements**

- An agent that supports the Agent Skills format (developed and tested with Claude Code)
- `git`
- For the GitHub adapter: the `gh` CLI, signed in with permission to create repositories and manage their settings

**A note on permissions.** These skills run commands with your credentials and can change repository settings, access and releases. Read a skill and its adapter before running it, and review the dry run before confirming any admin action.

## Roadmap

1. `conventions.md` — drafted
2. GitHub forge and tracker adapters
3. `repo-bootstrap`
4. `plan-to-issues`
5. `idea-to-plan`
6. `work-issue`
7. `repo-governance`
8. `ci-setup`
9. `release`
10. First tagged release of the skill set

The order may change as building the early skills exposes gaps. Progress is tracked in this repository's issues and milestones.

## Contributing

Contributions are welcome once the first release is out. Until then, issues with ideas, gaps or corrections are the most useful input.

Changes follow [`conventions.md`](conventions.md): one issue per change request, Conventional Commits, and tests included with the change. A new forge or tracker adapter must define every neutral verb or state its fallback.

## Licence

MIT. See [`LICENSE`](LICENSE). The choice is recorded in [`docs/decisions/0002-licence-mit.md`](docs/decisions/0002-licence-mit.md).
