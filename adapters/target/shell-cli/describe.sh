#!/usr/bin/env bash
# install.describe, usage.describe and the release README for the shell-cli
# target.
#
#   describe.sh install <tag> <url> [source-root]
#       The install instructions, as Markdown.
#   describe.sh usage [source-root]
#       How to use each command: the real output of `<command> --help`, run
#       from the source copy, for every executable file in bin/.
#   describe.sh readme <tag> <url> [source-root]
#       The release README (decision 0023): a title and four sections,
#       Version, About (the plan's summary), Install and Usage.
#
# source-root is a clean copy of the tagged commit (default: the current
# directory). <url> is the release's page.
# Exit status: 0 on success, 1 otherwise.

# The Markdown it prints uses backticks for code, inside single quotes on purpose.
# shellcheck disable=SC2016
set -euo pipefail

usage() { echo "usage: describe.sh install <tag> <url> [source-root] | usage [source-root] | readme <tag> <url> [source-root]" >&2; exit 1; }

repo_name() {
  local n
  n=$(sed -n 's/^repo:[[:space:]]*//p' "$1/.project/config.yml" 2>/dev/null | head -1)
  [[ $n =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: no usable repo name in $1/.project/config.yml" >&2; exit 1; }
  printf '%s\n' "$n"
}

# The first paragraph of the plan's summary: after its title and Status line.
# Falls back to the README's first paragraph after its title.
about() {
  local src=$1 text=""
  if [[ -f $src/docs/plan/PLAN.md ]]; then
    text=$(awk '
      NR == 1 && /^# / { next }
      started && NF == 0 { exit }
      !started && (NF == 0 || /^Status:/) { next }
      !started && /^#/ { exit }
      { started = 1; print }
    ' "$src/docs/plan/PLAN.md")
  fi
  if [[ -z $text && -f $src/README.md ]]; then
    text=$(awk '
      !seen && /^# / { seen = 1; next }
      !seen { next }
      started && NF == 0 { exit }
      !started && (NF == 0 || /^[#>]/) { next }
      { started = 1; print }
    ' "$src/README.md")
  fi
  [[ -n $text ]] || { echo "error: no summary to use for About: docs/plan/PLAN.md and README.md have none" >&2; exit 1; }
  printf '%s\n' "$text"
}

describe_install() {
  local repo=$1 tag=$2 url=$3
  cat <<EOF
Download \`$repo-$tag.tar.gz\` from $url, then:

    tar -xzf $repo-$tag.tar.gz
    cd $repo-$tag
    ./install.sh                      # into ~/.local/bin
    ./install.sh --prefix /usr/local  # or anywhere else: commands go in <prefix>/bin

Re-running replaces an earlier install. A file of the same name that this project didn't install is never replaced. If \`<prefix>/bin\` isn't on your \`PATH\`, the script says how to add it.
EOF
}

describe_usage() {
  local src=$1 f c out n=0
  for f in "$src"/bin/*; do
    [[ -f $f && -x $f ]] || continue
    c=$(basename "$f"); n=$((n + 1))
    if ! out=$(cd "$src" && PATH="$src/bin:$PATH" "$c" --help 2>&1); then
      echo "error: \`$c --help\` failed: $out" >&2; exit 1
    fi
    (( n > 1 )) && echo
    printf '### %s\n\n```\n$ %s --help\n%s\n```\n' "$c" "$c" "$out"
  done
  (( n > 0 )) || { echo "error: no executable commands in $src/bin/" >&2; exit 1; }
  if [[ -f $src/docs/tutorial.md ]]; then
    printf '\nA worked example, from installing to everyday use: `docs/tutorial.md`, in this archive.\n'
  fi
}

mode=${1:-}
case $mode in
  install)
    [[ $# -ge 3 ]] || usage
    src="${4:-.}"
    describe_install "$(repo_name "$src")" "$2" "$3"
    ;;
  usage)
    src="${2:-.}"
    describe_usage "$src"
    ;;
  readme)
    [[ $# -ge 3 ]] || usage
    tag=$2 url=$3 src="${4:-.}"
    repo=$(repo_name "$src")
    a=$(about "$src"); i=$(describe_install "$repo" "$tag" "$url"); u=$(describe_usage "$src")
    printf '# %s %s\n\n## Version\n\n%s %s, released %s. Release notes: %s\n\n## About\n\n%s\n\n## Install\n\n%s\n\n## Usage\n\n%s\n' \
      "$repo" "$tag" "$repo" "$tag" "$(date -u +%Y-%m-%d)" "$url" "$a" "$i" "$u"
    ;;
  *) usage ;;
esac
