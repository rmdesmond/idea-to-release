# Target adapter: agent-skills

Packages and installs a set of agent skills in the Agent Skills format: folders holding a `SKILL.md`, which Claude Code, Codex, GitHub Copilot, Gemini CLI and other agents load from a skills folder (decision 0013). This is the target of the idea-to-release repository itself.

**Limit:** today the scripts package the idea-to-release repository's own layout (its name, shared folder and files). Packaging another project's skills is #84.

Skills call the verbs by name. The commands live in `adapters/target/agent-skills/`. Every Target verb in `conventions.md` §2 has a section here, and `scripts/check-adapters.sh` checks it.

## What's shipped

Two channels per release:

- **The Claude Code plugin `i2r`** (decision 0019). The repository root is the plugin and its own marketplace: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. The marketplace's entry points at this repository at the release tag (`"ref": "v<version>"`), so users get released versions only. `cut-release` bumps both manifests through `release.version_files`.
- **An archive for every agent**, described below.

One archive per release, `idea-to-release-<version>.tar.gz`. Its layout is the installed layout (decision 0014):

```
idea-to-release-<version>/
  install.sh
  README.md                   the release README (decision 0023)
  skills/
    <skill>/SKILL.md          one folder per skill
    idea-to-release/          shared files; no SKILL.md, so it isn't loaded as a skill
      conventions.md
      adapters/               forge, tracker and target adapters, with their scripts
      scripts/check-*.sh
      LICENSE
      VERSION
  docs/tutorial.md          if the repository has one (decision 0020)
```

## Prerequisites

- bash 3.2 or later, `tar` and `gzip`: macOS and Linux defaults.
- `git`, to take a clean copy of the tagged commit.

---

## Target

### package.build

- **Tier:** write (local files only)
- **Inputs:** version (`v<major>.<minor>.<patch>`), the tag it was cut from, and the release's page, for the README
- **Check existing state:** the archive file. If `<out>/idea-to-release-<version>.tar.gz` exists from an earlier run, build again anyway, since building is cheap and only `package.verify`'s result counts.
- **Command:** build from a clean copy of the tag, never from the working tree, so the archive holds exactly what was tagged:
  ```sh
  src=$(mktemp -d); git archive <tag> | tar -x -C "$src"
  adapters/target/agent-skills/build.sh <version> <out> "$src" <release-url>
  ```
  It writes the release README at the top of the archive with `describe.sh readme`: Version, About (the plan's summary), Install (`install.describe`) and Usage (`usage.describe`).
- **Output:** the archive's path. It's the only artifact, and `release.draft` attaches it.

### package.verify

- **Tier:** read (works in a temporary folder)
- **Inputs:** the archive
- **Check existing state:** not applicable.
- **Command:**
  ```sh
  adapters/target/agent-skills/verify.sh <archive> <clean copy of the tag>
  ```
  It installs into a throw-away project with `install.sh --agent claude` and checks:
  - every skill folder has a `SKILL.md` whose `name` matches the folder
  - each skill says where the shared files are, and they exist at `../idea-to-release/`
  - the shared folder has no `SKILL.md`
  - the installed `check-adapters.sh` passes
  - a second install replaces the first; `--user`, `--dest` and each `--agent` install where they should
  - name clashes (decision 0015): a same-named folder idea-to-release didn't install is never replaced, even with `--force`, and a same-named personal skill stops a project install unless `--force` is given
  - every install runs with a throw-away `HOME`, so the real personal skills never affect the result
  - the archive's `README.md` has the Version, About, Install and Usage sections
  - with the tag's copy: the archive ships its `docs/tutorial.md` unchanged, if it has one
  - with the tag's copy: `plugin.json`'s `version` and the marketplace's `ref` match the archive's version, and `claude plugin validate --strict` passes on it, when `claude` is installed
- **Output:** `ok: … installs N skill(s); M checks passed`, or one `FAIL` line per problem and exit 1. A failure is a release gate: don't draft or publish.

### package.publish

- **Tier:** admin
- **Inputs:** the archive and the release
- **Check existing state:** not applicable.
- **Command:** none.
  - **The archive** is published with the forge release: `release.draft` attaches it, and `release.publish` makes it public.
  - **The plugin** is published by the tag itself. The release change request bumped the manifests, so once the tag exists, the marketplace on the default branch points at it, and `claude plugin marketplace update` finds the new version.
- **Output:** "published with the forge release; plugin i2r <version> follows the tag".

### install.describe

- **Tier:** read
- **Inputs:** version and the release URL
- **Command:**
  ```sh
  adapters/target/agent-skills/describe.sh install <version> <url>
  ```
  It prints two parts: **Claude Code**, installing the plugin `i2r` from this repository's marketplace and updating it; and **other agents**, downloading `idea-to-release-<version>.tar.gz` from `<url>` and running `install.sh` with `--agent` or `--dest`.
- **Output:** the Markdown, for the release notes and the release README.

### usage.describe

- **Tier:** read
- **Inputs:** the clean copy of the tag
- **Command:**
  ```sh
  adapters/target/agent-skills/describe.sh usage "$src"
  ```
  It lists each skill from its `SKILL.md`: its name, how to invoke it in Claude Code (`/i2r:<name>`, with the plugin's name from `plugin.json`), and the first sentence of its description. Then where a new project starts, and a pointer to `docs/tutorial.md` if there is one.
- **Output:** the Markdown, for the release README's Usage section.
