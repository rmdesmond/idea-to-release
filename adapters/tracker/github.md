# Tracker adapter: GitHub Issues

Translates the neutral tracker verbs in `conventions.md` §2 into GitHub commands. Prerequisites, repository resolution and error handling are the same as in [`../forge/github.md`](../forge/github.md).

Every tracker verb has a section here. A verb that is not yet available says `Status: not yet implemented`. `scripts/check-adapters.sh` checks that no verb is missing.

- **Run the commands with bash.** The snippets in this file rely on bash's word splitting and quoting. zsh, macOS's default interactive shell, splits words differently, so run them as `bash -c '…'` or from a bash script.

---

### label.ensure

- **Tier:** write
- **Inputs:** a list of labels, each with `name`, `color` (6-digit hex, no `#`) and `description`
- **Check existing state:** read every label once, not once per label:
  ```sh
  gh label list --repo {o}/{r} --limit 500 --json name,color,description
  ```
  Compare each wanted label by `name`. GitHub label names are case-insensitive, so compare them that way. Sort each label into one of three groups:
  - **missing:** not present
  - **same:** present, with the same colour (case-insensitive) and description
  - **different:** present, with a different colour or description
- **Command:** for each missing label only:
  ```sh
  gh label create "<name>" --repo {o}/{r} --color <color> --description "<description>"
  ```
  Don't use `--force`. A label that is present but different is reported, not overwritten (conventions §2). The skill asks the user before updating one:
  ```sh
  gh label edit "<name>" --repo {o}/{r} --color <color> --description "<description>"
  ```
- **Output:** the labels created, the labels unchanged, and the labels that differ (with their current and wanted values).
- **Notes:** labels not in the wanted list, such as GitHub's defaults, are left alone.
- **Fallback:** none needed.

### milestone.ensure

- **Tier:** write
- **Inputs:** a list of milestones, each with `title` (e.g. `M1: Foundations`) and an optional `description`
- **Check existing state:** read every milestone once, open and closed:
  ```sh
  gh api 'repos/{o}/{r}/milestones?state=all&per_page=100' --paginate \
    --jq '.[] | {number, title, description, state}'
  ```
  Quote the path, because `?` is a glob character in zsh. Compare by exact `title`. Sort each wanted milestone into one of four groups:
  - **missing:** not present
  - **same:** present and open, with the same description (an empty or missing description counts as `""`)
  - **different:** present, with a different description
  - **closed:** present but closed
- **Command:** for each missing milestone only:
  ```sh
  gh api -X POST repos/{o}/{r}/milestones -f title="<title>" -f description="<description>" --jq .number
  ```
  A milestone that is different or closed is reported, not changed. The skill asks before updating the description or reopening it:
  ```sh
  gh api -X PATCH repos/{o}/{r}/milestones/<number> -f description="<description>"
  gh api -X PATCH repos/{o}/{r}/milestones/<number> -f state=open
  ```
- **Output:** each milestone's title and number, grouped as created, unchanged, different or closed.
- **Notes:** `gh issue create --milestone` and `gh issue edit --milestone` take the milestone's *title*, not its number.
- **Fallback:** none needed. Trackers without milestones use the `milestone:<name>` label (conventions §14).

### issue.create

- **Tier:** write
- **Inputs:** `title`, `body`, `labels`, optional `milestone` (title). Relationships are added afterwards with `issue.link`, so there's only one way of creating links.
- **Check existing state:** the calling skill first looks in the ledger and the plan's `Issue:` line. The adapter then looks on the forge for an issue carrying the same marker line in its body (for plan tasks, `Plan-Task: T-NNN`):
  ```sh
  gh issue list --repo {o}/{r} --state all --limit 1000 --json number,state,body \
    --jq '.[] | select(.body | test("(?m)^Plan-Task: T-007$")) | {number, state}'
  ```
  Don't use `gh issue list --search` for this. GitHub's search index lags behind newly created issues, so a re-run straight after a create would miss them. If one issue matches, return it instead of creating one. If more than one matches, stop and report all of them.
- **Command:**
  ```sh
  gh issue create --repo {o}/{r} --title "<title>" --body-file <file> \
    --label "<label>" --label "<label>" --milestone "<milestone title>"
  ```
  Write the body to a temporary file. The command prints the issue URL; the number is its last path segment.
- **Output:** issue number and URL, and whether it was created or found.
- **Fallback:** none needed.

