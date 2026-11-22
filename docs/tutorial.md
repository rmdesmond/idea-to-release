# Tutorial: from an idea to a first release

This tutorial follows one small project, `dedupe`, from an empty folder to its first published release, using the idea-to-release skills in the order you'd use them. Every prompt and reply below comes from a real run of the Claude Code plugin `i2r`.

- **Names:** the run used `rmdesmond/dedupe`. Here it's `you/dedupe`, and the licence holder is `Your Name`. Use your own account and name. The install at the end ran with a throw-away home folder, shown here as `$HOME`.
- **Replies are shortened:** `…` marks a cut. An agent words things a little differently each time, so your replies won't match exactly, but they'll have the same steps, dry runs and questions.

**The project:** `dedupe` is a bash command that removes repeated lines and keeps the first copy of each, in their original order:

```console
$ printf 'b\na\nb\nA\n' | dedupe
b
a
A
$ printf 'b\na\nb\nA\n' | dedupe --ignore-case
b
a
```

**The steps:**

| Step | Skill | What it does |
|---|---|---|
| 1 | `idea-to-plan` | Interviews you and writes the plan |
| 2 | `repo-bootstrap` | Creates the repository and its standard files |
| 3 | `plan-to-issues` | Turns the plan into milestones and issues |
| 4 | `work-issue` | Takes the first task to a pull request |
| 5 | `ci-setup` | Adds CI that runs the plan's checks |
| 6 | `repo-governance` | Protects `main` with branch rules |
| 7 | `work-issue` | Takes the remaining tasks |
| 8 | `cut-release` | Tags, packages and publishes the release |

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

- **Names:** the skills are now typed with the plugin's name in front: `/i2r:idea-to-plan`, `/i2r:work-issue` and so on. In their own replies, the skills name each other without the prefix ("run plan-to-issues next"). In Claude Code, that's `/i2r:plan-to-issues`.
- **Updates** come with releases: `claude plugin marketplace update i2r`, then `claude plugin update i2r@i2r`.
- **Other agents** (Codex, Copilot, Gemini CLI) use the release archive and its `install.sh` instead. See the README's *Installing* section.

Make an empty folder for the project, and start Claude Code there:

```sh
mkdir dedupe && cd dedupe && claude
```

## 1. Plan: `idea-to-plan`

**Start it** with your idea, in as much or as little detail as you have:

