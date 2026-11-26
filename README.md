# idea-to-release

Agent skills that take a software project from a rough idea to an official release, and keep a record of how it got there.

The skills cover planning, repository setup, CI, branch rules, issues, day-to-day issue work, tutorials and releases. They share one set of conventions, so each step links to the one before it: plan → issues → change requests → release notes.

## Why

Plenty of individual skills exist for creating a repo, turning a plan into issues, or cutting a release. They don't share conventions, so nothing ties the plan to the tickets to the release. This set is built around that chain:

- **Fast:** an agent can do the routine work of setup, ticketing and releasing, with a person confirming the steps that matter.
- **Traceable:** every task has a permanent ID that follows it from the plan to the release that shipped it.
- **Portable:** the plan, decision records and changelog are plain files in the repository, and each squash-merged commit keeps its issue reference, so the trail from task to release survives a change of forge or tracker.

## How it fits together

Three gates take a project from an idea to its releases, each one a skill:

```
idea ──► idea-to-plan ──────► accept-the-plan ─────────► work-the-plan ──────────► releases
         a draft plan,        setup, CI, issues,         each task through          at each Release:
         saved in a new       branch rules; the plan     work-issue, one change     milestone, through
         private repository   is marked accepted         request at a time          cut-release
```

1. **The plan is the first gate.** `idea-to-plan` writes it with you, and saves it in a private repository straight away, so you can check that what you asked for is what was understood.
2. **Accepting it is the second.** `accept-the-plan` readies the repository in one dry run: the standard setup, a pipeline where every check already exists (a passing placeholder until a task sets it up), the issues, and branch rules that require the checks. No task is worked before all of that is in place.
3. **Working it is the third.** `work-the-plan` takes the tasks in plan order, stops at each change request for your merge, and cuts a release when a milestone that ends in one is done.

A task's ID links each step to the next: plan → issue → change request → release notes, with decision records along the way. A changed plan goes back through the first two gates.

| Stage | Skill | What it does |
|---|---|---|
| Idea → plan | `idea-to-plan` | Turns an idea into a plan with milestones, tasks and a verification strategy, saved in a new private repository (or a change request to an existing one) |
| Plan → ready repository | `accept-the-plan` | Accepts the plan, and readies its repository in one dry run: settings, labels and standard files, the pipeline (a passing placeholder for each stage a task will set up), the milestones and issues, and branch rules that require the core checks |
| Accepted plan → releases | `work-the-plan` | Works an accepted plan task by task in plan order through `work-issue`, stopping at each change request for your merge, and runs `cut-release` at each milestone with a `Release:` line |
| Issues → changes | `work-issue` | Takes a ready issue through branch, commits, tests and change request. Used by `work-the-plan`, or alone for a single issue |
| Tutorial | `write-tutorial` | Optional. Writes `docs/tutorial.md`, a worked example whose every command and output comes from a real run. Run it before a release that should ship one |
| Changes → release | `cut-release` | Derives the version, writes the changelog and release notes, tags and publishes |

## Design principles

- **Forge-agnostic.** Skills are written in neutral terms ("open a change request", "protect the default branch"). Adapters translate those into commands for a specific forge or tracker. There are GitHub adapters today. Others can be added without touching the skills.
- **One set of conventions.** Labels, branch names, commit style, the plan format and traceability are defined once in [`conventions.md`](conventions.md), and every skill follows it.
- **The repository is the record.** The plan and decision records are files in the repo. Which release shipped each task is read from the issues, change requests and tags, not stored a second time.
- **Same pipeline shape everywhere.** Every project has the same four core stages. A stage a project doesn't need stays in place as a no-op that states why, so it can be switched on later without changing branch rules.
- **Tests are part of the task.** A task's tests ship in the same change request as the work.
- **People confirm what can't be undone.** Reads run freely, writes are announced, and admin actions (creating a repo, changing access, merging, publishing) show a dry run and wait for confirmation.

## Repository layout

```
skills/              # one folder per skill, each with a SKILL.md
adapters/
  forge/             # one file per forge: github.md
  tracker/           # one file per tracker
  target/            # one file per release target: how a project's releases are packaged and installed
conventions.md       # shared rules every skill reads first
.claude-plugin/      # plugin.json and marketplace.json: the Claude Code plugin i2r
docs/
  tutorial.md        # from an idea to a first release, step by step
  plan/PLAN.md       # the plan for this project
  decisions/         # decision records
.project/
  config.yml         # this project's forge, tracker and pipeline choices
CHANGELOG.md
```

This repository is built with its own skills and follows its own conventions, so it doubles as a worked example.

## Installing

