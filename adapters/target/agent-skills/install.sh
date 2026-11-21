#!/usr/bin/env bash
# Install the idea-to-release skills for an agent that reads Agent Skills.
#
# Usage, from the unpacked release archive:
#   ./install.sh --agent <agent> [--project DIR | --user]
#   ./install.sh --dest DIR
#
#   --agent claude   Claude Code:    DIR/.claude/skills, or ~/.claude/skills
#   --agent codex    OpenAI Codex:   DIR/.agents/skills, or ~/.agents/skills
#   --agent copilot  GitHub Copilot: DIR/.github/skills, or ~/.copilot/skills
#   --agent gemini   Gemini CLI:     DIR/.gemini/skills, or ~/.gemini/skills
#   --project DIR    install into that project (default: the current directory)
#   --user           install for the current user, in every project
#   --dest DIR       any other agent: the folder it reads skills from
#   --force          install even if a personal skill of the same name would hide it
#
# Each skill goes in <skills-dir>/<skill>/, and the shared files (conventions,
# adapters, check scripts) in <skills-dir>/idea-to-release/ (decision 0014).
# Re-running replaces an earlier idea-to-release install and nothing else.
#
# Name clashes: an agent loads only one skill per name, and it doesn't warn.
# (In Claude Code, a personal skill wins over a project skill of the same name.)
# So install.sh never replaces a same-named folder it didn't install, and it
# stops if the agent's personal skills folder has one that would hide the new
# skill, unless given --force (decision 0015).
# Exit status: 0 on success, 1 otherwise.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
agent="" project="" user=0 dest="" force=0

usage() { sed -n '4,16p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
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
    claude)  personal="$HOME/.claude/skills";  in_project=".claude/skills" ;;
    codex)   personal="$HOME/.agents/skills";  in_project=".agents/skills" ;;
    copilot) personal="$HOME/.copilot/skills"; in_project=".github/skills" ;;
    gemini)  personal="$HOME/.gemini/skills";  in_project=".gemini/skills" ;;
    "") echo "error: give --agent or --dest" >&2; usage ;;
    *) echo "error: unknown agent '$agent'. Known: claude, codex, copilot, gemini. For another agent, use --dest with its skills folder" >&2; exit 1 ;;
  esac
  if [[ $user == 1 ]]; then dest=$personal; else dest="${project:-.}/$in_project"; fi
fi

src="$here/skills"
[[ -f "$src/idea-to-release/VERSION" ]] || { echo "error: run install.sh from the unpacked release archive" >&2; exit 1; }
version=$(cat "$src/idea-to-release/VERSION")

mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"
previous=""
[[ -f "$dest/idea-to-release/VERSION" ]] && previous=$(cat "$dest/idea-to-release/VERSION")

# Refuse to overwrite, or be hidden by, skills that another tool installed.
# A folder is ours if the idea-to-release/VERSION beside it exists.
clashes_in() {   # <skills-folder>: same-named folders there that aren't ours
  local dir=$1 d n
  [[ -d $dir && ! -f $dir/idea-to-release/VERSION ]] || return 0
  for d in "$src"/*/; do
    n=$(basename "$d")
    if [[ -e "$dir/$n" ]]; then printf '\n  %s' "$dir/$n"; fi
  done
}
here_clashes=$(clashes_in "$dest")
if [[ -n $here_clashes ]]; then
  echo "error: these folders have the names of idea-to-release skills, and idea-to-release didn't install them:$here_clashes" >&2
  echo "install.sh won't replace them. Rename or move them, then install again." >&2
  exit 1
fi
hidden_by=""
if [[ -n ${personal:-} && $user == 0 && -d $personal ]] && [[ "$(cd "$personal" && pwd)" != "$dest" ]]; then
  hidden_by=$(clashes_in "$personal")
fi
if [[ -n $hidden_by && $force == 0 ]]; then
  echo "error: your personal skills have the same names, so the agent would load them instead, without a warning:$hidden_by" >&2
  echo "Rename them, install with --user instead, or re-run with --force to install anyway." >&2
  exit 1
fi
[[ -n $hidden_by ]] && echo "warning: installed, but these personal skills will be used instead (--force):$hidden_by" >&2

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
