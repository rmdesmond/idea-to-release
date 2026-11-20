#!/usr/bin/env bash
# Run the repository's script tests.
#
# check-plan: every plan under tests/check-plan/valid must pass, and every plan
# under tests/check-plan/invalid must fail with the message given on its first
# line as "<!-- expect: <text> -->".
#
# Usage: tests/run.sh
# Exit status: 0 if every test passes, 1 otherwise.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/scripts/check-plan.sh"
passed=0 failed=0

for f in "$root"/tests/check-plan/valid/*.md; do
  if out=$("$check" "$f" 2>&1); then
    passed=$((passed + 1))
  else
    echo "FAIL  valid/$(basename "$f") was rejected:"; echo "$out" | sed 's/^/      /'
    failed=$((failed + 1))
  fi
done

for f in "$root"/tests/check-plan/invalid/*.md; do
  expect=$(sed -n '1s/^<!-- expect: \(.*\) -->$/\1/p' "$f")
  if [[ -z "$expect" ]]; then
    echo "FAIL  invalid/$(basename "$f") has no '<!-- expect: ... -->' first line"; failed=$((failed + 1)); continue
  fi
  if out=$("$check" "$f" 2>&1); then
    echo "FAIL  invalid/$(basename "$f") was accepted"; failed=$((failed + 1))
  elif ! grep -qF -- "$expect" <<<"$out"; then
    echo "FAIL  invalid/$(basename "$f") failed, but without: $expect"; echo "$out" | sed 's/^/      /'
    failed=$((failed + 1))
  else
    passed=$((passed + 1))
  fi
done

echo "$passed passed, $failed failed"
(( failed == 0 ))
