#!/usr/bin/env bash
# The local forge: a git repository on one machine, with no hosting service
# and no remote (decision 0027). See adapters/forge/local.md.
#
# Usage: forge.sh [-C <project>] <command> [arguments]
#
#   repo-describe
#   repo-create [--default-branch <b>] [--description <d>]
#   repo-configure [--merge-method squash] [--delete-branch-on-merge true|false]
#                  [--description <d>] [--visibility <v>] [--features <f>]
#   access-list
#   access-grant <login> <role>
#   rule-protect-branch [--check]
#   rule-require-review <approvals> [true|false] [--check]
#   rule-require-checks <stage>... [--check]
#   licence <key> [<holder>] [<year>]
#   owner-name
#   gitignore [<language>]
#
# -C <project>: the project's folder (default: the current one).
# Settings live in the repository's own git config (i2r.*), never in a commit.
# Exit status: 0 on success, 1 on failure.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adapters/tracker/local/store.sh
. "$here/../../tracker/local/store.sh"

usage() { sed -n '5,19p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

project="."
if [[ ${1:-} == -C ]]; then [[ $# -ge 2 ]] || usage; project=$2; shift 2; fi
[[ $# -ge 1 ]] || usage
cmd=$1; shift

# The marker line that identifies hooks this adapter installed.
marker="# idea-to-release local forge: rule.protect-branch"

in_repo() { git -C "$project" rev-parse --show-toplevel >/dev/null 2>&1; }
need_repo() {
  in_repo || die "$project is not a git repository; run repo-create first"
  PROJECT=$(git -C "$project" rev-parse --show-toplevel)
}
setting() { git -C "$PROJECT" config --get "i2r.$1" || true; }
default_branch() {
  local b=""
  [[ -f $PROJECT/.project/config.yml ]] && b=$(config_value "$PROJECT/.project/config.yml" default_branch)
  [[ -n $b ]] || b=$(git -C "$PROJECT" symbolic-ref --short HEAD 2>/dev/null || true)
  printf '%s' "${b:-main}"
}
description() {
  local f; f=$(git -C "$PROJECT" rev-parse --git-path description)
  case $f in /*) ;; *) f="$PROJECT/$f" ;; esac
  if [[ -f $f ]] && ! grep -q '^Unnamed repository' "$f"; then head -1 "$f"; fi
}
set_description() {
  local f; f=$(git -C "$PROJECT" rev-parse --git-path description)
  case $f in /*) ;; *) f="$PROJECT/$f" ;; esac
  printf '%s\n' "$1" > "$f"
}
hooks_dir() {
  local d; d=$(git -C "$PROJECT" rev-parse --git-path hooks)
  case $d in /*) ;; *) d="$PROJECT/$d" ;; esac
  printf '%s' "$d"
}

# The two hooks rule.protect-branch installs, for the default branch.
hook_pre_commit() {
  cat <<EOF
#!/bin/sh
$marker
# Refuses commits on the default branch, except from the adapter's merge step.
[ "\${I2R_MERGE:-}" = 1 ] && exit 0
branch=\$(git symbolic-ref --short HEAD 2>/dev/null) || exit 0
if [ "\$branch" = "$1" ]; then
  echo "error: '$1' is protected (idea-to-release local forge): commit on a branch, and merge it with merge.sh" >&2
  exit 1
fi
EOF
}
hook_reference_transaction() {
  cat <<EOF
#!/bin/sh
$marker
# Refuses any change to the default branch (a commit, a merge, a reset, a
# force update or a deletion), except from the adapter's merge step.
[ "\$1" = prepared ] || exit 0
[ "\${I2R_MERGE:-}" = 1 ] && exit 0
status=0
zero=0000000000000000000000000000000000000000
packed="\$(git rev-parse --git-common-dir)/packed-refs"
while read -r old new ref; do
  [ "\$ref" = "refs/heads/$1" ] || continue
  cur=\$(git rev-parse -q --verify "\$ref" 2>/dev/null) || cur=""
  # Judge the effect, not the raw line: git sends zero values when it doesn't
  # verify the old value (git branch -f, git branch -D), and pack-refs moves a
  # ref from a loose file into packed-refs without changing it.
  [ -z "\$cur" ] && continue                                    # creating the branch
  [ "\$new" != "\$zero" ] && [ "\$new" = "\$cur" ] && continue    # no change
  if [ "\$new" = "\$zero" ] && [ "\$old" = "\$cur" ] && [ -f "\$packed" ] &&
     grep -qx "\$cur \$ref" "\$packed"; then continue; fi          # pack-refs
  echo "error: '$1' is protected (idea-to-release local forge): changes reach it only through merge.sh" >&2
  status=1
done
exit \$status
EOF
}

# hook_state <name> <wanted-content>: missing | same | ours-different | foreign
hook_state() {
  local f; f="$(hooks_dir)/$1"
  if [[ ! -e $f ]]; then echo missing
  elif [[ $(cat "$f") == "$2" ]]; then echo same
  elif grep -qxF -- "$marker" "$f"; then echo ours-different
  else echo foreign; fi
}

case $cmd in
  repo-describe)
    if ! in_repo; then echo "exists: false"; exit 0; fi
    need_repo
    store_resolve "$PROJECT"
    empty=true; git -C "$PROJECT" rev-parse --verify -q HEAD >/dev/null && empty=false
    remotes=$(git -C "$PROJECT" remote | tr '\n' ' '); remotes=${remotes% }
    store_state=missing; if store_is_store; then store_state=exists; elif [[ -e $STORE ]]; then store_state="not a tracker store"; fi
    licence=none; [[ -f $PROJECT/LICENSE ]] && licence="present ($(head -1 "$PROJECT/LICENSE"))"
    printf 'exists: true\npath: %s\nempty: %s\nvisibility: not applicable (local)\ndefault_branch: %s\n' "$PROJECT" "$empty" "$(default_branch)"
    printf 'description: %s\nmerge_methods: %s\ndelete_branch_on_merge: %s\n' "$(description)" "$(setting mergemethod)" "$(setting deletebranchonmerge)"
    printf 'features: not applicable (issues are in the tracker store)\nlicence: %s\ntracker_store: %s (%s)\nremotes: %s\n' "$licence" "$store_state" "$STORE" "${remotes:-none}"
    ;;

  repo-create)
    branch=main desc=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --default-branch) branch=${2-}; shift 2 ;;
        --description) desc=${2-}; shift 2 ;;
        *) usage ;;
      esac
    done
    check_line "a description" "$desc"
    if in_repo; then
      need_repo
      echo "exists $PROJECT (adopt it; nothing created)"
      exit 0
    fi
    mkdir -p "$project"
    git -C "$project" init -q
    git -C "$project" symbolic-ref HEAD "refs/heads/$branch"
    need_repo
    [[ -z $desc ]] || set_description "$desc"
    echo "created $PROJECT (default branch $branch, no remote)"
    ;;

  repo-configure)
    need_repo; changes=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --merge-method)
          [[ ${2-} == squash ]] || die "the local forge supports only the squash merge method, not '${2-}'"
          old=$(setting mergemethod)
          [[ $old == squash ]] || { git -C "$PROJECT" config i2r.mergemethod squash; changes="${changes}merge_method: ${old:-unset} → squash"$'\n'; }
          shift 2 ;;
        --delete-branch-on-merge)
          case ${2-} in true|false) ;; *) die "--delete-branch-on-merge is true or false" ;; esac
          old=$(setting deletebranchonmerge)
          [[ $old == "$2" ]] || { git -C "$PROJECT" config i2r.deletebranchonmerge "$2"; changes="${changes}delete_branch_on_merge: ${old:-unset} → $2"$'\n'; }
          shift 2 ;;
        --description)
          check_line "a description" "${2-}"
          old=$(description)
          [[ $old == "${2-}" ]] || { set_description "$2"; changes="${changes}description: ${old:-none} → $2"$'\n'; }
          shift 2 ;;
        --visibility|--features)
          echo "${1#--}: not applicable on the local forge; ignored"; shift 2 ;;
        *) usage ;;
      esac
    done
    if [[ -z $changes ]]; then echo "no changes"; else printf '%s' "$changes"; fi
    ;;

  access-list)
    need_repo
    name=$(git -C "$PROJECT" config user.name || true)
    printf '%s\tadmin\n' "${name:-the local user}"
    echo "people who can write: 1"
    ;;

  access-grant)
    die "access.grant isn't applicable on the local forge: the repository is on one machine, for one person. Share the folder by other means if you must"
    ;;

  rule-protect-branch)
    need_repo; check=""; [[ ${1:-} == --check ]] && check=1
    b=$(default_branch); out=""; blocked=""
    for h in pre-commit reference-transaction; do
      if [[ $h == pre-commit ]]; then want=$(hook_pre_commit "$b"); else want=$(hook_reference_transaction "$b"); fi
      state=$(hook_state "$h" "$want")
      case $state in
        same) out="${out}$h: present"$'\n' ;;
        foreign) out="${out}$h: a different hook is installed, not this adapter's; left alone"$'\n'; blocked=1 ;;
        missing|ours-different)
          if [[ -n $check ]]; then out="${out}$h: $state → install"$'\n'
          else
            mkdir -p "$(hooks_dir)"
            printf '%s\n' "$want" > "$(hooks_dir)/$h"; chmod +x "$(hooks_dir)/$h"
            out="${out}$h: installed"$'\n'
          fi ;;
      esac
    done
    printf '%s' "$out"
    if [[ -n $blocked ]]; then
      echo "the default branch '$b' is not fully protected: merge the existing hook with this adapter's by hand (see local.md)" >&2
      exit 1
    fi
    [[ -n $check ]] || echo "'$b' now refuses direct commits, merges, resets, force updates and deletion, except through merge.sh"
    ;;

  rule-require-review)
    need_repo
    [[ $# -ge 1 ]] || usage
    approvals=$1; shift; owners=false check=""
    for a in "$@"; do case $a in --check) check=1 ;; true|false) owners=$a ;; *) usage ;; esac; done
    [[ $approvals =~ ^[0-9]+$ ]] || die "approvals is a number"
    [[ $approvals == 0 ]] || die "the local forge has one person, who can't approve their own change: required_approvals must be 0 (decision 0011)"
    [[ $owners == false ]] || die "code owners aren't applicable on the local forge"
    old=$(setting requiredapprovals)
    if [[ $old == 0 ]]; then echo "no change: required approvals 0"
    elif [[ -n $check ]]; then echo "required approvals: ${old:-unset} → 0"
    else git -C "$PROJECT" config i2r.requiredapprovals 0; echo "required approvals: ${old:-unset} → 0"; fi
    ;;

  rule-require-checks)
    need_repo; check="" stages=""
    for a in "$@"; do
      case $a in
        --check) check=1 ;;
        *) [[ $a =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "not a stage name: $a"; stages="${stages:+$stages }$a" ;;
      esac
    done
    [[ -n $stages ]] || usage
    old=$(setting requiredchecks)
    if [[ $old == "$stages" ]]; then echo "no change: required checks $stages"
    elif [[ -n $check ]]; then echo "required checks: ${old:-none} → $stages"
    else git -C "$PROJECT" config i2r.requiredchecks "$stages"; echo "required checks: ${old:-none} → $stages (merge.sh runs them)"; fi
    ;;

  licence)
    [[ $# -ge 1 ]] || usage
    key=$(lower "$1"); holder=${2:-} year=${3:-$(date -u +%Y)}
    f="$here/licences/$key.txt"
    if [[ ! -f $f ]]; then
      have=""; for l in "$here"/licences/*.txt; do l=$(basename "$l" .txt); have="$have $l"; done; have=${have# }
      die "no bundled text for '$key' (bundled: $have); ask the user for the licence text"
    fi
    H="$holder" Y="$year" awk 'BEGIN { h = ENVIRON["H"]; y = ENVIRON["Y"] }
      { if (h != "") gsub(/\[fullname\]/, h); gsub(/\[year\]/, y); print }' "$f"
    ;;

  owner-name)
    name=$(git config user.name || true)
    [[ -n $name ]] || die "git's user.name isn't set; ask the user for the name"
    printf '%s\n' "$name"
    ;;

  gitignore)
    [[ -z ${1:-} ]] || note "the local forge has no .gitignore templates; '$1' isn't included, only the OS and editor block"
    printf '# OS and editor files\n.DS_Store\nThumbs.db\n.idea/\n.vscode/\n*.swp\n'
    ;;

  -h|--help) usage ;;
  *) echo "error: unknown command: $cmd" >&2; usage ;;
esac
