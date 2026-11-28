#!/usr/bin/env bash
# The local tracker (adapters/tracker/local): every verb on a temporary store,
# with re-runs and failure cases. The store is a git repository, and every
# write is one commit.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tr="$root/adapters/tracker/local/tracker.sh"
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT

# Isolate git from the user's configuration, and give it an identity.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$work/gitconfig"
printf '[user]\n\tname = Test\n\temail = test@example.com\n[init]\n\tdefaultBranch = main\n' > "$work/gitconfig"

fail() { echo "FAIL: $*"; exit 1; }
# expect <text> <command...>: the command succeeds and its output contains <text>.
expect() {
  local want=$1 out; shift
  out=$("$@" 2>&1) || fail "'$*' failed: $out"
  grep -qF -- "$want" <<<"$out" || fail "'$*' printed '$out', expected '$want'"
}
# refuse <text> <command...>: the command fails and its output contains <text>.
refuse() {
  local want=$1 out; shift
  if out=$("$@" 2>&1); then fail "'$*' succeeded: $out"; fi
  grep -qF -- "$want" <<<"$out" || fail "'$*' printed '$out', expected '$want'"
}
commits() { git -C "$store" rev-list --count HEAD; }

p="$work/titlecase"
mkdir -p "$p/.project" && git -C "$p" init -q
printf 'forge: local\ntracker: local\nrepo: titlecase\n' > "$p/.project/config.yml"
cd "$p"
store="$work/titlecase-tracker"

# The default path, and no store yet: reads return nothing and say so.
expect "$store" "$tr" store-path
expect missing "$tr" store-path
out=$("$tr" issue-list 2>&1) || fail "issue-list without a store failed"
grep -q "doesn't exist yet" <<<"$out" || fail "issue-list didn't say the store is missing: $out"
[[ ! -e $store ]] || fail "a read created the store"

# The first write creates the store as a git repository.
expect "created the tracker store at $store" "$tr" label-ensure type:feature 1d76db "New capability"
[[ -d $store/.git ]] || fail "the store isn't a git repository"
[[ $(commits) == 2 ]] || fail "expected 2 commits (create, label), got $(commits)"
expect "same type:feature" "$tr" label-ensure Type:Feature 1D76DB "New capability"
expect "different type:feature" "$tr" label-ensure type:feature ff0000 "New capability"
[[ $(commits) == 2 ]] || fail "a check wrote a commit"
expect "updated type:feature" "$tr" label-ensure type:feature ff0000 "New capability" --update
for l in ready blocked priority:normal; do "$tr" label-ensure "$l" 0e8a16 "A label" >/dev/null; done
refuse "six hex digits" "$tr" label-ensure bad '#123456' "x"
refuse "can't contain ','" "$tr" label-ensure 'a,b' 123456 "x"
refuse "can't contain '|'" "$tr" label-ensure ok 123456 'a | b'
expect $'blocked\t0e8a16\tA label' "$tr" label-list

# Milestones: create, same, different, update, closed and reopen.
expect "created 1 M1: Walking skeleton" "$tr" milestone-ensure "M1: Walking skeleton" "A first usable step."
expect "same 1 M1: Walking skeleton" "$tr" milestone-ensure "M1: Walking skeleton" "A first usable step."
expect "different 1" "$tr" milestone-ensure "M1: Walking skeleton" "Something else."
expect "updated 1" "$tr" milestone-ensure "M1: Walking skeleton" 'A first step, with a \ backslash.' --update
expect 'with a \ backslash.' "$tr" milestone-list
expect "created 2 M2: Options" "$tr" milestone-ensure "M2: Options"
sed -i.bak 's/| 2 | M2: Options | open |/| 2 | M2: Options | closed |/' "$store/milestones.md" && rm "$store/milestones.md.bak"
git -C "$store" commit -qam "test: close M2"
expect "closed 2 M2: Options" "$tr" milestone-ensure "M2: Options"
expect "updated 2" "$tr" milestone-ensure "M2: Options" --reopen

# Issues: create, then find again by the Plan-Task line instead of duplicating.
printf '## Context\n\nThe first task.\n\nPlan-Task: T-001\n' > "$work/b1"
printf '## Context\n\nThe second task.\n\nPlan-Task: T-002\n' > "$work/b2"
printf 'No plan task here.\n' > "$work/b3"
expect "created 1" "$tr" issue-create --title "T-001: Add the command" --body-file "$work/b1" --label type:feature --label ready --milestone "M1: Walking skeleton"
expect "found 1 open" "$tr" issue-create --title "T-001: Add the command" --body-file "$work/b1"
expect "created 2" "$tr" issue-create --title "T-002: Add options" --body-file "$work/b2" --label blocked
expect "created 3" "$tr" issue-create --title "Fix a typo" --body-file "$work/b3"
refuse "no label 'nope'" "$tr" issue-create --title "x" --body-file "$work/b3" --label nope
refuse "no milestone 'M9: x'" "$tr" issue-create --title "x" --body-file "$work/b3" --milestone "M9: x"
refuse "one line" "$tr" issue-create --title $'two\nlines' --body-file "$work/b3"
[[ -f $store/issues/0001.md && -f $store/issues/0003.md && ! -f $store/issues/0004.md ]] || fail "unexpected issue files"
[[ $(tr -d '\n' < "$store/next") == 4 ]] || fail "the counter isn't 4"
grep -qx 'Labels: type:feature, ready' "$store/issues/0001.md" || fail "issue 1 labels: $(cat "$store/issues/0001.md")"

# A second issue with the same Plan-Task line is a conflict.
cp "$store/issues/0001.md" "$store/issues/0009.md" && git -C "$store" add -A && git -C "$store" commit -qm "test: duplicate"
refuse "more than one issue carries 'Plan-Task: T-001'" "$tr" issue-create --title "T-001: x" --body-file "$work/b1"
git -C "$store" rm -q "issues/0009.md" && git -C "$store" commit -qm "test: remove duplicate"

# Update: only what differs, reported as old → new.
expect "no changes" "$tr" issue-update 2 --title "T-002: Add options" --add-label blocked
before=$(commits)
expect "labels: blocked → ready" "$tr" issue-update 2 --remove-label blocked --add-label ready
expect "milestone: none → M2: Options" "$tr" issue-update 2 --milestone "M2: Options"
printf '## Context\n\nThe second task.   \n\nPlan-Task: T-002\n\n\n' > "$work/b2-trailing"
expect "no changes" "$tr" issue-update 2 --body-file "$work/b2-trailing"
printf '## Context\n\nThe second task, reworded.\n\nPlan-Task: T-002\n' > "$work/b2-new"
expect "body changed" "$tr" issue-update 2 --body-file "$work/b2-new"
expect "milestone: M2: Options → none" "$tr" issue-update 2 --remove-milestone
[[ $(commits) == $((before + 4)) ]] || fail "expected one commit per update"
refuse "no issue #42" "$tr" issue-update 42 --title "x"

# Links: blocked-by, blocks (stored on the dependent side), parent, cycles, removal.
expect "added #2 blocked-by #1" "$tr" issue-link 2 blocked-by 1
expect "present #2 blocked-by #1" "$tr" issue-link 2 blocked-by 1
expect "present #2 blocked-by #1" "$tr" issue-link 1 blocks 2
expect "added #3 blocked-by #2" "$tr" issue-link 2 blocks 3
refuse "would make a cycle" "$tr" issue-link 1 blocked-by 3
refuse "linked to itself" "$tr" issue-link 1 blocked-by 1
expect "Blocking: 2" "$tr" issue-view 1
expect "Blocked-by: 1" "$tr" issue-view 2
expect "added #2 parent #1" "$tr" issue-link 2 parent 1
expect "changed #2 parent: #1 → #3" "$tr" issue-link 2 parent 3
refuse "would make a cycle" "$tr" issue-link 3 parent 2
expect "Children: 2" "$tr" issue-view 3
expect "removed #3 blocked-by #2" "$tr" issue-link 3 blocked-by 2 --remove
expect "no changes" "$tr" issue-link 3 blocked-by 2 --remove
refuse "unknown relation" "$tr" issue-link 1 relates 2

