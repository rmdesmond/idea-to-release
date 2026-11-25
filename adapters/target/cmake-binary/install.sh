#!/usr/bin/env bash
# Install a project's commands and their files from its release archive.
#
# Usage, from the unpacked release archive:
#   ./install.sh [--prefix DIR]
#
#   --prefix DIR   commands go in DIR/bin, their files in DIR/share/<name>
#                  (default: ~/.local)
#
# A record of what was installed is kept in DIR/share/<name>/.installed, so a
# re-run replaces an earlier install of the same project, including commands
# it no longer ships. A file that this project didn't install is never
# replaced.
# Exit status: 0 on success, 1 otherwise.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
prefix="$HOME/.local"

usage() { sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case $1 in
    --prefix) [[ $# -ge 2 ]] || usage; prefix=$2; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown option: $1" >&2; usage ;;
  esac
done

[[ -f $here/VERSION && -d $here/bin ]] || { echo "error: run install.sh from the unpacked release archive" >&2; exit 1; }
read -r name version _ < "$here/VERSION"

mkdir -p "$prefix/bin"
prefix="$(cd "$prefix" && pwd)"
share="$prefix/share/$name"
record="$share/.installed"
previous=""
[[ -f $record ]] && previous=$(head -1 "$record")

# Never replace what another package installed.
clashes=""
if [[ -e $share && ! -f $record ]]; then
  clashes=" $share"
fi
for f in "$here"/bin/*; do
  c=$(basename "$f")
  if [[ -e $prefix/bin/$c ]] && ! tail -n +2 "$record" 2>/dev/null | grep -qx "$c"; then
    clashes="$clashes $prefix/bin/$c"
  fi
done
if [[ -n $clashes ]]; then
  echo "error: these already exist and $name didn't install them:$clashes" >&2
  echo "install.sh won't replace them. Move them, or use another --prefix." >&2
  exit 1
fi

# Remove the earlier install: its commands and its files.
if [[ -f $record ]]; then
  tail -n +2 "$record" | while IFS= read -r c; do
    if [[ -n $c && $c != */* ]]; then rm -f "$prefix/bin/$c"; fi
  done
  rm -rf "$share"
fi

commands=""
for f in "$here"/bin/*; do
  c=$(basename "$f")
  cp -p "$f" "$prefix/bin/$c"
  chmod +x "$prefix/bin/$c"
  commands="$commands $c"
done
mkdir -p "$share"
if [[ -d $here/share/$name ]]; then
  cp -R "$here/share/$name/." "$share/"
fi
{ echo "$version"; for c in $commands; do echo "$c"; done; } > "$record"

if [[ -n $previous ]]; then
  echo "Replaced $name $previous with $version in $prefix:$commands"
else
  echo "Installed $name $version in $prefix:$commands"
fi
case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) echo "Note: $prefix/bin isn't on your PATH. Add it, for example: export PATH=\"$prefix/bin:\$PATH\"" ;;
esac
