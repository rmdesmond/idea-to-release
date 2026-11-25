#!/usr/bin/env bash
# install.describe, usage.describe and the release README for the
# cmake-binary target.
#
#   describe.sh install <tag> <url> [source-root]
#       The install instructions, as Markdown, for this machine's platform.
#   describe.sh usage <installed-root>
#       How to use each command: the real output of `<command> --help`, for
#       every executable file in <installed-root>/bin/ (a staging prefix, an
#       unpacked archive or an install prefix).
#   describe.sh readme <tag> <url> <source-root> <installed-root>
#       The release README (decision 0023): a title and four sections,
#       Version, About (the plan's summary), Install and Usage.
#
# source-root is a clean copy of the tagged commit (default: the current
# directory). <url> is the release's page.
# Exit status: 0 on success, 1 otherwise.

# The Markdown it prints uses backticks for code, inside single quotes on purpose.
# shellcheck disable=SC2016
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091  # platform.sh, next to this script
. "$here/platform.sh"

usage() { echo "usage: describe.sh install <tag> <url> [source-root] | usage <installed-root> | readme <tag> <url> <source-root> <installed-root>" >&2; exit 1; }

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
  local repo=$1 tag=$2 url=$3 platform
  platform="$(platform_os)-$(platform_arch)"
  cat <<END
Download \`$repo-$tag-$platform.tar.gz\` from $url. It's built for $platform; on another system, build from source as the project's README describes. Then:

    tar -xzf $repo-$tag-$platform.tar.gz
    cd $repo-$tag-$platform
    ./install.sh                      # into ~/.local
    ./install.sh --prefix /usr/local  # or anywhere else

Commands go in \`<prefix>/bin\`, and their files in \`<prefix>/share/$repo\`. Re-running replaces an earlier install. A file of the same name that this project didn't install is never replaced. If \`<prefix>/bin\` isn't on your \`PATH\`, the script says how to add it.
END
}

describe_usage() {
  local root=$1 f c out n=0
  [[ -d $root/bin ]] || { echo "error: $root/bin not found" >&2; exit 1; }
  root="$(cd "$root" && pwd)"
  for f in "$root"/bin/*; do
    [[ -f $f && -x $f ]] || continue
    c=$(basename "$f"); n=$((n + 1))
    if ! out=$(cd "$root" && PATH="$root/bin:$PATH" "$c" --help 2>&1); then
      echo "error: \`$c --help\` failed: $out" >&2; exit 1
    fi
    (( n > 1 )) && echo
    printf '### %s\n\n```\n$ %s --help\n%s\n```\n' "$c" "$c" "$out"
  done
  (( n > 0 )) || { echo "error: no executable commands in $root/bin/" >&2; exit 1; }
}

mode=${1:-}
case $mode in
  install)
    [[ $# -ge 3 ]] || usage
    src="${4:-.}"
    describe_install "$(repo_name "$src")" "$2" "$3"
    ;;
  usage)
    [[ $# -ge 2 ]] || usage
    describe_usage "$2"
    ;;
  readme)
    [[ $# -ge 5 ]] || usage
    tag=$2 url=$3 src=$4 root=$5
    repo=$(repo_name "$src")
    a=$(about "$src"); i=$(describe_install "$repo" "$tag" "$url"); u=$(describe_usage "$root")
    if [[ -f $src/docs/tutorial.md ]]; then
      u=$(printf '%s\n\nA worked example, from installing to everyday use: `docs/tutorial.md`, in this archive.' "$u")
    fi
    printf '# %s %s\n\n## Version\n\n%s %s (%s), released %s. Release notes: %s\n\n## About\n\n%s\n\n## Install\n\n%s\n\n## Usage\n\n%s\n' \
      "$repo" "$tag" "$repo" "$tag" "$(platform_os)-$(platform_arch)" "$(date -u +%Y-%m-%d)" "$url" "$a" "$i" "$u"
    ;;
  *) usage ;;
esac