### issue.update

- **Tier:** write
- **Inputs:** issue number, and any of: `title`, `body`, `labels_add`, `labels_remove`, `milestone` (title, or none to remove)
- **Check existing state:**
  ```sh
  gh issue view <n> --repo {o}/{r} --json title,body,labels,milestone,state
  ```
  Compare, and pass only what differs. If nothing differs, report "no changes" and skip the command. Compare bodies after trimming trailing whitespace, because GitHub may normalise line endings.
- **Command:** one call carrying every difference:
  ```sh
  gh issue edit <n> --repo {o}/{r} --title "<title>" --body-file <file> \
    --add-label "<label>" --remove-label "<label>" --milestone "<milestone title>"
  ```
  Use `--remove-milestone` to clear the milestone.
- **Output:** fields changed, as `name: old → new` (for the body, just "body changed").
- **Notes:** a closed issue is updated like any other, and its state is left alone. Reopening isn't part of this verb.
- **Fallback:** none needed.

### issue.link

- **Tier:** write
- **Inputs:** issue number, `relation` (`blocked-by` | `blocks` | `parent`), and the other issue's number
- **Check existing state:**
  ```sh
  gh issue view <n> --repo {o}/{r} --json blockedBy,blocking,parent \
    --jq '{blockedBy: [.blockedBy.nodes[].number], blocking: [.blocking.nodes[].number], parent: .parent.number}'
  ```
  If the link is already there, report "no changes".
- **Command:**

  | Relation | Command |
  |---|---|
  | `blocked-by` | `gh issue edit <n> --repo {o}/{r} --add-blocked-by <other>` |
  | `blocks` | `gh issue edit <n> --repo {o}/{r} --add-blocking <other>` |
  | `parent` | `gh issue edit <n> --repo {o}/{r} --parent <other>` |

  To remove a link that's no longer wanted, for example after a dependency changes in the plan, use `--remove-blocked-by`, `--remove-blocking` or `--remove-parent`. That's a separate, announced write; never part of adding.
- **Output:** links added, links already present.
- **Notes:**
  - Links are two-sided. "#2 blocked by #1" also shows up as "#1 blocking #2", and a sub-issue shows up in its parent's `subIssues`. Record each dependency from one side only: the dependent task, with `blocked-by`. Treat the other side as already present, not as a separate link to add.
  - GitHub refuses a link that would create a cycle. `scripts/check-plan.sh` rejects cycles first, so this shouldn't happen from a plan.
  - An issue can have only one parent. Setting a different parent replaces the old one, so report it as a change.
- **Fallback:** where dependencies or sub-issues aren't available (older GitHub Enterprise Server), the `gh issue edit` command fails with an unknown-field or 404 error. Then use conventions §14:
  - blocked by / blocks: add a `Depends on: #<other>` line to the body via `issue.update`, and the `blocked` label while the other issue is open
  - parent: a task-list line `- [ ] #<n>` in the parent's body

  Tell the user the fallback was used.

### issue.close

- **Tier:** write
- **Inputs:** issue number, `reason` (`completed` | `not planned`), optional comment
- **Check existing state:** `gh issue view <n> --repo {o}/{r} --json state,stateReason`. If it's already closed, report "no changes", even if the reason differs.
- **Command:**
  ```sh
  gh issue close <n> --repo {o}/{r} --reason "<reason>" --comment "<comment>"
  ```
- **Output:** issue number and reason.
- **Notes:** closing is the tracker's way of saying "done" or "dropped". Issues are never deleted (conventions §13).
- **Fallback:** none needed.

### issue.list

- **Tier:** read
- **Inputs:** optional filters: `state` (`open` | `closed` | `all`, default `open`), `labels`, `milestone`
- **Check existing state:** not applicable (this is the read).
- **Command:**
  ```sh
  gh issue list --repo {o}/{r} --state <state> --limit 1000 \
    --json number,title,state,labels,milestone,body,closedAt,url
  ```
  Add `--label <name>` once per label, and `--milestone "<title>"`, to filter.
- **Output:** for each issue: `number`, `title`, `state` (lower-cased), `labels` (names), `milestone` (title or none), `body`, `closed` (date or none), `url`. Pull requests are not included.
- **Notes:** `--limit` caps the result. If exactly 1000 come back, say the list may be incomplete.
- **Fallback:** none needed.
