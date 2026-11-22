#!/usr/bin/env bash
# package.verify for the shell-cli target: install a release archive into a
# throw-away prefix and smoke-test the installed commands.
#
# Checks:
# - install.sh puts every command from the archive's bin/ in <prefix>/bin,
#   executable
# - the smoke test passes: the project's tests/smoke.sh, if it has one, run
#   with the installed commands first on PATH and nothing else of the project's
# - a second install replaces the first, and a file another package
#   installed is never replaced
# - if the project has docs/tutorial.md, the archive ships the same file
# - the archive's README.md is the release README: it has the Version,
#   About, Install and Usage sections (decision 0023)
#
# Usage: verify.sh <archive.tar.gz> [source-root]
#   source-root  where to find tests/smoke.sh (default: the current directory)
# Exit status: 0 if every check passes, 1 otherwise.

set -uo pipefail

[[ $# -ge 1 && -f $1 ]] || { echo "usage: verify.sh <archive.tar.gz> [source-root]" >&2; exit 1; }
archive="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
src="$(cd "${2:-.}" && pwd)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0 checks=0
ok()   { checks=$((checks + 1)); }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); checks=$((checks + 1)); }

tar -xzf "$archive" -C "$work" || { echo "FAIL  can't unpack $archive"; exit 1; }
top=$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -1)
[[ -n $top && -x $top/install.sh && -f $top/VERSION ]] || { echo "FAIL  no install.sh and VERSION at the top of the archive"; exit 1; }

prefix="$work/prefix"
if out=$("$top/install.sh" --prefix "$prefix" 2>&1); then ok; else fail "install.sh failed: $out"; fi

n=0
for f in "$top"/bin/*; do
  c=$(basename "$f"); n=$((n + 1))
  if [[ -x $prefix/bin/$c ]]; then ok; else fail "$c wasn't installed as an executable in <prefix>/bin"; fi
done
(( n > 0 )) || fail "the archive has no commands"

if [[ -f $src/tests/smoke.sh ]]; then
  # Run from an empty folder, so the smoke test can only reach the installed commands.
  mkdir "$work/empty"
  if out=$(cd "$work/empty" && PATH="$prefix/bin:/usr/bin:/bin" bash "$src/tests/smoke.sh" 2>&1); then ok; else fail "tests/smoke.sh failed against the installed commands: $out"; fi
  smoke="tests/smoke.sh passed"
else
  smoke="no tests/smoke.sh, so only the install was checked"
fi

if out=$("$top/install.sh" --prefix "$prefix" 2>&1) && grep -q '^Replaced' <<<"$out"; then ok; else fail "a second install didn't replace the first: $out"; fi
first=$(basename "$(find "$top/bin" -type f | head -1)")
mkdir -p "$work/other/bin" && echo theirs > "$work/other/bin/$first"
if "$top/install.sh" --prefix "$work/other" >/dev/null 2>&1; then fail "install.sh replaced a file another package installed"; else ok; fi
if grep -qx theirs "$work/other/bin/$first"; then ok; else fail "a file another package installed was changed"; fi

if [[ -f $top/README.md ]]; then
  for s in Version About Install Usage; do
    if grep -qx "## $s" "$top/README.md"; then ok; else fail "the archive's README.md has no \"## $s\" section"; fi
  done
else
  fail "the archive has no README.md"
fi

if [[ -f $src/docs/tutorial.md ]]; then
  if cmp -s "$src/docs/tutorial.md" "$top/docs/tutorial.md"; then ok; else fail "the project has docs/tutorial.md, but the archive doesn't ship it (or ships another copy)"; fi
fi

if (( failures > 0 )); then
  echo "$failures of $checks check(s) failed for $(basename "$archive")"
  exit 1
fi
echo "ok: $(basename "$archive") installs $n command(s); $smoke; $checks checks passed"
