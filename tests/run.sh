#!/usr/bin/env bash
# Run the repository's script tests.
#
# Each folder tests/check-<name>/ tests scripts/check-<name>.sh:
# - every file under valid/ must pass
# - every file under invalid/ must fail with the message given on its first
#   line, as "<!-- expect: <text> -->" (Markdown) or "# expect: <text>" (YAML)
# - if the folder has a plan.md, it is passed as the script's second argument
#
# Each folder tests/render-<name>/ tests a renderer, named in its "command"
# file (a path relative to the repository root):
# - every ok/<case>/config.yml must render exactly ok/<case>/expected.yml
# - every err/*.yml must fail with the message on its first line,
#   as "# expect: <text>"
#
# Each script tests/script-<name>.sh is a self-contained test: it passes if
# it exits 0. Its output is shown when it fails.
#
# Usage: tests/run.sh
# Exit status: 0 if every test passes, 1 otherwise.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
passed=0 failed=0

fail() {
  echo "FAIL  $1"
  if [[ -n "${2:-}" ]]; then printf '%s\n' "$2" | while IFS= read -r line; do echo "      $line"; done; fi
  failed=$((failed + 1))
}

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

for dir in "$root"/tests/render-*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  cmd="$root/$(cat "$dir/command")"
  [[ -x "$cmd" ]] || { fail "$name: command $cmd is not executable"; continue; }

  for case in "$dir"ok/*/; do
    [[ -d "$case" ]] || continue
    rel="$name/ok/$(basename "$case")"
    if ! out=$("$cmd" "$case/config.yml" 2>&1); then
      fail "$rel failed to render" "$out"
    elif ! diff_out=$(diff "$case/expected.yml" <(printf '%s\n' "$out")); then
      fail "$rel differs from expected.yml" "$diff_out"
    else
      passed=$((passed + 1))
    fi
  done

  for f in "$dir"err/*.yml; do
    [[ -f "$f" ]] || continue
    rel="$name/err/$(basename "$f")"
    expect=$(sed -n '1s/^# expect: \(.*\)$/\1/p' "$f")
    if [[ -z "$expect" ]]; then fail "$rel has no expect line"; continue; fi
    if out=$("$cmd" "$f" 2>&1); then
      fail "$rel was rendered"
    elif ! grep -qF -- "$expect" <<<"$out"; then
      fail "$rel failed, but without: $expect" "$out"
    else
      passed=$((passed + 1))
    fi
  done
done

for t in "$root"/tests/script-*.sh; do
  [[ -f "$t" ]] || continue
  if out=$("$t" 2>&1); then
    passed=$((passed + 1))
  else
    fail "$(basename "$t")" "$out"
  fi
done

echo "$passed passed, $failed failed"
(( failed == 0 ))
