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
#   cr-open --head <branch> --title <t> --body-file <f> [--base <b>] [--label <l>]...
#   cr-update <n|branch> [--title <t>] [--body-file <f>] [--add-label <l>]... [--remove-label <l>]...
#   cr-status <n|branch>
#   cr-list [--base <b>] [--state merged|open|closed|all]
#   pipeline-render [<config>]
#   pipeline-status <commit|tag|branch|cr-number> [--event change_request|merge|release]
#   tag-create <tag> <commit> [-m <message>]
#   release-draft <tag> --notes-file <f> [--title <t>] [--asset <file>]...
#   release-publish <tag>
#   release-view <tag>
#   release-links <tag> [<path>]
#   licence <key> [<holder>] [<year>]
#   owner-name
#   gitignore [<language>]
#
# -C <project>: the project's folder (default: the current one).
# Settings live in the repository's own git config (i2r.*), never in a commit.
# Exit status: 0 on success, 1 on failure.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adapters/forge/local/lib.sh
. "$here/lib.sh"

usage() { sed -n '5,31p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

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

  cr-open)
    need_repo; store_resolve "$PROJECT"
    head="" base="" title="" body="" labels=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --head) head=${2-}; shift 2 ;;
        --base) base=${2-}; shift 2 ;;
        --title) title=${2-}; shift 2 ;;
        --body-file) body=${2-}; shift 2 ;;
        --label) labels=$(list_add "$labels" "${2-}"); shift 2 ;;
        *) usage ;;
      esac
    done
    [[ -n $head && -n $title && -n $body ]] || die "cr-open needs --head, --title and --body-file"
    [[ -f $body ]] || die "no such body file: $body"
    check_line "a title" "$title"
    base=${base:-$(default_branch)}
    [[ $head != "$base" ]] || die "the head and base branches are the same: $head"
    git -C "$PROJECT" rev-parse -q --verify "refs/heads/$head" >/dev/null || die "no local branch $head"
    git -C "$PROJECT" rev-parse -q --verify "refs/heads/$base" >/dev/null || die "no local branch $base"
    [[ $(git -C "$PROJECT" rev-list --count "$base..$head") -gt 0 ]] || die "$head has no commits that aren't on $base"
    if store_is_store; then
      for n in $(cr_numbers); do
        f=$(cr_file "$n")
        if [[ $(rec_get "$f" Head) == "$head" && $(rec_get "$f" State) == open ]]; then
          echo "exists $n (an open change request for $head; use cr-update)"; exit 0
        fi
      done
    fi
    store_begin_write
    old_ifs=$IFS; IFS=,
    for l in $labels; do
      l=${l# }
      table_rows "$STORE/labels.md" | cut -f1 | tr '[:upper:]' '[:lower:]' | grep -xF -- "$(lower "$l")" >/dev/null ||
        die "no label '$l' in the store; create it with label-ensure first"
    done
    IFS=$old_ifs
    mkdir -p "$STORE/crs"
    n=$(store_next_number); f=$(cr_file "$n")
    {
      printf 'Number: %s\nTitle: %s\nState: open\nHead: %s\nBase: %s\nCreated: %s\n' "$n" "$title" "$head" "$base" "$(today)"
      printf 'Labels:%s\nMerged:\nMerge-Commit:\nCloses:\n\n' "${labels:+ $labels}"
      cat "$body"
    } > "$f"
    store_commit "cr.open: #$n $title"
    echo "opened $n"
    echo "closes: $(closes_issues "$f")"
    ;;

  cr-update)
    [[ $# -ge 1 ]] || usage
    need_repo; store_resolve "$PROJECT"; store_require_read || die "no change requests: the store doesn't exist yet"
    n=$(cr_find "$1"); shift; f=$(cr_file "$n")
    [[ $(rec_get "$f" State) == open ]] || die "#$n is $(rec_get "$f" State); it isn't updated"
    title="" body="" add="" remove="" changes=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --title) title=${2-}; shift 2 ;;
        --body-file) body=${2-}; shift 2 ;;
        --add-label) add=$(list_add "$add" "${2-}"); shift 2 ;;
        --remove-label) remove=$(list_add "$remove" "${2-}"); shift 2 ;;
        *) usage ;;
      esac
    done
    store_begin_write
    if [[ -n $title ]]; then
      check_line "a title" "$title"; old=$(rec_get "$f" Title)
      if [[ $old != "$title" ]]; then rec_set "$f" Title "$title"; changes="${changes}title: $old → $title"$'\n'; fi
    fi
    if [[ -n $body ]]; then
      [[ -f $body ]] || die "no such body file: $body"
      if [[ $(rec_body "$f" | normalise_body) != "$(normalise_body < "$body")" ]]; then
        rec_set_body "$f" "$body"; changes="${changes}body changed"$'\n'
      fi
    fi
    old=$(rec_get "$f" Labels); new=$old
    old_ifs=$IFS; IFS=,
    for l in $add; do
      l=${l# }
      table_rows "$STORE/labels.md" | cut -f1 | tr '[:upper:]' '[:lower:]' | grep -xF -- "$(lower "$l")" >/dev/null ||
        die "no label '$l' in the store; create it with label-ensure first"
      list_has "$new" "$l" ci || new=$(list_add "$new" "$l")
    done
    for l in $remove; do l=${l# }; new=$(list_remove "$new" "$l" ci); done
    IFS=$old_ifs
    if [[ $new != "$old" ]]; then rec_set "$f" Labels "$new"; changes="${changes}labels: ${old:-none} → ${new:-none}"$'\n'; fi
    if [[ -z $changes ]]; then echo "no changes"; exit 0; fi
    store_commit "cr.update: #$n"
    printf '%s' "$changes"
    ;;

  cr-status)
    [[ $# -ge 1 ]] || usage
    need_repo; store_resolve "$PROJECT"; store_require_read || die "no change requests: the store doesn't exist yet"
    n=$(cr_find "$1" any); f=$(cr_file "$n")
    state=$(rec_get "$f" State); head=$(rec_get "$f" Head); base=$(rec_get "$f" Base)
    if [[ $state == merged ]]; then
      mergeable="merged"; closes=$(rec_get "$f" Closes)
    else
      closes=$(closes_issues "$f")
      if ! git -C "$PROJECT" rev-parse -q --verify "refs/heads/$head" >/dev/null; then mergeable="unknown (no branch $head)"
      else
        rc=0; git -C "$PROJECT" merge-tree --write-tree --quiet "$base" "$head" >/dev/null 2>&1 || rc=$?
        case $rc in
          0) mergeable=yes ;;
          1) mergeable=conflicts ;;
          *) mergeable="unknown (git merge-tree failed; it needs git 2.38 or later)" ;;
        esac
      fi
    fi
    printf 'number: %s\nstate: %s\ntitle: %s\nhead: %s\nbase: %s\nlabels: %s\n' "$n" "$state" "$(rec_get "$f" Title)" "$head" "$base" "$(rec_get "$f" Labels)"
    printf 'checks: no checks reported (no pipeline service: the local runs in the body are the check)\n'
    printf 'review: no review required\nmergeable: %s\ncloses: %s\n' "$mergeable" "$closes"
    [[ $state != merged ]] || printf 'merged: %s\nmerge_commit: %s\n' "$(rec_get "$f" Merged)" "$(rec_get "$f" Merge-Commit)"
    printf 'record: %s\n' "$f"
    ;;

  cr-list)
    need_repo; store_resolve "$PROJECT"
    base="" state=merged
    while [[ $# -gt 0 ]]; do
      case $1 in
        --base) base=${2-}; shift 2 ;;
        --state) state=${2-}; shift 2 ;;
        *) usage ;;
      esac
    done
    case $state in merged|open|closed|all) ;; *) die "--state is merged, open, closed or all" ;; esac
    base=${base:-$(default_branch)}
    store_require_read || exit 0
    for n in $(cr_numbers); do
      f=$(cr_file "$n"); s=$(rec_get "$f" State)
      [[ $(rec_get "$f" Base) == "$base" ]] || continue
      [[ $state == all || $s == "$state" ]] || continue
      if [[ $state == merged ]]; then
        printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$(rec_get "$f" Title)" "$(rec_get "$f" Merged)" "$(rec_get "$f" Merge-Commit)" "$(rec_get "$f" Closes)"
      else
        printf '%s\t%s\t%s\t%s\n' "$n" "$s" "$(rec_get "$f" Title)" "$(rec_get "$f" Head)"
      fi
    done
    ;;

  pipeline-render)
    need_repo
    config="${1:-$PROJECT/.project/config.yml}"
    [[ -f $config ]] || die "$config not found"
    list=$(stage_list "$config") || die "the pipeline block can't be run (see above)"
    echo "no CI files written: the local forge has no pipeline service; the stages run locally"
    while IFS=$'\t' read -r st en mode runs what; do
      if [[ $en == true ]]; then printf '  %s\t%s, on %s: %s\n' "$st" "$mode" "$runs" "$what"
      else printf '  %s\tplaceholder: %s\n' "$st" "$what"; fi
    done <<<"$list"
    ;;

  pipeline-status)
    [[ $# -ge 1 ]] || usage
    need_repo; target=$1; shift; event=""
    while [[ $# -gt 0 ]]; do
      case $1 in --event) event=${2-}; shift 2 ;; *) usage ;; esac
    done
    # A change request is checked at its head; a tag on release; anything else as asked.
    if [[ $target =~ ^[0-9]+$ ]]; then
      store_resolve "$PROJECT"; store_require_read || die "no change requests: the store doesn't exist yet"
      f=$(cr_file "$target"); [[ -f $f ]] || die "no change request #$target"
      target=$(rec_get "$f" Head); event=${event:-change_request}
    elif git -C "$PROJECT" rev-parse -q --verify "refs/tags/$target" >/dev/null; then
      event=${event:-release}
    fi
    event=${event:-change_request}
    case $event in change_request|merge|release) ;; *) die "--event is change_request, merge or release" ;; esac
    sha=$(git -C "$PROJECT" rev-parse -q --verify "$target^{commit}") || die "no commit for $target"
    tmp=$(mktemp -d); logs=$(mktemp -d)
    trap 'git -C "$PROJECT" worktree remove --force "$tmp/wt" >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
    git -C "$PROJECT" worktree add -q --detach "$tmp/wt" "$sha" >/dev/null 2>&1 || die "couldn't make a clean worktree for $sha"
    config="$tmp/wt/.project/config.yml"
    [[ -f $config ]] || die "$target has no .project/config.yml"
    list=$(stage_list "$config") || die "the pipeline block at $target can't be run"
    echo "commit: $(git -C "$PROJECT" rev-parse --short "$sha") ($event)"
    overall=pass
    while IFS=$'\t' read -r st en mode runs what; do
      case " $runs " in *" $event "*) ;; *) printf '%s: skipped (runs on %s)\n' "$st" "$runs"; continue ;; esac
      if [[ $en != true ]]; then printf '%s: pass (placeholder)\n' "$st"; continue; fi
      if (cd "$tmp/wt" && bash -c "$what") > "$logs/$st.log" 2>&1; then printf '%s: pass\n' "$st"
      elif [[ $mode == advisory ]]; then printf '%s: fail (advisory; log: %s)\n' "$st" "$logs/$st.log"
      else printf '%s: fail (log: %s)\n' "$st" "$logs/$st.log"; overall=fail; fi
    done <<<"$list"
    echo "overall: $overall"
    ;;

  tag-create)
    [[ $# -ge 2 ]] || usage
    need_repo; tag=$1 target=$2; shift 2; msg=$tag
    [[ ${1:-} == -m ]] && { msg=${2-}; shift 2; }
    git check-ref-format "refs/tags/$tag" || die "not a valid tag name: $tag"
    sha=$(git -C "$PROJECT" rev-parse -q --verify "$target^{commit}") || die "no commit for $target"
    if cur=$(git -C "$PROJECT" rev-parse -q --verify "refs/tags/$tag^{commit}"); then
      [[ $cur == "$sha" ]] && { echo "no change: $tag is at $(git -C "$PROJECT" rev-parse --short "$sha")"; exit 0; }
      die "$tag already exists at $(git -C "$PROJECT" rev-parse --short "$cur"), not $(git -C "$PROJECT" rev-parse --short "$sha"); a release tag is never moved"
    fi
    git -C "$PROJECT" tag -a "$tag" "$sha" -m "$msg"
    echo "created $tag at $(git -C "$PROJECT" rev-parse --short "$sha")"
    ;;

  release-draft)
    [[ $# -ge 1 ]] || usage
    need_repo; store_resolve "$PROJECT"; tag=$1; shift; title=$tag notes="" assets=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --title) title=${2-}; shift 2 ;;
        --notes-file) notes=${2-}; shift 2 ;;
        --asset) assets+=("${2-}"); shift 2 ;;
        *) usage ;;
      esac
    done
    [[ -n $notes && -f $notes ]] || die "release-draft needs --notes-file with an existing file"
    check_line "a title" "$title"
    sha=$(git -C "$PROJECT" rev-parse -q --verify "refs/tags/$tag^{commit}") || die "tag $tag doesn't exist: run tag.create first"
    for a in ${assets[@]+"${assets[@]}"}; do [[ -f $a ]] || die "no such asset: $a"; done
    store_begin_write
    d="$STORE/releases/$tag" r="$STORE/releases/$tag/release.md" changes=""
    if [[ -f $r ]]; then
      [[ $(rec_get "$r" State) == draft ]] || die "$tag is already published; a correction is a new patch release"
      old=$(rec_get "$r" Title); [[ $old == "$title" ]] || { rec_set "$r" Title "$title"; changes="${changes}title: $old → $title"$'\n'; }
      old=$(rec_get "$r" Commit); [[ $old == "$sha" ]] || { rec_set "$r" Commit "$sha"; changes="${changes}commit: $old → $sha"$'\n'; }
      if [[ $(rec_body "$r" | normalise_body) != "$(normalise_body < "$notes")" ]]; then rec_set_body "$r" "$notes"; changes="${changes}notes changed"$'\n'; fi
      verb=updated
    else
      mkdir -p "$d/assets"
      { printf 'Tag: %s\nTitle: %s\nState: draft\nCommit: %s\nCreated: %s\nPublished:\n\n' "$tag" "$title" "$sha" "$(today)"; cat "$notes"; } > "$r"
      verb=created
    fi
    mkdir -p "$d/assets"
    for a in ${assets[@]+"${assets[@]}"}; do
      b=$(basename "$a")
      if [[ -f $d/assets/$b ]] && cmp -s "$a" "$d/assets/$b"; then continue; fi
      cp "$a" "$d/assets/$b"; changes="${changes}asset: $b"$'\n'
    done
    if [[ $verb == updated && -z $changes ]]; then echo "no changes: draft $tag"; exit 0; fi
    store_commit "release.draft: $tag"
    echo "$verb draft $tag ($r)"
    printf '%s' "$changes"
    for a in "$d"/assets/*; do [[ -f $a ]] && printf 'asset %s %s bytes\n' "$(basename "$a")" "$(wc -c < "$a" | tr -d ' ')"; done
    true
    ;;

  release-publish)
    [[ $# -ge 1 ]] || usage
    need_repo; store_resolve "$PROJECT"; store_require_read || die "no releases: the store doesn't exist yet"
    tag=$1; r="$STORE/releases/$tag/release.md"
    [[ -f $r ]] || die "no draft for $tag: run release.draft first"
    [[ $(rec_get "$r" State) != published ]] || { echo "no change: $tag was published $(rec_get "$r" Published)"; exit 0; }
    sha=$(git -C "$PROJECT" rev-parse -q --verify "refs/tags/$tag^{commit}") || die "tag $tag is missing"
    [[ $sha == "$(rec_get "$r" Commit)" ]] || die "tag $tag points at $sha, not the drafted commit $(rec_get "$r" Commit)"
    store_begin_write
    rec_set "$r" State published; rec_set "$r" Published "$(today)"
    store_commit "release.publish: $tag"
    echo "published $tag ($r)"
    ;;

  release-view)
    [[ $# -ge 1 ]] || usage
    need_repo; store_resolve "$PROJECT"; store_require_read || die "no releases: the store doesn't exist yet"
    r="$STORE/releases/$1/release.md"
    [[ -f $r ]] || die "release not found: $1"
    cat "$r"
    for a in "$STORE/releases/$1"/assets/*; do [[ -f $a ]] && printf 'asset %s %s bytes\n' "$(basename "$a")" "$(wc -c < "$a" | tr -d ' ')"; done
    true
    ;;

  release-links)
    [[ $# -ge 1 ]] || usage
    need_repo; store_resolve "$PROJECT"
    printf 'release: %s/releases/%s/release.md\n' "$STORE" "$1"
    printf 'file: %s at %s (git show %s:%s)\n' "${2:-<path>}" "$1" "$1" "${2:-<path>}"
    printf 'compare: none (the changelog has no link references)\n'
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
