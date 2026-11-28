#!/usr/bin/env bash
# The local tracker store: shared functions, sourced by tracker.sh and by the
# local forge's change-request commands (decision 0027). Not run on its own.
#
# The store is a folder outside the project, found through tracker_path in
# .project/config.yml (relative to the project root; default ../<repo>-tracker).
# It's a git repository of its own, and every write is one commit:
#
#   README.md        what the folder is
#   next             the next number, shared by issues and change requests
#   labels.md        a table: | Name | Colour | Description |
#   milestones.md    a table: | Number | Title | State | Description |
#   issues/NNNN.md   one file per issue: "Key: value" header lines, a blank line, the body
#
# Written for bash 3.2 and BSD or GNU tools.

# Print an error and exit.
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf 'note: %s\n' "$*" >&2; }

# store_resolve [project-root]: sets PROJECT and STORE.
store_resolve() {
  local dir="${1:-.}" cfg path repo
  PROJECT=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) ||
    die "$dir is not inside a git repository"
  cfg="$PROJECT/.project/config.yml"
  path="" repo=""
  if [[ -f $cfg ]]; then
    path=$(config_value "$cfg" tracker_path)
    repo=$(config_value "$cfg" repo)
  fi
  [[ -n $repo ]] || repo=$(basename "$PROJECT")
  [[ -n $path ]] || path="../$repo-tracker"
  case $path in
    /*) STORE=$path ;;
    *) STORE="$PROJECT/$path" ;;
  esac
  # Normalise the path when it exists, so messages show where it really is.
  if [[ -d $STORE ]]; then STORE=$(cd "$STORE" && pwd -P)
  elif [[ -d $(dirname "$STORE") ]]; then STORE="$(cd "$(dirname "$STORE")" && pwd -P)/$(basename "$STORE")"; fi
}

# config_value <file> <key>: a top-level scalar, without quotes or a trailing comment.
config_value() {
  awk -v k="$2:" '
    $1 == k {
      sub(/^[^:]*:[ \t]*/, "")
      sub(/[ \t]+#.*$/, "")
      if ($0 ~ /^".*"$/ || $0 ~ /^\047.*\047$/) $0 = substr($0, 2, length($0) - 2)
      print
      exit
    }' "$1"
}

# store_is_store: 0 if STORE looks like a tracker store.
store_is_store() { [[ -d $STORE/.git && -f $STORE/next && -f $STORE/labels.md && -f $STORE/milestones.md ]]; }

# store_require_read: for reads. Returns 1 (with a note) if there's no store yet.
store_require_read() {
  if [[ ! -e $STORE ]]; then note "the tracker store doesn't exist yet: $STORE"; return 1; fi
  store_is_store || die "$STORE exists but isn't a tracker store"
}

# store_begin_write: create the store if needed, take the lock, check it's clean.
store_begin_write() {
  if [[ ! -e $STORE ]] || { [[ -d $STORE ]] && [[ -z $(ls -A "$STORE") ]]; }; then
    store_create
  fi
  store_is_store || die "$STORE exists but isn't a tracker store; refusing to write to it"
  mkdir "$STORE/.lock" 2>/dev/null || die "the tracker store is locked by another write ($STORE/.lock); remove it if no write is running"
  trap 'rmdir "$STORE/.lock" 2>/dev/null || true' EXIT
  if [[ -n $(git -C "$STORE" status --porcelain) ]]; then
    die "the tracker store has uncommitted changes ($STORE); commit or undo them first"
  fi
}

# store_create: a new, empty store, as its first commit.
store_create() {
  mkdir -p "$STORE"
  STORE=$(cd "$STORE" && pwd -P)
  git -C "$STORE" init -q
  git -C "$STORE" symbolic-ref HEAD refs/heads/main
  mkdir -p "$STORE/issues"
  printf '1\n' > "$STORE/next"
  printf '# Tracker store\n\nIssues, labels and milestones for %s, kept by the idea-to-release local tracker (decision 0027).\nEvery change is a commit. Edit it only through the adapter.\n' "$(basename "$PROJECT")" > "$STORE/README.md"
  printf '# Labels\n\n| Name | Colour | Description |\n|---|---|---|\n' > "$STORE/labels.md"
  printf '# Milestones\n\n| Number | Title | State | Description |\n|---|---|---|---|\n' > "$STORE/milestones.md"
  git -C "$STORE" add -A
  git -C "$STORE" commit -q -m "store: create the tracker store" || die "couldn't commit in $STORE (is git's user.name and user.email set?)"
  note "created the tracker store at $STORE"
}

