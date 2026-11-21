# Target adapter: agent-skills

Packages and installs a set of agent skills in the Agent Skills format: folders holding a `SKILL.md`, which Claude Code, Codex, GitHub Copilot, Gemini CLI and other agents load from a skills folder (decision 0013). This is the target of the idea-to-release repository itself.

Skills call the verbs by name. The commands live in `adapters/target/agent-skills/`. Every Target verb in `conventions.md` §2 has a section here, and `scripts/check-adapters.sh` checks it.

## What's shipped

One archive per release, `idea-to-release-<version>.tar.gz`. Its layout is the installed layout (decision 0014):

```
idea-to-release-<version>/
  install.sh
  skills/
    <skill>/SKILL.md          one folder per skill
    idea-to-release/          shared files; no SKILL.md, so it isn't loaded as a skill
      conventions.md
      adapters/               forge, tracker and target adapters, with their scripts
      scripts/check-*.sh
      LICENSE
      VERSION
```

## Prerequisites

- bash 3.2 or later, `tar` and `gzip`: macOS and Linux defaults.
- `git`, to take a clean copy of the tagged commit.

---

## Target

### package.build

- **Tier:** write (local files only)
- **Inputs:** version (`v<major>.<minor>.<patch>`) and the tag it was cut from
- **Check existing state:** the archive file. If `<out>/idea-to-release-<version>.tar.gz` exists from an earlier run, build again anyway, since building is cheap and only `package.verify`'s result counts.
- **Command:** build from a clean copy of the tag, never from the working tree, so the archive holds exactly what was tagged:
  ```sh
  src=$(mktemp -d); git archive <tag> | tar -x -C "$src"
  adapters/target/agent-skills/build.sh <version> <out> "$src"
  ```
- **Output:** the archive's path. It's the only artifact, and `release.draft` attaches it.

### package.verify

- **Tier:** read (works in a temporary folder)
- **Inputs:** the archive
- **Check existing state:** not applicable.
- **Command:**
  ```sh
  adapters/target/agent-skills/verify.sh <archive>
  ```
  It installs into a throw-away project with `install.sh --agent claude` and checks:
  - every skill folder has a `SKILL.md` whose `name` matches the folder
  - each skill says where the shared files are, and they exist at `../idea-to-release/`
  - the shared folder has no `SKILL.md`
  - the installed `check-adapters.sh` passes
  - a second install replaces the first, `--dest` works, and a folder that idea-to-release didn't install is refused
- **Output:** `ok: … installs N skill(s); M checks passed`, or one `FAIL` line per problem and exit 1. A failure is a release gate: don't draft or publish.

### package.publish

- **Tier:** admin
- **Inputs:** the archive and the release
- **Check existing state:** not applicable.
- **Command:** none. The archive is published with the forge release: `release.draft` attaches it, and `release.publish` makes it public.
- **Output:** "published with the forge release".
- **Notes:** no other channel yet. A Claude Code plugin marketplace entry, or another tool's skill registry, would be added here (decision 0013).

### install.describe

- **Tier:** read
- **Inputs:** version and the release URL
- **Command:** print this text, with `<version>` and `<url>` filled in:
  ```markdown
  Download `idea-to-release-<version>.tar.gz` from <url>, then:

      tar -xzf idea-to-release-<version>.tar.gz
      cd idea-to-release-<version>
      ./install.sh --agent claude --project /path/to/your/project   # or --user, for every project
      ./install.sh --dest /path/to/skills-folder                     # any other agent

  Each skill goes in its own folder, and the shared files go in `idea-to-release/` beside them. Re-running replaces an earlier install.
  ```
- **Output:** the Markdown, for the release notes and the README.
