#!/usr/bin/env bash
# The local tracker: issues, labels and milestones in a store outside the
# project (decision 0027). See adapters/tracker/local.md.
#
# Usage: tracker.sh [-C <project>] <command> [arguments]
#
#   store-path
#   label-ensure <name> <colour> <description> [--update]
#   label-list
#   milestone-ensure <title> [<description>] [--update] [--reopen]
#   milestone-list
#   issue-create --title <t> --body-file <f> [--label <l>]... [--milestone <m>]
#   issue-update <n> [--title <t>] [--body-file <f>] [--add-label <l>]...
#                    [--remove-label <l>]... [--milestone <m> | --remove-milestone]
#   issue-link <n> blocked-by|blocks|parent <other> [--remove]
#   issue-close <n> --reason completed|not-planned [--comment <c>]
#   issue-list [--state open|closed|all] [--label <l>]... [--milestone <m>] [--bodies]
#   issue-view <n>
#
# -C <project>: the project's folder (default: the current one).
# Exit status: 0 on success, 1 on failure.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adapters/tracker/local/store.sh
. "$here/store.sh"

usage() { sed -n '5,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

project="."
if [[ ${1:-} == -C ]]; then [[ $# -ge 2 ]] || usage; project=$2; shift 2; fi
[[ $# -ge 1 ]] || usage
cmd=$1; shift
store_resolve "$project"

issue_file() { printf '%s/issues/%04d.md' "$STORE" "$1"; }
need_issue() {
  [[ $1 =~ ^[0-9]+$ ]] || die "not an issue number: $1"
  local f; f=$(issue_file "$1")
  [[ -f $f ]] || die "no issue #$1 in $STORE"
  printf '%s' "$f"
}
label_known() { table_rows "$STORE/labels.md" | cut -f1 | while IFS= read -r l; do [[ $(lower "$l") == "$(lower "$1")" ]] && { echo yes; break; }; done; }
milestone_known() { table_rows "$STORE/milestones.md" | cut -f2 | grep -xF -- "$1" >/dev/null; }

# All issue numbers, in order.
issue_numbers() {
  local f
  for f in "$STORE"/issues/*.md; do
    [[ -f $f ]] || continue
    f=$(basename "$f" .md); printf '%d\n' "$((10#$f))"
  done
}

# reaches <from> <to> <key>: 0 if following <key> links from <from> reaches <to>.
reaches() {
  local todo="$1" seen=" " cur next f
  while [[ -n $todo ]]; do
    cur=${todo%% *}; todo=${todo#"$cur"}; todo=${todo# }
    [[ $cur == "$2" ]] && return 0
    case $seen in *" $cur "*) continue ;; esac
    seen="$seen$cur "
    f=$(issue_file "$cur"); [[ -f $f ]] || continue
    next=$(rec_get "$f" "$3" | tr -d ',')
    [[ -n $next ]] && todo="$todo $next" && todo=${todo# }
  done
  return 1
}

case $cmd in
  store-path)
    printf '%s\n' "$STORE"
    if store_is_store; then echo "exists"; elif [[ -e $STORE ]]; then echo "not a tracker store"; else echo "missing"; fi
    ;;

  label-ensure)
    [[ $# -ge 3 ]] || usage
    name=$1 colour=$2 desc=$3 update=""; shift 3
    [[ ${1:-} == --update ]] && update=1
    check_line "a label name" "$name" ',|'; check_line "a label description" "$desc" '|'
    [[ -n $name ]] || die "a label needs a name"
    [[ $colour =~ ^[0-9a-fA-F]{6}$ ]] || die "a colour is six hex digits, without #: $colour"
    colour=$(lower "$colour")
    if [[ -e $STORE ]]; then store_require_read; fi
    current=""
    if store_is_store 2>/dev/null; then
      current=$(table_rows "$STORE/labels.md" | N="$(lower "$name")" awk -F'\t' 'BEGIN { n = ENVIRON["N"] } tolower($1) == n { print; exit }')
    fi
    if [[ -n $current ]]; then
      cur_colour=$(cut -f2 <<<"$current"); cur_desc=$(cut -f3 <<<"$current")
      if [[ $(lower "$cur_colour") == "$colour" && $cur_desc == "$desc" ]]; then echo "same $(cut -f1 <<<"$current")"; exit 0; fi
      if [[ -z $update ]]; then echo "different $name: $cur_colour \"$cur_desc\" (wanted $colour \"$desc\")"; exit 0; fi
      store_begin_write
      N="$(lower "$name")" ROW="| $name | $colour | $desc |" awk '
        BEGIN { n = ENVIRON["N"]; row = ENVIRON["ROW"] }
        /^\|---/ { on = 1; print; next }
        on && /^\| / { split(substr($0, 3), f, / \| /); if (tolower(f[1]) == n) { print row; next } }
        { print }' "$STORE/labels.md" > "$STORE/labels.md.tmp" && mv "$STORE/labels.md.tmp" "$STORE/labels.md"
      store_commit "label.ensure: update $name"
      echo "updated $name: $cur_colour \"$cur_desc\" → $colour \"$desc\""
    else
      store_begin_write
      printf '| %s | %s | %s |\n' "$name" "$colour" "$desc" >> "$STORE/labels.md"
      store_commit "label.ensure: create $name"
      echo "created $name"
    fi
    ;;

  label-list)
    store_require_read || exit 0
    table_rows "$STORE/labels.md"
    ;;

  milestone-ensure)
    [[ $# -ge 1 ]] || usage
    title=$1; shift; desc="" update="" reopen=""
    if [[ $# -gt 0 && $1 != --* ]]; then desc=$1; shift; fi
    while [[ $# -gt 0 ]]; do
      case $1 in --update) update=1 ;; --reopen) reopen=1 ;; *) usage ;; esac; shift
    done
    check_line "a milestone title" "$title" '|'; check_line "a milestone description" "$desc" '|'
    [[ -n $title ]] || die "a milestone needs a title"
    if [[ -e $STORE ]]; then store_require_read; fi
    current=""
    if store_is_store 2>/dev/null; then
      current=$(table_rows "$STORE/milestones.md" | T="$title" awk -F'\t' 'BEGIN { t = ENVIRON["T"] } $2 == t { print; exit }')
    fi
    if [[ -z $current ]]; then
      store_begin_write
      n=$(( $(table_rows "$STORE/milestones.md" | wc -l) + 1 ))
      printf '| %s | %s | open | %s |\n' "$n" "$title" "$desc" >> "$STORE/milestones.md"
      store_commit "milestone.ensure: create $title"
      echo "created $n $title"
      exit 0
    fi
    n=$(cut -f1 <<<"$current"); state=$(cut -f3 <<<"$current"); cur_desc=$(cut -f4 <<<"$current")
    new_state=$state new_desc=$cur_desc
    [[ -n $reopen ]] && new_state=open
    [[ -n $update ]] && new_desc=$desc
    if [[ $new_state != "$state" || $new_desc != "$cur_desc" ]]; then
      store_begin_write
      T="$title" ROW="| $n | $title | $new_state | $new_desc |" awk '
        BEGIN { t = ENVIRON["T"]; row = ENVIRON["ROW"] }
        /^\|---/ { on = 1; print; next }
        on && /^\| / { split(substr($0, 3), f, / \| /); if (f[2] == t) { print row; next } }
        { print }' "$STORE/milestones.md" > "$STORE/milestones.md.tmp" && mv "$STORE/milestones.md.tmp" "$STORE/milestones.md"
      store_commit "milestone.ensure: update $title"
      echo "updated $n $title"
      exit 0
    fi
    if [[ $state == closed ]]; then echo "closed $n $title"
    elif [[ $cur_desc != "$desc" ]]; then echo "different $n $title: \"$cur_desc\" (wanted \"$desc\")"
    else echo "same $n $title"; fi
    ;;

  milestone-list)
    store_require_read || exit 0
    table_rows "$STORE/milestones.md"
    ;;

  issue-create)
    title="" body="" labels="" milestone=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --title) title=${2-}; shift 2 ;;
        --body-file) body=${2-}; shift 2 ;;
        --label) labels=$(list_add "$labels" "${2-}"); shift 2 ;;
        --milestone) milestone=${2-}; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ -n $title && -n $body ]] || die "issue-create needs --title and --body-file"
    [[ -f $body ]] || die "no such body file: $body"
    check_line "a title" "$title"
    # Find an existing issue carrying the same Plan-Task line, instead of creating another.
    marker=$(grep -m1 -E '^Plan-Task: T-[0-9]+$' "$body" || true)
    if [[ -n $marker && -e $STORE ]] && store_require_read; then
      found=""
      for n in $(issue_numbers); do
        if rec_body "$(issue_file "$n")" | grep -xF -- "$marker" >/dev/null; then found="$found $n"; fi
      done
      found=${found# }
      case $found in
        "") ;;
        *" "*) die "more than one issue carries '$marker': $found" ;;
        *) echo "found $found $(rec_get "$(issue_file "$found")" State)"; exit 0 ;;
      esac
    fi
    store_begin_write
    old_ifs=$IFS; IFS=,
    for l in $labels; do
      l=${l# }; [[ -n $(label_known "$l") ]] || die "no label '$l' in the store; create it with label-ensure first"
    done
    IFS=$old_ifs
    [[ -z $milestone ]] || milestone_known "$milestone" || die "no milestone '$milestone' in the store; create it with milestone-ensure first"
    n=$(store_next_number)
    f=$(issue_file "$n")
    {
      printf 'Number: %s\nTitle: %s\nState: open\nCreated: %s\n' "$n" "$title" "$(today)"
      printf 'Labels:%s\nMilestone:%s\n' "${labels:+ $labels}" "${milestone:+ $milestone}"
      printf 'Blocked-by:\nParent:\nClosed:\nReason:\nComment:\n\n'
      cat "$body"
    } > "$f"
    store_commit "issue.create: #$n $title"
    echo "created $n"
    ;;

  issue-update)
    [[ $# -ge 1 ]] || usage
    store_require_read || die "no issue #$1: the store doesn't exist yet"
    f=$(need_issue "$1"); n=$1; shift
    title="" body="" add="" remove="" milestone="" set_ms="" changes=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --title) title=${2-}; shift 2 ;;
        --body-file) body=${2-}; shift 2 ;;
        --add-label) add=$(list_add "$add" "${2-}"); shift 2 ;;
        --remove-label) remove=$(list_add "$remove" "${2-}"); shift 2 ;;
        --milestone) milestone=${2-}; set_ms=1; shift 2 ;;
        --remove-milestone) milestone=""; set_ms=1; shift ;;
        *) usage ;;
      esac
    done
    store_begin_write
    if [[ -n $title ]]; then
      check_line "a title" "$title"
      old=$(rec_get "$f" Title)
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
      l=${l# }; [[ -n $(label_known "$l") ]] || die "no label '$l' in the store; create it with label-ensure first"
      list_has "$new" "$l" ci || new=$(list_add "$new" "$l")
    done
    for l in $remove; do l=${l# }; new=$(list_remove "$new" "$l" ci); done
    IFS=$old_ifs
    if [[ $new != "$old" ]]; then rec_set "$f" Labels "$new"; changes="${changes}labels: ${old:-none} → ${new:-none}"$'\n'; fi
    if [[ -n $set_ms ]]; then
      [[ -z $milestone ]] || milestone_known "$milestone" || die "no milestone '$milestone' in the store"
      old=$(rec_get "$f" Milestone)
      if [[ $old != "$milestone" ]]; then rec_set "$f" Milestone "$milestone"; changes="${changes}milestone: ${old:-none} → ${milestone:-none}"$'\n'; fi
    fi
    if [[ -z $changes ]]; then echo "no changes"; exit 0; fi
    store_commit "issue.update: #$n"
    printf '%s' "$changes"
    ;;

  issue-link)
    [[ $# -ge 3 ]] || usage
    store_require_read || die "no issue #$1: the store doesn't exist yet"
    n=$1 rel=$2 other=$3 rm=""
    [[ ${4:-} == --remove ]] && rm=1
    need_issue "$n" >/dev/null; need_issue "$other" >/dev/null
    [[ $n != "$other" ]] || die "an issue can't be linked to itself"
    case $rel in
      blocks) dep=$other on=$n key=Blocked-by ;;
      blocked-by) dep=$n on=$other key=Blocked-by ;;
      parent) dep=$n on=$other key=Parent ;;
      *) die "unknown relation: $rel (blocked-by, blocks or parent)" ;;
    esac
    f=$(issue_file "$dep"); cur=$(rec_get "$f" "$key")
    if [[ -n $rm ]]; then
      if [[ $key == Parent ]]; then
        [[ $cur == "$on" ]] || { echo "no changes"; exit 0; }
        new=""
      else
        list_has "$cur" "$on" || { echo "no changes"; exit 0; }
        new=$(list_remove "$cur" "$on")
      fi
      store_begin_write; rec_set "$f" "$key" "$new"
      store_commit "issue.link: #$dep no longer $(lower "$key") #$on"
      echo "removed #$dep $(lower "$key") #$on"
      exit 0
    fi
    if [[ $key == Parent ]]; then
      [[ $cur != "$on" ]] || { echo "present #$dep parent #$on"; exit 0; }
      reaches "$on" "$dep" Parent && die "linking #$dep to parent #$on would make a cycle"
      store_begin_write; rec_set "$f" Parent "$on"
      store_commit "issue.link: #$dep parent #$on"
      if [[ -n $cur ]]; then echo "changed #$dep parent: #$cur → #$on"; else echo "added #$dep parent #$on"; fi
    else
      list_has "$cur" "$on" && { echo "present #$dep blocked-by #$on"; exit 0; }
      reaches "$on" "$dep" Blocked-by && die "#$dep blocked-by #$on would make a cycle"
      store_begin_write; rec_set "$f" Blocked-by "$(list_add "$cur" "$on")"
      store_commit "issue.link: #$dep blocked-by #$on"
      echo "added #$dep blocked-by #$on"
    fi
    ;;

  issue-close)
    [[ $# -ge 1 ]] || usage
    store_require_read || die "no issue #$1: the store doesn't exist yet"
    f=$(need_issue "$1"); n=$1; shift; reason="" comment=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --reason) reason=${2-}; shift 2 ;;
        --comment) comment=${2-}; shift 2 ;;
        *) usage ;;
      esac
    done
    case $reason in completed) ;; not-planned|"not planned") reason="not planned" ;; *) die "--reason is completed or not-planned" ;; esac
    check_line "a comment" "$comment"
    if [[ $(rec_get "$f" State) == closed ]]; then echo "no changes (#$n is already closed: $(rec_get "$f" Reason))"; exit 0; fi
    store_begin_write
    rec_set "$f" State closed; rec_set "$f" Closed "$(today)"; rec_set "$f" Reason "$reason"; rec_set "$f" Comment "$comment"
    store_commit "issue.close: #$n ($reason)"
    echo "closed $n $reason"
    ;;

  issue-list)
    state=open labels="" milestone="" bodies=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --state) state=${2-}; shift 2 ;;
        --label) labels=$(list_add "$labels" "${2-}"); shift 2 ;;
        --milestone) milestone=${2-}; shift 2 ;;
        --bodies) bodies=1; shift ;;
        *) usage ;;
      esac
    done
    case $state in open|closed|all) ;; *) die "--state is open, closed or all" ;; esac
    store_require_read || exit 0
    for n in $(issue_numbers); do
      f=$(issue_file "$n")
      s=$(rec_get "$f" State); l=$(rec_get "$f" Labels); m=$(rec_get "$f" Milestone)
      [[ $state == all || $s == "$state" ]] || continue
      [[ -z $milestone || $m == "$milestone" ]] || continue
      ok=1; old_ifs=$IFS; IFS=,
      for x in $labels; do x=${x# }; list_has "$l" "$x" ci || ok=""; done
      IFS=$old_ifs
      [[ -n $ok ]] || continue
      if [[ -n $bodies ]]; then printf '=== #%s\n' "$n"; cat "$f"; printf '\n'
      else printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$s" "$(rec_get "$f" Title)" "$l" "$m" "$(rec_get "$f" Closed)"; fi
    done
    ;;

  issue-view)
    [[ $# -ge 1 ]] || usage
    store_require_read || die "no issue #$1: the store doesn't exist yet"
    f=$(need_issue "$1")
    blocking="" children=""
    for m in $(issue_numbers); do
      g=$(issue_file "$m")
      list_has "$(rec_get "$g" Blocked-by)" "$1" && blocking=$(list_add "$blocking" "$m")
      [[ $(rec_get "$g" Parent) == "$1" ]] && children=$(list_add "$children" "$m")
    done
    awk 'NF == 0 { exit } { print }' "$f"
    printf 'Blocking:%s\nChildren:%s\n\n' "${blocking:+ $blocking}" "${children:+ $children}"
    rec_body "$f"
    ;;

  -h|--help) usage ;;
  *) echo "error: unknown command: $cmd" >&2; usage ;;
esac
