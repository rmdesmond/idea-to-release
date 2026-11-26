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

# The release README (decision 0023): four sections, About from the plan, and
# every skill under Usage. One without Usage fails verify.
readme=$(tar -xzOf "$archive" idea-to-release-v0.0.0/README.md)
for h in '# idea-to-release v0.0.0' '## Version' '## About' '## Install' '## Usage'; do
  grep -qxF -- "$h" <<<"$readme" || { echo "the release README lacks: $h"; exit 1; }
done
grep -qF "$(sed -n '5p' "$root/docs/plan/PLAN.md" | cut -c1-40)" <<<"$readme" || { echo "About isn't the plan's summary"; exit 1; }
for d in "$root"/skills/*/; do
  grep -qF "\`/i2r:$(basename "$d")\`" <<<"$readme" || { echo "Usage doesn't list $(basename "$d")"; exit 1; }
done
rm -rf "$work/x" && mkdir "$work/x" && tar -xzf "$archive" -C "$work/x"
sed -i.bak '/^## Usage$/d' "$work/x/idea-to-release-v0.0.0/README.md" && rm "$work/x/idea-to-release-v0.0.0/README.md.bak"
tar -czf "$work/no-usage.tar.gz" -C "$work/x" idea-to-release-v0.0.0
if out=$("$t/verify.sh" "$work/no-usage.tar.gz" 2>&1); then echo "verify accepted a README without Usage"; exit 1; fi
grep -q 'has no "## Usage" section' <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }

# The plugin's manifests (decision 0019) must match the release's version.
# The source root is a copy of this repository, so `claude plugin validate`
# runs too when claude is installed (it isn't on CI).
src="$work/src"; mkdir "$src"
(cd "$root" && tar -cf - --exclude .git .) | tar -xf - -C "$src"
v=$(grep -F '"version":' "$src/.claude-plugin/plugin.json" | sed -E 's/[^0-9]*([0-9]+[.][0-9]+[.][0-9]+).*/\1/')
match=$("$t/build.sh" "v$v" "$work/match" "$src")
"$t/verify.sh" "$match" "$src" >/dev/null || { echo "verify failed with matching plugin manifests"; "$t/verify.sh" "$match" "$src"; exit 1; }
tar -tzf "$match" | grep -x "idea-to-release-v$v/docs/tutorial.md" >/dev/null || { echo "the archive doesn't ship docs/tutorial.md"; exit 1; }
printf '# edited\n' >> "$src/docs/tutorial.md"
if out=$("$t/verify.sh" "$match" "$src" 2>&1); then echo "verify accepted an archive without the current tutorial"; exit 1; fi
grep -q "doesn't ship it" <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }
(cd "$root" && cat docs/tutorial.md) > "$src/docs/tutorial.md"
sed -i.bak "s/\"version\": \"$v\"/\"version\": \"9.9.9\"/" "$src/.claude-plugin/plugin.json" && rm "$src/.claude-plugin/plugin.json.bak"
if out=$("$t/verify.sh" "$match" "$src" 2>&1); then echo "verify accepted a plugin.json with the wrong version"; exit 1; fi
grep -q "plugin.json's version isn't $v" <<<"$out" || { echo "unexpected verify output: $out"; exit 1; }
