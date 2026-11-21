#!/usr/bin/env bash
# The shell-cli target: a minimal project's archive passes package.verify,
# including its smoke test, and a broken command fails it.
#
# The fixture scripts below are written with single quotes on purpose: their
# $1 and $(...) belong to the generated scripts, not to this one.
# shellcheck disable=SC2016
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
t="$root/adapters/target/shell-cli"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

p="$work/project"
mkdir -p "$p/.project" "$p/bin" "$p/tests"
printf 'forge: github\nrepo: hello-cli\n' > "$p/.project/config.yml"
printf '#!/usr/bin/env bash\necho "hello, ${1:-world}"\n' > "$p/bin/hello"
chmod +x "$p/bin/hello"
printf 'MIT\n' > "$p/LICENSE"
printf '#!/usr/bin/env bash\nset -e\n[ "$(hello you)" = "hello, you" ]\n' > "$p/tests/smoke.sh"

archive=$("$t/build.sh" v1.2.3 "$work/out" "$p")
[[ $(basename "$archive") == hello-cli-v1.2.3.tar.gz ]] || { echo "unexpected archive name: $archive"; exit 1; }
out=$("$t/verify.sh" "$archive" "$p") || { echo "verify failed on a good build: $out"; exit 1; }
grep -q 'tests/smoke.sh passed' <<<"$out" || { echo "smoke test didn't run: $out"; exit 1; }

# A command that's broken once installed: verify must catch it through the smoke test.
printf '#!/usr/bin/env bash\necho "goodbye"\n' > "$p/bin/hello"
archive=$("$t/build.sh" v1.2.4 "$work/out" "$p")
if out=$("$t/verify.sh" "$archive" "$p" 2>&1); then echo "verify accepted a broken command"; exit 1; fi
grep -q 'tests/smoke.sh failed against the installed commands' <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }
