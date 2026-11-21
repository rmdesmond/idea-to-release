#!/usr/bin/env bash
# Install a project's commands from its release archive.
#
# Usage, from the unpacked release archive:
#   ./install.sh [--prefix DIR]
#
#   --prefix DIR   commands go in DIR/bin (default: ~/.local)
#
# A record of what was installed is kept in DIR/share/<name>/installed, so a
# re-run replaces an earlier install of the same project. A file in DIR/bin
# that this project didn't install is never replaced.
# Exit status: 0 on success, 1 otherwise.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
prefix="$HOME/.local"

usage() { sed -n '4,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case $1 in
    --prefix) [[ $# -ge 2 ]] || usage; prefix=$2; shift 2 ;;
    -h|--help) usage ;;
    *) echo "error: unknown option: $1" >&2; usage ;;
  esac
done

[[ -f $here/VERSION && -d $here/bin ]] || { echo "error: run install.sh from the unpacked release archive" >&2; exit 1; }
read -r name version < "$here/VERSION"

mkdir -p "$prefix/bin" "$prefix/share/$name"
prefix="$(cd "$prefix" && pwd)"
record="$prefix/share/$name/installed"
previous=""
[[ -f $record ]] && previous=$(head -1 "$record")

# Never replace a command another package installed.
clashes=""
for f in "$here"/bin/*; do
  c=$(basename "$f")
  if [[ -e $prefix/bin/$c ]] && ! grep -qx "$c" "$record" 2>/dev/null; then
    clashes="$clashes $prefix/bin/$c"
  fi
done
if [[ -n $clashes ]]; then
  echo "error: these files already exist and $name didn't install them:$clashes" >&2
  echo "install.sh won't replace them. Move them, or use another --prefix." >&2
  exit 1
fi

commands=""
for f in "$here"/bin/*; do
  c=$(basename "$f")
  cp -p "$f" "$prefix/bin/$c"
  chmod +x "$prefix/bin/$c"
  commands="$commands $c"
done
{ echo "$version"; for c in $commands; do echo "$c"; done; } > "$record"

if [[ -n $previous ]]; then
  echo "Replaced $name $previous with $version in $prefix/bin:$commands"
else
  echo "Installed $name $version in $prefix/bin:$commands"
fi
case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) echo "Note: $prefix/bin isn't on your PATH. Add it, for example: export PATH=\"$prefix/bin:\$PATH\"" ;;
esac