# store_commit <message>: commit everything the write changed.
store_commit() {
  git -C "$STORE" add -A
  if git -C "$STORE" diff --cached --quiet; then return 0; fi
  git -C "$STORE" commit -q -m "$1" || die "couldn't commit in $STORE; the write is left uncommitted there"
}

# store_next_number: allocate the next number (write only).
store_next_number() {
  local n
  n=$(tr -d ' \n' < "$STORE/next")
  [[ $n =~ ^[0-9]+$ ]] || die "$STORE/next doesn't hold a number"
  printf '%s\n' $((n + 1)) > "$STORE/next"
  printf '%s\n' "$n"
}

today() { date -u +%Y-%m-%d; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# check_line <what> <value> [forbidden-chars]: one line, no forbidden characters.
check_line() {
  case $2 in *$'\n'*|*$'\r'*) die "$1 must be one line" ;; esac
  local c rest="${3:-}"
  while [[ -n $rest ]]; do
    c=${rest:0:1}; rest=${rest:1}
    case $2 in *"$c"*) die "$1 can't contain '$c': $2" ;; esac
  done
}

# --- Records with a header (issues, and the forge's change requests) ---

# rec_get <file> <key>: the header value, or nothing.
rec_get() {
  awk -v k="$2" '
    NF == 0 { exit }
    $0 == k ":" { exit }
    index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$1"
}

# rec_body <file>: everything after the first blank line.
rec_body() { awk 'b { print } !b && NF == 0 { b = 1 }' "$1"; }

# rec_set <file> <key> <value>: replace one header line (the key must exist).
rec_set() {
  local tmp="$1.tmp"
  V="$3" awk -v k="$2" '
    BEGIN { v = ENVIRON["V"] }
    !b && NF == 0 { b = 1 }
    !b && ($0 == k ":" || index($0, k ": ") == 1) { print (v == "" ? k ":" : k ": " v); next }
    { print }' "$1" > "$tmp" && mv "$tmp" "$1"
}

# rec_set_body <file> <body-file>: replace the body.
rec_set_body() {
  local tmp="$1.tmp"
  { awk 'NF == 0 { exit } { print }' "$1"; printf '\n'; cat "$2"; } > "$tmp" && mv "$tmp" "$1"
}

# normalise_body: strip trailing whitespace from each line, and trailing blank lines.
normalise_body() { sed 's/[[:space:]]*$//' | awk '{ a[NR] = $0 } NF { last = NR } END { for (i = 1; i <= last; i++) print a[i] }'; }

# --- Comma-separated lists in headers ("a, b, c") ---

# list_has <list> <item> [ci]: 0 if present (case-insensitive with ci).
list_has() {
  L="$1" X="$2" awk -v ci="${3:-}" 'BEGIN { l = ENVIRON["L"]; x = ENVIRON["X"]
    n = split(l, a, /, */)
    for (i = 1; i <= n; i++) { if (a[i] == x || (ci && tolower(a[i]) == tolower(x))) exit 0 }
    exit 1 }'
}
list_add() { if [[ -z $1 ]]; then printf '%s' "$2"; else printf '%s, %s' "$1" "$2"; fi; }
list_remove() {
  L="$1" X="$2" awk -v ci="${3:-}" 'BEGIN { l = ENVIRON["L"]; x = ENVIRON["X"]
    n = split(l, a, /, */); out = ""
    for (i = 1; i <= n; i++) {
      if (a[i] == "" || a[i] == x || (ci && tolower(a[i]) == tolower(x))) continue
      out = (out == "" ? a[i] : out ", " a[i])
    }
    printf "%s", out }'
}

# --- Tables (labels.md, milestones.md) ---

# table_rows <file>: the data rows, fields separated by tabs.
table_rows() {
  awk '/^\|---/ { on = 1; next } on && /^\| / {
    line = substr($0, 3, length($0) - 4)
    n = split(line, f, / \| /); out = f[1]
    for (i = 2; i <= n; i++) out = out "\t" f[i]
    print out }' "$1"
}

# store_end_write: release the lock before the end of the script, so another
# command (tracker.sh, from merge.sh) can write.
store_end_write() { rmdir "$STORE/.lock" 2>/dev/null || true; trap - EXIT; }