The skills use the open [Agent Skills](https://agentskills.io) format, so any agent that reads `SKILL.md` folders can load them. They're developed and tested with Claude Code.

New to the skills? [The tutorial](docs/tutorial.md) takes a small project from an idea to its first release, one skill at a time, with the prompts and replies from a real run.

### Claude Code: the plugin `i2r`

The repository is also a Claude Code plugin marketplace:

```sh
claude plugin marketplace add rmdesmond/idea-to-release
claude plugin install i2r@i2r
```

The skills are then typed with the plugin's name in front: `/i2r:idea-to-plan`, `/i2r:work-issue` and so on. The short name saves typing ([decision 0019](docs/decisions/0019-claude-code-plugin-i2r.md)). Plugin skills are namespaced, so they never clash with skills of the same name. The plugin follows releases: to update, run `claude plugin marketplace update i2r`, then `claude plugin update i2r@i2r`.

In the skills' own text, they name each other without the prefix ("then run `accept-the-plan`"). In Claude Code, that's `/i2r:accept-the-plan`.

### Any agent: the archive and `install.sh`

Each [release](https://github.com/rmdesmond/idea-to-release/releases) has an archive, `idea-to-release-<version>.tar.gz`, with an install script and its own `README.md`: the version, what it is, how to install it, and the skills and how to run them:

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

**What's installed.** Each skill goes in its own folder: `idea-to-plan`, `accept-the-plan`, `work-the-plan`, `work-issue`, `write-tutorial` and `cut-release`. Beside them, `idea-to-release/` holds the files they share: `conventions.md`, the adapters and the check scripts. It has no `SKILL.md`, so it isn't loaded as a skill ([decision 0014](docs/decisions/0014-installed-shared-files.md)). Running the script again replaces an earlier install.

**Name clashes.** An agent loads only one skill of a given name, without a warning. In Claude Code, a personal skill wins over a project skill. So `install.sh` never replaces a folder it didn't install, and it stops if one of your personal skills has the same name as one of these. `--force` installs anyway, with a warning ([decision 0015](docs/decisions/0015-skill-name-clashes.md)).

**From a clone,** to try unreleased changes, build the archive yourself:

```sh
git clone https://github.com/rmdesmond/idea-to-release.git && cd idea-to-release
adapters/target/agent-skills/build.sh v0.0.0 /tmp/idea-to-release   # prints the archive's path
```

**Requirements**

- An agent that reads Agent Skills
- bash 3.2 or later, `tar`, `git`: the macOS and Linux defaults
- For the GitHub adapters: the `gh` CLI 2.40 or later, signed in with the `repo` scope (and `workflow` for `accept-the-plan`, which writes the pipeline)

Start with `idea-to-plan`, for a new idea or an existing repository, then `accept-the-plan`, then `work-the-plan` after each merge.

**A note on permissions.** These skills run commands with your credentials and can change repository settings, access and releases. Read a skill and its adapter before running it, and review the dry run before confirming any admin action.

## Status

Early: expect the conventions to change between minor versions until 1.0. There are GitHub forge and tracker adapters, and three release targets: `agent-skills` (this repository), `shell-cli` (command-line scripts) and `cmake-binary` (compiled command-line tools built with CMake).

- **Released:** the [releases](https://github.com/rmdesmond/idea-to-release/releases), and what each one changed in [`CHANGELOG.md`](CHANGELOG.md)
- **Next:** the plan, [`docs/plan/PLAN.md`](docs/plan/PLAN.md), with one issue per task in this repository's milestones
- **Why things are the way they are:** the [decision records](docs/decisions/)

## Contributing

Issues with ideas, gaps or corrections are welcome, and so are change requests for an existing issue.

Changes follow [`conventions.md`](conventions.md): one issue per change request, Conventional Commits, and tests included with the change. A new forge or tracker adapter must define every neutral verb or state its fallback.

### How `main` is protected

The repository is public ([decision 0025](docs/decisions/0025-public-repository.md)), and GitHub enforces its rules on `main` ([decision 0017](docs/decisions/0017-branch-rules-enforced.md)):

- Nobody pushes to `main`, the maintainer included. Every change arrives through a pull request, and force pushes and deletion are blocked.
- A pull request can be merged only when `lint`, `build`, `unit` and `integration` pass. `shellcheck` runs too, as an advisory check.
- No approval is required while there's a single maintainer: the maintainer's merge is the review ([decision 0011](docs/decisions/0011-review-rule-single-maintainer.md)). Agents open pull requests but never approve, merge or override a check.

## Licence

MIT. See [`LICENSE`](LICENSE). The choice is recorded in [`docs/decisions/0002-licence-mit.md`](docs/decisions/0002-licence-mit.md).
