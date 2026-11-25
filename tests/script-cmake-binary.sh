#!/usr/bin/env bash
# The cmake-binary target: a minimal CMake project's archive passes
# package.verify, including its smoke test from two prefixes, and each broken
# project fails the build or the verify.
#
# Needs cmake and a C compiler. Without them it skips, except in CI (CI is
# set), where it fails: the CI runner has both.
#
# The fixture files below are written with single quotes on purpose: their
# $1 and $(...) belong to the generated files, not to this script.
# shellcheck disable=SC2016
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
t="$root/adapters/target/cmake-binary"
# shellcheck disable=SC1091  # the adapter's platform.sh
. "$t/platform.sh"

if ! command -v cmake >/dev/null || ! command -v cc >/dev/null; then
  if [[ -n ${CI:-} ]]; then echo "cmake or cc not found"; exit 1; fi
  echo "skip: cmake or cc not found"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
platform="$(platform_os)-$(platform_arch)"

# The fixture: a compiled command, hello, and a script, greet, that reads its
# greeting from share/<repo>/ relative to its own location.
p="$work/project"
mkdir -p "$p/.project" "$p/src" "$p/data" "$p/tests"
printf 'forge: github\nrepo: hello-bin\ntarget: cmake-binary\n' > "$p/.project/config.yml"
cat > "$p/CMakeLists.txt" <<'END'
cmake_minimum_required(VERSION 3.16)
project(hello_bin LANGUAGES C)
add_executable(hello src/hello.c)
install(TARGETS hello RUNTIME DESTINATION bin)
install(PROGRAMS src/greet DESTINATION bin)
install(FILES data/greeting.txt DESTINATION share/hello-bin)
END
cat > "$p/src/hello.c" <<'END'
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
  if (argc > 1 && strcmp(argv[1], "--help") == 0) { puts("usage: hello [name]"); return 0; }
  printf("hello, %s\n", argc > 1 ? argv[1] : "world");
  return 0;
}
END
printf '#!/usr/bin/env bash\n[ "${1:-}" = --help ] && { echo "usage: greet"; exit 0; }\ncat "$(dirname "$0")/../share/hello-bin/greeting.txt"\n' > "$p/src/greet"
chmod +x "$p/src/greet"
printf 'salaam\n' > "$p/data/greeting.txt"
printf 'MIT\n' > "$p/LICENSE"
printf '# hello-bin\n\nSays hello, compiled.\n' > "$p/README.md"
printf '#!/usr/bin/env bash\nset -e\n[ "$(hello you)" = "hello, you" ]\n[ "$(greet)" = salaam ]\n' > "$p/tests/smoke.sh"

archive=$("$t/build.sh" v1.2.3 "$work/out" "$p" https://example.com/r/v1.2.3)
[[ $(basename "$archive") == "hello-bin-v1.2.3-$platform.tar.gz" ]] || { echo "unexpected archive name: $archive"; exit 1; }
listing=$(tar -tzf "$archive")
for f in install.sh bin/hello bin/greet share/hello-bin/greeting.txt VERSION README.md LICENSE; do
  grep -qx "hello-bin-v1.2.3-$platform/$f" <<<"$listing" || { echo "the archive lacks $f:"; echo "$listing"; exit 1; }
done
out=$("$t/verify.sh" "$archive" "$p") || { echo "verify failed on a good build: $out"; exit 1; }
grep -q 'tests/smoke.sh passed, in two prefixes' <<<"$out" || { echo "smoke test didn't run: $out"; exit 1; }

# The release README: four sections, Usage from the built commands' --help.
readme=$(tar -xzOf "$archive" "hello-bin-v1.2.3-$platform/README.md")
for h in '# hello-bin v1.2.3' '## Version' '## About' '## Install' '## Usage' 'Says hello, compiled.' '$ hello --help' 'usage: hello [name]' '$ greet --help'; do
  grep -qxF -- "$h" <<<"$readme" || { echo "the release README lacks: $h"; echo "$readme"; exit 1; }
done
grep -qF "hello-bin-v1.2.3-$platform.tar.gz\` from https://example.com/r/v1.2.3" <<<"$readme" || { echo "Install doesn't name the archive and URL"; echo "$readme"; exit 1; }

# install.sh: a re-install drops commands the new version no longer ships.
mkdir "$work/x" && tar -xzf "$archive" -C "$work/x"
x="$work/x/hello-bin-v1.2.3-$platform"
"$x/install.sh" --prefix "$work/pfx" >/dev/null
rm "$x/bin/greet"
"$x/install.sh" --prefix "$work/pfx" >/dev/null
[[ ! -e $work/pfx/bin/greet && -x $work/pfx/bin/hello ]] || { echo "a re-install kept a command the archive no longer has"; exit 1; }

# Files outside bin/ and share/<repo>/ stop the build.
cp -R "$p" "$work/leaky"
printf 'install(FILES src/hello.c DESTINATION include)\n' >> "$work/leaky/CMakeLists.txt"
if out=$("$t/build.sh" v1.2.3 "$work/out2" "$work/leaky" 2>&1); then echo "build accepted files outside bin/ and share/"; exit 1; fi
grep -q 'outside bin/ and share/hello-bin/: include' <<<"$out" || { echo "unexpected build output: $out"; exit 1; }

# A compile error stops the build, with the compiler's output.
cp -R "$p" "$work/broken"
printf 'this is not C\n' >> "$work/broken/src/hello.c"
if out=$("$t/build.sh" v1.2.3 "$work/out3" "$work/broken" 2>&1); then echo "build accepted a compile error"; exit 1; fi
grep -q "failed; the end of its output" <<<"$out" || { echo "unexpected build output: $out"; exit 1; }

# A command that reads its files from a fixed path, not from its own location, fails verify.
cp -R "$p" "$work/fixed"
printf '#!/usr/bin/env bash\n[ "${1:-}" = --help ] && { echo "usage: greet"; exit 0; }\ncat "%s/share/hello-bin/greeting.txt"\n' "$work/fixed-prefix" > "$work/fixed/src/greet"
a4=$("$t/build.sh" v1.2.4 "$work/out4" "$work/fixed")
if out=$("$t/verify.sh" "$a4" "$work/fixed" 2>&1); then echo "verify accepted a command with a fixed path"; exit 1; fi
grep -q 'tests/smoke.sh failed against the installed commands' <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }

# A command whose --help fails stops the build.
cp -R "$p" "$work/nohelp"
printf '#!/usr/bin/env bash\nexit 3\n' > "$work/nohelp/src/greet"
if "$t/build.sh" v1.2.3 "$work/out5" "$work/nohelp" >/dev/null 2>&1; then echo "build accepted a command whose --help fails"; exit 1; fi

# A tutorial is shipped, and verify checks the copy.
mkdir -p "$p/docs" && printf '# Tutorial\n' > "$p/docs/tutorial.md"
a6=$("$t/build.sh" v1.2.5 "$work/out6" "$p")
"$t/verify.sh" "$a6" "$p" >/dev/null || { echo "verify failed with a tutorial"; exit 1; }
printf '# Changed\n' > "$p/docs/tutorial.md"
if "$t/verify.sh" "$a6" "$p" >/dev/null 2>&1; then echo "verify accepted a stale tutorial"; exit 1; fi

echo "ok"