> /i2r:idea-to-plan My idea: dedupe, a tiny command-line tool in bash that removes repeated lines from its input and keeps the first time each line appears, in order (unlike sort -u, it doesn't reorder). It reads files named as arguments, or stdin when there are none. An --ignore-case option treats lines that differ only in case as the same. Keep it to one milestone with at most three tasks. It lives on GitHub as you/dedupe, private, MIT. Installed with an install.sh into ~/.local/bin.

**What it asks.** It looks at the folder first:

```
- **The directory is empty.** It isn't a git repository yet and has no `.project/config.yml`. I'd
  suggest running `/i2r:repo-bootstrap` first, since it creates `you/dedupe` (private, MIT) and
  writes the config. I can still write the plan now, but until the config exists I can't update its
  `pipeline` block or open a change request.
…
I'll go through the seven planning topics one at a time. Here's the first.
```

> The goal is right. Plan now; I'll run repo-bootstrap after. Next topic.

It goes through seven topics, one at a time, proposing an answer for each and waiting for you to confirm or change it:

1. **Goal**
2. **Scope**: what's in, and what's explicitly out
3. **Constraints**: language, versions, hosting, licence
4. **Release target**: how a release is packaged and installed
5. **Milestones**
6. **Tasks**: each with a *Done when* checklist and its dependencies
7. **Verification strategy**: test levels, and the command for each pipeline stage

It raises the decisions you might not have thought about. From the scope topic:

```
Does that match what you want? In particular, are you happy with two choices:
- repeats are removed across all the files together, not file by file
- `--ignore-case` keeps the first copy's original case
```

> Yes to both. Scope confirmed; next topic.

From the constraints topic:

```
Does that work for you? I especially want to check two things:
- Is bash 3.2 compatibility (stock macOS) a requirement?
- Is using `awk` inside the script OK, or do you want pure bash?
```

> Bash 3.2 is required, and awk is fine. No deadline. Next topic.

From the release-target topic:

```
Target: `shell-cli` - a `dedupe` command, installed into `~/.local/bin` by the release archive's `install.sh`

The skill set's `shell-cli` adapter fits what you described:
- Each release ships `dedupe-<version>.tar.gz`, containing `bin/dedupe`, `install.sh`, `VERSION`,
  `LICENSE` and `README.md`.
- The adapter supplies `install.sh` itself. It installs into `~/.local/bin` by default, and `--prefix`
  changes the location. …
- So the project doesn't need to write its own `install.sh`, and no task is needed for that.
- The project should also provide a `tests/smoke.sh`. The adapter runs it against the installed
  command when verifying a release, and I'd make it part of the integration task.
```

The tasks it proposed, each with a *Done when* list:

```
**T-001: Set up the test runner and lint**
Depends on: none
…
**T-002: Add the dedupe command**
Depends on: T-001
…
- [ ] `--help` prints usage. `--version` prints `dedupe <version>` from a `DEDUPE_VERSION=` line, and
  `.project/config.yml` gets `release.version_files: ["bin/dedupe:DEDUPE_VERSION="]`
- [ ] Unit tests in `tests/unit/dedupe_test.sh` cover each item above

**T-003: Add the install smoke test and integration tests**
Depends on: T-002
…
```

And the verification strategy:

```
| Stage | Enabled | Run command, or reason if disabled |
|---|---|---|
| lint | yes | `shellcheck $(git ls-files 'bin/*' '*.sh')` |
| build | no | Bash scripts run as they are; there's nothing to compile, and the `shell-cli` target packages the release |
| unit | yes | `tests/run.sh unit` |
| integration | yes | `tests/run.sh integration` |
…
**When each command starts passing:**
- The lint command uses `git ls-files` instead of fixed paths. It lints whatever shell files exist,
  so it passes from T-001 on, before `bin/dedupe` exists.
- `tests/run.sh` is created in T-001. Both test commands pass from then on, and the integration suite
  reports "no tests" until T-003.
```

> Confirmed.

**What it changes:** only files in your folder:

```
I've written the plan to `docs/plan/PLAN.md`, and `check-plan.sh` passes it: 1 milestone, 3 tasks.
Nothing is committed yet, because the directory isn't a git repository and has no
`.project/config.yml`. …
**Decision record**
- `docs/decisions/0001-bash-3-2-with-awk.md` (accepted): the script must run on bash 3.2 and uses
  `awk`. It also records that `--ignore-case` only works reliably for plain ASCII letters.
…
**Next steps:**
1. Run `/i2r:repo-bootstrap` to create `you/dedupe` (private, MIT). It should pick up the two files
   already here.
…
```

## 2. Create the repository: `repo-bootstrap`

> /i2r:repo-bootstrap Create you/dedupe: private, MIT licence, description 'Remove repeated lines, keeping the first'. Use the stage settings the plan's verification strategy gives.

**What it asks:** nothing up front. It reads the plan, checks the forge, and shows a dry run, grouped by how much each change matters:

```
Mode: create   Repository: you/dedupe (private)

Admin (needs your confirmation):
  repo.create     gh repo create you/dedupe --private
                  --description "Remove repeated lines, keeping the first"
                  (created empty, then remote origin = git@github.com:you/dedupe.git)
  repo.configure  merge methods: GitHub default (squash, merge, rebase) → squash only
                  squash commit message → PR title + description
                  delete branch on merge: off → on
                  wiki: on → off      projects: on → off      issues: on (kept)
Write:
  local git       git init -b main (this folder isn't a git repo yet)
  label.ensure    create 10 labels (type:*, priority:*, ready, blocked, needs-decision); 0 present; 0 differ
  files           create .project/config.yml, CHANGELOG.md, LICENSE (MIT, 2026 Your Name),
                  .gitignore (OS/editor block only), README.md,
                  .github/pull_request_template.md, .github/ISSUE_TEMPLATE/task.md
                  keep docs/plan/PLAN.md (exists)
  decisions       keep 0001-bash-3-2-with-awk.md
                  create 0002-licence-mit.md, 0003-visibility-private.md,
                         0004-merge-strategy.md, 0005-review-rule.md
  commit          "chore: bootstrap repository" directly on main, pushed
                  (create mode only: the repo has no history yet)
```

It also says which defaults it chose for what you didn't specify, and why:

```
- `review: {required_approvals: 0, code_owners: false}`. On a new repo you're the only person who can
  write, and GitHub never counts an author's own approval, so 1 would block every merge. The core
  checks gate merges, and your merge counts as the review. …
```

> Yes, go ahead with all of it.

**What it changes:**
- **On GitHub:** it creates the repository, its settings and the 10 labels.
- **In the repository:** the files listed above, in one commit pushed to `main`. That's the only commit that ever goes straight to `main`; everything after it goes through a pull request.

The plan and the stage settings go in with that first commit:

```
- `.project/config.yml`:
  - `target: shell-cli` and `required_approvals: 0`.
  - The pipeline comes from the plan's verification strategy: lint, unit and integration are enabled
    with the plan's commands, and build is disabled with the plan's reason.
…
**Not changed:** `docs/plan/PLAN.md` and `docs/decisions/0001-bash-3-2-with-awk.md` already existed
and went into the first commit as they were. The plan check passes on it (1 milestone, 3 tasks).
```

**Already have a repository?** Run `/i2r:repo-bootstrap` in it. It switches to *adopt* mode, keeps what's there, and only adds what's missing.

## 3. Create the issues: `plan-to-issues`

> /i2r:plan-to-issues

**What it asks:** only for a yes on its dry run:

```
Repository: you/dedupe   Plan: 1 milestone, 3 tasks (0 done, 0 dropped)

milestone.ensure  create M1: Usable dedupe
issue.create      "T-001: Set up the test runner and lint"                       type:chore   priority:normal ready    M1
                  "T-002: Add the dedupe command"                                type:feature priority:normal blocked  M1
                  "T-003: Add the install smoke test and integration tests"      type:chore   priority:normal blocked  M1
issue.update      none
issue.link        T-002 blocked-by T-001
                  T-003 blocked-by T-002
issue.close       none
labels            none

Reported, not changed: none
```

- **Labels:** each issue gets a type, a priority and a state. `ready` means nothing blocks the task; `blocked` means a task it depends on isn't finished.
- **Issue bodies:** each one has the task's *Done when* list, copied from the plan, and a `Plan-Task: T-002` line. That line is how every later step finds the task again.

> Yes, go ahead as shown.

**What it changes:**

```
| Issue | Task | Labels | Blocked by |
|---|---|---|---|
| #1 | T-001: Set up the test runner and lint | `type:chore` `priority:normal` `ready` | none |
| #2 | T-002: Add the dedupe command | `type:feature` `priority:normal` `blocked` | #1 |
| #3 | T-003: Add the install smoke test and integration tests | `type:chore` `priority:normal` `blocked` | #2 |

- **Milestone:** I created `M1: Usable dedupe` (milestone #1), with the plan's M1 summary as its
  description. All three issues are in it.
```

The repository's files don't change: the plan stays the only source of the tasks.

**Run it again whenever the plan changes.** It changes only what differs. With no changes, it reports "Issues match the plan; no changes".

## 4. The first task: `work-issue`

> /i2r:work-issue

**What it asks:** which issue to take. With no issue named, it proposes the first `ready` one:

```
**Proposed issue: #1, T-001: Set up the test runner and lint** (`ready`, M1, `type:chore`,
`priority:normal`). No change request is open for it.

It's the only `ready` issue, so there are no other candidates:

- #2, T-002: Add the dedupe command is `blocked` by #1, which is still open.
- #3, T-003: Add the install smoke test and integration tests is `blocked` by #2.
…
Should I go ahead with #1?
```

> Yes, go ahead.

**What it changes:**
- **Locally:** it creates the branch, does the work, and runs every enabled stage.
- **On GitHub:** if every stage passes, it pushes and opens a pull request that closes exactly that issue. It also ticks the task's *Done when* boxes in the plan, in the same pull request.

```
I've opened PR #4 for T-001 (issue #1). The lint, unit and integration stages all pass locally.

**PR:** https://github.com/you/dedupe/pull/4, titled `test: add the test runner and assertion helpers`
- **Status:** open, mergeable (`CLEAN`), no review required. It closes #1 and nothing else.
- **CI checks:** none. The repo has no pipeline yet because ci-setup hasn't been run.
…
- **`docs/plan/PLAN.md`:** T-001's four boxes are ticked, and `check-plan.sh` passes.
…
- Your review rule needs 0 approvals, so nothing stops a merge. I haven't approved or merged it;
  that's yours to do.
```

**When a check fails,** `work-issue` stops before pushing, and never opens a pull request with a failing stage. If the cause is outside its task (a wrong run command in the config, say), it won't fix it there: it says where the fix belongs. See *When a step stops* below.

Review the pull request, and merge it.

## 5. CI: `ci-setup`

> /i2r:ci-setup

**What it asks:** for a yes on its dry run. It runs the enabled stages locally first, so the CI it adds starts green:

```
Pipeline: 4 core stages (3 enabled, 1 placeholder), 0 extra stages
  lint         run: shellcheck $(git ls-files 'bin/*' '*.sh')
  build        placeholder: Bash scripts run as they are; nothing to compile, and the shell-cli target packages releases
  unit         run: tests/run.sh unit
  integration  run: tests/run.sh integration
Files:     create .github/workflows/pipeline.yml (no CI files exist on main yet)
Local run: lint pass (3 files), unit pass (1 passed), integration pass ("no tests" yet)
Change request: branch chore/ci → main, "chore(ci): render the pipeline from the config"
```

> Go ahead.

**What it changes:** one file, `.github/workflows/pipeline.yml`, in pull request #5. It waits for CI to run on that pull request:

```
| Stage | Result on the change request |
|---|---|
| lint | pass |
| build | pass (placeholder; the log shows its `skipped:` message) |
| unit | pass (1 passed, 0 failed) |
| integration | pass, but it checks nothing yet ("integration: no tests") |
```

The workflow is generated from the `pipeline` block in `.project/config.yml`. To change it, edit the config and run `ci-setup` again; don't edit the file by hand. Merge #5.

## 6. Protect `main`: `repo-governance`

> /i2r:repo-governance

**What it asks:** for a yes on its dry run. It checks first that the four checks it will require have run on GitHub, so the rules can't lock the repository:

```
Repository: you/dedupe (private)   Default branch: main
Visibility:    private (no change; matches config and decision 0003)
Access:        you admin; 1 person can write; no pending invitations; grants: none
Branch rules (new ruleset "idea-to-release" on ~DEFAULT_BRANCH, enforcement active, no bypass actors):
  protect      deletion: allowed → blocked; force push: allowed → blocked; direct push: allowed → blocked (pull requests only)
  reviews      required approvals: none → 0; code owners: off (decision 0005)
  checks       required: none → lint, build, unit, integration (GitHub Actions only, strict off)
               all four reported success on PR #5; on main 3bb4472, build/unit/integration passed and lint skipped (it only runs on PRs)
Other rulesets: none.   Classic branch protection: none.
Fallback:      none needed
```

> Yes, apply it.

**What it changes:** a ruleset on `main`, and no files, so there's no pull request:

```
- **Protection:** `main` can't be deleted, force-pushed to or pushed to directly. Every change has
  to come through a pull request.
- **Reviews:** no approvals are required and code-owner review is off, per decision 0005.
- **Checks:** `lint`, `build`, `unit` and `integration` must pass before a pull request can merge,
  and only GitHub Actions can report them.
- **Who it applies to:** the ruleset is active with no bypass actors, so it applies to you as admin
  too.
…
- If a pull request is blocked, `gh pr merge` may suggest `--admin`. Don't use it: that skips the
  gates.
```

**On a private repository**, branch rules need a paid GitHub plan. This run's account had one. On a free account, GitHub refuses the rules. Then `repo-governance` writes a decision record that says which rules aren't enforced and what replaces them (`work-issue` never opens a red pull request, and you only merge green ones), and opens a pull request for it. Making the repository public, or upgrading the plan, lets a later run enforce the rules.

## 7. The remaining tasks: `work-issue`

> /i2r:work-issue

When T-001 merged, #2's blocker closed, but its label still said `blocked`. `work-issue` noticed:

```
No issue is labelled `ready`, so I looked for a `blocked` label that's out of date. I found one.

**Proposed: #2 — T-002: Add the dedupe command** (M1, `type:feature`, `priority:normal`)
- Its label says `blocked`, but its only blocker, #1 (T-001), is closed. The label is stale.
- If you confirm, I'll first change #2's label from `blocked` to `ready`, then branch
  `feat/2-add-dedupe-command` from `main` and do the work.
…
There are no other candidates. Shall I take #2?
```

> Yes, go ahead.

It opened pull request #6, which closes #2. That task added `--version`, so it also added `bin/dedupe:DEDUPE_VERSION=` to `release.version_files`. **What it leaves to you:** the choices it made where the plan was silent, listed for your review:

```
**Decisions for you to check in review**
- **Version:** `--version` prints `dedupe 0.0.0` for now. The first release will set the real number.
- **Bad files:** when one file is bad, the others are still read and printed, as `cat` does, and the
  exit status is still 1. If every file is bad, it doesn't fall back to reading stdin.
- **File names with `=`:** a file named something like `a=b` is read as a file. Without a fix, `awk`
  would treat that name as a variable assignment.
```

Merge it, then run `/i2r:work-issue` once more. It offers #3 the same way (its `blocked` label is out of date too), and opens pull request #7 for T-003. Merge that too:

```
Merging is your call. Once #7 merges, every task in M1 is done.
```

**A `blocked` issue whose blockers are still open is never taken.** If you name one (`/i2r:work-issue issue=3`), `work-issue` refuses and names what it's waiting for.

## 8. Release: `cut-release`

With every task in M1 merged:

> /i2r:cut-release

`cut-release` runs in stages, and you run it once per stage. Each run picks up where the last one stopped.

**Run 1: the release pull request.** It works out the version and the changelog from the pull requests merged since the last release, and the plan tasks they delivered:

```
I've opened the release change request: **https://github.com/you/dedupe/pull/8** (`chore(release): v0.1.0`).

- **Version:** v0.1.0. It's the first release, so it starts at 0.1.0. #6 (`feat: add the dedupe
  command`) is the change that justifies a release.
- **`CHANGELOG.md`:** adds `## [0.1.0] - 2026-11-22` with one entry under Added, "Add the dedupe
  command (#6)", and a link to the release page. `## [Unreleased]` stays at the top, empty. The other
  three change requests (#4, #5, #7) are test and CI chores, which the changelog doesn't list.
- **`bin/dedupe`:** `DEDUPE_VERSION=0.0.0` → `0.1.0`.
- **Tasks delivered (M1: Usable dedupe):**
  - T-001: test runner and lint (#1, change request #4)
  - T-002: the dedupe command (#2, change request #6)
  - T-003: install smoke test and integration tests (#3, change request #7)
  - No task was closed without a change request.
…
```

- **The version** comes from the pull request titles: a `feat` raises the minor version, a `fix` the patch.
- **The changelog** is written from those titles too. So write a pull request's title as you'd want it in the changelog.

Merge #8, then:

> I merged #8. Run /i2r:cut-release again.

**Run 2: the tag.** It checks that `main`'s head is the release pull request's merge commit, and that its checks pass, then asks:

```
**Dry run of `tag.create`:**

git tag -a v0.1.0 9a6de45dc4563f749a59c79c2ad06748d0d7fef9 -m "v0.1.0"
git push origin refs/tags/v0.1.0

Pushing the tag starts the release checks (build, unit, integration). Once they pass, I'll package
the archive (`dedupe-0.1.0.tar.gz`), test that it installs, and create a draft release. Publishing
needs a separate yes from you.

Tags are permanent and never moved. If a release check fails after the push, v0.1.0 stays as it is,
and the fix would go out as v0.1.1.

**Do you want me to create and push the `v0.1.0` tag?**
```

> Yes, create and push the tag.

**What it changes:**
- **Tag and package:** it pushes the tag, waits for the release checks, then builds the archive from a clean copy of the tag. It installs the archive somewhere temporary and tests it.
- **Draft:** it saves the release as a draft:

```
- **Tag:** `v0.1.0` → `9a6de45`, the merge commit of #8.
- **Checks on the tag:** build passed (placeholder), unit and integration passed, and lint was
  skipped because it only runs on pull requests. Overall: pass.
- **Asset:** `dedupe-v0.1.0.tar.gz`, 3,095 bytes. I built it from a clean copy of the tag and tested
  the install: `dedupe` installed, `tests/smoke.sh` passed, 6 checks passed.
…
**Do you want me to publish v0.1.0?** If you say no, the draft stays as it is, and a later
`/i2r:cut-release` run picks it up at this step.
```

> Yes, publish v0.1.0.

```
**dedupe v0.1.0 is published:** https://github.com/you/dedupe/releases/tag/v0.1.0

- **Published:** 2026-11-22 04:31 UTC. It's marked as the latest release.
- **Tag:** `v0.1.0` still points at `9a6de45`, the merge commit of #8. Publishing didn't move it.
…
```

The release notes list the plan tasks it delivered, the changelog section, and how to install it. Installed from the archive:

```console
$ tar -xzf dedupe-v0.1.0.tar.gz && cd dedupe-v0.1.0 && ./install.sh
Installed dedupe v0.1.0 in $HOME/.local/bin: dedupe
Note: $HOME/.local/bin isn't on your PATH. Add it, for example: export PATH="$HOME/.local/bin:$PATH"
```

Then, with it on your `PATH`:

```console
$ printf 'b\na\nb\nA\n' | dedupe
b
a
A
$ printf 'b\na\nb\nA\n' | dedupe --ignore-case
b
a
$ dedupe --version
dedupe 0.1.0
```

## What's next: the next feature

After the first release, every change goes round the same loop:

1. `/i2r:idea-to-plan` with what you want to change. In *revise* mode, it adds milestones and tasks without renumbering the old ones. If the change contradicts the plan's scope, it says so, and records the reversal in a decision record.
2. `/i2r:plan-to-issues` creates the new issues.
3. `/i2r:work-issue`, once per task.
4. `/i2r:cut-release` when there's a `feat` or `fix` worth releasing.

`ci-setup` and `repo-governance` only need running again when the pipeline stages or the rules change. Optionally, `/i2r:write-tutorial` writes your project's own `docs/tutorial.md` from a real run, before a release that should ship one.

## When a step stops

The skills stop rather than guess, and say why. The common cases:

| It says | Why | What to do |
|---|---|---|
| A stage fails locally, and the cause isn't the task's code | A run command or the config is wrong | Fix it through `idea-to-plan`, which changes the plan and the config together, merge, then tell `work-issue` to carry on |
| A stage fails because of the task's code | The work isn't finished | Let `work-issue` fix it. It doesn't open a red pull request |
| No issue is `ready` | Every open issue waits on another | Merge the open pull requests. `work-issue` then offers the first issue whose blockers have all closed |
| An issue is `blocked` | A blocker is still open | Finish the blocker first |
| Standard labels are missing | The repository wasn't bootstrapped | Run `repo-bootstrap`, which adds only what's missing |
| `check-plan.sh` fails | The plan's format is broken | Fix the plan through `idea-to-plan` |
| GitHub refuses the branch rules | A private repository on a free plan | `repo-governance` records the gap in a decision record. Go public or upgrade to enforce them |
| `main` moved after the release pull request | Something merged in between | `cut-release` asks: prepare again, or tag the release commit itself |
| A release check fails on the tag | The tag's build or tests fail | Fix it in a new pull request, then cut a patch release. Tags are never moved |

You can stop at any confirmation and come back later. Every skill checks what's already done before it acts, so running it again is safe.

## See also

- `README.md`: installing, and how the skills fit together
- `conventions.md`: the rules the skills follow (labels, branches, commits, releases, safety)
- `skills/<name>/SKILL.md`: each skill's full procedure
- `docs/decisions/`: why things are the way they are

Outputs from a recorded run from 2026-11-22.
