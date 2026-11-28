#!/usr/bin/env bash
# The local forge (adapters/forge/local): the repository, access and rule
# verbs, and the forge-specific sources. The hooks from rule.protect-branch
# must refuse every change to the default branch except merge.sh's.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fg="$root/adapters/forge/local/forge.sh"
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

p="$work/titlecase"

# repo.describe and repo.create: no repository, then one with no remote.
expect "exists: false" "$fg" -C "$work" repo-describe
expect "created $p (default branch main, no remote)" "$fg" -C "$p" repo-create --description "Title-cases text"
expect "exists $p" "$fg" -C "$p" repo-create
# A folder git-inited before repo-create gets the description; a set one is kept.
p3="$work/inited" && git init -q "$p3"
expect "description: none → Inited first" "$fg" -C "$p3" repo-create --description "Inited first"
expect "repo-configure --description changes it" "$fg" -C "$p3" repo-create --description "Another"
expect "description: Inited first" "$fg" -C "$p3" repo-describe
cd "$p"
mkdir -p .project && printf 'forge: local\ntracker: local\nrepo: titlecase\ndefault_branch: main\n' > .project/config.yml
out=$("$fg" repo-describe)
for want in "exists: true" "empty: true" "default_branch: main" "description: Title-cases text" "visibility: not applicable" "remotes: none" "tracker_store: missing ($work/titlecase-tracker)"; do
  grep -qF -- "$want" <<<"$out" || fail "repo-describe lacks '$want': $out"
done
[[ -z $(git remote) ]] || fail "repo-create added a remote"

# repo.configure: only squash; visibility and features don't apply.
expect "merge_method: unset → squash" "$fg" repo-configure --merge-method squash
expect "no changes" "$fg" repo-configure --merge-method squash
refuse "only the squash merge method" "$fg" repo-configure --merge-method rebase
expect "delete_branch_on_merge: unset → true" "$fg" repo-configure --delete-branch-on-merge true
expect "description: Title-cases text → Title-cases words" "$fg" repo-configure --description "Title-cases words"
expect "visibility: not applicable" "$fg" repo-configure --visibility private
expect "merge_methods: squash" "$fg" repo-describe

# access: one person, and nothing to grant.
expect $'Ada Lovelace\tadmin' "$fg" access-list
expect "people who can write: 1" "$fg" access-list
refuse "isn't applicable on the local forge" "$fg" access-grant someone write

# The first commit on main, before any rules (conventions §10).
echo "# titlecase" > README.md && git add -A && git commit -qm "docs(plan): plan titlecase"

# rule.require-review: 0 approvals only; rule.require-checks: recorded for merge.sh.
expect "required approvals: unset → 0" "$fg" rule-require-review 0 false --check
[[ -z $(git config --get i2r.requiredapprovals || true) ]] || fail "--check wrote the review rule"
expect "required approvals: unset → 0" "$fg" rule-require-review 0 false
expect "no change: required approvals 0" "$fg" rule-require-review 0
refuse "must be 0" "$fg" rule-require-review 1
expect "required checks: none → lint build unit integration" "$fg" rule-require-checks lint build unit integration --check
expect "required checks: none → lint build unit integration" "$fg" rule-require-checks lint build unit integration
expect "no change: required checks lint build unit integration" "$fg" rule-require-checks lint build unit integration
refuse "not a stage name" "$fg" rule-require-checks 'lint;rm'

# rule.protect-branch: check, install, re-run.
expect "pre-commit: missing → install" "$fg" rule-protect-branch --check
[[ ! -e .git/hooks/pre-commit ]] || fail "--check installed a hook"
expect "pre-commit: installed" "$fg" rule-protect-branch
expect "reference-transaction: present" "$fg" rule-protect-branch
expect "pre-commit: present" "$fg" rule-protect-branch

# The hooks: no direct commit, merge, reset, force update or deletion of main.
echo "change" >> README.md && git add README.md
refuse "'main' is protected" git commit -qm "direct"
git reset -q --hard
git switch -q -c feat/1-words && echo "words" > words.txt && git add words.txt && git commit -qm "feat: words"
git switch -q main
refuse "'main' is protected" git merge -q --ff-only feat/1-words
git reset -q --hard   # a refused fast-forward can leave the working tree updated; HEAD is unchanged
[[ ! -e words.txt ]] || fail "reset left words.txt"
refuse "'main' is protected" git merge -q --no-ff -m merge feat/1-words
git merge --abort 2>/dev/null || git reset -q --hard
git switch -q feat/1-words
refuse "'main' is protected" git branch -f main feat/1-words
refuse "'main' is protected" git branch -D main
git switch -q main
before=$(git rev-parse HEAD)
refuse "'main' is protected" git reset -q --hard feat/1-words
[[ $(git rev-parse HEAD) == "$before" ]] || fail "main moved"
# Branches and tags are free; merge.sh's step (I2R_MERGE=1) is let through.
{ git tag v0.0.1 && git tag -d v0.0.1 >/dev/null; } || fail "tags were refused"
git switch -q feat/1-words
{ echo more >> words.txt && git commit -qam "feat: more words"; } || fail "a branch commit was refused"
git switch -q main
{ I2R_MERGE=1 git merge -q --squash feat/1-words >/dev/null && I2R_MERGE=1 git commit -qm "feat: words (#1)"; } || fail "the merge step was refused"
[[ -f words.txt ]] || fail "the squash merge didn't land"
# Housekeeping moves refs without changing them, and must keep working.
main_before=$(git rev-parse main)
git pack-refs --all || fail "pack-refs was refused"
git gc -q || fail "gc was refused"
[[ $(git rev-parse main) == "$main_before" ]] || fail "main moved during housekeeping"
git switch -q feat/1-words
refuse "'main' is protected" git branch -D main   # packed now, not loose
refuse "'main' is protected" git update-ref refs/heads/main feat/1-words
git switch -q main

# A hook the adapter didn't write is never overwritten.
p2="$work/other" && "$fg" -C "$p2" repo-create >/dev/null
printf '#!/bin/sh\necho mine\n' > "$p2/.git/hooks/pre-commit"
refuse "a different hook is installed" "$fg" -C "$p2" rule-protect-branch
grep -qx 'echo mine' "$p2/.git/hooks/pre-commit" || fail "a foreign hook was overwritten"
# An older hook of the adapter's own is replaced.
printf '#!/bin/sh\n# idea-to-release local forge: rule.protect-branch\n' > "$p/.git/hooks/pre-commit"
expect "pre-commit: ours-different → install" "$fg" rule-protect-branch --check
expect "pre-commit: installed" "$fg" rule-protect-branch

# Forge-specific sources, offline.
for k in mit apache-2.0 bsd-3-clause gpl-3.0 mpl-2.0; do "$fg" licence "$k" "Ada Lovelace" 2026 >/dev/null || fail "no $k text"; done
expect "Copyright (c) 2026 Ada Lovelace" "$fg" licence MIT "Ada Lovelace" 2026
out=$("$fg" licence mit "A \\ B" 2026); grep -qF 'Copyright (c) 2026 A \ B' <<<"$out" || fail "the holder was mangled: $out"
refuse "ask the user for the licence text" "$fg" licence unlicense
expect "Ada Lovelace" "$fg" owner-name
expect ".DS_Store" "$fg" gitignore
expect "no .gitignore templates" "$fg" gitignore Python

echo "ok: local forge"
