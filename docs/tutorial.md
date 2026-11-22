# Tutorial: from an idea to a first release

This tutorial follows one small project, `revwords`, from an empty folder to its first published release, through the three gates of the idea-to-release skills: the plan, its acceptance, and working it. Every prompt and reply below comes from a real run of the Claude Code plugin `i2r`.

- **Names:** the run used `rmdesmond/revwords`. Here it's `you/revwords`, and the licence holder is `Your Name`. Use your own account and name. The install at the end ran with a throw-away home folder, shown here as `$HOME`.
- **Answers up front:** the run was headless, so each prompt gives its answers and its yeses in advance ("I confirm the dry run in advance"). Run interactively, the skills ask you instead: they show each dry run and wait for your yes, and you can leave those sentences out.
- **Replies are shortened:** `…` marks a cut. An agent words things a little differently each time, so your replies won't match exactly, but they'll have the same steps, dry runs and questions.

**The project:** `revwords` is a bash command that reverses the order of the words in each line:

```console
$ revwords one two three
three two one
$ printf 'the quick  brown fox\njumps over\n' | revwords
fox brown quick the
over jumps
```

**The steps:**

| Step | Skill | What it does |
|---|---|---|
| 1 | `idea-to-plan` | Writes the plan with you, and saves it in a new private repository |
| 2 | `accept-the-plan` | Readies the repository in one dry run, and marks the plan accepted |
| 3–5 | `work-the-plan` | Takes the tasks one at a time, then cuts the release |
| 6 | | Installs the release and uses it |

**How the skills behave.** Two habits run through every step:
- **Dry run first.** Before a skill changes anything outside your working folder, it shows a dry run: a list of every write it's about to make. It waits for your yes before anything that's hard to undo: creating the repository, changing settings or rules, tagging and publishing.
- **You merge.** The skills open pull requests, and never merge them.

## Before you start

You need:
- **Claude Code**
- **The GitHub CLI** (`gh`) 2.40 or later, signed in with `gh auth login`, with the `repo` and `workflow` scopes
- **git**, with credentials for GitHub. `gh auth setup-git` sets them up, or use an SSH key.
- **bash 3.2 or later** and `tar`: the macOS and Linux defaults
- **`shellcheck`**, for this example's lint stage

## 0. Install the plugin

```console
$ claude plugin marketplace add rmdesmond/idea-to-release
✔ Successfully added marketplace: i2r
$ claude plugin install i2r@i2r
✔ Successfully installed plugin: i2r@i2r (scope: user)
```

- **Names:** the skills are now typed with the plugin's name in front: `/i2r:idea-to-plan`, `/i2r:work-the-plan` and so on. In their own replies, the skills name each other without the prefix ("run accept-the-plan"). In Claude Code, that's `/i2r:accept-the-plan`.
- **Updates** come with releases: `claude plugin marketplace update i2r`, then `claude plugin update i2r@i2r`.
- **Other agents** (Codex, Copilot, Gemini CLI) use the release archive and its `install.sh` instead. See the README's *Installing* section.

Make an empty folder for the project, and start Claude Code there:

```sh
mkdir revwords && cd revwords && claude
```

## 1. The plan: `idea-to-plan`

**Start it** with your idea, and where the project should live. It goes through seven topics (goal, scope, constraints, release target, milestones, tasks, verification), proposing an answer for each. This run gave every answer in the prompt:

> /i2r:idea-to-plan idea="revwords: a small command-line tool that reverses the order of the words in each line of its input, read from its arguments or from standard input." owner=you repo=revwords
>
> I am running you headless, so I can't answer questions as we go. Here are my answers to your topics:
> - Goal: as in the idea, for people who script text in a shell.
> - Scope: in, the revwords command with --help and --version, reading arguments or stdin. Out, other text transforms and file arguments.
> - Constraints: bash 3.2 and standard tools only, on macOS and Linux. No deadline.
> - Release target: shell-cli, the revwords command installed into a bin folder.
> - Milestones: one, a walking skeleton, which ends in release v0.1.0.
> - Tasks: the command itself, then a test harness (tests/run.sh) with unit tests.
> - Verification: lint with shellcheck, unit tests through the harness once it exists, no build and no integration stage.
>
> Propose anything else yourself and record it under Assumptions. The description is "Reverse the order of words in each line". I confirm in advance the dry run for creating the repository.

**What it changes:** it creates a private repository on GitHub, and saves the plan there in one commit, so you can read what it understood before anything else happens:

```
The plan is saved in a new private repository: **https://github.com/you/revwords**. Its first commit is
`a928345 docs(plan): plan revwords` on `main`, and the plan passes `check-plan.sh`. The plan is a draft,
so nothing can be worked until you accept it.

**The plan** (`docs/plan/PLAN.md`)
- **M1: Walking skeleton**, ending in release v0.1.0. It has two tasks, and neither is done yet. …
  - **T-001: Add the revwords command.** It covers reading arguments or stdin, `--help`, `--version`,
    and the version entry in the config.
  - **T-002: Add the test harness and unit tests for revwords.** It depends on T-001, adds
    `tests/run.sh` and `tests/revwords_test.sh`, and turns on the `unit` stage.
- **Release target:** `shell-cli`, the `revwords` command installed into a `bin` folder.
- **Pipeline stages:**

| Stage | Enabled | Run command, or reason |
|---|---|---|
| lint | yes | `git ls-files -z 'bin/*' '*.sh' \| xargs -0 -r shellcheck` (passes on an empty repo; I checked) |
| build | no | Shell scripts run as they are; nothing to compile |
| unit | from T-002 | `tests/run.sh` (switched off until then: "not set up yet: T-002 adds it") |
| integration | no | One command with no external interfaces |
…
```

- **The plan's `Release:` line** (`M1 … ending in release v0.1.0`) is what tells `work-the-plan` to cut a release when M1's tasks are done.
- **A pending stage:** `unit` has no command until T-002 writes the test harness. Until then it's a passing placeholder, and T-002 switches it on.

**What it leaves to you:** the choices it made itself. It records them as decisions, and the one you haven't confirmed is `proposed`:

```
**Decision records**
- 0001, accepted: bash 3.2 and standard tools only, on macOS and Linux.
- 0002, accepted: no file arguments and no other text transforms.
- 0003, accepted: the command comes before its test harness. This is your task order, which differs
  from the usual rule that the test setup comes first.
- 0004, **proposed**: how words, lines and options are handled.

**Assumptions I made, which you need to confirm before T-001:**
- **Words, lines and options (record 0004):**
  - A word is a run of characters other than spaces and tabs.
  - Words come out joined by single spaces.
  - Empty lines are kept.
  - Arguments are joined into one line, like `echo`, and then stdin isn't read.
  - Options only count as the first argument, and `--` ends them.
  - An unknown option exits with status 2.
…
**Next:** review the plan in the repository. If it's not right, change it with this skill. When it is,
run **accept-the-plan**, and accept or change record 0004 before T-001 starts.
```

**Not right?** Run `/i2r:idea-to-plan` again with what to change. It revises the plan without renumbering its tasks.

## 2. Accept the plan: `accept-the-plan`

> /i2r:accept-the-plan licence=mit
>
> I am running you headless, so I can't answer as we go: use the defaults for anything not given, and I confirm the dry run in advance.

**What it asks:** for a yes on one dry run that covers the whole setup, and for your answer on each `proposed` decision record: accept it as written, or leave it proposed.

**What it changes:** everything a task needs, before any task starts:

```
I've set up the repository and opened the acceptance change request, **[PR #3](https://github.com/you/revwords/pull/3)**.
The plan becomes accepted when you merge it. I haven't merged it, as the skill requires.

**What I changed**
- **Settings:** merges are now squash-only, and a squashed commit takes the PR's title and description.
  Branches are deleted after merging, and the wiki and projects are turned off.
- **Labels:** created the 10 standard labels. GitHub's default labels are still there.
- **Files:** one setup commit pushed straight to `main`, `057894e`, which was allowed because no branch
  rules existed yet. It adds:
  - `LICENSE` (MIT, 2026 Your Name)
  - `CHANGELOG.md` and `README.md`
  …
  - decision records 0005 (licence), 0006 (private visibility), 0007 (squash merges, releases from
    `main`) and 0008 (0 required approvals while you're the only maintainer)
- **Pipeline:** added `.github/workflows/pipeline.yml`.
  - `lint` runs shellcheck.
  - `unit` is a passing placeholder until T-002 adds the tests.
  - `build` and `integration` are passing placeholders because the project doesn't need them.
  …
- **Issues:**
  - milestone M1: Walking skeleton
  - [#1](https://github.com/you/revwords/issues/1) T-001: Add the revwords command, labelled feature,
    normal priority, ready
  - [#2](https://github.com/you/revwords/issues/2) T-002: Add the test harness and unit tests for
    revwords, labelled chore, normal priority, blocked. It's linked as blocked by #1.
- **PR #3:** changes the plan's status from `draft` to `accepted 2026-11-22`. All four checks passed on
  it, `lint` included, and it closes no issue.
- **Branch rules:** the `idea-to-release` ruleset now protects `main`, with no exceptions for admins.
  - Deleting `main`, force-pushing and pushing to it directly are blocked.
  - PRs need 0 approvals.
  - lint, build, unit and integration must pass before a merge.
  …
```

