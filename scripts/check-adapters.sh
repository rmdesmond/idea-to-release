#!/usr/bin/env bash
# Check that every adapter covers every neutral verb in conventions.md §2.
#
# - Tracker verbs (the "**Tracker:**" line of §2) must have a section in every
#   adapters/tracker/*.md. All other verbs must have one in every adapters/forge/*.md.
# - A section is a heading "### <verb>". It must contain either a "**Command:**"
#   entry or the line "Status: not yet implemented".
# - Verb-shaped headings that aren't in §2 are reported as errors.
#
# Usage: scripts/check-adapters.sh [repo-root]   (default: the script's parent directory)
# Exit status: 0 if every check passes, 1 otherwise.

set -euo pipefail

root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
conventions="$root/conventions.md"
[[ -f "$conventions" ]] || { echo "error: $conventions not found" >&2; exit 1; }

# Print the §2 bullet lines, then the backticked verbs on them.
section2() {
  awk '/^## 2\./ {on=1; next} /^## / {on=0} on' "$conventions"
}
verbs_from() {
  # The backticks are literal Markdown code spans, not command substitution.
  # shellcheck disable=SC2016
  grep -o '`[a-z]*\.[a-z-]*`' | tr -d '`' | sort -u
}

tracker_verbs=$(section2 | grep '^- \*\*Tracker:\*\*' | verbs_from)
forge_verbs=$(section2 | grep '^- \*\*' | grep -v '^- \*\*Tracker:\*\*' | verbs_from)

if [[ -z "$tracker_verbs" || -z "$forge_verbs" ]]; then
  echo "error: could not read verbs from conventions.md §2" >&2
  exit 1
fi

failures=0
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

# Print the body of section "### <verb>" (up to the next ## or ### heading).
section_body() {
  awk -v h="### $2" '$0 == h {on=1; next} /^##/ {on=0} on' "$1"
}

check_adapter() {
  local file="$1" expected="$2" rel="${1#"$root"/}"
  local verb body headings

  for verb in $expected; do
    if ! grep -qx "### $verb" "$file"; then
      fail "$rel: missing section for $verb"
      continue
    fi
    body=$(section_body "$file" "$verb")
    if ! grep -q '\*\*Command:\*\*' <<<"$body" && ! grep -qx 'Status: not yet implemented' <<<"$body"; then
      fail "$rel: $verb has neither a **Command:** nor 'Status: not yet implemented'"
    fi
  done

  headings=$(grep -o '^### [a-z]*\.[a-z-]*$' "$file" | sed 's/^### //' || true)
  for verb in $headings; do
    grep -qx "$verb" <<<"$expected" || fail "$rel: $verb is not a verb in conventions.md §2 for this adapter type"
  done
}

shopt -s nullglob
adapters=0
for f in "$root"/adapters/forge/*.md;   do check_adapter "$f" "$forge_verbs";   adapters=$((adapters + 1)); done
for f in "$root"/adapters/tracker/*.md; do check_adapter "$f" "$tracker_verbs"; adapters=$((adapters + 1)); done

if (( adapters == 0 )); then
  echo "error: no adapters found under $root/adapters" >&2
  exit 1
fi

if (( failures > 0 )); then
  echo "$failures problem(s) in $adapters adapter(s)"
  exit 1
fi
echo "ok: $adapters adapter(s) cover all $(wc -w <<<"$forge_verbs $tracker_verbs" | tr -d ' ') verbs"
