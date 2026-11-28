#!/usr/bin/env bash
# Merge a local change request: the maintainer's command, never a skill's
# (conventions §10, decision 0027). See adapters/forge/local.md.
#
# Usage: merge.sh [-C <project>] <number> [--yes]
#
# 1. Checks the change request is open, and its branches exist.
# 2. Squash-merges the head into the base in a temporary worktree, as one
#    commit "<title> (#<number>)" with the change request's body.
# 3. Runs the required stages (rule.require-checks) on that merge result.
# 4. Asks for a yes (or takes --yes), then moves the base branch to the merge
#    commit, records the merge, closes the issues the body names, and deletes
#    the head branch if delete_branch_on_merge is on.
#
# Refuses, changing nothing, if it isn't open, has conflicts, or a required
# stage fails. Exit status: 0 when merged, 1 otherwise.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adapters/forge/local/lib.sh
. "$here/lib.sh"
tracker="$here/../../tracker/local/tracker.sh"

usage() { sed -n '5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

project="." yes=""
if [[ ${1:-} == -C ]]; then [[ $# -ge 2 ]] || usage; project=$2; shift 2; fi
[[ $# -ge 1 ]] || usage
n=$1; shift
[[ ${1:-} == --yes ]] && yes=1
[[ $n =~ ^[0-9]+$ ]] || usage

store_resolve "$project"
store_require_read || die "no change requests: the tracker store doesn't exist yet"
f=$(cr_file "$n")
[[ -f $f ]] || die "no change request #$n in $STORE"
state=$(rec_get "$f" State); title=$(rec_get "$f" Title); head=$(rec_get "$f" Head); base=$(rec_get "$f" Base)
[[ $state == open ]] || die "#$n is $state, not open"
git -C "$PROJECT" rev-parse -q --verify "refs/heads/$head" >/dev/null || die "no local branch $head"
old=$(git -C "$PROJECT" rev-parse -q --verify "refs/heads/$base") || die "no local branch $base"

# A worktree that has the base checked out must be clean: it's moved forward.
base_wt=""
wt=""
while IFS= read -r line; do
  case $line in
    "worktree "*) wt=${line#worktree } ;;
    "branch refs/heads/$base") base_wt=$wt ;;
  esac
done < <(git -C "$PROJECT" worktree list --porcelain)
if [[ -n $base_wt && -n $(git -C "$base_wt" status --porcelain --untracked-files=no) ]]; then
  die "$base_wt has $base checked out with uncommitted changes; commit or undo them first"
fi

# Merge in a temporary worktree, and run the required stages there.
tmp=$(mktemp -d)
logs=$(mktemp -d)
cleanup() { git -C "$PROJECT" worktree remove --force "$tmp/wt" >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
git -C "$PROJECT" worktree add -q --detach "$tmp/wt" "$old" >/dev/null 2>&1 || die "couldn't make a temporary worktree"
if ! git -C "$tmp/wt" merge -q --squash "$head" >"$logs/merge.log" 2>&1; then
  die "#$n has conflicts with $base; nothing was merged (see $logs/merge.log)"
fi
git -C "$tmp/wt" diff --cached --quiet && die "#$n changes nothing on $base; nothing was merged"
{ printf '%s (#%s)\n\n' "$title" "$n"; rec_body "$f"; } > "$tmp/message"
I2R_MERGE=1 git -C "$tmp/wt" commit -q -F "$tmp/message" || die "couldn't commit the merge"
new=$(git -C "$tmp/wt" rev-parse HEAD)

config="$tmp/wt/.project/config.yml"
[[ -f $config ]] || die "the merge result has no .project/config.yml, so its stages can't run"
stages=$(required_stages "$PROJECT")
echo "Merging #$n \"$title\": $head → $base"
echo "Required stages, on the merge result:"
# shellcheck disable=SC2086
if ! run_stages "$config" "$tmp/wt" "$logs" $stages | sed 's/^/  /'; then
  die "a required stage failed on the merge result; nothing was merged (logs: $logs)"
fi
closes=$(closes_issues "$f")
delete=$(git -C "$PROJECT" config --get i2r.deletebranchonmerge || true)
echo "Commit:  $title (#$n)"
echo "Closes:  ${closes:-none}"
[[ $delete != true ]] || echo "Deletes: branch $head"

if [[ -z $yes ]]; then
  [[ -t 0 ]] || die "not a terminal; run with --yes to merge without asking"
  printf 'Merge? [y/N] '
  read -r answer
  case $answer in y|Y|yes|YES) ;; *) echo "not merged"; exit 1 ;; esac
fi

# Move the base forward (the hooks let I2R_MERGE=1 through), checked against
# the value it had when the merge began.
if [[ -n $base_wt ]]; then
  I2R_MERGE=1 git -C "$base_wt" merge -q --ff-only "$new" || die "couldn't move $base forward in $base_wt"
else
  I2R_MERGE=1 git -C "$PROJECT" update-ref "refs/heads/$base" "$new" "$old" || die "couldn't move $base: it changed while merging"
fi
cleanup; trap - EXIT

# Record the merge, then close the issues it names.
store_begin_write
rec_set "$f" State merged; rec_set "$f" Merged "$(today)"; rec_set "$f" Merge-Commit "$new"; rec_set "$f" Closes "$closes"
store_commit "cr.merge: #$n $title"
store_end_write
short=$(git -C "$PROJECT" rev-parse --short "$new")
for i in $closes; do
  "$tracker" -C "$PROJECT" issue-close "$i" --reason completed --comment "Closed by change request #$n ($short)" | sed 's/^/  /'
done

if [[ $delete == true ]]; then
  if git -C "$PROJECT" worktree list --porcelain | grep -x "branch refs/heads/$head" >/dev/null; then
    note "$head is checked out, so it wasn't deleted"
  else
    git -C "$PROJECT" branch -q -D "$head" && echo "  deleted branch $head"
  fi
fi
rm -rf "$logs"
echo "merged #$n as $short"
