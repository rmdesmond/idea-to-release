#!/usr/bin/env bash
# The local forge's pipeline and release verbs (adapters/forge/local):
# pipeline.render writes nothing, pipeline.status runs the stages in a clean
# worktree, tag.create never moves a tag, and releases are kept in the store.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fg="$root/adapters/forge/local/forge.sh"
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

p="$work/titlecase" store="$work/titlecase-tracker"
"$fg" -C "$p" repo-create >/dev/null
cd "$p"
mkdir -p .project tests
cat > .project/config.yml <<'EOF'
forge: local
tracker: local
repo: titlecase
pipeline:
  ci: on-demand
  stages:
    lint:
      enabled: true
      run: "test -f README.md"
    build:
      enabled: false
      reason: "Nothing to compile"
    unit:
      enabled: true
      run: "tests/run.sh"
    integration:
      enabled: false
      reason: "No interfaces"
  extra_stages:
    - name: audit
      runs_on: [change_request, release]
      mode: advisory
      run: "false"
EOF
printf '#!/usr/bin/env bash\n[ ! -e FAIL ]\n' > tests/run.sh && chmod +x tests/run.sh
echo "# titlecase" > README.md
echo "scratch" > untracked.txt   # not committed: a clean worktree mustn't see it
git add .project tests README.md && git commit -qm "docs(plan): plan titlecase"

# pipeline.render: no files, and the stages it would run; a bad block fails.
expect "no CI files written" "$fg" pipeline-render
expect "placeholder: Nothing to compile" "$fg" pipeline-render
expect "advisory, on change_request release: false" "$fg" pipeline-render
[[ -z $(git status --porcelain --untracked-files=no) && ! -d .github ]] || fail "pipeline-render wrote something"
sed 's/      reason: "No interfaces"//' .project/config.yml > "$work/bad.yml"
refuse "a disabled stage needs a reason" "$fg" pipeline-render "$work/bad.yml"
awk '/^    integration:/ { skip = 3 } skip { skip--; next } { print }' .project/config.yml > "$work/bad2.yml"
refuse "the core stage integration is missing" "$fg" pipeline-render "$work/bad2.yml"

# pipeline.status: a commit on change_request runs lint and the advisory stage.
out=$("$fg" pipeline-status main)
for want in "lint: pass" "build: pass (placeholder)" "unit: pass" "integration: pass (placeholder)" "audit: fail (advisory" "overall: pass"; do
  grep -qF -- "$want" <<<"$out" || fail "pipeline-status lacks '$want': $out"
done
# A release tag skips lint; a failing required stage fails overall.
git switch -q -c feat/1-break && touch FAIL && git add FAIL && git commit -qm "test: break"
out=$("$fg" pipeline-status feat/1-break)
{ grep -qF "unit: fail" <<<"$out" && grep -qF "overall: fail" <<<"$out"; } || fail "a failing stage passed: $out"
git switch -q main
expect "lint: skipped (runs on change_request)" "$fg" pipeline-status main --event merge
refuse "--event is change_request, merge or release" "$fg" pipeline-status main --event push

# tag.create: annotated, never moved.
expect "created v0.1.0 at" "$fg" tag-create v0.1.0 main -m "v0.1.0"
[[ $(git cat-file -t v0.1.0) == tag ]] || fail "the tag isn't annotated"
expect "no change: v0.1.0 is at" "$fg" tag-create v0.1.0 main
refuse "a release tag is never moved" "$fg" tag-create v0.1.0 feat/1-break
refuse "not a valid tag name" "$fg" tag-create 'v0..1' main
out=$("$fg" pipeline-status v0.1.0)
{ grep -qF "lint: skipped" <<<"$out" && grep -qF "overall: pass" <<<"$out"; } || fail "the tag's release stages: $out"

# pipeline.status on a change request checks its head.
"$tr" label-ensure x 123456 y >/dev/null 2>&1
printf 'Breaks it.\n' > "$work/b"
"$fg" cr-open --head feat/1-break --title "test: break" --body-file "$work/b" >/dev/null
expect "overall: fail" "$fg" pipeline-status 1
[[ $(git worktree list | wc -l | tr -d ' ') == 1 ]] || fail "a temporary worktree was left behind"

# release.draft and release.publish: kept in the store, a draft first, never overwritten once published.
printf '# v0.1.0\n\nThe first release.\n' > "$work/notes"
printf 'archive bytes\n' > "$work/titlecase-v0.1.0.tar.gz"
refuse "tag v9.9.9 doesn't exist" "$fg" release-draft v9.9.9 --notes-file "$work/notes"
refuse "no draft for v0.1.0" "$fg" release-publish v0.1.0
expect "created draft v0.1.0" "$fg" release-draft v0.1.0 --title "v0.1.0" --notes-file "$work/notes" --asset "$work/titlecase-v0.1.0.tar.gz"
expect "asset titlecase-v0.1.0.tar.gz 14 bytes" "$fg" release-view v0.1.0
expect "State: draft" "$fg" release-view v0.1.0
expect "no changes: draft v0.1.0" "$fg" release-draft v0.1.0 --title "v0.1.0" --notes-file "$work/notes" --asset "$work/titlecase-v0.1.0.tar.gz"
printf '# v0.1.0\n\nThe first release, reworded.\n' > "$work/notes2"
expect "notes changed" "$fg" release-draft v0.1.0 --title "v0.1.0" --notes-file "$work/notes2" --asset "$work/titlecase-v0.1.0.tar.gz"
expect "published v0.1.0" "$fg" release-publish v0.1.0
expect "no change: v0.1.0 was published" "$fg" release-publish v0.1.0
refuse "already published" "$fg" release-draft v0.1.0 --notes-file "$work/notes"
[[ -f $store/releases/v0.1.0/titlecase-v0.1.0.tar.gz ]] || fail "the asset isn't in the store"
git -C "$store" log --format=%s | grep -x 'release.publish: v0.1.0' >/dev/null || fail "no commit for the publish"
[[ -z $(git -C "$store" status --porcelain) ]] || fail "the store is dirty"

# A tag moved behind the draft's back is refused at publish.
expect "created v0.2.0" "$fg" tag-create v0.2.0 main
"$fg" release-draft v0.2.0 --notes-file "$work/notes" >/dev/null
git tag -d v0.2.0 >/dev/null && git tag -a v0.2.0 feat/1-break -m moved
refuse "not the drafted commit" "$fg" release-publish v0.2.0

# Release and changelog links.
expect "release: $store/releases/v0.1.0" "$fg" release-links v0.1.0
printf x > "$work/release.md"
refuse "can't be named release.md" "$fg" release-draft v0.2.0 --notes-file "$work/notes" --asset "$work/release.md"
expect "docs/tutorial.md at v0.1.0 (git show v0.1.0:docs/tutorial.md)" "$fg" release-links v0.1.0 docs/tutorial.md
expect "compare: none" "$fg" release-links v0.1.0

echo "ok: local forge pipeline and releases"
