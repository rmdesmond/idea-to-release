#!/usr/bin/env bash
# The local forge's change requests (adapters/forge/local): cr.open, cr.update,
# cr.status and cr.list as records in the tracker store, and the maintainer's
# merge.sh, with conflicts, a failing stage and re-runs.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fg="$root/adapters/forge/local/forge.sh"
mg="$root/adapters/forge/local/merge.sh"
tr="$root/adapters/tracker/local/tracker.sh"
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$work/gitconfig"
printf '[user]\n\tname = Ada Lovelace\n\temail = ada@example.com\n' > "$work/gitconfig"

fail() { echo "FAIL: $*"; exit 1; }
expect() {
  local want=$1 out; shift
  out=$("$@" 2>&1) || fail "'$*' failed: $out"
  grep -qF -- "$want" <<<"$out" || fail "'$*' printed '$out', expected '$want'"
}
refuse() {
  local want=$1 out; shift
  if out=$("$@" 2>&1); then fail "'$*' succeeded: $out"; fi
  grep -qF -- "$want" <<<"$out" || fail "'$*' printed '$out', expected '$want'"
}

# A project with the rules in place, a passing unit stage and a placeholder.
p="$work/titlecase" store="$work/titlecase-tracker"
"$fg" -C "$p" repo-create >/dev/null
cd "$p"
mkdir -p .project tests
cat > .project/config.yml <<'EOF'
forge: local
tracker: local
repo: titlecase
default_branch: main
pipeline:
  stages:
    lint:
      enabled: false
      reason: "Nothing to lint"
    unit:
      enabled: true
      run: "tests/run.sh"   # a comment
  extra_stages: []
EOF
printf '#!/usr/bin/env bash\n[ ! -e FAIL ]\n' > tests/run.sh && chmod +x tests/run.sh
echo "# titlecase" > README.md
git add -A && git commit -qm "docs(plan): plan titlecase"
"$fg" repo-configure --merge-method squash --delete-branch-on-merge true >/dev/null
"$fg" rule-require-checks lint unit >/dev/null
"$fg" rule-protect-branch >/dev/null
"$tr" label-ensure ci:full 5319e7 "Run the full pipeline" >/dev/null 2>&1
printf 'Plan-Task: T-001\n' > "$work/i1"; printf 'Plan-Task: T-002\n' > "$work/i2"
"$tr" issue-create --title "T-001: Add words" --body-file "$work/i1" >/dev/null   # #1
"$tr" issue-create --title "T-002: Add more" --body-file "$work/i2" >/dev/null    # #2

# cr.open: a record numbered from the shared counter; one per open head.
git switch -q -c feat/1-words && echo words > words.txt && git add words.txt && git commit -qm "feat: words"
printf '## What changed\n\nWords.\n\n## Issue\n\nCloses #1\n' > "$work/b1"
expect "opened 3" "$fg" cr-open --head feat/1-words --title "feat: add words" --body-file "$work/b1"
expect "exists 3" "$fg" cr-open --head feat/1-words --title "feat: add words" --body-file "$work/b1"
[[ -f $store/crs/0003.md ]] || fail "no record for #3"
git branch -q empty main
refuse "has no commits that aren't on main" "$fg" cr-open --head empty --title x --body-file "$work/b1"
refuse "no local branch nope" "$fg" cr-open --head nope --title x --body-file "$work/b1"
git branch -q lbl feat/1-words
refuse "no label 'nope'" "$fg" cr-open --head lbl --title x --body-file "$work/b1" --label nope
git branch -q -D lbl

# cr.status: closing references parsed as GitHub does; a reference that isn't
# preceded by a keyword, or names no issue, doesn't count.
out=$("$fg" cr-status feat/1-words)
for want in "number: 3" "state: open" "mergeable: yes" "closes: 1" "checks: no checks reported" "review: no review required"; do
  grep -qF -- "$want" <<<"$out" || fail "cr-status lacks '$want': $out"
done
printf 'Fixes: #2, see #1, prefix#1 and closes #99.\nRESOLVED #1\n' > "$work/b1x"
expect "body changed" "$fg" cr-update 3 --body-file "$work/b1x"
expect "closes: 2 1" "$fg" cr-status 3
expect "body changed" "$fg" cr-update 3 --body-file "$work/b1"
expect "no changes" "$fg" cr-update feat/1-words --body-file "$work/b1" --title "feat: add words"
expect "labels: none → ci:full" "$fg" cr-update 3 --add-label ci:full
expect "title: feat: add words → feat: add the words" "$fg" cr-update 3 --title "feat: add the words"
expect $'3\topen\tfeat: add the words\tfeat/1-words' "$fg" cr-list --state open

