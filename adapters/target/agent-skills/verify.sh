#!/usr/bin/env bash
# package.verify for the agent-skills target: install a release archive into a
# throw-away project and check that the installed skills can find their files.
#
# Checks:
# - install.sh --agent claude installs every skill and the shared folder
# - each skill's SKILL.md names its folder, and says where the shared files are
# - from each skill folder, ../idea-to-release/conventions.md exists
# - the installed check-adapters.sh passes against the installed adapters
# - a second install replaces the first; --dest works; a foreign folder is refused
#
# Usage: verify.sh <archive.tar.gz>
# Exit status: 0 if every check passes, 1 otherwise.

set -uo pipefail

[[ $# -eq 1 && -f $1 ]] || { echo "usage: verify.sh <archive.tar.gz>" >&2; exit 1; }
archive="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0 checks=0
ok()   { checks=$((checks + 1)); }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); checks=$((checks + 1)); }
# check <message-if-it-fails> <command...>
check() { local msg=$1; shift; if "$@"; then ok; else fail "$msg"; fi; }

tar -xzf "$archive" -C "$work" || { echo "FAIL  can't unpack $archive"; exit 1; }
top=$(find "$work" -mindepth 1 -maxdepth 1 -type d -name 'idea-to-release-*' | head -1)
[[ -n $top && -x $top/install.sh ]] || { echo "FAIL  no idea-to-release-*/install.sh in the archive"; exit 1; }
version=$(cat "$top/skills/idea-to-release/VERSION" 2>/dev/null)

project="$work/project"
mkdir -p "$project"
if out=$("$top/install.sh" --agent claude --project "$project" 2>&1); then ok; else fail "install.sh --agent claude failed: $out"; fi
skills_dir="$project/.claude/skills"

installed=$(cat "$skills_dir/idea-to-release/VERSION" 2>/dev/null || true)
check "shared folder or VERSION missing" test "$installed" = "$version"
check "the shared folder has a SKILL.md, so agents would load it as a skill" test ! -e "$skills_dir/idea-to-release/SKILL.md"

n=0
for d in "$skills_dir"/*/; do
  name=$(basename "$d")
  [[ $name == idea-to-release ]] && continue
  n=$((n + 1))
  skill="$d/SKILL.md"
  [[ -f $skill ]] || { fail "$name: no SKILL.md"; continue; }
  check "$name: SKILL.md frontmatter doesn't say 'name: $name'" grep -qx "name: $name" "$skill"
  check "$name: SKILL.md doesn't say where the shared files are" grep -qF '../idea-to-release/' "$skill"
  check "$name: ../idea-to-release/conventions.md not found" test -f "$d/../idea-to-release/conventions.md"
done
(( n > 0 )) || fail "no skills installed"

if out=$("$skills_dir/idea-to-release/scripts/check-adapters.sh" "$skills_dir/idea-to-release" 2>&1); then ok; else fail "installed check-adapters.sh: $out"; fi

if out=$("$top/install.sh" --agent claude --project "$project" 2>&1) && grep -q '^Replaced' <<<"$out"; then ok; else fail "a second install didn't replace the first: $out"; fi
if out=$("$top/install.sh" --dest "$work/other" 2>&1) && [[ -f $work/other/idea-to-release/conventions.md ]]; then ok; else fail "install.sh --dest failed: $out"; fi
mkdir -p "$work/foreign/work-issue"
if "$top/install.sh" --dest "$work/foreign" >/dev/null 2>&1; then fail "install.sh overwrote a folder it didn't install"; else ok; fi

if (( failures > 0 )); then
  echo "$failures of $checks check(s) failed for $(basename "$archive")"
  exit 1
fi
echo "ok: $(basename "$archive") installs $n skill(s); $checks checks passed"