- **The setup commit** is the last one that goes straight to `main`. From here on, every change comes through a pull request, and the four checks gate it.
- **Issue bodies** carry the task's *Done when* list, copied from the plan, and a `Plan-Task: T-001` line. That line is how every later step finds the task again.
- **On a private repository,** branch rules need a paid GitHub plan. This run's account had one. On a free account, GitHub refuses the rules. Then `accept-the-plan` writes a decision record that says which rules aren't enforced and what replaces them (`work-issue` never opens a red pull request, and you only merge green ones). Making the repository public, or upgrading the plan, lets a later run enforce the rules.

**A proposed record is still open.** This prompt didn't answer for decision 0004, so the skill left it alone:

```
**Left alone**
…
- Decision 0004 (word and line handling) is still `proposed`. Accepting the plan doesn't accept it,
  and you need to accept or change it before T-001 starts.
```

Run it again with your answer. Every skill checks what's already done before it acts, so a second run changes only what's left:

> /i2r:accept-the-plan licence=mit
>
> I am running you headless, so I can't answer as we go: use the defaults for anything not given, and I confirm the dry run in advance. My answer for decision record 0004: accept it as written.

```
Decision record 0004 is now accepted, and the acceptance pull request #3 is ready for you to merge.
This was a re-run: an earlier run had already done the rest of the setup, so 0004 was the only thing
left to change.

**What changed this run**
- In `docs/decisions/0004-word-and-line-handling.md`, I changed `Status: proposed` to
  `Status: accepted`, as you answered. I committed it as `docs(decisions): accept decision 0004` and
  pushed it to the open pull request's branch, `docs/accept-plan`, instead of opening a second one.
…
**Already in place, no change**
- **Plan:** it passes `check-plan.sh`, with 1 milestone ("M1: Walking skeleton"), 2 tasks, release
  v0.1.0 and target `shell-cli`. Its `Status: accepted 2026-11-22` line is in #3 and takes effect when
  you merge.
…
**Next:** merge https://github.com/you/revwords/pull/3, which accepts the plan and decision 0004. Then
run **work-the-plan**, which starts with T-001 (#1).
```

Merge #3. **Run `accept-the-plan` again whenever the plan changes**, or the pipeline, the rules, visibility or access. It changes only what differs.

## 3. The first task: `work-the-plan`

> /i2r:work-the-plan
>
> I am running you headless, so I can't answer as we go: I confirm in advance that you should take the first task you propose, and the stale-label change if there is one. Take only that one task.

**What it asks:** whether to take the next task in plan order. It refuses a plan that isn't accepted, and skips a task that depends on a decision record that's still `proposed`.

**What it changes:** it takes the task through `work-issue`: a branch, the work, every enabled stage run locally, and a pull request that closes exactly that issue. The task's *Done when* boxes are ticked in the plan, in the same pull request:

```
I took T-001 (#1) and opened **PR #4**, "feat: add the revwords command"
(https://github.com/you/revwords/pull/4). All four checks pass on CI, it merges cleanly, it closes only
#1, and no review is required. It's waiting for your merge; I haven't approved or merged it.

**Checks before starting:**
- The plan is accepted, no change request was open, and no release is due yet.
- T-001 was `ready`, and decision 0004 is now `accepted`.
- There was no stale label to change: #2 (T-002) is correctly `blocked`, since #1 is still open.

**What's in the PR:**
- **`bin/revwords`:** the command itself. It reverses the words from its arguments or, with none, from
  standard input, following decision 0004. It handles `--help`, `--version` (`revwords 0.0.0`) and
  `--`, and exits 2 on an unknown option.
- **`.project/config.yml`:** now lists `"bin/revwords:REVWORDS_VERSION="` as a version file, so the
  release can set the version.
- **The plan:** T-001's boxes are ticked.
…
**For your review:**
- `revwords --` with nothing after it reads standard input. Decision 0004 doesn't cover that case, so
  it's my choice.
…
Run work-the-plan again after you merge PR #4, and it will move on to T-002.
```

**What it leaves to you:** the review, and the choices it made where the plan was silent. Review the pull request, and merge it.

**When a check fails,** `work-issue` stops before pushing, and never opens a pull request with a failing stage. If the cause is outside its task (a wrong run command in the config, say), it won't fix it there: it says where the fix belongs. See *When a step stops* below.

## 4. The next task: `work-the-plan` again

Run the same prompt again after the merge:

> /i2r:work-the-plan
>
> I am running you headless, so I can't answer as we go: I confirm in advance that you should take the first task you propose, and the stale-label change if there is one. Take only that one task.

When T-001 merged, #2's blocker closed, but its label still said `blocked`. `work-the-plan` noticed, and with your yes moved it to `ready`. This task also switches on the pending `unit` stage:

```
I took T-002 (#2, adding the test harness and unit tests), and it's now waiting for your merge in
**PR #5**: https://github.com/you/revwords/pull/5

**Where the plan stood:** it was accepted, nothing else was waiting for review, and the v0.1.0 release
wasn't due yet because T-002 was still open. Its `blocked` label was out of date, since its only blocker
(#1) is closed, so I changed it to `ready` as you'd approved.

**What the PR adds:**
- **`tests/run.sh`:** runs every `tests/*_test.sh`. …
- **`tests/revwords_test.sh`:** 25 cases covering decision 0004: …
- **The `unit` stage is now on:** it's enabled in `.project/config.yml` with `run: tests/run.sh`, and I
  regenerated the pipeline file with the adapter's renderer.
- **The plan:** all of T-002's boxes are ticked.

**Verification:**
- On macOS bash 3.2.57, lint passes and the tests give `25 passed, 0 failed`.
- On CI (`ubuntu-latest`), all four checks pass, and the unit job's log shows `25 passed, 0 failed`. …
- When I changed one expected value on purpose, the run printed a `FAIL` line and exited 1. I reverted
  that change and didn't commit it.
- The PR closes exactly #2 and can be merged cleanly.

Once you've merged it, run `/i2r:work-the-plan` again: with every M1 task done, it will move on to the
v0.1.0 release.
```

The pipeline is generated from the `pipeline` block in `.project/config.yml`. To change a stage outside a task, change the plan's verification strategy with `idea-to-plan`, which keeps the config in step, then run `accept-the-plan`; don't edit the workflow file by hand. Merge #5.

## 5. The release: `work-the-plan` at the end of M1

With every task in M1 merged, M1's `Release: v0.1.0` line is due. `work-the-plan` runs `cut-release`, and first offers `write-tutorial`, for a project that should ship a tutorial of its own. This run said no with `tutorial=no`:

> /i2r:work-the-plan tutorial=no
>
> I am running you headless, so I can't answer as we go. If a release is due, I confirm in advance each step cut-release asks me to confirm: the release change request, creating the tag, and publishing. Stop wherever it needs my merge.

**Run 1: the release pull request.** It works out the version and the changelog from the pull requests merged since the last release, and the plan tasks they delivered:

```
Release v0.1.0 is due, and its release change request is open: **#6 `chore(release): v0.1.0`**
(https://github.com/you/revwords/pull/6). It needs your merge before the release can go on.
…
**What the release change request contains**
- **`CHANGELOG.md`:** a new `## [0.1.0] - 2026-11-22` section with one entry under Added: "Add the
  revwords command (#4)". It also gets a link to the release page. #3 is a docs change and #5 is a test
  change, so neither goes in the changelog.
- **`bin/revwords`:** the version goes from `REVWORDS_VERSION="0.0.0"` to `"0.1.0"`.
- **Checks:** lint, build, unit and integration all pass on the change request. …
…
After you merge #6, run `/i2r:work-the-plan` again. That run will tag `v0.1.0` on the merge commit,
wait for the release stages to pass on the tag, build and check the archive, draft the release, and
publish it. You've already said yes to the tag and the publish. It will stop if the merge commit isn't
the newest commit on `main`, or if a release check fails.
```

- **The version** comes from the pull request titles: a `feat` raises the minor version, a `fix` the patch.
- **The changelog** is written from those titles too. So write a pull request's title as you'd want it in the changelog.

Merge #6, then:

> /i2r:work-the-plan tutorial=no
>
> I am running you headless, so I can't answer as we go. I confirm in advance each step cut-release asks me to confirm: creating the tag, and publishing the release.

**Run 2: the tag and the release.** Run interactively, it shows a dry run of the tag and asks first, then asks again before it publishes. Tags are permanent: if a release check fails after the tag, the fix goes out as a patch release.

```
I published v0.1.0, and with it the plan is complete.

**Release:** https://github.com/you/revwords/releases/tag/v0.1.0
- **Tag:** `v0.1.0` on `3199d43`, the merge commit of the release change request (#6). The checks
  passed on that commit before tagging and on the tag afterwards (lint doesn't run on tags or merges).
- **Asset:** `revwords-v0.1.0.tar.gz` (3046 bytes). The install check on it passed all 9 checks. It
  only covers installing, because the project has no `tests/smoke.sh`.
- **Published** at 2026-11-22 18:09 UTC, and it's marked as the latest release.
- **Tasks delivered (M1: Walking skeleton):**
  - T-001: Add the revwords command (issue #1, change request #4)
  - T-002: Add the test harness and unit tests for revwords (issue #2, change request #5)
- **Changelog:** Added "Add the revwords command (#4)".
…
**Plan status:** M1 is the only milestone. Both its tasks are done and its release line, v0.1.0, has
its tag and a published release.
…
What comes next is up to you. To start a new milestone, run **idea-to-plan** in revise mode, then
**accept-the-plan**.
```

## 6. Install and use the release

The release notes list the plan tasks it delivered, the changelog section, and how to install it. The archive has its own `README.md`, with the same install steps and the command's `--help`. Installed from the archive:

```console
$ tar -xzf revwords-v0.1.0.tar.gz && cd revwords-v0.1.0 && ./install.sh
Installed revwords v0.1.0 in $HOME/.local/bin: revwords
Note: $HOME/.local/bin isn't on your PATH. Add it, for example: export PATH="$HOME/.local/bin:$PATH"
```

Then, with it on your `PATH`:

```console
$ revwords one two three
three two one
$ printf 'the quick  brown fox\njumps over\n' | revwords
fox brown quick the
over jumps
$ revwords --version
revwords 0.1.0
```

A wrong option says what to do, and exits with status 2:

```console
$ revwords -x
revwords: unknown option: -x
Try 'revwords --help' for more information.
```

## What's next: the next feature

After the first release, every change goes through the same gates:

1. `/i2r:idea-to-plan` with what you want to change. In *revise* mode, it adds milestones and tasks without renumbering the old ones, and proposes the revised plan as a pull request. If the change contradicts the plan's scope, it says so, and records the reversal in a decision record.
2. `/i2r:accept-the-plan` accepts the revision, and creates the new issues.
3. `/i2r:work-the-plan`, after each merge, until the next milestone's release is published.

`work-issue` also works alone, for a single issue: `/i2r:work-issue issue=12`.

## When a step stops

The skills stop rather than guess, and say why. The common cases:

| It says | Why | What to do |
|---|---|---|
| The plan isn't accepted | `work-the-plan` only works an accepted plan | Run `accept-the-plan`, and merge its pull request |
| A task waits on a decision record | The record is still `proposed` | Answer it in `accept-the-plan`, or change it through `idea-to-plan` |
| A change request is open | It takes one task at a time | Review and merge it, then run `work-the-plan` again |
| A stage fails locally, and the cause isn't the task's code | A run command or the config is wrong | Fix it through `idea-to-plan`, which changes the plan and the config together, then `accept-the-plan`, and carry on |
| A stage fails because of the task's code | The work isn't finished | Let `work-issue` fix it. It doesn't open a red pull request |
| `check-plan.sh` fails | The plan's format is broken | Fix the plan through `idea-to-plan` |
| GitHub refuses the branch rules | A private repository on a free plan | `accept-the-plan` records the gap in a decision record. Go public or upgrade to enforce them |
| `main` moved after the release pull request | Something merged in between | `cut-release` asks: prepare again, or tag the release commit itself |
| A release check fails on the tag | The tag's build or tests fail | Fix it in a new pull request, then cut a patch release. Tags are never moved |

You can stop at any confirmation and come back later. Every skill checks what's already done before it acts, so running it again is safe.

## See also

- `README.md`: installing, and how the skills fit together
- `conventions.md`: the rules the skills follow (labels, branches, commits, releases, safety)
- `skills/<name>/SKILL.md`: each skill's full procedure
- `docs/decisions/`: why things are the way they are

Outputs from a run of e81b79e (2026-11-22) and a recorded run from 2026-11-22.
