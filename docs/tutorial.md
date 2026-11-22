# Tutorial: from an idea to a first release

This tutorial follows one small project, `titlecase`, from an idea to its first published release, using the seven idea-to-release skills in the order you'd use them. Every prompt and reply below comes from a real run of the Claude Code plugin `i2r` (made for T-039 of this repository's plan).

- **Names:** the run used `rmdesmond/titlecase`. Here it's `you/titlecase`; use your own account.
- **Replies are shortened:** `…` marks a cut. An agent words things a little differently each time, so your replies won't match exactly, but they'll have the same steps, dry runs and questions.

**The project:** `titlecase` is a bash command that turns text into title case:

```console
$ titlecase the lord of the rings
The Lord of the Rings
$ echo 'a tale OF two cities' | titlecase
A Tale of Two Cities
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

```sh
claude plugin marketplace add rmdesmond/idea-to-release
claude plugin install i2r@i2r
```

```
✔ Successfully added marketplace: i2r
✔ Successfully installed plugin: i2r@i2r (scope: user)
```

- **Names:** the skills are now typed with the plugin's name in front: `/i2r:idea-to-plan`, `/i2r:work-issue` and so on. In their own replies, the skills name each other without the prefix ("run plan-to-issues next"). In Claude Code, that's `/i2r:plan-to-issues`.
- **Updates** come with releases: `claude plugin marketplace update i2r`, then `claude plugin update i2r@i2r`.
- **Other agents** (Codex, Copilot, Gemini CLI) use the release archive and its `install.sh` instead. See the README's *Installing* section.

Make an empty folder for the project, and start Claude Code there:

```sh
mkdir titlecase && cd titlecase && claude
```

## 1. Plan: `idea-to-plan`

**Start it** with your idea, in as much or as little detail as you have:

> /i2r:idea-to-plan My idea: titlecase, a tiny command-line tool in bash that turns text into title case ('the lord of the rings' → 'The Lord of the Rings'). Small words (a, an, and, of, the, ...) stay lower-case except at the start. It reads arguments, or stdin when there are none. Keep it to one milestone with at most three tasks. It lives on GitHub as you/titlecase, private, MIT. Installed with an install.sh into ~/.local/bin.

**What it asks.** It looks at the folder first: here, an empty one, so it's in *new* mode. Then it goes through seven topics, one at a time, proposing an answer for each and waiting for you to confirm or change it:

1. **Goal**
2. **Scope**: what's in, and what's explicitly out
3. **Constraints**: language, versions, hosting, licence
4. **Release target**: how a release is packaged and installed
5. **Milestones**
6. **Tasks**: each with a *Done when* checklist and its dependencies
7. **Verification strategy**: test levels, and the command for each pipeline stage

It raises the decisions you might not have thought about. From the scope topic:

```
Two calls to check:
1. Should the rest of each word be left alone (so `NASA` stays `NASA`), or forced to lower-case (`Nasa`)?
2. Is that small-word list right?
```

> 1. Leave the rest alone. 2. The list is right. Scope confirmed; next topic.

From the release-target topic:

```
> Target: `shell-cli` - a `titlecase` command, installed into `~/.local/bin` by the release archive's
> `install.sh` (`--prefix` to install elsewhere)

- The archive: `titlecase-<version>.tar.gz`, containing `install.sh`, `bin/titlecase`, `VERSION`,
  `LICENSE` and `README.md`.
- Version string: `--version` puts the version in the code, so the task that adds it also registers
  `bin/titlecase:TITLECASE_VERSION=` under `release.version_files`. That way each release bumps it
  automatically.
```

The tasks it proposed, each with a *Done when* list:

```
T-001: Set up the test harness and lint.                     Depends on: none
T-002: Add the titlecase command.                             Depends on: T-001
T-003: Add end-to-end tests, smoke test and README.           Depends on: T-002
```

And the verification strategy:

```
| Stage       | Enabled | Run command, or reason if disabled |
| lint        | yes     | shellcheck … |
| build       | no      | Bash script, nothing to compile. Packaging is done by the shell-cli target at release time |
| unit        | yes     | tests/run.sh unit (created by T-001) |
| integration | yes     | tests/run.sh integration (created by T-001; tests from T-003) |
```

**What it changes:** only files in your folder. Here it wrote `docs/plan/PLAN.md` and two decision records, `0001-language-bash-3-2.md` and `0002-test-harness-plain-bash.md`. It checked the plan with `check-plan.sh`:

```
ok: docs/plan/PLAN.md has 1 milestone(s) and 3 task(s)
```

There was no repository yet, so it committed nothing. It listed the stage settings for the next step instead.

## 2. Create the repository: `repo-bootstrap`

> /i2r:repo-bootstrap Create you/titlecase: private, MIT licence, description 'Turn text into title case'. Use the stage settings the plan's verification strategy gives.

**What it asks:** nothing up front. It reads the plan, checks the forge, and shows a dry run, grouped by how much each change matters:

```
Mode: create   Repository: you/titlecase (private)

Admin (needs your confirmation):
  repo.create     gh repo create you/titlecase --private
                  --description "Turn text into title case"   (empty: no README, licence or .gitignore)
                  then: git init -b main here, and add origin
  repo.configure  merge methods → squash only (merge and rebase off)
                  squash commit message → PR title and description
                  delete branch on merge → on
                  issues on; wiki and projects off (the plan and decisions live in the repo)
Write:
  label.ensure    create 10 labels (type:*, priority:*, ready, blocked, needs-decision)
  files           create .project/config.yml, CHANGELOG.md, LICENSE (MIT), .gitignore, README.md,
                  .github/pull_request_template.md, .github/ISSUE_TEMPLATE/task.md
                  keep docs/plan/PLAN.md (exists)
  decisions       create 0003-licence-mit.md, 0004-visibility-private.md,
                  0005-merge-strategy.md, 0006-review-rule.md
                  keep 0001, 0002 (exist)
  commit          "chore: bootstrap repository" straight to main, then push
                  (create mode only: the repo has no history yet)
```

It also says which defaults it chose for what you didn't specify. For example, it requires 0 approvals, because GitHub never counts an author's own approval, so with a single maintainer 1 would block every merge.

> Yes, go ahead with all of it.

**What it changes:**
- **On GitHub:** it creates the repository, its settings and the 10 labels.
- **In the repository:** the files listed above, in one commit pushed to `main`. That's the only commit that ever goes straight to `main`; everything after it goes through a pull request.

**Already have a repository?** Run `/i2r:repo-bootstrap` in it. It switches to *adopt* mode, keeps what's there, and only adds what's missing.

## 3. Create the issues: `plan-to-issues`

> /i2r:plan-to-issues

**What it asks:** only for a yes on its dry run:

```
Repository: you/titlecase   Plan: 1 milestone, 3 tasks (0 done, 0 dropped)

milestone.ensure  create "M1: Working titlecase"
issue.create      "T-001: Set up the test harness and lint"              type:chore   priority:normal ready    M1
                  "T-002: Add the titlecase command"                      type:feature priority:normal blocked  M1
                  "T-003: Add end-to-end tests, smoke test and README"    type:chore   priority:normal blocked  M1
issue.update      none
issue.link        T-002 blocked-by T-001
                  T-003 blocked-by T-002
issue.close       none
labels            none (no closed issues)

Reported, not changed: none
```

- **Labels:** each issue gets a type, a priority and a state. `ready` means nothing blocks the task; `blocked` means a task it depends on isn't finished.
- **Issue bodies:** each one has the task's *Done when* list, copied from the plan, and a `Plan-Task: T-002` line. That line is how every later step finds the task again.

> Yes, go ahead as shown.

**What it changes:**
- **On the tracker:** the milestone, the three issues (#1 to #3), and the two links.
- **In the repository:** nothing. The plan stays the only source of the tasks.

**Run it again whenever the plan changes.** It changes only what differs. With no changes, it reports "Issues match the plan; no changes".

## 4. The first task: `work-issue`

> /i2r:work-issue

**What it asks:** which issue to take. With no issue named, it proposes the first `ready` one:

```
I'd take #1: T-001: Set up the test harness and lint.

- It's the only issue labelled `ready` in M1 (`type:chore`, `priority:normal`), and it has no open
  change request.
- Branch: `chore/1-test-harness-and-lint`.
…
There's nothing else to pick yet:
- #2: T-002: Add the titlecase command is `blocked` until #1 is done.
- #3: T-003: Add end-to-end tests, smoke test and README is `blocked` until #2 is done.

Should I go ahead with #1?
```

> Yes, go ahead.

**What it changes:**
- **Locally:** it creates the branch, does the work, and runs every enabled stage.
- **On GitHub:** if every stage passes, it pushes and opens a pull request that closes exactly that issue. It also ticks the task's *Done when* boxes in the plan, in the same pull request.

**When a check fails.** In this run, lint failed, and not because of T-001's code:

```
I've stopped before pushing anything: the required `lint` stage fails, and the cause is in the
config, not in this task's code.

The problem. The lint `run` command in `.project/config.yml` (and in the plan's verification table)
is `shellcheck bin/titlecase tests/*.sh tests/*/*.sh`. `bin/titlecase` doesn't exist until T-002
(#2), so shellcheck stops … and exits 2. …

My suggestion: change the lint command to something that works before and after T-002 … in its own
small change request through idea-to-plan, which updates the plan's verification table and the
config together. Once it merges, I'd rebase this branch, run every stage again and open the change
request for #1.
```

`work-issue` never opens a pull request with a failing stage. It also won't fix a problem outside its task, so it stops and says where the fix belongs. Here, that meant changing the plan:

> /i2r:idea-to-plan Revise the verification strategy: the lint command names bin/titlecase, which T-002 creates, so lint fails on T-001. Change lint to: shellcheck $(git ls-files 'bin/*' '*.sh'). Update the plan and the config together.

`idea-to-plan` opened pull request #4 with that one change. Since v0.2.0 it doesn't propose a command like the first one, but the way out is the same for any check that fails for a reason outside the task. After merging #4:

> I merged PR #4 with the new lint command. Rebase and carry on.

```
Pull request #5 for issue #1 is open … It's titled `test: add plain-bash test runner and assertion
helpers` and closes only #1. Every stage passes locally, and the pull request is mergeable with no
conflicts.
…
| lint        | pass |
| build       | skipped (disabled in the config) |
| unit        | pass: 2 test files, 0 failed |
| integration | pass: no test files yet, those come with T-003 |
…
The merge is up to you.
```

Review the pull request, and merge it.

## 5. CI: `ci-setup`

> /i2r:ci-setup

**What it asks:** for a yes on its dry run. It runs the enabled stages locally first, so the CI it adds starts green:

```
Pipeline: 4 core stages (3 enabled, 1 placeholder), 0 extra stages
  lint         run: shellcheck $(git ls-files 'bin/*' '*.sh')       (change requests only)
  build        placeholder: Bash script, nothing to compile; packaging is done by the shell-cli target at release time
  unit         run: tests/run.sh unit
  integration  run: tests/run.sh integration
Files:     create .github/workflows/pipeline.yml (no CI files exist yet)
Local run: lint pass (shellcheck 0.11.0), unit pass (2 files, 0 failed), integration pass (0 test files)
Change request: branch chore/ci → main, "chore(ci): render the pipeline from the config"
```

> Go ahead.

**What it changes:** one file, `.github/workflows/pipeline.yml`, in pull request #6. It waits for CI to run on that pull request:

```
| lint        | pass |
| build       | pass (placeholder: prints `skipped: …` and succeeds) |
| unit        | pass |
| integration | pass |
```

The workflow is generated from the `pipeline` block in `.project/config.yml`. To change it, edit the config and run `ci-setup` again; don't edit the file by hand. Merge #6.

## 6. Protect `main`: `repo-governance`

> /i2r:repo-governance

**What it asks:** for a yes on its dry run. It checks first that the four checks it will require have run on GitHub, so the rules can't lock the repository:

```
Repository: you/titlecase (private)   Default branch: main
Visibility:    private (no change; matches the config and decision 0004)
Access:        you admin; 1 person can write; no pending invitations; grants: none
Branch rules (new ruleset "idea-to-release" on ~DEFAULT_BRANCH, enforcement active, no bypass actors):
  protect      deletion: allowed → blocked; force push: allowed → blocked; direct push: allowed → blocked
  reviews      required approvals: none → 0; code owners: off (decision 0006)
  checks       required: none → lint, build, unit, integration (GitHub Actions only, strict off)
Other rulesets / classic protection on main: none
Fallback:      none needed
```

> Yes, apply it.

**What it changes:** a ruleset on `main`. From then on, `main` can't be deleted or force-pushed, every change has to come through a pull request, and the four checks must pass before a merge. That applies to you too, as admin, because the ruleset has no bypass actors.

**On a private repository**, branch rules need a paid GitHub plan. This run's account had one. On a free account, GitHub refuses the rules. Then `repo-governance` writes a decision record that says which rules aren't enforced and what replaces them (`work-issue` never opens a red pull request, and you only merge green ones), and opens a pull request for it. Making the repository public, or upgrading the plan, lets a later run enforce the rules.

## 7. The remaining tasks: `work-issue`

> /i2r:work-issue

When T-001 merged, #2's blocker closed, but its label still said `blocked`. `work-issue` noticed:

```
I checked the tracker. No open issue is labelled `ready`, but one has a stale `blocked` label:

Proposed: #2 — T-002: Add the titlecase command (M1, `type:feature`, `priority:normal`)
- It's labelled `blocked`, but its only blocker, #1 (T-001: Set up the test harness and lint), was
  closed on 2026-11-22. So the label is out of date.
- If you confirm, I'll first change #2's label from `blocked` to `ready`. …

Should I go ahead with #2?
```

> Yes, go ahead.

**What it asks along the way:** when the plan leaves something open, `work-issue` stops and asks instead of guessing:

```
The question: the plan's Scope says "Each word's first letter is upper-cased; the rest of the word is
left alone (`NASA`, `iPhone` survive)". Those two parts don't agree for a word like `iPhone`:

- A. Apply the rule literally … `iPhone` → `IPhone` …
- B. Leave mixed-case words alone (recommended) … `iPhone` stays `iPhone` …

Which do you want, A or B?
```

> B. Flag the scope wording in the PR, and carry on.

It opened pull request #7, which closes #2. That task added `--version`, so it also added `bin/titlecase:TITLECASE_VERSION=` to `release.version_files`. Merge it, then run `/i2r:work-issue` once more for T-003 (pull request #8), and merge that too.

**A `blocked` issue whose blockers are still open is never taken.** If you name one (`/i2r:work-issue issue=3`), `work-issue` refuses and names what it's waiting for.

## 8. Release: `cut-release`

With every task in M1 merged:

> /i2r:cut-release

`cut-release` runs in stages, and you run it once per stage. Each run picks up where the last one stopped.

**Run 1: the release pull request.** It works out the version and the changelog from the pull requests merged since the last release, and the plan tasks they delivered:

```
I've opened the release change request for v0.1.0, which is titlecase's first release: …/pull/9
(`chore(release): v0.1.0`). It now needs you to review and merge it.

- Checks: lint, build, unit and integration all pass on the PR …
- Version: `0.1.0`. A first release always starts there, and `feat: add the titlecase command` (#7)
  is the only change that raises the version.
- Changelog: the PR adds one section, `## [0.1.0] - 2026-11-22`, with one entry under Added: "Add the
  titlecase command (#7)". … The other merged PRs (#4 docs, #5 test, #6 and #8 chore) don't appear in
  the changelog, because those types aren't listed.
- Plan tasks delivered: …
  - T-001 (issue #1, PR #5)
  - T-002 (issue #2, PR #7)
  - T-003 (issue #3, PR #8)
```

- **The version** comes from the pull request titles: a `feat` raises the minor version, a `fix` the patch.
- **The changelog** is written from those titles too. So write a pull request's title as you'd want it in the changelog.

Merge #9, then:

> I merged #9. Run /i2r:cut-release again.

**Run 2: the tag.** It checks that `main`'s head is the release pull request's merge commit, and that its checks pass, then asks:

```
git tag -a v0.1.0 7d06340… -m "v0.1.0"
git push origin refs/tags/v0.1.0

- The push runs the pipeline's release stages: build, unit and integration. …
- Tags are permanent. If something turns out wrong after this, the fix is a new patch release, never
  moving the tag.

Shall I create and push the `v0.1.0` tag?
```

> Yes, create and push the tag.

**What it changes:**
- **Tag and package:** it pushes the tag, waits for the release checks, then builds the archive from a clean copy of the tag. It installs the archive somewhere temporary and tests it.
- **Draft:** it saves the release as a draft:

```
- Package: built from a clean copy of the tag, then installed somewhere temporary and tested. All 6
  checks passed, including `tests/smoke.sh`.
- Draft: …/releases/tag/untagged-…
  - One file attached: `titlecase-v0.1.0.tar.gz`, 4,543 bytes. …

Shall I publish v0.1.0? If you'd rather wait, the draft stays as it is and the next
`/i2r:cut-release` run carries on from here.
```

> Yes, publish v0.1.0.

The release is published. Its notes list the plan tasks it delivered, the changelog section, and how to install it:

```console
$ tar -xzf titlecase-v0.1.0.tar.gz && cd titlecase-v0.1.0 && ./install.sh
Installed titlecase v0.1.0 in ~/.local/bin: titlecase
$ titlecase the lord of the rings
The Lord of the Rings
```

## What's next: the next feature

After the first release, every change goes round the same loop:

1. `/i2r:idea-to-plan` with what you want to change. In *revise* mode, it adds milestones and tasks without renumbering the old ones. If the change contradicts the plan's scope, it says so, and records the reversal in a decision record.
2. `/i2r:plan-to-issues` creates the new issues.
3. `/i2r:work-issue`, once per task.
4. `/i2r:cut-release` when there's a `feat` or `fix` worth releasing.

`ci-setup` and `repo-governance` only need running again when the pipeline stages or the rules change.

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

- `conventions.md`: the rules the skills follow (labels, branches, commits, releases, safety)
- `skills/<name>/SKILL.md`: each skill's full procedure
- `docs/decisions/`: why things are the way they are
