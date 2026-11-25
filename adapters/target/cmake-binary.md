# Target adapter: cmake-binary

Packages and installs a compiled project built with CMake: the commands its `cmake --install` puts in `bin/`, and the files they need in `share/<repo>/` (data, web assets). They're installed by copying both into a prefix, `~/.local` by default. Use it for C and C++ command-line tools whose commands find their files relative to their own location. A Homebrew formula or a distribution package would be a target of its own (decision 0013).

Each archive is built on, and for, one platform: the machine that runs `package.build`. A release from a Mac carries a macOS archive. People on other systems build from source.

Skills call the verbs by name. The commands live in `adapters/target/cmake-binary/`. Every Target verb in `conventions.md` §2 has a section here, and `scripts/check-adapters.sh` checks it.

## What's shipped

One archive per release, `<repo>-<tag>-<os>-<arch>.tar.gz`. `<repo>` is taken from `.project/config.yml` and `<tag>` is the release tag, prefix included. `<os>` is `macos` or `linux` and `<arch>` is `arm64` or `x86_64`: `qtool-v0.1.0-macos-arm64.tar.gz`.

```
<repo>-<tag>-<os>-<arch>/
  install.sh
  bin/<command> ...       what cmake --install put in bin/
  share/<repo>/...        what cmake --install put in share/<repo>/, if anything
  VERSION                 "<repo> <tag> <os>-<arch>"
  README.md               the release README (decision 0023), not the project's own
  LICENSE                 if the project has one
  docs/tutorial.md        if the project has one (decision 0020)
```

## What the project provides

- **A top-level `CMakeLists.txt`** that builds in Release with `-DBUILD_TESTING=OFF`, using only what's in the repository, or what CMake fetches at configure time.
- **Install rules** (`install(...)`) that put the commands in `bin/` and their files in `share/<repo>/`, and nothing else. A bundled dependency's install rules must be turned off (for example `set(UTF8PROC_INSTALL OFF)`), or `package.build` stops and names what it found.
- **Relocatable commands:** each one finds its files from its own path (`<bin>/../share/<repo>/`), not from a path fixed at build time. `package.verify` installs into two prefixes to check it.
- **A `--help` option on every command,** which exits 0. The release README's Usage section is its output.
- **A summary,** for the release README's About section: the plan's first paragraph, or the README's.
- **Optionally, `docs/tutorial.md`:** the project's tutorial, written by write-tutorial. It's shipped as it is.
- **Optionally, `tests/smoke.sh`:** a short test of the *installed* commands. `package.verify` runs it from an empty folder, with the installed commands first on `PATH`, so it can't reach the build's copies. It should exit 0 when they work.

## Prerequisites

- CMake, and the project's compilers.
- bash 3.2 or later, `tar` and `gzip`: macOS and Linux defaults.
- `git`, to take a clean copy of the tagged commit.
- Network access, if the project's CMake fetches its dependencies.

---

## Target

### package.build

- **Tier:** write (local files only)
- **Inputs:** version (`v<major>.<minor>.<patch>`), the tag it was cut from, and the release's page, for the README
- **Check existing state:** none needed. Building is repeatable, so build again; only `package.verify`'s result counts.
- **Command:** build from a clean copy of the tag, never from the working tree:
  ```sh
  src=$(mktemp -d); git archive <tag> | tar -x -C "$src"
  <skill-set>/adapters/target/cmake-binary/build.sh <version> <out> "$src" <release-url>
  ```
  It copies the source into its own temporary folder, configures it (`-DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF`), builds it, and runs `cmake --install` into a staging prefix. That copy is deleted afterwards, so nothing in the archive can rely on a source path. It then writes the release README with `describe.sh readme`: Version, About, Install (`install.describe`) and Usage (`usage.describe`, run against the staged commands).
  `<skill-set>` is where the idea-to-release files are: `../idea-to-release/` from an installed skill (conventions §3).
- **Output:** the archive's path. It's the only artifact, and `release.draft` attaches it.
- **Errors:**
  - no `.project/config.yml`, no `repo` name, or no `CMakeLists.txt`
  - a failed configure, build or install (with the end of its output)
  - installed files outside `bin/` and `share/<repo>/`
  - no commands in `bin/`
  - a command whose `--help` fails
  - no summary for About

### package.verify

- **Tier:** read (works in a temporary folder)
- **Inputs:** the archive, and the clean copy of the tag (for `tests/smoke.sh`)
- **Check existing state:** not applicable.
- **Command:**
  ```sh
  <skill-set>/adapters/target/cmake-binary/verify.sh <archive> "$src"
  ```
  It installs into a throw-away prefix and checks:
  - every command is installed and executable, and `share/<repo>/` matches the archive's
  - `tests/smoke.sh` passes, if the project has one
  - it passes again from a second prefix, with the first moved away, so the commands don't depend on where they were first installed
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
  <skill-set>/adapters/target/cmake-binary/describe.sh install <tag> <url> "$src"
  ```
  It prints where to download `<repo>-<tag>-<os>-<arch>.tar.gz` for this machine's platform, what to do on another system, and how to run `install.sh` with or without `--prefix`.
- **Output:** the Markdown, for the release notes and the release README.

### usage.describe

- **Tier:** read
- **Inputs:** the installed commands: a staging prefix, an unpacked archive or an install prefix
- **Command:**
  ```sh
  <skill-set>/adapters/target/cmake-binary/describe.sh usage <installed-root>
  ```
  It runs each command in `<installed-root>/bin/` with `--help`, and prints the real output, one section per command. `package.build` runs it against the staged build, and adds a pointer to `docs/tutorial.md` if the project has one.
- **Output:** the Markdown, for the release README's Usage section. A command whose `--help` fails is an error.
