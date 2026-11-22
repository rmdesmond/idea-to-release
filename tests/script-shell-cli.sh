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
printf '# hello-cli\n\n> A badge line, skipped.\n\nSays hello to whoever you name.\n' > "$p/README.md"
printf '#!/usr/bin/env bash\nset -e\n[ "$(hello you)" = "hello, you" ]\n' > "$p/tests/smoke.sh"

archive=$("$t/build.sh" v1.2.3 "$work/out" "$p")
[[ $(basename "$archive") == hello-cli-v1.2.3.tar.gz ]] || { echo "unexpected archive name: $archive"; exit 1; }
out=$("$t/verify.sh" "$archive" "$p") || { echo "verify failed on a good build: $out"; exit 1; }
grep -q 'tests/smoke.sh passed' <<<"$out" || { echo "smoke test didn't run: $out"; exit 1; }

# The release README (decision 0023): four sections, About from the README
# when there's no plan, and Usage from the command's real --help output.
readme=$(tar -xzOf "$archive" hello-cli-v1.2.3/README.md)
for h in '# hello-cli v1.2.3' '## Version' '## About' '## Install' '## Usage' 'Says hello to whoever you name.' '$ hello --help' 'hello, --help'; do
  grep -qxF -- "$h" <<<"$readme" || { echo "the release README lacks: $h"; echo "$readme"; exit 1; }
done
# With a plan, About is the plan's summary instead.
mkdir -p "$p/docs/plan" && printf '# Plan: hello-cli\n\nStatus: accepted 2026-11-22\n\nA friendly greeter.\n\n## Scope\n' > "$p/docs/plan/PLAN.md"
a2=$("$t/build.sh" v1.2.3 "$work/out2" "$p" https://example.com/r/v1.2.3)
tar -xzOf "$a2" hello-cli-v1.2.3/README.md | grep -qx 'A friendly greeter.' || { echo "About isn't the plan's summary"; exit 1; }
tar -xzOf "$a2" hello-cli-v1.2.3/README.md | grep -qF 'from https://example.com/r/v1.2.3' || { echo "the README doesn't use the release URL"; exit 1; }
rm -rf "$p/docs"
# An archive whose README lacks a section fails verify.
mkdir "$work/x" && tar -xzf "$archive" -C "$work/x"
sed -i.bak '/^## Usage$/d' "$work/x/hello-cli-v1.2.3/README.md" && rm "$work/x/hello-cli-v1.2.3/README.md.bak"
tar -czf "$work/no-usage.tar.gz" -C "$work/x" hello-cli-v1.2.3
if out=$("$t/verify.sh" "$work/no-usage.tar.gz" "$p" 2>&1); then echo "verify accepted a README without Usage"; exit 1; fi
grep -q 'has no "## Usage" section' <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }
# A command whose --help fails stops the build.
printf '#!/usr/bin/env bash\nexit 3\n' > "$p/bin/broken" && chmod +x "$p/bin/broken"
if "$t/build.sh" v1.2.3 "$work/out3" "$p" >/dev/null 2>&1; then echo "build accepted a command whose --help fails"; exit 1; fi
rm "$p/bin/broken"

# A command that's broken once installed: verify must catch it through the smoke test.
printf '#!/usr/bin/env bash\necho "goodbye"\n' > "$p/bin/hello"
archive=$("$t/build.sh" v1.2.4 "$work/out" "$p")
if out=$("$t/verify.sh" "$archive" "$p" 2>&1); then echo "verify accepted a broken command"; exit 1; fi
grep -q 'tests/smoke.sh failed against the installed commands' <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }

# A project with a tutorial (decision 0020): the archive ships it, and verify
# fails if the archive's copy doesn't match the project's.
printf '#!/usr/bin/env bash\necho "hello, ${1:-world}"\n' > "$p/bin/hello"
mkdir -p "$p/docs" && printf '# Tutorial\n' > "$p/docs/tutorial.md"
archive=$("$t/build.sh" v1.2.5 "$work/out" "$p")
tar -tzf "$archive" | grep -qx 'hello-cli-v1.2.5/docs/tutorial.md' || { echo "the archive doesn't ship docs/tutorial.md"; exit 1; }
"$t/verify.sh" "$archive" "$p" >/dev/null || { echo "verify failed with a shipped tutorial"; "$t/verify.sh" "$archive" "$p"; exit 1; }
printf '# Tutorial, edited\n' > "$p/docs/tutorial.md"
if out=$("$t/verify.sh" "$archive" "$p" 2>&1); then echo "verify accepted an archive without the current tutorial"; exit 1; fi
grep -q "doesn't ship it" <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }
