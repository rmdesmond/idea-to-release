#!/usr/bin/env bash
# package.verify for the agent-skills target: install a release archive into a
# throw-away project and check that the installed skills can find their files.
#
# Checks:
# - install.sh --agent claude installs every skill and the shared folder
# - each skill's SKILL.md names its folder, and says where the shared files are
# - from each skill folder, ../idea-to-release/conventions.md exists
# - the installed check-adapters.sh passes against the installed adapters
# - a second install replaces the first; --dest works; each --agent picks its folder
# - name clashes: a same-named folder idea-to-release didn't install is never
#   replaced, and a same-named personal skill stops a project install unless --force
# Installs run with a throw-away HOME, so the real personal skills never matter.
# With a source root (a clean copy of the release tag), it also checks the
# Claude Code plugin i2r (decision 0019): plugin.json's version and the
# marketplace's ref match the archive's version, and, when `claude` is on
# PATH, `claude plugin validate --strict` passes. If the source has
# docs/tutorial.md, the archive ships the same file.
#
# Usage: verify.sh <archive.tar.gz> [source-root]
# Exit status: 0 if every check passes, 1 otherwise.

set -uo pipefail

[[ ( $# -eq 1 || $# -eq 2 ) && -f $1 ]] || { echo "usage: verify.sh <archive.tar.gz> [source-root]" >&2; exit 1; }
archive="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
src=${2:-}
[[ -z $src || -d $src ]] || { echo "usage: verify.sh <archive.tar.gz> [source-root]" >&2; exit 1; }

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
mkdir -p "$project" "$work/home"
export HOME="$work/home"
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
for pair in codex:.agents copilot:.github gemini:.gemini; do
  a=${pair%%:*} dir=${pair#*:}
  if out=$("$top/install.sh" --agent "$a" --project "$work/p-$a" 2>&1) && [[ -f $work/p-$a/$dir/skills/idea-to-release/VERSION ]]; then ok; else fail "install.sh --agent $a didn't install into $dir/skills: $out"; fi
done
if out=$("$top/install.sh" --agent claude --user 2>&1) && [[ -f $HOME/.claude/skills/idea-to-release/VERSION ]]; then ok; else fail "install.sh --user failed: $out"; fi

mkdir -p "$work/foreign/work-issue"
echo mine > "$work/foreign/work-issue/SKILL.md"
if "$top/install.sh" --dest "$work/foreign" --force >/dev/null 2>&1; then fail "install.sh replaced a folder it didn't install"; else ok; fi
check "a foreign folder was changed" grep -qx mine "$work/foreign/work-issue/SKILL.md"

rm -rf "$HOME/.claude/skills" && mkdir -p "$HOME/.claude/skills/cut-release"
if out=$("$top/install.sh" --agent claude --project "$work/p-hidden" 2>&1); then fail "a same-named personal skill didn't stop the install"; else check "the clash message doesn't name the personal skill: $out" grep -q "$HOME/.claude/skills/cut-release" <<<"$out"; fi
if out=$("$top/install.sh" --agent claude --project "$work/p-hidden" --force 2>&1) && grep -q '^warning: installed' <<<"$out"; then ok; else fail "--force didn't install with a warning: $out"; fi

if [[ -n $src && -f $src/docs/tutorial.md ]]; then
  check "the repository has docs/tutorial.md, but the archive doesn't ship it" cmp -s "$src/docs/tutorial.md" "$top/docs/tutorial.md"
fi

if [[ -n $src ]]; then
  # The first X.Y.Z on the line after the marker (conventions section 12).
  vfile() { grep -F -- "$2" "$1" 2>/dev/null | head -1 | sed -E 's/.*'"$2"'[^0-9]*([0-9]+[.][0-9]+[.][0-9]+).*/\1/'; }
  want=${version#v}
  check "plugin.json's version isn't $want" test "$(vfile "$src/.claude-plugin/plugin.json" '"version":')" = "$want"
  check "the marketplace's ref isn't v$want" test "$(vfile "$src/.claude-plugin/marketplace.json" '"ref":')" = "$want"
  if command -v claude >/dev/null 2>&1; then
    if out=$(claude plugin validate "$src" --strict 2>&1); then ok; else fail "claude plugin validate --strict: $(grep -E '❯|✘' <<<"$out" | head -5)"; fi
  fi
fi

if (( failures > 0 )); then
  echo "$failures of $checks check(s) failed for $(basename "$archive")"
  exit 1
fi
echo "ok: $(basename "$archive") installs $n skill(s); $checks checks passed"
