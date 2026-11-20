# Tracker adapter: GitHub Issues

Translates the neutral tracker verbs in `conventions.md` §2 into GitHub commands. Prerequisites, repository resolution and error handling are the same as in [`../forge/github.md`](../forge/github.md).

Every tracker verb has a section here. A verb that is not yet available says `Status: not yet implemented`. `scripts/check-adapters.sh` checks that no verb is missing.

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

Status: not yet implemented

### issue.create

Status: not yet implemented

### issue.update

Status: not yet implemented

### issue.link

Status: not yet implemented

### issue.close

Status: not yet implemented

### issue.list

Status: not yet implemented