# Close: kept, never deleted; a second close is no change.
expect "closed 1 completed" "$tr" issue-close 1 --reason completed --comment 'Done, with a \ backslash.'
expect "already closed" "$tr" issue-close 1 --reason not-planned
expect "closed 3 not planned" "$tr" issue-close 3 --reason "not planned"
[[ -f $store/issues/0001.md ]] || fail "a closed issue was deleted"
grep -qx 'Comment: Done, with a \\ backslash.' "$store/issues/0001.md" || fail "the comment was mangled"
grep -qx "Closed: $(date -u +%Y-%m-%d)" "$store/issues/0001.md" || fail "no UTC closed date"
refuse "--reason is completed or not-planned" "$tr" issue-close 2 --reason finished
expect "no changes" "$tr" issue-update 1 --title "T-001: Add the command"

# List: filters, and full records with --bodies.
out=$("$tr" issue-list)
{ [[ $(wc -l <<<"$out" | tr -d ' ') == 1 ]] && grep -q $'^2\topen\tT-002: Add options\tready' <<<"$out"; } || fail "open list: $out"
[[ $("$tr" issue-list --state all | wc -l | tr -d ' ') == 3 ]] || fail "the all list isn't 3 issues"
[[ $("$tr" issue-list --state closed --milestone "M1: Walking skeleton" | cut -f1) == 1 ]] || fail "milestone filter"
[[ $("$tr" issue-list --state all --label READY | cut -f1 | tr '\n' ' ') == "1 2 " ]] || fail "label filter"
out=$("$tr" issue-list --state all --bodies); grep -qx 'Plan-Task: T-002' <<<"$out" || fail "--bodies lacks the bodies"
refuse "--state is open, closed or all" "$tr" issue-list --state merged

# Safety: a dirty store, a lock, and a folder that isn't a store are refused.
echo "stray" > "$store/stray.txt"
refuse "uncommitted changes" "$tr" issue-close 2 --reason completed
rm "$store/stray.txt"
mkdir "$store/.lock"
refuse "locked by another write" "$tr" issue-close 2 --reason completed
rmdir "$store/.lock"
[[ ! -e $store/.lock ]] || fail "lock left behind"
git -C "$store" log --format=%s | grep -x 'issue.close: #3 (not planned)' >/dev/null || fail "no commit for the close"
[[ -z $(git -C "$store" status --porcelain) ]] || fail "the store is dirty after the writes"

# tracker_path from the config, relative to the project root; a non-store folder is refused.
mkdir -p "$work/elsewhere/notes" && echo "mine" > "$work/elsewhere/notes/todo.txt"
printf 'forge: local\ntracker: local\nrepo: titlecase\ntracker_path: "../elsewhere/notes"   # a comment\n' > "$p/.project/config.yml"
expect "$work/elsewhere/notes" "$tr" store-path
expect "not a tracker store" "$tr" store-path
refuse "isn't a tracker store" "$tr" label-ensure x 123456 y
[[ $(cat "$work/elsewhere/notes/todo.txt") == mine && ! -d $work/elsewhere/notes/.git ]] || fail "a non-store folder was changed"
printf 'forge: local\ntracker: local\ntracker_path: ../fresh\n' > "$p/.project/config.yml"
(cd "$work" && "$tr" -C "$p" label-ensure x 123456 y >/dev/null 2>&1) || fail "-C with a config tracker_path failed"
[[ -d $work/fresh/.git ]] || fail "tracker_path wasn't used for a new store"

echo "ok: local tracker"
