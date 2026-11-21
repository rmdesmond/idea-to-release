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
