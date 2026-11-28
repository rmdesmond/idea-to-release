# Tracker adapter: local

Keeps the tracker in a **store**: a folder outside the project, next to it by default, that is a git repository of its own (decision 0027). It pairs with the `local` forge, for a project with no hosting service. Mixing it with a hosted forge isn't supported.

Every tracker verb has a section here. The commands live in `adapters/tracker/local/`. `scripts/check-adapters.sh` checks that no verb is missing.

## Prerequisites

- `git`, with `user.name` and `user.email` set: every write is a commit in the store.
- bash 3.2 or later, and the standard tools (`awk`, `sed`, `grep`, BSD or GNU). No `gh` and no network.
- Run the commands from the project's root, or pass `-C <project>` first. Below, `tracker.sh` means `<skill set>/adapters/tracker/local/tracker.sh`.

## Finding the store

1. `tracker_path` in `.project/config.yml`: relative to the project's root (conventions §4). An absolute path works too.
2. Otherwise `../<repo>-tracker`, with `<repo>` from the config, or the project folder's name.

`tracker.sh store-path` prints the path, then `exists`, `missing` or `not a tracker store`.

- **No store yet:** reads return nothing, and say on stderr that the store doesn't exist yet. The first write creates it: `git init`, then a first commit, `store: create the tracker store`. It says so on stderr.
- **A folder that isn't a store** (it has files but no store layout): every verb refuses to write to it. Nothing in it is changed.

## The store

```
<store>/
  README.md        what the folder is
  next             the next number, shared by issues and the local forge's change requests
  labels.md        | Name | Colour | Description |
  milestones.md    | Number | Title | State | Description |
  issues/NNNN.md   one file per issue
  crs/NNNN.md      the local forge's change requests (adapters/forge/local.md)
```

An issue file is `Key: value` header lines, a blank line, then the body:

```
Number: 3
Title: T-002: Add options
State: open
Created: 2026-11-28
Labels: type:feature, priority:normal, blocked
Milestone: M1: Walking skeleton
Blocked-by: 1, 2
Parent:
Closed:
Reason:
Comment:

## Context
...
Plan-Task: T-002
```

- `State` is `open` or `closed`. `Reason` is `completed` or `not planned`. `Closed` is a UTC date.
- Links are stored on the dependent side only: `Blocked-by` and `Parent`. `issue-view` works out the other side, `Blocking` and `Children`.
- Titles, label names, milestone titles and comments are single lines. Label names can't contain `,` or `|`, and descriptions can't contain `|`, because those separate fields in the files.

**Writes.** Each write takes a lock (`<store>/.lock`), refuses to run if the store has uncommitted changes, and ends in one commit naming the verb and the issue, for example `issue.close: #3 (not planned)`. So `git -C <store> log` is the tracker's history, and a mistaken write can be undone with `git revert`. Edit the store only through the adapter.

## Errors

- A non-zero exit is a failure: report the message (`error: ...` on stderr) and stop. Don't retry writes automatically.
- `the tracker store has uncommitted changes`: someone edited the store by hand, or a write failed half-way. Look at `git -C <store> status`, then commit or undo those changes.
- `the tracker store is locked by another write`: another write is running, or one was killed. Remove `<store>/.lock` only if no write is running.

---

### label.ensure

- **Tier:** write
- **Inputs:** a list of labels, each with `name`, `color` (6-digit hex, no `#`) and `description`
- **Check existing state:** built in. Names are compared case-insensitively, as on GitHub. For each label the command prints one of `created <name>`, `same <name>`, or `different <name>: <current> (wanted <wanted>)`. A check alone writes nothing.
- **Command:** once per label:
  ```sh
  tracker.sh label-ensure "<name>" <color> "<description>"
  ```
  A label that is present but different is reported, not overwritten (conventions §2). After the user's yes, update it:
  ```sh
  tracker.sh label-ensure "<name>" <color> "<description>" --update
  ```
- **Output:** the labels created, unchanged and different. `tracker.sh label-list` prints every label, tab-separated.
- **Fallback:** none needed.

### milestone.ensure

- **Tier:** write
- **Inputs:** a list of milestones, each with `title` and an optional `description`
- **Check existing state:** built in, by exact title. The command prints `created <n> <title>`, `same <n> <title>`, `different <n> <title>: ...` or `closed <n> <title>`.
- **Command:** once per milestone:
  ```sh
  tracker.sh milestone-ensure "<title>" "<description>"
  ```
  A different or closed milestone is reported, not changed. After the user's yes:
  ```sh
  tracker.sh milestone-ensure "<title>" "<description>" --update   # the description
  tracker.sh milestone-ensure "<title>" --reopen                    # a closed one
  ```
- **Output:** each milestone's number and title, grouped as created, unchanged, different or closed. `tracker.sh milestone-list` prints them all, tab-separated.
- **Notes:** issues refer to a milestone by its title.
- **Fallback:** none needed.

### issue.create

- **Tier:** write
- **Inputs:** `title`, `body`, `labels`, optional `milestone` (title). Relationships are added afterwards with `issue.link`.
- **Check existing state:** the calling skill first looks at the plan's `Issue:` line. The command then looks for an issue whose body carries the same `Plan-Task: T-NNN` line. If one matches, it prints `found <n> <state>` and creates nothing. If more than one matches, it fails and names them.
- **Command:** write the body to a temporary file, then:
  ```sh
  tracker.sh issue-create --title "<title>" --body-file <file> \
    --label "<label>" --label "<label>" --milestone "<milestone title>"
  ```
  Every label and the milestone must already exist (`label.ensure`, `milestone.ensure`), or nothing is created.
- **Output:** `created <n>` or `found <n> <state>`. The issue's file is `<store>/issues/<NNNN>.md`.
- **Fallback:** none needed.

### issue.update

- **Tier:** write
- **Inputs:** issue number, and any of: `title`, `body`, `labels_add`, `labels_remove`, `milestone` (title, or none to remove)
- **Check existing state:** built in. Only what differs is written. Bodies are compared after trimming trailing whitespace. Nothing differing prints `no changes`, with no commit.
- **Command:** one call carrying every change:
  ```sh
  tracker.sh issue-update <n> --title "<title>" --body-file <file> \
    --add-label "<label>" --remove-label "<label>" --milestone "<milestone title>"
  ```
  Use `--remove-milestone` to clear the milestone.
- **Output:** fields changed, as `name: old → new` (for the body, just `body changed`).
- **Notes:** a closed issue is updated like any other, and its state is left alone. Reopening isn't part of this verb.
- **Fallback:** none needed.

### issue.link

- **Tier:** write
- **Inputs:** issue number, `relation` (`blocked-by` | `blocks` | `parent`), and the other issue's number
- **Check existing state:** built in. `tracker.sh issue-view <n>` shows `Blocked-by`, `Blocking`, `Parent` and `Children`. A link already there prints `present ...` and writes nothing.
- **Command:**
  ```sh
  tracker.sh issue-link <n> blocked-by <other>
  tracker.sh issue-link <n> blocks <other>     # stored as: <other> blocked-by <n>
  tracker.sh issue-link <n> parent <other>
  ```
  Add `--remove` to remove a link that's no longer wanted. That's a separate, announced write, never part of adding.
- **Output:** `added ...`, `present ...`, `changed #<n> parent: #<old> → #<new>` or `removed ...`.
- **Notes:**
  - Links are two-sided, and stored once, on the dependent side. Record each dependency as the dependent task's `blocked-by`.
  - A link that would make a cycle, in either `blocked-by` or `parent`, is refused.
  - An issue has one parent. Setting another replaces it, and that's reported as a change.
- **Fallback:** none needed. The store records dependencies and parents itself.

### issue.close

- **Tier:** write
- **Inputs:** issue number, `reason` (`completed` | `not planned`), optional comment (one line)
- **Check existing state:** built in. An issue that's already closed prints `no changes`, even if the reason differs.
- **Command:**
  ```sh
  tracker.sh issue-close <n> --reason completed --comment "<comment>"
  tracker.sh issue-close <n> --reason not-planned --comment "<comment>"
  ```
- **Output:** `closed <n> <reason>`.
- **Notes:** closing sets `State: closed`, today's UTC date in `Closed`, the reason and the comment. The issue's file is kept (conventions §13), and its labels are left as they are.
- **Fallback:** none needed.

### issue.list

- **Tier:** read
- **Inputs:** optional filters: `state` (`open` | `closed` | `all`, default `open`), `labels`, `milestone`
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  tracker.sh issue-list --state <state> --label "<label>" --milestone "<title>"
  tracker.sh issue-list --state all --bodies     # every issue's whole file
  tracker.sh issue-view <n>                       # one issue, with Blocking and Children
  ```
  Give `--label` once per label. An issue must carry all of them.
- **Output:** one tab-separated line per issue: `number`, `state`, `title`, `labels`, `milestone`, `closed` (date or empty). With `--bodies`, each issue's whole file instead, after a line `=== #<n>`, which also gives `body` and `reason`. There's no `url`: the issue's file, `<store>/issues/<NNNN>.md`, takes its place. With no store, nothing.
- **Notes:** there's no limit, so the list is always complete.
- **Fallback:** none needed.
