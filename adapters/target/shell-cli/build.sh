#!/usr/bin/env bash
# package.build for the shell-cli target: archive a project's commands.
#
# The project's commands are the executable files in its bin/ folder.
# The archive:
#   <name>-<version>/
#     install.sh
#     bin/<command> ...
#     VERSION
#     LICENSE, README.md     if the project has them
#
# <name> is the project's repo name, from .project/config.yml.
#
# Usage: build.sh <version> <out-dir> [source-root]
#   version      e.g. v0.1.0
#   out-dir      where the archive is written (created if missing)
#   source-root  a clean copy of the tagged commit (default: the current directory)
# Prints the archive's path. Exit status: 0 on success, 1 otherwise.

set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: build.sh <version> <out-dir> [source-root]" >&2; exit 1; }
version=$1 out=$2 src="${3:-.}"
here="$(cd "$(dirname "$0")" && pwd)"

[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like v1.2.3, got: $version" >&2; exit 1; }
[[ -f $src/.project/config.yml ]] || { echo "error: $src/.project/config.yml not found" >&2; exit 1; }
name=$(sed -n 's/^repo:[[:space:]]*//p' "$src/.project/config.yml" | head -1)
[[ $name =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: no usable repo name in $src/.project/config.yml" >&2; exit 1; }

count=0
for f in "$src"/bin/*; do [[ -f $f && -x $f ]] && count=$((count + 1)); done
(( count > 0 )) || { echo "error: no executable commands in $src/bin/" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
top="$work/$name-$version"
mkdir -p "$top/bin"
for f in "$src"/bin/*; do [[ -f $f && -x $f ]] && cp -p "$f" "$top/bin/"; done
for f in LICENSE README.md; do [[ -f $src/$f ]] && cp "$src/$f" "$top/"; done
printf '%s %s\n' "$name" "$version" > "$top/VERSION"
cp "$here/install.sh" "$top/install.sh"
chmod +x "$top/install.sh"

mkdir -p "$out"
archive="$(cd "$out" && pwd)/$name-$version.tar.gz"
tar -czf "$archive" -C "$work" "$name-$version"
echo "$archive"
