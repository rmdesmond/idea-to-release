#!/usr/bin/env bash
# package.build for the agent-skills target: build the release archive.
#
# The archive's layout is the installed layout (conventions §3, decision 0014):
#   idea-to-release-<version>/
#     install.sh
#     skills/<skill>/SKILL.md ...
#     skills/idea-to-release/     conventions.md, adapters/, scripts/check-*.sh,
#                                 LICENSE, VERSION (no SKILL.md: not a skill)
#     docs/tutorial.md            if the repository has one (decision 0020)
#
# Usage: build.sh <version> <out-dir> [source-root]
#   version      e.g. v0.1.0
#   out-dir      where the archive is written (created if missing)
#   source-root  a clean copy of the tagged commit (default: this repository).
#                release builds from `git archive <tag>`, never a working tree.
# Prints the archive's path. Exit status: 0 on success, 1 otherwise.

set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: build.sh <version> <out-dir> [source-root]" >&2; exit 1; }
version=$1 out=$2
src="${3:-$(cd "$(dirname "$0")/../../.." && pwd)}"

[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like v1.2.3, got: $version" >&2; exit 1; }
for f in conventions.md LICENSE skills adapters scripts adapters/target/agent-skills/install.sh; do
  [[ -e "$src/$f" ]] || { echo "error: $src/$f not found" >&2; exit 1; }
done

name="idea-to-release-$version"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
top="$work/$name"
mkdir -p "$top/skills/idea-to-release/scripts"

count=0
for d in "$src"/skills/*/; do
  [[ -f "$d/SKILL.md" ]] || continue
  cp -R "$d" "$top/skills/$(basename "$d")"
  count=$((count + 1))
done
(( count > 0 )) || { echo "error: no skills found under $src/skills" >&2; exit 1; }

shared="$top/skills/idea-to-release"
cp "$src/conventions.md" "$src/LICENSE" "$shared/"
cp -R "$src/adapters" "$shared/adapters"
cp "$src"/scripts/check-*.sh "$shared/scripts/"
printf '%s\n' "$version" > "$shared/VERSION"
cp "$src/adapters/target/agent-skills/install.sh" "$top/install.sh"
if [[ -f $src/docs/tutorial.md ]]; then mkdir -p "$top/docs" && cp "$src/docs/tutorial.md" "$top/docs/"; fi
chmod +x "$top/install.sh" "$shared"/scripts/*.sh

mkdir -p "$out"
archive="$(cd "$out" && pwd)/$name.tar.gz"
tar -czf "$archive" -C "$work" "$name"
echo "$archive"