# merge.sh refuses without a terminal or --yes, and changes nothing.
before=$(git rev-parse main)
refuse "run with --yes" "$mg" 3 </dev/null
[[ $(git rev-parse main) == "$before" ]] || fail "a refused merge moved main"

# A failing required stage refuses the merge.
touch FAIL && git add FAIL && git commit -qm "test: break the unit stage"
refuse "a required stage failed" "$mg" 3 --yes
[[ $(git rev-parse main) == "$before" ]] || fail "a failing merge moved main"
git rm -q FAIL && git commit -qm "test: mend the unit stage"

# A good merge: main checked out and clean moves forward; the record, the issue
# and the branch follow.
git switch -q main
out=$("$mg" 3 --yes 2>&1) || fail "merge failed: $out"
for want in "unit: pass" "lint: pass (placeholder: Nothing to lint)" "Closes:  1" "closed 1 completed" "deleted branch feat/1-words" "merged #3 as"; do
  grep -qF -- "$want" <<<"$out" || fail "merge output lacks '$want': $out"
done
[[ $(git log -1 --format=%s main) == "feat: add the words (#3)" ]] || fail "merge commit subject: $(git log -1 --format=%s main)"
[[ $(git rev-list --count "$before..main") == 1 ]] || fail "the merge isn't one squash commit"
[[ -f words.txt && -z $(git status --porcelain) ]] || fail "the checked-out main wasn't moved forward cleanly"
! git rev-parse -q --verify refs/heads/feat/1-words >/dev/null || fail "the head branch wasn't deleted"
{ grep -qx 'State: merged' "$store/crs/0003.md" && grep -qx "Merge-Commit: $(git rev-parse main)" "$store/crs/0003.md"; } || fail "the record wasn't updated: $(cat "$store/crs/0003.md")"
expect "Comment: Closed by change request #3" "$tr" issue-view 1
expect "state: merged" "$fg" cr-status 3
merged=$("$fg" cr-list)
[[ $merged == "3	feat: add the words	$(date -u +%Y-%m-%d)	$(git rev-parse main)	1" ]] || fail "cr-list: $merged"
refuse "#3 is merged, not open" "$mg" 3 --yes
refuse "it isn't updated" "$fg" cr-update 3 --title x
[[ -z $(git -C "$store" status --porcelain) ]] || fail "the store is dirty"
git -C "$store" log --format=%s | grep -x 'cr.merge: #3 feat: add the words' >/dev/null || fail "no commit for the merge"

# Conflicts refuse the merge; cr.status sees them first.
git switch -q -c feat/2-more && echo "more" > README.md && git commit -qam "feat: more"
git switch -q -c other main && echo "other" > README.md && git commit -qam "feat: other"
printf 'Closes #2\n' > "$work/b2"
expect "opened 4" "$fg" cr-open --head feat/2-more --title "feat: more" --body-file "$work/b2"
expect "opened 5" "$fg" cr-open --head other --title "feat: other" --body-file "$work/b2"
git switch -q main
"$mg" 5 --yes >/dev/null 2>&1 || fail "merging #5 failed"
expect "mergeable: conflicts" "$fg" cr-status 4
refuse "has conflicts with main" "$mg" 4 --yes
[[ $(git log -1 --format=%s main) == "feat: other (#5)" ]] || fail "a conflicting merge changed main"
expect "no changes (#2 is already closed" "$tr" issue-close 2 --reason completed

# With main not checked out anywhere, the ref moves directly; a dirty main refuses.
git switch -q feat/2-more && git reset -q --hard main && echo "even more" >> README.md && git commit -qam "feat: even more"
"$mg" 4 --yes >/dev/null 2>&1 || fail "merging #4 with main not checked out failed"
[[ $(git log -1 --format=%s main) == "feat: more (#4)" ]] || fail "main didn't move: $(git log -1 --format=%s main)"
git switch -q main && git switch -q -c feat/9-x && echo x > x.txt && git add x.txt && git commit -qm "feat: x"
printf 'Nothing to close.\n' > "$work/b9"
"$fg" cr-open --head feat/9-x --title "feat: x" --body-file "$work/b9" >/dev/null
git switch -q main && echo "dirty" >> README.md
refuse "uncommitted changes" "$mg" 6 --yes
git checkout -q README.md

echo "ok: local forge change requests"
