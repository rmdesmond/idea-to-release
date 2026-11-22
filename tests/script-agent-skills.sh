#!/usr/bin/env bash
# The agent-skills target: an archive built from this repository passes
# package.verify, and a broken archive fails it.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
t="$root/adapters/target/agent-skills"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

archive=$("$t/build.sh" v0.0.0 "$work/out" "$root")
"$t/verify.sh" "$archive" >/dev/null || { echo "verify failed on a fresh build"; "$t/verify.sh" "$archive"; exit 1; }

# Break one skill's pointer to the shared files; verify must notice.
mkdir "$work/x" && tar -xzf "$archive" -C "$work/x"
sed -i.bak 's#\.\./idea-to-release/#../shared/#g' "$work/x/idea-to-release-v0.0.0/skills/work-issue/SKILL.md"
rm "$work/x/idea-to-release-v0.0.0/skills/work-issue/SKILL.md.bak"
tar -czf "$work/broken.tar.gz" -C "$work/x" idea-to-release-v0.0.0
if out=$("$t/verify.sh" "$work/broken.tar.gz" 2>&1); then echo "verify accepted a broken archive"; exit 1; fi
grep -q "work-issue: SKILL.md doesn't say where the shared files are" <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }

# The plugin's manifests (decision 0019) must match the release's version.
# The source root is a copy of this repository, so `claude plugin validate`
# runs too when claude is installed (it isn't on CI).
src="$work/src"; mkdir "$src"
(cd "$root" && tar -cf - --exclude .git .) | tar -xf - -C "$src"
v=$(grep -F '"version":' "$src/.claude-plugin/plugin.json" | sed -E 's/[^0-9]*([0-9]+[.][0-9]+[.][0-9]+).*/\1/')
match=$("$t/build.sh" "v$v" "$work/match" "$src")
"$t/verify.sh" "$match" "$src" >/dev/null || { echo "verify failed with matching plugin manifests"; "$t/verify.sh" "$match" "$src"; exit 1; }
sed -i.bak "s/\"version\": \"$v\"/\"version\": \"9.9.9\"/" "$src/.claude-plugin/plugin.json" && rm "$src/.claude-plugin/plugin.json.bak"
if out=$("$t/verify.sh" "$match" "$src" 2>&1); then echo "verify accepted a plugin.json with the wrong version"; exit 1; fi
grep -q "plugin.json's version isn't $v" <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }
