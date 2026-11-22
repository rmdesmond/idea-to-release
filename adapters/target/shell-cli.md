# Target adapter: shell-cli

Packages and installs a project's command-line tools: the executable files in its `bin/` folder, such as shell scripts. They're installed by copying them into a `bin` folder on the user's `PATH`. Use it for projects whose commands run as they are, with no compile step and no package manager. A compiled tool, a Homebrew formula or an npm package would be a target of its own (decision 0013).

Skills call the verbs by name. The commands live in `adapters/target/shell-cli/`. Every Target verb in `conventions.md` §2 has a section here, and `scripts/check-adapters.sh` checks it.

## What's shipped

One archive per release, `<repo>-<tag>.tar.gz`, with `<repo>` taken from `.project/config.yml` and `<tag>` the release tag, prefix included: `dedupe-v0.1.0.tar.gz`.

```
<repo>-<tag>/
  install.sh
  bin/<command> ...       every executable file in the project's bin/
  VERSION                 "<repo> <tag>"
  README.md               the release README (decision 0023), not the project's own
  LICENSE                 if the project has one
  docs/tutorial.md        if the project has one (decision 0020)
```

## What the project provides

- **`bin/`:** the commands, executable, each with no dependency on the rest of the repository once installed.
- **A `--help` option on every command,** which exits 0. The release README's Usage section is its output.
- **A summary,** for the release README's About section: the plan's first paragraph, or the README's.
- **Optionally, `docs/tutorial.md`:** the project's tutorial, written by write-tutorial. It's shipped as it is.
- **Optionally, `tests/smoke.sh`:** a short test of the *installed* commands. `package.verify` runs it from an empty folder, with the installed commands first on `PATH`, so it can't reach the repository's own copies. It should exit 0 when they work.

## Prerequisites

- bash 3.2 or later, `tar` and `gzip`: macOS and Linux defaults.
- `git`, to take a clean copy of the tagged commit.

---

## Target

### package.build

- **Tier:** write (local files only)
- **Inputs:** version (`v<major>.<minor>.<patch>`), the tag it was cut from, and the release's page, for the README
- **Check existing state:** none needed. Building is cheap, so build again, and only `package.verify`'s result counts.
- **Command:** build from a clean copy of the tag, never from the working tree:
  ```sh
  src=$(mktemp -d); git archive <tag> | tar -x -C "$src"
  <skill-set>/adapters/target/shell-cli/build.sh <version> <out> "$src" <release-url>
  ```
  It writes the release README at the top of the archive with `describe.sh readme`: Version, About, Install (`install.describe`) and Usage (`usage.describe`).
  `<skill-set>` is where the idea-to-release files are: `../idea-to-release/` from an installed skill (conventions §3).
- **Output:** the archive's path. It's the only artifact, and `release.draft` attaches it.
- **Errors:** no `.project/config.yml` or `repo` name; no executable files in `bin/`; a command whose `--help` fails; no summary for About.

### package.verify

- **Tier:** read (works in a temporary folder)
- **Inputs:** the archive, and the clean copy of the tag (for `tests/smoke.sh`)
- **Check existing state:** not applicable.
- **Command:**
  ```sh
  <skill-set>/adapters/target/shell-cli/verify.sh <archive> "$src"
  ```
  It installs into a throw-away prefix and checks:
  - every command is installed and executable
  - `tests/smoke.sh` passes, if the project has one
  - a second install replaces the first
  - a file another package installed is never replaced
  - the archive ships the project's `docs/tutorial.md` unchanged, if it has one
  - the archive's `README.md` has the Version, About, Install and Usage sections
- **Output:** `ok: … installs N command(s); …; M checks passed`, or one `FAIL` line per problem and exit 1. A failure is a release gate: don't draft or publish.

### package.publish

- **Tier:** admin
- **Inputs:** the archive and the release
- **Check existing state:** not applicable.
- **Command:** none. The archive is published with the forge release: `release.draft` attaches it, and `release.publish` makes it public.
- **Output:** "published with the forge release".

### install.describe

- **Tier:** read
- **Inputs:** the repo name, the tag (`v0.1.0`) and the release URL
- **Command:**
  ```sh
  <skill-set>/adapters/target/shell-cli/describe.sh install <tag> <url> "$src"
  ```
  It prints where to download `<repo>-<tag>.tar.gz`, and how to run `install.sh` with or without `--prefix`.
- **Output:** the Markdown, for the release notes and the release README.

### usage.describe

- **Tier:** read
- **Inputs:** the clean copy of the tag
- **Command:**
  ```sh
  <skill-set>/adapters/target/shell-cli/describe.sh usage "$src"
  ```
  It runs each command in `bin/` with `--help` from the clean copy, and prints the real output, one section per command, plus a pointer to `docs/tutorial.md` if the project has one.
- **Output:** the Markdown, for the release README's Usage section. A command whose `--help` fails is an error.
