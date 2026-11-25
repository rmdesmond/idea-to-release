#!/usr/bin/env bash
# package.build for the cmake-binary target: build a CMake project, install
# it into a staging prefix, and archive that.
#
# The source is copied into a temporary folder and built there (Release, with
# BUILD_TESTING=OFF), so nothing in the archive can depend on a path in the
# source tree: that copy is removed afterwards. `cmake --install` must produce
# only bin/ (the commands) and share/<name>/ (their files); anything else,
# such as a bundled dependency's headers or libraries, is an error.
#
# The archive, <name>-<version>-<os>-<arch>.tar.gz:
#   <name>-<version>-<os>-<arch>/
#     install.sh
#     bin/<command> ...
#     share/<name>/...       if the project installs files there
#     VERSION                "<name> <version> <os>-<arch>"
#     README.md              the release README (decision 0023), from describe.sh
#     LICENSE                if the project has one
#     docs/tutorial.md       if the project has one (decision 0020)
#
# <name> is the project's repo name, from .project/config.yml.
#
# Usage: build.sh <version> <out-dir> [source-root] [release-url]
#   version      e.g. v0.1.0
#   out-dir      where the archive is written (created if missing)
#   source-root  a clean copy of the tagged commit (default: the current directory)
#   release-url  the release's page, for the README (default: a placeholder)
# Prints the archive's path. Exit status: 0 on success, 1 otherwise.

set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: build.sh <version> <out-dir> [source-root] [release-url]" >&2; exit 1; }
version=$1 out=$2 src="${3:-.}" url="${4:-the release page}"
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091  # platform.sh, next to this script
. "$here/platform.sh"

[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like v1.2.3, got: $version" >&2; exit 1; }
[[ -f $src/.project/config.yml ]] || { echo "error: $src/.project/config.yml not found" >&2; exit 1; }
[[ -f $src/CMakeLists.txt ]] || { echo "error: $src/CMakeLists.txt not found: not a CMake project" >&2; exit 1; }
command -v cmake >/dev/null || { echo "error: cmake not found" >&2; exit 1; }
name=$(sed -n 's/^repo:[[:space:]]*//p' "$src/.project/config.yml" | head -1)
[[ $name =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: no usable repo name in $src/.project/config.yml" >&2; exit 1; }

platform="$(platform_os)-$(platform_arch)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/src"
cp -R "$src/." "$work/src/"

jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
log="$work/build.log"
step() {
  if ! "$@" >>"$log" 2>&1; then
    echo "error: '$*' failed; the end of its output:" >&2
    tail -n 40 "$log" >&2
    exit 1
  fi
}
step cmake -S "$work/src" -B "$work/build" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
step cmake --build "$work/build" --parallel "$jobs"
top="$work/$name-$version-$platform"
step cmake --install "$work/build" --prefix "$top"

# Only bin/ and share/<name>/: install.sh installs nothing else.
extra=""
for p in "$top"/* "$top"/.[!.]*; do
  [[ -e $p ]] || continue
  case ${p#"$top"/} in
    bin) ;;
    share)
      for q in "$top"/share/* "$top"/share/.[!.]*; do
        [[ -e $q ]] || continue
        [[ ${q#"$top"/} == "share/$name" ]] || extra="$extra ${q#"$top"/}"
      done
      ;;
    *) extra="$extra ${p#"$top"/}" ;;
  esac
done
[[ -z $extra ]] || { echo "error: cmake --install put files outside bin/ and share/$name/:$extra (turn off the install rules of bundled dependencies)" >&2; exit 1; }
count=0
for f in "$top"/bin/*; do [[ -f $f && -x $f ]] && count=$((count + 1)); done
(( count > 0 )) || { echo "error: cmake --install put no executable commands in bin/" >&2; exit 1; }

[[ -f $src/LICENSE ]] && cp "$src/LICENSE" "$top/"
"$here/describe.sh" readme "$version" "$url" "$src" "$top" > "$work/README.md"
mv "$work/README.md" "$top/README.md"
if [[ -f $src/docs/tutorial.md ]]; then mkdir -p "$top/docs" && cp "$src/docs/tutorial.md" "$top/docs/"; fi
printf '%s %s %s\n' "$name" "$version" "$platform" > "$top/VERSION"
cp "$here/install.sh" "$top/install.sh"
chmod +x "$top/install.sh"

mkdir -p "$out"
archive="$(cd "$out" && pwd)/$name-$version-$platform.tar.gz"
tar -czf "$archive" -C "$work" "$name-$version-$platform"
echo "$archive"
