#!/usr/bin/env bash
# install.describe, usage.describe and the release README for the
# agent-skills target.
#
#   describe.sh install <tag> <url>
#       The install instructions, as Markdown: the Claude Code plugin, then
#       the archive for other agents.
#   describe.sh usage [source-root]
#       Each skill, with how to invoke it and the first sentence of its
#       description, from its SKILL.md.
#   describe.sh readme <tag> <url> [source-root]
#       The release README (decision 0023): a title and four sections,
#       Version, About (the plan's summary), Install and Usage.
#
# source-root is a clean copy of the tagged commit (default: this
# repository). <url> is the release's page.
# Exit status: 0 on success, 1 otherwise.

# The Markdown it prints uses backticks for code, inside single quotes on purpose.
# shellcheck disable=SC2016
set -euo pipefail

usage() { echo "usage: describe.sh install <tag> <url> | usage [source-root] | readme <tag> <url> [source-root]" >&2; exit 1; }
default_src="$(cd "$(dirname "$0")/../../.." && pwd)"

# The first paragraph of the plan's summary: after its title and Status line.
about() {
  local text=""
  [[ -f $1/docs/plan/PLAN.md ]] && text=$(awk '
    NR == 1 && /^# / { next }
    started && NF == 0 { exit }
    !started && (NF == 0 || /^Status:/) { next }
    !started && /^#/ { exit }
    { started = 1; print }
  ' "$1/docs/plan/PLAN.md")
  [[ -n $text ]] || { echo "error: no summary in $1/docs/plan/PLAN.md to use for About" >&2; exit 1; }
  printf '%s\n' "$text"
}

describe_install() {
  local tag=$1 url=$2
  cat <<EOF
**Claude Code:** install the plugin \`i2r\`:

    claude plugin marketplace add rmdesmond/idea-to-release
    claude plugin install i2r@i2r

The skills are then \`/i2r:idea-to-plan\`, \`/i2r:accept-the-plan\` and so on. To update after a new release: \`claude plugin marketplace update i2r\`, then \`claude plugin update i2r@i2r\`.

**Other agents:** download \`idea-to-release-$tag.tar.gz\` from $url, then:

    tar -xzf idea-to-release-$tag.tar.gz
    cd idea-to-release-$tag
    ./install.sh --agent codex --project /path/to/your/project   # or --user, for every project

\`--agent\` takes \`claude\`, \`codex\`, \`copilot\` or \`gemini\`. For any other agent, use \`--dest <its skills folder>\`. Each skill goes in its own folder, and the shared files go in \`idea-to-release/\` beside them. Re-running replaces an earlier install. If a skill of the same name is already there, or in your personal skills, the script stops and names it.
EOF
}

describe_usage() {
  local src=$1 plugin d name desc n=0
  plugin=$(sed -n 's/^[[:space:]]*"name":[[:space:]]*"\([^"]*\)".*/\1/p' "$src/.claude-plugin/plugin.json" 2>/dev/null | head -1)
  [[ -n $plugin ]] || plugin=i2r
  printf 'Ask your agent to run a skill by name. In Claude Code, type it with the plugin'"'"'s name in front.\n\n'
  printf '| Skill | In Claude Code | What it does |\n|---|---|---|\n'
  for d in "$src"/skills/*/; do
    [[ -f $d/SKILL.md ]] || continue
    name=$(sed -n '2,/^---$/s/^name:[[:space:]]*//p' "$d/SKILL.md" | head -1)
    desc=$(sed -n '2,/^---$/s/^description:[[:space:]]*//p' "$d/SKILL.md" | head -1)
    [[ -n $name && -n $desc ]] || { echo "error: $d/SKILL.md has no name or description" >&2; exit 1; }
    # The first sentence, up to ". " or " - ".
    desc=$(printf '%s\n' "$desc" | awk '{ s = $0; i = index(s, ". "); j = index(s, " - "); if (j > 0 && (i == 0 || j < i)) i = j; if (i > 0) s = substr(s, 1, i - 1); sub(/\.$/, "", s); print s "." }')
    printf '| `%s` | `/%s:%s` | %s |\n' "$name" "$plugin" "$name" "$desc"
    n=$((n + 1))
  done
  (( n > 0 )) || { echo "error: no skills found under $src/skills" >&2; exit 1; }
  printf '\nA new project starts with `idea-to-plan`, then `accept-the-plan`, then `work-the-plan` after each merge.\n'
  if [[ -f $src/docs/tutorial.md ]]; then
    printf '\nA worked example, from an idea to a first release: `docs/tutorial.md`, in this archive.\n'
  fi
}

mode=${1:-}
case $mode in
  install)
    [[ $# -ge 3 ]] || usage
    describe_install "$2" "$3"
    ;;
  usage)
    describe_usage "${2:-$default_src}"
    ;;
  readme)
    [[ $# -ge 3 ]] || usage
    tag=$2 url=$3 src="${4:-$default_src}"
    a=$(about "$src"); i=$(describe_install "$tag" "$url"); u=$(describe_usage "$src")
    printf '# idea-to-release %s\n\n## Version\n\nidea-to-release %s, released %s. Release notes: %s\n\n## About\n\n%s\n\n## Install\n\n%s\n\n## Usage\n\n%s\n' \
      "$tag" "$tag" "$(date -u +%Y-%m-%d)" "$url" "$a" "$i" "$u"
    ;;
  *) usage ;;
esac
