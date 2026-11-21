#!/usr/bin/env bash
# Install the idea-to-release skills for an agent that reads Agent Skills.
#
# Usage, from the unpacked release archive:
#   ./install.sh --agent claude [--project DIR | --user]
#   ./install.sh --dest DIR
#
#   --agent claude   Claude Code: DIR/.claude/skills, or ~/.claude/skills with --user
#   --project DIR    install into that project (default: the current directory)
#   --user           install for the current user, in every project
#   --dest DIR       any other agent: the folder it reads skills from
#   --force          replace skill folders that idea-to-release didn't install
#
# Each skill goes in <skills-dir>/<skill>/, and the shared files (conventions,
# adapters, check scripts) in <skills-dir>/idea-to-release/ (decision 0014).
# Re-running replaces an earlier idea-to-release install and nothing else.
# Exit status: 0 on success, 1 otherwise.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
agent="" project="" user=0 dest="" force=0

usage() { sed -n '4,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case $1 in
    --agent)   [[ $# -ge 2 ]] || usage; agent=$2; shift 2 ;;
    --project) [[ $# -ge 2 ]] || usage; project=$2; shift 2 ;;
    --user)    user=1; shift ;;
    --dest)    [[ $# -ge 2 ]] || usage; dest=$2; shift 2 ;;
    --force)   force=1; shift ;;
    -h|--help) usage ;;
    *) echo "error: unknown option: $1" >&2; usage ;;
  esac
done

if [[ -n $dest ]]; then
  [[ -z $agent && -z $project && $user == 0 ]] || { echo "error: --dest can't be combined with --agent, --project or --user" >&2; exit 1; }
else
  [[ -n $project && $user == 1 ]] && { echo "error: choose --project or --user, not both" >&2; exit 1; }
  case $agent in
    claude) if [[ $user == 1 ]]; then dest="$HOME/.claude/skills"; else dest="${project:-.}/.claude/skills"; fi ;;
    "") echo "error: give --agent or --dest" >&2; usage ;;
    *) echo "error: unknown agent '$agent'. Known: claude. For another agent, use --dest with its skills folder" >&2; exit 1 ;;
  esac
fi

src="$here/skills"
[[ -f "$src/idea-to-release/VERSION" ]] || { echo "error: run install.sh from the unpacked release archive" >&2; exit 1; }
version=$(cat "$src/idea-to-release/VERSION")

mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"
previous=""
[[ -f "$dest/idea-to-release/VERSION" ]] && previous=$(cat "$dest/idea-to-release/VERSION")

# Refuse to overwrite skill folders that another tool installed.
if [[ -z $previous && $force == 0 ]]; then
  for d in "$src"/*/; do
    n=$(basename "$d")
    [[ -e "$dest/$n" ]] && { echo "error: $dest/$n already exists and wasn't installed by idea-to-release. Move it, or re-run with --force" >&2; exit 1; }
  done
fi

names=""
for d in "$src"/*/; do
  n=$(basename "$d")
  rm -rf "${dest:?}/$n"
  cp -R "$d" "$dest/$n"
  [[ $n == idea-to-release ]] || names="$names $n"
done

if [[ -n $previous ]]; then
  echo "Replaced idea-to-release $previous with $version in $dest"
else
  echo "Installed idea-to-release $version in $dest"
fi
echo "Skills:$names"
echo "Shared files: $dest/idea-to-release"
