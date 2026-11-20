#!/usr/bin/env bash
# Run the repository's script tests.
#
# Each folder tests/check-<name>/ tests scripts/check-<name>.sh:
# - every file under valid/ must pass
# - every file under invalid/ must fail with the message given on its first
#   line, as "<!-- expect: <text> -->" (Markdown) or "# expect: <text>" (YAML)
# - if the folder has a plan.md, it is passed as the script's second argument
#
# Usage: tests/run.sh
# Exit status: 0 if every test passes, 1 otherwise.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
passed=0 failed=0

fail() { echo "FAIL  $1"; [[ -n "${2:-}" ]] && echo "$2" | sed 's/^/      /'; failed=$((failed + 1)); }

for dir in "$root"/tests/check-*/; do
  name=$(basename "$dir")
  check="$root/scripts/$name.sh"
  [[ -x "$check" ]] || { fail "$name: no executable scripts/$name.sh"; continue; }
  extra=()
  [[ -f "$dir/plan.md" ]] && extra=("$dir/plan.md")

  for f in "$dir"valid/*; do
    [[ -f "$f" ]] || continue
    if out=$("$check" "$f" "${extra[@]+"${extra[@]}"}" 2>&1); then
      passed=$((passed + 1))
    else
      fail "$name/valid/$(basename "$f") was rejected" "$out"
    fi
  done

  for f in "$dir"invalid/*; do
    [[ -f "$f" ]] || continue
    rel="$name/invalid/$(basename "$f")"
    expect=$(sed -n -e '1s/^<!-- expect: \(.*\) -->$/\1/p' -e '1s/^# expect: \(.*\)$/\1/p' "$f")
    if [[ -z "$expect" ]]; then fail "$rel has no expect line"; continue; fi
    if out=$("$check" "$f" "${extra[@]+"${extra[@]}"}" 2>&1); then
      fail "$rel was accepted"
    elif ! grep -qF -- "$expect" <<<"$out"; then
      fail "$rel failed, but without: $expect" "$out"
    else
      passed=$((passed + 1))
    fi
  done
done

echo "$passed passed, $failed failed"
(( failed == 0 ))
